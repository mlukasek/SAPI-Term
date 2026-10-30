; SAPI-Term - the session log and downloads (XMODEM with 128 or 1K blocks, CRC or checksum, YMODEM batch).
; Files go to the disk of SAPITERM.COM (cfg_drive, config.asm), BDOS with MAP_CPM.

; --- session log ---

; log_start: the received data (after telnet) from now into a new file LOGnn.ANS, the first nn 00-99 not on the
; disk; "SAPITERM LOGnn.ANS" replays the session. A = 0 started, 1 no file. Changes all.
log_start:
        xor a
        ld (log_num),a
lst_try:
        call log_fcb_init
        ld de,log_fcb
        ld c,B_OPEN
        call BDOS
        inc a
        jr z,lst_make
        ld a,(log_num)
        inc a
        ld (log_num),a
        cp 100
        jr c,lst_try
        ld a,1
        ret
lst_make:
        call log_fcb_init
        ld de,log_fcb
        ld c,B_MAKE
        call BDOS
        inc a
        ld a,1
        ret z
        ld hl,log_buf
        ld (log_ptr),hl
        ld (log_on),a           ; A = 1
        xor a
        ret

; show_log: the log after its menu line: LOGnn.ANS, or off. Changes all.
show_log:
        ld a,(log_on)
        or a
        ld hl,t_log_off
        jp z,stat_puts
        ld hl,txt_log
        call stat_puts
        ld a,(log_num)
        call dec2
        push bc
        ld a,b
        call stat_putc
        pop bc
        ld a,c
        call stat_putc
        ld hl,txt_ans
        jp stat_puts
txt_log:
        defb 'LOG',0
txt_ans:
        defb '.ANS',0

; log_fcb_init: the FCB of LOGnn.ANS (nn = log_num) on cfg_drive, record 0. Changes A, BC, DE, HL.
log_fcb_init:
        ld hl,log_fcb
        ld b,36
lfi_clear:
        ld (hl),0
        inc hl
        djnz lfi_clear
        ld a,(cfg_drive)
        inc a
        ld (log_fcb),a
        ld hl,txt_log_name
        ld de,log_fcb+1
        ld bc,11
        ldir
        ld a,(log_num)
        call dec2
        ld a,b
        ld (log_fcb+4),a
        ld a,c
        ld (log_fcb+5),a
        ret
txt_log_name:
        defb 'LOG00   ANS'

; dec2: A (0-99) -> B = tens, C = ones as digits. Changes A, BC.
dec2:
        ld b,'0'
d2_ten:
        cp 10
        jr c,d2_one
        sub 10
        inc b
        jr d2_ten
d2_one:
        add a,'0'
        ld c,a
        ret

; log_data: BC bytes at HL into the log when it is on, a record of 128 bytes written when full (a full disk ends
; the log). Changes all.
log_data:
        ld a,(log_on)
        or a
        ret z
        ld de,(log_ptr)
ldt_byte:
        ld a,b
        or c
        jr z,ldt_end
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        dec bc
        ld a,e
        cp low (log_buf+128)
        jr nz,ldt_byte
        ld a,d
        cp high (log_buf+128)
        jr nz,ldt_byte
        push hl
        push bc
        call log_record
        pop bc
        pop hl
        ld de,log_buf
        ld a,(log_on)
        or a
        jr nz,ldt_byte
        ret
ldt_end:
        ld (log_ptr),de
        ret

; log_record: log_buf to the file; when BDOS fails the log ends. Changes all.
log_record:
        ld de,log_buf
        ld c,B_SETDMA
        call BDOS
        ld de,log_fcb
        ld c,B_WRITESEQ
        call BDOS
        or a
        ret z
        xor a
        ld (log_on),a
        ld de,log_fcb
        ld c,B_CLOSE
        jp BDOS

; log_stop: the last record (1Ah after the data) written, the file closed. Changes all.
log_stop:
        ld a,(log_on)
        or a
        ret z
        ld hl,(log_ptr)
        ld de,log_buf
        or a
        sbc hl,de
        jr z,lsp_close          ; the records are full: no end mark needed
        ld a,128
        sub l
        ld b,a
        ld hl,(log_ptr)
