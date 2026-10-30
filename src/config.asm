; SAPI-Term - settings and the address book of BBS in SAPITERM.CFG, on the disk SAPITERM.COM was started from.
;
; CP/M 2.2 does not tell a program its disk. The CCP is still in memory when the program starts: its command
; line (CCP + 7 length, CCP + 8 text, CCP = BDOS entry - 806h, checked by the two jumps it starts with) begins
; with "X:" when the program was started as X:SAPITERM, else the program came from the current disk (0004h).
;
; The file is text (CR LF, 1Ah at the end), lines "KEY=value", ";" starts a comment:
;   KEYBOARD=EKL-1 or CONSUL
;   SCREEN=CGA or AND             the card of the terminal when both are there
;   SPEED=MAX or 38400 ... 300    the speed of a modem shown (bytes to the terminal tick by tick)
;   COLUMNS=80 or 40              columns of the CGA-1V on line (40: the font 4x8 with its dots doubled)
;   BBS=name,host[:port][,set]    at most BOOK_MAX, in this order on the start screen (no ',' in the name);
;                                 set = the character set of the BBS (charset.asm: CP437 when none, UTF-8,
;                                 LATIN2, CP1250, CP852, KAMENICKY, KOI8)
; Saving writes the file anew from the settings and the book (comments and unknown lines are not kept).

BOOK_MAX        equ 16
NAME_MAX        equ 31
ADDR_MAX        equ LINE_MAX
BOOK_ENTRY      equ NAME_MAX+1+ADDR_MAX+1+1 ; name 00h, address 00h, character set
CFG_RECORDS     equ 20                      ; records of 128 bytes read at most
CFG_BUF_SIZE    equ CFG_RECORDS*128+128     ; the text, its end mark and the rest of the last record
B_CLOSE         equ 16
B_DELETE        equ 19
B_READSEQ       equ 20
B_WRITESEQ      equ 21
B_MAKE          equ 22

; cfg_find_drive: cfg_drive = the disk SAPITERM was started from (0 = A). Call it before anything overwrites
; the CCP. Changes A, DE, HL.
cfg_find_drive:
        ld a,(0004h)            ; the current disk
        and 0Fh
        ld (cfg_drive),a
        ld hl,(0006h)           ; BDOS entry - 806h = the CCP
        ld de,0806h
        or a
        sbc hl,de
        ld a,(hl)               ; the CCP starts with two JPs
        cp 0C3h
        ret nz
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        cp 0C3h
        ret nz
        inc hl
        inc hl
        inc hl
        inc hl                  ; CCP + 7: length of the command line
        ld a,(hl)
        cp 2
        ret c
        inc hl
        inc hl                  ; CCP + 9: ':' after a drive letter?
        ld a,(hl)
        cp ':'
        ret nz
        dec hl
        ld a,(hl)
        sub 'A'
        ret c
        cp 16
        ret nc
        ld (cfg_drive),a
        ret

; cfg_fcb_init: the FCB of SAPITERM.CFG on cfg_drive, record 0. Changes A, BC, DE, HL.
cfg_fcb_init:
        ld hl,cfg_fcb
        ld b,36
cfi_clear:
        ld (hl),0
        inc hl
        djnz cfi_clear
        ld a,(cfg_drive)
        inc a
        ld (cfg_fcb),a
        ld hl,txt_cfg_name
        ld de,cfg_fcb+1
        ld bc,11
        ldir
        ret
txt_cfg_name:
        defb 'SAPITERMCFG'
txt_cfg_file:
        defb ':SAPITERM.CFG',0

; cfg_load: settings and book from the file (no file: the defaults, an empty book). Changes all.
cfg_load:
        xor a
        ld (book_n),a
        call cfg_fcb_init
        ld de,cfg_fcb
        ld c,B_OPEN
        call BDOS
        inc a
        ret z                   ; no file
        ld hl,cfg_buf           ; read up to CFG_RECORDS records
        ld (cfg_ptr),hl
        ld b,CFG_RECORDS
cl_read:
        push bc
        ld de,(cfg_ptr)
        ld c,B_SETDMA
        call BDOS
        ld de,cfg_fcb
        ld c,B_READSEQ
        call BDOS
        pop bc
        or a
        jr nz,cl_parse          ; the end of the file
        ld hl,(cfg_ptr)
        ld de,128
        add hl,de
        ld (cfg_ptr),hl
        djnz cl_read
cl_parse:
        ld hl,(cfg_ptr)
        ld (hl),1Ah             ; the end mark
        ld hl,cfg_buf
