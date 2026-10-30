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
