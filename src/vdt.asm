; SAPI-Term - Viewdata (Prestel, teletext level 1 on line): 40x24 in its 8 colours, serial attributes, mosaic
; graphics 2x3 (contiguous and separated), double height, flash, conceal; nothing scrolls (the cursor wraps).
;
; The codes received are kept in vdt_raw (24 x 40: 20h-7Fh characters, 80h-9Fh attributes, ESC + 40h-5Fh is the
; attribute too). A row is decoded from its left into the shadow through scr_set: the character (an attribute
; shows as a space), the attribute flash << 7 | background << 4 | colour, the flags EXT_VDT + VDT_MOS,
; VDT_SEP, VDT_DHT (the upper half of double height) or VDT_DHB (the lower one). A row under a row with double
; height shows the lower halves of that row. glyph_addr makes the glyph in vdt_glyph: font_ata or vdt_extra
; for letters, 2x3 blocks for mosaics, half of it twice as high. Hold mosaics are not done.

EXT_VDT         equ 08h
VDT_MOS         equ 10h
VDT_SEP         equ 20h
VDT_DHT         equ 40h
VDT_DHB         equ 80h
VDT_ROWS        equ 24
VDT_COLS        equ 40

; vdt_enter: the terminal becomes a Viewdata screen, cleared, no cursor. Changes all.
vdt_enter:
        ld hl,vdt_putc
        ld (term_putc+1),hl
        xor a
        ld (js_enable),a
        ld (vdt_esc),a
        ld (ice_mode),a         ; bit 7 of an attribute: flash
        call pet_palette
        call term_size
        call scr_reset_region
        ld a,1
        ld (cur_off),a
; vdt_clear: all codes spaces, no double height, the screen cleared, the cursor home. Changes all.
vdt_clear:
        ld hl,vdt_raw
        ld bc,VDT_ROWS*VDT_COLS
        ld a,' '
        call fill
        ld hl,vdt_dh
        ld bc,VDT_ROWS
        xor a
        call fill
        call vdt_att
        call scr_cls
        xor a
        ld (cur_row),a
        ld (cur_col),a
        ret

; vdt_att: cur_att white on black. Changes A.
vdt_att:
        ld a,07h
        ld (cur_att),a
        ret

; vdt_putc: byte A of the BBS. Changes all.
vdt_putc:
        ld c,a
        ld a,(vdt_esc)
        or a
        jr z,vp_byte
        xor a
        ld (vdt_esc),a
        ld a,c                  ; ESC + 40h-5Fh: the attribute 80h-9Fh
        and 1Fh
        or 80h
        jr vdt_write
vp_byte:
        ld a,c
        cp 80h
        jr c,vp_seven
        cp 0A0h
        jr c,vdt_write          ; 80h-9Fh: an attribute as it is
        and 7Fh
vp_seven:
        cp 20h
        jr nc,vdt_write
        cp 1Bh
        jr z,vp_esc
        cp 08h
        jp z,vdt_left
        cp 09h
        jp z,vdt_right
        cp 0Ah
        jp z,vdt_down
        cp 0Bh
        jp z,vdt_up
        cp 0Ch
        jp z,vdt_clear
        cp 0Dh
        jp z,vdt_cr
        cp 1Eh
        jp z,vdt_home
        cp 11h
        jr z,vp_cursor
        cp 14h
        ret nz
        ld a,1                  ; DC4: no cursor
        ld (cur_off),a
        ret
vp_cursor:                      ; DC1: the cursor
        xor a
        ld (cur_off),a
        ret
vp_esc:
        ld a,1
        ld (vdt_esc),a
        ret

; vdt_write: code A at the cursor, the row decoded again as needed, the cursor right. Changes all.
vdt_write:
        ld c,a
        ld a,(cur_row)
        ld d,a
        ld a,(cur_col)
        ld e,a
        call vdt_raw_addr
        ld b,(hl)               ; the code before
        ld (hl),c
        ld a,b                  ; an attribute comes or goes, or double height: the whole row
        or c
        and 80h
        jr nz,vw_row
        ld a,d
        call vdt_dh_any
        jr nz,vw_row
        call vdt_cell
        jr vdt_right
vw_row:
        call vdt_row
; vdt_right: the cursor right, from the last column to the next row (from the last row to the first).
vdt_right:
        ld a,(cur_col)
        inc a
        cp VDT_COLS
        jr c,vr_set
        xor a
        ld (cur_col),a
        jr vdt_down
vr_set:
        ld (cur_col),a
        ret
vdt_left:
        ld a,(cur_col)
        or a
        jr z,vl_wrap
        dec a
        ld (cur_col),a
        ret
vl_wrap:
        ld a,VDT_COLS-1
        ld (cur_col),a
