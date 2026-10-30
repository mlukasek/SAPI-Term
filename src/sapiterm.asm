; SAPI-Term - terminal for internet BBS (telnet) for the Tesla SAPI-1, set V, as a CP/M program SAPITERM.COM.
; Copyright (C) 2026 Martin Lukasek, GPLv3. Assembler pasmo 0.5.3 (build.cmd), docs in docs/.
;
; Phase 2: the terminal screen. Text 80x25 on the CGA-1V (own font 4x8, pairs of colours) or 64x20 on the
; AND-1V, the status on the other card, a test screen and typing on the keyboard (a local typewriter).
;
; Memory: the program, its data and the stack stay below C000h (MAP_CGA hides the RAM and CP/M above it). The
; whole program runs with interrupts disabled (an interrupt acknowledged with PC in the window of a video card
; freezes the JPR-1V). BDOS is called only with MAP_CPM.

        include "hw.inc"

        org 0100h

        jp start
        defb 0Dh,0Ah,'SAPI-Term 0.2',0Dh,0Ah,1Ah

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
        jr nz,st_cards
        ld a,(has_and)
        or a
        jr nz,st_cards
        ld de,t_no_and          ; no display at all: a message through BDOS, then back
        call bdos_puts
        jp quit
st_cards:
        ld a,(has_cga)
        or a
        call nz,cga_init
        ld a,(has_cga)          ; the terminal on the CGA-1V when there is one, the status on the AND-1V
        or a
        ld a,DEV_CGA
        jr nz,st_term
        ld a,DEV_AND
st_term:
        ld (term_dev),a
        xor a
        ld (stat_dev),a
        ld a,(has_cga)
        ld b,a
        ld a,(has_and)
        and b
        jr z,st_screens
        ld a,DEV_AND
        ld (stat_dev),a
st_screens:
        ld a,07h
        ld (cur_att),a
        ld a,(term_dev)
        call scr_init
        call test_screen
        call stat_screen
        call cur_restart

main_loop:
        call kbd_get
        jr nc,ml_idle
        push af
        call cur_hide
        pop af
        call handle_key
        call cur_restart
        call stat_update
        jr main_loop
ml_idle:
        call tick_poll
        call nz,cur_tick
        ld hl,(pal_dirty)       ; new pairs of colours go to the palette in the next VBI
        ld a,h
        or l
        jr z,main_loop
        ld a,MAP_CGA
        out (MAPREG),a
        call pal_flush
        ld a,MAP_CPM
        out (MAPREG),a
        call stat_update
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

; handle_key: the local typewriter. Changes all.
handle_key:
        ld (last_key),a
        cp K_MENU
        jp z,quit
        cp 09h                  ; Tab: swap the cards
        jp z,swap_cards
        cp 14h                  ; Ctrl+T: test screen
        jp z,test_screen
        cp 0Ch                  ; Ctrl+L: clear
        jp z,scr_cls
        cp 10h                  ; Ctrl+P: next foreground
        jp z,hk_fg
        cp 0Fh                  ; Ctrl+O: next background 0-7
        jp z,hk_bg
        cp 0Dh
        jp z,hk_enter
        cp 08h
        jp z,hk_left
        cp 05h                  ; EKL-1 arrows (WordStar)
        jp z,hk_up
        cp 18h
        jp z,hk_down
        cp 13h
        jp z,hk_left
        cp 04h
        jp z,hk_right
        cp 0C1h                 ; Consul 262.3 arrows
        jp z,hk_up
        cp 0C2h
        jp z,hk_down
        cp 0C4h
        jp z,hk_left
        cp 0C3h
        jp z,hk_right
        cp 0B0h                 ; Consul numeric keypad
        jp c,hk_text
        cp 0BAh
        jp nc,hk_text
        sub 0B0h-'0'
hk_text:
        cp ' '
        ret c
        cp 7Fh
        jp c,scr_putc           ; ASCII
        cp 0C0h
        ret c
        xor 20h                 ; EKL-1 Czech: KOI-8cs XOR 20h
        ld b,a
        ld a,EXT_KOI
        ld (cur_ext),a
        ld a,b
        call scr_putc
        xor a
        ld (cur_ext),a
        ret
hk_fg:
        ld a,(cur_att)
        ld b,a
        inc a
        and 0Fh
        ld c,a
        ld a,b
        and 0F0h
        or c
        ld (cur_att),a
        ret
hk_bg:
        ld a,(cur_att)
        add a,10h
        and 7Fh
        ld (cur_att),a
        ret
hk_enter:
        xor a
        ld (cur_col),a
        ld (wrap_pend),a
        jp scr_lf
hk_up:
        ld a,(cur_row)
        or a
        jr z,hk_nowrap
        dec a
        ld (cur_row),a
        jr hk_nowrap
