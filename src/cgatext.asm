; SAPI-Term - text 80x25 on the CGA-1V: font 4x8 in the EGA mode, pairs of colours per domain, scrolling,
; cursor.
;
; A character = 1 byte on each of its 8 lines: 4 dots from the font in D7..D4, the number of its pair of colours
; (slot 0-15) in D3..D0. Colour index = domain << 5 | slot << 1 | dot with domain = line >> 5 = text row >> 2:
; each domain (4 text rows, the 7th only row 24) has its own 16 slots, each a pair background / foreground
; (docs/technika.md). Slots are given to the attributes (bg << 4 | fg) as the cells need them, with a count of
; the cells per slot; when all 16 of a domain are used, the nearest pair is taken. An attribute tries to get the
; same slot number in every domain (att_pref), so a row that scrolls into the next domain mostly keeps its bytes.
; The pair routines work on the domain chosen by pair_setdom. Routines that touch the VRAM need MAP_CGA.

DOMAINS         equ 7

; glyph_addr: A = character, B = flags (EXT_KOI: KOI-8cs2 C0-FF from font_koi, EXT_8X8: font_pet, else CP437)
; -> HL = glyph. Changes A.
glyph_addr:
        bit 1,b
        jr nz,ga_pet
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
ga_pet:                         ; 8 dots a line (pet.asm), drawn in 40 columns as they are
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,h
        add a,high font_pet
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

; cga_cell_addr: D = row, E = column -> HL = VRAM address of the first line of the cell (in 40 columns a cell
; is 2 bytes). Changes A.
cga_cell_addr:
        ld a,d
        add a,a
        ld l,a
        ld h,high cga_rows      ; page aligned table
        ld a,(hl)
        inc l
        ld h,(hl)
        add a,e
        jr nc,cca_one
        inc h
cca_one:
        ld l,a
        ld a,(cga_wide)
        or a
        ret z
        ld a,l
        add a,e
        ld l,a
        ret nc
        inc h
        ret

; cga_clip: in 40 columns, B cells from column E are cut at column 40 and B doubled to bytes (0 when none is
; seen); in 80 columns nothing changes. Changes A.
cga_clip:
        ld a,(cga_wide)
        or a
        ret z
        ld a,e
        cp SCR_COLS/2
        jr nc,ccl_none
        add a,b
        cp SCR_COLS/2+1
        jr c,ccl_double
        ld a,SCR_COLS/2
        sub e
        ld b,a
ccl_double:
        sla b
        ret
ccl_none:
        ld b,0
        ret

; cga_draw: the glyph at HL at D = row, E = column with slot C, 8 lines unrolled (glyphs are 8 bytes,
; 8-aligned: inc e). MAP_CGA. Changes A, B, DE, HL.
cga_draw:
        ld a,(cga_wide)
        or a
        jr nz,cga_draw_wide
        push hl
        call cga_cell_addr
        pop de
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        inc e
        or c
        ld (hl),a
        ld a,l
        add a,80
        ld l,a
        jr nc,$+3
        inc h
        ld a,(de)
        or c
        ld (hl),a
        ret

; cga_draw_wide: cga_draw in 40 columns: each dot of the glyph doubled (wide_l, wide_r), 2 bytes a line;
; columns from 40 on are not seen. MAP_CGA. Changes A, B, DE, HL.
cga_draw_wide:
        ld a,e
        cp SCR_COLS/2
        ret nc
        ld a,h                  ; a glyph of font_pet: 8 dots, not doubled
        cp high font_pet
        jr nc,cga_draw_8
        push hl
        call cga_cell_addr
        pop de
        ld b,8
cdw_line:
        ld a,(de)
        push de
        ld e,a
        ld d,high wide_l
        ld a,(de)
        or c
        ld (hl),a
        inc hl
        inc d                   ; wide_r
        ld a,(de)
        or c
        ld (hl),a
        ld de,79
        add hl,de
        pop de
        inc e
        djnz cdw_line
        ret

; cga_draw_8: a glyph of 8 dots a line in 40 columns: the left four dots to the first byte, the right four to
; the second. MAP_CGA. Changes A, B, DE, HL.
cga_draw_8:
        push hl
        call cga_cell_addr
        pop de
        ld b,8
