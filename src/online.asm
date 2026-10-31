; SAPI-Term - the address of a BBS, the connection and the terminal on line.
;
; ui_prompt asks for "host[:port]" (port 23 when none) or a number of the address book on the terminal. online
; resolves the name (DNSREQ), opens TCP, then runs: keys to the BBS (arrows and the like as ANSI sequences),
; received bytes through telnet into the input buffer and the ANSI terminal (jump scroll looks ahead in it).
; Bytes 80h-FFh go through the character set of the BBS (charset.asm). The speed of a modem (menu R) lets
; the bytes to the terminal at that speed, as ANSI animations expect. Ctrl+] opens the menu on the status
; card: disconnect, quit, swap the cards, keyboard type, character set, speed, columns, into the book, the
; session log, a download (xfer.asm), the history (history.asm). The connection ends when the BBS closes it.

MODE_LOCAL      equ 0               ; test screen, typewriter
MODE_VIEW       equ 1               ; a file shown
MODE_ONLINE     equ 2               ; connected to a BBS
LINE_MAX        equ 63
MSG_ROW         equ 6               ; the start screen: how the last connection ended
BOOK_ROW        equ 8               ; the address book (8 rows of entries below)
PROMPT_ROW      equ 18              ; the input of the address
RX_CHUNK        equ 253             ; TCPRECV at most
IDLE_CHECK      equ 30              ; ticks without data between TCPSTATUS checks (0.5 s)

; ui_prompt: the start screen: the help, how the last connection ended, the address book (SAPITERM.CFG) and
; the input of an address or of a number from the book ("-number" deletes it). Tab moves the terminal to the
; other card, Ctrl+] opens ui_menu (K there ends the program). A = 0 connect to ui_line, 1 test screen.
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
        ld a,07h
        ld de,4*256+0
        ld hl,t_ui_help3
        call ts_text
        ld a,(has_dpi)
        or a
        jr nz,up_msg
        ld a,0Ch
        ld de,MSG_ROW*256+0
        ld hl,t_no_dpi
        call ts_text
up_msg:
        ld hl,(ui_msg)          ; how the last connection ended, or what the book did
        ld a,h
        or l
        jr z,up_book
        ld a,0Eh
        ld de,MSG_ROW*256+0
        call ts_text
up_book:
        call ui_book
        ld a,0Bh
        ld de,PROMPT_ROW*256+0
        ld hl,t_ui_prompt
        call ts_text
        ld a,0Fh
        ld (cur_att),a
        call stat_screen
        call ui_input
        jr z,up_line
        cp 2
        jr nz,up_tab
        call ui_menu            ; Ctrl+]: the settings without a BBS
        jp ui_prompt
up_tab:
        call swap_cards         ; Tab: the terminal to the other card, kept in the file
        call cfg_save_msg
        jp ui_prompt
up_line:
        ld a,(ui_len)
        or a
        ld a,1
        ret z                   ; empty: test screen
        ld hl,ui_line
        ld a,(hl)
        cp '-'
        jr z,up_delete
        call parse_num
        jr c,up_address
        call book_pick          ; a number: the address from the book
        jr c,up_nonum
up_address:
        ld a,(has_dpi)
        or a
        ld a,1
        ret z
        xor a
        ret
up_delete:
        inc hl
        call parse_num
        jr c,up_nonum
        call book_delete
        jr c,up_nonum
        call cfg_save_msg
        jp ui_prompt
up_nonum:
        ld hl,t_no_number
        ld (ui_msg),hl
        jp ui_prompt

; cfg_save_msg: cfg_save, ui_msg and om_msg = how it went. Changes all.
cfg_save_msg:
        call cfg_save
        ld hl,t_saved
        or a
        jr z,csm_set
        ld hl,t_save_fail
csm_set:
        ld (ui_msg),hl
        ld (om_msg),hl
        ret

; ui_book: the address book on the start screen: its file at BOOK_ROW, the entries below it in two columns of
; 8 ("number name"). Changes all.
ui_book:
        ld a,07h
        ld de,BOOK_ROW*256+0
        ld hl,t_book
        call ts_text
        ld a,(cfg_drive)
        add a,'A'
        call scr_putc
        ld hl,txt_cfg_file
        call scr_puts_koi
        ld a,(book_n)
        or a
        jr nz,ub_list
        ld hl,t_book_empty
        jp scr_puts_koi
