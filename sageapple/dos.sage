#########################################################################
## SageApple — DOS 3.3 command processor (PLAN.md M12)
##
## Authentic DOS 3.3 verbs: CATALOG SAVE LOAD RUN DELETE RENAME LOCK
## UNLOCK VERIFY MON NOMON PR# IN# MAXFILES INIT OPEN CLOSE READ WRITE
## APPEND POSITION BLOAD BSAVE BRUN EXEC FP INT.
##
## Host side: files live in the SAGEFS flash (Storage); buffers keep an
## in-memory line list for text I/O.  BASIC PRINT routes lines into the
## active WRITE/APPEND buffer and INPUT consumes the active READ buffer.
#########################################################################

import sageapple.storage

## int -> decimal string (Sage has no str())
proc intstr(n):
    if n == 0:
        return "0"
    var neg = 0
    var v = n
    if v < 0:
        neg = 1
        v = 0 - v
    var r = ""
    while v > 0:
        r = r + "0123456789"[v % 10]
        v = int(v / 10)
    var s = ""
    if neg:
        s = "-"
    var i = len(r) - 1
    while i >= 0:
        s = s + r[i]
        i = i - 1
    return s

proc _p3(n):
    var s = intstr(n)
    while len(s) < 3:
        s = "0" + s
    return s

proc _has_char(s, ch):
    var i = 0
    while i < len(s):
        if s[i] == ch:
            return true
        i = i + 1
    return false

