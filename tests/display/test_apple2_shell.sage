import sageapple.apple2_display
import sageapple.apple2_machine
import sageapple.apple2_shell

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

proc count_char(text, ch):
    var total = 0
    var i = 0
    while i < len(text):
        if text[i] == ch:
            total = total + 1
        i = i + 1
    return total

proc crlf_clean(text):
    var i = 0
    while i < len(text):
        if text[i] == "\n" and (i == 0 or text[i - 1] != "\r"):
            return false
        if text[i] == "\r" and (i + 1 >= len(text) or text[i + 1] != "\n"):
            return false
        i = i + 1
    return true

proc hex4(value):
    let digits = "0123456789ABCDEF"
    return "$" + digits[(value >> 12) & 0xF] + digits[(value >> 8) & 0xF] + digits[(value >> 4) & 0xF] + digits[value & 0xF]

proc new_shell():
    return apple2_shell.Apple2Shell(apple2_machine.Apple2Machine())

class StepCounter:
    proc init(self):
        self.budgets = []
        self.keys = []
        self.steps = 2000
        self.booted = false

    proc load_rom(self, image):
        self.booted = true
        return 0

    proc keyboard_input(self, text):
        push(self.keys, text)
        return 0

    proc run(self, steps):
        push(self.budgets, steps)
        return 0

proc boot_shell():
    let shell = new_shell()
    shell.boot()
    shell.drain()
    return shell

proc bus_fingerprint(bus):
    var checksum = 0
    var i = 0
    while i < len(bus.ram):
        checksum = (checksum + bus.ram[i] * (i % 251 + 1)) % 65521
        i = i + 1
    var card_total = 0
    i = 0
    while i < len(bus.language_card_ram):
        card_total = (card_total + bus.language_card_ram[i]) % 65521
        i = i + 1
    var rom_total = 0
    i = 0
    while i < len(bus.rom):
        rom_total = (rom_total + bus.rom[i] * (i % 253 + 1)) % 65521
        i = i + 1
    return [
        checksum,
        card_total,
        rom_total,
        len(bus.events),
        len(bus.video_events),
        bus.video_snapshot(),
        slice(bus.video_switches, 0, 8),
        slice(bus.video_values, 0, 8),
        bus.language_card_state(),
        bus.speaker_on,
        bus.speaker_toggles,
        len(bus.keyboard_queue),
        bus.keyboard_latch,
        bus.keyboard_strobe,
        bus.keyboard_latch_valid,
        len(bus.uart.tx),
        bus.uart.tx_rendered,
        bus.uart.tx_str,
        len(bus.uart.rx),
        bus.uart.rx_head,
    ]

print("== boot and ROM signature ==")
let boot = new_shell()
boot.boot()
let banner = boot.drain()
check(contains(banner, "A2 HOST") and contains(banner, "Apple ][") and endswith(banner, "a2> "), "boot prints a concise A2 host banner and the a2 prompt")
check(boot.machine.booted == true, "the shell boots the machine")
check(boot.machine.serial_text() == "A2\r\nHI\r\n", "boot runs the replacement ROM signature")
check(boot.machine.display_snapshot() == [1, "text", false], "boot starts on text page 1")
check(len(boot.machine.bus.events) == 2 and boot.machine.bus.events[0] == [0x0400, 0xC8] and boot.machine.bus.events[1] == [0x0401, 0xC9], "boot records the ROM high-bit text writes")
check(boot.steps == 2000 and boot.on_char == "#" and boot.off_char == ".", "the shell defaults to a 2000 step budget and dot frame characters")
check(boot.palette == apple2_display.default_palette() and len(boot.palette) == 16, "the shell starts from an independent default palette copy")
boot.boot()
let repeat_banner = boot.drain()
check(repeat_banner == banner, "booting the same shell twice prints the same banner")
check(boot.machine.serial_text() == "A2\r\nHI\r\nA2\r\nHI\r\n" and len(boot.machine.bus.events) == 4, "a second boot appends a second ROM signature")
let fresh = new_shell()
fresh.boot()
let second_banner = fresh.drain()
check(second_banner == banner and fresh.machine.serial_text() == "A2\r\nHI\r\n", "an independent shell boots to the same banner and signature")

