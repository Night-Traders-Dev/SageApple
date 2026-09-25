import bus.apple2bus
import sageapple.apple2_display
import sageapple.apple2_hires
import sageapple.apple2_lores
import sageapple.apple2_machine
import sageapple.apple2_text

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc new_display(bus):
    return apple2_display.Apple2Display(bus, apple2_text.Apple2TextPage(bus), apple2_lores.Apple2LoresPage(bus), apple2_hires.Apple2HiresPage(bus))

proc text_on(bus):
    bus.write8(0xC051, 0x00)

proc lores_on(bus):
    bus.write8(0xC050, 0x00)

proc hires_on(bus):
    bus.write8(0xC057, 0x00)

proc graphics_hires(bus):
    lores_on(bus)
    hires_on(bus)

proc graphics_lores(bus):
    bus.write8(0xC056, 0x00)
    lores_on(bus)

proc mixed_on(bus):
    bus.write8(0xC053, 0x00)

proc mixed_off(bus):
    bus.write8(0xC052, 0x00)

proc page1(bus):
    bus.write8(0xC054, 0x00)

proc page2(bus):
    bus.write8(0xC055, 0x00)

proc all_ascii(entries):
    var index = 0
    while index < len(entries):
        if type(entries[index]) != "string" or len(entries[index]) != 1:
            return false
        if ord(entries[index]) < 32 or ord(entries[index]) > 126:
            return false
        index = index + 1
    return true

proc count_of(rows, source):
    var total = 0
    var index = 0
    while index < len(rows):
        if rows[index] == source:
            total = total + 1
        index = index + 1
    return total

proc newlines_in(text):
    var total = 0
    var index = 0
    while index < len(text):
        if text[index] == "\n":
            total = total + 1
        index = index + 1
    return total

proc rejects_row(display, row):
    var rejected = false
    try:
        display.is_text_row(row)
    catch e:
        rejected = true
    return rejected

proc rejects_row_source(display, row):
    var rejected = false
    try:
        display.row_source(row)
    catch e:
        rejected = true
    return rejected

proc rejects_render_row(display, row, palette, on_char, off_char):
    var rejected = false
    try:
        display.render_row(row, palette, on_char, off_char)
    catch e:
        rejected = true
    return rejected

proc rejects_palette(display, palette):
    var rejected = false
    try:
        display.render_row(0, palette, "#", ".")
    catch e:
        rejected = true
    return rejected

proc rejects_lines_palette(display, palette):
    var rejected = false
    try:
        display.render_lines(palette, "#", ".")
    catch e:
        rejected = true
    return rejected

proc rejects_render_palette(display, palette):
    var rejected = false
    try:
        display.render(palette, "#", ".")
    catch e:
        rejected = true
    return rejected

proc ram_checksum(bus):
    var total = 0
    var index = 0
    while index < len(bus.ram):
        total = total + bus.ram[index]
        index = index + 1
    return total

proc alternating_cells(on_char, off_char, count):
    var line = ""
    var index = 0
    while index < count:
        if index % 2 == 0:
            line = line + on_char
        else:
            line = line + off_char
        index = index + 1
    return line

let palette = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]
let short_palette = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"]
let long_palette = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q"]
let base_palette = apple2_display.default_palette()

check(len(apple2_display.DEFAULT_PALETTE) == 16, "the default palette has exactly 16 entries")
check(all_ascii(apple2_display.DEFAULT_PALETTE), "every default palette entry is one printable ASCII character")
check(base_palette == apple2_display.DEFAULT_PALETTE, "default_palette() returns the default palette")
let mutated_palette = apple2_display.default_palette()
mutated_palette[0] = "!"
check(apple2_display.DEFAULT_PALETTE[0] != "!" and len(apple2_display.DEFAULT_PALETTE) == 16 and base_palette[0] != "!", "default_palette() returns an independent copy")
check(apple2_display.default_palette() == apple2_display.DEFAULT_PALETTE, "every default_palette() call returns a fresh full copy")

let machine = apple2_machine.Apple2Machine()
check(machine.display.bus == machine.bus, "machine display stores the existing bus")
check(machine.display.text == machine.text and machine.display.lores == machine.lores and machine.display.hires == machine.hires, "machine display shares the existing page views")
check(machine.display.text_window_start() == 20 and machine.display.text_window_rows() == 4, "the mixed text window starts at row twenty and spans four rows")