lsp_pad:
        ld (hl),1Ah
        inc hl
        djnz lsp_pad
        call log_record
        ld a,(log_on)
        or a
        ret z                   ; it failed and closed
lsp_close:
        xor a
        ld (log_on),a
        ld de,log_fcb
        ld c,B_CLOSE
        jp BDOS

; --- downloads ---

XM_SOH          equ 01h
XM_STX          equ 02h
XM_EOT          equ 04h
XM_ACK          equ 06h
XM_NAK          equ 15h
XM_CAN          equ 18h
XM_WAIT         equ 3*60            ; ticks without a whole block: ask again
XM_TRIES        equ 10
XM_DONE         equ 1               ; xm_result
XM_STOPPED      equ 2
XM_CANCELLED    equ 3
XM_TIMEOUT      equ 4
XM_DISK         equ 5
XM_ROW          equ 16              ; the progress on the status card (below the menu)

; xm_run: receive files the BBS sends (the download is started on the BBS first). 'C' asks for CRC blocks,
; after 3 tries without an answer NAK for checksum ones. Block 0 (YMODEM) names the file, a block 1 first is
; XMODEM (the file XMODEM.BIN); a name that is on the disk gets a digit at its end. Esc stops it (CAN CAN CAN).
; The log pauses meanwhile. HL = the message for the menu. Changes all.
xm_run:
        ld a,(log_on)
        ld (xm_logged),a
        xor a
        ld (log_on),a
        ld (xm_result),a
        ld (xm_files),a
        ld (xm_open),a
        ld (xm_pstate),a
        ld (xm_ymodem),a
        ld (xm_tries),a
        ld (xm_cans),a
        ld hl,0
        ld (xm_recs),hl
        ld a,1
        ld (xm_crcmode),a
        ld (xm_hdr),a           ; the next block starts a file (block 0 or 1)
        call xm_ask
xr_loop:
        call kbd_get
        jr nc,xr_net
        cp 1Bh
        jr z,xr_stop
        cp K_MENU
        jr z,xr_stop
xr_net:
        call net_rx
        jr z,xr_tick
        ld hl,in_buf
xr_byte:
        ld de,(in_end)
        ld a,l
        cp e
        jr nz,xr_one
        ld a,h
        cp d
        jr z,xr_tick
xr_one:
        ld c,(hl)
        inc hl
        push hl
        call xm_rx_byte
        pop hl
        ld a,(xm_result)
        or a
        jr z,xr_byte
        jr xr_end
xr_tick:
        call tick_poll
        jr z,xr_loop
        ld hl,(xm_wait)
        dec hl
        ld (xm_wait),hl
        ld a,h
        or l
        jr nz,xr_loop
        ld hl,xm_tries          ; nothing came in time: ask again
        inc (hl)
        ld a,(hl)
        cp XM_TRIES
        jr nc,xr_timeout
        cp 3
        jr c,xr_again
        ld a,(xm_hdr)           ; no answer to 'C' at the start: checksum blocks
        or a
        jr z,xr_again
        xor a
        ld (xm_crcmode),a
xr_again:
        xor a
        ld (xm_pstate),a
        call xm_ask
        jr xr_loop
xr_timeout:
        ld a,XM_TIMEOUT
        jr xr_cancel
xr_stop:
        ld a,XM_STOPPED
xr_cancel:
        ld (xm_result),a
        ld b,3
xr_can:
        ld a,XM_CAN
        call tx_data
        djnz xr_can
        call tx_flush
xr_end:
        call xm_close
        ld hl,in_buf            ; nothing of the protocol for the terminal
        ld (in_ptr),hl
        ld (in_end),hl
        ld a,(xm_logged)
        ld (log_on),a
        ld a,(xm_result)        ; the message
        ld hl,t_xm_stopped
        cp XM_STOPPED
        ret z
        ld hl,t_xm_cancel
        cp XM_CANCELLED
        ret z
        ld hl,t_xm_timeout
        cp XM_TIMEOUT
        ret z
        ld hl,t_xm_disk
        cp XM_DISK
        ret z
        ld de,msg_buf           ; done: t_xm_done, NAME.EXT, n KB (the last file)
        ld hl,t_xm_done
        call put_str
        call xm_put_name
        ld a,','
        ld (de),a
        inc de
        ld a,' '
        ld (de),a
        inc de
        ld hl,(xm_recs)         ; KB = records / 8, rounded up
        ld bc,7
        add hl,bc
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        call put_dec16
        ld hl,txt_kb
        call put_str
        xor a
        ld (de),a
        ld hl,msg_buf
        ret
