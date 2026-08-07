#########################################################################
## SageApple — 6502 two-pass assembler (M7; seeds the M9 backend)
##
## Grammar per line (case-insensitive, ';' comments):
##   MNEMONIC operand
##   label:
##   org $XXXX
##   .byte $AA,$BB,..
##
## Operands: #$NN, $NN/NNNN, $NN,X, $N,X, $NN,Y, $N,Y, ($NN),Y,
##           ($NN,X), ($NNNN), LABEL, A
#########################################################################

proc s_pre(s, n): return slice(s, 0, n)
proc s_start(s, p): return slice(s, 0, len(p)) == p
proc s_end(s, p): return slice(s, len(s) - len(p), len(s)) == p
proc s_find(s, sub):
    let sl = len(s)
    let bl = len(sub)
    if bl == 0 or bl > sl:
        return -1
    var i = 0
    while i <= sl - bl:
        if slice(s, i, i + bl) == sub:
            return i
        i = i + 1
    return -1

proc hext(s):
    var t = strip(s)
    if t == "":
        return -1
    if t[0] == "$":
        t = slice(t,1,len(t))
    if s_pre(t, 2) == "0x" or s_pre(t, 2) == "0X":
        t = slice(t,2,len(t))
    var v = 0
    var i = 0
    let n = len(t)
    let dig = "0123456789abcdef"
    while i < n:
        let c = lower(t[i])
        var dv = -1
        var k = 0
        let dn = len(dig)
        while k < dn:
            if dig[k] == c:
                dv = k
                break
            k = k + 1
        if dv < 0:
            return -1
        v = (v << 4) | dv
        i = i + 1
    return v

var _K = []
var _O = []
proc fadd(mn, mode, code):
    push(_K, upper(mn) + "|" + mode)
    push(_O, code & 0xFF)