cl_line:                        ; HL = the start of a line
        call skip_blanks
        ld a,(hl)
        cp 1Ah
        ret z
        cp ';'
        jr z,cl_next
        ld de,key_keyboard
        call match_key
        jr z,cl_keyboard
        ld de,key_screen
        call match_key
        jr z,cl_screen
        ld de,key_speed
        call match_key
        jr z,cl_speed
        ld de,key_columns
        call match_key
        jr z,cl_columns
        ld de,key_bbs
        call match_key
        jr z,cl_bbs
cl_next:                        ; to the start of the next line
        ld a,(hl)
        cp 1Ah
        ret z
        inc hl
        cp 0Ah
        jr nz,cl_next
        jr cl_line
cl_keyboard:
        ld de,val_consul
        call match_key
        ld a,0
        jr nz,cl_kbd_set
        inc a
cl_kbd_set:
        ld (kbd_type),a
        jr cl_next
cl_screen:
        ld de,val_and
        call match_key
        ld a,0
        jr nz,cl_scr_set
        inc a
cl_scr_set:
        ld (cfg_term),a
        jr cl_next
cl_columns:
        ld de,val_40
        call match_key
        ld a,0
        jr nz,cl_cols_set
        inc a
cl_cols_set:
        ld (cols40),a
        jp cl_next
cl_speed:
        ld de,speed_names
        ld b,0
csp_try:
        push de
        call match_key
        pop de
        jr z,csp_found
csp_next:
        ld a,(de)
        inc de
        or a
        jr nz,csp_next
        inc b
        ld a,b
        cp SPEED_COUNT
        jr c,csp_try
        jp cl_next              ; unknown: as it was
csp_found:
        ld a,b
        ld (speed),a
        jp cl_next
cl_bbs:                         ; the name up to ',', then the address up to a space or the end of the line
        ld a,(book_n)
        cp BOOK_MAX
        jr nc,cl_next
        call skip_blanks
        push hl
        call book_entry         ; DE = the entry
        pop hl
        ld b,NAME_MAX
        ld c,','
        call copy_field
        ld a,(hl)
        cp ','
        jr nz,cl_next           ; no address: not taken
        inc hl
        inc de
        call skip_blanks
        ld a,(hl)
        cp ' '+1
        jp c,cl_next            ; an empty address: not taken
        ld b,ADDR_MAX
        call copy_word
        inc de
        xor a                   ; the character set: CP437 when none or unknown
        ld (de),a
        call skip_blanks
        ld a,(hl)
        cp ','
        jr nz,cl_entry
        inc hl
        call skip_blanks
        push de
        call cs_parse
        pop de
        jr nz,cl_entry
        ld (de),a
cl_entry:
        ld a,(book_n)
        inc a
        ld (book_n),a
        jp cl_next

; skip_blanks: HL over spaces and tabs. Changes A.
skip_blanks:
        ld a,(hl)
        cp ' '
        jr z,sb_skip
        cp 09h
        ret nz
sb_skip:
        inc hl
        jr skip_blanks

; match_key: Z when the text at HL starts with the key at DE (capitals, 00h at the end; the text may have small
; letters); HL is after it then. Changes A, DE (HL only when it matches).
match_key:
        push hl
mk_char:
        ld a,(de)
        or a
        jr z,mk_yes
        ld a,(hl)
        call upcase
        ex de,hl
        cp (hl)
        ex de,hl
        jr nz,mk_no
        inc hl
        inc de
        jr mk_char
mk_yes:
        inc sp                  ; the saved HL is dropped, Z from "or a" stays
        inc sp
        ret
mk_no:
        pop hl
        ret
key_keyboard:
        defb 'KEYBOARD=',0
key_screen:
        defb 'SCREEN=',0
key_bbs:
        defb 'BBS=',0
key_speed:
        defb 'SPEED=',0
key_columns:
        defb 'COLUMNS=',0
val_40:
        defb '40',0
val_80:
        defb '80',0
val_ekl:
        defb 'EKL-1',0
val_consul:
        defb 'CONSUL',0
val_cga:
        defb 'CGA',0
val_and:
        defb 'AND',0

; upcase: A as a capital when it is a small letter. Changes A.
upcase:
        cp 'a'
        ret c
        cp 'z'+1
        ret nc
        sub 20h
        ret

; copy_field: from HL to DE at most B characters, up to the byte C or the end of the line (< 20h), 00h after
; them (DE stays on it). HL stays on the byte that ended it (characters over B are skipped). Changes A, B.
copy_field:
        ld a,(hl)
        cp c
        jr z,cf_end
        cp ' '
        jr c,cf_end
        inc hl
        inc b
        dec b
        jr z,copy_field         ; full: the rest is skipped
        dec b
        ld (de),a
        inc de
        jr copy_field
