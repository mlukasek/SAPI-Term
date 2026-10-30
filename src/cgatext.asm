; SAPI-Term - text 80x25 on the CGA-1V: font 4x8 in the EGA mode, pairs of colours, scrolling, cursor.
;
; A character = 1 byte on each of its 8 lines: 4 dots from the font in D7..D4, the number of its pair of colours
; (slot 0-15) in D3..D0. A slot is a pair background / foreground; the same 16 slots in all 7 domains of the
; palette (docs/technika.md). Slots are given to the attributes (bg << 4 | fg, CGA colours) as the screen
; needs them, with a count of the cells that use each; when all 16 are used, the nearest pair is taken.
; Routines that touch the VRAM need MAP_CGA (marked); the pair bookkeeping does not.

; glyph_addr: A = character, B = flags (EXT_KOI: KOI-8cs2 C0-FF from font_koi, else CP437) -> HL = glyph.
; Changes A.
glyph_addr:
        bit 0,b
        jr nz,ga_koi
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,high font_cp437
        ld h,a
        ret
ga_koi:
        sub 0C0h
        jr nc,ga_koi_ok
        xor a                   ; not a KOI letter: the empty glyph C0h
ga_koi_ok:
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,high font_koi
        ld h,a
        ret

; cga_cell_addr: D = row, E = column -> HL = VRAM address of the first line of the cell. Changes A.
cga_cell_addr:
        ld a,d
        add a,a
        ld l,a
        ld h,high cga_rows      ; page aligned table
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,e
        ld l,a
        ret nc
        inc h
        ret

; cga_draw: the glyph at HL at D = row, E = column with slot C. MAP_CGA. Changes A, B, DE, HL.
cga_draw:
        push hl
        call cga_cell_addr
        pop de
        ld b,8
cdr_line:
        ld a,(de)
        inc e                   ; glyphs are 8 bytes, 8-aligned
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,cdr_next
        inc h
cdr_next:
        djnz cdr_line
        ret

; cga_cursor_xor: invert the dots of the last line of the cell D = row, E = column (an underline in the
; foreground colour of the cell). MAP_CGA. Changes A, DE, HL.
cga_cursor_xor:
        call cga_cell_addr
        ld de,7*80
        add hl,de
        ld a,(hl)
        xor 0F0h
        ld (hl),a
        ret

; cga_fill_rows: text rows D to D + E - 1 filled with the byte A (slot A, no dots). MAP_CGA. The keyboard is
; polled after each row. Changes A, BC, DE, HL.
cga_fill_rows:
        ld (cf_byte),a
        ld a,e
        or a
        ret z
        ld (cf_count),a
        ld e,0
        call cga_cell_addr
cfr_row:
        ld a,(cf_byte)
        ld (hl),a
        ld d,h
        ld e,l
        inc de
        ld bc,639
        ldir
        ex de,hl                ; HL = start of the next row
        call kbd_scan
        ld a,(cf_count)
        dec a
        ld (cf_count),a
        jr nz,cfr_row
        ret

; cga_scroll: text rows 1 to A - 1 move up by one row, the last row (A - 1) is filled with the slot C.
; 80-byte pieces with unrolled LDI, the keyboard polled after each (0.4 ms at 4 MHz). MAP_CGA.
; Changes A, BC, DE, HL.
cga_scroll:
        push bc
        ld d,a
        dec d                   ; D = last row
        push de
        ld a,d
        or a
        jp z,csc_fill           ; one row only
        ld e,a                  ; pieces = (rows - 1) * 8
        ld a,0
csc_mul:
        add a,8
        dec e
        jr nz,csc_mul
        ld (cf_count),a
        ld hl,CGA_VRAM+640
        ld de,CGA_VRAM
csc_piece:
        rept 80
        ldi
        endm
        call kbd_scan
        ld a,(cf_count)
        dec a
        ld (cf_count),a
        jp nz,csc_piece
csc_fill:
        pop de                  ; D = last row
        pop bc
        ld a,c
        ld e,1
        jp cga_fill_rows

; --- pairs of colours ---

; pair_init: no attribute has a slot, all counts 0, nothing to write to the palette. Changes A, B, HL.
pair_init:
        ld hl,att_slot
        ld b,0
pi_att:
        ld (hl),0FFh
        inc l
        djnz pi_att
        ld hl,slot_ref
        ld b,32
pi_ref:
        ld (hl),0
        inc hl
        djnz pi_ref
        ld hl,0
        ld (pal_dirty),hl
        ret

; pair_get: A = attribute -> A = its slot, the count of the slot + 1. A free slot (count 0) is given to a new
; attribute and marked for the palette; with none free the nearest used pair is taken. Changes BC, DE, HL.
pair_get:
        ld l,a
        ld h,high att_slot
        ld a,(hl)
        cp 16
        jr c,pair_ref           ; it has a slot (exact or nearest)
        ld c,l                  ; C = attribute
        ld hl,slot_ref
        ld b,0
pg_find:
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        jr z,pg_free
        inc b
        ld a,b
        cp 16
        jr nz,pg_find
        ld a,c                  ; all used: the nearest pair
        call pair_nearest
        ld l,c
        ld h,high att_slot
        ld (hl),a
        jr pair_ref
pg_free:                        ; B = free slot, C = attribute
        ld a,b
        call pair_unmap
        ld hl,slot_att
        ld a,l
        add a,b
        ld l,a
        jr nc,pg_set
        inc h
pg_set:
        ld (hl),c
        ld l,c
        ld h,high att_slot
        ld (hl),b
        ld a,b
        call pal_mark
        ld a,b