class DOS:
    proc init(self, machine, basic):
        self.st = machine.bus.storage
        self.bus = machine.bus
        self.cpu = machine.cpu
        self.basic = basic
        self.host = nil
        self.maxfiles = 3
        self.buffers = []
        self.active_read = nil
        self.active_write = nil
        self.vol = 254
        self.outslot = 0
        self.inslot = 0
        self.mon_c = 0
        self.mon_i = 0
        self.mon_o = 0
        self.out = ""
        self.exec_depth = 0

    ## ---- EXEC ----
    proc exec(self, rest):
        if self.exec_depth >= 10:
            self.err("EXEC DEPTH EXCEEDED")
            return
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        let lines = self.st.load_text(name)
        var i = 0
        self.exec_depth = self.exec_depth + 1
        while i < len(lines) and self.host != nil:
            let l = strip(lines[i])
            if l != "":
                self.host.command(l)
                self.host.drain()
            i = i + 1
        self.exec_depth = self.exec_depth - 1
        return -1

    proc drain(self):
        let s = self.out
        self.out = ""
        return s

    proc err(self, msg):
        self.out = self.out + msg + "\r\n"

    proc _find_buf_num(self, n):
        if n >= 1 and n <= len(self.buffers):
            return n - 1
        return -1

    proc _close_buf(self, i):
        let b = self.buffers[i]
        if b["mode"] == "w" or b["mode"] == "a":
            self.st.save_text(b["name"], b["lines"])
        let nb = []
        var k = 0
        while k < len(self.buffers):
            if k != i:
                push(nb, self.buffers[k])
            k = k + 1
        self.buffers = nb
        if self.active_read == i:
            self.active_read = nil
        if self.active_write == i:
            self.active_write = nil
        if self.active_read != nil and self.active_read > i:
            self.active_read = self.active_read - 1
        if self.active_write != nil and self.active_write > i:
            self.active_write = self.active_write - 1

    proc _close_all(self):
        while len(self.buffers) > 0:
            self._close_buf(0)

    ## ---- text I/O used by BASIC ----
    ## BASIC PRINT: if a line completes while a WRITE/APPEND buffer is
    ## active, route it there instead of the screen.
    proc print_line(self, text):
        if self.active_write != nil:
            let b = self.buffers[self.active_write]
            push(b["lines"], text)
            return 1
        return 0

    proc input_line(self):
        if self.active_read != nil:
            let b = self.buffers[self.active_read]
            if b["pos"] >= len(b["lines"]):
                return nil
            let l = b["lines"][b["pos"]]
            b["pos"] = b["pos"] + 1
            return l
        return nil

    proc input_eof(self):
        if self.active_read != nil:
            let b = self.buffers[self.active_read]
            if b["pos"] >= len(b["lines"]):
                return 1
        return 0

    ## ---- command dispatch ----
    proc command(self, line):
        let s = strip(line)
        if s == "":
            return
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let verb = upper(slice(s, 0, i))
        let rest = slice(s, i, len(s))
        if startswith(verb, "PR#"):
            self.outslot = self._slot(slice(s, 3, len(s)))
        elif startswith(verb, "IN#"):
            self.inslot = self._slot(slice(s, 3, len(s)))
        elif verb == "CATALOG":
            self.catalog()
        elif verb == "SAVE":
            self.save(rest)
        elif verb == "LOAD":
            self.load(rest)
        elif verb == "RUN":
            self.run(rest)
        elif verb == "DELETE":
            self.del_file(rest)
        elif verb == "RENAME":
            self.rename(rest)
        elif verb == "LOCK":
            self.lock(rest)
        elif verb == "UNLOCK":
            self.unlock(rest)
        elif verb == "VERIFY":
            self.verify(rest)
        elif verb == "MON":
            self.mon(rest, 1)
        elif verb == "NOMON":
            self.mon(rest, 0)
        elif verb == "PR#":
            self.outslot = self._slot(rest)
        elif verb == "IN#":
            self.inslot = self._slot(rest)
        elif verb == "MAXFILES":
            self.maxfiles_cmd(rest)
        elif verb == "INIT":
            self.init_cmd(rest)
        elif verb == "OPEN":
            self.open(rest)
        elif verb == "CLOSE":
            self.close(rest)
        elif verb == "READ":
            self.read_cmd(rest)
        elif verb == "WRITE":
            self.write_cmd(rest)
        elif verb == "APPEND":
            self.append(rest)
        elif verb == "POSITION":
            self.position(rest)
        elif verb == "BLOAD":
            self.bload(rest)
        elif verb == "BSAVE":
            self.bsave(rest)
        elif verb == "BRUN":
            self.brun(rest)
        elif verb == "EXEC":
            self.exec(rest)
        elif verb == "FP":
            pass
        elif verb == "INT":
            self.err("LANGUAGE NOT AVAILABLE")
        else:
            self.err("SYNTAX ERROR")

    proc _arg1(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        return upper(slice(s, 0, i))

    proc _slot(self, rest):
        let s = strip(rest)
        if len(s) > 0 and s[0] == "#":
            s = slice(s, 1, len(s))
        var i = 0
        while i < len(s) and s[i] >= "0" and s[i] <= "9":
            i = i + 1
        if i == 0:
            return 0
        var v = 0
        var k = 0
        while k < i:
            v = v * 10 + (ord(s[k]) - 48)
            k = k + 1
        if v > 7:
            return 7
        return v

    ## ---- CATALOG ----
    proc catalog(self):
        self.out = self.out + "DISK VOLUME " + intstr(self.vol) + "\r\n\r\n"
        var i = 0
        while i < 16:
            var nm = ""
            var sz = 0
            var ty = 0
            var lock = 0
            let chunk = self.st.read_byte(16 + i * 20)
            if chunk != 0:
                var k = 0
                while k < 12:
                    let b = self.st.read_byte(16 + i * 20 + k)
                    if b == 0:
                        k = 12
                    else:
                        nm = nm + chr(b)
                        k = k + 1
                sz = self.st.read_byte(16 + i * 20 + 12) | (self.st.read_byte(16 + i * 20 + 13) << 8)
                ty = self.st.read_byte(16 + i * 20 + 16)
                lock = self.st.read_byte(16 + i * 20 + 17) & 0x01
                var tch = "T"
                if ty == 0x41:
                    tch = "A"
                elif ty == 0x42:
                    tch = "B"
                elif ty == 0x49:
                    tch = "I"
                let sec = 2 + int(sz / 256)
                let prefix = "*"
                if lock == 0:
                    prefix = " "
                self.out = self.out + prefix + tch + " " + _p3(sec) + " " + nm + "\r\n"
            i = i + 1

    ## ---- file verbs ----
    proc save(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        if self.st.is_locked(name) == 1:
            self.err("FILE LOCKED")
            return
        let lines = []
        var i = 0
        while i < len(self.basic.prog):
            push(lines, intstr(self.basic.prog[i][0]) + " " + self.basic.prog[i][1])
            i = i + 1
        let r = self.st.save_applesoft(name, lines)
        self._save_err(r)

    proc _save_err(self, r):
        if r != 0:
            var empty = false
            var i = 0
            while i < 16:
                if self.st.name_at(i) == "":
                    empty = true
                i = i + 1
            if empty == false:
                self.err("DIRECTORY FULL")
            else:
                self.err("DISK FULL")

    proc load(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        let i = self.st.find(name)
        if i < 0:
            self.err("FILE NOT FOUND")
            return
        if self.st.type_at(i) != 0x41:
            self.err("FILE TYPE MISMATCH")
            return
        self.basic.new()
        let lines = self.st.load_text(name)
        var k = 0
        while k < len(lines):
            let ln = lines[k]
            var j = 0
            while j < len(ln) and ln[j] >= "0" and ln[j] <= "9":
                j = j + 1
            if j > 0 and j < len(ln):
                var num = 0
                var m = 0
                while m < j:
                    num = num * 10 + (ord(ln[m]) - 48)
                    m = m + 1
                let text = slice(ln, j, len(ln))
                self.basic.set_line(num, strip(text))
            k = k + 1

    proc run(self, rest):
        let s = strip(rest)
        if s == "":
            self.basic.run()
            return
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let name = upper(slice(s, 0, i))
        var pln = 0
        var p = i
        while p < len(s):
            if s[p] == "P":
                var q = p + 1
                var v = 0
                while q < len(s) and s[q] >= "0" and s[q] <= "9":
                    v = v * 10 + (ord(s[q]) - 48)
                    q = q + 1
                pln = v
            p = p + 1
        let fi = self.st.find(name)
        if fi < 0:
            self.err("FILE NOT FOUND")
            return
        if self.st.type_at(fi) != 0x41:
            self.err("FILE TYPE MISMATCH")
            return
        self.basic.new()
        let lines = self.st.load_text(name)
        var k = 0
        while k < len(lines):
            let ln = lines[k]
            var j = 0
            while j < len(ln) and ln[j] >= "0" and ln[j] <= "9":
                j = j + 1
            if j > 0 and j < len(ln):
                var num = 0
                var m = 0
                while m < j:
                    num = num * 10 + (ord(ln[m]) - 48)
                    m = m + 1
                self.basic.set_line(num, strip(slice(ln, j, len(ln))))
            k = k + 1
        if pln > 0:
            self.basic.run_at(pln)
        else:
            self.basic.run()

    proc del_file(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        let i = self.st.find(name)
        if i < 0:
            self.err("FILE NOT FOUND")
            return
        if self.st.flags_at(i) & 0x01:
            self.err("FILE LOCKED")
            return
        self.st.delete(name)

    proc rename(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        if i == 0:
            self.err("SYNTAX ERROR")
            return
        let old = upper(slice(s, 0, i))
        let s2 = slice(s, i, len(s))
        var j = 0
        while j < len(s2) and (s2[j] == " " or s2[j] == ","):
            j = j + 1
        let k0 = j
        while j < len(s2) and s2[j] != " " and s2[j] != ",":
            j = j + 1
        let new = upper(slice(s2, k0, j))
        if new == "":
            self.err("SYNTAX ERROR")
            return
        let r = self.st.rename_file(old, new)
        if r == -1:
            self.err("FILE NOT FOUND")
        elif r == -2:
            self.err("DUPLICATE FILENAME")

    proc lock(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        if self.st.find(name) < 0:
            self.err("FILE NOT FOUND")
            return
        self.st.lock_file(name)

    proc unlock(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        if self.st.find(name) < 0:
            self.err("FILE NOT FOUND")
            return
        self.st.unlock_file(name)

    proc verify(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        if self.st.find(name) < 0:
            self.err("FILE NOT FOUND")

    proc mon(self, rest, on):
        let s = upper(strip(rest))
        if s == "":
            self.mon_c = on
            self.mon_i = on
            self.mon_o = on
            return
        self.mon_c = 0
        self.mon_i = 0
        self.mon_o = 0
        if _has_char(s, "C"):
            self.mon_c = on
        if _has_char(s, "I"):
            self.mon_i = on
        if _has_char(s, "O"):
            self.mon_o = on

    proc maxfiles_cmd(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] >= "0" and s[i] <= "9":
            i = i + 1
        if i == 0:
            self.err("SYNTAX ERROR")
            return
        var v = 0
        var k = 0
        while k < i:
            v = v * 10 + (ord(s[k]) - 48)
            k = k + 1
        if v < 1 or v > 16:
            self.err("RANGE ERROR")
            return
        self.maxfiles = v

    proc init_cmd(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        self.st.format()
        let lines = []
        var i = 0
        while i < len(self.basic.prog):
            push(lines, intstr(self.basic.prog[i][0]) + " " + self.basic.prog[i][1])
            i = i + 1
        self.st.save_applesoft("HELLO", lines)

    ## ---- OPEN / CLOSE / READ / WRITE / APPEND / POSITION ----
    proc open(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let name = upper(slice(s, 0, i))
        if name == "":
            self.err("SYNTAX ERROR")
            return
        if len(self.buffers) >= self.maxfiles:
            self.err("NO BUFFERS AVAILABLE")
            return
        if self._find_buf(name) >= 0:
            self.err("FILE ALREADY OPEN")
            return
        if self.st.find(name) >= 0:
            let t = self.st.file_type(name)
            if t != 0x54:
                self.err("FILE TYPE MISMATCH")
                return
        push(self.buffers, {"name": name, "mode": "r", "pos": 0, "lines": self.st.load_text(name)})

    proc close(self, rest):
        let s = strip(rest)
        if s == "":
            self._close_all()
            return
        if s[0] >= "0" and s[0] <= "9":
            var i = 0
            var v = 0
            while i < len(s) and s[i] >= "0" and s[i] <= "9":
                v = v * 10 + (ord(s[i]) - 48)
                i = i + 1
            let bi = self._find_buf_num(v)
            if bi < 0:
                self.err("FILE NOT OPEN")
                return
            self._close_buf(bi)
            return
        let name = self._arg1(rest)
        let bi = self._find_buf(name)
        if bi < 0:
            self.err("FILE NOT OPEN")
            return
        self._close_buf(bi)

    proc read_cmd(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] >= "0" and s[i] <= "9":
            i = i + 1
        if i == 0:
            self.err("SYNTAX ERROR")
            return
        var v = 0
        var k = 0
        while k < i:
            v = v * 10 + (ord(s[k]) - 48)
            k = k + 1
        let bi = self._find_buf_num(v)
        if bi < 0:
            self.err("FILE NOT OPEN")
            return
        self.active_read = bi
        self.active_write = nil

    proc write_cmd(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] >= "0" and s[i] <= "9":
            i = i + 1
        if i == 0:
            self.err("SYNTAX ERROR")
            return
        var v = 0
        var k = 0
        while k < i:
            v = v * 10 + (ord(s[k]) - 48)
            k = k + 1
        let bi = self._find_buf_num(v)
        if bi < 0:
            self.err("FILE NOT OPEN")
            return
        self.buffers[bi]["mode"] = "w"
        self.buffers[bi]["lines"] = []
        self.active_write = bi
        self.active_read = nil

    proc append(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let name = upper(slice(s, 0, i))
        if name == "":
            self.err("SYNTAX ERROR")
            return
        if len(self.buffers) >= self.maxfiles:
            self.err("NO BUFFERS AVAILABLE")
            return
        var bi = self._find_buf(name)
        if bi < 0:
            push(self.buffers, {"name": name, "mode": "a", "pos": 0, "lines": self.st.load_text(name)})
            bi = len(self.buffers) - 1
        else:
            self.buffers[bi]["mode"] = "a"
        self.active_write = bi
        self.active_read = nil

    proc position(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let s2 = slice(s, i, len(s))
        var j = 0
        while j < len(s2) and s2[j] >= "0" and s2[j] <= "9":
            j = j + 1
        if j == 0:
            self.err("SYNTAX ERROR")
            return
        var v = 0
        var k = 0
        while k < j:
            v = v * 10 + (ord(s2[k]) - 48)
            k = k + 1
        if self.active_read == nil:
            self.err("NO FILE OPEN")
            return
        self.buffers[self.active_read]["pos"] = v

    ## ---- BLOAD / BSAVE / BRUN ----
    proc bload(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        let fi = self.st.find(name)
        if fi < 0:
            self.err("FILE NOT FOUND")
            return
        if self.st.type_at(fi) != 0x42:
            self.err("FILE TYPE MISMATCH")
            return
        var addr = 0x0300
        let s = strip(rest)
        var p = 0
        while p < len(s) and s[p] != "A":
            p = p + 1
        if p < len(s):
            var q = p + 1
            var v = 0
            while q < len(s) and s[q] >= "0" and s[q] <= "9":
                v = v * 10 + (ord(s[q]) - 48)
                q = q + 1
            if v > 0:
                addr = v
        let blob = self.st.load_blob(name)
        var k = 0
        while k < len(blob):
            self.bus.write8((addr + k) & 0xFFFF, blob[k])
            k = k + 1

    proc bsave(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let name = upper(slice(s, 0, i))
        if name == "":
            self.err("SYNTAX ERROR")
            return
        var addr = 0
        var alen = 0
        var p = 0
        while p < len(s):
            if s[p] == "A":
                var q = p + 1
                var v = 0
                while q < len(s) and s[q] >= "0" and s[q] <= "9":
                    v = v * 10 + (ord(s[q]) - 48)
                    q = q + 1
                addr = v
            elif s[p] == "L":
                var q = p + 1
                var v = 0
                while q < len(s) and s[q] >= "0" and s[q] <= "9":
                    v = v * 10 + (ord(s[q]) - 48)
                    q = q + 1
                alen = v
            p = p + 1
        if alen == 0 or alen > 65535:
            self.err("SYNTAX ERROR")
            return
        if self.st.is_locked(name) == 1:
            self.err("FILE LOCKED")
            return
        let blob = []
        var k = 0
        while k < alen:
            push(blob, self.bus.read8((addr + k) & 0xFFFF))
            k = k + 1
        let r = self.st.save_binary(name, blob)
        self._save_err(r)

    proc brun(self, rest):
        let s = strip(rest)
        var i = 0
        while i < len(s) and s[i] != " " and s[i] != ",":
            i = i + 1
        let name = upper(slice(s, 0, i))
        if name == "":
            self.err("SYNTAX ERROR")
            return
        self.bload(name)
        let fi = self.st.find(name)
        if fi < 0:
            return
        if self.st.type_at(fi) != 0x42:
            return
        self.cpu.regs.set_pc(0x0300)
        var n = 0
        while n < 900000 and self.cpu.halted == false:
            self.cpu.step()
            n = n + 1

    ## ---- EXEC ----
    proc exec(self, rest):
        let name = self._arg1(rest)
        if name == "":
            self.err("SYNTAX ERROR")
            return
        let lines = self.st.load_text(name)
        var i = 0
        while i < len(lines) and self.host != nil:
            let l = lines[i]
            if strip(l) != "":
                self.host.command(l)
            i = i + 1
