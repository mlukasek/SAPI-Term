; SAPI-Term - terminal for internet BBS (telnet) for the Tesla SAPI-1, set V, as a CP/M program SAPITERM.COM.
; Copyright (C) 2026 Martin Lukasek, GPLv3. Assembler pasmo 0.5.3 (build.cmd), docs in docs/.
;
; Phase 8: the terminal for BBS. Text 80x25 on the CGA-1V (own font 4x8, pairs of colours per domain) or 64x20
; on the AND-1V, the status on the other card, ANSI-BBS and VT100, telnet through the DPI-1L. Settings and the
; address book in SAPITERM.CFG next to SAPITERM.COM (config.asm).
;   SAPITERM               asks for the address of a BBS or its number in the book (empty: the test screen and
;                          a local typewriter)
;   SAPITERM HOST[:PORT]   connects to the BBS (port 23 when none)
;   SAPITERM NUMBER        connects to that BBS of the book
;   SAPITERM FILE.ANS      shows an ANSI file (iCE colours from its SAUCE record), then the typewriter
; Ctrl+] is the menu on line, else it quits.
;
; Memory: the program, its data and the stack stay below C000h (MAP_CGA hides the RAM and CP/M above it). The
; whole program runs with interrupts disabled (an interrupt acknowledged with PC in the window of a video card
; freezes the JPR-1V). BDOS is called only with MAP_CPM.

        include "hw.inc"

        org 0100h

        jp start
        defb 0Dh,0Ah,'SAPI-Term 0.8',0Dh,0Ah,1Ah

; zero buffers up to 0200h, then the fonts and the tables aligned to pages: here before the code their padding
; does not change with the size of the code (only 72 B between font_ata.inc and tables.inc; check_build.py)
msg_buf:        defs 64         ; a message made up (xm_run, xm_progress)
cfg_fcb:        defs 36
log_fcb:        defs 36
xm_fcb:         defs 36
ans_reply:      defs 20
        defs (256 - ($ & 0FFh)) & 0FFh
        include "../build/font4x8.inc"
        include "../build/font_pet.inc"
        include "../build/font_ata.inc"
        defs (256 - ($ & 0FFh)) & 0FFh
        include "../build/tables.inc"
        include "../build/font_mz.inc"

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
        call cfg_find_drive     ; while the CCP still has the command line
        call kbd_init
        call detect
        call tpa_check          ; the buffers from C000h below the BDOS (before cfg_load writes there)
        call cfg_load           ; settings and the address book (DMA not at 0080h: the arguments stay)
        call hist_init
        ld a,(has_cga)
        or a
        jr nz,st_cards
        ld a,(has_and)
        or a
        jr nz,st_cards
        ld de,t_no_and          ; no display at all: a message through BDOS, then back
        jp quit_say
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
        ld a,(cfg_term)         ; SCREEN=AND: the terminal on the AND-1V
        or a
        jr z,st_screens
        ld a,DEV_CGA
        ld (stat_dev),a
        ld a,DEV_AND
        ld (term_dev),a
st_screens:
        ld a,07h
        ld (cur_att),a
        ld a,(term_dev)
        call scr_init
        call ansi_reset
        ld a,(CMD_TAIL)
        or a
        jr z,st_prompt
        ld de,FCB               ; an existing file is shown, anything else is the address of a BBS
        ld c,B_OPEN
        call BDOS
        inc a
        jr z,st_address
        ld a,MODE_VIEW
        ld (mode),a
        call stat_screen
        call view_file
        call stat_screen
        jr st_main
st_address:
        call tail_to_line
        ld hl,ui_line           ; a number: the BBS from the book
        call parse_num
        jr c,st_net
        call book_pick
        jr nc,st_net
        ld hl,t_no_number
        ld (ui_msg),hl
        jr st_prompt
st_net:
        ld a,(has_dpi)
        or a
        jr z,st_prompt
st_online:
        call online
st_prompt:
        xor a
        ld (test_on),a
        call ui_prompt
        cp 2
        jp z,quit
        cp 1
        jr nz,st_online
st_test:
        xor a
        ld (mode),a
        inc a
        ld (test_on),a
        call test_screen
        call stat_screen
st_main:
        call cur_restart

main_loop:
        call kbd_get
        jr nc,ml_idle
        push af
        call cur_hide
        pop af
        call handle_key
        call cur_restart
        ld a,1                  ; the status follows when idle
        ld (stat_dirty),a
        jr main_loop
