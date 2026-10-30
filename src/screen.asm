; SAPI-Term - the terminal screen: a shadow of 80x25 cells (character, attribute, flags) and its output on the
; terminal card (term_dev: the CGA-1V 80x25, or a 64x20 window on the AND-1V), plus the status screen on the
; other card (stat_dev).
;
; Attribute = background << 4 | foreground, colours in the CGA order (0 black, 1 blue ... 15 white). Flags:
; EXT_KOI = the character is KOI-8cs2 C0-FF (Czech letters), else CP437. The rows of the shadow are rotated by
; scrolling: row r of the screen is at row_off[r] in scr_chr, scr_att and scr_ext. Scrolling works in the
; region reg_top..reg_bot (VT100 DECSTBM, normally the whole screen).

DEV_CGA         equ 1
DEV_AND         equ 2
EXT_KOI         equ 01h
SCR_COLS        equ 80
SCR_ROWS        equ 25
BLINK_TICKS     equ 20              ; cursor on / off every 1/3 s

; scr_init: the terminal on card A (DEV_CGA or DEV_AND), its size, the cursor home, the screen cleared with
; cur_att. Changes all.
scr_init:
        ld (term_dev),a
        cp DEV_CGA
        ld a,SCR_COLS
        ld b,SCR_ROWS
        jr z,si_size
        ld a,AND_COLS
        ld b,AND_ROWS
si_size:
        ld (term_cols),a
        ld a,b
        ld (term_rows),a
        xor a
        ld (cur_vis),a
        ld (view_x),a
        ld (view_y),a
        jp scr_cls

; scr_reset_region: the scroll region is the whole screen. Changes A.
scr_reset_region:
        xor a
        ld (reg_top),a
        ld a,(term_rows)
        dec a
        ld (reg_bot),a
        ret

; scr_offset: D = row, E = column -> HL = offset of the cell in the shadow arrays. Changes A.
scr_offset:
        push de
        ld a,d
        add a,a
        ld l,a
        ld h,0
        ld de,row_off
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ld a,e
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; fill: BC bytes at HL with A (BC > 0), the keyboard polled after every 256 bytes. Changes A, BC, DE, HL.
fill:
        ld (hl),a
        dec bc
        ld a,b
        or c
        ret z
        ld d,h
        ld e,l
        inc de
fl_chunk:
        ld a,b
        or a
        jr z,fl_last
        push bc
        ld bc,256
        ldir
        pop bc
        dec b
        call kbd_scan
        jr fl_chunk
fl_last:
        ld a,c
        or a
        ret z
        ldir
        ret

; scr_blank: B cells of the shadow from offset HL: spaces with cur_att, no flags. Changes A, BC, DE, HL.
scr_blank:
        ld (sb_off),hl
        ld a,b
        ld (sb_n),a
        ld c,b
        ld b,0
        push bc
        ld de,scr_chr
        add hl,de
        ld a,' '
        call fill
        pop bc
        push bc
        ld hl,(sb_off)
        ld de,scr_ext
        add hl,de
        xor a
        call fill
        pop bc
        ld hl,(sb_off)
        ld de,scr_att
        add hl,de
        ld a,(cur_att)
        jp fill

; scr_cls: all 25 rows of the shadow spaces with cur_att, rows in order, cursor home, scroll region the whole
; screen, and the same on the terminal card. Changes all.
scr_cls:
        ld hl,row_off
        ld de,0
        ld a,SCR_ROWS
sc_rows:
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        push hl
        ld hl,SCR_COLS
        add hl,de
        ex de,hl
        pop hl
        dec a
        jr nz,sc_rows
        ld hl,scr_chr
        ld bc,SCR_COLS*SCR_ROWS
        ld a,' '
        call fill
        ld hl,scr_att
        ld bc,SCR_COLS*SCR_ROWS
        ld a,(cur_att)
        call fill
        ld hl,scr_ext
        ld bc,SCR_COLS*SCR_ROWS
        xor a
        call fill
        xor a
        ld (cur_row),a
        ld (cur_col),a
        ld (wrap_pend),a
        ld (js_pending),a
        call scr_reset_region
        ld a,(term_dev)
        cp DEV_CGA
        jr z,sc_cga
        cp DEV_AND
        ret nz
        jp and_render