cd8_line:
        ld a,(de)
        and 0F0h
        or c
        ld (hl),a
        inc hl
        ld a,(de)
        rlca
        rlca
        rlca
        rlca
        and 0F0h
        or c
        ld (hl),a
        inc e
        ld a,l
        add a,79
        ld l,a
        jr nc,cd8_next
        inc h
cd8_next:
        djnz cd8_line
        ret

; cga_cursor_xor: invert the dots of the last line of the cell D = row, E = column (an underline in the
; foreground colour of the cell). MAP_CGA. Changes A, DE, HL.
cga_cursor_xor:
        ld a,(cga_wide)
        or a
        jr z,cx_cell
        ld a,e
        cp SCR_COLS/2
        ret nc
cx_cell:
        call cga_cell_addr
        ld de,7*80
        add hl,de
        ld a,(hl)
        xor 0F0h
        ld (hl),a
        ld a,(cga_wide)
        or a
        ret z
        inc hl
        ld a,(hl)
        xor 0F0h
        ld (hl),a
        ret

; cga_fill_rows: text rows D to D + E - 1 filled with the byte A (slot A, no dots). MAP_CGA. The keyboard is
; polled after every line of 80 bytes (0.5 ms at 4 MHz). Changes A, BC, DE, HL.
cga_fill_rows:
        ld (cf_byte),a
        ld a,e
        or a
        ret z
        add a,a
        add a,a
        add a,a
        ld (cf_count),a         ; lines
        ld e,0
        call cga_cell_addr
        ld a,(cf_byte)
        ld (hl),a               ; the first byte, then each line copies the one before it
        ld d,h
        ld e,l
        inc de
        ld bc,79
        ldir
        jr cfr_next
cfr_line:
        ld bc,80
        ldir
cfr_next:
        call kbd_scan
        ld a,(cf_count)
        dec a
        ld (cf_count),a
        jr nz,cfr_line
        ret

; cga_fill_cells: B cells from D = row, E = column filled with the byte A (all 8 lines), the keyboard polled
; after each line. MAP_CGA. Changes A, BC, DE, HL.
cga_fill_cells:
        ld (cf_byte),a
        call cga_clip
        ld a,b
        or a
        ret z
        ld (cf_count),a
        call cga_cell_addr
        ld c,8
cfc_line:
        push hl
        ld a,(cf_count)
        ld b,a
        ld a,(cf_byte)
cfc_byte:
        ld (hl),a
        inc hl
        djnz cfc_byte
        pop hl
        ld de,80
        add hl,de
        call kbd_scan
        dec c
        jr nz,cfc_line
        ret

; cga_move_cells: in row D, B cells from column C move to column E (all 8 lines; to the right from the end;
; in 40 columns only the cells seen, as bytes). MAP_CGA. Changes all.
cga_move_cells:
        ld a,(cga_wide)
        or a
        jr z,cm_go
        ld a,c
        cp e
        jr nc,cm_max
        ld a,e
cm_max:                         ; A = the greater column
        cp SCR_COLS/2
        ret nc
        ld h,a
        ld a,SCR_COLS/2
        sub h                   ; cells seen from it
        cp b
        jr nc,cm_double
        ld b,a
cm_double:
        sla b
        sla c
        sla e
cm_go:
        ld a,b
        or a
        ret z
        ld (cm_count),a
        ld a,c
        ld (cm_src),a
        ld a,e
        ld (cm_dst),a
        ld e,0
        call cga_cell_addr      ; HL = start of the row
        ld a,8
        ld (cm_lines),a
cm_line:
        push hl
        ld a,(cm_dst)
        ld e,a
        ld d,0
        push hl
        add hl,de
        ex de,hl                ; DE = destination
        pop hl
        ld a,(cm_src)
        ld c,a
        ld b,0
        add hl,bc               ; HL = source
        ld a,(cm_count)
        ld c,a                  ; BC = count
        ld a,(cm_dst)
        ld b,a
        ld a,(cm_src)
        cp b
        ld b,0
        jr c,cm_right           ; source left of destination: copy from the end
        ldir
        jr cm_next
cm_right:
        dec bc
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        inc bc
        lddr