ml_idle:
        call tick_poll
        jr z,ml_flush
        call cur_tick
        ld a,(stat_dirty)       ; the status is updated in a quiet tick, not after every key
        or a
        jr z,ml_flush
        xor a
        ld (stat_dirty),a
        call stat_update
ml_flush:
        call pal_pending        ; new pairs of colours go to the palette in the next VBI
        jr z,main_loop
        call scr_flush
        call stat_update
        jr main_loop

; pal_pending: NZ when some pairs of colours wait for the palette. Changes A, B, HL.
pal_pending:
        ld hl,pal_dirty
        ld b,DOMAINS*2
        xor a
pp_loop:
        or (hl)
        inc hl
        djnz pp_loop
        or a
        ret

; view_file: the file named on the command line (FCB 005Ch from the CCP) through the ANSI terminal, up to its
; end or 1Ah (SAUCE follows); a key stops it, Ctrl+] ends the program. The SAUCE record (in the last two
; records of 128 bytes) switches the iCE colours on. Records are read at random by number. Changes all.
view_file:
        ld de,rec_buf
        ld c,B_SETDMA
        call BDOS
        ld de,FCB
        ld c,B_OPEN
        call BDOS
        inc a
        jr nz,vf_open
        ld a,2                  ; no such file
        ld (view_state),a
        ret
vf_open:
        ld de,FCB
        ld c,B_SIZE
        call BDOS
        ld hl,(FCB+FCB_R0)
        ld (vf_size),hl
        call view_sauce
        ld hl,0
        ld (vf_rec),hl
        xor a
        ld (vf_eof),a
        call js_by_speed        ; the input is buffered: jump scroll can look ahead (at full speed)
vf_fill:                        ; up to IN_RECORDS records into in_buf
        ld hl,in_buf
        ld (in_ptr),hl
        ld (in_end),hl
        ld a,IN_RECORDS
        ld (vf_count),a
vf_read:
        ld hl,(vf_rec)
        ld de,(vf_size)
        or a
        sbc hl,de
        jr nc,vf_feed
        ld de,(in_end)
        call read_record
        jr nz,vf_feed
        ld hl,(in_end)
        ld de,128
        add hl,de
        ld (in_end),hl
        ld hl,(vf_rec)
        inc hl
        ld (vf_rec),hl
        ld a,(vf_count)
        dec a
        ld (vf_count),a
        jr nz,vf_read
vf_feed:
        ld a,(speed)
        or a
        jr nz,vf_paced
vf_fast:
        ld hl,(in_ptr)
        ld de,(in_end)
        ld a,l
        cp e
        jr nz,vf_byte
        ld a,h
        cp d
        jr z,vf_more
vf_byte:
        ld a,(hl)
        cp 1Ah
        jr z,vf_end
        inc hl
        ld (in_ptr),hl
        call ansi_putc
        jr vf_fast
vf_paced:                       ; the speed of the line: the bytes in their time, a key stops the file
        call vf_cut_eof
        call pace_reset
vp_tick:
        ld hl,(in_ptr)
        ld de,(in_end)
        or a
        sbc hl,de
        jr z,vp_done
        call kbd_get
        jr c,vp_key
        call pace_due
        or a
        jr z,vp_tick
        call pace_feed
        call pal_pending
        call nz,scr_flush
        jr vp_tick
vp_key:
        cp K_MENU
        jp z,quit
        jr vf_end
vp_done:
        ld a,(vf_eof)
        or a
        jr nz,vf_end
        ld de,(in_end)
vf_more:
        ld hl,in_buf            ; nothing read: the end of the file
        or a
        sbc hl,de
        jr z,vf_end
        call scr_flush
        call kbd_get
        jp nc,vf_fill
        cp K_MENU
        jp z,quit
vf_end:
        xor a
        ld (js_enable),a
        call scr_flush
        ld a,1                  ; shown
        ld (view_state),a
        ret

; vf_cut_eof: in_end at the first 1Ah from in_ptr (the end of the art, SAUCE follows), vf_eof = 1 then.
; Changes A, DE, HL.
vf_cut_eof:
        ld hl,(in_ptr)
        ld de,(in_end)
vce_loop:
        ld a,l
        cp e
        jr nz,vce_byte
        ld a,h
        cp d
        ret z
vce_byte:
        ld a,(hl)
        cp 1Ah
        jr z,vce_found
        inc hl
        jr vce_loop
vce_found:
        ld (in_end),hl
        ld a,1
        ld (vf_eof),a
        ret

