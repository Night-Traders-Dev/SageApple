#########################################################################
## SageApple — 6502 monitor (Milestone 7)
##
## A command-line monitor assembled into the 32KB program ROM and driven
## over the same UART the terminal uses:
##   help | dump <lo> <hi> | peek <addr> | poke <addr> <val>
##   regs | run | reset
## Reset vector -> $8000.
#########################################################################

import compiler.asm6502

proc h2(v):
    let dig = "0123456789ABCDEF"
    return dig[(v >> 4) & 0xF] + dig[v & 0xF]

proc bline(b):
    var t = ".byte "
    var i = 0
    let n = len(b)
    while i < n:
        t = t + h2(b[i])
        if i < n - 1:
            t = t + ","
        i = i + 1
    return t

proc asbytes(s):
    var out = []
    var i = 0
    while i < len(s):
        push(out, ord(s[i]))
        i = i + 1
    push(out, 0)
    return out

proc build_monitor_rom():
    return pad32k(asm6502.asm(_MON_SRC, 0x8000)[0])

var _MON_SRC = [
"org $8000",
"",
"start:",
"    LDA #<banner",
"    STA $10",
"    LDA #>banner",
"    STA $11",
"    JSR prs",
"",
"cmdloop:",
"    STA $19             ; save A",
"    PHP",
"    PLA",
"    STA $1F             ; P",
"    TSX",
"    STX $1E             ; SP",
"    TXA",
"    STA $1B             ; X",
"    TYA",
"    STA $1C             ; Y",
"    LDA #<prompt",
"    STA $10",
"    LDA #>prompt",
"    STA $11",
"    JSR prs",
"    JSR read_line",
"    JSR dispatch",
"    JMP cmdloop",
"",
"read_line:",
"    LDY #$00",
"rl_loop:",
"    LDA $2000",
"    AND #$01",
"    BEQ rl_loop",
"    LDA $2001",
"    CMP #$0D",
"    BEQ rl_done",
"    CMP #$0A",
"    BEQ rl_done",
"    CMP #$20",
"    BCC rl_loop",
"    STA $0200,Y",
"    JSR out",
"    INY",
"    CPY #$40",
"    BCC rl_loop",
"    LDA #$0D",
"rl_done:",
"    LDA #$00",
"    STA $0200,Y",
"    JSR crlf",
"    RTS",
"",
"out:",
"    STA $2001",
"    RTS",
"",
"crlf:",
"    PHA",
"    LDA #$0D",
"    JSR out",
"    LDA #$0A",
"    JSR out",
"    PLA",
"    RTS",
"",
"prs:",
"    LDY #$00",
"pch:",
"    LDA ($10),Y",
"    BEQ pdone",
"    JSR out",
"    INY",
"    JMP pch",
"pdone:",
"    RTS",
"",
"hexout:",
"    PHA",
"    LSR a",
"    LSR a",
"    LSR a",
"    LSR a",
"    JSR hexdig",
"    PLA",
"    AND #$0F",
"hexdig:",
"    CMP #$0A",
"    BCS isalpha",
"    CLC",
"    ADC #$30",
"    JMP hdout",
"isalpha:",
"    CLC",
"    ADC #$37",
"hdout:",
"    JSR out",
"    RTS",
"",
"hexv:",
"    CMP #$30",
"    BCC hvbad",
"    CMP #$3A",
"    BCC hvdig",
"    CMP #$41",
"    BCC hvbad",
"    CMP #$47",
"    BCC hvup",
"    CMP #$61",
"    BCC hvbad",
"    CMP #$67",
"    BCC hvlo",
"hvbad:",
"    CLC",
"    RTS",
"hvdig:",
"    SEC",
"    SBC #$30",
"    RTS",
"hvup:",
"    SEC",
"    SBC #$37",
"    RTS",
"hvlo:",
"    SEC",
"    SBC #$57",
"    RTS",
"",
"parse16:",
"    LDA #$00",
"    STA $12",
"    STA $13",
"p16l:",
"    LDA $0200,Y",
"    JSR hexv",
"    BCC p16d",
"    ASL $12",
"    ROL $13",
"    ASL $12",
"    ROL $13",
"    ASL $12",
"    ROL $13",
"    ASL $12",
"    ROL $13",
"    ORA $12",
"    STA $12",
"    INY",
"    JMP p16l",
"p16d:",
"    RTS",
"",
"strcmp:",
"    LDY #$00",
"sc_loop:",
"    LDA ($10),Y",
"    STA $16",
"    CMP #$00",
"    BEQ sc_endlit",
"    LDA $0200,Y",
"    CMP $16",
"    BNE sc_ne",
"    INY",
"    JMP sc_loop",
"sc_endlit:",
"    LDA $0200,Y",
"    CMP #$00",
"    BEQ sc_eq",
"    CMP #$20",
"    BEQ sc_eq",
"    CMP #$0D",
"    BEQ sc_eq",
"sc_ne:",
"    CLC",
"    RTS",
"sc_eq:",
"    SEC",
"    RTS",
"",
"dispatch:",
"    LDA #<hlp",
"    STA $10",
"    LDA #>hlp",
"    STA $11",
"    JSR strcmp",
"    BCC sk_help",
"    JMP do_help",
"sk_help:",
"    LDA #<hdmp",
"    STA $10",
"    LDA #>hdmp",
"    STA $11",
"    JSR strcmp",
"    BCC sk_dump",
"    JMP do_dump",
"sk_dump:",
"    LDA #<hpk",
"    STA $10",
"    LDA #>hpk",
"    STA $11",
"    JSR strcmp",
"    BCC sk_peek",
"    JMP do_peek",
"sk_peek:",
"    LDA #<hpok",
"    STA $10",
"    LDA #>hpok",
"    STA $11",
"    JSR strcmp",
"    BCC sk_poke",
"    JMP do_poke",
"sk_poke:",
"    LDA #<hrgs",
"    STA $10",
"    LDA #>hrgs",
"    STA $11",
"    JSR strcmp",
"    BCC sk_regs",
"    JMP do_regs",
"sk_regs:",
"    LDA #<hrun",
"    STA $10",
"    LDA #>hrun",
"    STA $11",
"    JSR strcmp",
"    BCC sk_run",
"    JMP do_run",
"sk_run:",
"    LDA #<hrst",
"    STA $10",
"    LDA #>hrst",
"    STA $11",
"    JSR strcmp",
"    BCC sk_rst",
"    JMP do_reset",
"sk_rst:",
"    LDA #<hbad",
"    STA $10",
"    LDA #>hbad",
"    STA $11",
"    JSR prs",
"    JSR crlf",
"    RTS",
"",
"do_help:",
"    LDA #<helptxt",
"    STA $10",
"    LDA #>helptxt",
"    STA $11",
"    JSR prs",
"    RTS",
"",
"do_regs:",
"    LDA #<ha",
"    STA $10",
"    LDA #>ha",
"    STA $11",
"    JSR prs",
"    LDA $19",
"    JSR hexout",
"    LDA #$20",
"    JSR out",
"    LDA #<hx",
"    STA $10",
"    LDA #>hx",
"    STA $11",
"    JSR prs",
"    LDA $1B",
"    JSR hexout",
"    LDA #$20",
"    JSR out",
"    LDA #<hy",
"    STA $10",
"    LDA #>hy",
"    STA $11",
"    JSR prs",
"    LDA $1C",
"    JSR hexout",
"    LDA #$20",
"    JSR out",
"    LDA #<hs",
"    STA $10",
"    LDA #>hs",
"    STA $11",
"    JSR prs",
"    LDA $1E",
"    JSR hexout",
"    LDA #$20",
"    JSR out",
"    LDA #<hp",
"    STA $10",
"    LDA #>hp",
"    STA $11",
"    JSR prs",
"    LDA $1F",
"    JSR hexout",
"    JSR crlf",
"    RTS",
"",
"do_run:",
"    LDA #<noprog",
"    STA $10",
"    LDA #>noprog",
"    STA $11",
"    JSR prs",
"    JSR crlf",
"    RTS",
"",
"do_reset:",
"    JMP start",
"",
"do_dump:",
"    LDY #$00",
"dd_f1:",
"    LDA $0200,Y",
"    CMP #$00",
"    BEQ dd_ret",
"    CMP #$20",
"    BEQ dd_s1",
"    INY",
"    JMP dd_f1",
"dd_s1:",
"    INY",
"    JSR parse16",
"    LDA $12",
"    STA $14",
"    LDA $13",
"    STA $15",
"dd_f2:",
"    LDA $0200,Y",
"    CMP #$00",
"    BEQ dd_ret",
"    CMP #$20",
"    BEQ dd_s2",
"    INY",
"    JMP dd_f2",
"dd_s2:",
"    INY",
"    JSR parse16",
"dd_loop:",
"    LDA $15",
"    CMP $13",
"    BCC dd_go",
"    BNE dd_done",
"    LDA $14",
"    CMP $12",
"    BCS dd_done",
"dd_go:",
"    LDA $15",
"    JSR hexout",
"    LDA $14",
"    JSR hexout",
"    LDA #$3A",
"    JSR out",
"    LDA #$20",
"    JSR out",
"    LDY #$00",
"    LDA ($14),Y",
"    JSR hexout",
"    JSR crlf",
"    INC $14",
"    BNE dd_loop",
"    INC $15",
"    JMP dd_loop",
"dd_done:",
"dd_ret:",
"    RTS",
"",
"do_peek:",
"    LDY #$00",
"dp_f1:",
"    LDA $0200,Y",
"    CMP #$00",
"    BEQ dp_ret",
"    CMP #$20",
"    BEQ dp_s1",
"    INY",
"    JMP dp_f1",
"dp_s1:",
"    INY",
"    JSR parse16",
"    LDA $13",
"    JSR hexout",
"    LDA $12",
"    JSR hexout",
"    LDA #$3A",
"    JSR out",
"    LDA #$20",
"    JSR out",
"    LDY #$00",
"    LDA ($12),Y",
"    JSR hexout",
"    JSR crlf",
"dp_ret:",
"    RTS",
"",
"do_poke:",
"    LDY #$00",
"dw_f1:",
"    LDA $0200,Y",
"    CMP #$00",
"    BEQ dw_ret",
"    CMP #$20",
"    BEQ dw_s1",
"    INY",
"    JMP dw_f1",
"dw_s1:",
"    INY",
"    JSR parse16",
"    LDA $12",
"    STA $0C",
"    LDA $13",
"    STA $0D",
"dw_f2:",
"    LDA $0200,Y",
"    CMP #$00",
"    BEQ dw_ret",
"    CMP #$20",
"    BEQ dw_s2",
"    INY",
"    JMP dw_f2",
"dw_s2:",
"    INY",
"    JSR parse16",
"    LDA $12",
"    LDY #$00",
"    STA ($0C),Y",
"    JSR crlf",
"dw_ret:",
"    RTS",
"",
"banner:",
bline(asbytes("SageApple Monitor")),
".byte 0D,0A,0D,0A,00",
"prompt:",
".byte 4D,4F,4E,3E,20,00",
"hlp:",
".byte 68,65,6C,70,00",
"hdmp:",
".byte 64,75,6D,70,00",
"hpk:",
".byte 70,65,65,6B,00",
"hpok:",
".byte 70,6F,6B,65,00",
"hrgs:",
".byte 72,65,67,73,00",
"hrun:",
".byte 72,75,6E,00",
"hrst:",
".byte 72,65,73,65,74,00",
"hbad:",
".byte 3F,0D,0A,00",
"helptxt:",
bline(asbytes("Commands: help dump peek poke regs run reset")),
".byte 0D,0A,00",
"noprog:",
bline(asbytes("no user program")),
".byte 0D,0A,00",
"ha:",
".byte 41,3D,00",
"hx:",
".byte 58,3D,00",
"hy:",
".byte 59,3D,00",
"hs:",
".byte 53,50,3D,00",
"hp:",
".byte 50,3D,00",]

