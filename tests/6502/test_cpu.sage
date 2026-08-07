#########################################################################
## SageApple — Sage6502 CPU smoke test
##
## Run:  sage tests/6502/test_cpu.sage   (from the SageApple repo root)
#########################################################################

import sage6502.cpu
import bus.bus

var failures = 0
var passes = 0

proc hx(v):
    return "0x" + str(v)

# ---------------------------------------------------------------
# test 1: loads, INX, STX, ADC
# CLC ; LDA #$2A ; TAX ; INX ; STX $10 ; LDA $10 ; ADC #$05 ; STA $0300 ; JMP loop
# ---------------------------------------------------------------
let b1 = bus.bus.Bus()
let c1 = cpu.CPU(b1)
b1.load([0x18, 0xA9, 0x2A, 0xAA, 0xE8, 0x86, 0x10,
         0xA5, 0x10, 0x69, 0x05, 0x8D, 0x00, 0x03,
         0x00], 0x0200)
b1.write8(0xFFFC, 0x00)
b1.write8(0xFFFD, 0x02)
c1.reset()
c1.run()
print("test1  LDA/STX/INX/ADC")
if c1.regs.a == 0x30:
    print("  PASS A=", hx(c1.regs.a))
    passes = passes + 1
else:
    print("  FAIL A =", hx(c1.regs.a))
    failures = failures + 1
if c1.regs.x == 0x2B:
    print("  PASS X =", hx(c1.regs.x))
    passes = passes + 1
else:
    print("  FAIL X =", hx(c1.regs.x))
    failures = failures + 1
if b1.read8(0x10) == 0x2B and b1.read8(0x0300) == 0x30:
    print("  PASS mem stores")
    passes = passes + 1
else:
    print("  FAIL mem stores")
    failures = failures + 1
if c1.status.C() == 0:
    print("  PASS carry clear")
    passes = passes + 1
else:
    print("  FAIL carry not clear")
    failures = failures + 1

# ---------------------------------------------------------------
# test 2: SBC + branch
# LDX #$05 ; LDA #$07 ; SEC ; SBC #$03 ; BNE skip ; LDY #$00 ; skip: STY $0350
# ---------------------------------------------------------------
let b = bus.bus.Bus()
let c = cpu.CPU(b)
b.load([0xA2, 0x05, 0xA9, 0x07, 0x38, 0xE9, 0x03, 0xF0, 0x00,
        0xA0, 0x00, 0x8C, 0x50, 0x03, 0x00], 0x0200)
b.write8(0xFFFC, 0x00)
b.write8(0xFFFD, 0x02)
c.reset()
c.run()
print("2  SBC/comparison branch")
if c.regs.a == 0x04:
    print("  PASS A =", hx(c.regs.a))
    passes = passes + 1
else:
    print("  FAIL A =", hx(c.regs.a))
    failures = failures + 1
if c.status.C() == 1 and c.status.N() == 0:
    print("  PASS flags C=1 N=0")
    passes = passes + 1
else:
    print("  FAIL flags")
    failures = failures + 1
if b.read8(0x0350) == 0x00:
    print("  PASS branch taken (LDY skipped)")
    passes = passes + 1
else:
    print("  FAIL branch")
    failures = failures + 1
if c.regs.y == 0x00:
    print("  PASS Y = $00")
    passes = passes + 1
else:
    print("  FAIL Y =", hx(c.regs.y))
    failures = failures + 1

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")