; read_record: record vf_rec of the file to DE (128 bytes). NZ when it cannot be read. Changes all.
read_record:
        ld c,B_SETDMA
        call BDOS
        ld hl,(vf_rec)
        ld (FCB+FCB_R0),hl
        xor a
        ld (FCB+FCB_R0+2),a
        ld de,FCB
        ld c,B_READRAND
        call BDOS
        or a
        ret

; view_sauce: ice_mode = 1 when the SAUCE record at the end of the file has the iCE flag (TFlags bit 0).
; Changes all.
view_sauce:
        xor a
        ld (ice_mode),a
        ld hl,(vf_size)
        ld a,h
        or a
        jr nz,vs_two
        ld a,l
        cp 2
        ret c                   ; under 2 records: no room for SAUCE after the art
vs_two:
        dec hl
        dec hl
        ld (vf_rec),hl
        ld de,sauce_buf
        call read_record
        ret nz
        ld hl,(vf_rec)
        inc hl
        ld (vf_rec),hl
        ld de,sauce_buf+128
        call read_record
        ret nz
        ld hl,sauce_buf         ; "SAUCE00" at 0 .. 128 (the record ends at the end of the file)
        ld b,129
vs_find:
        push bc
        push hl
        ld de,txt_sauce
        ld b,7
vs_cmp:
        ld a,(de)
        cp (hl)
        jr nz,vs_no
        inc de
        inc hl
        djnz vs_cmp
        pop hl
        pop bc
        ld de,105               ; TFlags
        add hl,de
        ld a,(hl)
        and 1
        ld (ice_mode),a
        ld a,1
        ld (has_sauce),a
        ret
vs_no:
        pop hl
        pop bc
        inc hl
        djnz vs_find
        ret

txt_sauce:
        defb 'SAUCE00'

; quit: cards to a quiet state, MAP_CPM, the console cleared, interrupts as they were, warm boot.
; quit_say: quit with the KOI text DE on the console of CP/M, written after it is cleared.
quit_say:
        ld (quit_text),de
quit:
        ld sp,STACK_TOP
        ld a,MAP_CPM
        out (MAPREG),a
        call log_stop
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
        ld de,(quit_text)
        ld a,d
        or e
        jr z,q_iff
        call bdos_puts
        ld de,txt_crlf
        call bdos_puts
q_iff:
        ld a,(saved_iff)
        or a
        jr z,q_boot
        ei
q_boot:
        jp WBOOT

; hk_menu: Ctrl+] of the typewriter: the test screen goes back to the start screen (the stack as at the start),
; after a file shown SAPI-Term ends.
hk_menu:
        ld a,(test_on)
        or a
        jp z,quit
        ld sp,STACK_TOP
        jp st_prompt

; handle_key: the local typewriter. Changes all.
handle_key:
        cp K_MENU
        jp z,hk_menu
        cp 09h                  ; Tab: swap the cards
        jp z,swap_cards
        cp 12h                  ; PgUp of the EKL-1 (Ctrl+R): the history
        jp z,hist_view
        cp 14h                  ; Ctrl+T: test screen
        jp z,test_screen
        cp 07h                  ; Ctrl+G: the bell (a tone of the MPH-1V, without it nothing)
        jp z,mph_bell
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
        ld b,a
        ld a,(kbd_type)
        or a
        ld a,b
        jr z,hk_text            ; EKL-1: C0-FF are Czech letters
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
        jp scr_putc_koi
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
        jp term_resize

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
        ld a,07h                ; backgrounds 0-F with white (black on the bright ones); every domain
                                ; of the test screen has at most 16 pairs
        ld de,4*256+37
        ld hl,t_test_bg
        call ts_text
        ld de,5*256+37
        call scr_at
        ld c,0
ts_bg:
        ld a,c
        or a
        ld b,07h                ; 0 grey on black (the blank cells have it too: 16 pairs per domain)
        jr z,ts_bg_att
        ld b,0Fh
        bit 3,c
        jr z,ts_bg_att
        ld b,00h
ts_bg_att:
        ld a,c
        rlca
        rlca
        rlca
        rlca
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
        ld a,(cga_wide)
        or a
        jr z,sst_80
        ld hl,t_cga_size40
