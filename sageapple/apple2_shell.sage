import sageapple.apple2_display
import sageapple.apple2_rom

let _A2_PROMPT = "a2> "
let _A2_DIGITS = "0123456789ABCDEF"
let _A2_BAD = -1
let _A2_RANGE = -2
let _A2_BOOT_STEPS = 200
let _A2_MAX_STEPS = 1000000
let _A2_COLS = 40
let _A2_EVENTS = 8
let _A2_TAIL = 24
let _A2_SWITCHES = [["TEXT", 0xC051], ["GR", 0xC050], ["HGR", 0xC057], ["MIX", 0xC053], ["NOMIX", 0xC052], ["PAGE1", 0xC054], ["PAGE2", 0xC055]]

proc _a2_hex_digit(c):
    if c >= "0" and c <= "9":
        return ord(c) - 48
    if c >= "A" and c <= "F":
        return ord(c) - 55
    if c >= "a" and c <= "f":
        return ord(c) - 87
    return _A2_BAD

proc _a2_hex2(value):
    return _A2_DIGITS[(value >> 4) & 0xF] + _A2_DIGITS[value & 0xF]

proc _a2_hex4(value):
    return _a2_hex2((value >> 8) & 0xFF) + _a2_hex2(value & 0xFF)

proc _a2_flag(state):
    if state:
        return "on"
    return "off"

proc _a2_crlf(text):
    var out = ""
    var i = 0
    while i < len(text):
        if text[i] == "\n":
            out = out + "\r\n"
        else:
            out = out + text[i]
        i = i + 1
    return out

proc _a2_escape(text):
    var out = ""
    var i = 0
    while i < len(text):
        let c = text[i]
        if c == "\r":
            out = out + "\\r"
        elif c == "\n":
            out = out + "\\n"
        elif c == "\t":
            out = out + "\\t"
        else:
            out = out + c
        i = i + 1
    return out

proc _a2_tail(text, count):
    if len(text) <= count:
        return text
    return slice(text, len(text) - count, len(text))