txt_kb:
        defb ' KB',0

; xm_ask: the next block asked for: 'C' (CRC) or NAK (checksum) before a file, NAK in it; the wait starts.
; Changes A, HL.
xm_ask:
        ld a,(xm_hdr)
        or a
        ld a,XM_NAK
        jr z,xa_send
        ld a,(xm_crcmode)
        or a
        ld a,XM_NAK
        jr z,xa_send
        ld a,'C'
xa_send:
        call xm_send
xm_rearm:
        ld hl,XM_WAIT
        ld (xm_wait),hl
        ret

; xm_send: the byte A to the BBS at once. Changes A, HL.
xm_send:
        push bc
        push de
        call tx_data
        call tx_flush
        pop de
        pop bc
        ret

; xm_rx_byte: byte C of the BBS: a block is collected in xm_pkt (block number, its complement, the data, the
; CRC or the checksum), EOT ends a file, two CAN the download. Changes all.
xm_rx_byte:
        ld a,(xm_pstate)
        or a
        jr nz,xb_collect
        ld a,c
        cp XM_CAN
        jr nz,xb_head
        ld hl,xm_cans
        inc (hl)
        ld a,(hl)
        cp 2
        ret c
        ld a,XM_CANCELLED
        ld (xm_result),a
        ret
xb_head:
        xor a
        ld (xm_cans),a
        ld a,c
        ld hl,128
        cp XM_SOH
        jr z,xb_start
        ld hl,1024
        cp XM_STX
        jr z,xb_start
        cp XM_EOT
        jp z,xm_eot
        ret                     ; anything else between the blocks: noise
xb_start:
        ld (xm_psize),hl
        inc hl                  ; + the block number and its complement, + CRC (2) or checksum (1)
        inc hl
        inc hl
        ld a,(xm_crcmode)
        or a
        jr z,xb_left
        inc hl
xb_left:
        ld (xm_pleft),hl
        ld hl,xm_pkt
        ld (xm_pptr),hl
        ld a,1
        ld (xm_pstate),a
        ret
xb_collect:
        ld hl,(xm_pptr)
        ld (hl),c
        inc hl
        ld (xm_pptr),hl
        ld hl,(xm_pleft)
        dec hl
        ld (xm_pleft),hl
        ld a,h
        or l
        ret nz
        xor a
        ld (xm_pstate),a
; xm_packet: a whole block in xm_pkt: checked, then the header of a file or its data. Changes all.
xm_packet:
        ld a,(xm_pkt)
        ld b,a
        ld a,(xm_pkt+1)
        add a,b
        inc a
        jp nz,xm_nak            ; the complement does not fit
        call xm_check
        jp nz,xm_nak
        ld a,(xm_hdr)
        or a
        jr z,xp_data
        ld a,(xm_pkt)           ; the first block of a file
        or a
        jr z,xp_header
        dec a
        jp nz,xm_nak
        ld hl,txt_xmodem        ; block 1 at once: XMODEM, no name, no size
        call xm_create
        ret nz
        ld a,1
        ld (xm_expect),a
        xor a
        ld (xm_hdr),a
xp_data:
        ld a,(xm_expect)
        ld b,a
        ld a,(xm_pkt)
        cp b
        jr z,xp_new
        inc a
        cp b
        jp z,xm_ack             ; the block before again (our ACK was lost): only ACK
        jp xm_nak
xp_new:
        ld hl,xm_pkt+2          ; its records to the file
        ld bc,(xm_psize)