sst_80:
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
        ld a,(mode)
        cp MODE_ONLINE
        jp z,sst_online
        cp MODE_VIEW
        jr nz,sst_pairs
        ld de,10*256+0          ; the file: name, iCE, state
        ld hl,t_file
        call ss_text
        ld hl,FCB+1
        ld b,8
        call ss_name
        ld a,'.'
        call stat_putc
        ld b,3
        call ss_name
        ld hl,t_ice
        call stat_puts
        ld hl,t_yes
        ld a,(ice_mode)
        or a
        jr nz,sst_ice
        ld hl,t_no
sst_ice:
        call stat_puts
        ld de,9*256+0
        call stat_at
        ld hl,t_viewing
        ld a,(view_state)
        or a
        jr z,sst_view
        ld hl,t_shown
        dec a
        jr z,sst_view
        ld hl,t_not_found
sst_view:
        call stat_puts
        ld de,13*256+0
        ld hl,t_speed
        call ss_text
        ld de,13*256+23
        call stat_at
        call show_speed
sst_pairs:
        ld de,14*256+0
        ld hl,t_keys
        call ss_text
        ld de,15*256+2
        ld hl,t_key1
        call ss_text
        ld de,16*256+2
        ld hl,t_key2
        call ss_text
        ld de,17*256+2
        ld hl,t_key3
        call ss_text
        ld de,18*256+2
        ld hl,t_key4
        call ss_text
        ld de,19*256+2
        ld hl,t_key5
        ld a,(test_on)
        or a
        jr z,sst_key5
        ld hl,t_key5_test
sst_key5:
        call ss_text
        jp stat_update
sst_online:                     ; on line: the BBS, protocol, time and data (stat_update), set, speed, log, keys
        ld de,10*256+0
        ld hl,t_bbs
        call ss_text
        ld hl,net_host
        call stat_puts
        ld a,':'
        call stat_putc
        ld hl,(net_port)
        call stat_dec16
        ld de,11*256+0
        ld hl,t_proto
        call ss_text
        ld de,11*256+23
        call stat_at
        ld hl,t_proto_telnet
        ld a,(tn_raw)
        or a
        jr z,sst_proto
        ld hl,t_proto_raw
sst_proto:
        call stat_puts
        ld de,12*256+0
        ld hl,t_conn_time
        call ss_text
        ld de,13*256+0
        ld hl,t_received
        call ss_text
        ld de,14*256+0
        ld hl,t_charset
        call ss_text
        ld de,14*256+23
        call stat_at
        call show_cs
        ld de,15*256+0
        ld hl,t_speed
        call ss_text
        ld de,15*256+23
        call stat_at
        call show_speed
        ld de,16*256+0
        ld hl,t_log
        call ss_text
        ld de,16*256+23
        call stat_at
        call show_log
        ld de,17*256+0
        ld hl,t_keys
        call ss_text
        ld de,18*256+2
        ld hl,t_okey1
        call ss_text
        ld de,19*256+2
        ld hl,t_okey2
        call ss_text
        call show_kbd
        jr stat_update

; stat_dec16: HL in decimal without leading zeros. Changes A, BC, DE, HL.
stat_dec16:
        ld de,10000
        xor a
        ld (ad_lead),a
        call sd16_digit
        ld de,1000
        call sd16_digit
        ld de,100
        call sd16_digit
        ld de,10
        call sd16_digit
        ld a,l
        add a,'0'
        jp stat_putc
sd16_digit:
        ld b,'0'-1
sd16_sub:
        inc b
        or a
        sbc hl,de
        jr nc,sd16_sub
        add hl,de
        ld a,b
        cp '0'
        jr nz,sd16_put
        ld a,(ad_lead)
        or a
        ret z
        ld a,'0'
sd16_put:
        call stat_putc
        ld a,1
        ld (ad_lead),a
        ret

; stat_update: the changing values: pairs of colours in use, the last key.
stat_update:
        ld a,(stat_dev)
        or a
        ret z
        ld a,(mode)
        cp MODE_ONLINE
        ret nz
        ld de,12*256+23         ; the time on line h:mm:ss
        call stat_at
        ld a,(ol_hours)
        call stat_dec8
        ld a,':'
        call stat_putc
        ld a,(ol_mins)
        call stat_dec2
        ld a,':'
        call stat_putc
        ld a,(ol_secs)
        call stat_dec2
        ld de,13*256+23         ; received: KB (the total >> 10), KB/s of the last second with one decimal
        call stat_at
        ld hl,(rx_total+1)
        ld a,(rx_total+3)
        srl a
        rr h
        rr l
        srl a
        rr h
        rr l
        call stat_dec16
        ld hl,t_kb
        call stat_puts
        ld hl,(ol_rate)
        push hl
        ld a,h
        rrca
        rrca
        and 3Fh
        call stat_dec8
        ld a,','
        call stat_putc
        pop hl
        ld a,h                  ; the tenths: (rate & 3FFh) * 10 >> 10
        and 3
        ld h,a
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld a,h
        rrca
        rrca
        and 3Fh
        add a,'0'
        call stat_putc
        ld hl,t_kbs
        call stat_puts
        ld b,3                  ; a shorter number leaves nothing behind
