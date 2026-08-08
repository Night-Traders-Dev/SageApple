; SageApple — ATmega328P reset/startup sequence (avr-gcc asm)
;
; Boots the AVR: initializes the stack pointer, clears .bss, copies .data,
; then falls into the SageApple C main().

#define __SFR_OFFSET 0
#include <avr/io.h>
#include <avr/common.h>

.section .vector, "ax"
.global reset_vector
reset_vector:
    jmp _start

.section .text.startup, "ax"
.global _start
_start:
    ; set stack pointer to top of SRAM (0x08FF)
    ldi r16, lo8(RAMEND)
    out SPL, r16
    ldi r16, hi8(RAMEND)
    out SPH, r16

    ; clear .bss
    ldi r30, lo8(_bss_start)
    ldi r31, hi8(_bss_start)
    ldi r16, lo8(_bss_end)
    ldi r17, hi8(_bss_end)
    ldi r18, lo8(_bss_start)
    ldi r19, hi8(_bss_start)
    sub r16, r18
    sbc r17, r19
    breq 2f
1:  st Z+, r1
    subi r16, 1
    sbci r17, 0
    brne 1b
2:
    ; copy .data (flash -> SRAM)
    ldi r26, lo8(_data_start)
    ldi r27, hi8(_data_start)
    ldi r28, lo8(_data_end)
    ldi r29, hi8(_data_end)
    sub r28, r26
    sbc r29, r27
    breq 4f
    ldi r30, lo8(_etext)
    ldi r31, hi8(_etext)
3:  lpm r0, Z+
    st X+, r0
    subi r28, 1
    sbci r29, 0
    brne 3b
4:
    rjmp main