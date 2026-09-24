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

proc rejects_slot_rom(b, slot, image):
    var slot_rejected = false
    try:
        b.load_slot_rom(slot, image)
    catch e:
        slot_rejected = true
    return slot_rejected

proc rejects_expansion_rom(b, image):
    var expansion_rejected = false
    try:
        b.load_expansion_rom(image)
    catch e:
        expansion_rejected = true
    return expansion_rejected

proc make_image(size, value):
    let image = []
    var i = 0
    while i < size:
        push(image, value & 0xFF)
        i = i + 1
    return image

proc make_rom():
    return make_image(0x3000, 0x00)

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
rom[0x2800] = 0xF8
rom[0x2FFF] = 0xEE
check(b.load_rom(rom) == 0, "12 KiB ROM image loads")
check(b.read8(0xD000) == 0x11, "ROM starts at $D000")
check(b.read8(0xF800) == 0xF8, "main ROM remains explicit at $F800")
check(b.read8(0xFFFF) == 0xEE, "ROM ends at $FFFF")
b.write8(0xD000, 0x22)
b.write8(0xFFFF, 0x33)
check(b.read8(0xD000) == 0x11 and b.read8(0xFFFF) == 0xEE, "ROM is read-only")
check(rejects(b, [0x00]), "short ROM images are rejected")
let long_rom = make_rom()
push(long_rom, 0x00)
check(rejects(b, long_rom), "long ROM images are rejected")
check(b.read8(0xD000) == 0x11, "invalid ROM loads do not mutate ROM")

let compat = apple2bus.Apple2Bus()
check(compat.load_rom(rom) == 0, "compatibility bus loads the main ROM")
check(len(compat.language_card_ram) == 0x4000, "16 KiB language-card RAM is allocated")
check(compat.language_card_flat_rom_fallback, "flat ROM fallback is explicit")
check(compat.language_card_state() == [2, false, true, false], "language card resets to ROM-read bank 2")
compat.write8(0xD000, 0x3C)
check(compat.read8(0xD000) == 0x11, "ROM mode hides write-enabled language-card RAM")
compat.read8(0xC300)
check(compat.language_card_state() == [1, true, false, false], "C300 selects read RAM and write ROM")
compat.write8(0xD000, 0xA1)
check(compat.read8(0xD000) == 0x00, "C300 mode rejects language-card writes")
compat.read8(0xC302)
check(compat.language_card_state() == [1, false, true, false], "C302 selects read ROM and write RAM")
check(compat.read8(0xD000) == 0x11, "C302 keeps deterministic main ROM reads visible")
compat.write8(0xD000, 0xB2)
check(compat.read8(0xD000) == 0x11, "ROM reads remain visible while RAM is write-enabled")
compat.read8(0xC300)
check(compat.read8(0xD000) == 0xB2, "C300 exposes the prewritten bank 1 byte")
compat.read8(0xC303)
check(compat.language_card_state() == [1, false, false, true], "C303 selects read ROM and write ROM")
compat.read8(0xC303)
check(compat.language_card_state() == [1, false, false, true], "C303 never write-enables RAM")
compat.write8(0xD000, 0x55)
check(compat.read8(0xD000) == 0x11, "C303 keeps RAM write-protected")
compat.read8(0xC300)
compat.read8(0xC301)
compat.read8(0xC301)
compat.write8(0xE123, 0xD4)
compat.read8(0xC300)
check(compat.read8(0xE123) == 0xD4, "shared language-card RAM spans $E000-$F7FF")
compat.write8(0xF800, 0x55)
compat.write8(0xFFFF, 0x66)
check(compat.read8(0xF800) == 0xF8 and compat.read8(0xFFFF) == 0xEE, "RAM mode cannot override $F800-$FFFF ROM")
compat.read8(0xC308)
check(compat.language_card_state() == [2, true, false, false], "C308 selects the second 4 KiB bank")
check(compat.read8(0xD000) == 0x3C, "language-card D000 banks remain independent")
compat.read8(0xC300)
check(compat.read8(0xD000) == 0xB2, "bank 1 data survives bank switching")