let bus = apple2bus.Apple2Bus()
let view = new_display(bus)
check(view.snapshot() == [1, "text", false], "a new display composes the reset video state as page one text")
check(view.page() == 1 and view.mode() == "text" and view.mixed() == false, "a new display reads the reset page, mode, and mixed state")
check(len(view.row_sources()) == 24 and count_of(view.row_sources(), "text") == 24, "text mode composes twenty-four text rows")
check(count_of(view.row_sources(), "graphics") == 0, "text mode composes no graphics rows")
bus.reset()
check(view.snapshot() == [1, "text", false] and view.row_source(0) == "text" and view.row_source(23) == "text", "a bus reset returns the composed display to the text default")

lores_on(bus)
check(view.snapshot() == [1, "lores", false] and view.mode() == "lores" and view.mixed() == false, "the $C050 write selects full lo-res")
check(count_of(view.row_sources(), "graphics") == 24, "full lo-res composes twenty-four graphics rows")
hires_on(bus)
check(view.mode() == "hires" and view.mixed() == false, "the $C057 write selects hi-res graphics")
text_on(bus)
check(view.mode() == "text", "the $C051 write selects the full text screen")
mixed_on(bus)
check(view.mixed() == true and view.snapshot() == [1, "text", true], "the $C053 write sets the mixed flag on the text screen")
mixed_off(bus)
check(view.mixed() == false and view.snapshot() == [1, "text", false], "the $C052 write clears the mixed flag")
page2(bus)
check(view.page() == 2 and view.snapshot() == [2, "text", false], "the $C055 write selects display page two")
page1(bus)
check(view.page() == 1 and view.snapshot() == [1, "text", false], "the $C054 write returns to display page one")
bus.write8(0xC056, 0x00)
text_on(bus)
check(bus.read8(0xC050) == 0x80 and view.mode() == "lores" and view.snapshot() == [1, "lores", false], "a $C050 read returns the latched value and applies the graphics switch")
lores_on(bus)
mixed_on(bus)
page2(bus)
hires_on(bus)
check(view.snapshot() == [2, "hires", true], "read and write switches compose page, mode, and mixed state together")

let text_bus = apple2bus.Apple2Bus()
let text_display = new_display(text_bus)
text_bus.write8(0x0400, 0xC8)
text_bus.write8(0x0401, 0xC9)
text_bus.write8(0x0402, 0x3F)
let text_row0 = text_display.render_row(0, base_palette, "#", ".")
check(len(text_row0) == 40, "a composed text row is forty characters wide")
check(slice(text_row0, 0, 2) == "HI" and text_row0[2] == "?", "a composed text row carries the active page characters")
check(text_row0 == text_display.text.render_lines(1, false)[0] and text_display.text.render_lines(1, false)[0][2] == "?", "composed text rows drop inverse and flash attribute bits")
check(text_display.text_lines(false)[0] == text_row0, "text_lines uses the active page")
let ragged = text_display.text_lines(true)
check(len(ragged) == 24 and len(ragged[0]) == 3 and len(ragged[1]) == 0, "trimmed text lines are ragged")
check(len(text_display.text_lines(false)[23]) == 40, "untrimmed text lines are a fixed forty characters")
check(text_display.is_text_row(0) and text_display.is_text_row(23) and text_display.row_source(0) == "text", "every text-mode row reports the text source")
text_bus.write8(0x0402, 0xC3)
check(text_display.render_row(0, base_palette, "#", ".")[2] == "C", "composed text rows read live page overwrites")
page2(text_bus)
text_bus.write8(0x0800, 0xC3)
check(text_display.page() == 2 and text_display.render_row(0, base_palette, "#", ".")[0] == "C", "text rows follow the active page switch")
page1(text_bus)
check(text_display.render_row(0, base_palette, "#", ".")[0] == "H", "returning to page one restores the first page row")

let lores_bus = apple2bus.Apple2Bus()
let lores_display = new_display(lores_bus)
lores_on(lores_bus)
let packed_colors = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
var color_index = 0
while color_index < 16:
    lores_bus.write8(0x0400 + color_index, packed_colors[color_index])
    color_index = color_index + 1