ub_list:
        ld a,':'
        call scr_putc
        xor a
ub_entry:
        ld hl,book_n
        cp (hl)
        ret nc
        push af
        ld b,a
        and 7
        add a,BOOK_ROW+1
        ld d,a
        ld e,0
        bit 3,b
        jr z,ub_at
        ld a,(term_cols)
        srl a
        ld e,a
ub_at:
        call scr_at
        ld a,0Fh
        ld (cur_att),a
        pop af
        push af
        inc a
        call ui_num2
        ld a,07h
        ld (cur_att),a
        ld a,' '
        call scr_putc
        pop af
        push af
        call book_entry_a
        ex de,hl                ; HL = the name
        ld a,(term_cols)
        srl a
        sub 4
        ld b,a
        call ui_puts_n
        pop af
        inc a
        jr ub_entry

; ui_num2: A (0-99) in two places, a space before a single digit. Changes all.
ui_num2:
        ld b,'0'-1
un2_ten:
        inc b
        sub 10
        jr nc,un2_ten
        add a,10+'0'
        push af
        ld a,b
        cp '0'
        jr nz,un2_put
        ld a,' '
un2_put:
        call scr_putc
        pop af
        jp scr_putc

; ui_puts_n: the KOI text at HL (00h at the end), at most B characters. Changes all.
ui_puts_n:
        ld a,(hl)
        or a
        ret z
        inc hl
        push bc
        push hl
        call scr_putc_koi
        pop hl
        pop bc
        djnz ui_puts_n
        ret

; parse_num: the text at HL (00h at the end) as a number 0-99 to A; C when it is not one. Changes A, BC, HL.
parse_num:
        ld a,(hl)
        or a
        scf
        ret z
        ld b,0
pnum_digit:
        ld a,(hl)
        or a
        jr z,pnum_end
        sub '0'
        ret c
        cp 10
        ccf
        ret c
        ld c,a
        ld a,b
        cp 10
        ccf
        ret c                   ; a third digit
        add a,a
        add a,a
        add a,b
        add a,a
        add a,c
        ld b,a
        inc hl
        jr pnum_digit
pnum_end:
        ld a,b
        or a
        ret

; ui_input: a line of up to LINE_MAX characters to ui_line (00h at the end, ui_len), typed at the cursor;
; Backspace (and the left arrow) deletes. NZ with A = 2 for Ctrl+], A = 3 for Tab (with both cards).
; Changes all.
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
        push af
        call cur_hide
        pop af
        cp K_MENU
        jr z,ui_quit
        cp 09h
        jr z,ui_tab
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
ui_tab:
        ld a,(stat_dev)
        or a
        jr z,ui_next
        ld a,3
        ret

; online: connect to ui_line and run the terminal until the end of the connection. ui_msg = how it ended.
; Changes all.
online:
        call parse_address
        xor a
        ld (utf_need),a
        call book_find          ; the character set of the BBS from the book (bit 7: raw TCP), else CP437
        ld b,CS_CP437
        jr c,ol_cs
        call book_cs
        ld b,(hl)
ol_cs:
        ld a,b
        and 7Fh
        ld (cs_type),a
        ld a,b
        and 80h
        ld (tn_raw),a
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
        call term_size          ; 40 columns on the CGA-1V (COLUMNS=40): a new screen
        ld a,(cga_wide)
        or a
        call nz,scr_cls
        call tn_reset
        ld hl,tn_reply
        ld (reply_hook),hl
        ld hl,in_buf
        ld (in_ptr),hl
        ld (in_end),hl
        call ol_clock_reset
        call js_by_speed
        call term8_enter        ; a PETSCII or ATASCII BBS of the book: the screen of a C64 or an Atari
        ld hl,t_connected
        call ol_say
        call ansi_reset
        call term8_att
        call stat_screen
        call cur_restart
        xor a
        ld (ol_idle),a
ol_loop:
        call ol_clock
        call kbd_get
        jr nc,ol_net
        cp K_MENU
        jp z,ol_menu
        call key_send
