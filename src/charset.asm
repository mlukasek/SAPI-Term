; SAPI-Term - character sets of BBS: bytes 80h-FFh from the BBS to glyphs, Czech letters of the EKL-1 to the BBS.
;
; A glyph is a CP437 code, or a KOI-8cs2 letter C0-FF shown with EXT_KOI (Czech and Slovak letters are always
; taken from KOI-8cs2). The tables are made by tools/tables.py (build/tables.inc). cs_type is chosen per BBS
; (SAPITERM.CFG, the menu); CP437 shows the bytes as they are. UTF-8 is decoded up to FFFFh: 00A0-017F and
; 2500-25FF by tables, the rest from a list, anything else as '?'.

CS_CP437        equ 0
CS_UTF8         equ 1
CS_LATIN2       equ 2               ; ISO 8859-2
CS_CP1250       equ 3               ; Windows
CS_CP852        equ 4               ; DOS Latin-2
CS_KAMENICKY    equ 5               ; KEYBCS2
CS_KOI8         equ 6               ; KOI-8cs2, as SAPI-1
CS_PETSCII      equ 7               ; not a set only: the terminal of a C64 (pet.asm)
CS_ATASCII      equ 8               ; the terminal of an Atari 8-bit (ata.asm)
CS_COUNT        equ 9

; cs_byte: byte A (80h-FFh) of the BBS on the screen in the set cs_type (from ansi_putc). Changes all.
cs_byte:
        ld c,a
        ld a,(cs_type)
        or a
        ld a,c
        jp z,scr_putc           ; CP437
        ld a,(cs_type)
        cp CS_UTF8
        jr z,cs_utf8
        push bc                 ; the byte
        add a,a                 ; one byte sets: their tables from cs_in_tabs
        add a,a
        ld hl,cs_in_tabs-4*CS_LATIN2
        call add_hl_a
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld b,(hl)               ; BC = the KOI bits
        ex de,hl                ; HL = the codes
        pop de
        ld a,e
        and 7Fh
        jr cs_put_tab
cs_in_tabs:
        defw cs_in_latin2,cs_in_latin2_koi, cs_in_cp1250,cs_in_cp1250_koi, cs_in_cp852,cs_in_cp852_koi
        defw cs_in_kamenicky,cs_in_kamenicky_koi, cs_in_koi8,cs_in_koi8_koi

; cs_put_tab: the glyph of entry A of a table: HL = its codes, BC = its KOI bits (bit A & 7 of byte A >> 3).
; Changes all.
cs_put_tab:
        push af
        call add_hl_a
        ld d,(hl)               ; the code
        pop af
        ld e,a
        ld h,b
        ld l,c
        rrca
        rrca
        rrca
        and 1Fh
        call add_hl_a
        ld a,e
        and 7
        ld b,a
        ld a,(hl)
cpt_shift:
        dec b
        jp m,cpt_bit
        rrca
        jr cpt_shift
cpt_bit:
        and EXT_KOI
        ld (cur_ext),a
        ld a,d
        call scr_putc
        xor a
        ld (cur_ext),a
        ret

; cs_utf8: byte C of UTF-8. A lead byte starts a character (4 bytes: beyond FFFFh, shown as '?'), the
; continuation bytes build it, the last one shows it. Changes all.
cs_utf8:
        ld a,(utf_need)
        or a
        jr nz,cu_cont
cu_lead:
        ld a,c
        cp 0C0h
        jr c,cu_bad             ; a continuation byte alone
        ld hl,0
        cp 0E0h
        jr c,cu_two
        cp 0F0h
        jr c,cu_three
        ld b,3
        ld hl,0FFFFh            ; too far: only counted
        jr cu_start
cu_two:
        and 1Fh
        ld l,a
        ld b,1
        jr cu_start
cu_three:
        and 0Fh
        ld l,a
        ld b,2
cu_start:
        ld (utf_cp),hl
        ld a,b
        ld (utf_need),a
        ret
cu_cont:
        ld a,c
        cp 0C0h
        jr c,cu_more
        xor a                   ; a lead byte: the unfinished character is a '?'
        ld (utf_need),a
        push bc
        ld a,'?'
        call scr_putc
        pop bc
        jr cu_lead
