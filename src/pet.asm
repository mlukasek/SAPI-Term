; SAPI-Term - PETSCII (Commodore 64): 40x25 on the CGA-1V with the colours of the C64 and the font font_pet
; (tools/petfont.py), the control codes of the C64 screen editor, the keys as a C64 sends them.
;
; The shadow has the screen code of the C64 (0-127, bit 7 = the lower case set) with EXT_8X8; reverse swaps the
; colours (the background is black). Printing wraps at once at the end of a row, as on the C64. CS_PETSCII is a
; character set of the menu Z and the book: pet_enter and pet_leave switch the terminal.

EXT_8X8         equ 02h             ; the cell is a glyph of font_pet (screen.asm: flags of a cell)
PET_FG          equ 15              ; light grey at the start

; pet_enter: the terminal becomes a C64 screen: term_putc to pet_putc, 40 columns on the CGA-1V, its colours,
; no jump scroll, the screen cleared. Changes all.
pet_enter:
        ld hl,pet_putc
        ld (term_putc+1),hl
        xor a
        ld (js_enable),a
        ld (pet_rvs),a
        ld a,80h                ; the lower case set, as C64 terminal programs start (BBS text has both cases)
        ld (pet_lower),a
        ld a,PET_FG
        ld (pet_fg),a
        ld a,1                  ; bit 7 of an attribute: a background colour 8-15 (reverse), no blink
        ld (ice_mode),a
        call pet_palette
        call term_size
        call pet_att
        call scr_reset_region
        jp scr_cls

; pet_leave: the ANSI terminal again (80 columns, its colours), the screen cleared; from ATASCII too.
; Changes all.
pet_leave:
        ld hl,ansi_putc
        ld (term_putc+1),hl
        xor a
        ld (ice_mode),a
        ld (cs_type),a
        call pet_palette
        call term_size
        call ansi_reset
        call js_by_speed
        call scr_reset_region
        jp scr_cls

; term8_enter: the terminal of the set cs_type when it is PETSCII, ATASCII or Viewdata. Changes all.
term8_enter:
        ld a,(cs_type)
        cp CS_PETSCII
        jp z,pet_enter
        cp CS_ATASCII
        jp z,ata_enter
        cp CS_VIEWDATA
        jp z,vdt_enter
        ret

; term8_att: cur_att of PETSCII or ATASCII (after ansi_reset). Changes A.
term8_att:
        ld a,(cs_type)
        cp CS_PETSCII
        jp z,pet_att
        cp CS_ATASCII
        jp z,ata_att
        cp CS_VIEWDATA
        jp z,vdt_att
        ret

; term8_leave: from PETSCII or ATASCII the ANSI terminal again. Changes all.
term8_leave:
        ld a,(cs_type)
        cp CS_PETSCII
        ret c
        jp pet_leave

; pet_palette: rgb_tab = the colours of the C64 (PETSCII) or of the Atari (ATASCII) when it is on the CGA-1V,
; else the ANSI ones; every slot gets its colours again. Changes A, BC, HL.
pet_palette:
        ld hl,ansi_rgb
        ld a,(term_dev)
        cp DEV_CGA
        jr nz,ppl_set
        ld a,(cs_type)
        cp CS_PETSCII
        jr nz,ppl_ata
        ld hl,c64_rgb
        jr ppl_set
ppl_ata:
        cp CS_ATASCII
        jr nz,ppl_vdt
        ld hl,ata_rgb
        jr ppl_set
ppl_vdt:
        cp CS_VIEWDATA
        jr nz,ppl_set
        ld hl,vdt_rgb
ppl_set:
        ld (rgb_tab),hl
        ld hl,pal_dirty
        ld b,2*DOMAINS
ppl_dirty:
        ld (hl),0FFh
        inc hl
        djnz ppl_dirty
        ret

; pet_att: cur_att from pet_fg and pet_rvs (black background, reverse: the colour behind). Changes A.
pet_att:
        ld a,(pet_rvs)
        or a
        ld a,(pet_fg)
        jr z,pat_set
        rlca
        rlca
        rlca
        rlca
pat_set:
        ld (cur_att),a
        ret

; pet_putc: byte A of the BBS. Changes all.
pet_putc:
        cp 20h
        jr c,pet_ctl
        cp 80h
        jr c,pet_print
        cp 0A0h
        jr c,pet_ctl
pet_print:                      ; PETSCII -> screen code
        cp 0FFh
        jr nz,pp_code
        ld a,5Eh                ; pi
        jr pp_out
pp_code:
        cp 40h
        jr c,pp_out             ; 20-3F as they are
        cp 60h
        jr c,pp_sub40           ; 40-5F -> 00-1F
        cp 80h
        jr c,pp_sub20           ; 60-7F -> 40-5F
        cp 0C0h
        jr c,pp_sub40           ; A0-BF -> 60-7F
        sub 80h                 ; C0-DF -> 40-5F, E0-FE -> 60-7E
        jr pp_out
pp_sub20:
        sub 20h
        jr pp_out
pp_sub40:
        sub 40h
pp_out:
        ld hl,pet_lower
        or (hl)
        ld b,a
        ld a,(cur_att)
        ld c,a
        ld a,(cur_row)
        ld d,a
        ld a,(cur_col)
        ld e,a
        ld a,EXT_8X8
        call scr_set
        ld a,(cur_col)          ; the C64 wraps at once
        inc a
        ld hl,term_cols
        cp (hl)
        jr c,pp_col
        xor a
        ld (cur_col),a
        jp pet_down
pp_col:
        ld (cur_col),a
        ret

; pet_ctl: the control codes of the C64. Changes all.
pet_ctl:
        ld c,a
        ld hl,pet_colors        ; a colour?
        ld b,16