ol_net:
        call tx_flush
        ld a,(speed)
        or a
        jr nz,ol_slow
        call net_rx
        jr z,ol_quiet
        call cur_hide
        call feed_input
        call pal_pending        ; new colours of this block to the palette (in the next VBI)
        call nz,scr_flush
        xor a
        ld (ol_idle),a
        jp ol_loop
ol_slow:                        ; the speed of a modem: the received bytes go to the terminal in their time
        ld hl,(in_ptr)
        ld de,(in_end)
        or a
        sbc hl,de
        jr nz,ol_pace
        call net_rx             ; all shown: the next ones
        jr z,ol_quiet
        call pace_reset         ; the time of the line starts with the data
ol_pace:
        call pace_due
        or a
        jp z,ol_loop
        call cur_hide
        call pace_feed
        call pal_pending
        call nz,scr_flush
        call cur_show
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
        call ol_tick
        ld a,(ol_idle)
        inc a
        ld (ol_idle),a
        cp IDLE_CHECK
        jp c,ol_loop
        xor a
        ld (ol_idle),a
        call net_status         ; still connected?
        cp TCP_CONNECTED
        jp z,ol_loop
        cp TCP_CLOSED
        jr nz,ol_closed
        ld a,h                  ; closed by the BBS: read what is left first
        or l
        jp nz,ol_loop
ol_closed:
        ld hl,t_closed
ol_end:
        ld (ui_msg),hl
        call cur_hide
        call tx_flush
        call dpi_close
        call log_stop
        call term8_leave
        xor a
        ld (js_enable),a
        ld (mode),a
        ld (cs_type),a
        call term_size          ; 80 columns again
        ld hl,0
        ld (reply_hook),hl
        ret

; ol_menu: Ctrl+] on line: the menu on the card of the terminal (it stands meanwhile; the status card stays),
; Esc draws the terminal again from the shadow. The book (U) is saved in SAPITERM.CFG at once, the keyboard type,
; the speed, the columns and the card of the terminal when the menu closes (om_flush: a write takes 0.3 s).
ol_menu:
        call cur_hide
        ld a,(stat_dev)
        ld (om_stat),a
        call om_here
        ld hl,0
        ld (om_msg),hl
        xor a
        ld (om_save),a
om_show:                        ; the whole menu on a clear card
        call stat_cls
om_lines:                       ; its lines over the old ones (after T U L N R: no clearing, no new colours)
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
        call om_pad16
        ld de,6*256+2
        ld hl,t_menu_cs
        call ss_text
        call show_cs
        call om_pad16
        ld de,7*256+2
        ld hl,t_menu_speed
        call ss_text
        call show_speed
        call om_pad16
        ld de,8*256+2
        ld hl,t_menu_cols
        call ss_text
        call show_cols
        ld de,9*256+2
        ld hl,t_menu_book
        call ss_text
        ld de,10*256+2
        ld hl,t_menu_log
        call ss_text
        call show_log
        call om_pad16
        ld de,11*256+2
        ld hl,t_menu_dl
        call ss_text
        ld de,12*256+2
        ld hl,t_menu_hist
        call ss_text
        ld de,13*256+2
        ld hl,t_menu_raw
        call ss_text
        ld hl,t_proto_telnet
        ld a,(tn_raw)
        or a
        jr z,om_proto
        ld hl,t_proto_raw
om_proto:
        call stat_puts
        call om_pad16
        ld de,14*256+2
        ld hl,t_menu_back
        call ss_text
        ld de,16*256+0
        call stat_at
        ld hl,(om_msg)          ; what the last choice did (none: the old message wiped)
        ld b,40
        ld a,h
        or l
        jr z,om_wipe
        call stat_puts
        ld b,16
om_wipe:
        call om_pad
om_key:
        call kbd_get
        jr nc,om_key
        and 0DFh                ; letters as capitals
        cp 'O'
        jp z,om_end
        cp 'K'
        jp z,om_quit
        cp 'T'
        jr z,om_kbd
        cp 'U'
        jr z,om_book
        cp 'Z'
        jp z,om_cs
        cp 'R'
        jp z,om_speed
        cp 'S'
        jp z,om_width
        cp 'L'
        jr z,om_log
        cp 'D'
        jp z,om_download
        cp 'H'
        jr z,om_hist
        cp 'N'
        jr z,om_raw
        cp 09h                  ; Tab (09h stays 09h)
        jr z,om_swap
        cp 1Bh
        jp z,om_back
        cp K_MENU
        jp z,om_back
        jr om_key