let lores_row0 = lores_display.render_row(0, base_palette, "#", ".")
check(len(lores_row0) == 80, "a composed lo-res row is eighty characters wide")
check(slice(lores_row0, 0, 32) == "0123456789ABCDEF0123456789ABCDEF", "composed lo-res rows substitute all sixteen default palette entries")
check(lores_display.is_text_row(0) == false and lores_display.row_source(0) == "graphics", "full lo-res rows report the graphics source")
lores_bus.write8(0x0400, 0x12)
check(slice(lores_display.render_row(0, base_palette, "#", "."), 0, 2) == "12", "composed lo-res rows decode the high and low nibbles")
check(slice(lores_display.render_row(0, palette, "#", "."), 0, 2) == "BC", "a caller palette is substituted into composed lo-res rows")
check(lores_display.render_row(0, base_palette, "#", ".") == lores_display.lores.render_row(1, 0, base_palette), "a composed lo-res row equals the lo-res page row")
lores_bus.write8(0x0400, 0x3D)
check(slice(lores_display.render_row(0, base_palette, "#", "."), 0, 2) == "3D", "composed lo-res rows read live page overwrites")

let mixed_bus = apple2bus.Apple2Bus()
let mixed_display = new_display(mixed_bus)
lores_on(mixed_bus)
mixed_on(mixed_bus)
mixed_bus.write8(0x0400, 0x12)
mixed_bus.write8(mixed_display.lores.byte_address(19, 0, 1), 0x45)
mixed_bus.write8(mixed_display.text.cell_address(20, 0, 1), 0xC5)
mixed_bus.write8(mixed_display.text.cell_address(23, 0, 1), 0xC6)
let mixed_sources = mixed_display.row_sources()
check(mixed_display.mixed() == true and mixed_display.snapshot() == [1, "lores", true], "the mixed flag composes with the graphics mode")
check(mixed_sources[0] == "graphics" and mixed_sources[19] == "graphics" and mixed_sources[20] == "text" and mixed_sources[23] == "text", "mixed mode splits graphics and text at row twenty")
check(count_of(mixed_sources, "text") == 4 and count_of(mixed_sources, "graphics") == 20, "mixed mode reserves the last four rows for the text window")
check(mixed_display.text_window_start() + mixed_display.text_window_rows() == 24, "the text window ends at the last row")
check(mixed_display.is_text_row(19) == false and mixed_display.is_text_row(20) == true, "the text window boundary is inclusive of row twenty")
check(slice(mixed_display.render_row(0, base_palette, "#", "."), 0, 2) == "12" and len(mixed_display.render_row(0, base_palette, "#", ".")) == 80, "mixed lo-res graphics rows keep the eighty-cell lo-res width")
check(mixed_display.render_row(20, base_palette, "#", ".")[0] == "E" and mixed_display.render_row(23, base_palette, "#", ".")[0] == "F", "mixed lo-res bottom rows read the text page")
check(mixed_display.render_row(19, base_palette, "#", ".")[0] == "4" and mixed_display.render_row(20, base_palette, "#", ".")[0] == "E", "the mixed boundary switches from lo-res cells to text characters")
page2(mixed_bus)
mixed_bus.write8(0x0800, 0x34)
mixed_bus.write8(mixed_display.text.cell_address(23, 0, 2), 0xC7)
check(slice(mixed_display.render_row(0, base_palette, "#", "."), 0, 2) == "34", "mixed lo-res graphics rows follow the page switch")
check(mixed_display.render_row(23, base_palette, "#", ".")[0] == "G", "mixed lo-res text rows follow the page switch")
page1(mixed_bus)
check(slice(mixed_display.render_row(0, base_palette, "#", "."), 0, 2) == "12" and mixed_display.render_row(23, base_palette, "#", ".")[0] == "F", "returning to page one restores the mixed lo-res composition")

