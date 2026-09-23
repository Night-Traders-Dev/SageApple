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

proc contains(hay, needle):
    var i = 0
    while i + len(needle) <= len(hay):
        if slice(hay, i, i + len(needle)) == needle:
            return true
        i = i + 1
    return false

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
check(len(bus.events) == 2, "replacement ROM records text-page writes")
check(bus.events[0] == [0x0400, 0x48], "text event contains H")
check(bus.events[1] == [0x0401, 0x49], "text event contains I")
bus.serial_input("X")
steps = 0
while steps < 2000:
    machine_cpu.step()
    steps = steps + 1
check(contains(bus.serial_text(), "X"), "replacement ROM echoes serial input")
check(bus.events[2] == [0x0402, 0x58], "serial input updates text memory")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