hk_down:
        ld a,(term_rows)
        ld b,a
        ld a,(cur_row)
        inc a
        cp b
        jr nc,hk_nowrap
        ld (cur_row),a
        jr hk_nowrap
hk_left:
        ld a,(cur_col)
        or a
        jr z,hk_nowrap
        dec a
        ld (cur_col),a
        jr hk_nowrap
hk_right:
        ld a,(term_cols)
        ld b,a
        ld a,(cur_col)
        inc a
        cp b
        jr nc,hk_nowrap
        ld (cur_col),a
hk_nowrap:
        xor a
        ld (wrap_pend),a
        ret

; swap_cards: the terminal goes to the other card, the status to this one (only with both cards). The shadow
; keeps 80x25; the AND-1V shows its top left 64x20. Changes all.
swap_cards:
        ld a,(stat_dev)
        or a
        ret z
        ld b,a
        ld a,(term_dev)
        ld (stat_dev),a
        ld a,b
        ld (term_dev),a
        cp DEV_CGA
        ld a,SCR_COLS
        ld b,SCR_ROWS
        jr z,sw_size
        ld a,AND_COLS
        ld b,AND_ROWS
sw_size:
        ld (term_cols),a
        ld a,b
        ld (term_rows),a
        ld a,(cur_row)          ; a smaller screen keeps the rows up to the cursor (like a resized
        cp b                    ; terminal on a PC): the shadow moves up
        jr c,sw_col
        sub b
        inc a
        push bc
        call scr_shift
        pop bc
        ld a,b
        dec a
        ld (cur_row),a
sw_col:
        ld a,(term_cols)
        ld b,a
        ld a,(cur_col)
        cp b
        jr c,sw_draw
        ld a,b
        dec a
        ld (cur_col),a
sw_draw:
        xor a
        ld (wrap_pend),a
        call scr_redraw
        jp stat_screen

; tick_poll: NZ for a tick of 60 Hz: the MPH-1V counter, else the VBI of the CGA-1V, else every 1024 calls.
; Changes A, HL.
tick_poll:
        ld a,(has_mph)
        or a
        jp nz,mph_poll_tick
        ld a,(has_cga)
        or a
        jr z,tp_soft
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_poll_vbi
        ld a,MAP_CPM            ; ld and out keep the flags
        out (MAPREG),a
        ret
tp_soft:
        ld hl,(soft_ticks)
        inc hl
        ld (soft_ticks),hl
        ld a,l
        or a
        jr nz,tp_none
        ld a,h
        and 3
        jr nz,tp_none
        inc a                   ; NZ
        ret
tp_none:
        xor a
        ret

; test_screen: the test of the output on the terminal (fits 64x20). Changes all.
test_screen:
        ld a,07h
        ld (cur_att),a
        xor a
        ld (cur_ext),a
        call scr_cls
        ld a,0Fh
        ld de,0*256+0
        ld hl,t_test_title
        call ts_text
        ld b,0                  ; CP437: 8 rows of 32 characters, the first code in hex before them
ts_cp_row:
        ld a,b
        add a,2
        ld d,a
        ld e,0
        push bc
        call scr_at
        ld a,07h
        ld (cur_att),a
        pop bc
        push bc
        ld a,b
        rrca
        rrca
        rrca
        and 0E0h
        call ts_hex
        ld a,' '
        call scr_putc
        ld a,0Eh
        ld (cur_att),a
        pop bc
        push bc
        ld a,b
        rrca
        rrca
        rrca
        and 0E0h
        ld c,a
        ld b,32
ts_cp_char:
        push bc
        ld a,c
        call scr_putc
        pop bc
        inc c
        djnz ts_cp_char
        pop bc
        inc b
        ld a,b
        cp 8
        jr nz,ts_cp_row
        ld a,07h                ; foregrounds 0-F on black (0 on grey, to be seen)
        ld de,2*256+37
        ld hl,t_test_fg
        call ts_text
        ld de,3*256+37
        call scr_at
        ld c,0
ts_fg:
        ld a,c
        or a
        jr nz,ts_fg_att
        ld a,70h
ts_fg_att:
        ld (cur_att),a
        ld a,c
        push bc
        call ts_nibble
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,ts_fg
        ld a,07h                ; backgrounds 0-F with white (black on the bright ones)
        ld de,4*256+37
        ld hl,t_test_bg
        call ts_text
        ld de,5*256+37
        call scr_at
        ld c,0
ts_bg:
        ld a,c
        rlca
        rlca
        rlca
        rlca
        ld b,0Fh
        bit 3,c
        jr z,ts_bg_att
        ld b,00h
ts_bg_att:
        or b
        ld (cur_att),a
        ld a,c
        push bc
        call ts_nibble
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,ts_bg
        ld a,07h
        ld de,7*256+37
        ld hl,t_test_blocks
        call ts_text
        ld de,8*256+37
        call scr_at
        ld hl,ts_blocks
        ld a,0Eh
        call ts_codes
        ld de,9*256+37          ; full blocks in the 16 colours
        call scr_at
        ld c,0