let hires_bus = apple2bus.Apple2Bus()
let hires_display = new_display(hires_bus)
graphics_hires(hires_bus)
check(hires_display.mode() == "hires", "the $C050 and $C057 writes select hi-res graphics")
var hires_index = 0
while hires_index < 40:
    if hires_index % 2 == 0:
        hires_bus.write8(0x2000 + hires_index, 0x01)
    else:
        hires_bus.write8(0x2000 + hires_index, 0x7E)
    hires_index = hires_index + 1
let hires_row0 = hires_display.render_row(0, base_palette, "#", ".")
check(len(hires_row0) == 40, "a composed hi-res row is forty cells wide")
check(hires_row0 == alternating_cells("#", ".", 40), "composed hi-res rows sample the first bit of each seven-pixel group")
check(not hires_display.hires.pixel(7, 0, 1) and hires_display.hires.pixel(8, 0, 1) and hires_row0[1] == "." and hires_row0[2] == "#", "hi-res sampling ignores the other six bits of a group")
check(hires_display.render_row(0, base_palette, "X", "y") == alternating_cells("X", "y", 40), "composed hi-res rows honor the on and off characters")
check(hires_display.is_text_row(0) == false and hires_display.row_source(0) == "graphics", "full hi-res rows report the graphics source")
hires_bus.write8(0x2000, 0x00)
hires_bus.write8(0x2001, 0x00)
hires_bus.write8(hires_display.hires.byte_address(8, 0, 1), 0x01)
check(hires_display.render_row(1, base_palette, "#", ".")[0] == "#" and hires_display.render_row(0, base_palette, "#", ".")[0] == ".", "composed row one samples scanline eight")
hires_bus.write8(hires_display.hires.byte_address(16, 0, 1), 0x01)
check(hires_display.render_row(2, base_palette, "#", ".")[0] == "#" and hires_display.render_row(3, base_palette, "#", ".")[0] == ".", "composed row two samples scanline sixteen")
hires_bus.write8(hires_display.hires.byte_address(152, 0, 1), 0x01)
check(hires_display.render_row(19, base_palette, "#", ".")[0] == "#" and hires_display.render_row(18, base_palette, "#", ".")[0] == ".", "composed row nineteen samples scanline one hundred fifty-two")
hires_bus.write8(0x2000, 0x7F)
check(hires_display.render_row(0, base_palette, "#", ".")[0] == "#", "composed hi-res rows read live page overwrites")
let scanline_bus = apple2bus.Apple2Bus()
let scanline_display = new_display(scanline_bus)
graphics_hires(scanline_bus)
var scanline_row = 0
while scanline_row < 24:
    scanline_bus.write8(scanline_display.hires.byte_address(scanline_row * 8, 0, 1), 0x01)
    scanline_row = scanline_row + 1
let scanline_frame = scanline_display.render_lines(apple2_display.default_palette(), "#", ".")
var scanlines_match = true
scanline_row = 0
while scanline_row < 24:
    if scanline_frame[scanline_row][0] != "#":
        scanlines_match = false
    scanline_row = scanline_row + 1
check(scanlines_match, "every composed hi-res row samples its own scanline")

let hires_mixed_bus = apple2bus.Apple2Bus()
let hires_mixed = new_display(hires_mixed_bus)
graphics_hires(hires_mixed_bus)
mixed_on(hires_mixed_bus)
hires_mixed_bus.write8(0x2000, 0x01)
hires_mixed_bus.write8(hires_mixed.hires.byte_address(8, 0, 1), 0x01)
hires_mixed_bus.write8(hires_mixed.text.cell_address(20, 0, 1), 0xC7)
hires_mixed_bus.write8(hires_mixed.text.cell_address(23, 0, 1), 0xC8)
check(hires_mixed.snapshot() == [1, "hires", true], "the mixed flag composes with the hi-res mode")
check(hires_mixed.render_row(0, base_palette, "#", ".")[0] == "#" and hires_mixed.render_row(1, base_palette, "#", ".")[0] == "#", "mixed hi-res graphics rows sample the first two scanline groups")
check(hires_mixed.render_row(19, base_palette, "#", ".")[0] == ".", "mixed hi-res graphics rows stop before the text window")
check(len(hires_mixed.render_row(20, base_palette, "#", ".")) == 40 and hires_mixed.render_row(20, base_palette, "#", ".")[0] == "G", "mixed hi-res bottom rows use the forty-column text window")
check(hires_mixed.render_row(23, base_palette, "#", ".")[0] == "H", "mixed hi-res bottom rows read the text page")
page2(hires_mixed_bus)
hires_mixed_bus.write8(0x4000, 0x01)
check(hires_mixed.render_row(0, base_palette, "#", ".")[0] == "#", "mixed hi-res graphics rows follow the page switch to $4000")
hires_mixed_bus.write8(hires_mixed.text.cell_address(20, 0, 2), 0xC9)
check(hires_mixed.render_row(20, base_palette, "#", ".")[0] == "I", "mixed hi-res text rows follow the page switch to $0800")
page1(hires_mixed_bus)
check(hires_mixed.render_row(20, base_palette, "#", ".")[0] == "G", "returning to page one restores the mixed hi-res text window")

