; SAPI-Term - MPH-1V: the 82C54 counter 2 as a 60 Hz tick (F2 in STATUS), polled, no interrupt. Counter 0
; runs freely (divisor 65536, around in 1.17 s) as the clock of the speed of the line (pace_elapsed).

; mph_detect: start counter 2 (mode 2, TICK_DIV, gate open, no interrupt) and check that it counts: two latched
; values must be at most TICK_DIV and differ (an empty bus reads 52h 52h = 5252h). A = 1 when the card is there.
; Changes A, BC, DE, HL.
mph_detect:
        ld a,T2_MODE2
        out (MPH_CTL),a
        ld a,low TICK_DIV
        out (MPH_T2),a
        ld a,high TICK_DIV
        out (MPH_T2),a
        ld a,IEN_G2
        out (MPH_IEN),a
        call t2_read
        ex de,hl
        ld b,0                  ; ~3300 T, ~46 counts of the 55.9 kHz clock at 4 MHz
md_delay:
        djnz md_delay
        call t2_read
        or a
        sbc hl,de
        jr z,md_none            ; the same value twice: it does not count
        add hl,de
        ld bc,TICK_DIV+1
        or a
        sbc hl,bc
        jr nc,md_none
        ex de,hl
        or a
        sbc hl,bc
        jr nc,md_none
        ld a,T0_MODE2           ; counter 0: free running
        out (MPH_CTL),a
        xor a
        out (MPH_T0),a
        out (MPH_T0),a
        ld a,IEN_G2+IEN_G0
        out (MPH_IEN),a
        ld a,1
        ret
md_none:
        xor a
        out (MPH_IEN),a         ; nothing there, or the gates closed again
        ret

; t2_read: HL = latched value of counter 2. Changes A.
t2_read:
        ld a,T2_LATCH
        out (MPH_CTL),a
        in a,(MPH_T2)
        ld l,a
        in a,(MPH_T2)
        ld h,a
        ret

; t0_read: HL = latched value of counter 0 (it counts down at 55930 Hz). Changes A.
t0_read:
        ld a,T0_LATCH
        out (MPH_CTL),a
        in a,(MPH_T0)
        ld l,a
        in a,(MPH_T0)
        ld h,a
        ret

; mph_poll_tick: NZ when F2 is set (a tick of counter 2 came; F2 is cleared), Z when not. Changes A.
mph_poll_tick:
        in a,(MPH_CTL)
        and 80h
        ret z
        out (MPH_IACK),a        ; A = 80h clears F2
        ret

; mph_bell: BEL as a short tone (880 Hz, about 1/15 s) on channel 0 of the YM3812; without the MPH-1V nothing.
; Changes A, B, HL.
mph_bell:
        ld a,(has_mph)
        or a
        ret z
        ld hl,bell_on
        call ym_regs
        ld b,4                  ; 4 ticks of 60 Hz
mb_wait:
        call kbd_scan
        push hl
        call tick_poll
        pop hl
        jr z,mb_wait
        djnz mb_wait
        inc hl                  ; the key off after the FFh
; ym_regs: pairs register, value at HL to the YM3812 (FFh ends), with the waits it needs (3.3 us after the
; address, 23 us after the data). Changes A, HL.
ym_regs:
        ld a,(hl)
        cp 0FFh
        ret z
        inc hl
        out (MPH_YM_ADR),a
        ex (sp),hl              ; 38 T
        ex (sp),hl
        ld a,(hl)
        inc hl
        out (MPH_YM_DAT),a
        push bc
        ld b,8                  ; 104 T
ymr_wait:
        djnz ymr_wait
        pop bc
        jr ym_regs
bell_on:                        ; sine, the modulator silent, fast attack, then key on: block 5, F-number 244h
        defb 01h,00h, 20h,01h, 23h,01h, 40h,3Fh, 43h,06h, 60h,0F0h, 63h,0F0h, 80h,0F7h, 83h,0F7h
        defb 0C0h,00h, 0A0h,44h, 0B0h,36h, 0FFh
        defb 0B0h,16h, 0FFh     ; key off (mph_bell after the wait)

; mph_off: gates closed, no interrupt, flags cleared. Changes A.
mph_off:
        xor a
        out (MPH_IEN),a
        ld a,0C0h
        out (MPH_IACK),a
        ret
