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