om_kbd:
        ld a,(kbd_type)
        xor 1
        ld (kbd_type),a
        call om_dirty
        jp om_lines
om_swap:                        ; the terminal (and the menu) to the other card
        call om_leave
        call swap_cards
        call tn_naws            ; the BBS gets the new size at once
        call tx_flush
        call om_dirty
        ld a,(stat_dev)
        ld (om_stat),a
        call om_here
        jp om_show
om_book:                        ; this BBS and its set into the book (its host as the name)
        call book_add
        ld hl,t_book_full
        or a
        jr nz,om_said
        call cfg_save_msg
        jp om_lines
om_said:
        ld (om_msg),hl
        jp om_lines
om_log:                         ; the session log on or off
        ld a,(log_on)
        or a
        jr nz,om_log_off
        call log_start
        ld hl,t_log_fail
        or a
        jr nz,om_said
        jr om_log_said
om_log_off:
        call log_stop
om_log_said:
        ld hl,0
        jr om_said
om_raw:                         ; telnet or raw TCP (U keeps it for the BBS)
        ld a,(tn_raw)
        xor 80h
        ld (tn_raw),a
        ld hl,0
        ld (om_msg),hl
        jp om_lines
om_hist:                        ; the rows that scrolled off (it draws the terminal again), back to the BBS after it
        ld a,(hist_count)
        or a
        jp z,om_back
        call om_leave
        call om_flush
        call pet_palette
        call hist_view
        call cur_restart
        jp ol_loop
om_download:                    ; XMODEM, YMODEM (the BBS was told to send first)
        call stat_cls
        ld de,0*256+0
        ld hl,t_xm_title
        call ss_text
        call xm_run
        ld (om_msg),hl
        jp om_show
om_width:                       ; 80 or 40 columns on the CGA-1V, kept in the file
        ld a,(cols40)
        xor 1
        ld (cols40),a
        call om_leave
        call term_resize
        call om_here
        call tn_naws            ; the BBS gets the new size at once
        call tx_flush
        call om_dirty
        jp om_show
om_speed:                       ; the next speed (slower), kept in the file
        call speed_next
        call js_by_speed
        call pace_reset
        call om_dirty
        jp om_lines
om_cs:                          ; the next character set (U keeps it for the BBS)
        call cur_hide
        ld a,(cs_type)
        inc a
        cp CS_COUNT
        jr c,om_cs_new
        xor a
om_cs_new:
        push af
        call term8_leave        ; from PETSCII or ATASCII: the ANSI terminal again
        pop af
        ld (cs_type),a
        call term8_enter        ; to PETSCII or ATASCII: the screen of a C64 or an Atari
        call om_here            ; the menu stays in the colours of ANSI
        call tn_naws            ; the size may have changed
        call tx_flush
        xor a
        ld (utf_need),a
        ld hl,0
        ld (om_msg),hl
        jp om_show
om_back:
        call om_leave
        call om_flush
        call pet_palette        ; the colours of the terminal again
        call scr_redraw         ; the terminal from the shadow (the menu covered it)
        call stat_screen
        call cur_restart
        jp ol_loop
om_end:
        call om_leave
        call om_flush
        jp ol_user_end
om_quit:
        call om_leave
        call om_flush
        jp quit

; om_dirty: a setting changed, SAPITERM.CFG gets it when the menu closes (om_flush). Changes A, HL.
om_dirty:
        ld a,1
        ld (om_save),a
        ld hl,0
        ld (om_msg),hl
        ret

; om_flush: the settings changed in the menu to SAPITERM.CFG. Changes all.
om_flush:
        ld a,(om_save)
        or a
        ret z
        xor a
        ld (om_save),a
        jp cfg_save

