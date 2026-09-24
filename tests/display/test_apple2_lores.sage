import bus.apple2bus
import sageapple.apple2_lores
import sageapple.apple2_machine

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc rejects_page(view, page):
    var rejected = false
    try:
        view.page_base(page)
    catch e:
        rejected = true
    return rejected

proc rejects_address(view, row, column, page):
    var rejected = false
    try:
        view.byte_address(row, column, page)
    catch e:
        rejected = true
    return rejected

proc rejects_color(view, x, y, page):
    var rejected = false
    try:
        view.color(x, y, page)
    catch e:
        rejected = true
    return rejected

proc rejects_palette(view, palette):
    var rejected = false
    try:
        view.render_row(1, 0, palette)
    catch e:
        rejected = true
    return rejected

let bus = apple2bus.Apple2Bus()
let view = apple2_lores.Apple2LoresPage(bus)
check(view.bus == bus, "lo-res view stores the existing bus")
check(view.page_base(1) == 0x0400 and view.page_base(2) == 0x0800, "lo-res page bases are $0400 and $0800")
check(rejects_page(view, 0) and rejects_page(view, 3) and rejects_page(view, 1.5) and rejects_page(view, "1"), "lo-res page validation rejects invalid values")
check(view.byte_address(0, 0, 1) == 0x0400 and view.byte_address(0, 39, 1) == 0x0427, "row zero addresses are $0400..$0427")
check(view.byte_address(1, 0, 1) == 0x0480 and view.byte_address(1, 39, 1) == 0x04A7, "row one addresses are $0480..$04A7")
check(view.byte_address(8, 0, 1) == 0x0428 and view.byte_address(8, 39, 1) == 0x044F, "row eight uses the second text-row block")
check(view.byte_address(16, 0, 1) == 0x0450 and view.byte_address(16, 39, 1) == 0x0477, "row sixteen uses the third text-row block")
check(view.byte_address(23, 0, 1) == 0x07D0 and view.byte_address(23, 39, 1) == 0x07F7, "row twenty-three ends before the page boundary")
check(rejects_address(view, -1, 0, 1) and rejects_address(view, 24, 0, 1) and rejects_address(view, 1.5, 0, 1) and rejects_address(view, "0", 0, 1), "lo-res row validation rejects invalid values")
check(rejects_address(view, 0, -1, 1) and rejects_address(view, 0, 40, 1) and rejects_address(view, 0, 1.5, 1) and rejects_address(view, 0, "0", 1), "lo-res byte-column validation rejects invalid values")
check(rejects_color(view, -1, 0, 1) and rejects_color(view, 80, 0, 1) and rejects_color(view, 1.5, 0, 1) and rejects_color(view, "0", 0, 1), "lo-res x validation rejects invalid values")
check(rejects_color(view, 0, -1, 1) and rejects_color(view, 0, 24, 1) and rejects_color(view, 0, 1.5, 1) and rejects_color(view, 0, "0", 1), "lo-res y validation rejects invalid values")
check(rejects_color(view, 0, 0, 0) and rejects_color(view, 0, 0, 3) and rejects_color(view, 0, 0, 1.5) and rejects_color(view, 0, 0, "1"), "color reads reject invalid pages")

bus.write8(0x0400, 0xA5)
check(view.color(0, 0, 1) == 10 and view.color(1, 0, 1) == 5, "even x reads the high nibble and odd x reads the low nibble")

let palette = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]
let packed_colors = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
let color_bus = apple2bus.Apple2Bus()
let color_view = apple2_lores.Apple2LoresPage(color_bus)
var color_index = 0
while color_index < 16:
    color_bus.write8(0x0400 + color_index, packed_colors[color_index])
    color_index = color_index + 1
let color_row = color_view.render_row(1, 0, palette)
check(slice(color_row, 0, 32) == "ABCDEFGHIJKLMNOPABCDEFGHIJKLMNOP" and color_row[32] == "A", "the projection returns all sixteen lo-res colors")

let isolation_bus = apple2bus.Apple2Bus()
let isolation_view = apple2_lores.Apple2LoresPage(isolation_bus)
isolation_bus.write8(0x0400, 0x12)
isolation_bus.write8(0x0800, 0x34)
check(isolation_view.color(0, 0, 1) == 1 and isolation_view.color(1, 0, 1) == 2 and isolation_view.color(0, 0, 2) == 3 and isolation_view.color(1, 0, 2) == 4, "lo-res pages remain isolated")

