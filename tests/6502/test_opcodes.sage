#########################################################################
## SageApple - Sage6502 validation suite (Milestone 3)
##
## Run:  sage-c tests/6502/test_opcodes.sage   (from the repo root)
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

proc hx(v):
    if v < 16:
        return "0x0" + str(v)
    return "0x" + str(v)

proc mk():
    let b = bus.bus.Bus()
    let c = cpu.CPU(b)
    b.write8(0xFFFC, 0x00)
    b.write8(0xFFFD, 0x01)
    c.reset()
    return [b, c]

proc runpgm(b, image):
    b.load(image, 0x0100)

print("addressing modes (abs,X / abs,Y):")
let m1 = mk()
let b1 = m1[0]
let c1 = m1[1]
b1.write8(0x0200, 0x41)
runpgm(b1, [0xA2, 0x00, 0xBD, 0x00, 0x02, 0x8D, 0x00, 0x03,
            0xA0, 0x01, 0xB9, 0xFF, 0x01, 0x8D, 0x01, 0x03, 0x00])
c1.run(1000)
check(c1.regs.a == 0x41, "LDA $0200,X then LDA $01FF,Y both load $41")
check(b1.read8(0x0300) == 0x41, "STA $0300 stores $41")
check(b1.read8(0x0301) == 0x41, "STA $0301 stores $41")

print("zero page,X wraparound:")
let m2 = mk()
let b2 = m2[0]
let c2 = m2[1]
runpgm(b2, [0xA2, 0x10, 0xB5, 0xF0, 0x85, 0x20, 0x00])
c2.run(1000)
check(c2.regs.a == 0x00, "LDA $F0,X with X=$10 wraps to $00 (mem empty)")
check(b2.read8(0x20) == 0x00, "STA $20 stored 0")

print("stack push/pull:")
let m3 = mk()
let b3 = m3[0]
let c3 = m3[1]
runpgm(b3, [0xA9, 0x11, 0x48, 0xA9, 0x22, 0x48, 0x68])
c3.run(1000)
check(c3.regs.a == 0x22, "PLA returns last pushed ($22)")

print("JSR/RTS:")
let m4 = mk()
let b4 = m4[0]
let c4 = m4[1]
runpgm(b4, [0xA2, 0x05, 0x20, 0x20, 0x01, 0x8D, 0x10, 0x03, 0x00])
b4.load([0x8A, 0x8D, 0x00, 0x03, 0x60], 0x0120)
c4.run(1000)
check(c4.regs.a == 0x05, "subroutine TXA -> A=$05")
check(b4.read8(0x0300) == 0x05, "STA in subroutine")
check(b4.read8(0x0310) == 0x05, "returned to caller after RTS")

print("branches:")
let m5 = mk()
let b5 = m5[0]
let c5 = m5[1]
runpgm(b5, [0xA2, 0x00, 0xF0, 0x03, 0xA9, 0xFF, 0x00, 0xA9, 0x01, 0x00])
c5.run(1000)
check(c5.regs.a == 0x01, "BEQ taken: skipped LDA #$FF")

let m5b = mk()
let b5b = m5b[0]
let c5b = m5b[1]
runpgm(b5b, [0xA2, 0x01, 0xD0, 0x02, 0xA9, 0xFF, 0x00, 0x00])
c5b.run(1000)
check(c5b.regs.a == 0x00, "BNE taken on X=1")

print("interrupts (IRQ/RTI):")
let m6 = mk()
let b6 = m6[0]
let c6 = m6[1]
b6.load([0x58, 0xEA, 0x00], 0x0100)
b6.load([0xA0, 0x09, 0x40], 0x0120)
b6.write8(0xFFFE, 0x20)
b6.write8(0xFFFF, 0x01)
c6.reset()
c6.interrupt()
c6.run(1000)
check(c6.regs.y == 0x09, "IRQ serviced to $0120, LDY #$09 ran")
check(c6.halted == false, "BRK does NOT halt CPU (correct Phase A behavior)")

print("JMP indirect page-wrap:")
let m7 = mk()
let b7 = m7[0]
let c7 = m7[1]
b7.write8(0x12FF, 0x03)
b7.write8(0x1200, 0x01)
runpgm(b7, [0x6C, 0xFF, 0x12, 0xA9, 0x55, 0x00])
c7.run(1000)
check(c7.regs.a == 0x55, "JMP ($12FF) fetches hi from $1200, not $1300")

print("cycle counting:")
let m8 = mk()
let b8 = m8[0]
let c8 = m8[1]
b8.write8(0x0201, 0x41)
runpgm(b8, [0xA2, 0x07, 0xBD, 0xFA, 0x01, 0x00])
c8.run(3)
check(c8.regs.a == 0x41, "LDA $01FA,X with X=7 loads $0201")
check(c8.cycles == 14, "crossing LDA abs,X: LDX(2)+LDA(4+1)+BRK(7)=14")

let m8b = mk()
let b8b = m8b[0]
let c8b = m8b[1]
b8b.write8(0x01FF, 0x41)
runpgm(b8b, [0xA2, 0x05, 0xBD, 0xFA, 0x01, 0x00])
c8b.run(3)
check(c8b.cycles == 13, "same-page LDA abs,X: LDX(2)+LDA(4)+BRK(7)=13")

let m8c = mk()
let b8c = m8c[0]
let c8c = m8c[1]
b8c.write8(0x10, 0xE0)
b8c.write8(0x11, 0x01)
b8c.write8(0x0210, 0x42)
runpgm(b8c, [0xA0, 0x30, 0xB1, 0x10, 0x00])
c8c.run(3)
check(c8c.regs.a == 0x42, "LDA ($10),Y with Y=$30 loads $0210")
check(c8c.cycles == 15, "crossing LDA (zp),Y: LDY(2)+LDA(5+1)+BRK(7)=15")

let m8d = mk()
let b8d = m8d[0]
let c8d = m8d[1]
b8d.write8(0x0300, 0x00)
b8d.write8(0xFFFC, 0xFB)
b8d.write8(0xFFFD, 0x02)
b8d.load([0xA2, 0x01], 0x02FB)
b8d.load([0xD0, 0x01], 0x02FD)
c8d.reset()
c8d.run(3)
check(c8d.cycles == 13, "crossing BNE: LDX(2)+BNE+1(4)+BRK(7)=13")

let m8e = mk()
let b8e = m8e[0]
let c8e = m8e[1]
runpgm(b8e, [0xA2, 0x01, 0xD0, 0x02, 0x00, 0x00])
c8e.run(3)
check(c8e.cycles == 12, "same-page BNE: LDX(2)+BNE(3)+BRK(7)=12")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