xp_record:
        push hl
        push bc
        call xw_record
        pop bc
        pop hl
        jr nz,xp_disk
        ld de,128
        add hl,de
        ld a,c
        sub 128
        ld c,a
        ld a,b
        sbc a,0
        ld b,a
        or c
        jr nz,xp_record
        ld hl,xm_expect
        inc (hl)
        xor a
        ld (xm_tries),a
        call xm_progress
        jp xm_ack
xp_disk:
        ld a,XM_DISK
        ld (xm_result),a
        ld b,3
xpd_can:
        ld a,XM_CAN
        call tx_data
        djnz xpd_can
        jp tx_flush
xp_header:                      ; YMODEM block 0: the name (00h at the end, none = the end), the size
        ld a,(xm_pkt+2)
        or a
        jr nz,xp_file
        call xm_ack             ; an empty name: no more files
        ld a,XM_DONE
        ld (xm_result),a
        ret
xp_file:
        ld hl,xm_pkt+2
        call xm_create
        ret nz
        ld hl,xm_pkt+2          ; after the name: its size in decimal (none: unknown)
xpf_end:
        ld a,(hl)
        inc hl
        or a
        jr nz,xpf_end
        call parse_dec32
        ld a,1
        ld (xm_ymodem),a
        ld (xm_expect),a
        xor a
        ld (xm_hdr),a
        call xm_ack
        ld a,'C'                ; the data, CRC
        call xm_send
        jp xm_rearm
txt_xmodem:
        defb 'XMODEM.BIN',0

; xm_eot: the end of the file: it is closed and acknowledged; YMODEM asks for the next header, XMODEM is done.
xm_eot:
        call xm_close
        call xm_ack
        ld a,(xm_ymodem)
        or a
        jr nz,xe_next
        ld a,XM_DONE
        ld (xm_result),a
        ret
xe_next:
        ld a,1
        ld (xm_hdr),a
        xor a
        ld (xm_tries),a
        ld a,'C'
        call xm_send
        jp xm_rearm

xm_ack:
        ld a,XM_ACK
        call xm_send
        jp xm_rearm
xm_nak:
        ld a,XM_NAK
        call xm_send
        jp xm_rearm

; xm_check: Z when the CRC (CRC-16/XMODEM, high byte first) or the checksum of the data in xm_pkt fits.
; Changes all.
xm_check:
        ld hl,xm_pkt+2
        ld bc,(xm_psize)
        ld a,(xm_crcmode)
        or a
        jr z,xc_sum
        ld de,0                 ; DE = CRC
xc_byte:
        ld a,(hl)
        inc hl
        xor d
        ld d,a
        push bc
        ld b,8
xc_bit:
        ex de,hl
        add hl,hl
        jr nc,xc_next
        ld a,h
        xor 10h
        ld h,a
        ld a,l
        xor 21h
        ld l,a
xc_next:
        ex de,hl
        djnz xc_bit
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,xc_byte
        ld a,(hl)
        cp d
        ret nz
        inc hl
        ld a,(hl)
        cp e
        ret
xc_sum:
        xor a
xc_add:
        add a,(hl)
        inc hl
        dec bc
        ld e,a
        ld a,b
        or c
        ld a,e
        jr nz,xc_add
        cp (hl)
        ret

; xw_record: the record at HL (128 bytes) to the file, cut by the size from the header: past it nothing, the
; last one gets 1Ah after the end of the file. Z when written (or skipped), NZ when the disk failed.
; Changes all.
xw_record:
        ld a,(xm_left+3)
        ld b,a
        ld a,(xm_left+2)
        or b
        ld b,a
        ld a,(xm_left+1)
        or b
        jr nz,xw_full           ; 256 bytes or more left
        ld a,(xm_left)
        or a
        ret z                   ; nothing left: the padding of the sender
        cp 128
        jr nc,xw_full
        push hl                 ; the last record: 1Ah after the end
        ld c,a
        ld a,128
        sub c
        ld b,a
        ld a,c
        call add_hl_a
xw_pad:
        ld (hl),1Ah
        inc hl
        djnz xw_pad
        pop hl
        xor a
        ld (xm_left),a
        jr xw_write