print("== frame and screen ==")
let frame = fresh.frame()
check(slice(frame, 0, 2) == "HI" and slice(frame, 41 * 23, 41 * 23 + 2) == "  ", "the frame renders the booted text page")
check(len(frame) == 24 * 40 + 23 * 2, "the frame is 24 rows of 40 columns")
check(count_char(frame, "\n") == 23 and count_char(frame, "\r") == 23 and crlf_clean(frame), "the frame normalizes every newline to CRLF")
check(frame == join(fresh.machine.text.render_lines(1, false), "\r\n"), "the frame equals the text projection joined with CRLF")
check(fresh.screen() == "\x1b[H" + frame, "screen is the home escape followed by the frame")
check(len(fresh.screen()) == 3 + 24 * 40 + 23 * 2 and crlf_clean(fresh.screen()), "screen keeps the frame dimensions and CRLF endings")
check(fresh.drain() == "", "frame and screen do not write to the output buffer")

print("== soft switches ==")
let switches = boot_shell()
let cases = [
    ["text", 0xC051, [1, "text", false]],
    ["gr", 0xC050, [1, "lores", false]],
    ["hgr", 0xC057, [1, "hires", false]],
    ["mix", 0xC053, [1, "hires", true]],
    ["nomix", 0xC052, [1, "hires", false]],
    ["page2", 0xC055, [2, "hires", false]],
    ["page1", 0xC054, [1, "hires", false]],
]
var switch_ok = true
var switch_case = 0
while switch_case < len(cases):
    let entry = cases[switch_case]
    let text_events = len(switches.machine.bus.events)
    let video_events = len(switches.machine.bus.video_events)
    switches.command(entry[0])
    let reply = switches.drain()
    if not contains(reply, "SWITCH " + upper(entry[0]) + " -> " + hex4(entry[1])):
        switch_ok = false
    if not endswith(reply, "a2> "):
        switch_ok = false
    if switches.machine.display_snapshot() != entry[2]:
        switch_ok = false
    if len(switches.machine.bus.video_events) != video_events + 1:
        switch_ok = false
    elif switches.machine.bus.video_events[video_events] != [entry[1], 0x00]:
        switch_ok = false
    if switches.machine.bus.video_state(entry[1] - 0xC050) != true:
        switch_ok = false
    if len(switches.machine.bus.events) != text_events:
        switch_ok = false
    switch_case = switch_case + 1
check(switch_ok, "every soft-switch verb writes one canonical $C050-$C057 event and updates the display state")
check(switches.machine.display_snapshot() == [1, "hires", false], "the switch sequence leaves the display in a known state")

let mixed = boot_shell()
mixed.command("gr")
mixed.command("mix")
check(mixed.machine.display_mixed() == true and mixed.machine.display_row_sources()[0] == "graphics" and mixed.machine.display_row_sources()[19] == "graphics" and mixed.machine.display_row_sources()[20] == "text" and mixed.machine.display_row_sources()[23] == "text", "mix reserves the bottom four rows for the text window")
let mixed_frame = mixed.frame()
check(len(mixed_frame) == 20 * 80 + 4 * 40 + 23 * 2 and crlf_clean(mixed_frame), "the mixed frame is twenty lo-res rows above four text rows")
mixed.command("nomix")
check(mixed.machine.display_mixed() == false and mixed.machine.display_row_sources()[20] == "graphics", "nomix returns the last four rows to graphics")
check(mixed.switch("sideways") == false and contains(mixed.drain(), "?SWITCH SIDEWAYS"), "an unknown switch name is rejected")
check(mixed.machine.display_snapshot() == [1, "lores", false], "a rejected switch leaves the video state untouched")

