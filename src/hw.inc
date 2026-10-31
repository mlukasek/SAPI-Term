; SAPI-Term - ports and addresses of the set V (docs/technika.md).

; CP/M 2.2 with ECMON IDE-1 (TPA 0100-D5FF, BDOS D606, BIOS E400)
WBOOT           equ 0000h
BDOS            equ 0005h
B_CONOUT        equ 2           ; BDOS functions: console output (E = character)
B_OPEN          equ 15          ; open file (DE = FCB), A = FFh not found
B_SETDMA        equ 26          ; DMA address = DE
B_READRAND      equ 33          ; read record r0..r2 of the FCB, A = 0 OK
B_SIZE          equ 35          ; r0..r2 = size in records
FCB             equ 005Ch       ; FCB of the first argument (from the CCP)
FCB_R0          equ 33          ; random record number in the FCB (3 bytes)
CMD_TAIL        equ 0080h       ; length of the command line arguments, then the text

; JPR-1V port P0/P1: parallel keyboard (EKL-1, Consul 262.3) on connector K2
KB_STAT         equ 01h         ; in: bit 0 = 0 while STROBE is active (a key is ready)
                                ; out: bit 0 = ACK, bit 1 = 0 sounds the EKL-1 buzzer
KB_DATA         equ 02h         ; in: the key code, inverted
KB_IDLE         equ 02h         ; out KB_STAT: ACK off, buzzer off
KB_ACK          equ 03h         ; out KB_STAT: ACK on, buzzer off (bit 1 = 0: the buzzer of the EKL-1 sounds)

; RAM-1V MAP register (bit 6 = MAP1, bit 7 = MAP2). Bits 0-5 of the same port are A16-A21 of the ZRD-1V RAM
; disk; the BIOS sets them again before every disk access.
MAPREG          equ 63h
MAP_CPM         equ 00h         ; RAM at C000-F7FF, AND-1V at F800-FFFF
MAP_CGA         equ 0C0h        ; CGA-1V at C000-FFFF, the RAM and CP/M there are hidden

; AND-1V (64x20 characters, VRAM row * 64 + column, rows 20-31 are spare RAM), with MAP_CPM
AND_VRAM        equ 0F800h
AND_COLS        equ 64
AND_ROWS        equ 20
AND_TEST        equ 0FFF0h      ; a byte of the invisible rows, used to detect the card

; CGA-1V (base C000h, 16 KB), with MAP_CGA
CGA_VRAM        equ 0C000h      ; 320x200, 80 bytes per line, 4 pixels per byte (D7 = left)
CGA_SIZE        equ 16000
CGA_TEST        equ 0FF00h      ; C000h + 3F00h: RAM that is not displayed, used to detect the card
CGA_CFG         equ 0FFFBh      ; write CONFIG, read STATUS (D7 = VBI request, D0-D6 from the SRAM)
CGA_PAL_ADR     equ 0FFFCh      ; Bt476 palette address for writing
CGA_PAL_DAT     equ 0FFFDh      ; Bt476 palette data: R, G, B (6 bits each), then the address + 1
CGA_COLMASK     equ 0FFFEh      ; Bt476 pixel mask
CFG_SHOW_B      equ 01h         ; CONFIG D0: page B displayed (else A)
CFG_CPU_B       equ 02h         ; CONFIG D1: page B for the CPU (else A)
CFG_CGA         equ 04h         ; CONFIG D2: CGA mode (else EGA)
CFG_IRQ         equ 08h         ; CONFIG D3: VBI interrupt enabled
CFG_ACK         equ 80h         ; CONFIG D7: acknowledge the VBI request
STAT_VBI        equ 80h         ; STATUS D7: VBI request

; MPH-1V (base 50h): 82C54 with CLK0 = CLK2 = 55930.4 Hz, YM3812
MPH_BASE        equ 50h
MPH_T0          equ MPH_BASE+0  ; 82C54 counter 0
MPH_T2          equ MPH_BASE+2  ; 82C54 counter 2
MPH_CTL         equ MPH_BASE+3  ; write: 82C54 control word, read: STATUS (D7 = F2, set by the rising edge of OUT2)
MPH_IEN         equ MPH_BASE+4  ; write: gates G0-G2 (D3-D5) and interrupt enables (D7 F2, D6 F1, D0 YM)
MPH_IACK        equ MPH_BASE+5  ; write: D7 = 1 clears F2, D6 = 1 clears F1
MPH_YM_ADR      equ MPH_BASE+6
MPH_YM_DAT      equ MPH_BASE+7
T2_MODE2        equ 0B4h        ; control word: counter 2, LSB then MSB, mode 2 (rate generator), binary
T2_LATCH        equ 80h         ; control word: latch counter 2
T0_MODE2        equ 34h         ; control word: counter 0, LSB then MSB, mode 2, binary
T0_LATCH        equ 00h         ; control word: latch counter 0
IEN_G2          equ 20h         ; IEN: gate of counter 2 open, no interrupt
IEN_G0          equ 08h         ; IEN: gate of counter 0 open
TICK_DIV        equ 932         ; 55930.4 Hz / 932 = 60.01 Hz

; DPI-1L Repository API (docs/technika.md, ..\SAPI_DPI-firmware\docs\unicard.md)
DPI_CMD         equ 0B0h        ; out: command, in: status (4 bytes, then 00h)
DPI_DATA        equ 0B1h        ; out: parameter, in: output
DPI_RESET       equ 00h
DPI_STSR        equ 03h         ; only resets the status pointer
DPI_REVD        equ 06h         ; output: major, minor, 'D', board (bit 0 = DPI-1L)
DPI_RTCGETT     equ 63h         ; output: hour, minute, second of the RTC (binary)
DPI_TCPSTATUS   equ 80h         ; 10 B: connected, state, WORD waiting, IP, port
DPI_TCPIP       equ 81h         ; 4 B: IP, first octet first
DPI_TCPPORT     equ 82h         ; WORD
DPI_TCPOPEN     equ 83h         ; in the background (TCPSTATUS)
DPI_TCPCLOSE    equ 84h
DPI_TCPSEND     equ 85h         ; WORD length (bit 15 = now), 1-252 bytes
DPI_TCPRECV     equ 86h         ; WORD max -> WORD n, n bytes (n <= 253)
DPI_DNSREQ      equ 88h         ; string (ends with a byte < 20h)
DPI_DNSRES      equ 89h         ; 5 B: state (0 idle, 1 looking, 2 found, 3 unknown, 4 bad), IP
ST_PARAMRQ      equ 01h
ST_DOUTRQ       equ 02h
ST_INPROGRESS   equ 40h
ST_ERROR        equ 80h

; keys (EKL-1 and Consul 262.3)
K_MENU          equ 1Dh         ; Ctrl+] on both keyboards (EKL-1 TR_CTRL: ']' AND 1Fh)
