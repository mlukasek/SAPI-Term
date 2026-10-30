; SAPI-Term - the history: the rows that scroll off the top of the screen, in a ring of HIST_LINES lines from
; hist_buf (after the stack up to D5FFh; C000h-D5FFh with MAP_CPM is the TPA of CP/M under its CCP, which the
; warm boot loads again). hist_view shows it on the terminal; the screen itself goes to the end of the ring
; meanwhile and comes back from it.

HIST_REC        equ 2*SCR_COLS+SCR_COLS/8   ; a row: characters, attributes, the KOI bits (170 bytes)

; hist_push_top: rows 0 to rg_k - 1 leave the screen at its top: into the history (not while it is shown).
; Changes A.
hist_push_top:
        ld a,(hv_on)
        or a
        ret nz
        push bc
        push de
        push hl
        ld a,(rg_k)
        ld b,a
        ld c,0
hpt_row:
        push bc
        ld a,c
        call hist_push
        pop bc
        inc c
        djnz hpt_row
        pop hl
        pop de
        pop bc
        ret

; hist_push: shadow row A at the end of the history; when it is full the oldest line goes. MAP_CPM after it.
; Changes all.
hist_push:
        call row_off_addr
        ld e,(hl)
        inc hl
        ld d,(hl)
        push de                 ; the offset of the row in the shadow
        ld a,MAP_CPM            ; the ring reaches above C000h
        out (MAPREG),a
        ld a,(hist_head)
        call hist_addr
        ex de,hl                ; DE = the record
        pop hl
        push hl
        ld bc,scr_chr
        add hl,bc
        ld bc,SCR_COLS
        ldir
        pop hl
        push hl
        ld bc,scr_att
        add hl,bc
        ld bc,SCR_COLS
        ldir
        pop hl
        ld bc,scr_ext
        add hl,bc
        ld c,SCR_COLS/8
hpu_byte:                       ; 8 cells a byte, the first in bit 0
        push de
        ld b,8
hpu_bit:
        ld a,(hl)
        inc hl
        rrca                    ; EXT_KOI to the carry
        rr e
        djnz hpu_bit
        ld a,e
        pop de
        ld (de),a
        inc de
        dec c
        jr nz,hpu_byte
        ld a,(hist_head)
        inc a
        cp HIST_LINES
        jr c,hpu_head
        xor a
hpu_head:
        ld (hist_head),a
        ld a,(hist_count)
        cp HIST_LINES
        ret nc
        inc a
        ld (hist_count),a
        ret

; hist_line: HL = the record of line A of the history (0 = the oldest). Changes A, B, DE, HL.
hist_line:
        ld b,a
        ld a,(hist_head)
        ld hl,hist_count
        sub (hl)
        jr nc,hli_first
        add a,HIST_LINES
hli_first:
        add a,b
        cp HIST_LINES
        jr c,hist_addr
        sub HIST_LINES
; hist_addr: HL = hist_buf + A * HIST_REC (170 = 128 + 32 + 8 + 2). Changes DE, HL.
hist_addr:
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l                  ; DE = 2a
        add hl,hl
        add hl,hl               ; 8a
        ex de,hl
        add hl,de               ; 10a
        ex de,hl
        add hl,hl
        add hl,hl               ; 32a
        ex de,hl
        add hl,de               ; 42a
        ex de,hl
        add hl,hl
        add hl,hl               ; 128a
        add hl,de               ; 170a
        ld de,hist_buf
        add hl,de
        ret

; hist_view: the history on the terminal card: the screen goes to the end of the history, the arrows move by a
; line, PgUp and PgDn by a screen, Home to the oldest line, End back to the screen; Esc or Ctrl+] return (the
; screen as it was, from the history). Nothing scrolled off yet: nothing to do. Changes all.
hist_view:
        ld a,(hist_count)
        or a
        ret z
        ld hl,(cur_row)         ; cur_row, cur_col
        ld (hv_cur),hl
        ld a,(cur_att)
        ld (hv_att),a
        ld a,(wrap_pend)
        ld (hv_wrap),a
        ld a,(reg_top)
        ld (hv_rtop),a
        ld a,(reg_bot)
        ld (hv_rbot),a
        call cur_hide
        ld a,(term_rows)        ; the screen into the history
        ld b,a
        ld c,0
hv_push:
        push bc
        ld a,c
        call hist_push
        pop bc
        inc c
        djnz hv_push
        ld a,1
        ld (hv_on),a
        call scr_reset_region
        ld a,(hist_count)
        ld (hv_total),a
        call hv_end_top
        call stat_cls
        ld de,0*256+0
        ld hl,t_hist_title
        call ss_text
        call hv_status
