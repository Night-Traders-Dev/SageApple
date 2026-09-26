#########################################################################
## SageApple — AVR boot image generator (Milestone M4)
##
## Demonstrates the toolchain path: SageLang -> AVR opcodes -> Intel HEX -> flash.
## Builds a minimal ATmega328P UART boot that writes "H" out of the serial
## port and then spins, and emits build/boot.hex.
##
## This deliberately goes through the SageLang AVR backend
## (core/boards/AVR) rather than hand-rolled encoders. It used to carry its own
## copy, and both copies were wrong in ways the backend was not:
##
##   * the Intel HEX emitter wrote every word high byte first, so the image
##     decoded as different instructions entirely;
##   * USART0 registers live at data addresses 0x00C0-0x00C6, which are outside
##     the 0x00-0x3F I/O window that `in`/`out` can reach. An `out` encoder given
##     0xC5 silently emitted `out 0x05` -- PORTB, not UBRR0H.
##
## `make -C avr boot-verify` cross-checks the result against avr-as and avr-ld
## byte for byte, and `make -C avr boot-flash` puts it on the board.
##
## Run:  sage -I ../SageLang/core/boards/AVR tools/avr_boot.sage
#########################################################################

import avr_assembler
import avr_hex
import io

let _BOOT_SRC = [
"; ATmega328P UART boot: write one 'H' out of the serial port, then spin.",
"; USART0 sits at data addresses 0x00C0-0x00C6, outside the 0x00-0x3F I/O",
"; window that in/out can reach, so these need sts and lds.",
"    ldi r16, 0x00",
"    sts 0x00C5, r16          ; UBRR0H = 0",
"    ldi r16, 0x67",
"    sts 0x00C4, r16          ; UBRR0L = 103 -> 9600 baud at 16 MHz",
"    ldi r16, 0x18",
"    sts 0x00C1, r16          ; UCSR0B = RXEN0 | TXEN0",
"    ldi r16, 0x06",
"    sts 0x00C2, r16          ; UCSR0C = 8 data bits, 1 stop, no parity",
"    ldi r16, 0x48            ; 'H'",
"txwait:",
"    lds r17, 0x00C0          ; UCSR0A",
"    sbrs r17, 5              ; UDRE0 set means the data register is free",
"    rjmp txwait",
"    sts 0x00C6, r16          ; UDR0 = 'H'",
"done:",
"    rjmp done",
]

proc main():
    ## assemble() takes source text, not a list of lines.
    let src = join(_BOOT_SRC, "\n")
    let words = avr_assembler.assemble(src)
    let hex_txt = avr_hex.emit_hex(words, 0)
    print("word count:", len(words))
    print(hex_txt)
    io.mkdir("build")
    io.writefile("build/boot.hex", hex_txt)
    ## Also write the exact source that was assembled, so `make boot-verify`
    ## can hand the same text to avr-as instead of keeping a second copy that
    ## could drift.
    io.writefile("build/boot.asm", src + "\n")
    print("wrote build/boot.hex and build/boot.asm")

main()
