; SAPI-Term - the address of a BBS, the connection and the terminal on line.
;
; ui_prompt asks for "host[:port]" (port 23 when none) on the terminal. online resolves the name (DNSREQ), opens
; TCP, then runs: keys to the BBS (arrows and the like as ANSI sequences), received bytes through telnet into
; the input buffer and the ANSI terminal (jump scroll looks ahead in it). Ctrl+] opens the menu on the status
; card: disconnect, quit, swap the cards, keyboard type. The connection ends when the BBS closes it.

MODE_LOCAL      equ 0               ; test screen, typewriter
MODE_VIEW       equ 1               ; a file shown
MODE_ONLINE     equ 2               ; connected to a BBS
LINE_MAX        equ 63
RX_CHUNK        equ 253             ; TCPRECV at most
IDLE_CHECK      equ 30              ; ticks without data between TCPSTATUS checks (0.5 s)

; ui_prompt: the start screen with the input of the address. A = 0 connect to ui_line, 1 test screen, 2 quit.
; Changes all.
ui_prompt:
        call ansi_reset
        call scr_cls
        ld a,0Fh
        ld de,0*256+0
        ld hl,t_ui_title
        call ts_text
        ld a,07h
        ld de,2*256+0
        ld hl,t_ui_help1
        call ts_text
        ld a,07h
        ld de,3*256+0
        ld hl,t_ui_help2
        call ts_text
        ld a,(has_dpi)
        or a
        jr nz,up_msg
        ld a,0Ch
        ld de,5*256+0
        ld hl,t_no_dpi
        call ts_text
up_msg:
        ld hl,(ui_msg)          ; how the last connection ended
        ld a,h
        or l
        jr z,up_input
        ld a,0Eh
        ld de,5*256+0
        call ts_text
up_input:
        ld a,0Bh
        ld de,7*256+0
        ld hl,t_ui_prompt
        call ts_text
        ld a,0Fh
        ld (cur_att),a
        call stat_screen
        call ui_input
        ret nz                  ; A = 2: quit
        ld a,(ui_len)
        or a
        ld a,1
        ret z                   ; empty: test screen
        ld a,(has_dpi)
        or a
        ld a,1
        ret z
        xor a
        ret

; ui_input: a line of up to LINE_MAX characters to ui_line (00h at the end, ui_len), typed at the cursor;
; Backspace (and the left arrow) deletes. NZ with A = 2 for Ctrl+]. Changes all.
ui_input:
        xor a
        ld (ui_len),a
        ld (ui_line),a
        call cur_restart
ui_key:
        call kbd_get
        jr c,ui_got
        call tick_poll
        call nz,cur_tick
        call pal_pending
        call nz,scr_flush
        jr ui_key
ui_got:
        ld (last_key),a
        push af
        call cur_hide
        pop af
        cp K_MENU
        jr z,ui_quit
        cp 0Dh
        jr z,ui_done
        cp 08h
        jr z,ui_back
        cp 13h                  ; left arrow of EKL-1 and of the Consul
        jr z,ui_back
        cp 0C4h
        jr z,ui_back
        cp ' '
        jr c,ui_next
        cp 7Fh
        jr nc,ui_next
        ld b,a
        ld a,(ui_len)
        cp LINE_MAX
        jr nc,ui_next
        ld hl,ui_line
        call add_hl_a
        ld (hl),b
        inc hl
        ld (hl),0
        inc a
        ld (ui_len),a
        ld a,b
        call scr_putc
ui_next:
        call cur_restart
        jr ui_key
ui_back:
        ld a,(ui_len)
        or a
        jr z,ui_next
        dec a
        ld (ui_len),a
        ld hl,ui_line
        call add_hl_a
        ld (hl),0
        call ans_bs
        ld a,' '
        call scr_putc
        call ans_bs
        jr ui_next
ui_done:
        call ans_cr
        call scr_lf
        xor a
        ret
ui_quit:
        ld a,2
        or a
        ret

; online: connect to ui_line and run the terminal until the end of the connection. ui_msg = how it ended.
; Changes all.
online:
        call parse_address
        ld hl,t_looking
        call ol_say
        ld hl,net_host
        call net_dns
        or a
        jr z,ol_found
        ld hl,t_err_dns
        dec a
        jr z,ol_fail
        ld hl,t_err_timeout
        dec a
        jr z,ol_fail
        ld hl,t_stopped
ol_fail:
        ld (ui_msg),hl
        ret