let hole_bus = apple2bus.Apple2Bus()
let hole_view = apple2_lores.Apple2LoresPage(hole_bus)
hole_bus.write8(0x0478, 0x7F)
hole_bus.write8(0x0B78, 0x7F)
check(hole_view.color(78, 0, 1) == 0 and hole_view.color(79, 0, 1) == 0 and hole_view.color(78, 8, 2) == 0 and hole_view.color(79, 8, 2) == 0, "the $0478 and $0B78 holes are not projected")

let live_bus = apple2bus.Apple2Bus()
let live_view = apple2_lores.Apple2LoresPage(live_bus)
check(not live_view.color(0, 0, 1), "a new lo-res view reads current bus contents")
live_bus.write8(0x0400, 0xA7)
check(live_view.color(0, 0, 1) == 10 and live_view.color(1, 0, 1) == 7 and slice(live_view.render_row(1, 0, palette), 0, 2) == "KH", "lo-res rendering reads live bus overwrites")

let lines_bus = apple2bus.Apple2Bus()
let lines_view = apple2_lores.Apple2LoresPage(lines_bus)
let lines = lines_view.render_lines(1, palette)
var dimensions_match = len(lines) == 24
var line_index = 0
while line_index < 24:
    if len(lines[line_index]) != 80:
        dimensions_match = false
    line_index = line_index + 1
check(dimensions_match, "lo-res lines have 24 rows of 80 horizontal cells")
check(color_row == "ABCDEFGHIJKLMNOPABCDEFGHIJKLMNOPAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "rendering substitutes the exact sixteen-color palette")

let short_palette = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"]
let long_palette = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q"]
check(rejects_palette(view, "ABCDEFGHIJKLMNOP") and rejects_palette(view, short_palette) and rejects_palette(view, long_palette), "lo-res rendering rejects non-arrays and palettes without 16 entries")

let machine = apple2_machine.Apple2Machine()
let machine_palette = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"]
machine.bus.write8(0x0400, 0x12)
check(machine.lores.bus == machine.bus, "machine exposes the shared lo-res view")
check(machine.lores_color(0, 0, 1) == 1 and machine.lores_color(1, 0, 1) == 2, "machine forwards lo-res color reads")
let machine_rendered = machine.render_lores(1, machine_palette)
check(len(machine_rendered) == 1943 and slice(machine_rendered, 0, 2) == "12" and slice(machine_rendered, 80, 81) == "\n", "machine newline-joins lo-res rendering")

let stable_bus = apple2bus.Apple2Bus()
let stable_view = apple2_lores.Apple2LoresPage(stable_bus)
stable_bus.write8(0x0400, 0x21)
stable_bus.write8(0xC050, 0x12)
stable_bus.write8(0xC300, 0x00)
stable_bus.write8(0xC030, 0x00)
stable_bus.write8(0xC080, ord("U"))
stable_bus.keyboard_input("K")
let ram_before = slice(stable_bus.ram, 0, len(stable_bus.ram))
let events_before = slice(stable_bus.events, 0, len(stable_bus.events))
let video_events_before = slice(stable_bus.video_events, 0, len(stable_bus.video_events))
let switches_before = slice(stable_bus.video_switches, 0, len(stable_bus.video_switches))
let switch_values_before = slice(stable_bus.video_values, 0, len(stable_bus.video_values))
let video_state_before = stable_bus.video_snapshot()
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
stable_view.render_lines(1, machine_palette)
check(stable_bus.ram == ram_before and stable_bus.events == events_before and stable_bus.video_events == video_events_before and stable_bus.video_switches == switches_before and stable_bus.video_values == switch_values_before and stable_bus.video_snapshot() == video_state_before and stable_bus.keyboard_queue == keyboard_queue_before and stable_bus.keyboard_latch == keyboard_latch_before and stable_bus.keyboard_strobe == keyboard_strobe_before and stable_bus.keyboard_latch_valid == keyboard_valid_before and stable_bus.language_card_state() == language_before and stable_bus.speaker_on == speaker_on_before and stable_bus.speaker_toggles == speaker_toggles_before and stable_bus.uart.rx == uart_rx_before and stable_bus.uart.rx_head == uart_rx_head_before and stable_bus.uart.tx == uart_tx_before and stable_bus.uart.tx_rendered == uart_rendered_before and stable_bus.uart.tx_str == uart_text_before, "lo-res rendering preserves RAM, events, switches, latch, language card, speaker, and UART state")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