let width_bus = apple2bus.Apple2Bus()
let width_display = new_display(width_bus)
lores_on(width_bus)
let lores_frame = width_display.render_lines()
check(len(lores_frame) == 24, "render_lines returns twenty-four composed rows")
var widths_match = true
var width_index = 0
while width_index < 24:
    if len(lores_frame[width_index]) != 80:
        widths_match = false
    width_index = width_index + 1
check(widths_match, "composed lo-res rows are all eighty characters wide")
hires_on(width_bus)
let hires_frame = width_display.render_lines()
widths_match = true
width_index = 0
while width_index < 24:
    if len(hires_frame[width_index]) != 40:
        widths_match = false
    width_index = width_index + 1
check(widths_match, "composed hi-res rows are all forty characters wide")
text_on(width_bus)
let text_frame = width_display.render_lines()
widths_match = true
width_index = 0
while width_index < 24:
    if len(text_frame[width_index]) != 40:
        widths_match = false
    width_index = width_index + 1
check(widths_match, "composed text rows are all forty characters wide")
graphics_lores(width_bus)
mixed_on(width_bus)
let mixed_frame = width_display.render_lines()
check(len(mixed_frame[19]) == 80 and len(mixed_frame[20]) == 40 and len(mixed_frame[23]) == 40, "a mixed frame is ragged across the text window boundary")
mixed_off(width_bus)
let joined = width_display.render()
check(newlines_in(joined) == 23 and len(joined) == 24 * 80 + 23 and slice(joined, 0, 80) == lores_frame[0], "render newline-joins the composed rows")
check(width_display.render_default() == join(width_display.render_lines(apple2_display.default_palette(), "#", "."), "\n"), "render_default matches the default-palette rows")

let invalid_bus = apple2bus.Apple2Bus()
let invalid_display = new_display(invalid_bus)
check(rejects_row(invalid_display, -1) and rejects_row(invalid_display, 24) and rejects_row(invalid_display, 1.5) and rejects_row(invalid_display, "0"), "row classification rejects invalid rows")
check(rejects_row_source(invalid_display, -1) and rejects_row_source(invalid_display, 24) and rejects_row_source(invalid_display, 1.5) and rejects_row_source(invalid_display, "0"), "row source lookup rejects invalid rows")
check(rejects_row_source(invalid_display, 0) == false and rejects_row_source(invalid_display, 23) == false, "rows zero and twenty-three are valid composed rows")
check(rejects_render_row(invalid_display, -1, palette, "#", ".") and rejects_render_row(invalid_display, 24, palette, "#", ".") and rejects_render_row(invalid_display, 1.5, palette, "#", "."), "text-mode row rendering rejects invalid rows")
lores_on(invalid_bus)
check(rejects_render_row(invalid_display, -1, palette, "#", ".") and rejects_render_row(invalid_display, 24, palette, "#", ".") and rejects_render_row(invalid_display, 1.5, palette, "#", "."), "lo-res row rendering rejects invalid rows")
hires_on(invalid_bus)
check(rejects_render_row(invalid_display, -1, palette, "#", ".") and rejects_render_row(invalid_display, 24, palette, "#", ".") and rejects_render_row(invalid_display, 1.5, palette, "#", "."), "hi-res row rendering rejects invalid rows")
mixed_on(invalid_bus)
check(rejects_row_source(invalid_display, 24) and rejects_render_row(invalid_display, 24, palette, "#", ".") and rejects_render_row(invalid_display, 23.5, palette, "#", "."), "mixed-mode rendering rejects invalid rows in both windows")

