; SAPI-Term - DPI-1L Repository API (docs/technika.md, ..\SAPI_DPI-firmware\docs\unicard.md).
;
; OUT DPI_CMD = command (the status pointer goes back to byte 0), IN DPI_CMD = status bytes 0-3: flags, last
; command, error / free parameter space / output bytes left, FatFs result. Parameters OUT and output IN on
; DPI_DATA. On the real card an access after a TCP command waits (WAIT) until the core 0 of the RP2350 has done
; it, up to ~8 ms; the emulator answers at once.

; dpi_detect: A = 1 when a DPI card answers REVD with the status 02 06 04 and 'D' in the output, else 0 (an
; empty bus gives the port number for IN A,(n), so the status would be B0h). Sets dpi_major, dpi_minor,
; dpi_board, then RESET closes what an earlier program left open (a /RES does not close a TCP connection).
dpi_detect:
        ld a,DPI_REVD
        out (DPI_CMD),a
        in a,(DPI_CMD)
        cp ST_DOUTRQ            ; output waiting, no error
        jr nz,dd_none
        in a,(DPI_CMD)
        cp DPI_REVD
        jr nz,dd_none
        in a,(DPI_CMD)
        cp 4                    ; 4 bytes of output
        jr nz,dd_none
        in a,(DPI_DATA)
        ld (dpi_major),a
        in a,(DPI_DATA)
        ld (dpi_minor),a
        in a,(DPI_DATA)
        cp 'D'
        jr nz,dd_none
        in a,(DPI_DATA)
        ld (dpi_board),a        ; bit 0 = DPI-1L
        ld a,DPI_RESET
        out (DPI_CMD),a
        ld a,1
        ret
dd_none:
        xor a
        ret

; dpi_close: close the TCP connection (harmless without one). Changes A.
dpi_close:
        ld a,DPI_TCPCLOSE
        out (DPI_CMD),a
        ret

; dpi_status: the 4 status bytes to dpi_st (the pointer is at byte 0 after any write to DPI_CMD or access to
; DPI_DATA). NZ when the ERROR flag is set, then A = the error code. Changes A, B, HL.
dpi_status:
        ld hl,dpi_st
        ld b,4
dst_loop:
        in a,(DPI_CMD)
        ld (hl),a
        inc hl
        djnz dst_loop
        ld a,(dpi_st)
        and ST_ERROR
        ret z
        ld a,(dpi_st+2)
        or 80h                  ; NZ even for code 0
        ret

; dpi_cmd: command A with B bytes of parameters at HL (B = 0: none), then the status (dpi_status).
; Changes A, BC, HL.
dpi_cmd:
        out (DPI_CMD),a
        ld a,b
        or a
        jr z,dpi_status
        ld c,DPI_DATA
        otir
        jr dpi_status

; dpi_output: B bytes of output to HL. Changes A, BC, HL.
dpi_output:
        ld c,DPI_DATA
        inir
        ret

; --- TCP and DNS (one client connection, IPv4; docs/technika.md) ---

; net_dns: HL = host name (00h at the end) -> net_ip. Numeric addresses are ready at once. Polled once a tick
; (tick_poll) for at most DNS_TICKS; Esc or Ctrl+] stops it. A = 0 found, 1 unknown name, 2 timeout,
; 3 stopped. Changes all.
DNS_TICKS       equ 6*60
net_dns:
        ld a,DPI_DNSREQ
        out (DPI_CMD),a
nd_name:
        ld a,(hl)
        inc hl
        out (DPI_DATA),a        ; the 00h ends the string
        or a
        jr nz,nd_name
        call dpi_status
        ld a,1
        ret nz
        ld hl,DNS_TICKS
        ld (net_wait),hl
nd_poll:
        ld a,DPI_DNSRES
        ld b,0
        call dpi_cmd
        ld a,1
        ret nz
        ld hl,dpi_res
        ld b,5
        call dpi_output
        ld a,(dpi_res)
        cp 2
        jr z,nd_found
        cp 2
        ld a,1
        ret nc                  ; 3 unknown, 4 bad name
        call net_tick           ; 0, 1: still looking
        ret nz
        jr nd_poll
nd_found:
        ld hl,dpi_res+1
        ld de,net_ip
        ld bc,4
        ldir
        xor a
        ret

; net_tick: wait for the next tick of 60 Hz, count net_wait down. NZ with A = 2 at the timeout, A = 3 when Esc
; or Ctrl+] was pressed. Changes A, HL.
net_tick:
nt_wait:
        call kbd_get
        jr nc,nt_tick
        cp 1Bh
        jr z,nt_stop
        cp K_MENU
        jr z,nt_stop
nt_tick:
        call tick_poll
        jr z,nt_wait
        ld hl,(net_wait)
        dec hl
        ld (net_wait),hl
        ld a,h
        or l
        jr z,nt_timeout
        xor a                   ; Z: go on
        ret
nt_timeout:
        ld a,2
        or a
        ret
nt_stop:
        ld a,3
        or a
        ret

; net_open: TCP connection to net_ip, net_port. Polled once a tick for at most CONNECT_TICKS (the card itself
; gives up after 10 s). A = 0 connected, 1 refused or failed, 2 timeout, 3 stopped. Changes all.
CONNECT_TICKS   equ 12*60
net_open:
        ld a,DPI_TCPIP
        ld hl,net_ip
        ld b,4
        call dpi_cmd
        ld a,1
        ret nz
        ld a,DPI_TCPPORT
        ld hl,net_port
        ld b,2
        call dpi_cmd
        ld a,1
        ret nz
        ld a,DPI_TCPOPEN
        ld b,0
        call dpi_cmd
        ld a,1
        ret nz
        ld hl,CONNECT_TICKS
        ld (net_wait),hl
no_poll:
        call net_status
        cp TCP_CONNECTED
        jr z,no_ok
        cp TCP_CONNECTING
        ld a,1
        ret nz                  ; failed or closed
        call net_tick
        ret nz
        jr no_poll
no_ok:
        xor a
        ret

; net_status: TCPSTATUS to net_st (10 bytes). A = state (TCP_*), HL = bytes waiting. Changes all.
TCP_IDLE        equ 0
TCP_CONNECTING  equ 1
TCP_CONNECTED   equ 2
TCP_FAILED      equ 3
TCP_CLOSED      equ 4
net_status:
        ld a,DPI_TCPSTATUS
        ld b,0
        call dpi_cmd
        ld a,TCP_FAILED
        ret nz
        ld hl,net_st
        ld b,10
        call dpi_output
        ld hl,(net_st+2)
        ld a,(net_st+1)
        ret

; net_recv: up to B bytes (1-253) to DE. A = the number received (0 = none). Changes all.
net_recv:
        push de
        ld a,DPI_TCPRECV
        out (DPI_CMD),a
        ld a,b
        out (DPI_DATA),a
        xor a
        out (DPI_DATA),a
        call dpi_status
        pop hl
        ld a,0
        ret nz
        in a,(DPI_DATA)         ; WORD n (n <= 253)
        ld b,a
        in a,(DPI_DATA)
        ld a,b
        or a
        ret z
        push af
        call dpi_output
        pop af
        ret

; net_send: B bytes (1-252) at HL. Z = sent, NZ with A = error (5 = the card has no room now: send again).
; Changes all.
net_send:
        ld a,DPI_TCPSEND
        out (DPI_CMD),a
        ld a,b
        out (DPI_DATA),a
        ld a,80h                ; bit 15: send now
        out (DPI_DATA),a
        ld c,DPI_DATA
        otir
        jp dpi_status
