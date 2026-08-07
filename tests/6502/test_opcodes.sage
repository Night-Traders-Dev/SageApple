#########################################################################
## SageApple — Sage6502 validation suite (Milestone 3)
##
## Run:  sage tests/6502/test_opcodes.sage   (from the repo root)
#########################################################################

import sage6502.cpu
import bus.bus

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc nz2(v):
    if v < 16:
        return "0x0" + str(v)
    return "0x" + str(v)

# fresh machine, program runs at $0100, reset vector -> $0100
proc mk():
    let b = bus.bus.Bus()
    let c = cpu.CPU(b)
    b.write8(0xFFFC, 0x00)
    b.write8(0xFFFD, 0x01)
    c.reset()
    return [b, c]

proc runpgm(b, image):
    b.load(image, 0x0100)

# ---------------------------------------------------------------
# 1. addressing modes: absolute,X and absolute,Y (page crossing)
# ---------------------------------------------------------------
print("addressing modes (abs,X / abs,Y):")
let m1 = mk()
let b1 = m1[0]
let c1 = m1[1]
b1.write8(0x0200, 0x41)
runpgm(b1, [0xA2, 0x00, 0xBD, 0x00, 0x02, 0x8D, 0x00, 0x03,
            0xA0, 0x01, 0xB9, 0xFF, 0x01, 0x8D, 0x01, 0x03, 0x00])
c1.run()
check(c1.regs.a == 0x41, "LDA $0200,X then LDA $01FF,Y both load $41")
check(b1.read8(0x0300) == 0x41, "STA $0300 stores $41")
check(b1.read8(0x0301) == 0x41, "STA $0301 stores $41")

# ---------------------------------------------------------------
# 2. zero page,X wraparound
# ---------------------------------------------------------------
print("zero page,X wraparound:")
let m2 = mk()
let b2 = m2[0]
let c2 = m2[1]
runpgm(b2, [0xA2, 0x10, 0xB5, 0xF0, 0x85, 0x20, 0x00])
c2.run()
check(c2.regs.a == 0x00, "LDA $F0,X with X=$10 wraps to $00 (mem empty)")
check(b2.read8(0x20) == 0x00, "STA $20 stored 0")

# ---------------------------------------------------------------
# 3. stack push/pull ordering
# ---------------------------------------------------------------
print("stack push/pull:")
let m3 = mk()
let b3 = m3[0]
let c3 = m3[1]
runpgm(b3, [0xA9, 0x11, 0x48, 0xA9, 0x22, 0x48, 0x68])
c3.run()
check(c3.regs.a == 0x22, "PLA returns last pushed ($22)")

# ---------------------------------------------------------------
# 4. JSR / RTS round-trip
# ---------------------------------------------------------------
print("JSR/RTS:")
let m4 = mk()
let b4 = m4[0]
let c4 = m4[1]
runpgm(b4, [0xA2, 0x05, 0x20, 0x20, 0x01, 0x8D, 0x10, 0x03, 0x00])
b4.load([0x8A, 0x8D, 0x00, 0x03, 0x60], 0x0120)
c4.run()
check(c4.regs.a == 0x05, "subroutine TXA -> A=$05")
check(b4.read8(0x0300) == 0x05, "STA in subroutine")
check(b4.read8(0x0310) == 0x05, "returned to caller after RTS")

# ---------------------------------------------------------------
# 5. branch taken / not taken
# ---------------------------------------------------------------
print("branches:")
let m5 = mk()
let b5 = m5[0]
let c5 = m5[1]
runpgm(b5, [0xA2, 0x00, 0xF0, 0x03, 0xA9, 0xFF, 0x00, 0xA9, 0x01, 0x00])
c5.run()
check(c5.regs.a == 0x01, "BEQ taken: skipped LDA #$FF")

let m5b = mk()
let b5b = m5b[0]
let c5b = m5b[1]
runpgm(b5b, [0xA2, 0x01, 0xD0, 0x02, 0xA9, 0xFF, 0x00, 0x00])
c5b.run()
check(c5b.regs.a == 0x00, "BNE taken on X=1")

# ---------------------------------------------------------------
# 6. interrupts: IRQ service + RTI return
# ---------------------------------------------------------------
print("interrupts (IRQ/RTI):")
let m6 = mk()
let b6 = m6[0]
let c6 = m6[1]
b6.load([0x58, 0xEA, 0x00], 0x0100)      # CLI ; NOP ; BRK
b6.load([0xA0, 0x09, 0x40], 0x0120)     # LDY #$09 ; RTI
b6.write8(0xFFFE, 0x20)
b6.write8(0xFFFF, 0x01)
c6.reset()
c6.interrupt()
c6.run()
check(c6.regs.y == 0x09, "IRQ serviced to $0120, LDY #$09 ran")
check(c6.halted == true, "RTI returned to program which BRK-halted")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")