let palette_bus = apple2bus.Apple2Bus()
let palette_display = new_display(palette_bus)
lores_on(palette_bus)
check(rejects_palette(palette_display, "0123456789ABCDEF") and rejects_palette(palette_display, short_palette) and rejects_palette(palette_display, long_palette), "composed lo-res rows reject non-arrays and palettes without sixteen entries")
check(rejects_lines_palette(palette_display, short_palette) and rejects_render_palette(palette_display, "0123456789ABCDEF"), "composed frames reject invalid palettes through the lo-res view")
mixed_on(palette_bus)
check(rejects_palette(palette_display, short_palette) and rejects_lines_palette(palette_display, long_palette), "mixed frames reject invalid palettes on the graphics rows")
check(palette_display.render_lines() == palette_display.render_lines(apple2_display.default_palette(), "#", "."), "render_lines defaults to the default palette and characters")
check(palette_display.render() == join(palette_display.render_lines(apple2_display.default_palette(), "#", "."), "\n"), "render defaults to the default palette and characters")
palette_bus.write8(0x0400, 0x12)
check(slice(palette_display.render_default(), 0, 2) == "12" and palette_display.render_default() == palette_display.render(), "render_default composes with the default palette")
hires_on(palette_bus)
palette_bus.write8(0x2000, 0x01)
check(slice(palette_display.render_default(), 0, 1) == "#" and slice(palette_display.render_default(), 1, 2) == ".", "render_default composes hi-res cells with the default characters")
palette_display.render_default()
check(apple2_display.DEFAULT_PALETTE[0] == "0" and apple2_display.default_palette() == apple2_display.DEFAULT_PALETTE, "composing a default frame leaves the module palette untouched")

let consistent_bus = apple2bus.Apple2Bus()
let consistent_display = new_display(consistent_bus)
lores_on(consistent_bus)
consistent_bus.write8(0x0400, 0x12)
let lo_frame = consistent_display.render_lines(apple2_display.default_palette(), "#", ".")
var rows_match = true
var consistent_index = 0
while consistent_index < 24:
    if lo_frame[consistent_index] != consistent_display.render_row(consistent_index, apple2_display.default_palette(), "#", "."):
        rows_match = false
    consistent_index = consistent_index + 1
check(rows_match, "every composed lo-res frame row matches the single-row projection")
hires_on(consistent_bus)
consistent_bus.write8(0x2000, 0x01)
let hi_frame = consistent_display.render_lines(apple2_display.default_palette(), "#", ".")
rows_match = true
consistent_index = 0
while consistent_index < 24:
    if hi_frame[consistent_index] != consistent_display.render_row(consistent_index, apple2_display.default_palette(), "#", "."):
        rows_match = false
    consistent_index = consistent_index + 1
check(rows_match, "every composed hi-res frame row matches the single-row projection")
text_on(consistent_bus)
consistent_bus.write8(0x0400, 0xC1)
let tx_frame = consistent_display.render_lines(apple2_display.default_palette(), "#", ".")
rows_match = true
consistent_index = 0
while consistent_index < 24:
    if tx_frame[consistent_index] != consistent_display.render_row(consistent_index, apple2_display.default_palette(), "#", ".") or tx_frame[consistent_index] != consistent_display.text_lines(false)[consistent_index]:
        rows_match = false
    consistent_index = consistent_index + 1
check(rows_match, "every composed text frame row matches the text page line")
graphics_lores(consistent_bus)
mixed_on(consistent_bus)
let mx_frame = consistent_display.render_lines(apple2_display.default_palette(), "#", ".")
rows_match = true
consistent_index = 0
while consistent_index < 24:
    if mx_frame[consistent_index] != consistent_display.render_row(consistent_index, apple2_display.default_palette(), "#", "."):
        rows_match = false
    consistent_index = consistent_index + 1
