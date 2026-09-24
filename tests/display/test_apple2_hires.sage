import bus.apple2bus
import sageapple.apple2_hires
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

proc rejects_pixel(view, x, y, page):
    var rejected = false
    try:
        view.pixel(x, y, page)
    catch e:
        rejected = true
    return rejected

proc contains(hay, needle):
    let hn = len(hay)
    let nn = len(needle)
    if nn == 0:
        return true
    if nn > hn:
        return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

let bus = apple2bus.Apple2Bus()
let view = apple2_hires.Apple2HiresPage(bus)
check(view.bus == bus, "HGR view stores the existing bus")
check(view.page_base(1) == 0x2000 and view.page_base(2) == 0x4000, "HGR page bases are $2000 and $4000")
check(rejects_page(view, 0) and rejects_page(view, 3) and rejects_page(view, 1.5) and rejects_page(view, "1"), "HGR page validation rejects invalid values")
check(view.byte_address(0, 0, 1) == 0x2000 and view.byte_address(0, 39, 1) == 0x2027, "row zero addresses are $2000..$2027")
check(view.byte_address(1, 0, 1) == 0x2080 and view.byte_address(1, 39, 1) == 0x20A7, "row one addresses begin at $2080")
check(view.byte_address(63, 0, 1) == 0x3F80 and view.byte_address(63, 39, 1) == 0x3FA7, "row sixty-three reaches the first block end")
check(view.byte_address(64, 0, 1) == 0x2028 and view.byte_address(64, 39, 1) == 0x204F, "row sixty-four uses the second line block")
check(view.byte_address(128, 0, 1) == 0x2050 and view.byte_address(128, 39, 1) == 0x2077, "row one hundred twenty-eight uses the third line block")
check(view.byte_address(191, 0, 1) == 0x3FD0 and view.byte_address(191, 39, 1) == 0x3FF7, "row one hundred ninety-one ends before the page boundary")
check(view.byte_address(0, 0, 2) == 0x4000 and view.byte_address(191, 39, 2) == 0x5FF7, "page two uses the $4000 base")
check(rejects_address(view, -1, 0, 1) and rejects_address(view, 192, 0, 1) and rejects_address(view, 1.5, 0, 1), "HGR row validation rejects invalid values")
check(rejects_address(view, 0, -1, 1) and rejects_address(view, 0, 40, 1) and rejects_address(view, 0, 1.5, 1), "HGR byte-column validation rejects invalid values")
check(rejects_address(view, 0, 0, 0) and rejects_address(view, 0, 0, 3) and rejects_address(view, 0, 0, 1.5), "byte addresses reject invalid pages")
check(rejects_pixel(view, -1, 0, 1) and rejects_pixel(view, 280, 0, 1) and rejects_pixel(view, 1.5, 0, 1), "HGR x validation rejects invalid values")
check(rejects_pixel(view, 0, -1, 1) and rejects_pixel(view, 0, 192, 1) and rejects_pixel(view, 0, 1.5, 1), "HGR y validation rejects invalid values")
check(rejects_pixel(view, 0, 0, 0) and rejects_pixel(view, 0, 0, 3) and rejects_pixel(view, 0, 0, 1.5), "pixel reads reject invalid pages")

let low_bus = apple2bus.Apple2Bus()
let low_view = apple2_hires.Apple2HiresPage(low_bus)
low_bus.write8(0x2000, 0x7F)
check(low_view.pixel(0, 0, 1) and low_view.pixel(6, 0, 1) and not low_view.pixel(7, 0, 1), "low seven bits drive HGR pixels")

let order_bus = apple2bus.Apple2Bus()
let order_view = apple2_hires.Apple2HiresPage(order_bus)
order_bus.write8(0x2000, 0x01)
order_bus.write8(0x2001, 0x02)
let order_row = order_view.render_row(1, 0, "#", ".")
check(slice(order_row, 0, 10) == "#........#", "bit zero is the leftmost HGR pixel")

let high_bus = apple2bus.Apple2Bus()
let high_view = apple2_hires.Apple2HiresPage(high_bus)
high_bus.write8(0x2000, 0x80)
let high_row = high_view.render_row(1, 0, "#", ".")
check(not high_view.pixel(0, 0, 1) and not high_view.pixel(7, 0, 1) and not contains(high_row, "#"), "HGR bit seven is ignored")

