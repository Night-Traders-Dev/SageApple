#########################################################################
## SageApple — 6502 compiler backend (Milestone 9)
##
## Lowers a numbered BASIC program (same tokenizer as M8) to standalone
## 6502 machine code.  Variables A-Z live in zero page $20-$3E;
## expressions are evaluated in A using ZP temporaries $7C/$7E with the
## runtime's helpers for multiply/divide.  Statements compiled:
##   PRINT (expr / string / blank, optional ';'), LET, GOTO, IF/THEN
##   (relational and numeric), END/STOP, REM.
## A small runtime block is appended: UART output, decimal printing,
## string printing, 8x8 multiply, 8-bit divide.
##
##   compile(prog_lines, base) -> [image_bytes, halt_pc]
##   (program assembled at `base`, e.g. $0300 in RAM; run the image there)
#########################################################################

import basic.basic
import compiler.asm6502

var _tk = basic.Basic()            # tokenizer instance (M8)

proc hex2(v):
    let dig = "0123456789ABCDEF"
    return dig[(v >> 4) & 0xF] + dig[v & 0xF]

proc hex4(v):
    return hex2((v >> 8) & 0xFF) + hex2(v & 0xFF)

proc var_addr(name):
    return 0x20 + (ord(name) - 65)

## ---------------- expression parsing -> AST --------------------------
## AST nodes: ["num", v] ["var", name] ["neg", x] ["bin", op, l, r]
##            ["cmp", op, l, r] (only from parse_cond)
proc parse_expr(toks, pos):
    return parse_add(toks, pos)

proc parse_add(toks, pos):
    let l = parse_mul(toks, pos)
    var v = l[0]
    var p = l[1]
    while p < len(toks):
        let t = toks[p]
        if t[0] == "sym" and (t[1] == "+" or t[1] == "-"):
            let r = parse_mul(toks, p + 1)
            v = ["bin", t[1], v, r[0]]
            p = r[1]
        else:
            break
    return [v, p]

proc parse_mul(toks, pos):
    let l = parse_un(toks, pos)
    var v = l[0]
    var p = l[1]
    while p < len(toks):
        let t = toks[p]
        if t[0] == "sym" and (t[1] == "*" or t[1] == "/"):
            let r = parse_un(toks, p + 1)
            v = ["bin", t[1], v, r[0]]
            p = r[1]
        else:
            break
    return [v, p]

proc parse_un(toks, pos):
    if pos < len(toks) and toks[pos][0] == "sym" and toks[pos][1] == "-":
        let r = parse_un(toks, pos + 1)
        return [["neg", r[0]], r[1]]
    return parse_atom(toks, pos)

proc parse_atom(toks, pos):
    let t = toks[pos]
    if t[0] == "num":
        return [["num", t[1]], pos + 1]
    if t[0] == "sym" and t[1] == "(":
        let e = parse_expr(toks, pos + 1)
        if e[1] < len(toks) and toks[e[1]][0] == "sym" and toks[e[1]][1] == ")":
            return [e[0], e[1] + 1]
        return [e[0], e[1]]
    if t[0] == "id":
        return [["var", t[1]], pos + 1]
    return [["num", 0], pos + 1]

## condition parser: plain expr AST, or ["cmp", op, l, r]
proc parse_cond(toks, pos):
    let l = parse_expr(toks, pos)
    var op = ""
    var q = l[1]
    if q < len(toks) and toks[q][0] == "sym":
        let s1 = toks[q][1]
        if s1 == "=":
            op = "="
        elif s1 == "<":
            if q + 1 < len(toks) and toks[q + 1][0] == "sym" and toks[q + 1][1] == "=":
                op = "<="
                q = q + 1
            elif q + 1 < len(toks) and toks[q + 1][0] == "sym" and toks[q + 1][1] == ">":
                op = "<>"
                q = q + 1
            else:
                op = "<"
        elif s1 == ">":
            if q + 1 < len(toks) and toks[q + 1][0] == "sym" and toks[q + 1][1] == "=":
                op = ">="
                q = q + 1
            else:
                op = ">"
    if op != "":
        let r = parse_expr(toks, q + 1)
        return [["cmp", op, l[0], r[0]], r[1]]
    return [l[0], l[1]]

