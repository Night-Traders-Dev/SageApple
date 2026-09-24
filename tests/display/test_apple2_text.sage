import bus.apple2bus
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

proc rejects_address(view, row, column, page):
    var rejected = false
    try:
        view.cell_address(row, column, page)
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

let b = apple2bus.Apple2Bus()
let view = apple2_text.Apple2TextPage(b)
check(view.page_base(1) == 0x0400 and view.page_base(2) == 0x0800, "text page bases are $0400 and $0800")
b.write8(0x0400, 0xC1)
b.write8(0x0401, 0x3F)
b.write8(0x0402, 0x41)
b.write8(0x0403, 0x00)
check(view.cell(0, 0, 1) == ["A", "normal"], "normal text masks the high bit")
check(view.cell(0, 1, 1) == ["?", "inverse"], "inverse text decodes its mode")
check(view.cell(0, 2, 1) == ["A", "flash"], "flash text decodes its mode")
check(view.cell(0, 3, 1) == [" ", "inverse"], "code zero maps to a space")
check(view.cell_address(0, 0, 1) == 0x0400, "row zero starts at $0400")
check(view.cell_address(8, 0, 1) == 0x0428, "row eight starts at $0428")
check(view.cell_address(16, 0, 1) == 0x0450, "row sixteen starts at $0450")
check(view.cell_address(23, 0, 1) == 0x07D0, "row twenty-three starts at $07D0")
check(rejects_address(view, -1, 0, 1), "negative rows are rejected")
check(rejects_address(view, 24, 0, 1), "rows past twenty-three are rejected")
check(rejects_address(view, 0, -1, 1), "negative columns are rejected")
check(rejects_address(view, 0, 40, 1), "columns past thirty-nine are rejected")
check(rejects_address(view, 0, 0, 0), "page zero is rejected")
check(rejects_address(view, 0, 0, 3), "page three is rejected")

let hole_bus = apple2bus.Apple2Bus()
let hole_view = apple2_text.Apple2TextPage(hole_bus)
hole_bus.write8(0x0478, 0xC9)
let hole_lines = hole_view.render_lines(1, true)
check(hole_view.cell(0, 39, 1) == [" ", "inverse"] and hole_lines[0] == "" and not contains(join(hole_lines, "\n"), "Y"), "the $0478 hole is not a text cell")

let line_bus = apple2bus.Apple2Bus()
let line_view = apple2_text.Apple2TextPage(line_bus)
line_bus.write8(0x0402, 0xC8)
line_bus.write8(0x0403, 0xC9)
let fixed_lines = line_view.render_lines(1, false)
let trimmed_lines = line_view.render_lines(1, true)
check(len(fixed_lines) == 24, "renderer returns twenty-four lines")
var fixed_width = true
var line_index = 0
while line_index < 24:
    if len(fixed_lines[line_index]) != 40:
        fixed_width = false
    line_index = line_index + 1
check(fixed_width, "fixed lines are forty columns wide")
check(trimmed_lines[0] == "  HI", "trimming preserves leading spaces")
check(trimmed_lines[1] == "", "trimming removes trailing spaces")

let isolation_bus = apple2bus.Apple2Bus()
let isolation_view = apple2_text.Apple2TextPage(isolation_bus)
isolation_bus.write8(0x0400, 0xC1)
isolation_bus.write8(0x0800, 0xC2)
check(isolation_view.render_lines(1, true)[0] == "A", "page one is isolated")
check(isolation_view.render_lines(2, true)[0] == "B", "page two is isolated")
let before_i_o = isolation_view.render_lines(1, true)[0]
isolation_bus.write8(0x2000, 0x7E)
check(isolation_view.render_lines(1, true)[0] == before_i_o, "a $2000 write does not change text")

let ansi_bus = apple2bus.Apple2Bus()
let ansi_view = apple2_text.Apple2TextPage(ansi_bus)
ansi_bus.write8(0x0400, 0x3F)
ansi_bus.write8(0x0401, 0x41)
let ansi_lines = ansi_view.render_ansi(1, true)
check(contains(ansi_lines[0], "\x1b[7m"), "ANSI rendering marks inverse text")
check(contains(ansi_lines[0], "\x1b[5m"), "ANSI rendering marks flash text")
check(contains(ansi_lines[0], "\x1b[27m"), "ANSI rendering resets inverse text")
check(contains(ansi_lines[0], "\x1b[25m"), "ANSI rendering resets flash text")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