print("== poke and peek ==")
let memory = boot_shell()
memory.drain()
check(memory.poke("$0400", "$C1") == 0xC1, "poke writes a byte and returns the value")
check(contains(memory.drain(), "POKE $0400 = C1"), "poke reports the address and the value")
check(memory.peek("$0400") == 0xC1, "peek reads the poked byte back")
check(contains(memory.drain(), "PEEK $0400 = C1"), "peek reports the address and the value")
memory.poke("2000", "5A")
check(contains(memory.drain(), "POKE $2000 = 5A") and memory.peek("$2000") == 0x5A, "poke and peek accept a bare hexadecimal address")
memory.poke(0x0300, 0x2B)
check(contains(memory.drain(), "POKE $0300 = 2B") and memory.peek("$0300") == 0x2B, "poke and peek accept plain numbers")
memory.poke("$0401", "C8")
check(len(memory.machine.bus.events) == 5, "poke logs text page and graphics page writes")
check(memory.machine.bus.events[2] == [0x0400, 0xC1] and memory.machine.bus.events[3] == [0x2000, 0x5A] and memory.machine.bus.events[4] == [0x0401, 0xC8], "poked text and graphics writes are logged in order")
memory.drain()
memory.poke("ZZZZ", "$00")
check(contains(memory.drain(), "POKE: address must be 1-4 hex digits"), "poke rejects a non-hexadecimal address")
memory.poke("$12345", "$00")
check(contains(memory.drain(), "POKE: address must be 1-4 hex digits"), "poke rejects an address longer than four digits")
memory.poke(70000, "$00")
check(contains(memory.drain(), "POKE: address must be 1-4 hex digits"), "poke rejects a numeric address outside the bus")
memory.poke("$0400", "GG")
check(contains(memory.drain(), "POKE: value must be 1-4 hex digits"), "poke rejects a non-hexadecimal value")
memory.poke("$0400", "1FF")
check(contains(memory.drain(), "POKE: value must be 1-4 hex digits"), "poke rejects a value above $FF")
memory.peek("nope")
check(contains(memory.drain(), "PEEK: address must be 1-4 hex digits"), "peek rejects a non-hexadecimal address")
memory.peek(70000)
check(contains(memory.drain(), "PEEK: address must be 1-4 hex digits"), "peek rejects a numeric address outside the bus")
check(memory.peek("$0402") == 0x00 and memory.peek("$0400") == 0xC1, "rejected pokes and peeks leave memory unchanged")

print("== type, key, run ==")
let typing = boot_shell()
typing.drain()
check(typing.type_text("SAGEAPPLE") == 9, "type_text reports the number of cells written")
check(typing.peek("$0400") == 0xD3 and typing.peek("$0408") == 0xC5, "type_text writes high-bit characters into row 0")
check(slice(typing.frame(), 0, 9) == "SAGEAPPLE", "the frame shows the typed text")
check(typing.type_text("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFG") == 40, "type_text stops at forty columns")
check(typing.peek("$0400") == 0xC1 and len(typing.frame()) == 24 * 40 + 23 * 2, "the typed frame is still 40 columns wide")
check(typing.type_text("") == 0 and typing.type_text("lowercase") == 9 and slice(typing.frame(), 0, 9) == "LOWERCASE", "type_text uppercases the text it writes")
typing.command("page2")
typing.drain()
typing.type_text("P2")
check(typing.peek("$0800") == 0xD0 and typing.peek("$0801") == 0xB2 and slice(typing.frame(), 0, 2) == "P2", "type_text follows the active display page")
typing.command("page1")
check(slice(typing.frame(), 0, 2) == "LO", "switching back restores the first text page")

let running = boot_shell()
running.drain()
check(running.key("X") == 2000, "key feeds the keyboard and runs the step budget")
check(running.machine.serial_text() == "A2\r\nHI\r\nX", "the ROM echoes the key to the serial bridge")
check(slice(running.frame(), 0, 3) == "HIX", "the key reaches the active text page")
check(running.machine.bus.events[2] == [0x0402, 0xD8], "the keyboard echo records a high-bit text event")
running.steps = 100
check(running.key("Y") == 100 and slice(running.frame(), 0, 3) == "HIY", "key honors the configured step budget and the ROM retypes at $0402")
check(running.run() == 100, "run without a count uses the step budget")
check(running.run(0) == 100, "run with a zero count uses the step budget")
check(running.run(10) == 10, "run honors an explicit step count")
check(running.run(-5) == 0, "run ignores a negative step count")
check(running.machine.serial_text() == "A2\r\nHI\r\nXY", "extra steps leave the ROM signature stable")
check(running.command("key Z") == "" and running.machine.serial_text() == "A2\r\nHI\r\nXYZ", "the key command reaches the keyboard")
check(contains(running.drain(), "KEY 1 -> 100 steps"), "the key command reports the key count and the step budget")
let counter = StepCounter()
let budget = apple2_shell.Apple2Shell(counter)
check(budget.run(2000000) == 1000000 and counter.budgets[0] == 1000000, "run caps the step budget at one million")
check(budget.run(10) == 10 and counter.budgets[1] == 10, "run passes a small budget straight through")
check(budget.run() == 2000 and counter.budgets[2] == 2000, "run without a count uses the configured step budget")
check(budget.key("AB") == 2000 and counter.keys[0] == "AB" and counter.budgets[3] == 2000, "key feeds the keyboard and then runs the step budget")