let hole_bus = apple2bus.Apple2Bus()
let hole_view = apple2_hires.Apple2HiresPage(hole_bus)
hole_bus.write8(0x2078, 0x7F)
let hole_lines = hole_view.render_lines(1, "#", ".")
check(not hole_view.pixel(0, 0, 1) and not hole_view.pixel(0, 1, 1) and not contains(join(hole_lines, "\n"), "#"), "the $2078 hole is not projected as a pixel")

let isolation_bus = apple2bus.Apple2Bus()
let isolation_view = apple2_hires.Apple2HiresPage(isolation_bus)
isolation_bus.write8(0x2000, 0x01)
isolation_bus.write8(0x4000, 0x02)
check(isolation_view.pixel(0, 0, 1) and not isolation_view.pixel(1, 0, 1) and not isolation_view.pixel(0, 0, 2) and isolation_view.pixel(1, 0, 2), "HGR pages remain isolated")

let live_bus = apple2bus.Apple2Bus()
let live_view = apple2_hires.Apple2HiresPage(live_bus)
check(not live_view.pixel(0, 0, 1), "a new HGR view reads current bus contents")
live_bus.write8(0x2000, 0x01)
check(live_view.pixel(0, 0, 1) and live_view.render_row(1, 0, "#", ".")[0] == "#", "HGR rendering reads live bus overwrites")

let lines_bus = apple2bus.Apple2Bus()
let lines_view = apple2_hires.Apple2HiresPage(lines_bus)
lines_bus.write8(0x2028, 0x01)
let lines = lines_view.render_lines(1, "#", ".")
var line_widths_match = true
var line_index = 0
while line_index < 192:
    if len(lines[line_index]) != 280:
        line_widths_match = false
    line_index = line_index + 1
check(len(lines) == 192 and line_widths_match and lines[0][0] == "." and lines[64][0] == "#" and lines[191][0] == ".", "HGR lines have 192 rows of 280 pixels")

let machine = apple2_machine.Apple2Machine()
machine.bus.write8(0x2000, 0x01)
check(machine.hires.bus == machine.bus, "machine exposes the shared HGR view")
check(machine.hires_pixel(1, 0, 0), "machine forwards HGR pixel reads")
check(machine.video_snapshot() == [true, false, false, false], "machine forwards video snapshots")
check(machine.video_mode() == "text" and machine.video_page() == 1, "machine forwards video mode and page")
machine.bus.write8(0xC055, 0x00)
machine.bus.write8(0xC050, 0x00)
check(machine.video_snapshot() == [false, false, true, false] and machine.video_mode() == "lores" and machine.video_page() == 2, "machine forwards live video state")
let machine_rendered = machine.render_hires(1, "#", ".")
check(len(machine_rendered) == 53951 and slice(machine_rendered, 0, 2) == "#.", "machine newline-joins HGR rendering")

let stable_bus = apple2bus.Apple2Bus()
let stable_view = apple2_hires.Apple2HiresPage(stable_bus)
stable_bus.write8(0x2000, 0x01)
stable_bus.write8(0xC050, 0x12)
stable_bus.write8(0xC030, 0x00)
let event_count = len(stable_bus.events)
let video_event_count = len(stable_bus.video_events)
let language_before = stable_bus.language_card_state()
let speaker_before = stable_bus.speaker_toggles
let video_state_before = stable_bus.video_snapshot()
let video_mode_before = stable_bus.video_mode()
let video_page_before = stable_bus.video_page()
stable_view.render_lines(1, "#", ".")
check(len(stable_bus.events) == event_count and len(stable_bus.video_events) == video_event_count and stable_bus.video_switches[0] and stable_bus.video_values[0] == 0x12 and stable_bus.speaker_toggles == speaker_before and stable_bus.language_card_state() == language_before and stable_bus.video_snapshot() == video_state_before and stable_bus.video_mode() == video_mode_before and stable_bus.video_page() == video_page_before, "HGR rendering does not write the bus or change soft switches")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