proc build_monitor_rom_at(org, size, vec):
    var body = _MON_SRC
    if len(body) > 0 and body[0] == "org $8000":
        body = slice(body, 1, len(body))
    let src = ["org " + h2((org >> 12) & 0xF) + "000"] + body
    let img = asm6502.asm(src, org)[0]
    return pad_to(img, size, org, vec)

proc pad_to(img, size, org, vec):
    let out = []
    var i = 0
    while i < size:
        push(out, 0x00)
        i = i + 1
    let n = len(img)
    var j = 0
    while j < n and j < size:
        out[j] = img[j]
        j = j + 1
    out[size - 4] = vec & 0xFF
    out[size - 3] = (vec >> 8) & 0xFF
    return out

proc pad32k(img):
    let out = []
    var i = 0
    while i < 32768:
        push(out, 0x00)
        i = i + 1
    let n = len(img)
    var j = 0
    while j < n and j < 32768:
        out[j] = img[j]
        j = j + 1
    out[0x7FFC] = 0x00
    out[0x7FFD] = 0x80
    return out
#########################################################################
## Host-side interactive Monitor (Apple II style)
##
##   * 300.30F       forward dump
##   * 30F-300       backward dump
##   * 300:41 42     store bytes
##   * 300G          go
##   * 300J / 300C   jsr/call
##   * R             run vector
##   * S             step  (T = trace until BRK)
##   * 300L          disassemble 20 lines
##   * N / I / F     display mode
##   * E             exit to BASIC
#########################################################################