sc_cga:
        ld a,(cur_att)
; cga_cls_att: the CGA-1V cleared with attribute A: pairs anew, in every domain one slot for all its cells,
; the rows filled with it. Changes all.
cga_cls_att:
        ld (sc_att),a
        call pair_init
        xor a
sc_domain:
        ld (sc_dom),a
        call pair_setdom
        ld a,(sc_att)
        call pair_get
        ld (sc_slot),a
        ld de,4*SCR_COLS-1
        ld a,(sc_dom)
        cp DOMAINS-1
        jr nz,sc_count
        ld de,SCR_COLS-1        ; the last domain has one row
sc_count:
        ld a,(sc_slot)
        call pair_add
        ld a,(sc_dom)
        add a,a
        add a,a
        ld d,a
        ld e,4
        cp 4*(DOMAINS-1)
        jr nz,sc_fill
        ld e,1
sc_fill:
        ld a,MAP_CGA
        out (MAPREG),a
        ld a,(sc_slot)
        call cga_fill_rows
        ld a,MAP_CPM
        out (MAPREG),a
        ld a,(sc_dom)
        inc a
        cp DOMAINS
        jr nz,sc_domain
        jp scr_flush

; scr_set: cell D = row, E = column gets character B, attribute C, flags A; it is drawn on the terminal card.
; Changes all except D, E.
scr_set:
        ld (ss_ext),a
        ld a,b
        ld (ss_chr),a
        ld a,c
        ld (ss_att),a
        call scr_offset
        ld bc,scr_chr           ; scr_chr, scr_att, scr_ext follow each other
        add hl,bc
        ld a,(ss_chr)
        ld (hl),a
        ld bc,SCR_COLS*SCR_ROWS
        add hl,bc
        ld a,(hl)
        ld (ss_old),a
        ld a,(ss_att)
        ld (hl),a
        add hl,bc
        ld a,(ss_ext)
        ld (hl),a
        ld a,(term_dev)
        cp DEV_CGA
        jr z,ss_cga
        cp DEV_AND
        ret nz
        ld a,(ss_ext)
        ld b,a
        ld a,(ss_chr)
        call and_char
        jp and_cell
ss_cga:
        push de
        ld a,d
        call pair_row_dom
        ld a,(ss_old)           ; the same attribute as before: its slot, the count stays
        ld b,a
        ld a,(ss_att)
        cp b
        jr nz,ss_pair
        ld l,a
        ld a,(pd_page)
        ld h,a
        ld a,(hl)
        cp 16
        jr c,ss_slot
ss_pair:
        ld a,(ss_old)
        call pair_unref
        ld a,(ss_att)
        call pair_get
ss_slot:
        push af
        call kbd_scan           ; a new pair may have taken a scan of 256 attributes
        pop af
        ld c,a                  ; slot
        ld a,(ss_ext)
        ld b,a
        ld a,(ss_chr)
        call glyph_addr
        pop de
        push de
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_draw
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
        ret

; scr_draw_cell: draw cell D = row, E = column from the shadow on the terminal card, without counting its
; pair (the caller does, or it did not change). Changes all except D, E.
scr_draw_cell:
        call scr_offset
        push hl
        ld bc,scr_att
        add hl,bc
        ld a,(hl)
        ld (ss_att),a
        pop hl
        push hl
        ld bc,scr_ext
        add hl,bc
        ld a,(hl)
        ld (ss_ext),a
        pop hl
        ld bc,scr_chr
        add hl,bc
        ld a,(hl)
        ld (ss_chr),a
        ld a,(term_dev)
        cp DEV_CGA
        jr z,sdc_cga
        ld a,(ss_ext)
        ld b,a
        ld a,(ss_chr)
        call and_char
        jp and_cell
sdc_cga:
        ld a,d
        call pair_row_dom
        ld a,(pd_page)
        ld h,a
        ld a,(ss_att)
        ld l,a
        ld c,(hl)               ; slot
        ld a,(ss_ext)
        ld b,a
        ld a,(ss_chr)
        call glyph_addr
        push de
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_draw
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
        ret

