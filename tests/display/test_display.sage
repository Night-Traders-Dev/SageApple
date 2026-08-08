#########################################################################
## SageApple — SPI display controller + graphics (Milestone 10)
##
## Run:  sage tests/display/test_display.sage   (from the repo root)
#########################################################################

import devices.display
import sageapple.graphics
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

print("== display controller protocol ==")
let d = display.DisplaySPI()
check(d.oled.on == 0, "display off after power-on")
d.cmd(0xAF)
check(d.oled.on == 1, "display-on command applied")
d.cmd(0xB0)                    # page 0
d.cmd(0x00)                    # column low nibble
d.cmd(0x10)                    # column high nibble
d.dat(0xFF)                    # data byte
check(d.oled.fb[0] == 0xFF, "data byte lands at page0/col0")
d.dat(0x01)
check(d.oled.fb[1] == 0x01, "cursor advances to col1")
d.cmd(0xB1)                    # page 1
d.cmd(0x00)
d.cmd(0x10)
d.dat(0xAA)
check(d.oled.fb[128] == 0xAA, "page1 col0 written")

print("== addressing window ==")
d.cmd(0xB0)                    # back to page 0
d.cmd(0x21)                    # column address mode
d.cmd(0x02)                    # col_a = 2
d.cmd(0x04)                    # col_b = 4
d.dat(0x11)
d.dat(0x22)
d.dat(0x44)
check(d.oled.fb[2] == 0x11, "window start col2")
check(d.oled.fb[3] == 0x22, "col3")
check(d.oled.fb[4] == 0x44, "col4 held within window")
d.dat(0x88)
check(d.oled.fb[2] == 0x88, "wrap: next byte returns to col_a")
check(d.oled.fb[5] == 0, "column outside window untouched")
d.cmd(0x21)
d.cmd(0x00)
d.cmd(0x7F)                    # restore full window

print("== graphics: pixels ==")
let g = graphics.Gfx(d)
g.clear(0)
check(g.get_pixel(10, 10) == 0, "framebuffer starts clear")
g.put_pixel(10, 10, 1)
check(g.get_pixel(10, 10) == 1, "pixel set")
check(g.get_pixel(9, 10) == 0, "neighbour stays clear")
g.put_pixel(10, 10, 0)
check(g.get_pixel(10, 10) == 0, "pixel cleared")
g.put_pixel(0, 63, 1)
check((d.oled.fb[7 * 128 + 0] & 0x80) != 0, "y=63 maps to bit7 of page7")
g.put_pixel(0, 0, 1)
check((d.oled.fb[0] & 0x01) != 0, "y=0 maps to bit0 of page0")

print("== graphics: lines ==")
g.clear(0)
g.draw_line(0, 0, 4, 4)
check(g.get_pixel(0, 0) == 1 and g.get_pixel(2, 2) == 1 and g.get_pixel(4, 4) == 1, "diagonal pixels lit")
check(g.get_pixel(4, 0) == 0 and g.get_pixel(0, 4) == 0, "off-diagonal pixels clear")
g.clear(0)
g.draw_line(0, 0, 2, 4)
check(g.get_pixel(0, 0) == 1 and g.get_pixel(1, 2) == 1 and g.get_pixel(2, 4) == 1, "steep line pixels lit")
check(g.get_pixel(0, 4) == 0, "steep line endpoint region exact")

print("== graphics: text ==")
g.clear(0)
g.draw_text(2, 8, "A")
check(g.get_pixel(3, 8) == 1 and g.get_pixel(5, 8) == 1, "'A' top row lit")
check(g.get_pixel(2, 8) == 0, "'A' top-left corner clear")
check(g.get_pixel(4, 11) == 1, "'A' crossbar lit")
check(g.get_pixel(2, 11) == 1 and g.get_pixel(6, 11) == 1, "'A' crossbar ends lit")
check(g.get_pixel(4, 14) == 0, "'A' legs gap clear")

print("== 6502 drives the display ==")
let m = machine.SageApple()
let code = asm6502.asm([
    "org $0300",
    "    LDA #$AE",
    "    STA $2002",      # display off
    "    LDA #$B0",
    "    STA $2002",      # page 0
    "    LDA #$00",
    "    STA $2002",      # column low = 0
    "    LDA #$10",
    "    STA $2002",      # column high = 0
    "    LDA #$0F",
    "    STA $2003",      # data: rows 0-3 of col 0
    "    LDA #$F0",
    "    STA $2003",      # data: rows 4-7 of col 1
    "done:",
    "    JMP done"],
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
while steps < 600000:
    m.cpu.step()
    steps = steps + 1
check(m.bus.gpu.oled.fb[0] == 0x0F, "6502 wrote 0x0F to page0/col0")
check(m.bus.gpu.oled.fb[1] == 0xF0, "6502 wrote 0xF0 to page0/col1")
check(m.bus.gpu.oled.on == 0, "6502 display-off command applied")
check(m.bus.read8(0x2004) == 0x80, "status port reports ready")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")