fadd("LDA","imm",0xA9)
fadd("LDA","zp",0xA5)
fadd("LDA","zpx",0xB5)
fadd("LDA","abs",0xAD)
fadd("LDA","absx",0xBD)
fadd("LDA","absy",0xB9)
fadd("LDA","indzpx",0xA1)
fadd("LDA","indzp_y",0xB1)
fadd("LDX","imm",0xA2)
fadd("LDX","zp",0xA6)
fadd("LDX","abs",0xAE)
fadd("LDX","zpy",0xB6)
fadd("LDX","absy",0xBE)
fadd("LDY","imm",0xA0)
fadd("LDY","zp",0xA4)
fadd("LDY","abs",0xAC)
fadd("LDY","zpx",0xB4)
fadd("LDY","absx",0xBC)
fadd("STA","zp",0x85)
fadd("STA","zpx",0x95)
fadd("STA","abs",0x8D)
fadd("STA","absx",0x9D)
fadd("STA","absy",0x99)
fadd("STA","indzpx",0x81)
fadd("STA","indzp_y",0x91)
fadd("STX","zp",0x86)
fadd("STX","zpy",0x96)
fadd("STX","abs",0x8E)
fadd("STY","zp",0x84)
fadd("STY","zpx",0x94)
fadd("STY","abs",0x8C)
fadd("ADC","imm",0x69)
fadd("ADC","zp",0x65)
fadd("ADC","zpx",0x75)
fadd("ADC","abs",0x6D)
fadd("ADC","absx",0x7D)
fadd("ADC","absy",0x79)
fadd("SBC","imm",0xE9)
fadd("SBC","zp",0xE5)
fadd("SBC","zpx",0xF5)
fadd("SBC","abs",0xED)
fadd("SBC","absx",0xFD)
fadd("SBC","absy",0xF9)
fadd("AND","imm",0x29)
fadd("AND","zp",0x25)
fadd("AND","zpx",0x35)
fadd("AND","abs",0x2D)
fadd("AND","absx",0x3D)
fadd("AND","absy",0x39)
fadd("ORA","imm",0x09)
fadd("ORA","zp",0x05)
fadd("ORA","zpx",0x15)
fadd("ORA","abs",0x0D)
fadd("ORA","absx",0x1D)
fadd("ORA","absy",0x19)
fadd("EOR","imm",0x49)
fadd("EOR","zp",0x45)
fadd("EOR","zpx",0x55)
fadd("EOR","abs",0x4D)
fadd("EOR","absx",0x5D)
fadd("EOR","absy",0x59)
fadd("CMP","imm",0xC9)
fadd("CMP","zp",0xC5)
fadd("CMP","zpx",0xD5)
fadd("CMP","abs",0xCD)
fadd("CMP","absx",0xDD)
fadd("CMP","absy",0xD9)
fadd("CPX","imm",0xE0)
fadd("CPX","zp",0xE4)
fadd("CPX","abs",0xEC)
fadd("CPY","imm",0xC0)
fadd("CPY","zp",0xC4)
fadd("CPY","abs",0xCC)
fadd("INC","zp",0xE6)
fadd("INC","zpx",0xF6)
fadd("INC","abs",0xEE)
fadd("INC","absx",0xFE)
fadd("DEC","zp",0xC6)
fadd("DEC","zpx",0xD6)
fadd("DEC","abs",0xCE)
fadd("DEC","absx",0xDE)
fadd("BIT","zp",0x24)
fadd("BIT","abs",0x2C)
fadd("ASL","acc",0x0A)
fadd("ASL","zp",0x06)
fadd("ASL","zpx",0x16)
fadd("ASL","abs",0x0E)
fadd("ASL","absx",0x1E)
fadd("ROL","acc",0x2A)
fadd("ROL","zp",0x26)
fadd("ROL","zpx",0x36)
fadd("ROL","abs",0x2E)
fadd("ROL","absx",0x3E)
fadd("LSR","acc",0x4A)
fadd("LSR","zp",0x46)
fadd("LSR","zpx",0x56)
fadd("LSR","abs",0x4E)
fadd("LSR","absx",0x5E)
fadd("ROR","acc",0x6A)
fadd("ROR","zp",0x66)
fadd("ROR","zpx",0x76)
fadd("ROR","abs",0x6E)
fadd("ROR","absx",0x7E)
fadd("JMP","abs",0x4C)
fadd("JMP","indabs",0x6C)
fadd("JSR","abs",0x20)
fadd("RTS","imp",0x60)
fadd("RTI","imp",0x40)
fadd("BNE","rel",0xD0)
fadd("BEQ","rel",0xF0)
fadd("BCC","rel",0x90)
fadd("BCS","rel",0xB0)
fadd("BPL","rel",0x10)
fadd("BMI","rel",0x30)
fadd("BVC","rel",0x50)
fadd("BVS","rel",0x70)
fadd("CLC","imp",0x18)
fadd("SEC","imp",0x38)
fadd("CLI","imp",0x58)
fadd("SEI","imp",0x78)
fadd("CLD","imp",0xD8)
fadd("SED","imp",0xF8)
fadd("CLV","imp",0xB8)
fadd("PHA","imp",0x48)
fadd("PLA","imp",0x68)
fadd("PHP","imp",0x08)
fadd("PLP","imp",0x28)
fadd("TAX","imp",0xAA)
fadd("TXA","imp",0x8A)
fadd("TAY","imp",0xA8)
fadd("TYA","imp",0x98)
fadd("TSX","imp",0xBA)
fadd("TXS","imp",0x9A)
fadd("INX","imp",0xE8)
fadd("INY","imp",0xC8)
fadd("DEX","imp",0xCA)
fadd("DEY","imp",0x88)
fadd("NOP","imp",0xEA)
fadd("BRK","imp",0x00)

proc opcode(mn, mode):
    let key = upper(mn) + "|" + mode
    var i = 0
    let n = len(_K)
    while i < n:
        if _K[i] == key:
            return _O[i]
        i = i + 1
    return -1

proc is_branch(mn):
    let m = upper(mn)
    if m == "BEQ" or m == "BNE" or m == "BCC" or m == "BCS" or m == "BPL" or m == "BMI" or m == "BVC" or m == "BVS":
        return true
    return false