ts_colours:
        ld a,c
        ld (cur_att),a
        push bc
        ld a,0DBh
        call scr_putc
        pop bc
        inc c
        ld a,c
        cp 16
        jr nz,ts_colours
        ld hl,ts_frames         ; frames: double and single
        ld a,0Bh
        call ts_codes_at
        ld a,0Fh
        ld de,12*256+2
        ld hl,t_test_double
        call ts_text
        ld a,0Fh
        ld de,12*256+34
        ld hl,t_test_single
        call ts_text
        ld a,0Bh
        ld de,16*256+0
        ld hl,t_cz_lower
        call ts_text
        ld a,0Bh
        ld de,17*256+0
        ld hl,t_cz_upper
        call ts_text
        ld a,0Ah
        ld de,18*256+0
        ld hl,t_test_help
        call ts_text
        ld a,07h
        ld (cur_att),a
        ld de,19*256+0
        jp scr_at

; ts_text: KOI text HL at D, E with the attribute A.
ts_text:
        ld (cur_att),a
        push hl
        call scr_at
        pop hl
        jp scr_puts_koi

; ts_hex: A as two hex digits. ts_nibble: A & 0Fh as one.
ts_hex:
        push af
        rrca
        rrca
        rrca
        rrca
        call ts_nibble
        pop af
ts_nibble:
        and 0Fh
        add a,90h
        daa
        adc a,40h
        daa
        jp scr_putc

; ts_codes: CP437 codes at HL up to FFh with the attribute A.
ts_codes:
        ld (cur_att),a
tc_loop:
        ld a,(hl)
        inc hl
        cp 0FFh
        ret z
        push hl
        call scr_putc
        pop hl
        jr tc_loop

; ts_codes_at: lines "row, column, codes..., FFh", the list ends with FFh; attribute A.
ts_codes_at:
        ld (cur_att),a
tca_line:
        ld a,(hl)
        cp 0FFh
        ret z
        ld d,a
        inc hl
        ld e,(hl)
        inc hl
        push hl
        call scr_at
        pop hl
        call tc_loop
        jr tca_line

; stat_screen: the status card. Changes all.
stat_screen:
        ld a,(stat_dev)
        or a
        ret z
        call stat_cls
        ld de,0*256+0
        ld hl,t_title
        call ss_text
        ld de,2*256+0
        ld hl,t_terminal
        call ss_text
        ld de,2*256+14
        ld hl,t_cga_size
        ld a,(term_dev)
        cp DEV_CGA
        jr z,sst_term
        ld hl,t_and_size
sst_term:
        call ss_text
        ld de,4*256+0
        ld hl,t_cards
        call ss_text
        ld de,5*256+2
        ld hl,txt_cga
        ld a,(has_cga)
        call ss_card
        ld de,6*256+2
        ld hl,txt_and
        ld a,(has_and)
        call ss_card
        ld de,7*256+2
        ld hl,txt_mph
        ld a,(has_mph)
        call ss_card
        ld de,8*256+2
        ld hl,txt_dpi
        ld a,(has_dpi)
        call ss_card
        ld a,(has_dpi)
        or a
        jr z,sst_keys
        ld hl,t_firmware
        call stat_puts
        ld a,' '
        call stat_putc
        ld a,(dpi_major)
        call stat_dec8
        ld a,'.'
        call stat_putc
        ld a,(dpi_minor)
        call stat_dec8
sst_keys:
        ld de,10*256+0
        ld hl,t_pairs
        call ss_text
        ld de,11*256+0
        ld hl,t_last_key
        call ss_text
        ld de,13*256+0
        ld hl,t_keys
        call ss_text
        ld de,14*256+2
        ld hl,t_key1
        call ss_text
        ld de,15*256+2
        ld hl,t_key2
        call ss_text
        ld de,16*256+2
        ld hl,t_key3
        call ss_text
        ld de,17*256+2
        ld hl,t_key4
        call ss_text
        ld de,18*256+2
        ld hl,t_key5
        call ss_text
; stat_update: the changing values: pairs of colours in use, the last key.
stat_update:
        ld a,(stat_dev)
        or a
        ret z
        ld de,10*256+23
        call stat_at
        ld a,(term_dev)
        cp DEV_CGA
        ld a,0
        call z,pair_used
        call stat_dec8
        ld hl,txt_of16
        call stat_puts
        ld de,11*256+23
        call stat_at
        ld a,(last_key)
        jp stat_hex8

ss_text:
        call stat_at
        jp stat_puts