; om_here: the menu output (the stat_ routines) goes to the card of the terminal, in the colours of ANSI (its
; pairs start anew there, stat_cls). Changes A, HL.
om_here:
        ld a,(term_dev)
        ld (stat_dev),a
        ld hl,ansi_rgb
        ld (rgb_tab),hl
        ret

; om_pad16, om_pad: 16 or B spaces after a value of the menu (the rest of a longer old one). Changes A, B.
om_pad16:
        ld b,16
om_pad:
        ld a,' '
        call stat_putc
        djnz om_pad
        ret

; om_leave: the status card back to stat_dev. Changes A.
om_leave:
        ld a,(om_stat)
        ld (stat_dev),a
        ret

; ui_menu: Ctrl+] on the start screen: what is set without a BBS (the keyboard type, the speed of the line, the
; columns, Tab) and K, on the card of the terminal as ol_menu. Esc or Ctrl+] back: SAPITERM.CFG gets the
; changes, ui_msg says how it went. Changes all.
ui_menu:
        ld a,(stat_dev)
        ld (om_stat),a
        call om_here
        xor a
        ld (om_save),a
um_show:
        call stat_cls
um_lines:
        ld de,0*256+0
        ld hl,t_menu_title
        call ss_text
        ld de,2*256+2
        ld hl,t_menu_end
        call ss_text
        ld de,3*256+2
        ld hl,t_menu_swap
        call ss_text
        ld de,4*256+2
        ld hl,t_menu_kbd
        call ss_text
        call show_kbd
        call om_pad16
        ld de,5*256+2
        ld hl,t_menu_speed
        call ss_text
        call show_speed
        call om_pad16
        ld de,6*256+2
        ld hl,t_menu_cols
        call ss_text
        call show_cols
        ld de,7*256+2
        ld hl,t_menu_prompt
        call ss_text
um_key:
        call kbd_get
        jr nc,um_key
        and 0DFh                ; letters as capitals
        cp 'K'
        jr z,um_quit
        cp 'T'
        jr z,um_kbd
        cp 'R'
        jr z,um_speed
        cp 'S'
        jr z,um_cols
        cp 09h                  ; Tab
        jr z,um_swap
        cp 1Bh
        jr z,um_back
        cp K_MENU
        jr z,um_back
        jr um_key
um_kbd:
        ld a,(kbd_type)
        xor 1
        ld (kbd_type),a
        call om_dirty
        jr um_lines
um_speed:
        call speed_next
        call om_dirty
        jp um_lines
um_cols:                        ; only kept: the start screen has 80 columns, a BBS gets these
        ld a,(cols40)
        xor 1
        ld (cols40),a
        call om_dirty
        jp um_lines
um_swap:                        ; the start screen (and the menu) to the other card
        call om_leave
        call swap_cards
        call om_dirty
        ld a,(stat_dev)
        ld (om_stat),a
        call om_here
        jp um_show
um_back:
        call om_leave
        ld a,(om_save)
        or a
        ret z
        xor a
        ld (om_save),a
        jp cfg_save_msg
um_quit:
        call om_leave
        call om_flush
        jp quit

; speed_next: the next speed of the line (slower, after the slowest MAX again). Changes A.
speed_next:
        ld a,(speed)
        inc a
        cp SPEED_COUNT
        jr c,sn_set
        xor a
sn_set:
        ld (speed),a
        ret

; ol_clock_reset: the time and the data on line from zero (a new connection): the MPH-1V counter 0, without it
; the time of the RTC of the DPI-1L (rtc_ok; when the card does not give it, the quiet ticks count).
; Changes A, BC, DE, HL.
ol_clock_reset:
        ld hl,rx_total
        ld b,OL_STATS
        xor a
ocr_zero:
        ld (hl),a
        inc hl
        djnz ocr_zero
        ld a,(has_mph)
        or a
        jr z,ocr_rtc
        call t0_read
        ld (clk_t0),hl
        ret
ocr_rtc:
        call dpi_time
        ret nz
        ld a,1
        ld (rtc_ok),a
        ld hl,rtc_now
        ld de,rtc_t0
        ld bc,3
        ldir
        jp or_mark