cm_next:
        pop hl
        ld de,80
        add hl,de
        ld a,(cm_lines)
        dec a
        ld (cm_lines),a
        jr nz,cm_line
        ret

; cga_copy_row: text row D copied to text row E (640 bytes in pieces of 80 with unrolled LDI, the keyboard
; polled after each piece: 0.4 ms at 4 MHz). MAP_CGA. Changes all.
cga_copy_row:
        push de
        ld e,0
        call cga_cell_addr      ; source
        pop de
        push hl
        ld d,e
        ld e,0
        call cga_cell_addr      ; destination
        ex de,hl
        pop hl
        ld a,8
        ld (cf_count),a
ccr_piece:
        rept 80
        ldi
        endm
        call kbd_scan
        ld a,(cf_count)
        dec a
        ld (cf_count),a
        jp nz,ccr_piece
        ret

; cga_fix_cells: B cells of row D from column E get slot C (the dots stay), the keyboard polled after each
; line. MAP_CGA. Changes A, B, E, HL.
cga_fix_cells:
        call cga_clip
        ld a,b
        or a
        ret z
        ld (cf_count),a
        call cga_cell_addr
        ld e,8
cfx_line:
        push hl
        ld a,(cf_count)
        ld b,a
cfx_cell:
        ld a,(hl)
        and 0F0h
        or c
        ld (hl),a
        inc hl
        djnz cfx_cell
        pop hl
        ld a,l
        add a,80
        ld l,a
        jr nc,cfx_next
        inc h
cfx_next:
        call kbd_scan           ; a line of 80 cells takes up to 1 ms at 4 MHz
        dec e
        jr nz,cfx_line
        ret

; --- pairs of colours ---

; pair_init: no attribute has a slot in any domain, all counts 0, nothing to write to the palette, domain 0.
; Changes A, BC, DE, HL.
pair_init:
        ld hl,att_slot
        ld bc,DOMAINS*256
        ld a,0FFh
        call fill
        ld hl,att_pref
        ld bc,256
        ld a,0FFh
        call fill
        ld hl,slot_ref
        ld bc,DOMAINS*32
        xor a
        call fill
        ld hl,pal_dirty
        ld bc,DOMAINS*2
        xor a
        call fill
        ld hl,slot_att          ; owners: attribute 0 (pair_unmap checks that it has the slot)
        ld bc,DOMAINS*16
        xor a
        call fill
        ld hl,near_n
        ld bc,DOMAINS
        xor a
        call fill
        ld a,0FFh               ; no domain chosen yet
        ld (pair_dom),a
        xor a
; pair_setdom: domain A (0-6) for the pair routines (nothing to do when it is chosen already). Changes A.
pair_setdom:
        push hl
        ld hl,pair_dom
        cp (hl)
        pop hl
        ret z
        ld (pair_dom),a
        push de
        push hl
        ld e,a
        add a,high att_slot
        ld (pd_page),a
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,slot_att
        add hl,de
        ld (pd_satt),hl
        ld a,(pair_dom)
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        ld l,a
        ld h,0
        ld de,slot_ref
        add hl,de
        ld (pd_sref),hl
        pop hl
        pop de
        ret

; pair_row_dom: the domain of row A (A >> 2) for the pair routines. Changes A.
pair_row_dom:
        rrca
        rrca
        and 3Fh
        jr pair_setdom

; slot_count: HL = address of the count of slot B in the domain, Z when the count is 0. Changes A.
slot_count:
        ld hl,(pd_sref)
        ld a,b
        add a,a
        add a,l
        ld l,a
        jr nc,sct_load
        inc h
sct_load:
        ld a,(hl)
        inc hl
        or (hl)
        dec hl
        ret

; pair_get: A = attribute -> A = its slot in the domain, the count of the slot + 1. A free slot (count 0) is
; given to a new attribute, its preferred slot number first, and marked for the palette; with none free the
; nearest used pair is taken. pair_get_hint: a free slot B is taken before the preferred one (a row that
; scrolled into the domain keeps its slot numbers when it can). Changes BC, DE, HL.
pair_get:
        ld b,0FFh