; ss_card: name HL at D, E, then "ano" when A <> 0, else "není".
ss_card:
        push af
        call ss_text
        ld a,' '
        call stat_putc
        call stat_putc
        pop af
        ld hl,t_yes
        or a
        jr nz,ssc_put
        ld hl,t_no
ssc_put:
        call stat_puts
        ld a,' '
        jp stat_putc

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
        include "cgatext.asm"
        include "screen.asm"
        include "mph.asm"
        include "dpi.asm"

; test screen data (CP437 codes)
ts_blocks:
        defb 0B0h,0B1h,0B2h,0DBh,0DFh,0DCh,0DDh,0DEh,' ',18h,19h,1Ah,1Bh,1Dh,12h,' '
        defb 01h,02h,03h,04h,05h,06h,0Eh,0Fh,0FFh
ts_frames:
        defb 11,0,0C9h
        rept 28
        defb 0CDh
        endm
        defb 0BBh,0FFh
        defb 12,0,0BAh,0FFh, 12,29,0BAh,0FFh
        defb 13,0,0CCh
        rept 13
        defb 0CDh
        endm
        defb 0CBh
        rept 14
        defb 0CDh
        endm
        defb 0B9h,0FFh
        defb 14,0,0C8h
        rept 13
        defb 0CDh
        endm
        defb 0CAh
        rept 14
        defb 0CDh
        endm
        defb 0BCh,0FFh
        defb 11,32,0DAh
        rept 28
        defb 0C4h
        endm
        defb 0BFh,0FFh
        defb 12,32,0B3h,0FFh, 12,61,0B3h,0FFh
        defb 13,32,0C3h
        rept 13
        defb 0C4h
        endm
        defb 0C2h
        rept 14
        defb 0C4h
        endm
        defb 0B4h,0FFh
        defb 14,32,0C0h
        rept 13
        defb 0C4h
        endm
        defb 0C1h
        rept 14
        defb 0C4h
        endm
        defb 0D9h,0FFh
        defb 0FFh

txt_cga:        defb 'CGA-1V',0
txt_and:        defb 'AND-1V',0
txt_mph:        defb 'MPH-1V',0
txt_dpi:        defb 'DPI-1L',0
txt_of16:       defb ' / 16 ',0

        include "../build/texts.inc"

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
and_ptr:        defw AND_VRAM
ad_lead:        defb 0          ; and_dec8, stat_dec8: a digit was written
kb_head:        defb 0
kb_tail:        defb 0
last_key:       defb 0
soft_ticks:     defw 0
term_dev:       defb 0          ; DEV_CGA or DEV_AND
stat_dev:       defb 0          ; the other card, or 0
term_cols:      defb SCR_COLS
term_rows:      defb SCR_ROWS
cur_row:        defb 0
cur_col:        defb 0
cur_att:        defb 07h
cur_ext:        defb 0
wrap_pend:      defb 0
view_x:         defb 0
view_y:         defb 0
cur_vis:        defb 0          ; the cursor is drawn
cur_phase:      defb 0          ; blink phase: 1 = visible
cur_ticks:      defb 0
cur_drow:       defb 0          ; where the drawn cursor is
cur_dcol:       defb 0
stat_row:       defb 0
stat_col:       defb 0
stat_att:       defb 07h
ss_chr:         defb 0          ; scr_set, scr_draw_cell
ss_att:         defb 0
ss_ext:         defb 0
ss_old:         defb 0
sl_off:         defw 0          ; scr_scroll, scr_shift
sh_count:       defb 0          ; scr_shift
ar_ptr:         defw 0          ; and_render
cf_byte:        defb 0          ; cga_fill_rows, cga_scroll
cf_count:       defb 0
pal_dirty:      defw 0          ; slots whose pair must go to the palette
pn_best:        defw 0          ; pair_nearest
pn_slot:        defb 0
ps_rgb:         defs 6          ; pal_slot

; font and tables, page aligned
        defs (256 - ($ & 0FFh)) & 0FFh
        include "../build/font4x8.inc"
        include "../build/tables.inc"

PROGRAM_END:

; buffers after the program (not in the .COM)
BSS             equ (PROGRAM_END + 0FFh) & 0FF00h
att_slot        equ BSS                         ; 256: slot of each attribute (FFh = none), page aligned
scr_chr         equ att_slot + 256              ; shadow: characters
scr_att         equ scr_chr + SCR_COLS*SCR_ROWS ; attributes
scr_ext         equ scr_att + SCR_COLS*SCR_ROWS ; flags
row_off         equ scr_ext + SCR_COLS*SCR_ROWS ; 25 words: offset of each screen row
kb_ring         equ row_off + 2*SCR_ROWS        ; 16 keys
slot_att        equ kb_ring + 16                ; 16: attribute of each slot
slot_ref        equ slot_att + 16               ; 16 words: cells using each slot
STACK_TOP       equ slot_ref + 32 + 256
BSS_END         equ STACK_TOP

        end start