; pair_ref: the count of slot A + 1; A stays. Changes DE, HL.
pair_ref:
        push af
        add a,a
        ld e,a
        ld d,0
        ld hl,slot_ref
        add hl,de
        inc (hl)
        jr nz,prf_done
        inc hl
        inc (hl)
prf_done:
        pop af
        ret

; pair_add: the count of slot A + DE. Changes A, DE, HL.
pair_add:
        push de
        add a,a
        ld e,a
        ld d,0
        ld hl,slot_ref
        add hl,de
        pop de
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        ret

; pair_unref: the count of the slot of attribute A - 1. Changes A, DE, HL.
pair_unref:
        ld l,a
        ld h,high att_slot
        ld a,(hl)
        cp 16
        ret nc                  ; no slot (cannot happen for a cell on the CGA-1V)
        add a,a
        ld e,a
        ld d,0
        ld hl,slot_ref
        add hl,de
        ld a,(hl)
        sub 1
        ld (hl),a
        ret nc
        inc hl
        dec (hl)
        ret

; pair_unmap: attributes that have slot A lose it. Changes HL.
pair_unmap:
        ld hl,att_slot
pu_loop:
        cp (hl)
        jr nz,pu_next
        ld (hl),0FFh
pu_next:
        inc l
        jr nz,pu_loop
        ret

; pair_nearest: A = attribute -> A = the slot whose pair is the nearest (colour distance of the foreground
; + 2 x of the background). Changes BC, DE, HL.
pair_nearest:
        ld c,a
        ld hl,0FFFFh
        ld (pn_best),hl
        xor a
        ld (pn_slot),a
        ld b,15
pn_loop:
        ld hl,slot_att
        ld a,l
        add a,b
        ld l,a
        jr nc,pn_att
        inc h
pn_att:
        ld e,(hl)               ; E = attribute of slot B
        ld a,c
        and 0F0h
        ld d,a
        ld a,e
        rrca
        rrca
        rrca
        rrca
        and 0Fh
        or d
        ld l,a
        ld h,high col_dist
        ld d,(hl)               ; D = background distance
        ld a,c
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        ld l,a
        ld a,e
        and 0Fh
        or l
        ld l,a
        ld e,(hl)               ; E = foreground distance
        ld l,d
        ld h,0
        add hl,hl
        ld d,0
        add hl,de
        ld de,(pn_best)
        or a
        sbc hl,de
        jr nc,pn_next
        add hl,de
        ld (pn_best),hl
        ld a,b
        ld (pn_slot),a
pn_next:
        dec b
        jp p,pn_loop
        ld a,(pn_slot)
        ret

; pair_used: A = the number of slots with a count above 0. Changes BC, HL.
pair_used:
        ld hl,slot_ref
        ld b,16
        ld c,0
pus_loop:
        ld a,(hl)
        inc hl
        or (hl)
        inc hl
        jr z,pus_next
        inc c
pus_next:
        djnz pus_loop
        ld a,c
        ret

; pal_mark: slot A must get its colours in the palette. Changes A, HL.
pal_mark:
        push bc
        ld hl,1
        or a
        jr z,pm_set
        ld b,a
pm_shift:
        add hl,hl
        djnz pm_shift
pm_set:
        ld a,(pal_dirty)
        or l
        ld (pal_dirty),a
        ld a,(pal_dirty+1)
        or h
        ld (pal_dirty+1),a
        pop bc
        ret

; pal_flush: when some slots got new pairs, wait for the VBI (the keyboard is polled) and write their
; colours to all 7 domains. MAP_CGA. Changes A, BC, DE, HL.
pal_flush:
        ld hl,(pal_dirty)
        ld a,h
        or l
        ret z
        call cga_wait_vbi
        ld hl,(pal_dirty)
        ld b,0
pf_loop:
        srl h
        rr l
        jr nc,pf_next
        push hl
        push bc
        call pal_slot
        pop bc
        pop hl
pf_next:
        inc b
        ld a,h
        or l
        jr nz,pf_loop
        ld (pal_dirty),hl
        ret

; pal_slot: palette entries d * 32 + 2 * B (background) and + 1 (foreground) for the domains d = 0-6, from the
; pair of slot B. MAP_CGA. Changes A, BC, DE, HL.
pal_slot:
        ld hl,slot_att
        ld a,l
        add a,b
        ld l,a
        jr nc,ps_att
        inc h
ps_att:
        ld a,(hl)
        push af
        rrca
        rrca
        rrca
        rrca
        ld de,ps_rgb
        call ps_copy            ; background
        pop af
        call ps_copy            ; foreground
        ld a,b
        add a,a
        ld c,a                  ; C = entry in domain 0
        ld b,7
ps_domain:
        ld a,c
        ld (CGA_PAL_ADR),a
        ld hl,ps_rgb
        ld a,(hl)
        ld (CGA_PAL_DAT),a
        inc hl
        ld a,(hl)
        ld (CGA_PAL_DAT),a
        inc hl
        ld a,(hl)
        ld (CGA_PAL_DAT),a
        inc hl
        ld a,(hl)
        ld (CGA_PAL_DAT),a
        inc hl
        ld a,(hl)
        ld (CGA_PAL_DAT),a
        inc hl
        ld a,(hl)
        ld (CGA_PAL_DAT),a
        ld a,c
        add a,32
        ld c,a
        djnz ps_domain
        ret
ps_copy:                        ; colour A & 0Fh -> 3 bytes at DE
        and 0Fh
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        push bc
        ld bc,ansi_rgb
        add hl,bc
        ld bc,3
        ldir
        pop bc
        ret