xw_full:
        push hl
        ld hl,xm_left
        ld a,(hl)
        sub 128
        ld (hl),a
        inc hl
        ld a,(hl)
        sbc a,0
        ld (hl),a
        inc hl
        ld a,(hl)
        sbc a,0
        ld (hl),a
        inc hl
        ld a,(hl)
        sbc a,0
        ld (hl),a
        pop hl
xw_write:
        ex de,hl
        ld c,B_SETDMA
        call BDOS
        ld de,xm_fcb
        ld c,B_WRITESEQ
        call BDOS
        or a
        ret nz
        ld hl,(xm_recs)
        inc hl
        ld (xm_recs),hl
        xor a
        ret

; xm_create: a file named by the text at HL (a path is cut, 8.3, capitals, characters CP/M does not take as
; '_') made on cfg_drive; a name that is there gets a digit 1-9 at the end of its name part. Z when made,
; else NZ with xm_result = XM_DISK. Changes all.
xm_create:
        push hl
        ld hl,xm_fcb
        ld b,36
xcr_clear:
        ld (hl),0
        inc hl
        djnz xcr_clear
        ld a,(cfg_drive)
        inc a
        ld (xm_fcb),a
        ld hl,xm_fcb+1
        ld b,11
xcr_space:
        ld (hl),' '
        inc hl
        djnz xcr_space
        pop hl
        ld d,h                  ; the name starts after the last '/' or '\'
        ld e,l
xcr_path:
        ld a,(hl)
        inc hl
        or a
        jr z,xcr_name
        cp '/'
        jr z,xcr_cut
        cp '\'
        jr nz,xcr_path
xcr_cut:
        ld d,h
        ld e,l
        jr xcr_path
xcr_name:
        ex de,hl
        ld de,xm_fcb+1
        ld b,8
        call xm_name_part       ; up to '.'
        ld a,(hl)
        cp '.'
        jr nz,xcr_named
        inc hl
        ld de,xm_fcb+9
        ld b,3
        call xm_name_part
xcr_named:
        ld a,(xm_fcb+1)
        cp ' '
        jr nz,xcr_unique
        ld hl,txt_download      ; no name at all
        ld de,xm_fcb+1
        ld bc,8
        ldir
xcr_unique:
        ld b,'0'
xcr_try:
        push bc
        call xm_fcb_reset
        ld de,xm_fcb
        ld c,B_OPEN
        call BDOS
        pop bc
        inc a
        jr z,xcr_make
        inc b                   ; it is there: a digit at the end of the name
        ld a,b
        cp '9'+1
        jr nc,xcr_fail
        ld hl,xm_fcb+8
        ld c,8
xcr_last:                       ; after the last letter of the name, or over the eighth
        ld a,(hl)
        cp ' '
        jr nz,xcr_digit
        dec hl
        dec c
        jr nz,xcr_last
xcr_digit:
        ld a,c
        cp 8
        jr nc,xcr_set
        cp 1
        jr c,xcr_set
        ld a,b                  ; the first time after the name, then over that digit
        cp '1'
        jr nz,xcr_set
        inc hl
xcr_set:
        ld (hl),b
        jr xcr_try
xcr_make:
        call xm_fcb_reset
        ld de,xm_fcb
        ld c,B_MAKE
        call BDOS
        inc a
        jr z,xcr_fail
        ld a,1
        ld (xm_open),a
        ld hl,xm_files
        inc (hl)
        ld hl,0
        ld (xm_recs),hl
        dec hl                  ; the size: unknown until the header says it
        ld (xm_left),hl
        ld (xm_left+2),hl
        call xm_progress
        xor a
        ret
xcr_fail:
        ld a,XM_DISK
        ld (xm_result),a
        or a
        ret
txt_download:
        defb 'DOWNLOAD'

; xm_fcb_reset: xm_fcb from the extent on 0 (for open and make). Changes A, B, HL.
xm_fcb_reset:
        ld hl,xm_fcb+12
        ld b,36-12
xfr_clear:
        ld (hl),0
        inc hl
        djnz xfr_clear
        ret

