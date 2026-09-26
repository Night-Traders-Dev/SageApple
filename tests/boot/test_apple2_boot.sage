import sageapple.apple2_display
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

check(machine.display.bus == bus and machine.display.text == machine.text and machine.display.lores == machine.lores and machine.display.hires == machine.hires, "the machine display shares the boot bus and page views")
check(machine.display_page() == 1 and machine.display_mode() == "text" and machine.display_mixed() == false, "the machine forwards the reset display page, mode, and mixed state")
check(machine.display_snapshot() == [1, "text", false], "the machine forwards the three-field display snapshot")
check(len(machine.display_row_sources()) == 24 and machine.display_row_sources()[0] == "text" and machine.display_row_sources()[23] == "text", "the machine forwards twenty-four text row sources after boot")
let boot_frame = machine.render_display_default()
check(len(boot_frame) == 24 * 40 + 23 and slice(boot_frame, 0, 3) == "HIX", "the default display frame shows the booted text screen")
check(boot_frame == join(machine.text.render_lines(1, false), "\n"), "the display frame matches the text projection of the active page")
check(machine.render_display(apple2_display.default_palette(), "#", ".") == boot_frame, "the machine forwards a caller palette to the display frame")
check(slice(machine.render_text(1, true), 0, 3) == "HIX", "the existing text projection is unchanged by display composition")
let boot_events = len(bus.events)
machine.render_display_default()
check(len(bus.events) == boot_events, "display composition adds no bus events after boot")
bus.write8(0xC050, 0x00)
check(machine.display_mode() == "lores" and machine.display_snapshot() == [1, "lores", false] and machine.display_row_sources()[0] == "graphics", "a boot-time soft switch switches the forwarded display to lo-res")
check(slice(machine.render_display_default(), 0, 6) == "C8C9D8", "the lo-res frame reinterprets the booted high-bit text bytes as color cells")
bus.write8(0xC057, 0x00)
bus.write8(0x2000, 0x01)
check(machine.display_mode() == "hires" and machine.render_display_default()[0] == "#", "a boot-time hi-res switch samples the hi-res page in the frame")
bus.write8(0xC053, 0x00)
check(machine.display_mixed() == true and machine.display_row_sources()[19] == "graphics" and machine.display_row_sources()[20] == "text", "a boot-time mixed switch splits the frame at the text window")
bus.write8(machine.text.cell_address(20, 0, 1), 0xC4)
let mixed_frame = machine.render_display_default()
check(mixed_frame[20 * 41] == "D" and mixed_frame[0] == "#", "the mixed frame keeps hi-res rows above the text window")
bus.write8(0xC052, 0x00)
bus.write8(0xC054, 0x00)
bus.write8(0xC051, 0x00)
check(machine.display_snapshot() == [1, "text", false] and slice(machine.render_display_default(), 0, 3) == "HIX", "restoring the switches restores the booted text frame")

## ---- console behaviour (cursor, Return, backspace) ---------------------
proc boot_fresh():
    let mm = apple2_machine.Apple2Machine()
    let rr = apple2_rom.build()
    mm.load_rom(rr)
    let cc = mm.cpu
    var k = 0
    while k < 200:
        cc.step()
        k = k + 1
    return mm

proc type_keys(mm, keys, n):
    mm.keyboard_input(keys)
    var k = 0
    while k < n:
        mm.cpu.step()
        k = k + 1

print("== console: the cursor advances across the text page ==")
let cm = boot_fresh()
type_keys(cm, "ABC", 2000)
check(cm.bus.serial_text() == "A2\r\nHI\r\nABC", "printable keys echo in order")
check(cm.bus.read8(0x0402) == 0xC1, "first key lands at $0402 with the high bit")
check(cm.bus.read8(0x0403) == 0xC2, "second key lands at $0403")
check(cm.bus.read8(0x0404) == 0xC3, "third key lands at $0404")
check(slice(cm.render_text(1, true), 0, 5) == "HIABC", "the text page shows HIABC")

print("== console: Return starts the next 40-column row ==")
let cm2 = boot_fresh()
type_keys(cm2, "AB\r", 2000)
check(cm2.bus.serial_text() == "A2\r\nHI\r\nAB\r\n", "Return echoes a newline")
check(cm2.bus.read8(0x0402) == 0xC1 and cm2.bus.read8(0x0403) == 0xC2, "keys before Return stay on row one")
type_keys(cm2, "Z", 2000)
check(cm2.bus.read8(0x042A) == 0xDA, "the key after Return lands at $042A (row two)")

print("== console: backspace clears the previous cell ==")
let cm3 = boot_fresh()
type_keys(cm3, "AB", 2000)
## chr(127) is a real DEL byte; "\u007f" is not interpreted as one here and
## would arrive as the literal six characters.
type_keys(cm3, chr(127), 2000)
check(cm3.bus.read8(0x0402) == 0xC1, "backspace leaves the earlier key alone")
check(cm3.bus.read8(0x0403) == 0xA0, "backspace blanks the cell it steps back over")
check(slice(cm3.render_text(1, true), 0, 3) == "HIA", "the text page reflects the erase")
type_keys(cm3, "C", 2000)
check(cm3.bus.read8(0x0403) == 0xC3, "typing after a backspace rewrites the same cell")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