; scr_redraw: the whole screen again on the terminal card (after it changed). On the CGA-1V the pairs are
; given anew. Changes all.
scr_redraw:
        ld a,(term_dev)
        cp DEV_AND
        jp z,and_render
        cp DEV_CGA
        ret nz
        call pair_init
        ld d,0
srd_row:
        ld a,d
        call pair_row_dom
        ld e,0
srd_col:
        push de
        call scr_offset
        ld bc,scr_att
        add hl,bc
        ld a,(hl)
        call pair_get
        pop de
        push de
        call scr_draw_cell
        pop de
        inc e
        ld a,e
        cp SCR_COLS
        jr nz,srd_col
        call kbd_scan
        inc d
        ld a,d
        cp SCR_ROWS
        jr nz,srd_row
        jp scr_flush

; scr_flush: new pairs of colours of the CGA-1V into the palette (waits for the VBI when there are some).
; Changes all.
scr_flush:
        ld a,(term_dev)
        cp DEV_CGA
        jr z,sf_cga
        ld a,(stat_dev)
        cp DEV_CGA
        ret nz
sf_cga:
        ld a,MAP_CGA
        out (MAPREG),a
        call pal_flush
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; scr_putc: character A with cur_att and cur_ext at the cursor, the cursor moves right; at the last column it
; waits there and the next character goes to the next line (deferred wrap like the VT100). With wrap_off
; the last column is overwritten. Changes all.
scr_putc:
        ld b,a
        ld a,(wrap_pend)
        or a
        jr z,sp_put
        xor a
        ld (wrap_pend),a
        ld (cur_col),a
        push bc
        call scr_lf
        pop bc
sp_put:
        ld a,(cur_row)
        ld d,a
        ld a,(cur_col)
        ld e,a
        ld a,(cur_att)
        ld c,a
        ld a,(cur_ext)
        call scr_set
        ld a,(term_cols)
        dec a
        cp e
        jr z,sp_wrap
        inc e
        ld a,e
        ld (cur_col),a
        ret
sp_wrap:
        ld a,(wrap_off)
        or a
        ret nz
        ld a,1
        ld (wrap_pend),a
        ret

; scr_puts_koi: the KOI-8cs2 text at HL up to 00h with cur_att (codes C0-FF as Czech letters). Changes all.
scr_puts_koi:
        ld a,(hl)
        inc hl
        or a
        ret z
        push hl
        call scr_putc_koi
        pop hl
        jr scr_puts_koi

; scr_putc_koi: the KOI-8cs2 character A with cur_att (C0-FF as a Czech letter). Changes all.
scr_putc_koi:
        ld b,0
        cp 0C0h
        jr c,spk_put
        ld b,EXT_KOI
spk_put:
        ld c,a
        ld a,b
        ld (cur_ext),a
        ld a,c
        call scr_putc
        xor a
        ld (cur_ext),a
        ret

; scr_at: cursor to D = row, E = column. Changes A.
scr_at:
        ld a,d
        ld (cur_row),a
        ld a,e
        ld (cur_col),a
        xor a
        ld (wrap_pend),a
        ld (js_pending),a
        ret

; scr_lf: cursor one row down; at the bottom of the scroll region the region scrolls up, below it the cursor
; stops at the last row. Jump scroll: when the buffered input has n more line feeds before anything but text
; and SGR (js_count), the region scrolls by n + 1 rows at once and the cursor goes to the first new row; the next
; n line feeds only move down. A row they enter is blanked again when the attribute changed meanwhile, so the
; screen ends exactly as with scrolling row by row. Changes all.
scr_lf:
        ld a,(reg_bot)
        ld b,a
        ld a,(cur_row)
        cp b
        jr z,lf_scroll
        inc a
        ld hl,term_rows
        cp (hl)
        ret nc
        ld (cur_row),a
        ld b,a
        ld a,(js_pending)       ; a row of a jump scroll: blank with the attribute of now
        or a
        ret z
        dec a
        ld (js_pending),a
        ld a,(js_att)
        ld hl,cur_att
        cp (hl)
        ret z
        ld d,b
        ld e,0
        ld b,SCR_COLS
        jp scr_erase