vdt_up:
        ld a,(cur_row)
        or a
        jr nz,vu_set
        ld a,VDT_ROWS
vu_set:
        dec a
        ld (cur_row),a
        ret
vdt_down:
        ld a,(cur_row)
        inc a
        cp VDT_ROWS
        jr c,vd_set
        xor a
vd_set:
        ld (cur_row),a
        ret
vdt_cr:
        xor a
        ld (cur_col),a
        ret
vdt_home:
        xor a
        ld (cur_row),a
        ld (cur_col),a
        ret

; vdt_raw_addr: HL = vdt_raw + D * 40 + E. Changes A.
vdt_raw_addr:
        push bc
        ld a,d
        add a,a
        add a,a
        add a,d
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,e
        call add_hl_a
        ld bc,vdt_raw
        add hl,bc
        pop bc
        ret

; vdt_dh_any: NZ when row D or the row above it has double height. Changes A, HL.
vdt_dh_any:
        ld hl,vdt_dh
        ld a,d
        call add_hl_a
        ld a,(hl)
        or a
        ret nz
        ld a,d
        or a
        ret z
        dec hl
        ld a,(hl)
        or a
        ret

; vdt_rowstart: the state at the start of a row: white letters on black, steady, normal height, contiguous.
; Changes A, HL.
vdt_rowstart:
        ld hl,vs_fg
        ld (hl),7
        inc hl
        ld a,6                  ; vs_bg, vs_mos, vs_sep, vs_flash, vs_dh, vs_conc
vrs_zero:
        ld (hl),0
        inc hl
        dec a
        jr nz,vrs_zero
        ret

; vdt_step: the next cell of a row with code A: B = its character, C = its attribute, vd_ext = its flags; the
; attributes change the state: set at the cell (steady, normal height, conceal, contiguous, separated, black and
; new background) or after it (colours of letters and mosaics, flash, double height). Changes A, HL.
vdt_step:
        cp 80h
        jp c,vst_show
        ld (vs_code),a
        cp 89h
        jr nz,vst_a1
        xor a
        ld (vs_flash),a
vst_a1:
        ld a,(vs_code)
        cp 8Ch
        jr nz,vst_a2
        xor a
        ld (vs_dh),a
vst_a2:
        ld a,(vs_code)
        cp 98h
        jr nz,vst_a3
        ld a,1
        ld (vs_conc),a
vst_a3:
        ld a,(vs_code)
        cp 99h
        jr nz,vst_a4
        xor a
        ld (vs_sep),a
vst_a4:
        ld a,(vs_code)
        cp 9Ah
        jr nz,vst_a5
        ld a,VDT_SEP
        ld (vs_sep),a
vst_a5:
        ld a,(vs_code)
        cp 9Ch
        jr nz,vst_a6
        xor a
        ld (vs_bg),a
vst_a6:
        ld a,(vs_code)
        cp 9Dh
        jr nz,vst_a7
        ld a,(vs_fg)
        ld (vs_bg),a
vst_a7:
        ld a,' '                ; the cell itself: a space
        call vst_show
        ld a,(vs_code)          ; set after
        cp 88h
        jr nz,vst_b1
        ld a,1
        ld (vs_flash),a
vst_b1:
        ld a,(vs_code)
        cp 8Dh
        jr nz,vst_b2
        ld a,VDT_DHT
        ld (vs_dh),a
vst_b2:
        ld a,(vs_code)          ; 81h-87h letters, 91h-97h mosaics in colour 1-7
        and 0Fh
        ret z
        cp 8
        ret nc
        ld (vs_fg),a
        xor a
        ld (vs_conc),a
        ld a,(vs_code)
        and VDT_MOS             ; 10h of 9xh
        ld (vs_mos),a
        ret
vst_show:                       ; the cell: character A in the state
        ld b,a
        ld a,(vs_conc)          ; concealed: in the colour of the background
        or a
        ld a,(vs_bg)
        jr nz,vss_fg
        ld a,(vs_fg)
vss_fg:
        ld c,a
        ld a,(vs_bg)
        rlca
        rlca
        rlca
        rlca
        or c
        ld c,a
        ld a,(vs_flash)
        or a
        jr z,vss_ext
        set 7,c
vss_ext:
        ld a,(vs_mos)
        ld hl,vs_sep
        or (hl)
        ld hl,vs_dh
        or (hl)
        or EXT_VDT
        ld (vd_ext),a
        ret

; vdt_cell: cell D, E of the shadow from its code (the state from the start of the row). Changes all.
vdt_cell:
        ld a,e
        ld (vc_col),a
        call vdt_rowstart
        ld e,0
vc_step:
        push de
        call vdt_raw_addr
        ld a,(hl)
        call vdt_step
        pop de
        ld a,(vc_col)
        cp e
        jr z,vc_set
        inc e
        jr vc_step