; ol_clock: the time on line by the MPH-1V counter 0 (55930 Hz, in eighths so that the sum fits a word): every
; second ol_second. Without the MPH-1V the RTC of the DPI-1L, read when due (ol_rtc): four times a second when
; quiet (ol_tick), every 2 KB of data when busy (a command of the card holds the Z80 up to 8 ms). Changes all.
CLK_SECOND      equ 6991                ; 55930 / 8
ol_clock:
        ld a,(has_mph)
        or a
        jr z,oc_rtc
        call t0_read            ; the counter counts down
        ld de,(clk_t0)
        ld (clk_t0),hl
        ex de,hl
        or a
        sbc hl,de
        srl h
        rr l
        srl h
        rr l
        srl h
        rr l
        ld de,(clk_acc)
        add hl,de
oc_second:
        ld de,CLK_SECOND
        or a
        sbc hl,de
        jr c,oc_keep
        push hl
        call ol_second
        pop hl
        jr oc_second
oc_keep:
        add hl,de
        ld (clk_acc),hl
        ret
oc_rtc:
        ld a,(rtc_ok)
        or a
        ret z
        ld a,(rtc_due)
        or a
        jr nz,oc_read
        ld hl,(rx_total)        ; 2 KB of data since the last reading
        ld de,(rtc_rx)
        or a
        sbc hl,de
        ld a,h
        cp 8
        ret c
oc_read:
        xor a
        ld (rtc_due),a
        ld hl,(rx_total)
        ld (rtc_rx),hl
; ol_rtc: the time on line = the RTC now - rtc_t0; when seconds passed since the last reading (rtc_last), the bytes
; per second since then (ol_rate) and the live lines of the status card. Changes all.
ol_rtc:
        call dpi_time
        ret nz
        ld hl,rtc_t0
        call rtc_sub
        ld (ol_secs),a
        ld a,c
        ld (ol_mins),a
        ld a,b
        ld (ol_hours),a
        ld hl,rtc_last
        call rtc_sub
        ld e,a
        ld a,b
        or c
        jr nz,or_long           ; a minute or more: no rate
        ld a,e
        or a
        ret z                   ; still the same second
        push af
        call or_mark
        pop af
        ld c,a
        ld hl,(rx_total)
        ld de,(rx_last)
        ld (rx_last),hl
        or a
        sbc hl,de
        call div_hl_c           ; the bytes per second of these seconds, each of them into the ring
        ld a,c
        cp RATE_SECS
        jr c,or_push
        ld c,RATE_SECS
or_push:
        ld b,c
or_one:
        push bc
        push hl
        call rate_push
        pop hl
        pop bc
        djnz or_one
        jp stat_update
or_long:
        call or_mark
        ld hl,(rx_total)
        ld (rx_last),hl
        ld hl,0
        ld c,RATE_SECS
        jr or_push

; or_mark: rtc_last = rtc_now. Changes BC, DE, HL.
or_mark:
        ld hl,rtc_now
        ld de,rtc_last
        ld bc,3
        ldir
        ret

; rtc_sub: rtc_now - the time at HL (hour, minute, second), over midnight too -> B = hours, C = minutes,
; A = seconds. Changes BC, HL.
rtc_sub:
        push de
        ld de,rtc_now+2
        inc hl
        inc hl
        ld a,(de)
        sub (hl)
        ld b,0
        jp p,rsb_sec
        add a,60
        inc b
rsb_sec:
        push af
        dec de
        dec hl
        ld a,(de)
        sub (hl)
        sub b
        ld b,0
        jp p,rsb_min
        add a,60
        inc b
rsb_min:
        ld c,a
        dec de
        dec hl
        ld a,(de)
        sub (hl)
        sub b
        jp p,rsb_hour
        add a,24
rsb_hour:
        ld b,a
        pop af
        pop de
        ret

; div_hl_c: HL = HL / C (C 1-127). Changes A, B.
div_hl_c:
        xor a
        ld b,16
dhc_bit:
        add hl,hl
        rla
        cp c
        jr c,dhc_next
        sub c
        inc l
dhc_next:
        djnz dhc_bit
        ret