lf_scroll:
        call js_count
        inc a
        ld (rg_k),a
        dec a
        ld (js_pending),a
        ld a,(cur_att)
        ld (js_att),a
        ld a,(rg_k)
        ld c,a
        ld a,(reg_bot)
        sub c
        inc a
        ld (cur_row),a
        ld a,(reg_top)
        ld b,a
        ld a,(reg_bot)
        ld c,a
        jp scr_region_upk

; js_count: A = line feeds in the buffered input (in_ptr to in_end, when js_enable) before anything but
; printable characters, CR, BS, TAB, BEL and CSI ... m, at most the rows of the region minus two (a jump keeps
; at least one row). Changes BC, DE, HL.
js_count:
        ld a,(js_enable)
        or a
        ret z
        ld a,(reg_top)
        ld b,a
        ld a,(reg_bot)
        sub b
        ret z
        dec a
        ret z
        ld b,a                  ; B = the most
        ld c,0
        ld hl,(in_ptr)
        ld de,(in_end)
jc_byte:
        call jc_get
        jr c,jc_done
        cp 0Ah
        jr z,jc_lf
        cp 1Bh
        jr z,jc_esc
        cp 20h
        jr nc,jc_byte
        cp 0Dh
        jr z,jc_byte
        cp 08h
        jr z,jc_byte
        cp 09h
        jr z,jc_byte
        cp 07h
        jr z,jc_byte
jc_done:
        ld a,c
        ret
jc_lf:
        inc c
        ld a,c
        cp b
        jr nz,jc_byte
        jr jc_done
jc_esc:
        call jc_get
        jr c,jc_done
        cp '['
        jr nz,jc_done
jc_param:
        call jc_get
        jr c,jc_done
        cp 40h
        jr c,jc_param
        cp 'm'
        jr z,jc_byte
        jr jc_done
jc_get:                         ; A = next byte, carry at the end of the input
        ld a,l
        cp e
        jr nz,jg_byte
        ld a,h
        cp d
        scf
        ret z
jg_byte:
        ld a,(hl)
        inc hl
        or a                    ; no carry
        ret

; scr_ri: cursor one row up; at the top of the scroll region the region scrolls down. Changes all.
scr_ri:
        ld a,(reg_top)
        ld b,a
        ld a,(cur_row)
        cp b
        jr z,scr_scroll_down
        or a
        ret z
        dec a
        ld (cur_row),a
        ret

; scr_scroll: the scroll region up by one row. scr_scroll_down: down. Changes all.
scr_scroll:
        ld a,(reg_top)
        ld b,a
        ld a,(reg_bot)
        ld c,a
        jr scr_region_up
scr_scroll_down:
        ld a,(reg_top)
        ld b,a
        ld a,(reg_bot)
        ld c,a
        jp scr_region_down

; scr_region_up: rows B + 1 to C move up by one, row C becomes spaces with cur_att (its background), on the
; shadow and on the terminal card. scr_region_upk: by rg_k rows (1 to C - B + 1). On the CGA-1V a row that
; comes into another domain gets its pairs there. Changes all.
scr_region_up:
        ld a,1
        ld (rg_k),a
scr_region_upk:
        ld a,b
        ld (rg_top),a
        ld a,c
        ld (rg_bot),a
        ld a,(term_dev)         ; the rows that leave give back their pairs
        cp DEV_CGA
        jr nz,ru_shadow
        ld a,(rg_k)
        ld c,a
        ld d,b
ru_unref:
        push bc
        push de
        call row_unref
        pop de
        pop bc
        inc d
        dec c
        jr nz,ru_unref
ru_shadow:
        ld a,(rg_k)
        ld (ru_left),a
ru_rotate:
        ld a,(rg_top)           ; row_off: the row of the top becomes the bottom one
        call row_off_addr
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sl_off),de
        dec hl
        ld d,h
        ld e,l
        inc hl
        inc hl
        ld a,(rg_bot)
        ld b,a
        ld a,(rg_top)
        ld c,a
        ld a,b
        sub c
        jr z,ru_last
        add a,a
        ld c,a
        ld b,0
        ldir
ru_last:
        ex de,hl
        ld de,(sl_off)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(sl_off)
        ld b,SCR_COLS
        call scr_blank
        call kbd_scan
        ld a,(ru_left)
        dec a
        ld (ru_left),a
        jr nz,ru_rotate
        ld a,(term_dev)
        cp DEV_AND
        jr nz,ru_cga
        ld a,(rg_k)
        dec a
        jp z,and_scroll
        jp and_render
