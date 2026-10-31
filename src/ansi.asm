; SAPI-Term - ANSI-BBS and VT100 terminal: bytes from a BBS (or a .ANS file) to the screen.
;
; Printable bytes 20-FF are CP437 characters. Controls: CR, LF, BS, TAB, FF (clear like ANSI-BBS), BEL; other
; control bytes show their CP437 glyph like ANSI.SYS, 00h is ignored. ESC 7/8 save and restore the cursor, ESC D
; index, ESC M reverse index, ESC E next line, ESC c reset; ESC ( ) * + # % skip one byte.
; CSI (ESC [): A B C D E F G ` a d e H f (cursor), J K (erase, J 2 also homes like ANSI-BBS), L M (lines),
; @ P X (characters), S T (scroll), m (SGR), r (scroll region), s u (save, restore), n c (replies),
; ? 7 h/l (wrap), ? 25 h/l (cursor), ? 33 h/l (iCE colours, CTerm). Other sequences are swallowed.
; tools/ansiref.py does exactly the same in Python for the tests.

ANS_NORMAL      equ 0
ANS_ESC         equ 1
ANS_CSI         equ 2
ANS_SKIP        equ 3
ANS_PARAMS      equ 8

; ansi_reset: parser, SGR, modes, scroll region and the saved cursor to their defaults (the screen stays).
; Changes A, BC, DE, HL.
ansi_reset:
        xor a
        ld (ans_state),a
        ld (wrap_off),a
        ld (cur_off),a
        ld (cur_ext),a
        ld hl,sgr_fg
        ld (hl),7
        inc hl
        ld b,SGR_SIZE-1
ar_sgr:
        ld (hl),0
        inc hl
        djnz ar_sgr
        ld hl,sgr_fg
        ld de,sv_sgr
        ld bc,SGR_SIZE
        ldir
        xor a
        ld (sv_row),a
        ld (sv_col),a
        call scr_reset_region
        jp sgr_apply

; ansi_putc: byte A from the BBS. Changes all.
ansi_putc:
        ld c,a
        ld a,(ans_state)
        or a
        jr nz,ans_seq
        ld a,c
        cp 20h
        jr c,ans_control
        cp 80h
        jp c,scr_putc
        jp cs_byte              ; 80h-FFh in the set of the BBS
ans_control:
        cp 1Bh
        jr z,ans_esc_start
        cp 0Dh
        jp z,ans_cr
        cp 0Ah
        jp z,ans_lf
        cp 08h
        jp z,ans_bs
        cp 09h
        jp z,ans_tab
        cp 0Ch
        jp z,ans_ff
        cp 07h
        jp z,mph_bell           ; BEL: a tone on the MPH-1V
        or a
        ret z
        jp scr_putc             ; other controls: their CP437 glyph
ans_esc_start:
        ld a,ANS_ESC
        ld (ans_state),a
        ret

ans_seq:
        cp ANS_CSI
        jp z,ans_csi
        cp ANS_SKIP
        jr z,ans_to_normal
        ld a,ANS_NORMAL         ; after ESC
        ld (ans_state),a
        ld a,c
        cp '['
        jr z,ans_csi_start
        cp '7'
        jp z,ans_save
        cp '8'
        jp z,ans_restore
        cp 'D'
        jp z,ans_lf
        cp 'M'
        jp z,ans_ri
        cp 'E'
        jp z,ans_nel
        cp 'c'
        jp z,ans_ris
        cp '('
        jr z,ans_skip_next
        cp ')'
        jr z,ans_skip_next
        cp '*'
        jr z,ans_skip_next
        cp '+'
        jr z,ans_skip_next
        cp '#'
        jr z,ans_skip_next
        cp '%'
        jr z,ans_skip_next
        cp 1Bh
        jr z,ans_esc_start
        ret
ans_skip_next:
        ld a,ANS_SKIP
        ld (ans_state),a
        ret
ans_to_normal:
        xor a
        ld (ans_state),a
        ret
ans_csi_start:                  ; the ANS_PARAMS (8) parameters cleared by words
        ld a,ANS_CSI
        ld (ans_state),a
        xor a
        ld (ans_np),a
        ld (ans_priv),a
        ld (ans_inter),a
        ld h,a
        ld l,a
        ld (ans_par),hl
        ld (ans_par+2),hl
        ld (ans_par+4),hl
        ld (ans_par+6),hl
        ld hl,ans_par
        ld (ans_pp),hl
        ret

; CSI: parameters, then the final byte runs the command.
ans_csi:
        ld a,c
        cp '0'
        jr c,csi_other
        cp '9'+1
        jr nc,csi_other
        sub '0'                 ; digit: param = param * 10 + digit, at most 255
        ld e,a
        ld hl,(ans_pp)
        ld a,(hl)
        cp 26
        jr nc,csi_max
        ld b,a
        add a,a
        add a,a
        add a,b
        add a,a                 ; * 10 (at most 250)
        add a,e
        jr nc,csi_store
csi_max:
        ld a,255
csi_store:
        ld (hl),a
        ret
csi_other:
        cp ';'
        jr z,csi_next
        cp ':'
        jr z,csi_next
        cp 3Ch                  ; < = > ?: private sequence
        jr c,csi_ctl
        cp 40h
        jr nc,csi_final
        ld (ans_priv),a
        ret
csi_next:
        ld a,(ans_np)
        cp ANS_PARAMS-1
        ret nc
        inc a
        ld (ans_np),a
        ld hl,(ans_pp)
        inc hl
        ld (ans_pp),hl
        ret
csi_ctl:
        cp 20h
        jr c,csi_c0
        ld (ans_inter),a        ; 20-2F: intermediate byte
        ret
csi_c0:
        cp 1Bh
        jp z,ans_esc_start
        cp 18h                  ; CAN, SUB: abort
        jp z,ans_to_normal
        cp 1Ah
        jp z,ans_to_normal
        ret                     ; other controls inside a sequence: ignored
csi_final:
        ld b,a
        xor a
        ld (ans_state),a
        ld a,b
        cp 7Fh
        ret nc                  ; DEL is not a final byte
        ld a,(ans_inter)
        or a
        ret nz                  ; with an intermediate byte: not ours
        ld a,(ans_priv)
        cp '?'
        jp z,csi_private
        or a
        ret nz
        ld c,b
        ld a,b                  ; final bytes 40h-7Eh: their routine from csi_jump
        sub 40h
        ret c
        add a,a
        ld l,a
        ld h,0
        ld de,csi_jump
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)
csi_none:
        ret

csi_jump:
        defw csi_ich, csi_cuu, csi_cud, csi_cuf, csi_cub, csi_cnl, csi_cpl, csi_cha     ; @ A B C D E F G
        defw csi_cup, csi_none, csi_ed, csi_el, csi_il, csi_dl, csi_none, csi_none      ; H I J K L M N O
        defw csi_dch, csi_none, csi_none, csi_su, csi_sd, csi_none, csi_none, csi_none  ; P Q R S T U V W
        defw csi_ech, csi_none, csi_none, csi_none, csi_none, csi_none, csi_none, csi_none ; X Y Z [ \ ] ^ _
        defw csi_cha, csi_cuf, csi_none, csi_da, csi_vpa, csi_cud, csi_cup, csi_none    ; ` a b c d e f g
        defw csi_none, csi_none, csi_none, csi_none, csi_none, csi_sgr, csi_dsr, csi_none ; h i j k l m n o
        defw csi_none, csi_none, csi_stbm, ans_save, csi_none, ans_restore, csi_none, csi_none ; p q r s t u v w
        defw csi_none, csi_none, csi_none, csi_none, csi_none, csi_none, csi_none       ; x y z { | } ~

; p0: A = parameter 0 as it is. p1: A = parameter 0, 1 when 0 (the default of counts). p1b: the same for
; parameter 1.
p0:
        ld a,(ans_par)
        ret
p1:
        ld a,(ans_par)
        or a
        ret nz
        inc a
        ret
p1b:
        ld a,(ans_par+1)
        or a
        ret nz
        inc a
        ret

; --- cursor ---

ans_cr:
        xor a
        ld (cur_col),a
        ld (wrap_pend),a
        ret
ans_lf:
        xor a
        ld (wrap_pend),a
        jp scr_lf
ans_ri:
        xor a
        ld (wrap_pend),a
        jp scr_ri
ans_nel:
        call ans_cr
        jp scr_lf
ans_bs:
        xor a
        ld (wrap_pend),a
        ld a,(cur_col)
        or a
        ret z
        dec a
        ld (cur_col),a
        ret
ans_tab:
        xor a
        ld (wrap_pend),a
        ld a,(cur_col)
        add a,8
        and 0F8h
        ld b,a
        ld a,(term_cols)
        dec a
        cp b
        jr c,at_last
        ld a,b
at_last:
        ld (cur_col),a
        ret
ans_ff:
        jp scr_cls
ans_ris:
        call ansi_reset
        jp scr_cls

; set_row: cursor row A clamped to the screen. set_col: column. Both clear the pending wrap. Change A.
set_row:
        push hl
        ld hl,term_rows
        cp (hl)
        jr c,sr_ok
        ld a,(hl)
        dec a
sr_ok:
        ld (cur_row),a
        pop hl
        xor a
        ld (wrap_pend),a
        ld (js_pending),a
        ret
set_col:
        push hl
        ld hl,term_cols
        cp (hl)
        jr c,sc_ok
        ld a,(hl)
        dec a
sc_ok:
        ld (cur_col),a
        pop hl
        xor a
        ld (wrap_pend),a
        ret

csi_cuu:
        call p1
        ld b,a
        ld a,(cur_row)
        sub b
        jr nc,set_row
        xor a
        jr set_row
csi_cud:
        call p1
        ld b,a
        ld a,(cur_row)
        add a,b
        jr nc,set_row
        ld a,255
        jr set_row
csi_cuf:
        call p1
        ld b,a
        ld a,(cur_col)
        add a,b
        jr nc,set_col
        ld a,255
        jr set_col
csi_cub:
        call p1
        ld b,a
        ld a,(cur_col)
        sub b
        jr nc,set_col
        xor a
        jr set_col
csi_cnl:
        call csi_cud
        jp ans_cr
csi_cpl:
        call csi_cuu
        jp ans_cr
csi_cha:
        call p1
        dec a
        jr set_col
csi_vpa:
        call p1
        dec a
        jr set_row
csi_cup:
        call p1b
        dec a
        call set_col
        call p1
        dec a
        jp set_row

ans_save:
        ld a,(cur_row)
        ld (sv_row),a
        ld a,(cur_col)
        ld (sv_col),a
        ld hl,sgr_fg
        ld de,sv_sgr
        ld bc,SGR_SIZE
        ldir
        ret
ans_restore:
        ld a,(sv_row)
        call set_row
        ld a,(sv_col)
        call set_col
        ld hl,sv_sgr
        ld de,sgr_fg
        ld bc,SGR_SIZE
        ldir
        jp sgr_apply

; --- erase, insert, delete ---

csi_ed:
        call p0
        cp 1
        jr z,ed_above
        jr c,ed_below
        jp scr_cls              ; 2 (and 3): all, cursor home (ANSI-BBS)
ed_below:
        call csi_el0
        ld a,(cur_row)
edb_row:
        inc a
        cp SCR_ROWS
        ret nc
        push af
        ld d,a
        ld e,0
        ld b,SCR_COLS
        call scr_erase
        pop af
        jr edb_row
ed_above:
        call csi_el1
        ld a,(cur_row)
eda_row:
        or a
        ret z
        dec a
        push af
        ld d,a
        ld e,0
        ld b,SCR_COLS
        call scr_erase
        pop af
        jr eda_row

csi_el:
        call p0
        or a
        jr z,csi_el0
        cp 1
        jr z,csi_el1
        ld a,(cur_row)          ; 2: the whole row
        ld d,a
        ld e,0
        ld b,SCR_COLS
        jp scr_erase
csi_el0:                        ; cursor to the end of the row
        call cur_de
        ld a,SCR_COLS
        sub e
        ld b,a
        jp scr_erase
csi_el1:                        ; start of the row to the cursor
        call cur_de
        ld b,e
        inc b
        ld e,0
        jp scr_erase

; cur_de: D = cursor row, E = cursor column. Changes A.
cur_de:
        ld a,(cur_row)
        ld d,a
        ld a,(cur_col)
        ld e,a
        ret

csi_ech:
        call p1
        ld b,a
        call cur_de
        ld a,SCR_COLS
        sub e
        cp b
        jr nc,ech_go
        ld b,a
ech_go:
        jp scr_erase
csi_ich:
        call p1
        ld b,a
        call cur_de
        jp scr_insert_chars
csi_dch:
        call p1
        ld b,a
        call cur_de
        jp scr_delete_chars

; lines: only with the cursor inside the scroll region; the cursor goes to column 0
csi_il:
        call in_region
        ret c
        call ans_cr
        call rep_count
ilr_loop:
        push bc
        ld a,(cur_row)
        ld b,a
        ld a,(reg_bot)
        ld c,a
        call scr_region_down
        pop bc
        djnz ilr_loop
        ret
csi_dl:
        call in_region
        ret c
        call ans_cr
        call rep_count
dlr_loop:
        push bc
        ld a,(cur_row)
        ld b,a
        ld a,(reg_bot)
        ld c,a
        call scr_region_up
        pop bc
        djnz dlr_loop
        ret
csi_su:
        call rep_count
sur_loop:
        push bc
        call scr_scroll
        pop bc
        djnz sur_loop
        ret
csi_sd:
        call rep_count
sdr_loop:
        push bc
        call scr_scroll_down
        pop bc
        djnz sdr_loop
        ret

; rep_count: B = parameter 0 (default 1), at most the number of rows. Changes A.
rep_count:
        call p1
        cp SCR_ROWS
        jr c,rc_ok
        ld a,SCR_ROWS
rc_ok:
        ld b,a
        ret

; in_region: carry when the cursor row is outside the scroll region. Changes A, B.
in_region:
        ld a,(reg_top)
        ld b,a
        ld a,(cur_row)
        cp b
        ret c                   ; above the region
        ld b,a
        ld a,(reg_bot)
        cp b                    ; carry when the row is below the region
        ret

; csi_stbm: scroll region from row p0 (default 1) to p1 (default the last); a valid one homes the cursor.
csi_stbm:
        call p1
        dec a
        ld b,a
        ld a,(ans_par+1)
        or a
        jr nz,stbm_bot
        ld a,(term_rows)
stbm_bot:
        ld hl,term_rows
        cp (hl)
        jr c,stbm_dec
        ld a,(hl)
stbm_dec:
        dec a
        ld c,a                  ; C = bottom
        ld a,b
        cp c
        ret nc                  ; top must be above the bottom
        ld (reg_top),a
        ld a,c
        ld (reg_bot),a
        xor a
        ld (cur_row),a
        ld (cur_col),a
        ld (wrap_pend),a
        ret

; --- modes and replies ---

csi_private:
        ld a,b
        cp 'h'
        ld c,0
        jr z,cp_set
        cp 'l'
        ret nz
        ld c,1
cp_set:                         ; C = 1 for reset ('l')
        ld a,(ans_par)
        cp 7
        jr nz,cp_25
        ld a,c
        ld (wrap_off),a
        xor a
        ld (wrap_pend),a
        ret
cp_25:
        cp 25
        jr nz,cp_33
        ld a,c
        ld (cur_off),a
        ret
cp_33:
        cp 33                   ; CTerm (SyncTERM): ?33h = iCE colours (blink = bright background)
        ret nz
        ld a,c
        xor 1
        ld (ice_mode),a
        call blink_mark         ; bit 7 means something else now
        jp sgr_apply

; csi_dsr: 6 = cursor position (ESC [ row ; column R), 5 = status (ESC [ 0 n).
csi_dsr:
        call p0
        cp 5
        jr z,dsr_ok
        cp 6
        ret nz
        ld hl,ans_reply
        ld (hl),1Bh
        inc hl
        ld (hl),'['
        inc hl
        ld a,(cur_row)
        inc a
        call dec_to_hl
        ld (hl),';'
        inc hl
        ld a,(cur_col)
        inc a
        call dec_to_hl
        ld (hl),'R'
        inc hl
        ld (hl),0
        jr reply
dsr_ok:
        ld hl,txt_dsr_ok
        jr reply_hl
csi_da:
        call p0
        or a
        ret nz
        ld hl,txt_da
reply_hl:
        ld de,ans_reply
rh_copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,rh_copy
; reply: the answer in ans_reply (00h at the end) goes to the BBS through reply_hook (none: dropped).
reply:
        ld hl,(reply_hook)
        ld a,h
        or l
        ret z
        jp (hl)

; dec_to_hl: A (1-255) in decimal at HL, HL after it. Changes A, B.
dec_to_hl:
        ld b,'0'-1
dth_100:
        inc b
        sub 100
        jr nc,dth_100
        add a,100
        push af
        ld a,b
        cp '0'
        jr z,dth_tens
        ld (hl),b
        inc hl
        pop af
        ld b,'0'-1
dth_10b:
        inc b
        sub 10
        jr nc,dth_10b
        add a,10
        ld (hl),b
        inc hl
        jr dth_units
dth_tens:
        pop af
        ld b,'0'-1
dth_10:
        inc b
        sub 10
        jr nc,dth_10
        add a,10
        push af
        ld a,b
        cp '0'
        jr z,dth_skip
        ld (hl),b
        inc hl
dth_skip:
        pop af
dth_units:
        add a,'0'
        ld (hl),a
        inc hl
        ret

txt_dsr_ok:
        defb 1Bh,'[0n',0
txt_da:
        defb 1Bh,'[?1;0c',0

; --- SGR ---

csi_sgr:
        ld a,(ans_np)
        inc a
        ld b,a
        ld hl,ans_par
sgr_loop:
        ld a,(hl)
        inc hl
        cp 38
        jr z,sgr_ext
        cp 48
        jr z,sgr_ext
        push bc
        push hl
        call sgr_one
        pop hl
        pop bc
sgr_next:
        djnz sgr_loop
        jp sgr_apply
sgr_ext:                        ; 38/48 ; 5 ; n  or  38/48 ; 2 ; r ; g ; b: skipped
        dec b
        jr z,sgr_done
        ld a,(hl)
        inc hl
        ld c,1
        cp 5
        jr z,sgr_skip
        ld c,3
        cp 2
        jr nz,sgr_next
sgr_skip:
        dec b
        jr z,sgr_done
        inc hl
        dec c
        jr nz,sgr_skip
        jr sgr_next
sgr_done:
        jp sgr_apply

; sgr_one: one SGR parameter A. The colours first (30-49, the most of them), then the rest.
sgr_one:
        or a
        jr z,so_reset_all
        cp 30
        jr c,so_1
        cp 50
        jr nc,so_bright
        sub 30
        cp 8
        jr c,so_fg              ; 30-37
        cp 9
        jr z,so_fg_default      ; 39
        sub 10
        cp 8
        jr c,so_bg              ; 40-47
        cp 9
        jr z,so_bg_default      ; 49
        ret
so_bright:
        sub 90
        ret c
        cp 8
        jr c,so_fg_bright       ; 90-97
        sub 10
        ret c
        cp 8
        ret nc
        ld (sgr_bg),a           ; 100-107: bright background
        ld a,1
        ld (sgr_bghi),a
        ret
so_reset_all:
        ld hl,sgr_fg            ; 0: all off
        ld (hl),7
        inc hl
        ld b,SGR_SIZE-1
so_reset:
        ld (hl),0
        inc hl
        djnz so_reset
        ret
so_1:
        ld hl,sgr_bold
        cp 1
        jr z,so_set
        cp 22
        jr z,so_clear
        ld hl,sgr_blink
        cp 5
        jr z,so_set
        cp 6
        jr z,so_set
        cp 25
        jr z,so_clear
        ld hl,sgr_rev
        cp 7
        jr z,so_set
        cp 27
        jr z,so_clear
        ret
so_set:
        ld (hl),1
        ret
so_clear:
        ld (hl),0
        ret
so_fg_default:
        ld a,7
so_fg:
        ld (sgr_fg),a
        ret
so_fg_bright:
        ld (sgr_fg),a
        ld a,1
        ld (sgr_bold),a
        ret
so_bg_default:
        xor a
so_bg:
        ld (sgr_bg),a
        xor a
        ld (sgr_bghi),a
        ret

; sgr_apply: cur_att from the SGR state: bold = bright foreground, a bright background with 100-107 or with
; blink in the iCE mode (blink itself is not shown yet), reverse swaps the two. Changes A, B, HL.
sgr_apply:
        ld a,(sgr_fg)
        call ansi_to_cga
        ld b,a
        ld a,(sgr_bold)
        or a
        jr z,sa_bg
        ld a,b
        or 8
        ld b,a
sa_bg:
        ld a,(sgr_bg)
        call ansi_to_cga
        ld c,a
        ld a,(sgr_bghi)         ; bit 7 of the attribute: blink, or a bright background with iCE (as the
        or a                    ; attribute byte of a PC; pal_slot shows it by ice_mode)
        jr nz,sa_bright
        ld a,(sgr_blink)
        or a
        jr z,sa_rev
sa_bright:
        ld a,c
        or 8
        ld c,a
sa_rev:
        ld a,(sgr_rev)
        or a
        jr z,sa_set
        ld a,b
        ld b,c
        ld c,a
sa_set:                         ; B = foreground, C = background
        ld a,c
        rlca
        rlca
        rlca
        rlca
        or b
        ld (cur_att),a
        ret

; ansi_to_cga: ANSI colour A (0-7: black red green yellow blue magenta cyan white) -> CGA colour. Changes HL.
ansi_to_cga:
        and 7
        ld hl,ansi_cga
        add a,l
        ld l,a
        jr nc,atc_hl
        inc h
atc_hl:
        ld a,(hl)
        ret
ansi_cga:
        defb 0,4,2,6,1,5,3,7
