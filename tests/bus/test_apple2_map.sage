import bus.apple2bus

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc rejects(b, image):
    var rejected = false
    try:
        b.load_rom(image)
    catch e:
        rejected = true
    return rejected

proc make_rom():
    let image = []
    var i = 0
    while i < 0x3000:
        push(image, 0x00)
        i = i + 1
    return image

let b = apple2bus.Apple2Bus()
check(len(b.ram) == 0xC000, "48 KiB RAM is allocated")
b.write_ram(0x0000, 0x12)
b.write8(0xBFFF, 0x34)
check(b.read8(0x0000) == 0x12, "RAM starts at $0000")
check(b.read8(0xBFFF) == 0x34, "RAM ends at $BFFF")
b.write8(0xC000, 0x56)
check(b.read8(0xC000) == 0x00, "C000 is not RAM")
b.write8(0xC100, 0x78)
check(b.read8(0xC100) == 0x00, "unsupported reads are deterministic")

let rom = make_rom()
rom[0] = 0x11
rom[0x2FFF] = 0xEE
check(b.load_rom(rom) == 0, "12 KiB ROM image loads")
check(b.read8(0xD000) == 0x11, "ROM starts at $D000")
check(b.read8(0xFFFF) == 0xEE, "ROM ends at $FFFF")
b.write8(0xD000, 0x22)
b.write8(0xFFFF, 0x33)
check(b.read8(0xD000) == 0x11 and b.read8(0xFFFF) == 0xEE, "ROM is read-only")
check(rejects(b, [0x00]), "short ROM images are rejected")
let long_rom = make_rom()
push(long_rom, 0x00)
check(rejects(b, long_rom), "long ROM images are rejected")
check(b.read8(0xD000) == 0x11, "invalid ROM loads do not mutate ROM")

b.keyboard_input("A")
check(b.read8(0xC000) == 65, "keyboard latch exposes injected input")
check(b.read8(0xC010) == 0x80, "keyboard strobe is set")
check(b.read8(0xC010) == 0x00, "keyboard strobe read clears it")

check(b.speaker_state() == false, "speaker starts off")
b.write8(0xC030, 0x00)
check(b.speaker_state() == true, "speaker toggle turns on")
b.write8(0xC030, 0x00)
check(b.speaker_state() == false, "speaker toggle turns off")

b.write8(0xC052, 0x5A)
check(b.video_state(2), "video switch state is recorded")
check(b.video_value(2) == 0x5A, "video switch value is retained")
check(b.read8(0xC052) == 0x80, "video switch is readable")

b.serial_input("Q")
check(b.read8(0xC081) == 0xD1, "serial bridge reports ready input with the high bit")
b.write8(0xC080, ord("O"))
b.write8(0xC080, ord("K"))
check(b.serial_text() == "OK", "serial bridge emits transmitted text")

b.clear_events()
b.write_ram(0x03FF, 0x01)
b.write8(0x0400, 0x41)
b.write8(0x0BFF, 0x42)
b.write8(0x1FFF, 0x43)
b.write_ram(0x2000, 0x44)
b.write8(0x5FFF, 0x45)
check(len(b.events) == 4, "only text and hi-res writes are recorded")
check(b.events[0] == [0x0400, 0x41], "first text event is ordered")
check(b.events[1] == [0x0BFF, 0x42], "second text event is ordered")
check(b.events[2] == [0x2000, 0x44], "first hi-res event is ordered")
check(b.events[3] == [0x5FFF, 0x45], "second hi-res event is ordered")

b.reset()
check(len(b.events) == 0 and b.speaker_state() == false, "reset clears volatile state")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