pair_get_hint:
        ld l,a
        ld a,(pd_page)
        ld h,a
        ld a,(hl)
        cp 16
        jr c,pair_ref           ; it has a slot (exact or nearest)
        ld c,l                  ; C = attribute
        ld a,b
        cp 16
        jr nc,pg_pref
        call slot_count
        jr z,pg_free            ; the hint is free here
pg_pref:
        ld h,high att_pref
        ld l,c
        ld a,(hl)
        cp 16
        jr nc,pg_scan
        ld b,a
        call slot_count
        jr z,pg_free            ; the preferred slot is free here
pg_scan:
        ld b,0
pg_find:
        call slot_count
        jr z,pg_free
        inc b
        ld a,b
        cp 16
        jr nz,pg_find
        ld a,c                  ; all used: the nearest pair
        call pair_nearest
        ld b,a
        ld a,(pair_dom)         ; one more attribute on a pair not its own
        ld hl,near_n
        call add_hl_a
        inc (hl)
        ld a,(pd_page)
        ld h,a
        ld l,c
        ld (hl),b
        ld a,b
        jr pair_ref
pg_free:                        ; B = free slot, C = attribute
        ld a,b
        call pair_unmap
        ld hl,(pd_satt)
        ld a,l
        add a,b
        ld l,a
        jr nc,pg_set
        inc h
pg_set:
        ld (hl),c
        ld a,(pd_page)
        ld h,a
        ld l,c
        ld (hl),b
        ld h,high att_pref      ; the first slot of an attribute becomes its preferred one
        ld a,(hl)
        cp 16
        jr c,pg_mark
        ld (hl),b
pg_mark:
        ld a,b
        call pal_mark
        ld a,b
; pair_ref: the count of slot A in the domain + 1; A stays. Changes B, HL.
pair_ref:
        ld b,a
        call slot_count
        inc (hl)
        jr nz,prf_done
        inc hl
        inc (hl)
prf_done:
        ld a,b
        ret

; pair_add: the count of slot A in the domain + DE. Changes A, HL.
pair_add:
        push bc
        ld b,a
        call slot_count
        pop bc
        ld a,(hl)
        add a,e
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,d
        ld (hl),a
        ret

; pair_unref: the count of the slot of attribute A in the domain - 1. pair_sub: - DE. Changes A, DE, HL.
pair_unref:
        ld de,1
pair_sub:
        ld l,a
        ld a,(pd_page)
        ld h,a
        ld a,(hl)
        cp 16
        ret nc                  ; no slot (cannot happen for a cell on the CGA-1V)
        push bc
        ld b,a
        call slot_count
        pop bc
        ld a,(hl)
        sub e
        ld (hl),a
        inc hl
        ld a,(hl)
        sbc a,d
        ld (hl),a
        ret

; pair_unmap: attributes that have slot A in the domain lose it: its old owner (slot_att), and the
; attributes that got it as the nearest pair, when the domain has any (near_n; the scan of all 256 takes 1.3 ms
; at 4 MHz, the keyboard is polled every 64 entries). Changes DE, HL.
pair_unmap:
        push af
        push bc
        ld c,a
        ld hl,(pd_satt)
        add a,l
        ld l,a
        jr nc,pu_owner
        inc h
pu_owner:
        ld l,(hl)               ; the old owner
        ld a,(pd_page)
        ld h,a
        ld a,(hl)
        cp c
        jr nz,pu_near
        ld (hl),0FFh
pu_near:
        ld a,(pair_dom)
        ld hl,near_n
        call add_hl_a
        ld a,(hl)
        or a
        jr z,pu_done
        push hl
        ld a,(pd_page)
        ld h,a
        ld l,0
        ld e,64
        ld b,0                  ; B = taken from the nearest ones
pu_loop:
        ld a,c
        cp (hl)
        jr nz,pu_next
        ld (hl),0FFh
        inc b
pu_next:
        inc l
        jr z,pu_end
        dec e
        jr nz,pu_loop
        ld e,64
        call kbd_scan
        jr pu_loop
pu_end:
        pop hl
        ld a,(hl)
        sub b
        jr nc,pu_count
        xor a
pu_count:
        ld (hl),a
pu_done:
        pop bc
        pop af
        ret
