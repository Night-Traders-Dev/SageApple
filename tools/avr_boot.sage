#########################################################################
## SageApple — AVR boot image generator (Milestone 4)
##
## Demonstrates the toolchain path: Sage -> AVR opcodes -> Intel HEX -> flash.
## Self-contained: encodes a minimal ATmega328P UART boot that writes
## "H" out the serial port, then loops, and emits an Intel HEX image.
##
## Run:  sage tools/avr_boot.sage
#########################################################################

# ---- minimal AVR encoders -------------------------------------------
proc enc_ldi(rd, k):
    return 0xE000 | ((rd & 0x0F) << 4) | ((k & 0xF0) << 4) | (k & 0x0F)

proc enc_out(a, rr):
    return 0xB800 | ((rr & 0x1F) << 4) | (((a & 0x30) << 5) | (a & 0x0F))

proc enc_in(rd, a):
    return 0xB000 | ((rd & 0x1F) << 4) | (((a & 0x30) << 5) | (a & 0x0F))

proc enc_rjmp(rel):
    return 0xC000 | (rel & 0x0FFF)

# ---- Intel HEX emitter ---------------------------------------------
proc hex2(v):
    let digs = "0123456789abcdef"
    return digs[(v >> 4) & 0xF] + digs[v & 0xF]

proc emit_hex(words):
    let out = []
    var base = 0
    var i = 0
    let n = len(words)
    while i < n:
        let w = words[i]
        let rec = ":02" + hex2((base >> 8) & 0xFF) + hex2(base & 0xFF) + "00"
        rec = rec + hex2((w >> 8) & 0xFF) + hex2(w & 0xFF)
        let ck = 0x02 + ((base >> 8) & 0xFF) + (base & 0xFF) + 0x00
        ck = ck + ((w >> 8) & 0xFF) + (w & 0xFF)
        rec = rec + hex2((0 - ck) & 0xFF)
        push(out, rec)
        base = base + 2
        i = i + 1
    push(out, ":00000001FF")
    var s = ""
    var j = 0
    let m = len(out)
    while j < m:
        if j > 0:
            s = s + "\n"
        s = s + out[j]
        j = j + 1
    return s

# ATmega328P I/O addresses (AVR I/O space, direct 0x00..0x3F window)
#   UCSR0A=0xC0 UCSR0B=0xC1 UCSR0C=0xC2 UBRR0L=0xC4 UBRR0H=0xC5 UDR0=0xC6
proc build_boot():
    let words = []
    push(words, enc_ldi(16, 0x00))     # UBRRH = 0
    push(words, enc_out(0xC5, 16))
    push(words, enc_ldi(16, 103))      # 16MHz / 16 / 9600 - 1 = 103
    push(words, enc_out(0xC4, 16))
    push(words, enc_ldi(16, 0x18))     # RXEN0 | TXEN0
    push(words, enc_out(0xC1, 16))
    push(words, enc_ldi(16, 0x06))     # 8 data bits, 1 stop, no parity
    push(words, enc_out(0xC2, 16))
    push(words, enc_ldi(16, 0x48))     # 'H'
    push(words, enc_out(0xC6, 16))     # UDR0 = 'H'
    push(words, enc_rjmp(0))           # infinite loop
    return words

import io
var boot = build_boot()
let hex_txt = emit_hex(boot)
print("AVR boot HEX:")
print(hex_txt)
if io.mkdir("build") == false:
    io.mkdir("build")
io.writefile("build/boot.hex", hex_txt)
print("wrote build/boot.hex")