#########################################################################
## SageApple — OS console: Applesoft BASIC + DOS 3.3 + monitor
##
## One console, three faces:
##   ]   BASIC prompt (Applesoft statements, DOS verbs, shell extensions)
##   *   Apple II style monitor (dumps, stores, disassembly, go)
## Running programs suspend at INPUT/GET: the OS feeds subsequent lines
## into the program until it completes.  CALL -151 drops into the monitor.
#########################################################################

import sageapple.machine
import basic.basic
import sageapple.monitor
import sageapple.dos
import apps.catalog
import sageapple.graphics

let _DOS_VERBS = ["CATALOG","SAVE","LOAD","RUN","DELETE","RENAME","LOCK","UNLOCK","VERIFY","MON","NOMON","MAXFILES","INIT","OPEN","CLOSE","READ","WRITE","APPEND","POSITION","BLOAD","BSAVE","BRUN","EXEC","FP","INT"]

class OS:
    proc init(self, machine):
        self.m = machine
        self.basic = basic.Basic()
        self.basic.speaker = machine.bus.speaker
        self.basic.machine = machine
        self.st = machine.bus.storage
        self.dos = dos.DOS(machine, self.basic)
        self.basic.dos = self.dos
        self.dos.host = self
        self.mon = monitor.Monitor(machine)
        self.out = ""
        self.mode = "basic"

    proc boot(self):
        self.out = "SageApple Computer\r\n"
        self.out = self.out + "Sage6502 CPU ........ OK\r\n"
        self.out = self.out + "Memory .............. 2048 bytes\r\n"
        self.out = self.out + "ROM ................. OK\r\n"
        self.out = self.out + "UART ................ OK\r\n"
        self.out = self.out + "SPI Display ......... OK\r\n"
        self.out = self.out + "SPI Flash ........... OK\r\n"
        self.out = self.out + "\r\nSageApple OS 0.1\r\n\r\n] "

    proc say(self, s):
        self.out = self.out + s

    proc drain(self):
        let s = self.out
        self.out = ""
        return s

    proc _word(self, s):
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        return [upper(slice(s, 0, i)), slice(s, i, len(s))]

    proc _in_list(self, list, v):
        var i = 0
        while i < len(list):
            if list[i] == v:
                return true
            i = i + 1
        return false

    ## one command line; response appended to self.out
    proc command(self, line):
        var cmd = strip(line)
        if cmd == "":
            if self.mode == "monitor":
                self.say("\r\n* ")
            else:
                self.say("\r\n] ")
            return
        if self.mode == "monitor":
            let r = self.mon.cmd(cmd)
            self.say(self.mon.out)
            self.mon.out = ""
            if r == "exit":
                self.mode = "basic"
                self.say("\r\n] ")
            elif r == "dump":
                self.say("\r\n- ")
            else:
                self.say("\r\n* ")
            return
        if self.basic.running:
            self.basic.input_line(cmd)
            self.say(self.basic.drain())
            if not self.basic.running:
                if endswith(self.out, "\r\n"):
                    self.say("] ")
                else:
                    self.say("\r\n] ")
            return

        let w = self._word(cmd)
        let verb = w[0]
        let rest = w[1]
        if verb == "EXIT" or verb == "QUIT":
            self.say("BYE\r\n")
        elif verb == "HELP":
            self.say("Commands: help info apps dir splash clear basic monitor beep\r\n")
            self.say("DOS: catalog save load run delete rename lock unlock verify\r\n")
            self.say("     mon nomon pr# in# maxfiles init open close read write append\r\n")
            self.say("     position bload bsave brun exec fp int\r\n")
            self.say("BASIC: Applesoft statements, LIST NEW RUN CONT\r\n")
        elif verb == "INFO":
            self.say(self._info_text())
        elif verb == "APPS":
            self.say(self._apps_text())
        elif verb == "DIR":
            self.dos.command("CATALOG")
            self.say(self.dos.drain())
        elif verb == "DEL":
            self.dos.command("DELETE " + rest)
            self.say(self.dos.drain())
        elif verb == "SPLASH":
            self.say(self._splash())
        elif verb == "CLEAR":
            self.say("\x1b[2J\x1b[H")
        elif verb == "MONITOR":
            self.mode = "monitor"
            self.say("\r\n* ")
            return
        elif verb == "BASIC":
            self.say("\r\n] ")
            return
        elif verb == "RUN":
            if strip(rest) == "":
                self.basic.input_line(cmd)
                self.say(self.basic.drain())
            else:
                self.dos.command(cmd)
                self.say(self.dos.drain())
                self.say(self.basic.drain())
        elif startswith(verb, "PR#") or startswith(verb, "IN#") or self._in_list(_DOS_VERBS, verb):
            self.dos.command(cmd)
            self.say(self.dos.drain())
        else:
            self.basic.input_line(cmd)
            self.say(self.basic.drain())
            if self.basic.called_monitor:
                self.basic.called_monitor = false
                self.mode = "monitor"
                self.say("\r\n* ")
                return
        if not self.basic.running:
            if endswith(self.out, "\r\n"):
                self.say("] ")
            else:
                self.say("\r\n] ")

    ## ---- internals ----

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

    ## run the stored 6502 binary app at $0300 (boot stub + RAM image)
    proc run_6502_app(self, name, steps):
        let blob = self.st.load_blob(name)
        if len(blob) == 0:
            return -1
        var rom = []
        var k = 0
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

    proc _info_text(self):
        return "CPU: 6502 @ 1 MHz\r\n" + "RAM: 2048 bytes\r\n" + "ROM: 32KB\r\n" + "UART: $2000-$2001  Display: $2002-$2004\r\n" + "Flash: $2005-$2006  Speaker: $2007\r\n"

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
