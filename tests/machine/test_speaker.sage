#########################################################################
## SageApple — PWM speaker device (Milestone 12)
##
## Run:  sage tests/machine/test_speaker.sage   (from the repo root)
#########################################################################

import devices.speaker
import basic.basic
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

print("== speaker device ==")
let sp = speaker.Speaker()
check(sp.count() == 0, "no tones yet")
check(sp.freq == 0, "silent at power-on")
sp.beep()
check(sp.count() == 1, "beep records a tone")
let t0 = sp.tone_at(0)
check(t0[0] == 1000 and t0[1] == 100, "beep is 1000Hz / 100ms")
sp.tone(2000, 50)
check(sp.count() == 2, "tone appended")
let t1 = sp.tone_at(1)
check(t1[0] == 2000, "tone frequency recorded")
sp.tone(0, 100)
check(sp.count() == 2, "zero frequency is silence (not recorded)")
check(sp.last()[0] == 2000, "last() reads the newest tone")

print("== BASIC BEEP ==")
let b = basic.Basic()
b.speaker = sp
b.reset_out()
b.set_line(10, "BEEP")
b.set_line(20, "BEEP 2000")
b.set_line(30, "END")
b.run()
check(sp.tone_at(2)[0] == 1000, "bare BEEP defaults to 1000Hz")
check(sp.tone_at(3)[0] == 2000, "BEEP 2000 uses the argument")

print("== 6502 drives the speaker ==")
let m = machine.SageApple()
let code = asm6502.asm([
    "org $0300",
    "    LDA #$77",
    "    STA $2007",           # speaker tone 119Hz
    "    LDA #$00",
    "    STA $2007",           # silence
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
while steps < 300000:
    m.cpu.step()
    steps = steps + 1
check(m.bus.speaker.count() == 1, "6502 STA $2007 recorded a tone")
let t = m.bus.speaker.tone_at(0)
check(t[0] == 0x77, "tone frequency matches written value")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")