; ol_tick: a quiet tick of 60 Hz without the MPH-1V: with the RTC every 15th asks for a reading (rtc_due), without
; it every 60th is a second (ol_second). Changes all.
ol_tick:
        ld a,(has_mph)
        or a
        ret nz
        ld hl,ol_ticks
        inc (hl)
        ld a,(rtc_ok)
        or a
        jr z,ot_count
        ld a,(hl)
        cp 15
        ret c
        ld (hl),0
        ld a,1
        ld (rtc_due),a
        ret
ot_count:
        ld a,(hl)
        cp 60
        ret c
        ld (hl),0
; ol_second: one second on line more; the bytes of that second; the live lines of the status card. Changes all.
ol_second:
        ld hl,ol_secs
        inc (hl)
        ld a,(hl)
        cp 60
        jr c,os_rate
        ld (hl),0
        inc hl
        inc (hl)
        ld a,(hl)
        cp 60
        jr c,os_rate
        ld (hl),0
        inc hl
        inc (hl)
os_rate:
        ld hl,(rx_total)
        ld de,(rx_last)
        ld (rx_last),hl
        or a
        sbc hl,de
        call rate_push
        jp stat_update

; rate_push: HL bytes received in one more second into the ring of the last RATE_SECS seconds; ol_rate = their
; average (over the seconds on line so far, at most RATE_SECS). Changes A, BC, DE, HL.
RATE_SECS       equ 5
rate_push:
        ex de,hl
        ld a,(rate_pos)
        add a,a
        ld l,a
        ld h,0
        ld bc,rate_ring
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d
        ld a,(rate_pos)
        inc a
        cp RATE_SECS
        jr c,rp_pos
        xor a
rp_pos:
        ld (rate_pos),a
        ld a,(rate_n)
        cp RATE_SECS
        jr nc,rp_sum
        inc a
        ld (rate_n),a
rp_sum:
        ld hl,rate_ring
        ld de,0
        ld b,RATE_SECS
rp_add:
        ld a,(hl)
        inc hl
        add a,e
        ld e,a
        ld a,(hl)
        inc hl
        adc a,d
        ld d,a
        jr nc,rp_next
        ld de,0FFFFh            ; more than 64 KB in the ring: as much as there can be
rp_next:
        djnz rp_add
        ex de,hl
        ld a,(rate_n)
        ld c,a
        call div_hl_c
        ld (ol_rate),hl
        ret

; rx_count: HL more bytes of data received (rx_total). Changes A, DE.
rx_count:
        push hl
        ld de,(rx_total)
        add hl,de
        ld (rx_total),hl
        jr nc,rxc_done
        ld hl,(rx_total+2)
        inc hl
        ld (rx_total+2),hl
rxc_done:
        pop hl
        ret
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

; show_cols: the columns on the CGA-1V (80 or 40) after the menu line. Changes all.
show_cols:
        ld a,(cols40)
        or a
        ld a,'8'
        jr z,sc_put
        ld a,'4'
sc_put:
        call stat_putc
        ld a,'0'
        jp stat_putc

; show_speed: the speed of the line after the menu line. Changes all.
show_speed:
        ld a,(speed)
        or a
        ld hl,t_speed_max
        jp z,stat_puts
        call speed_name
        call stat_puts
        ld hl,txt_bd
        jp stat_puts
txt_bd:
        defb ' Bd',0

; js_by_speed: jump scroll on line only at full speed (a modem shows line by line). Changes A.
js_by_speed:
        ld a,(cs_type)          ; PETSCII, ATASCII: no line feeds to look for
        cp CS_PETSCII
        jr nc,jbs_off
        ld a,(speed)
        or a
        ld a,1
        jr z,jbs_set
jbs_off:
        xor a
jbs_set:
        ld (js_enable),a
        ret

; show_cs: the character set of the BBS after the menu line. Changes all.
show_cs:
        ld a,(cs_type)
        call cs_name
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
        ret z
        call rx_count
        ld a,(log_on)           ; into the session log too
        or a
        jr z,nr_data
        ld b,h
        ld c,l
        ld hl,in_buf
        call log_data
nr_data:
        or 1                    ; NZ: data
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
        call term_putc          ; ansi_putc, or pet_putc
        jr feed_input

