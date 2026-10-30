; SAPI-Term - telnet (RFC 854) between the TCP connection of the DPI-1L and the terminal.
;
; Received bytes go through tn_filter: data to the input buffer of the terminal (in_end), commands answered. An
; option is answered only when its state changes (RFC 1143 in short), so there are no loops:
;   the server may DO TTYPE (we send "ANSI"), NAWS (we send the size of the terminal), BINARY, SGA; else WONT;
;   the server may WILL ECHO, SGA, BINARY (we DO them); else DONT.
; Sent bytes (keys, answers of the terminal) go to tx_buf: IAC doubled, CR followed by NUL (RFC 854) unless we
; send in binary mode. tx_flush sends tx_buf through TCPSEND.

TN_SE           equ 0F0h
TN_SB           equ 0FAh
TN_WILL         equ 0FBh
TN_WONT         equ 0FCh
TN_DO           equ 0FDh
TN_DONT         equ 0FEh
TN_IAC          equ 0FFh
OPT_BINARY      equ 0
OPT_ECHO        equ 1
OPT_SGA         equ 3
OPT_TTYPE       equ 24
OPT_NAWS        equ 31
TN_OPTS         equ 32              ; options with a state (0-31)
TN_SB_MAX       equ 16
TX_SIZE         equ 128

; tn_reset: no options agreed, no command half received, nothing to send. Changes A, B, HL.
tn_reset:
        xor a
        ld (tn_state),a
        ld (tx_len),a
        ld (tn_cr),a
        ld hl,tn_us
        ld b,2*TN_OPTS
tr_clear:
        ld (hl),a
        inc hl
        djnz tr_clear
        ret

; tn_filter: B received bytes at HL (B > 0); raw TCP (tn_raw): all of them data. Changes all.
tn_filter:
        ld a,(tn_raw)
        or a
        jr nz,tf_raw
tf_byte:
        ld a,(hl)
        inc hl
        push hl
        push bc
        call tn_byte
        pop bc
        pop hl
        djnz tf_byte
        ret
tf_raw:
        ld de,(in_end)
        ld c,b
        ld b,0
        ldir
        ld (in_end),de
        ret

; tn_byte: one received byte A.
tn_byte:
        ld c,a
        ld a,(tn_state)
        or a
        jr nz,tb_command
        ld a,c
        cp TN_IAC
        jr z,tb_state1
tb_data:
        ld a,c                  ; CR NUL from a server not in binary mode: the NUL is not data (RFC 854)
        or a
        jr nz,tb_store
        ld a,(tn_cr)
        or a
        jr z,tb_store
        ld a,(tn_them+OPT_BINARY)
        or a
        jr nz,tb_store
        xor a
        ld (tn_cr),a
        ret
tb_store:
        ld a,c
        sub 0Dh
        jr z,tb_cr
        ld a,1
tb_cr:
        xor 1
        ld (tn_cr),a
        ld hl,(in_end)
        ld (hl),c
        inc hl
        ld (in_end),hl
        ret
tb_state1:
        ld a,1
        ld (tn_state),a
        ret
tb_command:
        cp 1
        jr z,tb_after_iac
        cp 2
        jp z,tb_option
        cp 3
        jr z,tb_sb
        ld a,c                  ; 4: IAC inside SB
        cp TN_SE
        jr z,tb_sb_end
        cp TN_IAC
        jr z,tb_sb_store        ; IAC IAC = the byte FFh
        ld a,3
        ld (tn_state),a
        ret
tb_after_iac:
        xor a
        ld (tn_state),a
        ld a,c
        cp TN_IAC
        jr z,tb_data            ; IAC IAC = the data byte FFh
        cp TN_SB
        jr z,tb_sb_start
        cp TN_WILL
        ret c                   ; NOP, GA and the others: nothing
        ld (tn_verb),a
        ld a,2
        ld (tn_state),a
        ret
tb_sb_start:
        ld a,3
        ld (tn_state),a
        xor a
        ld (tn_sb_len),a
        ret
tb_sb:
        ld a,c
        cp TN_IAC
        jr nz,tb_sb_store
        ld a,4
        ld (tn_state),a
        ret
tb_sb_store:
        ld a,3
        ld (tn_state),a
        ld a,(tn_sb_len)
        cp TN_SB_MAX
        ret nc
        ld hl,tn_sb_buf
        call add_hl_a
        ld (hl),c
        inc a
        ld (tn_sb_len),a
        ret
tb_sb_end:
        xor a
        ld (tn_state),a
        ld a,(tn_sb_len)        ; TTYPE SEND -> TTYPE IS "ANSI"
        cp 2
        ret c
        ld a,(tn_sb_buf)
        cp OPT_TTYPE
        ret nz
        ld a,(tn_sb_buf+1)
        cp 1
        ret nz
        ld hl,tn_ttype
        ld b,TN_TTYPE_LEN
        jp tx_raw_n
tn_ttype:
        defb TN_IAC,TN_SB,OPT_TTYPE,0,'ANSI',TN_IAC,TN_SE
TN_TTYPE_LEN    equ 10