## parse an operand token.
## returns [mode, is_sym, value, sym]
##   is_sym: 1 if the effective target is a label symbol, else 0
##   value:  integer (numeric operands) or 0
##   sym:    label name string when is_sym==1 else ""
proc parse_operand(tok):
    tok = strip(tok)
    if tok == "":
        return ["imp", 0, 0, ""]
    if tok == "A":
        return ["acc", 0, 0, ""]
    if s_pre(tok, 1) == "#":
        return ["imm", 0, hext(slice(tok,1,len(tok))), ""]
    if s_pre(tok, 1) == "(":
        let inner = strip(slice(tok,1,len(tok)))
        if s_end(inner, "),Y"):
            return ["indzp_y", 0, hext(strip(slice(inner, 0, len(inner) - 3))), ""]
        if s_end(inner, "X)"):
            return ["indzpx", 0, hext(strip(slice(inner, 0, len(inner) - 2))), ""]
        return ["indabs", 0, hext(strip(slice(inner, 0, len(inner) - 1))), ""]
    if s_end(tok, ",X"):
        var baseX = strip(slice(tok, 0, len(tok) - 2))
        if s_pre(baseX, 1) == "$":
            let v = hext(baseX)
            if v <= 255:
                return ["zpx", 0, v, ""]
            return ["absx", 0, v, ""]
        return ["absx", 1, 0, baseX]
    if s_end(tok, ",Y"):
        var baseY = strip(slice(tok, 0, len(tok) - 2))
        if s_pre(baseY, 1) == "$":
            let v = hext(baseY)
            if v <= 255:
                return ["zpy", 0, v, ""]
            return ["absy", 0, v, ""]
        return ["absy", 1, 0, baseY]
    if s_pre(tok, 1) == "$":
        let v = hext(tok)
        if v <= 255:
            return ["zp", 0, v, ""]
        return ["abs", 0, v, ""]
    return ["abs", 1, 0, tok]

var _ASSM = nil

class Assembler:
    proc init(self):
        self.pc = 0
        self.image = []
        self.labels = {}

    proc emit(self, b):
        push(self.image, b & 0xFF)
        self.pc = self.pc + 1

    proc set_org(self, addr):
        self.pc = addr

    # effective mode (zp vs abs / rel) for an instruction's operand
    proc eff_mode(self, mn, mode, is_sym, value):
        if is_branch(mn):
            return "rel"
        if mode == "abs" or mode == "zp":
            if is_sym == 1:
                return "abs"
            if value <= 255:
                return "zp"
            return "abs"
        if mode == "absx" or mode == "absy":
            if is_sym == 1:
                return mode
            return mode
        return mode

    proc ins_bytes(self, mn, mode, is_sym, value):
        let m = self.eff_mode(mn, mode, is_sym, value)
        if m == "rel":
            return 2
        if m == "imp" or m == "acc":
            return 1
        if m == "imm" or m == "zp" or m == "zpx" or m == "zpy" or m == "indzpx" or m == "indzp_y":
            return 2
        return 3

    proc eff_mode(self, mn, mode, is_sym, value):
        if is_branch(mn):
            return "rel"
        if mode == "abs" or mode == "zp":
            if is_sym == 1:
                return "abs"
            if value <= 255:
                return "zp"
            return "abs"
        if (mode == "zpx" or mode == "absx") and is_sym == 1:
            return "absx"
        if (mode == "zpy" or mode == "absy") and is_sym == 1:
            return "absy"
        return mode

    proc emit_ins(self, ins):
        # ins structure: [mn, mode, is_sym, value, sym]
        let mn = ins[1]
        let mode = ins[2]
        let is_sym = ins[3]
        let value = ins[4]
        let sym = ins[5]
        if is_branch(mn):
            let start = self.pc
            let code = opcode(mn, "rel")
            self.emit(code)
            var target = 0
            if is_sym == 1:
                target = self.lookup(sym)
            else:
                target = value
            let off = (target - (start + 2)) & 0xFF
            self.emit(off)
            return
        let m = self.eff_mode(mn, mode, is_sym, value)
        if m == "imp" or m == "acc":
            self.emit(opcode(mn, m))
            return
        self.emit(opcode(mn, m))
        if m == "imm" or m == "zp" or m == "zpx" or m == "zpy" or m == "indzpx" or m == "indzp_y":
            if is_sym == 1:
                self.emit(self.lookup(sym) & 0xFF)
            else:
                self.emit(value & 0xFF)
        else:
            var lo = 0
            var hi = 0
            if is_sym == 1:
                let tv = self.lookup(sym)
                lo = tv & 0xFF
                hi = (tv >> 8) & 0xFF
            else:
                lo = value & 0xFF
                hi = (value >> 8) & 0xFF
            self.emit(lo)
            self.emit(hi)

    proc lookup(self, name):
        return self.labels[name]

    proc assemble(self, src, base):
        # pass 1: size everything, define labels
        self.pc = base
        self.labels = {}
        var i = 0
        let n = len(src)
        while i < n:
            let line = src[i]
            let k = line[0]
            if k == 1:
                self.labels[line[1]] = self.pc
            elif k == 2:
                self.pc = line[1]
            elif k == 3:
                self.pc = self.pc + len(line[1])
            else:
                let sz = self.size_bytes(line)
                self.pc = self.pc + sz
            i = i + 1
        # pass 2: emit
        self.pc = base
        self.image = []
        i = 0
        while i < n:
            let line = src[i]
            let k = line[0]
            if k == 2:
                self.pc = line[1]
            elif k == 3:
                var b = 0
                let bl = len(line[1])
                while b < bl:
                    self.emit(line[1][b])
                    b = b + 1
            elif k == 0:
                self.emit_ins(line)
            i = i + 1
        return self.image

    proc size_bytes(self, line):
        let m = self.eff_mode(line[1], line[2], line[3], line[4])
        if m == "rel":
            return 2
        if m == "imp" or m == "acc":
            return 1
        if m == "imm" or m == "zp" or m == "zpx" or m == "zpy" or m == "indzpx" or m == "indzp_y":
            return 2
        return 3

