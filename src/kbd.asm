; SAPI-Term - parallel keyboard on JPR-1V (EKL-1, Consul 262.3), polled, with a ring of 16 keys.
;
; Protocol of MikroMon and ECMON (docs/technika.md): STROBE active = KB_STAT bit 0 = 0, the code on KB_DATA
; inverted, then ACK until STROBE is inactive. EKL-1 holds a key until the ACK; the Consul 262.3 without the 7474
; latch gives only a 1 ms pulse, so kbd_scan must be called at least every ~0.5 ms where it can be connected.

; kbd_init: ACK off, buzzer off, empty ring. Changes A.
kbd_init:
        ld a,KB_IDLE
        out (KB_STAT),a
        xor a
        ld (kb_head),a
        ld (kb_tail),a
        ret

; kbd_scan: when a key is ready, read it, acknowledge it and put it into the ring (a key that does not fit is
; lost). Changes A, F.
kbd_scan:
        in a,(KB_STAT)
        rrca
        ret c                   ; STROBE inactive
        push bc
        push hl
        in a,(KB_DATA)
        cpl
        ld c,a
        ld a,KB_ACK
        out (KB_STAT),a
        ld b,0                  ; wait for STROBE inactive: EKL-1 lifts it after the ACK, the Consul after its
ks_wait:                        ; ~1 ms pulse (256 reads = 2.5 ms at 4 MHz)
        in a,(KB_STAT)
        rrca
        jr c,ks_released
        djnz ks_wait
ks_released:
        ld a,KB_IDLE
        out (KB_STAT),a
        ld a,(kb_head)
        ld l,a
        inc a
        and 15
        ld b,a
        ld a,(kb_tail)
        cp b
        jr z,ks_done            ; the ring is full
        ld a,b
        ld (kb_head),a
        ld a,l
        ld hl,kb_ring
        add a,l
        ld l,a
        jr nc,ks_store
        inc h
ks_store:
        ld (hl),c
ks_done:
        pop hl
        pop bc
        ret

; kbd_get: scans the keyboard, then takes the oldest key from the ring. Carry set and A = the key, or carry
; clear when there is none. Changes A, F.
kbd_get:
        call kbd_scan
        push hl
        ld a,(kb_tail)
        ld l,a
        ld a,(kb_head)
        cp l
        jr z,kg_none
        ld a,l
        inc a
        and 15
        ld (kb_tail),a
        ld a,l
        ld hl,kb_ring
        add a,l
        ld l,a
        jr nc,kg_load
        inc h
kg_load:
        ld a,(hl)
        pop hl
        scf
        ret
kg_none:
        pop hl
        or a                    ; carry clear
        ret