ru_cga:
        cp DEV_CGA
        ret nz
        ld a,(rg_bot)           ; VRAM: rows top + k .. bottom up by k
        ld hl,rg_k
        sub (hl)
        ld (ru_lastrow),a          ; the last destination row
        ld a,(rg_top)
        ld d,a
ru_copy:
        ld a,(ru_lastrow)
        cp d
        jr c,ru_moved
        push de
        ld a,(rg_k)
        add a,d
        ld e,d
        ld d,a
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_copy_row
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
        inc d
        jr ru_copy
ru_moved:
        ld a,(rg_top)           ; rows that came from another domain
        ld d,a
ru_dom:
        ld a,(ru_lastrow)
        cp d
        jr c,ru_new
        ld a,(rg_k)
        add a,d
        rrca
        rrca
        and 3Fh                 ; domain of the source row
        ld e,a
        ld a,d
        rrca
        rrca
        and 3Fh
        cp e
        jr z,ru_dom_next
        ld a,e
        push de
        call pair_move_row
        pop de
ru_dom_next:
        inc d
        jr ru_dom
ru_new:                         ; the new rows at the bottom
        ld a,(ru_lastrow)
        inc a
ru_new_row:
        push af
        call new_row
        pop af
        ld hl,rg_bot
        cp (hl)
        ret z
        inc a
        jr ru_new_row

; scr_region_down: rows B to C - 1 move down by one, row B becomes spaces with cur_att. Changes all.
scr_region_down:
        ld a,b
        ld (rg_top),a
        ld a,c
        ld (rg_bot),a
        ld a,(term_dev)
        cp DEV_CGA
        jr nz,rd_shadow
        ld d,c
        call row_unref          ; the bottom row leaves
rd_shadow:
        ld a,(rg_bot)           ; row_off: the row of the bottom becomes the top one
        call row_off_addr
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sl_off),de
        ld d,h
        ld e,l                  ; DE = high byte of the last entry
        dec hl
        dec hl                  ; HL = high byte of the entry above
        ld a,(rg_bot)
        ld b,a
        ld a,(rg_top)
        ld c,a
        ld a,b
        sub c
        jr z,rd_first
        add a,a
        ld c,a
        ld b,0
        lddr
rd_first:
        ld a,(rg_top)
        call row_off_addr
        ld de,(sl_off)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(sl_off)
        ld b,SCR_COLS
        call scr_blank
        ld a,(term_dev)
        cp DEV_AND
        jp z,and_render
        cp DEV_CGA
        ret nz
        ld a,(rg_bot)           ; VRAM: rows down, from the bottom
        ld d,a
rd_copy:
        ld a,(rg_top)
        cp d
        jr z,rd_moved
        push de
        ld e,d
        dec d
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_copy_row
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
        dec d
        jr rd_copy
rd_moved:
        ld a,(rg_top)           ; rows that came from the domain above (destination row 4k)
        ld d,a
rd_dom:
        inc d
        ld a,(rg_bot)
        cp d
        jr c,rd_new
        ld a,d
        and 3
        jr nz,rd_dom
        ld a,d
        dec a
        rrca
        rrca
        and 3Fh
        push de
        call pair_move_row
        pop de
        jr rd_dom
rd_new:
        ld a,(rg_top)
; new_row: the blank row A (cur_att) on the CGA-1V: its pairs and its VRAM.
new_row:
        ld (nr_row),a
        call pair_row_dom
        ld a,(cur_att)
        call pair_get
        ld (nr_slot),a
        ld de,SCR_COLS-1
        call pair_add
        ld a,MAP_CGA
        out (MAPREG),a
        ld a,(nr_row)
        ld d,a
        ld e,1
        ld a,(nr_slot)
        call cga_fill_rows
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; row_off_addr: HL = address of row_off[A]. Changes A.
row_off_addr:
        add a,a
        add a,low row_off
        ld l,a
        ld a,0
        adc a,high row_off
        ld h,a
        ret

; row_unref: the cells of row D give back their pairs (runs of one attribute at once). Changes all except D.
row_unref:
        ld e,0