let slot_image = make_image(0x100, 0x00)
slot_image[0] = 0x31
check(compat.load_slot_rom(1, slot_image) == 0, "256-byte slot ROM image loads")
check(rejects_slot_rom(compat, 1, make_image(0xFF, 0x00)), "short slot ROM images are rejected")
check(rejects_slot_rom(compat, 1, make_image(0x101, 0x00)), "long slot ROM images are rejected")
check(rejects_slot_rom(compat, 0, slot_image), "slot 0 ROM loads are rejected")
check(rejects_slot_rom(compat, 8, slot_image), "slot 8 ROM loads are rejected")
check(compat.read8(0xC100) == 0x31, "invalid slot ROM loads do not mutate storage")
compat.write8(0xC100, 0xEE)
check(compat.read8(0xC100) == 0x31, "slot ROM storage is read-only")
var slot_sizes_valid = true
var slot = 1
while slot <= 7:
    let address_image = make_image(0x100, 0x00)
    var offset = 0
    if slot == 3:
        offset = 4
    let marker = 0xA0 + slot
    address_image[offset] = marker
    compat.load_slot_rom(slot, address_image)
    let base = 0xC000 + slot * 0x100
    let value = compat.read8(base + offset)
    check(value == marker, "slot " + str(slot) + " ROM address maps correctly")
    if len(compat.slot_roms[slot]) != 0x100:
        slot_sizes_valid = false
    slot = slot + 1
check(slot_sizes_valid, "slots 1-7 each retain 256 bytes")
check(compat.read8(0xC300) == 0x00 and compat.read8(0xC304) == 0xA3, "C300-C303 take precedence over slot 3 base ROM")
check(compat.read8(0xC0FF) == 0x00, "unimplemented slot 0 space stays deterministic")

let expansion = make_image(0x800, 0x00)
expansion[0] = 0xC8
expansion[0x7FF] = 0xFE
check(compat.load_expansion_rom(expansion) == 0, "2 KiB expansion ROM image loads")
check(rejects_expansion_rom(compat, make_image(0x7FF, 0x00)), "short expansion ROM images are rejected")
check(rejects_expansion_rom(compat, make_image(0x801, 0x00)), "long expansion ROM images are rejected")
check(compat.read8(0xC800) == 0xC8 and compat.read8(0xCFFF) == 0xFE, "expansion ROM maps $C800-$CFFF")
compat.write8(0xC800, 0x99)
check(compat.read8(0xC800) == 0xC8, "expansion ROM storage is read-only")
check(compat.read8(0xC800) == 0xC8, "invalid expansion loads do not mutate storage")

compat.read8(0xC300)
compat.reset()
check(compat.language_card_state() == [2, false, true, false], "reset clears language-card mode and bank state")
check(compat.read8(0xD000) == 0x11 and compat.read8(0xF800) == 0xF8, "reset preserves and selects main ROM images")
check(compat.read8(0xC100) == 0xA1 and compat.read8(0xC800) == 0xC8, "reset preserves loaded peripheral ROMs")
compat.read8(0xC308)
check(compat.read8(0xD000) == 0x3C, "reset preserves language-card RAM")
compat.read8(0xC300)
check(compat.read8(0xD000) == 0xB2, "reset preserves both language-card banks")

b.reset()
b.keyboard_input("A")
check(b.read8(0xC000) == 0xC1, "string A is encoded as Apple $C1")
check(b.read8(0xC000) == 0xC1, "C000 exposes a stable latched key")
check(b.read8(0xC010) == 0x80, "keyboard strobe reports a pending key")
check(b.read8(0xC000) == 0x41, "C010 read clears the retained latch high bit")
check(b.read8(0xC010) == 0x00, "C010 read acknowledges the current key")

b.reset()
b.keyboard_input("a")
check(b.read8(0xC000) == 0xC1, "lowercase A normalizes to the Apple letter key")

b.reset()
b.keyboard_input("0")
check(b.read8(0xC000) == 0xB0, "string zero is encoded as Apple $B0")
check(b.read8(0xC000) == 0xB0, "encoded zero remains latched before acknowledgement")
check(b.read8(0xC010) == 0x80, "encoded zero sets the keyboard strobe")
check(b.read8(0xC000) == 0x30, "acknowledged zero clears its latch high bit")
check(b.read8(0xC010) == 0x00, "encoded zero is acknowledged")

b.reset()
b.keyboard_input(" ")
check(b.read8(0xC000) == 0xA0, "space is encoded as Apple $A0")
check(b.read8(0xC000) == 0xA0, "space remains latched before acknowledgement")
check(b.read8(0xC010) == 0x80, "space sets the keyboard strobe")
check(b.read8(0xC000) == 0x20, "acknowledged space clears its latch high bit")
check(b.read8(0xC010) == 0x00, "space is acknowledged")