## ----------------------- code generator ------------------------------
class Compiler:
    proc init(self):
        self.src = []
        self.strs = []
        self.stridx = 0
        self.lns = []
        self.cnt = 0

    proc em(self, line):
        push(self.src, line)

    proc nlabel(self):
        let n = "F" + basic.intstr(self.cnt)
        self.cnt = self.cnt + 1
        return n

    proc has_line(self, n):
        var i = 0
        while i < len(self.lns):
            if self.lns[i] == n:
                return true
            i = i + 1
        return false

    ## ---------------- top level --------------------------------------
    proc compile(self, progsrc, base):
        # de-duplicate by line number (last wins), then sort ascending
        var map = {}
        var i = 0
        while i < len(progsrc):
            let toks = _tk.tokenize(progsrc[i])
            if len(toks) > 0 and toks[0][0] == "num":
                var body = []
                var k = 1
                while k < len(toks):
                    push(body, toks[k])
                    k = k + 1
                map[basic.intstr(toks[0][1])] = body
            i = i + 1
        var lines = []
        # collect keys (list of [n, toks])
        var keys = []
        var ik = 0
        for k in map:
            push(keys, k)
            ik = ik + 1
        # sort keys numerically
        var sorted = []
        while len(keys) > 0:
            var best = keys[0]
            var bi = 0
            var j = 1
            while j < len(keys):
                if basic.atoi(keys[j]) < basic.atoi(best):
                    best = keys[j]
                    bi = j
                j = j + 1
            var rem = []
            var k2 = 0
            while k2 < len(keys):
                if k2 != bi:
                    push(rem, keys[k2])
                k2 = k2 + 1
            keys = rem
            push(sorted, best)
        i = 0
        while i < len(sorted):
            let n = basic.atoi(sorted[i])
            push(lines, [n, map[sorted[i]]])
            push(self.lns, n)
            i = i + 1

        self.em("org $" + hex4(base))
        i = 0
        while i < len(lines):
            let ln = lines[i]
            self.em("L" + basic.intstr(ln[0]) + ":")
            if len(ln[1]) > 0:
                self.gen_stmt(ln[1], 0)
            i = i + 1
        self.em("HALT:")
        self.em("    JMP HALT")
        self.runtime()
        # string data (after HALT, never executed)
        i = 0
        while i < len(self.strs):
            let sd = self.strs[i]
            self.em(sd[0] + ":")
            var b = ""
            var j = 0
            while j < len(sd[1]):
                b = b + hex2(ord(sd[1][j])) + ","
                j = j + 1
            self.em(".byte " + b + "00")
            i = i + 1
        let res = asm6502.asm(self.src, base)
        let halt = res[1]["HALT"]
        return [res[0], halt, res[1]]

    ## ---------------- statements -------------------------------------
    proc gen_stmt(self, toks, pos):
        if pos >= len(toks):
            return
        let t = toks[pos]
        if t[0] == "num":
            return
        let w = t[1]
        if w == "PRINT":
            self.gen_print(toks, pos + 1)
        elif w == "LET":
            self.gen_let(toks, pos + 1)
        elif w == "GOTO":
            self.gen_goto(toks, pos + 1)
        elif w == "IF":
            self.gen_if(toks, pos + 1)
        elif w == "END" or w == "STOP":
            self.em("    JMP HALT")
        else:
            self.gen_let(toks, pos)

    proc gen_let(self, toks, pos):
        if pos < len(toks) and toks[pos][0] == "id" and pos + 1 < len(toks) and toks[pos + 1][0] == "sym" and toks[pos + 1][1] == "=":
            let e = parse_expr(toks, pos + 2)
            self.gen_expr(e[0])
            self.em("    STA $" + hex2(var_addr(toks[pos][1])))

    proc gen_goto(self, toks, pos):
        if pos < len(toks) and toks[pos][0] == "num":
            let n = toks[pos][1]
            if self.has_line(n):
                self.em("    JMP L" + basic.intstr(n))
            else:
                self.em("    LDA #$3F")
                self.em("    JSR R_OUT")
                self.em("    JMP HALT")

    proc gen_print(self, toks, pos):
        var items = []
        var semi = 0
        var p = pos
        while p < len(toks):
            let t = toks[p]
            if t[0] == "str":
                let lab = "S" + basic.intstr(self.stridx)
                self.stridx = self.stridx + 1
                push(items, ["s", lab])
                push(self.strs, [lab, t[1]])
                p = p + 1
            elif t[0] == "sym" and t[1] == ";":
                semi = 1
                p = p + 1
            else:
                let e = parse_expr(toks, p)
                push(items, ["e", e[0]])
                p = e[1]
        var k = 0
        while k < len(items):
            let it = items[k]
            if it[0] == "e":
                self.gen_expr(it[1])
                self.em("    JSR R_PRINT2")
            else:
                self.em("    LDA #<" + it[1])
                self.em("    STA $10")
                self.em("    LDA #>" + it[1])
                self.em("    STA $11")
                self.em("    JSR R_PSTR")
            k = k + 1
        if semi == 0:
            self.em("    JSR R_CRLF")

    proc gen_if(self, toks, pos):
        let c = parse_cond(toks, pos)
        var p = c[1]
        if p < len(toks) and toks[p][0] == "id" and toks[p][1] == "THEN":
            p = p + 1
        if p < len(toks) and toks[p][0] == "id" and toks[p][1] == "GOTO":
            if p + 1 < len(toks) and toks[p + 1][0] == "num":
                let n = toks[p + 1][1]
                if self.has_line(n):
                    self.gen_cond_jump(c[0], "L" + basic.intstr(n))
                else:
                    self.gen_cond_jump(c[0], "HALT")
                return
        let sk = self.nlabel()
        self.gen_cond_skip(c[0], sk)
        if p < len(toks):
            self.gen_stmt(toks, p)
        self.em(sk + ":")

    ## condition that jumps to `target` when true
    proc gen_cond_jump(self, cond, target):
        if cond[0] == "cmp":
            self.gen_cmp(cond)
            let sk = self.nlabel()
            let op = cond[1]
            if op == "=":
                self.em("    BNE " + sk)
            elif op == "<>":
                self.em("    BEQ " + sk)
            elif op == "<":
                self.em("    BCS " + sk)
            elif op == ">=":
                self.em("    BCC " + sk)
            elif op == ">":
                self.em("    BCC " + sk)
                self.em("    BEQ " + sk)
            else:
                self.em("    BCS " + sk)
                self.em("    BEQ " + sk)
            self.em("    JMP " + target)
            self.em(sk + ":")
        else:
            self.gen_expr(cond)
            let sk = self.nlabel()
            self.em("    BEQ " + sk)
            self.em("    JMP " + target)
            self.em(sk + ":")

    ## condition that skips to `sk` when false (true falls through)
    proc gen_cond_skip(self, cond, sk):
        if cond[0] == "cmp":
            self.gen_cmp(cond)
            let op = cond[1]
            if op == "=":
                self.em("    BNE " + sk)
            elif op == "<>":
                self.em("    BEQ " + sk)
            elif op == "<":
                self.em("    BCS " + sk)
            elif op == ">=":
                self.em("    BCC " + sk)
            elif op == ">":
                self.em("    BCC " + sk)
                self.em("    BEQ " + sk)
            else:
                self.em("    BCS " + sk)
                self.em("    BEQ " + sk)
        else:
            self.gen_expr(cond)
            self.em("    BEQ " + sk)

    ## compare left vs right: Z set if equal, C set if left >= right
    proc gen_cmp(self, cond):
        self.gen_expr(cond[2])
        self.em("    STA $7C")
        self.gen_expr(cond[3])
        self.em("    STA $7E")
        self.em("    LDA $7C")
        self.em("    SEC")
        self.em("    SBC $7E")

    ## ---------------- expressions (result in A) ----------------------
    proc gen_expr(self, a):
        let k = a[0]
        if k == "num":
            self.em("    LDA #$" + hex2(a[1] & 0xFF))
        elif k == "var":
            self.em("    LDA $" + hex2(var_addr(a[1])))
        elif k == "neg":
            self.gen_expr(a[1])
            self.em("    EOR #$FF")
            self.em("    CLC")
            self.em("    ADC #$01")
        else:
            let op = a[1]
            self.gen_expr(a[2])
            self.em("    STA $7C")
            self.gen_expr(a[3])
            if op == "+":
                self.em("    CLC")
                self.em("    ADC $7C")
            elif op == "-":
                self.em("    STA $7E")
                self.em("    LDA $7C")
                self.em("    SEC")
                self.em("    SBC $7E")
            elif op == "*":
                self.em("    STA $7E")
                self.em("    LDA $7C")
                self.em("    JSR R_MUL")
            else:
                self.em("    STA $7E")
                self.em("    LDA $7C")
                self.em("    JSR R_DIV")

    ## ---------------- runtime helpers --------------------------------
    proc runtime(self):
        self.em("; runtime")
        self.em("R_OUT:")
        self.em("    PHA")
        self.em("R_OUTW:")
        self.em("    LDA $2000")
        self.em("    AND #$02")
        self.em("    BEQ R_OUTW")
        self.em("    PLA")
        self.em("    STA $2001")
        self.em("    RTS")
        self.em("")
        self.em("R_PSTR:")
        self.em("    LDY #$00")
        self.em("R_PSTR_L:")
        self.em("    LDA ($10),Y")
        self.em("    BEQ R_PSTR_D")
        self.em("    JSR R_OUT")
        self.em("    INY")
        self.em("    JMP R_PSTR_L")
        self.em("R_PSTR_D:")
        self.em("    RTS")
        self.em("")
        self.em("R_PRINT2:")
        self.em("    STA $7F")
        self.em("    LDA $7F")
        self.em("    BNE R_PN_GT")
        self.em("    LDA #$30")
        self.em("    JSR R_OUT")
        self.em("    RTS")
        self.em("R_PN_GT:")
        self.em("    LDA #$00")
        self.em("    STA $7C")
        self.em("    LDA $7F")
        self.em("R_PN_H:")
        self.em("    CMP #$64")
        self.em("    BCC R_PN_T")
        self.em("    SEC")
        self.em("    SBC #$64")
        self.em("    INC $7C")
        self.em("    JMP R_PN_H")
        self.em("R_PN_T:")
        self.em("    STA $7F")
        self.em("    LDX #$00")
        self.em("R_PN_T2:")
        self.em("    CMP #$0A")
        self.em("    BCC R_PN_O")
        self.em("    SEC")
        self.em("    SBC #$0A")
        self.em("    INX")
        self.em("    JMP R_PN_T2")
        self.em("R_PN_O:")
        self.em("    STA $7D")
        self.em("    STX $7E")
        self.em("    LDA $7C")
        self.em("    BNE R_PN_A")
        self.em("    LDA $7E")
        self.em("    BNE R_PN_B")
        self.em("    LDA $7D")
        self.em("    JMP R_PN_C")
        self.em("R_PN_A:")
        self.em("    LDA $7C")
        self.em("    JSR R_PN_D")
        self.em("    LDA $7E")
        self.em("    JSR R_PN_D")
        self.em("    LDA $7D")
        self.em("    JMP R_PN_C")
        self.em("R_PN_B:")
        self.em("    LDA $7E")
        self.em("    JSR R_PN_D")
        self.em("    LDA $7D")
        self.em("R_PN_C:")
        self.em("    JSR R_PN_D")
        self.em("    RTS")
        self.em("R_PN_D:")
        self.em("    CLC")
        self.em("    ADC #$30")
        self.em("    JMP R_OUT")
        self.em("")
        self.em("R_CRLF:")
        self.em("    LDA #$0D")
        self.em("    JSR R_OUT")
        self.em("    LDA #$0A")
        self.em("    JMP R_OUT")
        self.em("")
        self.em("R_MUL:")
        self.em("    STA $1A")
        self.em("    LDA #$00")
        self.em("    STA $1B")
        self.em("    LDA #$08")
        self.em("    STA $1C")
        self.em("R_M1:")
        self.em("    LSR $1A")
        self.em("    BCC R_M2")
        self.em("    LDA $1B")
        self.em("    CLC")
        self.em("    ADC $7E")
        self.em("    STA $1B")
        self.em("R_M2:")
        self.em("    ASL $7E")
        self.em("    DEC $1C")
        self.em("    BNE R_M1")
        self.em("    LDA $1B")
        self.em("    RTS")
        self.em("")
        self.em("R_DIV:")
        self.em("    LDA $7E")
        self.em("    BNE R_DV0")
        self.em("    LDA #$00")
        self.em("    RTS")
        self.em("R_DV0:")
        self.em("    LDA $7C")
        self.em("    LDX #$00")
        self.em("R_DV2:")
        self.em("    CMP $7E")
        self.em("    BCC R_DV3")
        self.em("    SEC")
        self.em("    SBC $7E")
        self.em("    INX")
        self.em("    JMP R_DV2")
        self.em("R_DV3:")
        self.em("    TXA")
        self.em("    RTS")