cf_end:
        xor a
        ld (de),a
        ret

; copy_word: from HL to DE at most B characters, up to a space, ',' or the end of the line, 00h after them (DE
; stays on it). HL stays on the byte that ended it (characters over B are skipped). Changes A, B.
copy_word:
        ld a,(hl)
        cp ','
        jr z,cf_end
        cp ' '+1
        jr c,cf_end
        inc hl
        inc b
        dec b
        jr z,copy_word
        dec b
        ld (de),a
        inc de
        jr copy_word

; book_entry: DE = entry book_n of the book (the first free one). book_entry_a: DE = entry A (0 = the first).
; Change A, DE, HL.
book_entry:
        ld a,(book_n)
book_entry_a:
        ld hl,book
        ld de,BOOK_ENTRY
        or a
        jr z,be_done
be_add:
        add hl,de
        dec a
        jr nz,be_add
be_done:
        ex de,hl
        ret

; book_addr: HL = the address of entry A (0 = the first), after its name. Changes A, DE, HL.
book_addr:
        call book_entry_a
        ex de,hl
ba_skip:
        ld a,(hl)
        inc hl
        or a
        jr nz,ba_skip
        ret

; book_pick: ui_line = the address of entry A (1 = the first); C when there is no such entry. Changes all.
book_pick:
        or a
        scf
        ret z
        ld b,a
        ld a,(book_n)
        cp b
        ret c
        ld a,b
        dec a
        call book_addr
        ld de,ui_line
bp_copy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        or a
        jr nz,bp_copy
        ret                     ; NC from "or a"

; book_delete: entry A (1 = the first) out of the book, the later ones move up; C when there is no such entry.
; Changes all.
book_delete:
        or a
        scf
        ret z
        ld b,a
        ld a,(book_n)
        cp b
        ret c
        call book_entry_a       ; DE = the end of the book
        push de
        ld a,b
        dec a
        call book_entry_a       ; DE = the entry
        ld hl,BOOK_ENTRY
        add hl,de               ; HL = the next one
        ex (sp),hl              ; HL = the end
        or a
        sbc hl,de
        ld bc,BOOK_ENTRY
        sbc hl,bc               ; bytes after the entry
        ld b,h
        ld c,l
        pop hl
        ld a,b
        or c
        jr z,bd_done
        ldir
bd_done:
        ld hl,book_n
        dec (hl)
        or a
        ret

; book_find: A = the entry with the address ui_line (letters in any case); C when there is none. Changes all.
book_find:
        ld a,(book_n)
        ld c,a
        ld b,0
bf_try:
        ld a,b
        cp c
        scf
        ret z
        push bc
        call book_addr
        ld de,ui_line
        call str_same           ; NC
        pop bc
        ld a,b
        ret z
        inc b
        jr bf_try

; book_cs: HL = the character set of entry A. Changes A, DE, HL.
book_cs:
        call book_addr
bcs_skip:
        ld a,(hl)
        inc hl
        or a
        jr nz,bcs_skip
        ret

; book_add: this connection into the book: ui_line (its address) with net_host as its name and cs_type, or
; cs_type into its entry when it is there already. A = 0 done, 2 the book is full. Changes all.
book_add:
        call book_find
        jr c,bk_new
        call book_cs
        ld a,(cs_type)
        ld (hl),a
        xor a
        ret
bk_new:
        ld a,(book_n)
        cp BOOK_MAX
        ld a,2
        ret nc
        call book_entry
        ld hl,net_host
        ld b,NAME_MAX
        ld c,0
        call copy_field
        inc de
        ld hl,ui_line
        ld b,ADDR_MAX
        call copy_word
        inc de
        ld a,(cs_type)
        ld (de),a
        ld a,(book_n)
        inc a
        ld (book_n),a
        xor a
        ret

; str_same: Z when the texts at HL and DE (00h at the end) are the same, small and capital letters alike.
; Changes A, B, DE, HL.
str_same:
        ld a,(de)
        call upcase
        ld b,a
        ld a,(hl)
        call upcase
        cp b
        ret nz
        or a
        ret z
        inc hl
        inc de
        jr str_same

; cfg_save: the settings and the book written to SAPITERM.CFG anew. A = 0 saved, else BDOS failed. MAP_CPM.
; Changes all.
cfg_save:
        ld a,(stat_dev)         ; with both cards the terminal card of now is kept
        or a
        jr z,cfs_text
        ld a,(term_dev)
        cp DEV_AND
        ld a,1
        jr z,cfs_term
        xor a