print("== state is read-only ==")
let read_only = boot_shell()
read_only.state()
read_only.frame()
let before = bus_fingerprint(read_only.machine.bus)
read_only.state()
read_only.frame()
read_only.screen()
read_only.state()
read_only.frame()
let after = bus_fingerprint(read_only.machine.bus)
check(before == after, "state, frame, and screen leave RAM, ROM, events, switches, keyboard, card, speaker, and UART state untouched")
check(read_only.frame() == read_only.frame(), "repeated frames are identical")
check(read_only.screen() == read_only.screen(), "repeated screens are identical")
check(read_only.state() == read_only.state(), "repeated state reports are identical")
check(read_only.drain() == "", "state, frame, and screen keep the output buffer empty")
let state_text = read_only.state()
check(contains(state_text, "page 1  mode text  mixed off"), "state reports the page, mode, and mixed flag")
check(contains(state_text, "video text on  mixed off  page2 off  hires off"), "state reports the canonical video snapshot")
check(contains(state_text, "card bank 2  read off  write on  prewrite off"), "state reports the language card")
check(contains(state_text, "events 2  video-events 0"), "state reports the event and video-event counts")
check(contains(state_text, "speaker off  toggles 0"), "state reports the speaker toggle count")
check(contains(state_text, "serial \"A2\\r\\nHI\\r\\n\""), "state escapes the serial tail")

print("== command grammar ==")
let grammar = boot_shell()
grammar.drain()
check(grammar.command("") == "" and grammar.drain() == "\r\na2> ", "an empty line re-emits the prompt")
check(grammar.command("    ") == "" and grammar.drain() == "\r\na2> ", "a blank line re-emits the prompt")
check(grammar.command("wibble") == "" and grammar.drain() == "?UNKNOWN WIBBLE\r\na2> ", "an unknown verb reports ?UNKNOWN and the prompt")
check(grammar.command("EXIT") == "exit" and grammar.drain() == "BYE\r\n", "exit returns the exit status and says goodbye")
check(grammar.command("quit") == "exit" and grammar.drain() == "BYE\r\n", "quit returns the exit status")
grammar.command("help")
let help_text = grammar.drain()
check(contains(help_text, "help state frame screen serial events clear exit"), "help lists the inspection commands")
check(contains(help_text, "text gr hgr mix nomix page1 page2"), "help lists the soft-switch verbs")
check(contains(help_text, "poke $0400 $C8") and contains(help_text, "peek $0400"), "help lists the memory verbs")
check(contains(help_text, "type HELLO") and contains(help_text, "key H") and contains(help_text, "run 2000"), "help lists the text and CPU verbs")
check(contains(help_text, "$C050-$C057") and endswith(help_text, "a2> "), "help explains the soft-switch window and leaves the prompt")
check(grammar.command("HELP") == "" and grammar.drain() == help_text, "verbs are case insensitive")
grammar.command("state")
let lower_state = grammar.drain()
grammar.command("STATE")
check(grammar.drain() == lower_state, "state is identical whatever the case of the verb")
let verbs = ["help", "state", "frame", "screen", "serial", "events", "events 2", "clear", "text", "gr", "hgr", "mix", "nomix", "page1", "page2", "run", "run 5", "type A", "key A", "poke $0300 $00", "peek $0300", "nope"]
var prompt_ok = true
var verb_index = 0
while verb_index < len(verbs):
    grammar.drain()
    grammar.command(verbs[verb_index])
    if not endswith(grammar.drain(), "a2> "):
        prompt_ok = false
    verb_index = verb_index + 1