su_pad:
        ld a,' '
        call stat_putc
        djnz su_pad
        ret

ss_text:
        call stat_at
        jp stat_puts

; ss_name: B characters of a CP/M name at HL without the spaces (bit 7 cleared). Changes A, B, HL.
ss_name:
        ld a,(hl)
        inc hl
        and 7Fh
        cp ' '
        call nz,stat_putc
        djnz ss_name
        ret

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

; tail_to_line: the arguments of the command line (CP/M made them capitals) to ui_line without spaces.
; Changes A, B, DE, HL.
tail_to_line:
        ld hl,CMD_TAIL
        ld b,(hl)
        inc hl
        ld de,ui_line
        xor a
        ld (ui_len),a
ttl_char:
        ld a,b
        or a
        jr z,ttl_end
        dec b
        ld a,(hl)
        inc hl
        cp ' '+1
        jr c,ttl_char
        ld (de),a
        inc de
        ld a,(ui_len)
        inc a
        ld (ui_len),a
        cp LINE_MAX
        jr c,ttl_char
ttl_end:
        xor a
        ld (de),a
        ret

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
; tpa_check: tpa_top = the page of the entry of the BDOS (its address at 0006h: builds of CP/M differ, a resident
; extension lowers it); the buffers from C000h, and without a CGA-1V HIST_MIN rows of history, must end below that
; page. Else a message and back to CP/M (the CCP below the BDOS may be overwritten: the warm boot loads it again).
; Changes all.
HIST_MIN        equ 4
tpa_check:
        ld a,(0007h)
        ld (tpa_top),a
        ld hl,hist_buf - 1      ; the last byte used: with a CGA-1V the history is on the card
        ld a,(has_cga)
        or a
        jr nz,tc_need
        ld hl,hist_buf + HIST_MIN*HIST_REC - 1
tc_need:
        ld a,(tpa_top)
        cp h
        jr z,tc_short
        ret nc
