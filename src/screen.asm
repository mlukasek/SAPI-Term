; SAPI-Term - the terminal screen: a shadow of 80x25 cells (character, attribute, flags) and its output on the
; terminal card (term_dev: the CGA-1V 80x25, or a 64x20 window on the AND-1V), plus the status screen on the
; other card (stat_dev).
;
; Attribute = background << 4 | foreground, colours in the CGA order (0 black, 1 blue ... 15 white). Flags:
; EXT_KOI = the character is KOI-8cs2 C0-FF (Czech letters), else CP437. The rows of the shadow are rotated by
; scrolling: row r of the screen is at row_off[r] in scr_chr, scr_att and scr_ext.

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

; scr_cls: all 25 rows of the shadow spaces with cur_att, rows in order, cursor home, and the same on the
; terminal card. Changes all.
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
        ld a,(term_dev)
        cp DEV_CGA
        jr z,sc_cga
        cp DEV_AND
        ret nz
        jp and_render
sc_cga:
        call pair_init
        ld a,(cur_att)
        call pair_get
        ld de,SCR_COLS*SCR_ROWS-1
        push af
        call pair_add           ; every cell has the attribute
        ld a,MAP_CGA
        out (MAPREG),a
        pop af
        ld de,0*256+SCR_ROWS
        call cga_fill_rows
        call pal_flush
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; fill: BC bytes at HL with A (BC > 0). Changes BC, DE, HL.
fill:
        ld (hl),a
        dec bc
        ld a,b
        or c
        ret z
        ld d,h
        ld e,l
        inc de
        ldir
        ret

; scr_set: cell D = row, E = column gets character B, attribute C, flags A; it is drawn on the terminal card.
; Changes all except D, E.
scr_set:
        ld (ss_ext),a
        ld a,b
        ld (ss_chr),a
        ld a,c
        ld (ss_att),a
        call scr_offset
        push hl
        ld bc,scr_chr
        add hl,bc
        ld a,(ss_chr)
        ld (hl),a
        pop hl
        push hl
        ld bc,scr_ext
        add hl,bc
        ld a,(ss_ext)
        ld (hl),a
        pop hl
        ld bc,scr_att
        add hl,bc
        ld a,(hl)
        ld (ss_old),a
        ld a,(ss_att)
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
        ld a,(ss_old)
        call pair_unref
        ld a,(ss_att)
        call pair_get
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
; pair (the caller does). Changes all except D, E.
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
        ld a,(ss_att)
        ld l,a
        ld h,high att_slot
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
        ld a,MAP_CGA
        out (MAPREG),a
        call pal_flush
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; scr_putc: character A with cur_att and cur_ext at the cursor, the cursor moves right; at the last column it
; waits there and the next character goes to the next line (deferred wrap like the VT100). Changes all.
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
        pop hl
        jr scr_puts_koi

; scr_at: cursor to D = row, E = column. Changes A.
scr_at:
        ld a,d
        ld (cur_row),a
        ld a,e
        ld (cur_col),a
        xor a
        ld (wrap_pend),a
        ret

; scr_lf: cursor one row down, at the last row the screen scrolls. Changes all.
scr_lf:
        ld a,(term_rows)
        ld b,a
        ld a,(cur_row)
        inc a
        cp b
        jr nc,scr_scroll
        ld (cur_row),a
        ret

; scr_scroll: rows 1 to term_rows - 1 move up, the last one is spaces with cur_att (its background), on the
; shadow and on the terminal card. Changes all.
scr_scroll:
        ld hl,(row_off)         ; the row that leaves becomes the last one
        ld (sl_off),hl
        ld a,(term_rows)
        dec a
        jr z,sl_last
        add a,a
        ld c,a
        ld b,0
        ld hl,row_off+2
        ld de,row_off
        ldir
sl_last:
        ld a,(term_rows)
        dec a
        add a,a
        ld l,a
        ld h,0
        ld de,row_off
        add hl,de
        ld de,(sl_off)
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(term_dev)         ; on the CGA-1V the cells of the old row leave their pairs
        cp DEV_CGA
        jr nz,sl_clear
        ld hl,scr_att
        add hl,de
        ld b,SCR_COLS
sl_unref:
        ld a,(hl)
        push hl
        push bc
        call pair_unref
        pop bc
        pop hl
        inc hl
        djnz sl_unref
sl_clear:
        ld de,(sl_off)
        ld hl,scr_chr
        add hl,de
        ld bc,SCR_COLS
        ld a,' '
        call fill
        ld de,(sl_off)
        ld hl,scr_ext
        add hl,de
        ld bc,SCR_COLS
        xor a
        call fill
        ld de,(sl_off)
        ld hl,scr_att
        add hl,de
        ld bc,SCR_COLS
        ld a,(cur_att)
        call fill
        ld a,(term_dev)
        cp DEV_AND
        jp z,and_scroll
        cp DEV_CGA
        ret nz
        ld a,(cur_att)
        call pair_get
        push af
        ld de,SCR_COLS-1
        call pair_add
        pop bc
        ld c,b                  ; C = slot of the new row
        ld a,MAP_CGA
        out (MAPREG),a
        ld a,(term_rows)
        call cga_scroll
        call pal_flush
        ld a,MAP_CPM
        out (MAPREG),a
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
        ld hl,scr_chr
        add hl,de
        ld bc,SCR_COLS
        ld a,' '
        call fill
        ld de,(sl_off)
        ld hl,scr_ext
        add hl,de
        ld bc,SCR_COLS
        xor a
        call fill
        ld de,(sl_off)
        ld hl,scr_att
        add hl,de
        ld bc,SCR_COLS
        ld a,(cur_att)
        call fill
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

; cur_show: draw the cursor when it is in its visible blink phase. Changes all.
cur_show:
        ld a,(cur_vis)
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

; cur_tick: one tick of 60 Hz: blink. Changes all.
cur_tick:
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
        call pair_init
        ld a,07h
        ld (stat_att),a
        call pair_get
        ld de,0*256+SCR_ROWS
        push af
        ld a,MAP_CGA
        out (MAPREG),a
        pop af
        call cga_fill_rows
        ld a,MAP_CPM
        out (MAPREG),a
        ret

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
        ld a,(stat_att)
        ld l,a
        ld h,high att_slot
        ld a,(hl)
        cp 16
        jr c,stp_slot
        ld a,(stat_att)
        call pair_get
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