kbd_scan_a:                     ; kbd_scan keeping A
        push af
        call kbd_scan
        pop af
        ret

; pair_nearest: A = attribute -> A = the slot of the domain whose pair is the nearest (colour distance of the
; foreground + 2 x of the background). Changes BC, DE, HL.
pair_nearest:
        ld c,a
        ld hl,0FFFFh
        ld (pn_best),hl
        xor a
        ld (pn_slot),a
        ld b,15
pn_loop:
        ld hl,(pd_satt)
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

; pair_used: A = the most slots in use in one domain. Changes BC, DE, HL.
pair_used:
        ld hl,slot_ref
        ld d,DOMAINS
        ld e,0
pus_dom:
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
        cp e
        jr c,pus_less
        ld e,a
pus_less:
        call kbd_scan
        dec d
        jr nz,pus_dom
        ld a,e
        ret

; pair_move_row: the cells of row D came from domain A (the row scrolled into another domain). Their counts
; move from domain A to the domain of row D, each run of one attribute at once; a run that has to change its
; slot number gets the new one in the VRAM. Changes all except D.
pair_move_row:
        push de
        ld (pm_from),a
        ld a,d
        rrca
        rrca
        and 3Fh
        ld (pm_to),a
        xor a
        ld (pm_col),a
        ld e,0
        call scr_offset
        ld bc,scr_att
        add hl,bc
        ld b,SCR_COLS
pm_run:
        ld a,(hl)
        ld (pm_att),a
        ld c,0
pm_len:
        inc c
        inc hl
        dec b
        jr z,pm_end
        cp (hl)
        jr z,pm_len
pm_end:
        ld (pm_ptr),hl
        ld a,b
        ld (pm_left),a
        ld a,c
        ld (pm_n),a
        call kbd_scan
        ld a,(pm_from)
        call pair_setdom
        ld a,(pm_att)
        ld l,a
        ld a,(pd_page)
        ld h,a
        ld a,(hl)
        ld (pm_old),a
        ld a,(pm_n)
        ld e,a
        ld d,0
        ld a,(pm_att)
        call pair_sub
        call kbd_scan
        ld a,(pm_to)
        call pair_setdom
        ld a,(pm_old)
        ld b,a
        ld a,(pm_att)
        call pair_get_hint
        ld (pm_new),a
        call kbd_scan
        ld a,(pm_n)
        dec a
        ld e,a
        ld d,0
        ld a,(pm_new)
        call pair_add
        ld a,(pm_new)
        ld hl,pm_old
        cp (hl)
        jr z,pm_same
        pop de                  ; another slot number: the cells of the run in the VRAM
        push de
        ld a,(pm_col)
        ld e,a
        ld a,(pm_n)
        ld b,a
        ld a,(pm_new)
        ld c,a
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_fix_cells
        ld a,MAP_CPM
        out (MAPREG),a
pm_same:
        call kbd_scan           ; a run takes up to 0.3 ms
        ld a,(pm_col)
        ld hl,pm_n
        add a,(hl)
        ld (pm_col),a
        ld hl,(pm_ptr)
        ld a,(pm_left)
        ld b,a
        or a
        jp nz,pm_run
        pop de
        ret

; blink_tick: one tick of 60 Hz: every BLINK_TICKS the blinking text (bit 7 of the attribute without iCE) is
; shown or hidden through the palette (pal_flush writes it). Changes all.
blink_tick:
        ld a,(ice_mode)
        or a
        ret nz
        ld a,(term_dev)
        cp DEV_CGA
        ret nz
        ld a,(blink_ticks)
        inc a
        ld (blink_ticks),a
        cp BLINK_TICKS
        ret c
        xor a
        ld (blink_ticks),a
        ld a,(blink_on)
        xor 1
        ld (blink_on),a
; blink_mark: every slot with bit 7 in its attribute must get its colours again. Changes all.
blink_mark:
        ld a,(has_cga)
        or a
        ret z
        ld hl,slot_att
        ld c,0
bm_dom:
        ld de,0
        ld b,16