tc_short:
        ld de,t_no_tpa
        jp quit_say

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
        include "ansi.asm"
        include "telnet.asm"
        include "online.asm"
        include "config.asm"
        include "charset.asm"
        include "xfer.asm"
        include "history.asm"
        include "pet.asm"
        include "ata.asm"
        include "vdt.asm"
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
sl_off:         defw 0          ; scr_region_up/down, scr_shift
sh_count:       defb 0          ; scr_shift
reg_top:        defb 0          ; scroll region
reg_bot:        defb SCR_ROWS-1
rg_top:         defb 0          ; scr_region_up/down
rg_bot:         defb 0
wrap_off:       defb 0          ; ?7l: no wrap at the last column
cur_off:        defb 0          ; ?25l: no cursor
sb_off:         defw 0          ; scr_blank
sb_n:           defb 0
sc_dom:         defb 0          ; cga_cls_att
sc_slot:        defb 0
sc_att:         defb 0
nr_row:         defb 0          ; new_row, scr_erase
nr_slot:        defb 0
er_n:           defb 0          ; scr_erase
ic_n:           defb 0          ; scr_insert_chars, scr_delete_chars
ic_len:         defb 0
ic_from:        defb 0
ic_to:          defb 0
cm_count:       defb 0          ; cga_move_cells
cm_src:         defb 0
cm_dst:         defb 0
cm_lines:       defb 0
pair_dom:       defb 0          ; pairs: the domain and its tables
pd_page:        defb 0
pd_satt:        defw 0
pd_sref:        defw 0
pm_from:        defb 0          ; pair_move_row
pm_to:          defb 0
pm_changed:     defb 0
pm_att:         defb 0
pm_n:           defb 0
pm_old:         defb 0
pm_new:         defb 0
pm_left:        defb 0
pm_ptr:         defw 0
pm_dst:         defw 0
ans_state:      defb 0          ; ANSI parser
ans_np:         defb 0
ans_priv:       defb 0
ans_inter:      defb 0
ans_par:        defs ANS_PARAMS
ans_pp:         defw 0          ; the current parameter (ans_par + ans_np)
sgr_fg:         defb 7          ; SGR state: ANSI colours, flags (SGR_SIZE bytes)
sgr_bg:         defb 0
sgr_bold:       defb 0
sgr_blink:      defb 0
sgr_rev:        defb 0
sgr_bghi:       defb 0
SGR_SIZE        equ 6
sv_row:         defb 0          ; saved cursor (ESC 7, CSI s)
sv_col:         defb 0
sv_sgr:         defs SGR_SIZE
ice_mode:       defb 0          ; blink = bright background
blink_on:       defb 1          ; blinking text shown (blink_tick)
blink_ticks:    defb 0
reply_hook:     defw 0          ; where answers to the BBS go (0 = nowhere)
view_state:     defb 0          ; 0 being shown, 1 shown, 2 no such file
has_sauce:      defb 0
vf_size:        defw 0          ; view_file: records of the file
vf_rec:         defw 0
vf_count:       defb 0
in_ptr:         defw 0          ; input buffer: next byte, end
in_end:         defw 0
js_enable:      defb 0          ; jump scroll: the input is in in_buf
js_pending:     defb 0          ; rows of a jump scroll the cursor did not enter yet
js_att:         defb 0          ; the attribute they were blanked with
rg_k:           defb 1          ; scr_region_upk: rows
ru_left:        defb 0
ru_lastrow:     defb 0
pm_col:         defb 0          ; pair_move_row
pf_budget:      defb 0          ; pal_flush: pairs left in this VBI
stat_dirty:     defb 0          ; the status card waits for an update
mode:           defb 0          ; MODE_LOCAL, MODE_VIEW, MODE_ONLINE
kbd_type:       defb 0          ; 0 EKL-1, 1 Consul 262.3
ui_len:         defb 0          ; the typed address
ui_line:        defs LINE_MAX+1
ui_msg:         defw 0          ; how the last connection ended (KOI text, 0 none)
net_host:       defs LINE_MAX+1
net_port:       defw 23
net_ip:         defs 4
net_wait:       defw 0          ; ticks left
net_st:         defs 10         ; TCPSTATUS
dpi_st:         defs 4          ; status of the card
dpi_res:        defs 5          ; DNSRES
rx_chunks:      defb 0
ol_idle:        defb 0          ; ticks without data
tn_state:       defb 0          ; telnet
tn_verb:        defb 0
tn_sb_len:      defb 0
tn_sb_buf:      defs TN_SB_MAX
tn_us:          defs TN_OPTS    ; options we do (agreed)
tn_them:        defs TN_OPTS    ; options the server does (agreed)
tx_len:         defb 0
tx_tries:       defb 0
tx_buf:         defs TX_SIZE
ar_ptr:         defw 0          ; and_render
cf_byte:        defb 0          ; cga_fill_rows, cga_scroll
cf_count:       defb 0
pal_dirty:      defs 2*DOMAINS  ; per domain: slots whose pair must go to the palette
pn_best:        defw 0          ; pair_nearest
near_n:         defs DOMAINS    ; per domain: attributes on the nearest pair (pair_unmap)
pn_slot:        defb 0
ps_rgb:         defs 6          ; pal_slot
om_msg:         defw 0          ; ol_menu: what the last choice did (KOI text, 0 none)
om_stat:        defb 0          ; ol_menu: the status card (stat_dev) while the menu is on the terminal card
om_save:        defb 0          ; ol_menu: a setting changed, to be saved when the menu closes
tpa_top:        defb 0          ; tpa_check: the first page of the BDOS (nothing written from there on)
test_on:        defb 0          ; the test screen from the start screen: Ctrl+] goes back there
quit_text:      defw 0          ; quit_say: the message for the console of CP/M (0 none)
txt_crlf:       defb 0Dh,0Ah,0
stat_new:       defb 0          ; stat_putc: a new pair of colours, the palette follows
srd_off:        defw 0          ; scr_redraw: the offset of the cell in the shadow
clk_t0:         defw 0          ; ol_clock: the MPH-1V counter 0 at the last call
rx_total:       defs 4          ; on line: bytes of data received (from here OL_STATS bytes cleared at the start)
rx_last:        defw 0          ; rx_total at the last second (low word)
ol_rate:        defw 0          ; bytes received in the last second
ol_secs:        defb 0          ; the time on line: seconds, minutes, hours (in this order)
ol_mins:        defb 0
ol_hours:       defb 0
clk_acc:        defw 0          ; ol_clock: eighths of the counts of the MPH-1V in this second
ol_ticks:       defb 0          ; without the MPH-1V: the quiet ticks of this second
rtc_ok:         defb 0          ; without the MPH-1V: the time on line from the RTC of the DPI-1L
rtc_due:        defb 0          ; read the RTC at the next ol_clock
rtc_rx:         defw 0          ; rx_total at the last reading of the RTC
rate_ring:      defs 2*RATE_SECS ; bytes received in each of the last seconds (rate_push)
rate_pos:       defb 0          ; the next of them
rate_n:         defb 0          ; seconds in the ring so far
OL_STATS        equ $-rx_total
rtc_now:        defs 3          ; the RTC of the DPI-1L: hour, minute, second (dpi_time)
rtc_t0:         defs 3          ; when the connection began
rtc_last:       defs 3          ; at the last reading that gave a new second
cfg_drive:      defb 0          ; the disk of SAPITERM.COM and SAPITERM.CFG (0 = A)
cfg_term:       defb 0          ; SCREEN=: 0 CGA-1V, 1 AND-1V
cfg_lptr:       defw 0          ; cfg_load: the end of the line in cfg_line
cfg_optr:       defw 0          ; cfg_save: the next byte in cfg_rec
cfg_werr:       defb 0          ; cfg_save: a record could not be written
book_n:         defb 0          ; entries in the address book
cs_type:        defb 0          ; character set of the BBS (CS_*)
utf_need:       defb 0          ; UTF-8: continuation bytes still to come
utf_cp:         defw 0          ; UTF-8: the character so far
speed:          defb 0          ; speed of the line (index of speed_rates, 0 = no limit)
pace_acc:       defw 0          ; the speed of the line: counts of time not used yet
pace_t0:        defw 0          ; the MPH-1V counter 0 at the last pace_elapsed
vf_eof:         defb 0          ; view_file: 1Ah in the buffer (in_end is there)
cols40:         defb 0          ; COLUMNS=40: the CGA-1V has 40 columns on line
cga_wide:       defb 0          ; the CGA-1V shows 40 columns now (term_size)
tn_cr:          defb 0          ; telnet: the last data byte was CR
tn_raw:         defb 0          ; 80h: raw TCP, no telnet (the book, menu N)
log_on:         defb 0          ; session log (xfer.asm)
log_num:        defb 0          ; LOGnn.ANS
log_ptr:        defw 0          ; next byte in log_buf
xm_logged:      defb 0          ; xm_run: the log was on
xm_result:      defb 0
xm_files:       defb 0
xm_open:        defb 0
xm_pstate:      defb 0          ; 0 between blocks, 1 in a block
xm_ymodem:      defb 0
xm_tries:       defb 0
xm_cans:        defb 0
xm_recs:        defw 0          ; records of the file written
xm_crcmode:     defb 0
xm_hdr:         defb 0          ; the next block starts a file
xm_wait:        defw 0          ; ticks left
xm_psize:       defw 0          ; data bytes of the block
xm_pleft:       defw 0          ; bytes of the block still to come
xm_pptr:        defw 0
xm_expect:      defb 0          ; the block number expected
xm_left:        defs 4          ; bytes of the file still to write (FFFFFFFFh unknown)
pd_out:         defw 0          ; put_dec16
term_putc:      jp ansi_putc    ; a byte of the BBS to the terminal: ansi_putc or pet_putc (pet.asm)
rgb_tab:        defw ansi_rgb   ; the colours of the attributes (pal_slot): ansi_rgb or c64_rgb
pet_lower:      defb 0          ; PETSCII: 80h = the lower case set
pet_rvs:        defb 0          ; PETSCII: reverse on
pet_fg:         defb 0          ; PETSCII: the colour of the text (0-15 of the C64)
ata_esc:        defb 0          ; ATASCII: ESC came, the next byte is printed as it is
vdt_esc:        defb 0          ; Viewdata: ESC came, the next byte is an attribute
vs_fg:          defb 0          ; Viewdata: the state of a row while it is decoded (vdt_rowstart: in this order)
vs_bg:          defb 0
vs_mos:         defb 0          ; VDT_MOS or 0
vs_sep:         defb 0          ; VDT_SEP or 0
vs_flash:       defb 0
vs_dh:          defb 0          ; VDT_DHT or 0
vs_conc:        defb 0
vs_code:        defb 0          ; vdt_step: the attribute
vd_ext:         defb 0          ; vdt_step: the flags of the cell
vr_any:         defb 0          ; vdt_row: double height in the row
vc_col:         defb 0          ; vdt_cell
gv_flags:       defb 0          ; ga_vdt
hist_head:      defb 0          ; history: the next line to write
hist_count:     defb 0          ; lines in it
hv_on:          defb 0          ; hist_view: shown (scrolled rows do not go to the history)
hv_top:         defb 0          ; the line of the history on the top row
hv_total:       defb 0
hist_vram:      defb 0          ; history: 1 = the ring is the page B of the CGA-1V
hist_base:      defw 0          ; history: the first record of the ring
hist_cap:       defb 0          ; history: rows in the ring
hv_cur:         defw 0          ; the terminal as it was: cursor row and column, attribute, wrap, region
hv_att:         defb 0
hv_wrap:        defb 0
hv_rtop:        defb 0
hv_rbot:        defb 0