; cells_unref: B... the cells of row D from column E to the end give back their pairs.
cells_unref:
        ld a,SCR_COLS
        sub e
        ld b,a
; cells_unref_n: B cells of row D from column E give back their pairs. Changes all except D.
cells_unref_n:
        ld a,b
        or a
        ret z
        push de
        ld a,d
        call pair_row_dom
        call scr_offset
        ld de,scr_att
        add hl,de
cu_run:
        call kbd_scan
        ld a,(hl)
        ld c,0
cu_len:
        inc c
        inc hl
        dec b
        jr z,cu_end
        cp (hl)
        jr z,cu_len
cu_end:
        push bc
        push hl
        ld e,c
        ld d,0
        call pair_sub
        call kbd_scan
        pop hl
        pop bc
        ld a,b
        or a
        jr nz,cu_run
        pop de
        ret

; scr_erase: B cells of row D from column E become spaces with cur_att (on the shadow and the card).
; Changes all except D, E.
scr_erase:
        ld a,b
        or a
        ret z
        ld (er_n),a
        ld a,(term_dev)
        cp DEV_CGA
        jr nz,er_shadow
        push de
        call cells_unref_n
        pop de
er_shadow:
        push de
        call scr_offset
        ld a,(er_n)
        ld b,a
        call scr_blank
        pop de
        ld a,(term_dev)
        cp DEV_CGA
        jr z,er_cga
        cp DEV_AND
        ret nz
        ld a,(er_n)             ; AND-1V: the cells one by one (spaces)
        ld b,a
        push de
er_and:
        push bc
        ld a,' '
        call and_cell
        pop bc
        inc e
        djnz er_and
        pop de
        ret
er_cga:
        push de
        ld a,d
        call pair_row_dom
        ld a,(cur_att)
        call pair_get
        ld (nr_slot),a
        ld a,(er_n)
        dec a
        ld e,a
        ld d,0
        ld a,(nr_slot)
        call pair_add
        pop de
        push de
        ld a,(er_n)
        ld b,a
        ld a,MAP_CGA
        out (MAPREG),a
        ld a,(nr_slot)
        call cga_fill_cells
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
        ret

; scr_insert_chars: B blank cells inserted at row D, column E; the cells to the right move right, the last
; ones are lost. scr_delete_chars: B cells deleted at row D, column E, the cells to the right move left, blank
; cells come in at the end. Changes all.
scr_insert_chars:
        call ic_clip
        ret z
        push de                 ; the cells pushed out at the end give back their pairs
        ld a,SCR_COLS
        sub b
        ld e,a
        ld a,(term_dev)
        cp DEV_CGA
        call z,cells_unref_n
        pop de
        ld a,SCR_COLS           ; shadow: cells E .. 79 - n move to E + n
        sub e
        ld hl,ic_n
        sub (hl)
        ld (ic_len),a
        ld a,e
        add a,(hl)
        ld (ic_to),a
        ld a,e
        ld (ic_from),a
        call ic_move_shadow
        ld a,(term_dev)
        cp DEV_CGA
        jr nz,ic_blank
        ld a,(ic_len)
        ld b,a
        ld a,(ic_from)
        ld c,a
        ld a,(ic_to)
        ld e,a
        push de
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_move_cells
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
ic_blank:
        ld a,(ic_from)
        ld e,a
        ld a,(ic_n)
        ld b,a
        call scr_erase_new
        jp ic_and

scr_delete_chars:
        call ic_clip
        ret z
        ld a,(term_dev)         ; the deleted cells give back their pairs
        cp DEV_CGA
        push de
        call z,cells_unref_n
        pop de
        ld a,SCR_COLS           ; shadow: cells E + n .. 79 move to E
        sub e
        ld hl,ic_n
        sub (hl)
        ld (ic_len),a
        ld a,e
        ld (ic_to),a
        add a,(hl)
        ld (ic_from),a
        call ic_move_shadow
        ld a,(term_dev)
        cp DEV_CGA
        jr nz,dc_blank
        ld a,(ic_len)
        ld b,a
        ld a,(ic_from)
        ld c,a
        ld a,(ic_to)
        ld e,a
        push de
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_move_cells
        ld a,MAP_CPM
        out (MAPREG),a
        pop de