bm_slot:                        ; bit n of DE = slot n has bit 7
        srl d
        rr e
        ld a,(hl)
        inc hl
        and 80h
        or d
        ld d,a
        djnz bm_slot
        push hl
        ld a,c
        add a,a
        ld hl,pal_dirty
        call add_hl_a
        ld a,(hl)
        or e
        ld (hl),a
        inc hl
        ld a,(hl)
        or d
        ld (hl),a
        pop hl
        inc c
        ld a,c
        cp DOMAINS
        jr nz,bm_dom
        ret

; pal_mark: slot A of the domain must get its colours in the palette. Changes A, HL.
pal_mark:
        push bc
        push de
        ld hl,1
        or a
        jr z,pmk_set
        ld b,a
pmk_shift:
        add hl,hl
        djnz pmk_shift
pmk_set:
        ex de,hl
        ld a,(pair_dom)
        add a,a
        ld l,a
        ld h,0
        ld bc,pal_dirty
        add hl,bc
        ld a,(hl)
        or e
        ld (hl),a
        inc hl
        ld a,(hl)
        or d
        ld (hl),a
        pop de
        pop bc
        ret

; pal_flush: when some slots got new pairs, wait for the VBI (the keyboard is polled) and write their
; colours to the palette of their domains, at most PAL_PER_VBI pairs in one VBI (a pair with the keyboard poll
; takes about 1000 T with the waits of the card; the VBI is 125 lines, 3.97 ms, 15900 T at 4 MHz; 16 pairs
; were just too many after the blink test in pal_slot), then the next VBI. MAP_CGA. Changes A, BC, DE, HL.
PAL_PER_VBI     equ 14
pal_flush:
        ld hl,pal_dirty
        ld b,DOMAINS*2
        xor a
pf_any:
        or (hl)
        inc hl
        djnz pf_any
        or a
        ret z
        call cga_wait_vbi
        ld a,PAL_PER_VBI
        ld (pf_budget),a
        ld c,0
pf_dom:
        ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,pal_dirty
        add hl,de
        ld e,(hl)
        ld (hl),0
        inc hl
        ld d,(hl)
        ld (hl),0
        ex de,hl                ; HL = slots of domain C to write
        ld b,0
pf_slot:
        ld a,h
        or l
        jr z,pf_next
        srl h
        rr l
        jr nc,pf_skip
        push hl
        push bc
        ld a,(pf_budget)        ; this VBI is used up: wait for the next one
        dec a
        jr nz,pf_write
        call cga_wait_vbi
        ld a,PAL_PER_VBI
pf_write:
        ld (pf_budget),a
        pop bc
        push bc
        call pal_slot
        call kbd_scan
        pop bc
        pop hl
pf_skip:
        inc b
        jr pf_slot
pf_next:
        inc c
        ld a,c
        cp DOMAINS
        jr nz,pf_dom
        ret

; pal_slot: palette entries 32 * C + 2 * B (background) and + 1 (foreground) from the pair of slot B in
; domain C. Bit 7 of the attribute without iCE is blink: the background is 0-7 and in the hidden phase of
; blink_on the foreground is the background. MAP_CGA. Changes A, DE, HL.
pal_slot:
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        ld e,a
        ld d,0
        ld hl,slot_att
        add hl,de
        ld a,(hl)
        bit 7,a
        jr z,ps_pair
        ld l,a
        ld a,(ice_mode)
        or a
        ld a,l
        jr nz,ps_pair
        and 7Fh                 ; blink
        ld l,a
        ld a,(blink_on)
        or a
        ld a,l
        jr nz,ps_pair
        and 0F0h                ; hidden: the foreground as the background
        ld l,a
        rrca
        rrca
        rrca
        rrca
        or l
ps_pair:
        push af
        rrca
        rrca
        rrca
        rrca
        ld de,ps_rgb
        call ps_copy            ; background
        pop af
        call ps_copy            ; foreground
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        add a,a
        add a,b
        add a,b
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
        ret
ps_copy:                        ; colour A & 0Fh -> 3 bytes at DE
        and 0Fh
        ld l,a
        add a,a
        add a,l
        ld l,a
        ld h,0
        push bc
        ld bc,(rgb_tab)         ; the ANSI colours, or those of the C64 (pet.asm)
        add hl,bc
        ld bc,3
        ldir
        pop bc
        ret