PROGRAM_END:

; buffers after the program (not in the .COM). Every EQU here may use only symbols defined above it: pasmo
; gives the code before it the value of its first pass otherwise (docs/vyvoj.md, tools/check_build.py).
IN_RECORDS      equ 16                          ; input buffer: records of 128 bytes
att_slot        equ 0B800h                      ; 7 pages under C000h (the BSS must end below, check_build.py):
                                                ; slot of each attribute per domain (FFh = none)
att_pref        equ att_slot + 256*DOMAINS      ; page: the preferred slot of each attribute (to BFFFh)
BSS             equ PROGRAM_END                 ; the rest needs no alignment: no padding after the program
scr_chr         equ BSS                         ; shadow: characters
scr_att         equ scr_chr + SCR_COLS*SCR_ROWS ; attributes
scr_ext         equ scr_att + SCR_COLS*SCR_ROWS ; flags
row_off         equ scr_ext + SCR_COLS*SCR_ROWS ; 25 words: offset of each screen row
kb_ring         equ row_off + 2*SCR_ROWS        ; 16 keys
slot_att        equ kb_ring + 16                ; 7 x 16: attribute of each slot
slot_ref        equ slot_att + 16*DOMAINS       ; 7 x 16 words: cells using each slot
rec_buf         equ slot_ref + 32*DOMAINS       ; 128: a record of the file
in_buf          equ rec_buf + 128               ; IN_RECORDS * 128: input (file, later the BBS)
sauce_buf       equ in_buf + 128*IN_RECORDS     ; 256: the last two records (SAUCE)
rx_raw          equ sauce_buf                   ; 253: a TCPRECV (SAUCE is not used on line)
log_buf         equ sauce_buf + 256             ; 128: a record of the session log
hv_line         equ log_buf + 128               ; HIST_REC: a row of the history put together or read back (the
                                                ; ring may be the page B of the CGA-1V: below C000h)