dc_blank:
        ld a,SCR_COLS
        ld hl,ic_n
        sub (hl)
        ld e,a
        ld b,(hl)
        call scr_erase_new
        jp ic_and

; ic_clip: B = count clipped to the cells from column E to the end, stored in ic_n; Z when nothing to do.
ic_clip:
        ld a,SCR_COLS
        sub e
        cp b
        jr nc,icc_ok
        ld b,a
icc_ok:
        ld a,b
        ld (ic_n),a
        or a
        ret

; ic_move_shadow: in row D, ic_len cells of the shadow from column ic_from to ic_to (all three arrays).
ic_move_shadow:
        ld a,(ic_len)
        or a
        ret z
        ld hl,scr_chr
        call icm_array
        ld hl,scr_att
        call icm_array
        ld hl,scr_ext
icm_array:
        push de
        push hl
        ld e,0
        call scr_offset
        pop de
        add hl,de               ; HL = the row in this array
        ld d,h
        ld e,l
        ld a,(ic_to)
        call add_de_a
        ld a,(ic_from)
        call add_hl_a
        ld a,(ic_len)
        ld c,a
        ld b,0
        ld a,(ic_to)
        push hl
        ld hl,ic_from
        cp (hl)
        pop hl
        jr c,icm_left
        dec bc                  ; to the right: from the end
        add hl,bc
        ex de,hl
        add hl,bc
        ex de,hl
        inc bc
        lddr
        pop de
        ret
icm_left:
        ldir
        pop de
        ret

; scr_erase_new: B cells of row D from column E become blank in the shadow and on the CGA-1V, counted as new
; cells (their old pairs were given back already).
scr_erase_new:
        ld a,b
        or a
        ret z
        ld (er_n),a
        push de
        call scr_offset
        ld a,(er_n)
        ld b,a
        call scr_blank
        pop de
        ld a,(term_dev)
        cp DEV_CGA
        ret nz
        jp er_cga

; ic_and: on the AND-1V the row D from column ic_to / ic_from to the end is drawn again.
ic_and:
        ld a,(term_dev)
        cp DEV_AND
        ret nz
        ld e,0
ica_cell:
        push de
        call scr_draw_cell
        pop de
        inc e
        ld a,e
        cp SCR_COLS
        jr nz,ica_cell
        ret

; add_hl_a: HL + A. add_de_a: DE + A. A and the flags stay.
add_hl_a:
        push af
        add a,l
        ld l,a
        jr nc,aha_done
        inc h
aha_done:
        pop af
        ret
add_de_a:
        push af
        add a,e
        ld e,a
        jr nc,ada_done
        inc d
ada_done:
        pop af
        ret

; scr_shift: the shadow only (no card): all 25 rows move up by A (> 0), the rows that come in at the bottom
; are spaces with cur_att. For a smaller screen (25 to 20 rows) that keeps the cursor row. Changes all.
scr_shift:
        ld (sh_count),a
sh_row:
        ld hl,(row_off)
        ld (sl_off),hl
        ld hl,row_off+2
        ld de,row_off
        ld bc,2*(SCR_ROWS-1)
        ldir
        ld hl,(sl_off)
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,(sl_off)
        ld b,SCR_COLS
        call scr_blank
        ld a,(sh_count)
        dec a
        ld (sh_count),a
        jr nz,sh_row
        ret

; --- cursor ---

; cur_hide: remove the cursor from the screen (before the screen changes). Changes all.
cur_hide:
        ld a,(cur_vis)
        or a
        ret z
        xor a
        ld (cur_vis),a
        jr cur_toggle

; cur_show: draw the cursor when it is enabled and in its visible blink phase. Changes all.
cur_show:
        ld a,(cur_vis)
        or a
        ret nz
        ld a,(cur_off)
        or a
        ret nz
        ld a,(cur_phase)
        or a
        ret z
        ld a,1
        ld (cur_vis),a
        ld a,(cur_row)
        ld (cur_drow),a
        ld a,(cur_col)
        ld (cur_dcol),a