tb_option:                      ; C = option after WILL / WONT / DO / DONT
        xor a
        ld (tn_state),a
        ld a,c
        cp TN_OPTS
        jr nc,tb_refuse
        ld hl,tn_us
        call add_hl_a           ; HL = our state of the option, + TN_OPTS = theirs
        ld a,(tn_verb)
        cp TN_DO
        jr z,tb_do
        cp TN_DONT
        jr z,tb_dont
        ld de,TN_OPTS
        add hl,de
        cp TN_WILL
        jr z,tb_will
        ld a,(hl)               ; WONT: we stop asking for it
        or a
        ret z
        ld (hl),0
        ld b,TN_DONT
        jr tb_send
tb_do:
        ld a,c                  ; options we do: TTYPE, NAWS, BINARY, SGA
        cp OPT_TTYPE
        jr z,tb_do_yes
        cp OPT_NAWS
        jr z,tb_do_yes
        cp OPT_BINARY
        jr z,tb_do_yes
        cp OPT_SGA
        jr z,tb_do_yes
        ld b,TN_WONT
        jr tb_send
tb_do_yes:
        ld a,(hl)
        or a
        ret nz                  ; agreed already
        ld (hl),1
        ld b,TN_WILL
        call tb_send
        ld a,c
        cp OPT_NAWS
        ret nz
        jp tn_naws
tb_dont:
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        ld b,TN_WONT
        jr tb_send
tb_will:
        ld a,c                  ; options we let the server do: ECHO, SGA, BINARY
        cp OPT_ECHO
        jr z,tb_will_yes
        cp OPT_SGA
        jr z,tb_will_yes
        cp OPT_BINARY
        jr z,tb_will_yes
        ld b,TN_DONT
        jr tb_send
tb_will_yes:
        ld a,(hl)
        or a
        ret nz
        ld (hl),1
        ld b,TN_DO
        jr tb_send
tb_refuse:                      ; options 32 and up: DO -> WONT, WILL -> DONT
        ld a,(tn_verb)
        ld b,TN_WONT
        cp TN_DO
        jr z,tb_send
        ld b,TN_DONT
        cp TN_WILL
        ret nz
; tb_send: IAC, verb B, option C. Changes A, HL.
tb_send:
        ld a,TN_IAC
        call tx_raw
        ld a,b
        call tx_raw
        ld a,c
        jp tx_raw

; tn_naws: the size of the terminal (IAC SB NAWS 0 cols 0 rows IAC SE), when NAWS is agreed. Changes A, HL.
tn_naws:
        ld a,(tn_us+OPT_NAWS)
        or a
        ret z
        push bc
        ld a,TN_IAC
        call tx_raw
        ld a,TN_SB
        call tx_raw
        ld a,OPT_NAWS
        call tx_raw
        xor a
        call tx_raw
        ld a,(term_cols)
        call tx_raw
        xor a
        call tx_raw
        ld a,(term_rows)
        call tx_raw
        ld a,TN_IAC
        call tx_raw
        ld a,TN_SE
        call tx_raw
        pop bc
        ret

; --- sending ---

; tx_data: data byte A to the BBS (FFh doubled, CR + NUL unless binary; raw TCP: as it is). Changes A, HL.
tx_data:
        push af
        ld a,(tn_raw)
        or a
        jr z,td_telnet
        pop af
        jr tx_raw
td_telnet:
        pop af
        cp TN_IAC
        jr nz,td_cr
        call tx_raw
        ld a,TN_IAC
        jr tx_raw
td_cr:
        cp 0Dh
        jr nz,tx_raw
        call tx_raw
        ld a,(tn_us+OPT_BINARY)
        or a
        ret nz
        xor a
; tx_raw: byte A to tx_buf as it is (a full buffer is sent first). Changes A, HL.
tx_raw:
        push af
        ld a,(tx_len)
        cp TX_SIZE
        call nc,tx_flush
        ld a,(tx_len)
        ld hl,tx_buf
        call add_hl_a
        inc a
        ld (tx_len),a
        pop af
        ld (hl),a
        ret

; tx_raw_n: B bytes at HL as they are. Changes A, B, HL.
tx_raw_n:
        ld a,(hl)
        inc hl
        push hl
        call tx_raw
        pop hl
        djnz tx_raw_n
        ret

; tx_str: the data bytes at HL up to 00h. Changes A, HL.
tx_str:
        ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call tx_data
        pop hl
        jr tx_str

; tn_reply: reply_hook of the terminal: ans_reply goes to the BBS. Changes A, HL.
tn_reply:
        ld hl,ans_reply
        jr tx_str

; tx_flush: tx_buf through TCPSEND. When the card has no room (error 5), again in the next ticks, for at most
; 2 s (then the bytes are dropped). Changes A, HL.
tx_flush:
        ld a,(tx_len)
        or a
        ret z
        push bc
        push de
        ld a,120
        ld (tx_tries),a
tf_send:
        ld a,(tx_len)
        ld b,a
        ld hl,tx_buf
        call net_send
        jr z,tf_done
        cp 80h+5
        jr nz,tf_done           ; another error: drop
        ld a,(tx_tries)
        dec a
        ld (tx_tries),a
        jr z,tf_done
tf_wait:
        call kbd_scan
        call tick_poll
        jr z,tf_wait
        jr tf_send
tf_done:
        xor a
        ld (tx_len),a
        pop de
        pop bc
        ret