hv_key:
        call kbd_get
        jr nc,hv_key
        cp 1Bh
        jp z,hv_exit
        cp K_MENU
        jp z,hv_exit
        cp 05h                  ; EKL-1 up, down, PgUp, PgDn, Home, End
        jr z,hv_up
        cp 18h
        jr z,hv_down
        cp 12h
        jr z,hv_pgup
        cp 03h
        jr z,hv_pgdn
        cp 1Eh
        jr z,hv_home
        cp 11h
        jr z,hv_end
        cp 0C1h                 ; Consul 262.3 up, down
        jr z,hv_up
        cp 0C2h
        jr z,hv_down
        jr hv_key
hv_up:
        ld a,(hv_top)
        or a
        jr z,hv_key
        dec a
        ld (hv_top),a
        ld a,(term_rows)
        dec a
        ld c,a
        ld b,0
        call scr_region_down
        ld d,0
        ld a,(hv_top)
        call hv_row
        jr hv_moved
hv_down:
        ld a,(hv_top)
        ld hl,term_rows
        add a,(hl)
        ld hl,hv_total
        cp (hl)
        jr nc,hv_key            ; the screen is the last one
        ld a,(hv_top)
        inc a
        ld (hv_top),a
        ld a,(term_rows)
        dec a
        ld c,a
        ld b,0
        call scr_region_up
        ld a,(term_rows)
        dec a
        ld d,a
        ld a,(hv_top)
        add a,d
        call hv_row
        jr hv_moved
hv_pgup:
        ld a,(term_rows)
        dec a
        ld b,a
        ld a,(hv_top)
        sub b
        jr nc,hv_set
hv_home:
        xor a
        jr hv_set
hv_pgdn:
        ld a,(term_rows)
        dec a
        ld b,a
        ld a,(hv_top)
        add a,b
        ld b,a
        call hv_end_top         ; A = the last top
        cp b
        jr c,hv_set
        ld a,b
        jr hv_set
hv_end:
        call hv_end_top
hv_set:
        ld (hv_top),a
        call hv_all
hv_moved:
        call pal_pending
        call nz,scr_flush
        call hv_status
        jp hv_key
hv_exit:
        call hv_end_top         ; the screen as it was
        ld (hv_top),a
        call hv_all
        ld a,(term_rows)        ; out of the history again
        ld b,a
        ld a,(hist_count)
        sub b
        ld (hist_count),a
        ld a,(hist_head)
        sub b
        jr nc,hve_head
        add a,HIST_LINES
hve_head:
        ld (hist_head),a
        xor a
        ld (hv_on),a
        ld hl,(hv_cur)
        ld (cur_row),hl
        ld a,(hv_att)
        ld (cur_att),a
        ld a,(hv_wrap)
        ld (wrap_pend),a
        ld a,(hv_rtop)
        ld (reg_top),a
        ld a,(hv_rbot)
        ld (reg_bot),a
        call pal_pending
        call nz,scr_flush
        jp stat_screen

; hv_end_top: A = (hv_top =) the top line when the last lines are shown. Changes A, HL.
hv_end_top:
        ld a,(hv_total)
        ld hl,term_rows
        sub (hl)
        ld (hv_top),a
        ret

; hv_all: the screen from the history from line hv_top. Changes all.
hv_all:
        ld d,0
hva_row:
        push de
        ld a,(hv_top)
        add a,d
        call hv_row
        pop de
        inc d
        ld a,(term_rows)
        cp d
        jr nz,hva_row
        ret

; hv_row: line A of the history to screen row D (all 80 cells of the shadow through scr_set, so the pairs of
; colours keep their counts). Changes all.
hv_row:
        push de
        call hist_line
        pop de
        ld (hv_rec),hl
        ld e,0
hvr_cell:
        push de
        ld hl,(hv_rec)          ; MAP_CPM here (scr_set leaves it)
        ld a,e
        call add_hl_a
        ld b,(hl)               ; the character
        ld a,SCR_COLS
        call add_hl_a
        ld c,(hl)               ; the attribute
        ld hl,(hv_rec)
        ld a,e
        rrca
        rrca
        rrca
        and 1Fh
        add a,2*SCR_COLS
        call add_hl_a
        ld a,e
        and 7
        push bc
        ld b,a
        inc b
        ld a,(hl)
hvr_bit:
        dec b
        jr z,hvr_got
        rrca
        jr hvr_bit
hvr_got:
        and EXT_KOI
        pop bc
        call scr_set
        pop de
        inc e
        ld a,e
        cp SCR_COLS
        jr nz,hvr_cell
        ret

; hv_status: the line shown last and of how many, on the status card. Changes all.
hv_status:
        ld a,(stat_dev)
        or a
        ret z
        ld de,2*256+0
        ld hl,t_hist_line
        call ss_text
        ld a,(hv_top)
        ld hl,term_rows
        add a,(hl)
        ld l,a
        ld h,0
        call stat_dec16
        ld hl,t_hist_of
        call stat_puts
        ld a,(hv_total)
        ld l,a
        ld h,0
        call stat_dec16
        ld hl,txt_spaces
        jp stat_puts
txt_spaces:
        defb '   ',0
