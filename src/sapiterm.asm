; SAPI-Term - terminal for internet BBS (telnet) for the Tesla SAPI-1, set V, as a CP/M program SAPITERM.COM.
; Copyright (C) 2026 Martin Lukasek, GPLv3. Assembler pasmo 0.5.3 (build.cmd), docs in docs/.
;
; Phase 1: start, detection of the cards, keyboard and the return to CP/M. The status screen is on the AND-1V,
; the CGA-1V shows 16 colour bars; the counters show the VBI of the CGA-1V and the tick of the MPH-1V.
;
; Memory: the program, its data and the stack stay below C000h (MAP_CGA hides the RAM and CP/M above it). The
; whole program runs with interrupts disabled (an interrupt acknowledged with PC in the window of a video card
; freezes the JPR-1V). BDOS is called only with MAP_CPM.

        include "hw.inc"

        org 0100h

        jp start
        defb 0Dh,0Ah,'SAPI-Term 0.1',0Dh,0Ah,1Ah

start:
        ld (cpm_sp),sp
        ld a,i                  ; P/V = IFF2
        di
        ld a,0
        jp po,st_di
        inc a
st_di:
        ld (saved_iff),a
        ld sp,STACK_TOP
        ld a,MAP_CPM
        out (MAPREG),a
        call kbd_init
        call detect
        ld a,(has_cga)
        or a
        call nz,cga_start
        ld a,(has_and)
        or a
        jr nz,st_screen
        ld de,msg_no_and        ; no AND-1V: a message through BDOS, then back
        call bdos_puts
        jp quit
st_screen:
        call show_screen

main_loop:
        call kbd_get
        jr nc,ml_vbi
        cp K_MENU
        jp z,quit
        call show_key
ml_vbi:
        ld a,(has_cga)
        or a
        jr z,ml_tick
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_poll_vbi
        ld a,MAP_CPM            ; ld and out keep the flags
        out (MAPREG),a
        jr z,ml_tick
        ld hl,(vbi_count)
        inc hl
        ld (vbi_count),hl
        call show_counts
ml_tick:
        ld a,(has_mph)
        or a
        jr z,main_loop
        call mph_poll_tick
        jr z,main_loop
        ld hl,(tick_count)
        inc hl
        ld (tick_count),hl
        call show_counts
        jr main_loop

; quit: cards to a quiet state, MAP_CPM, the console cleared, interrupts as they were, warm boot.
quit:
        ld sp,STACK_TOP
        ld a,(has_dpi)
        or a
        call nz,dpi_close
        ld a,(has_mph)
        or a
        call nz,mph_off
        ld a,(has_cga)
        or a
        call nz,cga_off
        ld a,MAP_CPM
        out (MAPREG),a
        ld a,KB_IDLE
        out (KB_STAT),a
        ld a,(has_and)
        or a
        call nz,and_cls
        ld e,1Dh                ; ECMON console: cursor home, clear to the end of the screen
        ld c,B_CONOUT
        call BDOS
        ld e,1Fh
        ld c,B_CONOUT
        call BDOS
        ld a,(saved_iff)
        or a
        jr z,q_boot
        ei
q_boot:
        jp WBOOT

; detect: has_and, has_cga, has_mph, has_dpi = 1 for the cards that answer. Changes A, BC, DE, HL.
detect:
        ld hl,AND_TEST
        call pattern_test
        ld (has_and),a
        call cga_detect
        ld (has_cga),a
        call mph_detect
        ld (has_mph),a
        call dpi_detect
        ld (has_dpi),a
        ret

; pattern_test: A = 1 when the byte at HL keeps 55h and AAh, else 0; the byte is restored. An empty bus reads
; the last byte on it (7Eh for LD A,(HL)). Changes B.
pattern_test:
        ld b,(hl)
        ld (hl),55h
        ld a,(hl)
        cp 55h
        jr nz,pt_none
        ld (hl),0AAh
        ld a,(hl)
        cp 0AAh
        jr nz,pt_none
        ld (hl),b
        ld a,1
        ret
pt_none:
        ld (hl),b
        xor a
        ret

; cga_detect: A = 1 when a CGA-1V is at C000h with MAP_CGA: the not displayed RAM keeps a pattern and the VBI
; request comes back after an acknowledgement (in plain RAM the written 80h would read back at once).
; Changes A, BC, HL.
cga_detect:
        ld a,MAP_CGA
        out (MAPREG),a
        ld hl,CGA_TEST
        call pattern_test
        or a
        jr z,cd_done
        xor a
        ld (cga_cfg),a
        ld b,2                  ; acknowledge; once more when a VBI came right then
