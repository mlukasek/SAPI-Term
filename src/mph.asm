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

; mph_off: gates closed, no interrupt, flags cleared. Changes A.
mph_off:
        xor a
        out (MPH_IEN),a
        ld a,0C0h
        out (MPH_IACK),a
        ret