vdt_glyph       equ hv_line + HIST_REC          ; 8: the glyph made by ga_vdt (after font_pet: drawn as it is)
vdt_dhbuf       equ vdt_glyph + 8               ; 8
STACK_TOP       equ vdt_dhbuf + 8 + 256
BSS_END         equ STACK_TOP                   ; at most att_slot

; from C000h to the end of the TPA (the page of the BDOS entry at 0006h, tpa_check; the CCP below it is loaded
; again by the warm boot when SAPI-Term ends): RAM with MAP_CPM only. Buffers the drawing does not touch (it maps
; the CGA-1V only inside cga_draw), then the history without a CGA-1V (with it the history is in its page B;
; hist_init counts its rows up to tpa_top).
book            equ 0C000h                      ; BOOK_MAX entries of the address book
xm_pkt          equ book + BOOK_ENTRY*BOOK_MAX  ; 1030: a block of XMODEM / YMODEM; cfg_rec and cfg_line in it too
                                                ; (SAPITERM.CFG is not read or written while a download runs)
cfg_rec         equ xm_pkt                      ; 128: a record of SAPITERM.CFG
cfg_line        equ cfg_rec + 128               ; CFG_LINE + 2: a line of it
vdt_raw         equ xm_pkt + 1030               ; 24 x 40: the codes of Viewdata
vdt_dh          equ vdt_raw + 24*40             ; 24: double height in the row
hist_buf        equ vdt_dh + 24                 ; the history without a CGA-1V (and so without att_slot)
HIST_LINES      equ (0D600h - hist_buf) / HIST_REC  ; the rows on the CP/M of the set V (BDOS at D606h)

        end start
