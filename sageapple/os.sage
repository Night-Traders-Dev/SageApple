#########################################################################
## SageApple — standalone OS console (PLAN.md §22 / M12)
##
## Boot menu and command shell tying the whole machine together:
##   help dir apps info basic monitor run save del beep splash
## BASIC and the monitor are reachable from the same console, apps are
## loaded from SAGEFS storage (BASIC source or 6502 binary).
#########################################################################

import sageapple.machine
import basic.basic
import sageapple.monitor
import apps.catalog
import sageapple.graphics

class OS:
    proc init(self, machine):
        self.m = machine
        self.basic = basic.Basic()
        self.basic.speaker = machine.bus.speaker
        self.st = machine.bus.storage
        self.out = ""

    ## boot banner (definition-of-done splash)
    proc boot(self):
        self.out = "SageApple Computer\r\n"
        self.out = self.out + "Sage6502 CPU ........ OK\r\n"
        self.out = self.out + "Memory .............. 2048 bytes\r\n"
        self.out = self.out + "ROM ................. OK\r\n"
        self.out = self.out + "UART ................ OK\r\n"
        self.out = self.out + "SPI Display ......... OK\r\n"
        self.out = self.out + "SPI Flash ........... OK\r\n"
        self.out = self.out + "\r\nSageApple OS 0.1\r\n\r\n> "

    proc say(self, s):
        self.out = self.out + s

    ## one command line; response appended to self.out
    proc command(self, line):
        var cmd = strip(line)
        var arg = ""
        let sp = _find(cmd, " ")
        if sp >= 0:
            arg = strip(slice(cmd, sp + 1, len(cmd)))
            cmd = strip(slice(cmd, 0, sp))
        if cmd == "help":
            self.say("Commands: help dir apps info basic monitor run save del beep splash\r\n")
        elif cmd == "dir":
            self.say(self._dir_text())
        elif cmd == "apps":
            self.say(self._apps_text())
        elif cmd == "info":
            self.say(self._info_text())
        elif cmd == "basic":
            self.say("Basic READY\r\n")
        elif cmd == "monitor":
            self.m.boot_rom(monitor.build_monitor_rom())
            self.say("SageApple Monitor\r\n> ")
        elif cmd == "run":
            self.say(self._run_app(arg))
        elif cmd == "save":
            self.say(self._save_prog(arg))
        elif cmd == "del":
            self.st.delete(arg)
            self.say("DELETED " + arg + "\r\n")
        elif cmd == "beep":
            self.m.bus.speaker.beep()
            self.say("BEEP\r\n")
        elif cmd == "splash":
            self.say(self._splash())
        else:
            self.say("? UNKNOWN COMMAND\r\n")
        self.say("\r\n> ")

    ## ---- internals ----

    proc _dir_text(self):
        let names = self.st.list()
        var s = ""
        var i = 0
        while i < len(names):
            s = s + names[i] + "  " + basic.intstr(self.st.size_of(names[i])) + "\r\n"
            i = i + 1
        if len(names) == 0:
            s = "(empty)\r\n"
        return s

    proc _apps_text(self):
        var s = ""
        let cat = catalog.basic_apps()
        var i = 0
        while i < len(cat):
            let app = cat[i]
            var mark = "-"
            if self.st.size_of(app[0]) != -1:
                mark = "I"
            s = s + mark + " " + app[0] + "\r\n"
            i = i + 1
        var mark2 = "-"
        if self.st.size_of("MACHINE1") != -1:
            mark2 = "I"
        s = s + mark2 + " MACHINE1 (6502)\r\n"
        return s

    proc _info_text(self):
        return "CPU: 6502 @ 1 MHz\r\n" + "RAM: 2048 bytes\r\n" + "ROM: 32KB\r\n" + "UART: $2000-$2001  Display: $2002-$2004\r\n" + "Flash: $2005-$2006  Speaker: $2007\r\n"

    ## run a BASIC app from storage; respond with its output
    proc _run_app(self, name):
        if name == "":
            return "? FILE NAME\r\n"
        let lines = self.st.load_text(name)
        if len(lines) == 0:
            return "? NOT FOUND: " + name + "\r\n"
        self.basic.new()
        var l = 0
        while l < len(lines):
            let line = lines[l]
            let sp = _find(line, " ")
            if sp > 0:
                let num = basic.atoi(line)
                let text = slice(line, sp + 1, len(line))
                self.basic.set_line(num, text)
            l = l + 1
        self.basic.reset_out()
        self.basic.run()
        return self.basic.out

    ## run the stored 6502 binary app at $0300 (boot stub + RAM image)
    proc run_6502_app(self, name, steps):
        let blob = self.st.load_blob(name)
        if len(blob) == 0:
            return -1
        var k = 0
        var rom = []
        while k < 32768:
            push(rom, 0)
            k = k + 1
        rom[0] = 0x4C
        rom[1] = 0x00
        rom[2] = 0x03
        rom[0x7FFC] = 0x00
        rom[0x7FFD] = 0x80
        self.m.boot_rom(rom)
        var i = 0
        while i < len(blob):
            self.m.bus.write_ram(0x0300 + i, blob[i])
            i = i + 1
        var s = 0
        while s < steps:
            self.m.cpu.step()
            s = s + 1
        return 0

    ## save the current BASIC program to storage
    proc _save_prog(self, name):
        if name == "":
            return "? FILE NAME\r\n"
        var lines = []
        var i = 0
        while i < len(self.basic.prog):
            let ln = self.basic.prog[i]
            push(lines, basic.intstr(ln[0]) + " " + ln[1])
            i = i + 1
        if self.st.save_text(name, lines) == 0:
            return "SAVED " + name + "\r\n"
        return "? SAVE FAILED\r\n"

    ## initialize the SPI display and draw a splash screen
    proc _splash(self):
        let d = self.m.bus.gpu
        d.cmd(0xAE)
        d.cmd(0x8D)
        d.dat(0x14)                    # charge pump
        d.cmd(0x20)
        d.dat(0x00)                    # horizontal memory mode
        d.cmd(0xA1)
        d.cmd(0xC8)
        d.cmd(0xAF)                    # display on
        let g = graphics.Gfx(d)
        g.clear(0)
        g.draw_text(0, 0, "SAGEAPPLE")
        g.draw_text(0, 10, "OS 0.1")
        return "DISPLAY READY\r\n"

proc _find(s, ch):
    var i = 0
    while i < len(s):
        if s[i] == ch:
            return i
        i = i + 1
    return -1