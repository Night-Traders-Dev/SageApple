import sageapple.apple2_machine
import sageapple.apple2_rom

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

let machine = apple2_machine.Apple2Machine()
let bus = machine.bus
let machine_cpu = machine.cpu
let rom = apple2_rom.build()
check(len(rom) == 0x3000, "replacement ROM is 12 KiB")
check(machine.load_rom(rom) == 0, "replacement ROM loads at Apple II space")
check(machine_cpu.regs.pc == 0xD000, "reset vector enters replacement ROM")
var steps = 0
while steps < 200:
    machine_cpu.step()
    steps = steps + 1
check(bus.serial_text() == "A2\r\nHI\r\n", "replacement ROM emits its signature")
check(slice(machine.render_text(1, true), 0, 2) == "HI", "rendered text starts with HI after boot")
check(len(bus.events) == 2, "replacement ROM records text-page writes")
check(bus.events[0] == [0x0400, 0xC8], "text event contains high-bit H")
check(bus.events[1] == [0x0401, 0xC9], "text event contains high-bit I")
machine.keyboard_input("X")
steps = 0
while steps < 2000:
    machine_cpu.step()
    steps = steps + 1
check(bus.serial_text() == "A2\r\nHI\r\nX", "replacement ROM echoes keyboard input")
check(slice(machine.render_text(1, true), 0, 3) == "HIX", "rendered text starts with HIX after keyboard input")
check(bus.events[2] == [0x0402, 0xD8], "keyboard input updates text memory with high-bit X")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