; xm_name_part: up to B characters of the name at HL to DE (capitals, characters CP/M does not take as '_'),
; up to '.' or 00h; HL stays there (characters over B are skipped). Changes A, B, DE, HL.
xm_name_part:
        ld a,(hl)
        or a
        ret z
        cp '.'
        ret z
        inc hl
        inc b
        dec b
        jr z,xm_name_part
        dec b
        call upcase
        cp '!'
        jr c,xnp_bad
        cp 7Fh
        jr nc,xnp_bad
        push hl
        push bc
        ld hl,txt_bad_chars
        ld bc,9
        cpir
        pop bc
        pop hl
        jr nz,xnp_put
xnp_bad:
        ld a,'_'
xnp_put:
        ld (de),a
        inc de
        jr xm_name_part
txt_bad_chars:
        defb '*?:;,<>=|'

; xm_close: the open file closed. Changes all.
xm_close:
        ld a,(xm_open)
        or a
        ret z
        xor a
        ld (xm_open),a
        ld de,xm_fcb
        ld c,B_CLOSE
        jp BDOS


; parse_dec32: xm_left = the decimal number at HL (no digit there: it stays). Changes A, BC, DE, HL.
parse_dec32:
        ld a,(hl)
        sub '0'
        ret c
        cp 10
        ret nc
        ld de,0
        ld (xm_left),de
        ld (xm_left+2),de
pd_digit:
        ld a,(hl)
        sub '0'
        ret c
        cp 10
        ret nc
        inc hl
        push hl
        ld c,a                  ; xm_left * 10 + the digit, byte by byte from the lowest: C = the carry
        ld hl,xm_left
        ld b,4
pd_byte:
        ld a,(hl)
        push hl
        ld l,a
        ld h,0
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl
        ld e,c
        add hl,de
        ld c,h
        ld a,l
        pop hl
        ld (hl),a
        inc hl
        djnz pd_byte
        pop hl
        jr pd_digit

; xm_put_name: the name of xm_fcb as NAME.EXT to DE. Changes A, B, DE, HL.
xm_put_name:
        ld hl,xm_fcb+1
        ld b,8
xpn_name:
        ld a,(hl)
        inc hl
        cp ' '
        jr z,xpn_skip
        ld (de),a
        inc de
xpn_skip:
        djnz xpn_name
        ld a,(hl)
        cp ' '
        ret z
        ld a,'.'
        ld (de),a
        inc de
        ld b,3
xpn_ext:
        ld a,(hl)
        inc hl
        cp ' '
        jr z,xpn_eskip
        ld (de),a
        inc de
xpn_eskip:
        djnz xpn_ext
        ret

; put_dec16: HL in decimal (no leading zeros) to DE, DE after the digits. Changes A, BC, HL.
put_dec16:
        ld (pd_out),de
        ld c,0                  ; C = a digit was written
        ld de,10000
        call p16_digit
        ld de,1000
        call p16_digit
        ld de,100
        call p16_digit
        ld de,10
        call p16_digit
        ld a,l
        add a,'0'
        call p16_put
        ld de,(pd_out)
        ret
p16_digit:
        ld b,'0'-1
p16_sub:
        inc b
        and a
        sbc hl,de
        jr nc,p16_sub
        add hl,de
        ld a,b
        cp '0'
        jr nz,p16_first
        ld a,c
        or a
        ret z                   ; a leading zero
        ld a,b
p16_first:
        ld c,1
p16_put:
        push hl
        ld hl,(pd_out)
        ld (hl),a
        inc hl
        ld (pd_out),hl
        pop hl
        ret

; xm_progress: the file and its KB on the status card, every KB. Changes all.
xm_progress:
        ld a,(stat_dev)
        or a
        ret z
        ld a,(xm_recs)
        and 7
        ret nz
        ld de,msg_buf
        ld hl,t_xm_getting
        call put_str
        call xm_put_name
        ld a,' '
        ld (de),a
        inc de
        ld hl,(xm_recs)
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        call put_dec16
        ld hl,txt_kb
        call put_str
        ld b,4                  ; over a longer text before
xpg_space:
        ld a,' '
        ld (de),a
        inc de
        djnz xpg_space
        xor a
        ld (de),a
        ld de,XM_ROW*256+0
        ld hl,msg_buf
        jp ss_text