ol_found:
        ld hl,t_connecting
        call ol_say
        call net_open
        or a
        jr z,ol_open
        ld hl,t_err_connect
        dec a
        jr z,ol_fail
        ld hl,t_err_timeout
        dec a
        jr z,ol_fail
        ld hl,t_stopped
        jr ol_fail
ol_open:
        ld a,MODE_ONLINE
        ld (mode),a
        call tn_reset
        ld hl,tn_reply
        ld (reply_hook),hl
        ld hl,in_buf
        ld (in_ptr),hl
        ld (in_end),hl
        ld a,1
        ld (js_enable),a
        ld hl,t_connected
        call ol_say
        call ansi_reset
        call stat_screen
        call cur_restart
        xor a
        ld (ol_idle),a
ol_loop:
        call kbd_get
        jr nc,ol_net
        ld (last_key),a
        cp K_MENU
        jp z,ol_menu
        call key_send
ol_net:
        call tx_flush
        call net_rx
        jr z,ol_quiet
        call cur_hide
        call feed_input
        call pal_pending        ; new colours of this block to the palette (in the next VBI)
        call nz,scr_flush
        xor a
        ld (ol_idle),a
        jp ol_loop
ol_quiet:
        call cur_show
        call pal_pending
        call nz,scr_flush
        call tick_poll
        jr z,ol_loop
        call cur_tick
        ld a,(ol_idle)
        inc a
        ld (ol_idle),a
        cp IDLE_CHECK
        jr c,ol_loop
        xor a
        ld (ol_idle),a
        call net_status         ; still connected?
        cp TCP_CONNECTED
        jr z,ol_loop
        cp TCP_CLOSED
        jr nz,ol_closed
        ld a,h                  ; closed by the BBS: read what is left first
        or l
        jr nz,ol_loop
ol_closed:
        ld hl,t_closed
ol_end:
        ld (ui_msg),hl
        call cur_hide
        call tx_flush
        call dpi_close
        xor a
        ld (js_enable),a
        ld (mode),a
        ld hl,0
        ld (reply_hook),hl
        ret

; ol_menu: Ctrl+] on line. Without a status card it disconnects at once.
ol_menu:
        ld a,(stat_dev)
        or a
        jp z,ol_user_end
om_show:
        call stat_cls
        ld de,0*256+0
        ld hl,t_menu_title
        call ss_text
        ld de,2*256+2
        ld hl,t_menu_off
        call ss_text
        ld de,3*256+2
        ld hl,t_menu_quit
        call ss_text
        ld de,4*256+2
        ld hl,t_menu_swap
        call ss_text
        ld de,5*256+2
        ld hl,t_menu_kbd
        call ss_text
        call show_kbd
        ld de,6*256+2
        ld hl,t_menu_back
        call ss_text
om_key:
        call kbd_get
        jr nc,om_key
        and 0DFh                ; letters as capitals
        cp 'O'
        jr z,ol_user_end
        cp 'K'
        jp z,quit
        cp 'T'
        jr z,om_kbd
        cp 09h                  ; Tab (09h stays 09h)
        jr z,om_swap
        cp 1Bh
        jr z,om_back
        cp K_MENU
        jr z,om_back
        jr om_key
om_kbd:
        ld a,(kbd_type)
        xor 1
        ld (kbd_type),a
        jr om_show
om_swap:
        call cur_hide
        call swap_cards
        call tn_naws            ; the BBS gets the new size at once
        call tx_flush
        jp om_show
om_back:
        call stat_screen
        call cur_restart
        jp ol_loop
ol_user_end:
        ld hl,t_disconnected
        jp ol_end

; show_kbd: the keyboard type after the menu line. Changes all.
show_kbd:
        ld hl,t_kbd_ekl
        ld a,(kbd_type)
        or a
        jr z,sk_put
        ld hl,t_kbd_consul
sk_put:
        jp stat_puts

; ol_say: the KOI text HL on its own line of the terminal (yellow). Changes all.
ol_say:
        push hl
        ld a,(cur_att)
        push af
        ld a,0Eh
        ld (cur_att),a
        call scr_puts_koi
        call ans_cr
        call scr_lf
        pop af
        ld (cur_att),a
        pop hl
        ret

; parse_address: ui_line "host[:port]" -> net_host (00h at the end), net_port (23 when none). Changes all.
parse_address:
        ld hl,ui_line
        ld de,net_host
        ld b,LINE_MAX
