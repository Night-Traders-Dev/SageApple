#########################################################################
## SageApple — SPI flash chip + 6502 flash access (Milestone 11)
##
## Run:  sage tests/storage/test_flash.sage   (from the repo root)
#########################################################################

import devices.flash
import sageapple.machine
import compiler.asm6502

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

let chip = flash.Flash(65536)
let f = flash.FlashSPI(chip)

print("== chip power-up ==")
check(chip.mem[0] == 0xFF, "memory reads $FF erased")
check(len(chip.mem) == 65536, "64KB capacity")

print("== JEDEC id ==")
f.csl(1)
f.byte(0x9F)
check(f.resp == 0xEF, "JEDEC byte 1 = $EF")
f.byte(0x00)
check(f.resp == 0x40, "JEDEC byte 2 = $40")
f.byte(0x00)
check(f.resp == 0x15, "JEDEC byte 3 = $15")
f.byte(0x00)
check(f.resp == 0x00, "JEDEC stream ends")
f.csl(0)

print("== write protect ==")
f.csl(1)
f.byte(0x05)
f.byte(0x00)
check(f.resp == 0x00, "status: not write-enabled")
f.byte(0x06)
f.byte(0x05)
f.byte(0x00)
check(f.resp == 0x02, "WEL set after write-enable")
f.byte(0x04)
f.byte(0x05)
f.byte(0x00)
check(f.resp == 0x00, "WEL cleared after write-disable")
f.csl(0)

print("== page program + read ==")
f.csl(1)
f.byte(0x06)                       # write enable
f.csl(0)
f.csl(1)
f.byte(0x02)                       # program
f.byte(0x00)                       # addr 0x000004
f.byte(0x00)
f.byte(0x04)
f.byte(0xAB)                       # payload
f.byte(0xCD)
f.byte(0xEF)
f.csl(0)
check(chip.mem[4] == 0xAB and chip.mem[5] == 0xCD and chip.mem[6] == 0xEF, "bytes programmed into flash")
f.csl(1)
f.byte(0x03)                       # read
f.byte(0x00)
f.byte(0x00)
f.byte(0x04)
check(f.resp == 0xAB, "read returns first byte at address")
f.byte(0x00)
check(f.resp == 0xCD, "stream advances")
f.byte(0x00)
check(f.resp == 0xEF, "third byte")
f.csl(0)

print("== program without write-enable is ignored ==")
f.csl(1)
f.byte(0x04)                       # write disable (clear WEL)
f.csl(0)
f.csl(1)
f.byte(0x02)
f.byte(0x00)
f.byte(0x00)
f.byte(0x04)
f.byte(0x42)
f.csl(0)
check(chip.mem[4] == 0xAB, "data unchanged without WEL")

print("== sector erase ==")
f.csl(1)
f.byte(0x06)
f.csl(0)
f.csl(1)
f.byte(0x20)                       # 4K sector erase
f.byte(0x00)
f.byte(0x00)
f.byte(0x04)
f.csl(0)
check(chip.mem[4] == 0xFF and chip.mem[5] == 0xFF, "sector erased")
f.csl(1)
f.byte(0x03)
f.byte(0x00)
f.byte(0x00)
f.byte(0x04)
check(f.resp == 0xFF, "erased byte reads back $FF")
f.csl(0)

print("== 6502 drives the flash ==")
let m = machine.SageApple()
let code = asm6502.asm([
    "org $0300",
    "    LDA #$01", "STA $2006",       # CS assert
    "    LDA #$06", "STA $2005",       # write enable
    "    LDA #$00", "STA $2006",       # CS release
    "    LDA #$01", "STA $2006",
    "    LDA #$02", "STA $2005",       # program
    "    LDA #$00", "STA $2005",       # addr high
    "    LDA #$00", "STA $2005",       # addr mid
    "    LDA #$40", "STA $2005",       # addr low -> 0x40
    "    LDA #$77", "STA $2005",       # data
    "    LDA #$88", "STA $2005",
    "    LDA #$00", "STA $2006",       # CS release
    "    LDA #$01", "STA $2006",
    "    LDA #$03", "STA $2005",       # read
    "    LDA #$00", "STA $2005",
    "    LDA #$00", "STA $2005",
    "    LDA #$40", "STA $2005",
    "    LDA $2005",                   # resp = mem[0x40]
    "    STA $0040",
    "    LDA #$00", "STA $2005",       # dummy advance
    "    LDA $2005",
    "    STA $0041",
    "    LDA #$00", "STA $2005",
    "    LDA $2005",
    "    STA $0042",
    "    LDA #$00", "STA $2006",
    "done:", "JMP done"],
    0x0300)[0]
var k = 0
var rom = []
while k < 32768:
    push(rom, 0)
    k = k + 1
rom[0] = 0x4C
rom[1] = 0x00
rom[2] = 0x03
rom[0x7FFC] = 0x00
rom[0x7FFD] = 0x80
m.boot_rom(rom)
var i = 0
while i < len(code):
    m.bus.write_ram(0x0300 + i, code[i])
    i = i + 1
var steps = 0
while steps < 800000:
    m.cpu.step()
    steps = steps + 1
check(m.bus.flashdev.mem[0x40] == 0x77 and m.bus.flashdev.mem[0x41] == 0x88, "6502 programmed flash data")
check(m.bus.ram[0x40] == 0x77, "6502 read back byte 1")
check(m.bus.ram[0x41] == 0x88, "6502 read back byte 2")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")