b.reset()
b.keyboard_input("\r\n")
check(b.read8(0xC000) == 0x8D, "carriage return is encoded as Apple $8D")
check(b.read8(0xC010) == 0x80, "carriage return sets the keyboard strobe")
check(b.read8(0xC000) == 0x0D, "acknowledged carriage return retains seven-bit data")
check(b.read8(0xC000) == 0x8D, "line feed promotes as Apple $8D")
check(b.read8(0xC010) == 0x80, "line return acknowledgement reports pending input")
check(b.read8(0xC000) == 0x0D, "acknowledged line feed clears bit 7")
check(b.read8(0xC010) == 0x00, "line feed is acknowledged")

b.reset()
b.keyboard_input(0xC1)
check(b.read8(0xC000) == 0xC1, "numeric keycode input is preserved")
check(b.read8(0xC010) == 0x80, "numeric keycode input sets the strobe")
check(b.read8(0xC000) == 0x41, "numeric keycode acknowledgement clears bit 7")
check(b.read8(0xC010) == 0x00, "numeric keycode input is acknowledged")

b.reset()
b.keyboard_input([0xC1, 0xB0])
check(b.read8(0xC000) == 0xC1, "array input preserves the first keycode")
check(b.read8(0xC010) == 0x80, "array input acknowledges the first keycode")
check(b.read8(0xC000) == 0x41, "first array keycode remains readable after C010")
check(b.read8(0xC000) == 0xB0, "array input preserves queued keycode order")
check(b.read8(0xC010) == 0x80, "queued keycode remains pending")
check(b.read8(0xC000) == 0x30, "final queued keycode clears bit 7")
check(b.read8(0xC010) == 0x00, "queued keycode is acknowledged")

b.reset()
b.keyboard_input("A0 ")
check(b.read8(0xC000) == 0xC1, "queued string input preserves first key")
check(b.read8(0xC010) == 0x80, "queued string input acknowledges first key")
check(b.read8(0xC000) == 0x41, "first queued string key remains readable after C010")
check(b.read8(0xC000) == 0xB0, "queued string input promotes zero second")
check(b.read8(0xC010) == 0x80, "queued string input acknowledges zero")
check(b.read8(0xC000) == 0x30, "zero queued string key remains readable after C010")
check(b.read8(0xC000) == 0xA0, "queued string input promotes space last")
check(b.read8(0xC010) == 0x80, "queued string input acknowledges space")
check(b.read8(0xC000) == 0x20, "queued string input ends with seven-bit space")
check(b.read8(0xC010) == 0x00, "queued string input is fully acknowledged")

b.reset()
b.keyboard_input("AB")
check(b.read8(0xC000) == 0xC1, "C010 write test starts with A")
b.write8(0xC010, 0x00)
check(b.read8(0xC000) == 0x41, "C010 write leaves the current key readable")
check(b.read8(0xC000) == 0xC2, "C010 write promotes B after current delivery")
check(b.read8(0xC010) == 0x80, "promoted B remains pending after write")
b.write8(0xC010, 0x00)
check(b.read8(0xC000) == 0x42, "C010 write clears the final latch high bit")
check(b.read8(0xC010) == 0x00, "C010 write leaves no pending key")

b.reset()
b.keyboard_input("AB")
b.reset()
check(b.read8(0xC000) == 0x00, "reset clears the keyboard latch")
check(b.read8(0xC010) == 0x00, "reset clears pending keyboard input")
b.keyboard_input("C")
check(b.read8(0xC000) == 0xC3, "reset drops queued keyboard input")

b.reset()
b.inject_keyboard(0xC1)
check(b.read8(0xC000) == 0xC1, "inject_keyboard remains an input alias")
b.reset()
b.keyboard_feed("A")
check(b.read8(0xC000) == 0xC1, "keyboard_feed remains an input alias")

b.reset()
b.keyboard_input("A")
b.serial_input("Q")
check(b.read8(0xC000) == 0xC1, "keyboard and UART input paths are independent")
check(b.read8(0xC081) == 0xD1, "UART input remains available through C081")
check(b.read8(0xC000) == 0xC1, "UART input does not change the keyboard latch")
b.reset()

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
