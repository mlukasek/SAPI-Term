; SAPI-Term - CGA-1V: EGA mode, palette, VBI (docs/technika.md).
;
; EGA mode: a byte = 4 pixels (D7..D4, D7 left) + an attribute (D3..D0) common to the four. Colour index =
; (y >> 5) << 5 | attribute << 1 | pixel, so every domain of 32 lines (4 text rows) has 16 pairs background /
; foreground. The palette is written only in the VBI (else the Bt476 disturbs the picture).
; All routines here except cga_init and cga_off need MAP_CGA and leave it.

; cga_init: EGA mode, page A shown and for the CPU, no interrupt, COLMASK FFh, both pages cleared, the palette
; of the 16 text colours on black. Needs and leaves MAP_CPM.
cga_init:
        ld a,MAP_CGA
        out (MAPREG),a
        xor a
        ld (cga_cfg),a
        call cga_wait_vbi
        ld a,0FFh
        ld (CGA_COLMASK),a
        call cga_pal_black
        ld a,CFG_CPU_B
        call cga_clear_page
        xor a
        call cga_clear_page
        call cga_wait_vbi
        call cga_pal_text
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; cga_off: both pages cleared, palette black, page A, no interrupt: a black screen for the programs after
; SAPI-Term. Needs and leaves MAP_CPM.
cga_off:
        ld a,MAP_CGA
        out (MAPREG),a
        ld a,CFG_CPU_B
        call cga_clear_page
        xor a
        call cga_clear_page
        call cga_wait_vbi
        call cga_pal_black
        ld a,MAP_CPM
        out (MAPREG),a
        ret

; cga_clear_page: A = CONFIG with the page for the CPU (0 = A, CFG_CPU_B = B), page A stays displayed; the page
; is filled with 00h. Changes A, BC, DE, HL.
cga_clear_page:
        ld (cga_cfg),a
        ld (CGA_CFG),a
        ld hl,CGA_VRAM
        ld de,CGA_VRAM+1
        ld bc,CGA_SIZE-1
        ld (hl),0
        ldir
        ret

; cga_poll_vbi: NZ when the VBI request is set (then it is acknowledged), Z when not. Changes A.
cga_poll_vbi:
        ld a,(CGA_CFG)
        and STAT_VBI
        ret z
        ld a,(cga_cfg)
        or CFG_ACK
        ld (CGA_CFG),a
        ret                     ; NZ (CFG_ACK is set)

; cga_wait_vbi: acknowledge an old VBI request and wait for the next one (at most a frame, 16.7 ms), polling
; the keyboard meanwhile; the new request is acknowledged too. Changes A.
cga_wait_vbi:
        ld a,(cga_cfg)
        or CFG_ACK
        ld (CGA_CFG),a
cwv_loop:
        call kbd_scan
        ld a,(CGA_CFG)
        and STAT_VBI
        jr z,cwv_loop
        ld a,(cga_cfg)
        or CFG_ACK
        ld (CGA_CFG),a
        ret

; cga_pal_black: all 256 palette entries black (2.7 ms at 4 MHz, call it right after the VBI). Changes A, B, HL.
cga_pal_black:
        ld hl,CGA_PAL_ADR
        ld (hl),0
        inc hl                  ; CGA_PAL_DAT
        xor a
        ld b,a
cpb_loop:
        ld (hl),a
        ld (hl),a
        ld (hl),a
        djnz cpb_loop
        ret

; cga_pal_text: in the domains 0-6, pair n = black background, foreground = colour n of ansi_rgb (3.4 ms at
; 4 MHz, call it right after the VBI). Changes A, BC, DE, HL.
cga_pal_text:
        ld hl,CGA_PAL_ADR
        ld (hl),0
        inc hl                  ; CGA_PAL_DAT
        ld c,7
cpt_domain:
        ld de,ansi_rgb
        ld b,16
cpt_pair:
        ld (hl),0
        ld (hl),0
        ld (hl),0
        ld a,(de)
        inc de
        ld (hl),a
        ld a,(de)
        inc de
        ld (hl),a
        ld a,(de)
        inc de
        ld (hl),a
        djnz cpt_pair
        dec c
        jr nz,cpt_domain
        ret

; cga_test_bars: 16 vertical bars of the colours 0-15 (bar n = 5 bytes of F0h | n, colour 0 is black) on page A.
; Changes A, BC, DE, HL.
cga_test_bars:
        ld hl,CGA_VRAM
        ld c,200
ctb_line:
        ld d,0F0h
        ld b,16
ctb_bar:
        ld (hl),d
        inc hl
        ld (hl),d
        inc hl
        ld (hl),d
        inc hl
        ld (hl),d
        inc hl
        ld (hl),d
        inc hl
        inc d
        djnz ctb_bar
        dec c
        jr nz,ctb_line
        ret

; The 16 text colours in the CGA order (black, blue, green, cyan, red, magenta, brown, light grey, then the
; bright ones; SGR 30-37 of ANSI go in another order), R, G, B with 6 bits as the Bt476 takes them.
ansi_rgb:
        defb 00h,00h,00h, 00h,00h,2Ah, 00h,2Ah,00h, 00h,2Ah,2Ah
        defb 2Ah,00h,00h, 2Ah,00h,2Ah, 2Ah,15h,00h, 2Ah,2Ah,2Ah
        defb 15h,15h,15h, 15h,15h,3Fh, 15h,3Fh,15h, 15h,3Fh,3Fh
        defb 3Fh,15h,15h, 3Fh,15h,3Fh, 3Fh,3Fh,15h, 3Fh,3Fh,3Fh
