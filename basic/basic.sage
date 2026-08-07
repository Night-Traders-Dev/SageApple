#########################################################################
## SageApple — Tiny BASIC interpreter (Milestone 8)
##
## A native (Sage) BASIC running on the SageApple OS layer. It reads
## input through `feed(ch)`, keeps a numbered program store, and executes
## PRINT/LET/GOTO/IF/FOR/NEXT/INPUT/LIST/RUN/NEW/END/REM.
## Integer arithmetic; variables are single letters A-Z (or A0-A9).
## Output accumulates in `out`; scripted input for INPUT comes from `inq`.
#########################################################################

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

## ASCII digit/letter tests
proc is_digit(ch):
    let c = ord(ch)
    return c >= 48 and c <= 57
proc is_alpha(ch):
    let c = ord(ch)
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122)

## parse an integer (optional signed) from start of a string
proc atoi(s0):
    var s = strip(s0)
    var neg = 0
    if len(s) > 0 and s[0] == "-":
        neg = 1
        s = slice(s, 1, len(s))
    var v = 0
    var i = 0
    while i < len(s) and is_digit(s[i]):
        v = v * 10 + (ord(s[i]) - 48)
        i = i + 1
    if neg:
        v = 0 - v
    return v

class Basic:
    proc init(self):
        self.prog = []
        self.vars = {}
        self.inq = []
        self.loops = []
        self.out = ""
        self.buf = ""
        self.running = 0
        var i = 0
        while i < 26:
            self.vars["abcdefghijklmnopqrstuvwxyz"[i]] = 0
            i = i + 1

    proc reset_out(self):
        self.out = ""

    ## tokenizer -------------------------------------------------------
    proc tokenize(self, raw0):
        var line = strip(raw0)
        var out = []
        var i = 0
        var n = len(line)
        while i < n:
            let c = line[i]
            if c == " ":
                i = i + 1
            elif c == "\"":
                var s = ""
                i = i + 1
                while i < n and line[i] != "\"":
                    s = s + line[i]
                    i = i + 1
                i = i + 1
                push(out, ["str", s])
            elif is_digit(c):
                var v = 0
                while i < n and is_digit(line[i]):
                    v = v * 10 + (ord(line[i]) - 48)
                    i = i + 1
                push(out, ["num", v])
            elif is_alpha(c):
                var w = ""
                while i < n and (is_alpha(line[i]) or is_digit(line[i])):
                    w = w + line[i]
                    i = i + 1
                push(out, ["id", upper(w)])
            else:
                push(out, ["sym", c])
                i = i + 1
        return out

    ## expression evaluator: [value, newpos]
    proc eval_arith(self, toks, pos):
        return self.eval_add(toks, pos)

    proc eval_add(self, toks, pos):
        let l = self.eval_mul(toks, pos)
        var v = l[0]
        var p = l[1]
        while p < len(toks):
            let t = toks[p]
            if t[0] == "sym" and (t[1] == "+" or t[1] == "-"):
                let r = self.eval_mul(toks, p + 1)
                if t[1] == "+":
                    v = v + r[0]
                else:
                    v = v - r[0]
                p = r[1]
            else:
                break
        return [v, p]

    proc eval_mul(self, toks, pos):
        let l = self.eval_un(toks, pos)
        var v = l[0]
        var p = l[1]
        while p < len(toks):
            let t = toks[p]
            if t[0] == "sym" and (t[1] == "*" or t[1] == "/"):
                let r = self.eval_un(toks, p + 1)
                if t[1] == "*":
                    v = v * r[0]
                else:
                    if r[0] == 0:
                        v = 0
                    else:
                        v = int(v / r[0])
                p = r[1]
            else:
                break
        return [v, p]

    proc eval_un(self, toks, pos):
        if pos < len(toks) and toks[pos][0] == "sym" and toks[pos][1] == "-":
            let r = self.eval_un(toks, pos + 1)
            return [0 - r[0], r[1]]
        return self.eval_atom(toks, pos)

    proc eval_atom(self, toks, pos):
        let t = toks[pos]
        if t[0] == "num":
            return [t[1], pos + 1]
        if t[0] == "sym" and t[1] == "(":
            let e = self.eval_arith(toks, pos + 1)
            if e[1] < len(toks) and toks[e[1]][0] == "sym" and toks[e[1]][1] == ")":
                return [e[0], e[1] + 1]
            return [e[0], e[1]]
        if t[0] == "id":
            return [self.vars[t[1]], pos + 1]
        return [0, pos + 1]

    ## comparison evaluator for IF; returns [value, newpos]
    proc eval_cond(self, toks, pos):
        let l = self.eval_arith(toks, pos)
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
            let r = self.eval_arith(toks, q + 1)
            let a = l[0]
            let b = r[0]
            var res = 0
            if op == "=" or op == "<>":
                if (op == "=" and a == b) or (op == "<>" and a != b):
                    res = 1
            else:
                if op == "<" and a < b:
                    res = 1
                if op == ">" and a > b:
                    res = 1
                if op == "<=" and a <= b:
                    res = 1
                if op == ">=" and a >= b:
                    res = 1
            return [res, r[1]]
        if l[0] != 0:
            return [1, l[1]]
        return [0, l[1]]

    ## statements; exec_line returns one of:
    ##   ["next"], ["end"], ["goto", n], ["jump", ci]
    proc exec_line(self, toks, pos, ci):
        if pos >= len(toks):
            return ["next"]
        let t = toks[pos]
        if t[0] == "num" or t[0] == "str":
            return ["next"]
        if t[0] == "sym":
            if t[1] == ":":
                return self.exec_line(toks, pos + 1, ci)
            return ["next"]
        let w = t[1]
        if w == "PRINT":
            self.do_print(toks, pos + 1)
            return ["next"]
        if w == "LET":
            if pos + 1 < len(toks):
                return self.exec_let(toks, pos + 1, ci)
            return ["next"]
        if w == "GOTO":
            return self.exec_goto(toks, pos + 1)
        if w == "IF":
            return self.exec_if(toks, pos, ci)
        if w == "FOR":
            return self.exec_for(toks, pos, ci)
        if w == "NEXT":
            return self.exec_next(toks, pos)
        if w == "INPUT":
            self.exec_input(toks, pos + 1)
            return ["next"]
        if w == "END" or w == "STOP":
            return ["end"]
        if w == "REM":
            return ["next"]
        return self.exec_let(toks, pos, ci)

    proc exec_let(self, toks, pos, ci):
        if pos < len(toks) and toks[pos][0] == "id" and pos + 1 < len(toks) and toks[pos + 1][0] == "sym" and toks[pos + 1][1] == "=":
            let name = toks[pos][1]
            let e = self.eval_arith(toks, pos + 2)
            self.vars[name] = e[0]
        return ["next"]

    proc exec_goto(self, toks, pos):
        if pos < len(toks) and toks[pos][0] == "num":
            return ["goto", toks[pos][1]]
        return ["next"]

    proc exec_if(self, toks, pos, ci):
        let c = self.eval_cond(toks, pos + 1)
        if c[0] == 0:
            return ["next"]
        let p = c[1]
        if p < len(toks) and toks[p][0] == "id":
            let w = toks[p][1]
            if w == "THEN":
                return self.exec_line(toks, p + 1, ci)
            if w == "GOTO":
                if p + 1 < len(toks) and toks[p + 1][0] == "num":
                    return ["goto", toks[p + 1][1]]
        return ["next"]

    proc exec_for(self, toks, pos, ci):
        # FOR var = e1 TO e2 [STEP e3]
        if pos + 2 < len(toks) and toks[pos + 1][0] == "id":
            let name = toks[pos + 1][1]
            var p = pos + 2
            if p < len(toks) and toks[p][0] == "sym" and toks[p][1] == "=":
                p = p + 1
                let e1 = self.eval_arith(toks, p)
                var step = 1
                var limit = 0
                if e1[1] < len(toks) and toks[e1[1]][0] == "id" and toks[e1[1]][1] == "TO":
                    let e2 = self.eval_arith(toks, e1[1] + 1)
                    limit = e2[0]
                    p = e2[1]
                    if p < len(toks) and toks[p][0] == "id" and toks[p][1] == "STEP":
                        let e3 = self.eval_arith(toks, p + 1)
                        step = e3[0]
                    self.vars[name] = e1[0]
                    if ci >= 0:
                        push(self.loops, [name, limit, step, ci])
            return ["next"]
        return ["next"]

    proc exec_next(self, toks, pos):
        if len(self.loops) == 0:
            return ["next"]
        var name = ""
        if pos + 1 < len(toks) and toks[pos + 1][0] == "id":
            name = toks[pos + 1][1]
        let f = self.loops[len(self.loops) - 1]
        if name != "" and f[0] != name:
            return ["next"]
        self.vars[f[0]] = self.vars[f[0]] + f[2]
        if (f[2] >= 0 and self.vars[f[0]] <= f[1]) or (f[2] < 0 and self.vars[f[0]] >= f[1]):
            return ["jump", f[3] + 1]
        # loop finished: drop the frame
        var newl = []
        var i = 0
        while i < len(self.loops) - 1:
            push(newl, self.loops[i])
            i = i + 1
        self.loops = newl
        return ["next"]

    proc do_print(self, toks, pos):
        var nline = 1
        while pos < len(toks):
            let t = toks[pos]
            if t[0] == "str":
                self.out = self.out + t[1]
                pos = pos + 1
            elif t[0] == "sym" and t[1] == ";":
                nline = 0
                pos = pos + 1
            elif t[0] == "sym" and t[1] == ",":
                self.out = self.out + "    "
                pos = pos + 1
            else:
                let e = self.eval_arith(toks, pos)
                self.out = self.out + intstr(e[0])
                pos = e[1]
        if nline:
            self.out = self.out + "\r\n"

    proc exec_input(self, toks, pos):
        if pos < len(toks) and toks[pos][0] == "id":
            let name = toks[pos][1]
            if len(self.inq) > 0:
                let v = atoi(self.inq[0])
                var newq = []
                var i = 1
                while i < len(self.inq):
                    push(newq, self.inq[i])
                    i = i + 1
                self.inq = newq
                self.vars[name] = v
            else:
                self.vars[name] = 0

    ## program store
    proc set_line(self, n, text):
        var i = 0
        while i < len(self.prog):
            if self.prog[i][0] == n:
                self.prog[i] = [n, text]
                return
            if self.prog[i][0] > n:
                var newp = []
                var j = 0
                while j < i:
                    push(newp, self.prog[j])
                    j = j + 1
                push(newp, [n, text])
                while j < len(self.prog):
                    push(newp, self.prog[j])
                    j = j + 1
                self.prog = newp
                return
            i = i + 1
        push(self.prog, [n, text])

    proc find_line(self, n):
        var i = 0
        while i < len(self.prog):
            if self.prog[i][0] == n:
                return i
            i = i + 1
        return -1

    ## commands
    proc run(self):
        self.running = 1
        self.loops = []
        var ci = 0
        var steps = 0
        while ci < len(self.prog):
            steps = steps + 1
            if steps > 1000000:
                self.out = self.out + "\r\n* RUN TIME OUT\r\n"
                break
            let ln = self.prog[ci]
            let toks = self.tokenize(ln[1])
            let res = self.exec_line(toks, 0, ci)
            if res[0] == "end":
                break
            if res[0] == "goto":
                ci = self.find_line(res[1])
                if ci < 0:
                    self.out = self.out + "\r\nNO LINE " + intstr(res[1]) + "\r\n"
                    break
            elif res[0] == "jump":
                ci = res[1]
            else:
                ci = ci + 1
        self.running = 0
        self.loops = []
        self.out = self.out + "\r\nOK\r\n"

    proc list_prog(self):
        var i = 0
        while i < len(self.prog):
            let ln = self.prog[i]
            self.out = self.out + intstr(ln[0]) + " " + ln[1] + "\r\n"
            i = i + 1
        self.out = self.out + "\r\nOK"

    proc new(self):
        self.prog = []
        self.loops = []
        self.out = self.out + "\r\nOK"

    ## raw character entry (terminal style); '\r' ends a line
    proc feed(self, ch):
        if ch == "\r":
            let line = self.buf
            self.buf = ""
            if self.running == 1:
                push(self.inq, line)
            else:
                self.process_line(line)
        else:
            self.buf = self.buf + ch

    proc process_line(self, line):
        let toks = self.tokenize(line)
        if len(toks) == 0:
            self.out = self.out + "\r\n>"
            return
        let f = toks[0]
        if f[0] == "num":
            var k = 0
            while k < len(line) and line[k] == " ":
                k = k + 1
            while k < len(line) and is_digit(line[k]):
                k = k + 1
            self.set_line(f[1], strip(slice(line, k, len(line))))
            return
        let w = f[1]
        if w == "RUN":
            self.run()
            return
        if w == "LIST":
            self.list_prog()
            return
        if w == "NEW":
            self.new()
            return
        if w == "PRINT":
            self.do_print(toks, 1)
            return
        self.loops = []
        let res = self.exec_line(toks, 0, -1)
        if res[0] == "goto":
            self.out = self.out + "\r\nGOTO " + intstr(res[1]) + "\r\n"

    ## feed a whole line (char by char + CR), terminal style
    proc input_line(self, s):
        var i = 0
        while i < len(s):
            self.feed(s[i])
            i = i + 1
        self.feed("\r")