; The speed of the line: pace_acc counts the time (in counts of 55930 Hz, the MPH-1V counter 0, without it
; 932 a tick) a byte is due after speed_counts of it; the terminal gets the bytes in their time and catches up
; after a slow operation (a scroll), as from a modem.
SPEED_COUNT     equ 8
PACE_MAX        equ 64              ; bytes at most in one pace_feed (the keyboard and the network go on)

; pace_reset: the time of the line starts now. Changes A, HL.
pace_reset:
        ld hl,0
        ld (pace_acc),hl
        ld a,(has_mph)
        or a
        ret z
        call t0_read
        ld (pace_t0),hl
        ret

; pace_elapsed: HL = counts of 55930 Hz since the last call: the MPH-1V counter 0 (it counts down), else a tick
; (tick_poll) = TICK_DIV. Changes A, DE, HL.
pace_elapsed:
        ld a,(has_mph)
        or a
        jr z,pe_tick
        call t0_read
        ld de,(pace_t0)
        ld (pace_t0),hl
        ex de,hl
        or a
        sbc hl,de
        ret
pe_tick:
        call tick_poll
        ld hl,0
        ret z
        ld hl,TICK_DIV
        ret

; pace_due: the time since the last call to pace_acc; A = 1 when a byte is due, else 0. Changes A, DE, HL.
pace_due:
        call pace_elapsed
        ld de,(pace_acc)
        add hl,de
        jr nc,pd_acc
        ld hl,0FFFFh
pd_acc:
        ld (pace_acc),hl
        call pace_cpb
        or a
        sbc hl,de
        ld a,0
        ret c
        inc a
        ret

; pace_cpb: DE = counts a byte at the speed. Changes A, DE, HL.
pace_cpb:
        ld a,(speed)
        add a,a
        ld hl,speed_counts
        call add_hl_a
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl,(pace_acc)
        ret

; pace_feed: the bytes that are due (at most PACE_MAX) from in_ptr through the terminal. When the buffer is
; empty the time left is dropped (a modem does not send faster later). Changes all.
pace_feed:
        ld b,PACE_MAX
pc_byte:
        push bc
        call pace_cpb
        or a
        sbc hl,de
        jr c,pc_done            ; its time has not come
        ld (pace_acc),hl
        ld hl,(in_ptr)
        ld de,(in_end)
        ld a,l
        cp e
        jr nz,pc_one
        ld a,h
        cp d
        jr nz,pc_one
        ld hl,0
        ld (pace_acc),hl
        jr pc_done
pc_one:
        ld a,(hl)
        inc hl
        ld (in_ptr),hl
        call term_putc          ; ansi_putc, or pet_putc
        pop bc
        djnz pc_byte
        ret
pc_done:
        pop bc
        ret

; speed_name: HL = the name of speed A (as in SAPITERM.CFG, 00h at the end). Changes A, HL.
speed_name:
        ld hl,speed_names
sn_next:
        or a
        ret z
        push af
sn_end:
        ld a,(hl)
        inc hl
        or a
        jr nz,sn_end
        pop af
        dec a
        jr sn_next

; speeds of the line: counts of 55930 Hz a byte (10 bits a byte); MAX is not paced
speed_counts:
        defw 0, 15, 29, 58, 117, 233, 466, 1864
speed_names:
        defb 'MAX',0, '38400',0, '19200',0, '9600',0, '4800',0, '2400',0, '1200',0, '300',0

; key_send: key A to the BBS. Cursor keys and the like as ANSI sequences: EKL-1 sends them as WordStar codes
; (05 18 13 04, Home 1E, End 11, PgUp 12, Ins 16, Del 0B), the Consul 262.3 as C1-C4, Home 8D, keypad B0-B9
; (kbd_type chooses). Changes all.
key_send:
        ld c,a
        ld a,(cs_type)
        cp CS_PETSCII
        ld a,c
        jp z,pet_key
        ld a,(cs_type)
        cp CS_ATASCII
        ld a,c
        jp z,ata_key
        ld a,(cs_type)
        cp CS_VIEWDATA
        ld a,c
        jp z,vdt_key
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
        cp 0C0h
        ret c                   ; others (function keys) not yet
        ld a,(kbd_type)
        or a
        ret nz
        ld a,c
        xor 20h                 ; EKL-1: Czech letters as KOI-8cs XOR 20h
        jp cs_key

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
