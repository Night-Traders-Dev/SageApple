#########################################################################
## SageApple — 6502 assembler test (Milestone 7, seeds M9)
##
## Run:  sage tests/compiler/test_asm6502.sage   (from the repo root)
#########################################################################

import compiler.asm6502
import sage6502.cpu
import bus.applebus

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

print("== assembly bytes ==")
let program = [
    "start:",
    "       CLC",
    "       LDA #$14",
    "       ADC #$0B",
    "       STA $0300",
    "loop:",
    "       DEX",
    "       BNE loop",
    "       JMP start",
]
let r = asm6502.asm(program, 0x8000)
let img = r[0]
check(img[0] == 0x18, "CLC = $18")
check(img[1] == 0xA9 and img[2] == 0x14, "LDA #$14 = A9 14")
check(img[3] == 0x69 and img[4] == 0x0B, "ADC #$0B = 69 0B")
check(img[5] == 0x8D and img[6] == 0x00 and img[7] == 0x03, "STA $0300 = 8D 00 03")
check(img[8] == 0xCA, "DEX = CA")
check(img[9] == 0xD0 and img[10] == 0xFD, "BNE loop relative offset")
check(img[11] == 0x4C and img[12] == 0x00 and img[13] == 0x80, "JMP start")
let labels = r[1]
check(labels["start"] == 0x8000, "label start = $8000")
check(labels["loop"] == 0x8008, "label loop = $8008")

print("== emulator execution ==")
let b = applebus.AppleBus()
b.load_rom(img)
let cp = cpu.CPU(b)
cp.regs.pc = 0x8000
var steps = 0
while steps < 1000 and cp.halted == false:
    cp.step()
    steps = steps + 1
check(cp.regs.a == 0x1F, "A = $1F after CLC/LDA/ADC")
check(b.ram[0x0300] == 0x1F, "STA $0300 stored $1F")