cu_more:
        ld hl,(utf_cp)
        ld a,h
        and l
        inc a
        jr z,cu_count
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld a,c
        and 3Fh
        or l
        ld l,a
        ld (utf_cp),hl
cu_count:
        ld hl,utf_need
        dec (hl)
        ret nz
        ld hl,(utf_cp)
        jr uni_put
cu_bad:
        ld a,'?'
        jp scr_putc

; uni_put: the glyph of Unicode HL. Changes all.
uni_put:
        ld a,h
        or a
        jr nz,up_high
        ld a,l
        cp 80h
        jp c,scr_putc
        cp 0A0h
        jr c,up_none            ; C1 controls
        sub 0A0h
up_lat:                         ; 00A0-017F
        ld hl,u_lat_code
        ld bc,u_lat_koi
        jp cs_put_tab
up_high:
        cp 01h
        jr nz,up_box
        ld a,l
        cp 80h
        jr nc,up_list
        add a,60h
        jr up_lat
up_box:
        cp 25h
        jr nz,up_combining
        ld a,l
        ld hl,u_box
        call add_hl_a
        ld a,(hl)
        jp scr_putc
up_combining:
        cp 03h                  ; combining accents 0300-036F: nothing
        jr nz,up_dots
        ld a,l
        cp 70h
        ret c
up_dots:
        ld de,2026h             ; the ellipsis as three dots
        or a
        sbc hl,de
        add hl,de
        jr nz,up_list
        ld a,'.'
        call scr_putc
        ld a,'.'
        call scr_putc
        ld a,'.'
        jp scr_putc
up_list:
        ex de,hl
        ld hl,u_list
ul_next:
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld a,b
        or c
        jr z,up_none
        ld a,c
        cp e
        jr nz,ul_skip
        ld a,b
        cp d
        jr z,ul_found
ul_skip:
        inc hl
        jr ul_next
ul_found:
        ld a,(hl)
        or a
        ret z                   ; zero width: nothing
        jp scr_putc
up_none:
        ld a,'?'
        jp scr_putc

; cs_key: the KOI-8cs2 letter A (C0h-FFh, typed on the EKL-1) to the BBS in the set cs_type. Changes all.
cs_key:
        sub 0C0h
        ld e,a
        ld a,(cs_type)
        cp CS_UTF8
        jr z,ck_utf8
        add a,a                 ; koi_out + cs_type * 64
        add a,a
        add a,a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,koi_out
        add hl,bc
        ld a,e
        call add_hl_a
        ld a,(hl)
        jp tx_data
ck_utf8:
        ld a,e
        add a,a
        ld hl,koi_uni
        call add_hl_a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d
        or a
        jr nz,ck_two
        ld a,e
        cp 80h
        jp c,tx_data
ck_two:                         ; 0080-07FF: 110xxxxx 10xxxxxx
        ld a,e
        and 3Fh
        or 80h
        push af
        ld a,e
        rlca
        rlca
        and 03h
        ld b,a
        ld a,d
        add a,a
        add a,a
        or b
        or 0C0h
        call tx_data
        pop af
        jp tx_data

; cs_name: HL = the name of set A (as in SAPITERM.CFG, 00h at the end). Changes A, HL.
cs_name:
        ld hl,cs_names
cn_next:
        or a
        ret z
        push af
cn_end:
        ld a,(hl)
        inc hl
        or a
        jr nz,cn_end
        pop af
        dec a
        jr cn_next

; cs_parse: Z with A = the set named at HL (HL after the name), NZ when none is. Changes A, B, DE (HL only
; when found).
cs_parse:
        ld de,cs_names
        ld b,0
cp_try:
        push de
        call match_key
        pop de
        ld a,b
        ret z
cp_next:                        ; DE to the next name
        ld a,(de)
        inc de
        or a
        jr nz,cp_next
        inc b
        ld a,b
        cp CS_COUNT
        jr c,cp_try
        ld de,cs_alias_utf8
        call match_key
        ld a,CS_UTF8
        ret

; names of the sets in the order of CS_*
cs_names:
        defb 'CP437',0, 'UTF-8',0, 'LATIN2',0, 'CP1250',0, 'CP852',0, 'KAMENICKY',0, 'KOI8',0, 'PETSCII',0, 'ATASCII',0
cs_alias_utf8:
        defb 'UTF8',0