pa_host:
        ld a,(hl)
        or a
        jr z,pa_end
        cp ':'
        jr z,pa_port
        cp ' '
        jr z,pa_skip
        ld (de),a
        inc de
pa_skip:
        inc hl
        djnz pa_host
pa_end:
        xor a
        ld (de),a
        ld hl,23
        ld (net_port),hl
        ret
pa_port:
        xor a
        ld (de),a
        inc hl
        ld de,0
pa_digit:
        ld a,(hl)
        sub '0'
        jr c,pa_done
        cp 10
        jr nc,pa_done
        push hl
        ld h,d
        ld l,e
        add hl,hl
        add hl,hl
        add hl,de
        add hl,hl               ; * 10
        ld e,a
        ld d,0
        add hl,de
        ex de,hl
        pop hl
        inc hl
        jr pa_digit
pa_done:
        ld a,d
        or e
        jr nz,pa_set
        ld de,23
pa_set:
        ld (net_port),de
        ret

; net_rx: received bytes (up to 8 TCPRECV, while the card has more and there is room) through telnet into
; in_buf from its start. NZ when there are data for the terminal. Changes all.
net_rx:
        ld hl,in_buf
        ld (in_ptr),hl
        ld (in_end),hl
        ld a,8
        ld (rx_chunks),a
nr_chunk:
        ld hl,in_buf+IN_RECORDS*128-RX_CHUNK
        ld de,(in_end)
        or a
        sbc hl,de
        jr c,nr_done            ; no room for another one
        ld de,rx_raw
        ld b,RX_CHUNK
        call net_recv
        or a
        jr z,nr_done
        ld b,a
        push af
        ld hl,rx_raw
        call tn_filter
        pop af
        cp RX_CHUNK
        jr c,nr_done            ; a short one: nothing more now
        ld a,(rx_chunks)
        dec a
        ld (rx_chunks),a
        jr nz,nr_chunk
nr_done:
        ld hl,(in_end)
        ld de,in_buf
        or a
        sbc hl,de
        ld a,h
        or l
        ret

; feed_input: the input buffer through the ANSI terminal. Changes all.
feed_input:
        ld hl,(in_ptr)
        ld de,(in_end)
        ld a,l
        cp e
        jr nz,fi_byte
        ld a,h
        cp d
        ret z
fi_byte:
        ld a,(hl)
        inc hl
        ld (in_ptr),hl
        call ansi_putc
        jr feed_input

; key_send: key A to the BBS. Cursor keys and the like as ANSI sequences: EKL-1 sends them as WordStar codes
; (05 18 13 04, Home 1E, End 11, PgUp 12, Ins 16, Del 0B), the Consul 262.3 as C1-C4, Home 8D, keypad B0-B9
; (kbd_type chooses). Changes all.
key_send:
        ld c,a
        ld hl,keys_ekl
        ld a,(kbd_type)
        or a
        jr z,ks_find
        ld hl,keys_consul
ks_find:
        ld a,(hl)
        or a
        jr z,ks_plain
        cp c
        jr z,ks_seq
ks_skip:
        inc hl
        ld a,(hl)
        or a
        jr nz,ks_skip
        inc hl
        jr ks_find
ks_seq:
        inc hl
        jp tx_str
ks_plain:
        ld a,c
        cp 80h
        jp c,tx_data            ; ASCII and controls as they are
        ret                     ; others (Czech letters, function keys) not yet

; key tables: code, the sequence, 00h; the list ends with 00h
keys_ekl:
        defb 05h,1Bh,'[A',0, 18h,1Bh,'[B',0, 04h,1Bh,'[C',0, 13h,1Bh,'[D',0
        defb 1Eh,1Bh,'[H',0, 11h,1Bh,'[K',0, 12h,1Bh,'[V',0, 16h,1Bh,'[@',0, 0Bh,7Fh,0
        defb 0
keys_consul:
        defb 0C1h,1Bh,'[A',0, 0C2h,1Bh,'[B',0, 0C3h,1Bh,'[C',0, 0C4h,1Bh,'[D',0, 8Dh,1Bh,'[H',0
        defb 0B0h,'0',0, 0B1h,'1',0, 0B2h,'2',0, 0B3h,'3',0, 0B4h,'4',0, 0B5h,'5',0, 0B6h,'6',0
        defb 0B7h,'7',0, 0B8h,'8',0, 0B9h,'9',0, 0AEh,'.',0
        defb 0