vc_set:
        ld a,(vd_ext)
        jp scr_set

; vdt_row: row D of the shadow from its codes; when its double height changed or it has some, the row below
; too (with the lower halves, or from its own codes again). Changes all.
vdt_row:
        ld a,d
        or a
        jr z,vr_top
        dec a
        ld hl,vdt_dh
        call add_hl_a
        ld a,(hl)
        or a
        jr nz,vdt_row_lower
vr_top:
        call vdt_rowstart
        xor a
        ld (vr_any),a
        ld e,0
vr_cell:
        push de
        call vdt_raw_addr
        ld a,(hl)
        call vdt_step
        ld a,(vd_ext)
        and VDT_DHT
        ld hl,vr_any
        or (hl)
        ld (hl),a
        pop de
        push de
        ld a,(vd_ext)
        call scr_set
        pop de
        inc e
        ld a,e
        cp VDT_COLS
        jr nz,vr_cell
        ld hl,vdt_dh
        ld a,d
        call add_hl_a
        ld a,(vr_any)
        ld b,(hl)
        ld (hl),a
        or b
        ret z                   ; no double height before or now
vr_below:
        ld a,d
        inc a
        cp VDT_ROWS
        ret nc
        ld d,a
        jr vdt_row

; vdt_row_lower: row D under a row with double height: the lower halves of that row, spaces in its background
; where it has single height. Changes all.
vdt_row_lower:
        call vdt_rowstart
        ld e,0
vrl_cell:
        push de
        dec d
        call vdt_raw_addr       ; the row above
        inc d
        ld a,(hl)
        call vdt_step
        ld a,(vd_ext)
        bit 6,a                 ; VDT_DHT
        jr z,vrl_blank
        xor VDT_DHT+VDT_DHB
        jr vrl_set
vrl_blank:
        ld a,c                  ; a space in the background
        and 70h
        ld c,a
        rrca
        rrca
        rrca
        rrca
        or c
        ld c,a
        ld b,' '
        ld a,EXT_VDT
vrl_set:
        pop de
        push de
        call scr_set
        pop de
        inc e
        ld a,e
        cp VDT_COLS
        jr nz,vrl_cell
        ld hl,vdt_dh            ; a lower row has no double height of its own
        ld a,d
        call add_hl_a
        ld a,(hl)
        ld (hl),0
        or a
        ret z
        jr vr_below             ; it had: the row below from its own codes again

; ga_vdt: (glyph_addr) the glyph of Viewdata character A with the flags B in vdt_glyph -> HL. Changes A.
ga_vdt:
        push bc
        push de
        ld c,a
        ld a,b
        ld (gv_flags),a
        ld a,c
        cp 80h
        jr nc,gv_blank          ; an attribute: a space
        bit 4,b                 ; VDT_MOS: 20h-3Fh and 60h-7Fh are blocks
        jr z,gv_alpha
        bit 5,a
        jr z,gv_alpha
        call gv_mosaic
        jr gv_height
gv_blank:
        ld hl,vdt_glyph
        ld b,8
gvb_line:
        ld (hl),0
        inc hl
        djnz gvb_line
        jr gv_height
gv_alpha:
        ld hl,vdt_alpha_map     ; the British characters
gva_find:
        ld b,(hl)
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,b
        or a
        jr z,gva_ata
        ld a,c
        cp b
        jr nz,gva_find
        ex de,hl
        jr gva_copy
gva_ata:
        ld l,c                  ; the others from font_ata
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,font_ata
        add hl,de
gva_copy:
        ld de,vdt_glyph
        ld bc,8
        ldir
gv_height:
        ld a,(gv_flags)
        and VDT_DHT+VDT_DHB
        jr z,gv_done
        ld hl,vdt_glyph         ; the upper or the lower half, each line twice
        and VDT_DHB
        jr z,gvh_half
        ld hl,vdt_glyph+4
gvh_half:
        ld de,vdt_dhbuf
        ld b,4
gvh_line:
        ld a,(hl)
        ld (de),a
        inc de
        ld (de),a
        inc de
        inc hl
        djnz gvh_line
        ld hl,vdt_dhbuf
        ld de,vdt_glyph
        ld bc,8
        ldir
gv_done:
        ld hl,vdt_glyph
        pop de
        pop bc
        ret

; gv_mosaic: the 2x3 blocks of mosaic A in vdt_glyph: bits 0 and 1 the upper third (rows 0-2), 2 and 3 the
; middle (3-4), 4 and 6 the lower (5-7), left and right half; separated: the last column and row of each block
; empty. Changes A, B, DE, HL.
gv_mosaic:
        ld d,a
        ld hl,vdt_glyph
        and 3
        ld b,3
        call gm_rows
        ld a,d
        rrca
        rrca
        and 3
        ld b,2
        call gm_rows
        ld a,d                  ; bit 4 left, bit 6 right
        rrca
        rrca
        rrca
        rrca
        and 1
        ld e,a
        ld a,d
        rrca
        rrca
        rrca
        rrca
        rrca
        and 2
        or e
        ld b,3
        call gm_rows
        ld a,(gv_flags)
        and VDT_SEP
        ret z
        ld hl,vdt_glyph         ; separated
        ld b,8