; cur_toggle: the cursor at cur_drow, cur_dcol drawn or removed (XOR on the CGA-1V; on the AND-1V the cell
; shows 7Fh or its character again).
cur_toggle:
        ld a,(cur_drow)
        ld d,a
        ld a,(cur_dcol)
        ld e,a
        ld a,(term_dev)
        cp DEV_CGA
        jr z,ct_cga
        cp DEV_AND
        ret nz
        ld a,(cur_vis)
        or a
        jp z,scr_draw_cell
        ld a,7Fh
        jp and_cell
ct_cga:
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_cursor_xor
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; cur_restart: the cursor in the visible phase from now (after a key). Changes all.
cur_restart:
        ld a,1
        ld (cur_phase),a
        xor a
        ld (cur_ticks),a
        jr cur_show

; cur_tick: one tick of 60 Hz: blink of the cursor and of the blinking text. Changes all.
cur_tick:
        call blink_tick
        ld a,(cur_ticks)
        inc a
        ld (cur_ticks),a
        cp BLINK_TICKS
        ret c
        xor a
        ld (cur_ticks),a
        ld a,(cur_phase)
        xor 1
        ld (cur_phase),a
        jr z,cur_hide
        jr cur_show

; --- status screen on the other card ---

; stat_cls: clear the status card. On the CGA-1V its pairs start anew (no terminal there). Changes all.
stat_cls:
        ld a,(stat_dev)
        cp DEV_AND
        jp z,and_cls
        cp DEV_CGA
        ret nz
        ld a,07h
        ld (stat_att),a
        jp cga_cls_att

; stat_at: the next status output at D = row, E = column. Changes A.
stat_at:
        ld a,(stat_dev)
        cp DEV_AND
        jp z,and_at
        ld a,d
        ld (stat_row),a
        ld a,e
        ld (stat_col),a
        ret

; stat_putc: KOI-8cs2 character A on the status card with stat_att (CGA-1V). Changes A.
stat_putc:
        push bc
        push de
        push hl
        ld c,a
        ld a,(stat_dev)
        cp DEV_AND
        jr z,stp_and
        cp DEV_CGA
        jr nz,stp_done
        ld a,(stat_row)
        call pair_row_dom
        ld a,(pd_page)
        ld h,a
        ld a,(stat_att)
        ld l,a
        ld a,(hl)
        cp 16
        jr c,stp_slot
        ld a,(stat_att)
        push bc
        call pair_get
        pop bc
stp_slot:
        push af
        ld a,c
        ld b,0
        cp 0C0h
        jr c,stp_glyph
        ld b,EXT_KOI
stp_glyph:
        call glyph_addr
        pop bc                  ; B = slot
        ld c,b
        ld a,(stat_row)
        ld d,a
        ld a,(stat_col)
        ld e,a
        inc a
        ld (stat_col),a
        ld a,MAP_CGA
        out (MAPREG),a
        call cga_draw
        call pal_flush
        ld a,MAP_CPM
        out (MAPREG),a
        jr stp_done
stp_and:
        ld a,c
        call and_putc
stp_done:
        pop hl
        pop de
        pop bc
        ret

; stat_puts: KOI-8cs2 text at HL up to 00h. Changes A, HL.
stat_puts:
        ld a,(hl)
        inc hl
        or a
        ret z
        call stat_putc
        jr stat_puts

; stat_hex8: A as two hex digits. Changes A.
stat_hex8:
        push af
        rrca
        rrca
        rrca
        rrca
        call stat_nibble
        pop af
stat_nibble:
        and 0Fh
        add a,90h
        daa
        adc a,40h
        daa
        jr stat_putc

; stat_dec8: A in decimal without leading zeros. Changes A.
stat_dec8:
        push bc
        ld c,a
        xor a
        ld (ad_lead),a
        ld a,c
        ld b,100
        call sd_digit
        ld b,10
        call sd_digit
        add a,'0'
        call stat_putc
        pop bc
        ret
sd_digit:
        ld c,'0'-1
sd_sub:
        inc c
        sub b
        jr nc,sd_sub
        add a,b
        push af
        ld a,c
        cp '0'
        jr nz,sd_put
        ld a,(ad_lead)
        or a
        jr z,sd_skip
        ld a,'0'
sd_put:
        call stat_putc
        ld a,1
        ld (ad_lead),a
sd_skip:
        pop af
        ret