check(rows_match, "every composed mixed frame row matches the single-row projection")
check(consistent_display.render(apple2_display.default_palette(), "#", ".") == join(mx_frame, "\n") and consistent_display.render_default() == join(consistent_display.render_lines(apple2_display.default_palette(), "#", "."), "\n"), "the joined frame matches the composed rows")
check(consistent_display.render_row(0, palette, "X", "y") == consistent_display.lores.render_row(1, 0, palette) and consistent_display.render_row(20, palette, "X", "y") == consistent_display.text_lines(false)[20], "a caller palette reaches the graphics rows and is ignored by the text window")

let live_bus = apple2bus.Apple2Bus()
let live_display = new_display(live_bus)
check(live_display.render_row(0, apple2_display.default_palette(), "#", ".") == " " * 40, "a new display composes the blank bus")
live_bus.write8(0x0400, 0xC5)
check(slice(live_display.render_row(0, apple2_display.default_palette(), "#", "."), 0, 1) == "E", "text composition sees a later page write")
lores_on(live_bus)
check(slice(live_display.render_row(0, apple2_display.default_palette(), "#", "."), 0, 2) == "C5", "lo-res composition sees the same later page write")
hires_on(live_bus)
check(live_display.render_row(0, apple2_display.default_palette(), "#", ".")[0] == ".", "hi-res composition ignores the text and lo-res page")
live_bus.write8(0x2000, 0x01)
check(live_display.render_row(0, apple2_display.default_palette(), "#", ".")[0] == "#", "hi-res composition sees a later page write")
live_bus.write8(0xC056, 0x00)
lores_on(live_bus)
check(live_display.mode() == "lores" and slice(live_display.render_default(), 0, 2) == "C5", "composition follows a later soft switch write")
text_on(live_bus)
check(live_display.mode() == "text" and slice(live_display.render_default(), 0, 1) == "E", "composition returns to the text screen after a later switch write")

let stable_bus = apple2bus.Apple2Bus()
let stable_display = new_display(stable_bus)
stable_bus.write8(0x0400, 0x12)
stable_bus.write8(0x2000, 0x01)
stable_bus.write8(0xC051, 0x00)
stable_bus.write8(0xC055, 0x00)
stable_bus.write8(0xC030, 0x00)
stable_bus.write8(0xC300, 0x00)
stable_bus.write8(0xC080, ord("U"))
stable_bus.keyboard_input("K")
let ram_before = slice(stable_bus.ram, 0, len(stable_bus.ram))
let events_before = slice(stable_bus.events, 0, len(stable_bus.events))
let video_events_before = slice(stable_bus.video_events, 0, len(stable_bus.video_events))
let switches_before = slice(stable_bus.video_switches, 0, len(stable_bus.video_switches))
let switch_values_before = slice(stable_bus.video_values, 0, len(stable_bus.video_values))
let video_state_before = stable_bus.video_snapshot()
let mode_before = stable_bus.video_mode()
let page_before = stable_bus.video_page()
let keyboard_queue_before = slice(stable_bus.keyboard_queue, 0, len(stable_bus.keyboard_queue))
let keyboard_latch_before = stable_bus.keyboard_latch
let keyboard_strobe_before = stable_bus.keyboard_strobe
let keyboard_valid_before = stable_bus.keyboard_latch_valid
let language_before = stable_bus.language_card_state()
let speaker_on_before = stable_bus.speaker_on
let speaker_toggles_before = stable_bus.speaker_toggles
let uart_rx_before = slice(stable_bus.uart.rx, 0, len(stable_bus.uart.rx))
let uart_rx_head_before = stable_bus.uart.rx_head
let uart_tx_before = slice(stable_bus.uart.tx, 0, len(stable_bus.uart.tx))
let uart_rendered_before = stable_bus.uart.tx_rendered
let uart_text_before = stable_bus.uart.tx_str
stable_display.snapshot()
stable_display.row_sources()
stable_display.text_lines(false)
stable_display.render_row(0, apple2_display.default_palette(), "#", ".")
stable_display.render_lines()
stable_display.render()
stable_display.render_default()
check(stable_bus.ram == ram_before and stable_bus.events == events_before and stable_bus.video_events == video_events_before and stable_bus.video_switches == switches_before and stable_bus.video_values == switch_values_before and stable_bus.video_snapshot() == video_state_before and stable_bus.video_mode() == mode_before and stable_bus.video_page() == page_before and stable_bus.keyboard_queue == keyboard_queue_before and stable_bus.keyboard_latch == keyboard_latch_before and stable_bus.keyboard_strobe == keyboard_strobe_before and stable_bus.keyboard_latch_valid == keyboard_valid_before and stable_bus.language_card_state() == language_before and stable_bus.speaker_on == speaker_on_before and stable_bus.speaker_toggles == speaker_toggles_before and stable_bus.uart.rx == uart_rx_before and stable_bus.uart.rx_head == uart_rx_head_before and stable_bus.uart.tx == uart_tx_before and stable_bus.uart.tx_rendered == uart_rendered_before and stable_bus.uart.tx_str == uart_text_before, "composing a frame preserves RAM, events, switches, latch, language card, speaker, and UART state")

