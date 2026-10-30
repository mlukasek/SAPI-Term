; SAPI-Term - AND-1V output: 64x20 characters straight in the VRAM at F800h (MAP_CPM).
;
; Character set of the card: 00-0F single line box drawing, ASCII, 7Fh checkerboard, 80-BF block graphics 2x3,
; C0-FF KOI-8cs2 (docs/technika.md).

; and_cls: spaces in the visible rows 0-19. Changes A, BC, DE, HL.
and_cls:
        ld hl,AND_VRAM
        ld de,AND_VRAM+1
        ld bc,AND_COLS*AND_ROWS-1
        ld (hl),' '
        ldir
        ret

; --- the terminal in a window of 64x20 (view_x, view_y = its top left cell of the screen) ---

; and_char: A = character of the shadow, B = its flags -> A = code for the AND-1V (KOI-8cs2 letters as they
; are, CP437 through and_map_cp437). Changes HL.
and_char:
        bit 0,b
        ret nz
        ld l,a
        ld h,high and_map_cp437
        ld a,(hl)
        ret

; and_cell: code A at the screen cell D = row, E = column, when it is in the window. Changes A, HL.
and_cell:
        push bc
        push de
        ld c,a
        ld a,(view_y)
        ld b,a
        ld a,d
        sub b
        jr c,ac_done
        cp AND_ROWS
        jr nc,ac_done
        ld d,a
        ld a,(view_x)
        ld b,a
        ld a,e
        sub b
        jr c,ac_done
        cp AND_COLS
        jr nc,ac_done
        ld e,a
        ld l,d
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        or e
        ld l,a
        ld a,h
        add a,high AND_VRAM
        ld h,a
        ld (hl),c
ac_done:
        pop de
        pop bc
        ret

; and_render: the whole window from the shadow (cells outside the 80x25 screen are spaces). Changes all.
and_render:
        ld hl,AND_VRAM
        ld (ar_ptr),hl
        ld a,(view_y)
        ld d,a
        ld b,AND_ROWS
ar_row:
        push bc
        ld a,(view_x)
        ld e,a
        ld b,AND_COLS
ar_col:
        push bc
        push de
        ld a,d
        cp SCR_ROWS
        jr nc,ar_space
        ld a,e
        cp SCR_COLS
        jr nc,ar_space
        call scr_offset
        push hl
        ld bc,scr_ext
        add hl,bc
        ld b,(hl)
        pop hl
        ld de,scr_chr
        add hl,de
        ld a,(hl)
        call and_char
        jr ar_put
ar_space:
        ld a,' '
ar_put:
        ld hl,(ar_ptr)
        ld (hl),a
        inc hl
        ld (ar_ptr),hl
        pop de
        pop bc
        inc e
        djnz ar_col
        call kbd_scan
        pop bc
        inc d
        djnz ar_row
        ret

; and_scroll: after the region rg_top..rg_bot of the shadow scrolled up. The whole screen of 20 rows in a
; window at 0,0 moves its VRAM up and gets a row of spaces, anything else is drawn again. Changes all.
and_scroll:
        ld a,(view_y)
        ld b,a
        ld a,(view_x)
        or b
        ld b,a
        ld a,(rg_top)
        or b
        jr nz,and_render
        ld a,(rg_bot)
        cp AND_ROWS-1
        jr nz,and_render
        ld a,(term_rows)
        cp AND_ROWS
        jr nz,and_render
        ld hl,AND_VRAM+AND_COLS
        ld de,AND_VRAM
        ld bc,AND_COLS*(AND_ROWS-1)
        ldir
        ld hl,AND_VRAM+AND_COLS*(AND_ROWS-1)
        ld bc,AND_COLS
        ld a,' '
        jp fill

; and_at: D = row, E = column; the next and_putc writes there. Changes A.
and_at:
        push hl
        ld l,d
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,l
        add a,e
        ld l,a
        ld a,h
        adc a,high AND_VRAM
        ld h,a
        ld (and_ptr),hl
        pop hl
        ret

; and_putc: A on the screen, the position moves right. Changes nothing else.
and_putc:
        push hl
        ld hl,(and_ptr)
        ld (hl),a
        inc hl
        ld (and_ptr),hl
        pop hl
        ret

; and_puts: the string at HL up to a 00h byte; HL then points after it. Changes A, HL.
and_puts:
        ld a,(hl)
        inc hl
        or a
        ret z
        call and_putc
        jr and_puts

; and_dec8: A in decimal without leading zeros. Changes A.
and_dec8:
        push bc
        ld c,a
        xor a
        ld (ad_lead),a          ; no digit written yet
        ld a,c
        ld b,100
        call ad_digit
        ld b,10
        call ad_digit
        add a,'0'
        call and_putc
        pop bc
        ret
ad_digit:                       ; B = 100 or 10; the digit A / B unless it is a leading zero, A = A mod B
        ld c,'0'-1
ad_sub:
        inc c
        sub b
        jr nc,ad_sub
        add a,b
        push af
        ld a,c
        cp '0'
        jr nz,ad_put
        ld a,(ad_lead)
        or a
        jr z,ad_skip
        ld a,'0'
ad_put:
        call and_putc
        ld a,1
        ld (ad_lead),a
ad_skip:
        pop af
        ret

; and_hex16: HL as four hex digits. Changes A.
and_hex16:
        ld a,h
        call and_hex8
        ld a,l
; and_hex8: A as two hex digits. Changes A.
and_hex8:
        push af
        rrca
        rrca
        rrca
        rrca
        call and_nibble
        pop af
and_nibble:
        and 0Fh
        add a,90h
        daa
        adc a,40h
        daa
        jr and_putc