# ----------------------------------------------------------------------
# public compiler: source lines -> [image, labels]
# ----------------------------------------------------------------------
proc parse_line(raw0):
    var raw = strip(raw0)
    let ci = s_find(raw, ";")
    if ci >= 0:
        raw = strip(slice(raw, 0, ci))
    if raw == "":
        return ["empty", nil]
    if s_is(raw, ".byte"):
        var vals = []
        for p in strip(slice(raw,5,len(raw))).split(","):
            push(vals, hext(p))
        return ["bytes", vals]
    if s_is(raw, "org"):
        return ["org", hext(strip(slice(raw,3,len(raw))))]
    var body = raw
    var label = ""
    let cix = s_find(raw, ":")
    if cix >= 0:
        let nm = strip(slice(raw, 0, cix))
        if s_find(nm, " ") < 0:
            label = nm
            body = strip(slice(raw, cix + 1, len(raw)))
    if label != "" and body == "":
        return ["label", label]
    if body == "":
        return ["empty", nil]
    let widx = s_find(body, " ")
    var mn = body
    var oper = ""
    if widx >= 0:
        mn = slice(body, 0, widx)
        oper = strip(slice(body, widx + 1, len(body)))
    mn = upper(mn)
    let pm = parse_operand(oper)
    return ["ins", mn, pm[0], pm[1], pm[2], pm[3], label]

proc s_is(s, word):
    return s_start(s, word)

proc parse(lines):
    var out = []
    for raw in lines:
        let t = parse_line(raw)
        let k = t[0]
        if k == "label":
            push(out, [1, t[1]])
        elif k == "ins":
            let lab = t[6]
            if lab != "":
                push(out, [1, lab])
            push(out, [0, t[1], t[2], t[3], t[4], t[5], t[6]])
        elif k == "org":
            push(out, [2, t[1]])
        elif k == "bytes":
            push(out, [3, t[1]])
    return out

proc hexb(v):
    let dig = "0123456789ABCDEF"
    return dig[(v >> 4) & 0xF] + dig[v & 0xF]

## top-level: source lines -> [image, labels]
proc asm(source_lines, base):
    let a = Assembler()
    let parsed = parse(source_lines)
    let img = a.assemble(parsed, base)
    return [img, a.labels]