let mode_bus = apple2bus.Apple2Bus()
let mode_display = new_display(mode_bus)
var modes_clean = true
var mode_index = 0
while mode_index < 4:
    if mode_index == 0:
        text_on(mode_bus)
    elif mode_index == 1:
        lores_on(mode_bus)
    elif mode_index == 2:
        hires_on(mode_bus)
    else:
        mixed_on(mode_bus)
    let checksum = ram_checksum(mode_bus)
    let video_events_count = len(mode_bus.video_events)
    let switches_state = slice(mode_bus.video_switches, 0, len(mode_bus.video_switches))
    let values_state = slice(mode_bus.video_values, 0, len(mode_bus.video_values))
    let snapshot_state = mode_bus.video_snapshot()
    let events_count = len(mode_bus.events)
    mode_display.render_row(0, apple2_display.default_palette(), "#", ".")
    mode_display.render_lines()
    mode_display.render()
    mode_display.render_default()
    if ram_checksum(mode_bus) != checksum or len(mode_bus.video_events) != video_events_count or slice(mode_bus.video_switches, 0, len(mode_bus.video_switches)) != switches_state or slice(mode_bus.video_values, 0, len(mode_bus.video_values)) != values_state or mode_bus.video_snapshot() != snapshot_state or len(mode_bus.events) != events_count:
        modes_clean = false
    mode_index = mode_index + 1
check(modes_clean, "composing a frame in every mode leaves bus memory, events, and soft switches unchanged")

let shared_bus = apple2bus.Apple2Bus()
let first_display = new_display(shared_bus)
let second_display = new_display(shared_bus)
shared_bus.write8(0x0400, 0xC4)
check(first_display.render_row(0, apple2_display.default_palette(), "#", ".") == second_display.render_row(0, apple2_display.default_palette(), "#", "."), "two displays over one bus compose the same text row")
check(first_display.snapshot() == second_display.snapshot() and first_display.bus == second_display.bus, "two displays over one bus share the same video state")
lores_on(shared_bus)
shared_bus.write8(0x0400, 0x12)
check(first_display.render_default() == second_display.render_default(), "two displays over one bus compose the same lo-res frame")
hires_on(shared_bus)
shared_bus.write8(0x2000, 0x01)
check(first_display.render_row(0, apple2_display.default_palette(), "#", ".") == second_display.render_row(0, apple2_display.default_palette(), "#", "."), "two displays over one bus follow a shared mode switch")
page2(shared_bus)
shared_bus.write8(0x4000, 0x01)
shared_bus.write8(first_display.text.cell_address(20, 0, 2), 0xC9)
shared_bus.write8(first_display.text.cell_address(23, 0, 2), 0xC8)
check(first_display.render_row(0, apple2_display.default_palette(), "#", ".")[0] == "#" and first_display.snapshot() == [2, "hires", false] and second_display.render_row(0, apple2_display.default_palette(), "#", ".")[0] == "#", "two displays over one bus share a page switch and live pages")
check(first_display.render_default() == second_display.render_default() and len(first_display.render_default()) == 24 * 40 + 23, "the shared bus yields identical default frames for both displays")
mixed_on(shared_bus)
check(first_display.render_default() == second_display.render_default() and first_display.render_row(20, apple2_display.default_palette(), "#", ".")[0] == "I" and first_display.render_row(23, apple2_display.default_palette(), "#", ".")[0] == "H", "both displays compose the same mixed frame")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