cd_ack:
        ld a,CFG_ACK
        ld (CGA_CFG),a
        ld a,(CGA_CFG)
        and STAT_VBI
        jr z,cd_wait
        djnz cd_ack
        xor a                   ; the request stays: no CGA-1V
        jr cd_done
cd_wait:
        ld bc,4000              ; ~52 ms at 4 MHz, three frames
cd_loop:
        ld a,(CGA_CFG)
        and STAT_VBI
        jr nz,cd_found
        dec bc
        ld a,b
        or c
        jr nz,cd_loop
        jr cd_done              ; A = 0
cd_found:
        ld a,1
cd_done:
        push af
        ld a,MAP_CPM
        out (MAPREG),a
        pop af
        ret

; cga_start: EGA mode with the text palette and the colour bars on page A.
cga_start:
        call cga_init
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_test_bars
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; show_screen: the status screen on the AND-1V. Changes A, BC, DE, HL.
show_screen:
        call and_cls
        ld hl,scr_text
ss_line:
        ld d,(hl)               ; row, column, text; row FFh ends
        inc hl
        ld a,d
        inc a
        jr z,ss_cards
        ld e,(hl)
        inc hl
        call and_at
        call and_puts
        jr ss_line
ss_cards:
        ld de,3*256+10
        ld a,(has_cga)
        call show_yes_no
        ld de,4*256+10
        ld a,(has_mph)
        call show_yes_no
        ld de,5*256+10
        ld a,(has_dpi)
        call show_yes_no
        ld a,(has_dpi)
        or a
        jr z,ss_counts
        ld de,5*256+14
        call and_at
        ld hl,txt_firmware
        call and_puts
        ld a,(dpi_major)
        call and_dec8
        ld a,'.'
        call and_putc
        ld a,(dpi_minor)
        call and_dec8
ss_counts:
        jp show_counts

; show_yes_no: at D = row, E = column "ano" when A <> 0, else "neni".
show_yes_no:
        push af
        call and_at
        pop af
        ld hl,txt_yes
        or a
        jr nz,syn_put
        ld hl,txt_no
syn_put:
        jp and_puts

; show_counts: the counters of the VBI and of the MPH-1V tick (hex). Changes A, DE, HL.
show_counts:
        ld de,8*256+20
        call and_at
        ld hl,(vbi_count)
        call and_hex16
        ld de,9*256+20
        call and_at
        ld hl,(tick_count)
        jp and_hex16

; show_key: the code of the key in A (hex) and the character itself. Changes A, DE.
show_key:
        push af
        ld de,11*256+20
        call and_at
        pop af
        push af
        call and_hex8
        ld a,' '
        call and_putc
        pop af
        jp and_putc

; bdos_puts: the string at DE up to a 00h byte through the BDOS console output. Changes A, BC, DE.
bdos_puts:
        ld a,(de)
        or a
        ret z
        push de
        ld e,a
        ld c,B_CONOUT
        call BDOS
        pop de
        inc de
        jr bdos_puts

        include "kbd.asm"
        include "and.asm"
        include "cga.asm"
        include "mph.asm"
        include "dpi.asm"

; texts (ASCII only for now: row, column, text)
scr_text:
        defb 0,0,'SAPI-Term 0.1 - terminal pro BBS (vyvojova verze, faze 1)',0
        defb 2,0,'Karty v sestave:',0
        defb 3,2,'CGA-1V',0
        defb 4,2,'MPH-1V',0
        defb 5,2,'DPI-1L',0
        defb 8,2,'VBI CGA-1V:',0
        defb 9,2,'Tik MPH-1V 60 Hz:',0
        defb 11,2,'Posledni klavesa:',0
        defb 13,2,'Ctrl+] = konec, navrat do CP/M',0
        defb 0FFh
txt_yes:
        defb 'ano',0
txt_no:
        defb 'neni',0
txt_firmware:
        defb 'firmware ',0
msg_no_and:
        defb 'SAPI-Term: chybi karta AND-1V.',0Dh,0Ah,0

; variables
cpm_sp:         defw 0
saved_iff:      defb 0
has_and:        defb 0
has_cga:        defb 0
has_mph:        defb 0
has_dpi:        defb 0
dpi_major:      defb 0
dpi_minor:      defb 0
dpi_board:      defb 0
cga_cfg:        defb 0          ; CONFIG of the CGA-1V without the ACK bit
vbi_count:      defw 0
tick_count:     defw 0
and_ptr:        defw AND_VRAM
ad_lead:        defb 0          ; and_dec8: a digit was written
kb_head:        defb 0
kb_tail:        defb 0

PROGRAM_END:

; buffers after the program (not in the .COM)
BSS             equ (PROGRAM_END + 0FFh) & 0FF00h
kb_ring         equ BSS             ; 16 keys
STACK_TOP       equ BSS + 200h
BSS_END         equ STACK_TOP

        end start