class Apple2Shell:
    proc init(self, machine):
        self.machine = machine
        self.out = ""
        self.steps = 2000
        self.on_char = "#"
        self.off_char = "."
        self.palette = apple2_display.default_palette()

    proc say(self, s):
        self.out = self.out + s

    proc drain(self):
        let s = self.out
        self.out = ""
        return s

    proc boot(self):
        self.out = ""
        self.machine.load_rom(apple2_rom.build())
        self.run(_A2_BOOT_STEPS)
        self.say("A2 HOST SHELL\r\n")
        self.say("Apple ][ host emulator -- 12K replacement ROM, 40x24 display\r\n")
        self.say("type help for commands\r\n")
        self.say(_A2_PROMPT)

    proc frame(self):
        return _a2_crlf(self.machine.render_display(self.palette, self.on_char, self.off_char))

    proc screen(self):
        return "\x1b[H" + self.frame()

    proc state(self):
        let video = self.machine.bus.video_snapshot()
        let card = self.machine.bus.language_card_state()
        var s = "page " + str(self.machine.video_page()) + "  mode " + self.machine.video_mode() + "  mixed " + _a2_flag(self.machine.display_mixed()) + "\r\n"
        s = s + "video text " + _a2_flag(video[0]) + "  mixed " + _a2_flag(video[1]) + "  page2 " + _a2_flag(video[2]) + "  hires " + _a2_flag(video[3]) + "\r\n"
        s = s + "card bank " + str(card[0]) + "  read " + _a2_flag(card[1]) + "  write " + _a2_flag(card[2]) + "  prewrite " + _a2_flag(card[3]) + "\r\n"
        s = s + "events " + str(len(self.machine.bus.events)) + "  video-events " + str(len(self.machine.bus.video_events)) + "\r\n"
        s = s + "speaker " + _a2_flag(self.machine.bus.speaker_state()) + "  toggles " + str(self.machine.bus.speaker_toggles) + "\r\n"
        s = s + "serial \"" + _a2_escape(_a2_tail(self.machine.serial_text(), _A2_TAIL)) + "\"\r\n"
        return s

    proc _token_addr(self, token):
        if type(token) == "number":
            if token != int(token):
                return _A2_BAD
            let n = int(token)
            if n < 0 or n > 0xFFFF:
                return _A2_RANGE
            return n
        let s = strip(token)
        if startswith(s, "$"):
            s = slice(s, 1, len(s))
        if len(s) < 1 or len(s) > 4:
            return _A2_BAD
        var value = 0
        var i = 0
        while i < len(s):
            let digit = _a2_hex_digit(s[i])
            if digit == _A2_BAD:
                return _A2_BAD
            value = value * 16 + digit
            i = i + 1
        return value

    proc _token_value(self, token):
        let parsed = self._token_addr(token)
        if parsed == _A2_BAD or parsed == _A2_RANGE:
            return parsed
        if parsed > 0xFF:
            return _A2_RANGE
        return parsed

    proc _token_decimal(self, token):
        let s = strip(token)
        if len(s) < 1:
            return _A2_BAD
        var value = 0
        var i = 0
        while i < len(s):
            if s[i] < "0" or s[i] > "9":
                return _A2_BAD
            value = value * 10 + (ord(s[i]) - 48)
            i = i + 1
        return value

    proc _words(self, text):
        var out = []
        var i = 0
        while i < len(text):
            if text[i] == " ":
                i = i + 1
            else:
                let start = i
                while i < len(text) and text[i] != " ":
                    i = i + 1
                push(out, slice(text, start, i))
        return out

    proc _switch_addr(self, name):
        let key = upper(strip(name))
        var i = 0
        while i < len(_A2_SWITCHES):
            if _A2_SWITCHES[i][0] == key:
                return _A2_SWITCHES[i][1]
            i = i + 1
        return _A2_BAD

    proc poke(self, addr, value):
        let a = self._token_addr(addr)
        if a == _A2_BAD or a == _A2_RANGE:
            self.say("POKE: address must be 1-4 hex digits ($0000-$FFFF)\r\n")
            return _A2_BAD
        let v = self._token_value(value)
        if v == _A2_BAD or v == _A2_RANGE:
            self.say("POKE: value must be 1-4 hex digits ($00-$FF)\r\n")
            return _A2_BAD
        self.machine.bus.write8(a, v)
        self.say("POKE $" + _a2_hex4(a) + " = " + _a2_hex2(v) + "\r\n")
        return v

    proc peek(self, addr):
        let a = self._token_addr(addr)
        if a == _A2_BAD or a == _A2_RANGE:
            self.say("PEEK: address must be 1-4 hex digits ($0000-$FFFF)\r\n")
            return _A2_BAD
        let value = self.machine.bus.read8(a)
        self.say("PEEK $" + _a2_hex4(a) + " = " + _a2_hex2(value) + "\r\n")
        return value

    proc type_text(self, text):
        let page = self.machine.video_page()
        var column = 0
        var i = 0
        while i < len(text) and column < _A2_COLS:
            let code = (ord(upper(text[i])) & 0x7F) | 0x80
            self.machine.bus.write8(self.machine.text.cell_address(0, column, page), code)
            column = column + 1
            i = i + 1
        return column

    proc key(self, text):
        self.machine.keyboard_input(text)
        return self.run(self.steps)

    proc run(self, count = 0):
        var budget = self.steps
        if type(count) == "number" and count != 0:
            budget = int(count)
        if budget > _A2_MAX_STEPS:
            budget = _A2_MAX_STEPS
        if budget < 0:
            budget = 0
        self.machine.run(budget)
        return budget

    proc switch(self, name):
        let key = upper(strip(name))
        let addr = self._switch_addr(key)
        if addr == _A2_BAD:
            self.say("?SWITCH " + key + "\r\n")
            return false
        self.machine.bus.write8(addr, 0x00)
        self.say("SWITCH " + key + " -> $" + _a2_hex4(addr) + "\r\n")
        return true

    proc serial(self):
        let text = self.machine.serial_text()
        if len(text) == 0:
            self.say("(no serial output)\r\n")
            return 0
        if not endswith(text, "\r\n"):
            self.say(text + "\r\n")
        else:
            self.say(text)
        return len(text)

    proc events(self, count = _A2_EVENTS):
        let total = len(self.machine.bus.events)
        if total == 0:
            self.say("NO EVENTS\r\n")
            return 0
        if count < 0:
            count = 0
        var first = total - count
        if first < 0:
            first = 0
        var i = first
        while i < total:
            let entry = self.machine.bus.events[i]
            self.say("$" + _a2_hex4(entry[0]) + " = " + _a2_hex2(entry[1]) + "\r\n")
            i = i + 1
        return total - first

    proc help(self):
        self.say("A2 host commands:\r\n")
        self.say("  help state frame screen serial events clear exit\r\n")
        self.say("  text gr hgr mix nomix page1 page2\r\n")
        self.say("  poke $0400 $C8   peek $0400\r\n")
        self.say("  type HELLO   key H   run 2000\r\n")
        self.say("  frame and screen are read-only; switches write $C050-$C057\r\n")

    proc clear(self):
        self.say("\x1b[2J\x1b[H")

    proc command(self, line):
        let text = strip(line)
        if text == "":
            self.say("\r\n" + _A2_PROMPT)
            return ""
        let parts = self._words(text)
        let verb = upper(parts[0])
        let rest = strip(slice(text, len(parts[0]), len(text)))
        if verb == "EXIT" or verb == "QUIT":
            self.say("BYE\r\n")
            return "exit"
        if verb == "HELP" or verb == "?":
            self.help()
        elif verb == "STATE":
            self.say(self.state())
        elif verb == "FRAME":
            self.say(self.frame())
            self.say("\r\n")
        elif verb == "SCREEN":
            self.say(self.screen())
            self.say("\r\n")
        elif verb == "POKE":
            let args = self._words(rest)
            if len(args) < 2:
                self.say("POKE: usage poke $0400 $C8\r\n")
            else:
                self.poke(args[0], args[1])
        elif verb == "PEEK":
            let args = self._words(rest)
            if len(args) < 1:
                self.say("PEEK: usage peek $0400\r\n")
            else:
                self.peek(args[0])
        elif verb == "TYPE":
            let written = self.type_text(rest)
            self.say("TYPED " + str(written) + "\r\n")
        elif verb == "KEY":
            let steps = self.key(rest)
            self.say("KEY " + str(len(rest)) + " -> " + str(steps) + " steps\r\n")
        elif verb == "RUN":
            var count = 0
            if rest != "":
                count = self._token_decimal(rest)
                if count == _A2_BAD:
                    self.say("RUN: steps must be a decimal number\r\n")
                    count = 0
            let steps = self.run(count)
            self.say("RAN " + str(steps) + " STEPS\r\n")
        elif verb == "SERIAL":
            self.serial()
        elif verb == "EVENTS":
            var count = _A2_EVENTS
            if rest != "":
                count = self._token_decimal(rest)
                if count == _A2_BAD:
                    self.say("EVENTS: count must be a decimal number\r\n")
                    count = _A2_EVENTS
            let shown = self.events(count)
            self.say("EVENTS " + str(shown) + " OF " + str(len(self.machine.bus.events)) + "\r\n")
        elif verb == "CLEAR":
            self.clear()
        elif self._switch_addr(verb) != _A2_BAD:
            self.switch(verb)
        else:
            self.say("?UNKNOWN " + verb + "\r\n")
        self.say(_A2_PROMPT)
        return ""