import sage6502.cpu

let _MNEMS = ["LDA","LDX","LDY","STA","STX","STY","TAX","TXA","TAY","TYA","TSX","TXS","PHA","PHP","PLA","PLP","ADC","SBC","AND","ORA","EOR","BIT","CMP","CPX","CPY","INC","DEC","INX","INY","DEX","DEY","ASL","LSR","ROL","ROR","BCC","BCS","BEQ","BMI","BNE","BPL","BVC","BVS","JMP","JSR","RTS","BRK","RTI","NOP","CLC","CLD","CLI","CLV","SEC","SED","SEI"]

proc _mh2(v):
    return "0123456789ABCDEF"[(v >> 4) & 0xF] + "0123456789ABCDEF"[v & 0xF]

proc _mh4(v):
    return _mh2((v >> 8) & 0xFF) + _mh2(v & 0xFF)

proc _mhexv(c):
    if c >= "0" and c <= "9":
        return ord(c) - 48
    if c >= "A" and c <= "F":
        return ord(c) - 55
    return -1

class Monitor:
    proc init(self, m):
        self.m = m
        self.out = ""
        self.last_addr = 0
        self.run_vec = 0x0300
        self.dmode = "N"
        self._GO_GUARD = 1000000

    ## ---- register line ----
    proc regs_line(self):
        let c = self.m.cpu
        return "A=" + _mh2(c.regs.a) + " X=" + _mh2(c.regs.x) + " Y=" + _mh2(c.regs.y) + " P=" + _mh2(c.status.get()) + " SP=" + _mh2(c.regs.sp) + "\r\n"

    ## ---- memory display ----
    proc line8(self, base):
        var s = _mh4(base) + "- "
        var k = 0
        while k < 8:
            s = s + _mh2(self.m.bus.read8(base + k)) + " "
            k = k + 1
        return s

    proc dump(self, a1, a2, fwd):
        let max_range = 4096
        if a1 > a2:
            let t = a1
            a1 = a2
            a2 = t
        if a2 - a1 > max_range:
            a2 = a1 + max_range
        var prev = -1
        if fwd:
            var base = a1
            while base <= a2:
                if (base & 0xF00) != prev:
                    self.out = self.out + "\r\n"
                    prev = base & 0xF00
                self.out = self.out + self.line8(base) + "\r\n"
                base = base + 8
            self.last_addr = a2
        else:
            var base = a1 - 7
            while base > a2 and base >= 0:
                if (base & 0xF00) != prev:
                    self.out = self.out + "\r\n"
                    prev = base & 0xF00
                self.out = self.out + self.line8(base) + "\r\n"
                base = base - 8
            self.last_addr = a1
        return ""

    ## ---- store ----
    proc store(self, addr, rest):
        var cur = ""
        var a = addr
        var i = 0
        while i < len(rest):
            let hv = _mhexv(rest[i])
            if hv >= 0:
                cur = cur + rest[i]
                if len(cur) == 2:
                    self.m.bus.write8(a & 0xFFFF, _mhexv(cur[0]) * 16 + _mhexv(cur[1]))
                    a = a + 1
                    cur = ""
            i = i + 1
        self.last_addr = a - 1
        return ""

    ## ---- execution ----
    proc _run_to(self, addr, stop_pc):
        let c = self.m.cpu
        c.regs.set_pc(addr)
        var n = 0
        while n < self._GO_GUARD and c.halted == false:
            if stop_pc >= 0 and c.regs.get_pc() == stop_pc:
                break
            c.step()
            n = n + 1
        self.out = self.out + self.regs_line()
        return ""

    proc go(self, addr):
        return self._run_to(addr, -1)

    proc jsr(self, addr):
        let c = self.m.cpu
        var sp = c.regs.sp
        self.m.bus.write8(0x0100 + sp, 0x00)
        sp = (sp - 1) & 0xFF
        self.m.bus.write8(0x0100 + sp, 0x00)
        sp = (sp - 1) & 0xFF
        c.regs.sp = sp
        return self._run_to(addr, 0x0001)

    ## ---- disassembly ----
    proc dis_line(self, pc):
        let ent = cpu._table()[self.m.bus.read8(pc)]
        let id = ent[0]
        let mode = ent[1]
        var n = 1
        if mode == cpu.M_IMM or mode == cpu.M_ZP or mode == cpu.M_ZPX or mode == cpu.M_ZPY or mode == cpu.M_INDX or mode == cpu.M_INDY or mode == cpu.M_REL:
            n = 2
        elif mode == cpu.M_ABS or mode == cpu.M_ABSX or mode == cpu.M_ABSY or mode == cpu.M_IND:
            n = 3
        var bs = ""
        var k = 0
        while k < n:
            bs = bs + _mh2(self.m.bus.read8(pc + k)) + " "
            k = k + 1
        while len(bs) < 9:
            bs = bs + " "
        let b1 = self.m.bus.read8(pc + 1)
        let b2 = self.m.bus.read8(pc + 2)
        var op = ""
        if mode == cpu.M_IMM:
            op = "#$" + _mh2(b1)
        elif mode == cpu.M_ZP:
            op = "$" + _mh2(b1)
        elif mode == cpu.M_ZPX:
            op = "$" + _mh2(b1) + ",X"
        elif mode == cpu.M_ZPY:
            op = "$" + _mh2(b1) + ",Y"
        elif mode == cpu.M_ABS:
            op = "$" + _mh4(b1 | (b2 << 8))
        elif mode == cpu.M_ABSX:
            op = "$" + _mh4(b1 | (b2 << 8)) + ",X"
        elif mode == cpu.M_ABSY:
            op = "$" + _mh4(b1 | (b2 << 8)) + ",Y"
        elif mode == cpu.M_INDX:
            op = "($" + _mh2(b1) + ",X)"
        elif mode == cpu.M_INDY:
            op = "($" + _mh2(b1) + "),Y"
        elif mode == cpu.M_IND:
            op = "($" + _mh4(b1 | (b2 << 8)) + ")"
        elif mode == cpu.M_REL:
            var tgt = pc + 2 + b1
            if b1 >= 0x80:
                tgt = pc + 2 + (b1 - 0x100)
            op = "$" + _mh4(tgt & 0xFFFF)
        return _mh4(pc) + "- " + bs + _MNEMS[id] + op

    proc list(self, addr):
        var pc = addr
        var n = 0
        while n < 20:
            self.out = self.out + self.dis_line(pc) + "\r\n"
            let ent = cpu._table()[self.m.bus.read8(pc)]
            let mode = ent[1]
            var sz = 1
            if mode == cpu.M_IMM or mode == cpu.M_ZP or mode == cpu.M_ZPX or mode == cpu.M_ZPY or mode == cpu.M_INDX or mode == cpu.M_INDY or mode == cpu.M_REL:
                sz = 2
            elif mode == cpu.M_ABS or mode == cpu.M_ABSX or mode == cpu.M_ABSY or mode == cpu.M_IND:
                sz = 3
            pc = (pc + sz) & 0xFFFF
            n = n + 1
        self.last_addr = pc
        return ""

    ## ---- command line ----
    proc cmd(self, line):
        self.out = ""
        let s = upper(strip(line))
        if s == "":
            return ""
        if len(s) == 1 and (s == "E" or s == "C"):
            if s == "C":
                return self.jsr(self.last_addr)
            return "exit"
        var i = 0
        var v = 0
        var vset = false
        while i < len(s) and _mhexv(s[i]) >= 0:
            v = v * 16 + _mhexv(s[i])
            vset = true
            i = i + 1
        if i >= len(s):
            return ""
        let ch = s[i]
        let rest = slice(s, i + 1, len(s))
        if ch == ".":
            var a2 = 0
            var a2set = false
            var j = 0
            while j < len(rest) and _mhexv(rest[j]) >= 0:
                a2 = a2 * 16 + _mhexv(rest[j])
                a2set = true
                j = j + 1
            if vset == false:
                v = (self.last_addr + 1) & 0xFFFF
            if a2set == false:
                return self.dump(v, v + 7, true)
            return self.dump(v, a2, true)
        if ch == "-":
            var a2 = 0
            var a2set = false
            var j = 0
            while j < len(rest) and _mhexv(rest[j]) >= 0:
                a2 = a2 * 16 + _mhexv(rest[j])
                a2set = true
                j = j + 1
            if vset == false:
                v = self.last_addr
                self.out = self.out + self.line8(v - 7) + "\r\n"
                self.last_addr = v - 8
                return ""
            if a2set == false:
                return self.dump(v - 7, v, false)
            return self.dump(v, a2, false)
        if ch == ":":
            if vset == false:
                v = self.last_addr
            return self.store(v, rest)
        if ch == "G":
            if vset == false:
                v = self.run_vec
            return self.go(v)
        if ch == "J" or ch == "C":
            if vset == false:
                v = self.last_addr
            return self.jsr(v)
        if ch == "R":
            return self.go(self.run_vec)
        if ch == "S":
            self.m.cpu.step()
            self.out = self.out + self.regs_line()
            return ""
        if ch == "T":
            let c = self.m.cpu
            var n = 0
            while n < self._GO_GUARD and c.halted == false:
                c.step()
                n = n + 1
            self.out = self.out + self.regs_line()
            return ""
        if ch == "L":
            if vset == false:
                v = self.last_addr
            return self.list(v)
        if ch == "N" or ch == "I" or ch == "F":
            self.dmode = ch
            return ""
        if ch == "E":
            return "exit"
        return ""