check(prompt_ok, "every command leaves the a2 prompt on the output")
grammar.command("poke")
check(contains(grammar.drain(), "POKE: usage poke $0400 $C8"), "poke without arguments prints the usage line")
grammar.command("peek")
check(contains(grammar.drain(), "PEEK: usage peek $0400"), "peek without arguments prints the usage line")
grammar.command("run many")
check(contains(grammar.drain(), "RUN: steps must be a decimal number"), "run rejects a non-decimal step count")
grammar.command("events many")
check(contains(grammar.drain(), "EVENTS: count must be a decimal number"), "events rejects a non-decimal count")
grammar.command("clear")
check(grammar.drain()[0] == "\x1b", "clear emits the terminal clear escape")
let grammar_events = boot_shell()
grammar_events.drain()
grammar_events.command("events 2")
check(contains(grammar_events.drain(), "$0400 = C8\r\n$0401 = C9\r\nEVENTS 2 OF 2"), "events prints recorded writes with dollar addresses")

print("== events, serial, palette, characters ==")
let logs = boot_shell()
logs.drain()
check(logs.events() == 2 and contains(logs.drain(), "$0400 = C8\r\n"), "events defaults to the last eight writes")
check(logs.events(1) == 1, "events honors an explicit count")
let one_event = logs.drain()
check(contains(one_event, "$0401 = C9\r\n") and not contains(one_event, "$0400"), "events prints only the requested tail of the log")
let blank = new_shell()
blank.drain()
blank.events()
check(contains(blank.drain(), "NO EVENTS"), "events reports an empty log")
let ser = new_shell()
ser.drain()
ser.serial()
check(contains(ser.drain(), "(no serial output)"), "serial reports an empty bridge")
ser.boot()
ser.drain()
ser.serial()
check(contains(ser.drain(), "A2\r\nHI\r\n"), "serial prints the replacement ROM signature")
ser.key("Z")
ser.drain()
ser.serial()
check(contains(ser.drain(), "A2\r\nHI\r\nZ\r\n"), "serial terminates an unterminated line with CRLF")

let palette = boot_shell()
let other = boot_shell()
palette.command("gr")
palette.drain()
palette.poke("$0400", "$01")
palette.palette[0] = "Z"
check(slice(palette.frame(), 0, 1) == "Z" and slice(other.frame(), 0, 1) == "H", "each shell owns an independent palette copy")
check(other.palette[0] == "0" and other.frame() == boot.frame(), "a palette edit in one shell leaves another shell unchanged")

let characters = boot_shell()
characters.command("gr")
characters.drain()
characters.command("hgr")
characters.machine.bus.write8(0x2000, 0x01)
characters.machine.bus.write8(0x2028, 0x00)
check(slice(characters.frame(), 0, 1) == "#" and slice(characters.frame(), 1, 2) == ".", "the frame uses the default on and off characters")
characters.drain()
characters.on_char = "X"
characters.off_char = " "
check(slice(characters.frame(), 0, 2) == "X " and len(characters.frame()) == 24 * 40 + 23 * 2, "on and off characters are caller controlled and keep the frame width")

print("== repeatability ==")
let first = boot_shell()
let second = boot_shell()
check(first.frame() == second.frame(), "two shells boot to the same frame")
check(first.state() == second.state(), "two shells boot to the same state")
first.command("help")
second.command("help")
check(first.drain() == second.drain(), "two shells print the same help")
let script = ["type SAGE", "poke $0500 $41", "peek $0500", "key S", "gr", "hgr", "nomix", "page2", "run 500", "serial", "events 3", "state"]
var same = true
var script_index = 0
while script_index < len(script):
    first.command(script[script_index])
    second.command(script[script_index])
    if first.drain() != second.drain():
        same = false
    script_index = script_index + 1
check(same, "an identical command script replays byte for byte in two shells")
check(first.frame() == second.frame() and first.state() == second.state(), "identical sessions end in the same frame and state")
check(first.machine.bus.events == second.machine.bus.events and first.machine.bus.video_events == second.machine.bus.video_events, "identical sessions record identical event logs")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
