; SAPI-Term - ATASCII (Atari 8-bit): 40x24 on the CGA-1V in the colours of the Atari (light text on blue), the
; font font_ata (tools/atafont.py), the control codes of the Atari screen editor, the keys as an Atari sends them.
;
; The shadow has the ATASCII code 00h-7Fh with EXT_ATA; 80h-FFh are the same in inverse video (the colours
; swapped, cell by cell). Printing wraps at once at the end of a row; the cursor keys wrap around the screen.
; 1Bh (ESC) prints the next byte as it is. CS_ATASCII is a set of the menu Z and of the book like CS_PETSCII
; (pet.asm, whose pet_leave and pet_palette serve both).

EXT_ATA         equ 04h             ; the cell is a glyph of font_ata
ATA_ATT         equ 01h             ; text colour 1 on background 0 of ata_rgb
ATA_INV         equ 10h             ; inverse video

; ata_enter: the terminal becomes an Atari screen. Changes all.
ata_enter:
        ld hl,ata_putc
        ld (term_putc+1),hl
        xor a
        ld (js_enable),a
        ld (ata_esc),a
        ld a,1                  ; bit 7 of an attribute: a background colour (inverse), no blink
        ld (ice_mode),a
        call pet_palette
        call term_size
        call ata_att
        call scr_reset_region
        jp scr_cls

; ata_att: cur_att for blank cells (light text on blue). Changes A.
ata_att:
        ld a,ATA_ATT
        ld (cur_att),a
        ret

; ata_putc: byte A of the BBS. Changes all.
ata_putc:
        ld c,a
        ld a,(ata_esc)
        or a
        jr nz,ata_literal
        ld a,c
        cp 1Bh
        jr z,ata_esc_on
        cp 1Ch
        jr z,ata_up
        cp 1Dh
        jp z,ata_down_wrap
        cp 1Eh
        jp z,ata_left
        cp 1Fh
        jp z,ata_right
        cp 7Dh
        jp z,ata_clear
        cp 7Eh
        jp z,ata_back
        cp 7Fh
        jp z,ata_tab
        cp 9Bh
        jp z,ata_eol
        cp 9Ch
        jp z,ata_del_line
        cp 9Dh
        jp z,ata_ins_line
        cp 9Eh                  ; tab stops: not kept
        ret z
        cp 9Fh
        ret z
        cp 0FDh                 ; the buzzer: nothing yet
        ret z
        cp 0FEh
        jp z,ata_del_char
        cp 0FFh
        jp z,ata_ins_char
        jr ata_print
ata_esc_on:
        ld a,1
        ld (ata_esc),a
        ret
ata_literal:
        xor a
        ld (ata_esc),a
ata_print:                      ; C = the code: 00h-7Fh, 80h-FFh inverse
        ld a,c
        and 7Fh
        ld b,a
        ld a,c
        and 80h
        ld c,ATA_ATT
        jr z,ap_att
        ld c,ATA_INV
ap_att:
        ld a,(cur_row)
        ld d,a
        ld a,(cur_col)
        ld e,a
        ld a,EXT_ATA
        call scr_set
        ld a,(cur_col)          ; wraps at once
        inc a
        ld hl,term_cols
        cp (hl)
        jr c,ap_col
        xor a
        ld (cur_col),a
        jr ata_eol_down
ap_col:
        ld (cur_col),a
        ret
ata_up:                         ; the cursor keys wrap around the screen
        ld a,(cur_row)
        or a
        jr nz,au_up
        ld a,(term_rows)
au_up:
        dec a
        ld (cur_row),a
        ret
ata_down_wrap:
        ld a,(term_rows)
        ld b,a
        ld a,(cur_row)
        inc a
        cp b
        jr c,adw_set
        xor a
adw_set:
        ld (cur_row),a
        ret
ata_left:
        ld a,(cur_col)
        or a
        jr nz,al_left
        ld a,(term_cols)
al_left:
        dec a
        ld (cur_col),a
        ret
ata_right:
        ld a,(term_cols)
        ld b,a
        ld a,(cur_col)
        inc a
        cp b
        jr c,ar_set
        xor a
ar_set:
        ld (cur_col),a
        ret
ata_clear:
        call ata_att
        call scr_cls
        xor a
        ld (cur_row),a
        ld (cur_col),a
        ret
ata_back:                       ; one left, the cell erased
        ld a,(cur_col)
        or a
        ret z
        dec a
        ld (cur_col),a
        ld e,a
        ld a,(cur_row)
        ld d,a
        ld b,' '
        ld c,ATA_ATT
        ld a,EXT_ATA
        jp scr_set
ata_tab:                        ; to the next column of 8, past the end to the next row
        ld a,(cur_col)
        or 7
        inc a
        ld hl,term_cols
        cp (hl)
        jr c,ap_col
        xor a
        ld (cur_col),a
        jr ata_eol_down
ata_eol:
        xor a
        ld (cur_col),a
ata_eol_down:                   ; a row down, at the bottom the screen scrolls
        call ata_att
        xor a
        ld (wrap_pend),a
        jp scr_lf
ata_del_line:                   ; the row goes, the rows below move up
        call ata_att
        xor a
        ld (cur_col),a
        ld a,(term_rows)
        dec a
        ld c,a
        ld a,(cur_row)
        ld b,a
        jp scr_region_up
ata_ins_line:                   ; a blank row at the cursor, the rows below move down
        call ata_att
        ld a,(term_rows)
        dec a
        ld c,a
        ld a,(cur_row)
        ld b,a
        jp scr_region_down
ata_del_char:
        call ata_att
        ld a,(cur_col)
        ld e,a
        ld a,(cur_row)
        ld d,a
        ld b,1
        jp scr_delete_chars
ata_ins_char:
        call ata_att
        ld a,(cur_col)
        ld e,a
        ld a,(cur_row)
        ld d,a
        ld b,1
        jp scr_insert_chars

; ata_key: key A to an ATASCII BBS: Enter = EOL (9Bh), Backspace, the cursor keys, Tab, Del and Ins as the
; Atari sends them; ASCII as it is, Czech letters are not sent. Changes all.
ata_key:
        ld c,a
        ld hl,ata_keys
ak_find:
        ld a,(hl)
        or a
        jr z,ak_plain
        inc hl
        cp c
        ld a,(hl)
        inc hl
        jp z,tx_data
        jr ak_find
ak_plain:
        ld a,c
        cp 80h
        ret nc
        jp tx_data

; keys of the EKL-1 and the Consul: code, ATASCII; 00h ends it
ata_keys:
        defb 0Dh,9Bh, 08h,7Eh, 7Fh,7Eh, 05h,1Ch, 18h,1Dh, 13h,1Eh, 04h,1Fh, 09h,7Fh, 0Bh,0FEh, 16h,0FFh
        defb 0C1h,1Ch, 0C2h,1Dh, 0C4h,1Eh, 0C3h,1Fh
        defb 0

; the colours: 0 the blue of the Atari, 1 its light text; the rest as ansi_rgb (texts of SAPI-Term)
ata_rgb:
        defb 00h,0Eh,22h, 20h,30h,3Fh, 00h,2Ah,00h, 00h,2Ah,2Ah
        defb 2Ah,00h,00h, 2Ah,00h,2Ah, 2Ah,15h,00h, 2Ah,2Ah,2Ah
        defb 15h,15h,15h, 15h,15h,3Fh, 15h,3Fh,15h, 15h,3Fh,3Fh
        defb 3Fh,15h,15h, 3Fh,15h,3Fh, 3Fh,3Fh,15h, 3Fh,3Fh,3Fh