cfs_term:
        ld (cfg_term),a
cfs_text:
        ld de,cfg_buf
        ld hl,cfg_header
        call put_str
        ld hl,key_keyboard
        call put_str
        ld hl,val_ekl
        ld a,(kbd_type)
        or a
        jr z,cfs_kbd
        ld hl,val_consul
cfs_kbd:
        call put_str
        call put_crlf
        ld hl,key_screen
        call put_str
        ld hl,val_cga
        ld a,(cfg_term)
        or a
        jr z,cfs_scr
        ld hl,val_and
cfs_scr:
        call put_str
        call put_crlf
        ld hl,key_speed
        call put_str
        push de
        ld a,(speed)
        call speed_name
        pop de
        call put_str
        call put_crlf
        ld hl,key_columns
        call put_str
        ld hl,val_80
        ld a,(cols40)
        or a
        jr z,cfs_cols
        ld hl,val_40
cfs_cols:
        call put_str
        call put_crlf
        xor a
cfs_entry:
        ld hl,book_n
        cp (hl)
        jr nc,cfs_end
        push af
        push de
        call book_entry_a
        ex de,hl                ; HL = the entry
        pop de
        push hl
        ld hl,key_bbs
        call put_str
        pop hl
        call put_str            ; the name
        ld a,','
        ld (de),a
        inc de
        inc hl
        call put_str            ; the address
        inc hl
        ld a,(hl)               ; the character set, when not CP437
        or a
        jr z,cfs_line
        push de
        call cs_name
        pop de
        ld a,','
        ld (de),a
        inc de
        call put_str
cfs_line:
        call put_crlf
        pop af
        inc a
        jr cfs_entry
cfs_end:
        ld (cfg_ptr),de         ; the end mark, 1Ah up to the end of its record
        ld a,1Ah
        ld b,128
cfs_pad:
        ld (de),a
        inc de
        djnz cfs_pad
        call cfg_fcb_init
        ld de,cfg_fcb
        ld c,B_DELETE
        call BDOS
        call cfg_fcb_init
        ld de,cfg_fcb
        ld c,B_MAKE
        call BDOS
        inc a
        ld a,1
        ret z                   ; the directory is full
        ld hl,cfg_buf
cfs_record:                     ; records up to the one with the end mark
        push hl
        ex de,hl
        ld c,B_SETDMA
        call BDOS
        ld de,cfg_fcb
        ld c,B_WRITESEQ
        call BDOS
        pop hl
        or a
        jr nz,cfs_failed        ; the disk is full
        ld de,128
        add hl,de
        ex de,hl
        ld hl,(cfg_ptr)
        or a
        sbc hl,de
        ex de,hl
        jr nc,cfs_record
        ld de,cfg_fcb
        ld c,B_CLOSE
        call BDOS
        inc a
        ld a,1
        ret z
        xor a
        ret
cfs_failed:
        ld de,cfg_fcb
        ld c,B_CLOSE
        call BDOS
        ld a,1
        ret
cfg_header:
        defb '; SAPI-Term: nastaveni a adresar BBS. Lezi vedle SAPITERM.COM, SAPI-Term ho prepisuje.',0Dh,0Ah
        defb '; KEYBOARD=EKL-1 nebo CONSUL, SCREEN=CGA nebo AND (terminal na karte),',0Dh,0Ah
        defb '; SPEED=MAX nebo rychlost linky 38400, 19200, 9600, 4800, 2400, 1200, 300 (ANSI animace),',0Dh,0Ah
        defb '; COLUMNS=80 nebo 40 (sloupce CGA-1V na BBS),',0Dh,0Ah
        defb '; BBS=jmeno,adresa[:port][,sada] (nejvys 16, poradi jako na uvodni obrazovce, jmeno bez carky),'
        defb 0Dh,0Ah
        defb ';   sada znaku BBS: CP437 (bez udani), UTF-8, LATIN2, CP1250, CP852, KAMENICKY, KOI8.',0Dh,0Ah,0

; put_str: the text at HL (00h at the end) to DE, HL stays on its 00h. Changes A, DE, HL.
put_str:
        ld a,(hl)
        or a
        ret z
        ld (de),a
        inc hl
        inc de
        jr put_str

; put_crlf: CR LF to DE. Changes A, DE.
put_crlf:
        ld a,0Dh
        ld (de),a
        inc de
        ld a,0Ah
        ld (de),a
        inc de
        ret