gms_mask:
        ld a,(hl)
        and 0EEh
        ld (hl),a
        inc hl
        djnz gms_mask
        xor a
        ld (vdt_glyph+2),a
        ld (vdt_glyph+4),a
        ld (vdt_glyph+7),a
        ret
gm_rows:                        ; B rows at HL of the pair A (bit 0 left, bit 1 right)
        ld e,0
        rrca
        jr nc,gmr_right
        ld e,0F0h
gmr_right:
        rrca
        jr nc,gmr_line
        ld a,e
        or 0Fh
        ld e,a
gmr_line:
        ld (hl),e
        inc hl
        djnz gmr_line
        ret

; the British characters: code, glyph; 00h ends it
vdt_alpha_map:
        defb 23h
        defw vdt_extra          ; pound
        defb 5Bh
        defw font_ata+1Eh*8     ; left arrow
        defb 5Ch
        defw vdt_extra+8        ; 1/2
        defb 5Dh
        defw font_ata+1Fh*8     ; right arrow
        defb 5Eh
        defw font_ata+1Ch*8     ; up arrow
        defb 5Fh
        defw font_ata+23h*8     ; #
        defb 60h
        defw font_ata+12h*8     ; dash
        defb 7Bh
        defw vdt_extra+16       ; 1/4
        defb 7Ch
        defw vdt_extra+32       ; double bar
        defb 7Dh
        defw vdt_extra+24       ; 3/4
        defb 7Eh
        defw vdt_extra+40       ; divide
        defb 7Fh
        defw vdt_extra+48       ; block
        defb 0

; ach_vdt: (and_char) the Viewdata character A with the flags B as a character of the AND-1V. Changes A, HL.
ach_vdt:
        cp 80h
        jr nc,acv_space
        bit 7,b                 ; the lower half: shown once only
        jr nz,acv_space
        bit 4,b
        jr z,acv_alpha
        bit 5,a
        jr z,acv_alpha
        ld l,a                  ; mosaic: the 2x3 graphics of the AND-1V (bits 0-4, 6 -> 0-5)
        and 1Fh
        bit 6,l
        jr z,acv_semi
        or 20h
acv_semi:
        or 80h
        ret
acv_alpha:
        ld hl,vdt_and_map
acv_find:
        cp (hl)
        inc hl
        jr z,acv_found
        inc hl
        bit 7,(hl)              ; the end: FFh
        jr z,acv_find
        ret                     ; as it is
acv_found:
        ld a,(hl)
        ret
acv_space:
        ld a,' '
        ret
vdt_and_map:
        defb 23h,'#', 5Bh,'<', 5Ch,'/', 5Dh,'>', 5Eh,5Eh, 5Fh,'#', 60h,'-', 7Bh,'/', 7Ch,'|', 7Dh,'/'
        defb 7Eh,'%', 7Fh,0BFh, 0FFh

; vdt_key: key A to a Viewdata BBS: Enter as # (5Fh, sends a choice), Backspace, the cursor keys; ASCII as it
; is. Changes all.
vdt_key:
        ld c,a
        ld hl,vdt_keys
vk_find:
        ld a,(hl)
        or a
        jr z,vk_plain
        inc hl
        cp c
        ld a,(hl)
        inc hl
        jp z,tx_data
        jr vk_find
vk_plain:
        ld a,c
        cp 80h
        ret nc
        jp tx_data
vdt_keys:
        defb 0Dh,5Fh, 7Fh,08h, 05h,0Bh, 18h,0Ah, 13h,08h, 04h,09h, 0C1h,0Bh, 0C2h,0Ah, 0C4h,08h, 0C3h,09h
        defb 0

; the colours of teletext: black, red, green, yellow, blue, magenta, cyan, white; 8-15 as ansi_rgb (texts)
vdt_rgb:
        defb 00h,00h,00h, 3Fh,00h,00h, 00h,3Fh,00h, 3Fh,3Fh,00h
        defb 00h,00h,3Fh, 3Fh,00h,3Fh, 00h,3Fh,3Fh, 3Fh,3Fh,3Fh
        defb 15h,15h,15h, 15h,15h,3Fh, 15h,3Fh,15h, 15h,3Fh,3Fh
        defb 3Fh,15h,15h, 3Fh,15h,3Fh, 3Fh,3Fh,15h, 3Fh,3Fh,3Fh