pc_color:
        cp (hl)
        jr z,pc_set_color
        inc hl
        djnz pc_color
        cp 0Dh
        jr z,pet_return
        cp 8Dh
        jr z,pet_return
        cp 11h
        jr z,pet_down
        cp 91h
        jr z,pet_up
        cp 1Dh
        jr z,pet_right
        cp 9Dh
        jr z,pet_left
        cp 13h
        jr z,pet_home
        cp 93h
        jr z,pet_clear
        cp 12h
        jr z,pet_rvs_on
        cp 92h
        jr z,pet_rvs_off
        cp 14h
        jp z,pet_del
        cp 94h
        jp z,pet_inst
        cp 0Eh
        jp z,pet_lower_set
        cp 8Eh
        jp z,pet_upper_set
        cp 07h
        jp z,bell
        ret                     ; the others: nothing
pc_set_color:
        ld a,16
        sub b
        ld (pet_fg),a
        jp pet_att
pet_return:                     ; to the start of the next row, reverse off
        xor a
        ld (cur_col),a
        ld (pet_rvs),a
        call pet_att
pet_down:                       ; a row down, at the bottom the screen scrolls
        xor a
        ld (wrap_pend),a
        jp scr_lf
pet_up:
        ld a,(cur_row)
        or a
        ret z
        dec a
        ld (cur_row),a
        ret
pet_right:
        ld a,(cur_col)
        inc a
        ld hl,term_cols
        cp (hl)
        jr c,pr_set
        xor a
        ld (cur_col),a
        jr pet_down
pr_set:
        ld (cur_col),a
        ret
pet_left:
        ld a,(cur_col)
        or a
        jr z,pl_up
        dec a
        ld (cur_col),a
        ret
pl_up:                          ; from the first column to the end of the row above
        ld a,(cur_row)
        or a
        ret z
        dec a
        ld (cur_row),a
        ld a,(term_cols)
        dec a
        ld (cur_col),a
        ret
pet_home:
        xor a
        ld (cur_row),a
        ld (cur_col),a
        ret
pet_clear:
        call scr_cls
        jr pet_home
pet_rvs_on:
        ld a,1
        jr prv_set
pet_rvs_off:
        xor a
prv_set:
        ld (pet_rvs),a
        jp pet_att
pet_del:                        ; the character before the cursor goes, the rest of the row moves left
        ld a,(cur_col)
        or a
        ret z
        dec a
        ld (cur_col),a
        ld e,a
        ld a,(cur_row)
        ld d,a
        ld b,1
        jp scr_delete_chars
pet_inst:                       ; a space at the cursor, the rest of the row moves right
        ld a,(cur_col)
        ld e,a
        ld a,(cur_row)
        ld d,a
        ld b,1
        jp scr_insert_chars
pet_lower_set:
        ld a,80h
        jr pls_set
pet_upper_set:
        xor a
pls_set:
        ld hl,pet_lower
        cp (hl)
        ret z
        ld (hl),a
        ld c,a                  ; every PETSCII cell of the shadow into the other set, then drawn again
        ld hl,scr_chr
        ld de,scr_ext
pls_cell:
        ld a,(de)
        and EXT_8X8
        jr z,pls_next
        ld a,(hl)
        and 7Fh
        or c
        ld (hl),a
pls_next:
        inc hl
        inc de
        ld a,l
        cp low (scr_chr+SCR_ROWS*SCR_COLS)
        jr nz,pls_cell
        ld a,h
        cp high (scr_chr+SCR_ROWS*SCR_COLS)
        jr nz,pls_cell
        jp scr_redraw

; pet_key: key A to a PETSCII BBS: letters as a C64 sends them (small = 41h-5Ah, capitals = C1h-DAh), the
; cursor keys, Home, Backspace as DEL, Ins as INST. Czech letters are not sent. Changes all.
pet_key:
        ld c,a
        ld hl,pet_keys
pk_find:
        ld a,(hl)
        or a
        jr z,pk_plain
        inc hl
        cp c
        ld a,(hl)
        inc hl
        jp z,tx_data
        jr pk_find
pk_plain:
        ld a,c
        cp 'a'
        jr c,pk_capital
        cp 'z'+1
        jr nc,pk_ascii
        sub 20h                 ; a -> 41h
        jp tx_data
pk_capital:
        cp 'A'
        jr c,pk_ascii
        cp 'Z'+1
        jr nc,pk_ascii
        add a,80h               ; A -> C1h
        jp tx_data
pk_ascii:
        cp 80h
        ret nc
        jp tx_data

; keys of the EKL-1 and the Consul: code, PETSCII; 00h ends it
pet_keys:
        defb 05h,91h, 18h,11h, 13h,9Dh, 04h,1Dh, 1Eh,13h, 08h,14h, 16h,94h, 7Fh,14h
        defb 0C1h,91h, 0C2h,11h, 0C4h,9Dh, 0C3h,1Dh, 8Dh,13h
        defb 0

; colour control codes of the C64 in the order of its colours 0-15
pet_colors:
        defb 90h,05h,1Ch,9Fh,9Ch,1Eh,1Fh,9Eh,81h,95h,96h,97h,98h,99h,9Ah,9Bh

; the colours of the C64 (6 bits for the Bt476)
c64_rgb:
        defb 00h,00h,00h, 3Fh,3Fh,3Fh, 1Ah,0Dh,0Ah, 1Ch,29h,2Ch
        defb 1Bh,0Fh,21h, 16h,23h,10h, 0Dh,0Ah,1Eh, 2Eh,31h,1Bh
        defb 1Bh,13h,09h, 10h,0Eh,00h, 26h,19h,16h, 11h,11h,11h
        defb 1Bh,1Bh,1Bh, 26h,34h,21h, 1Bh,17h,2Dh, 25h,25h,25h
