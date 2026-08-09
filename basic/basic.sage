#########################################################################
## SageApple — Applesoft BASIC interpreter (host, PLAN.md M13)
##
## A faithful-enough Applesoft II implementation in SageLang: floating
## point 9-digit arithmetic, string vars (A$), arrays (DIM), DEF FN,
## FOR/NEXT, GOSUB/RETURN, ONERR, READ/DATA/RESTORE, INPUT/GET, PEEK/
## POKE/CALL, graphics statements (HGR/GR/HPLOT/PLOT/...), DOS hooks
## (PRINT CHR$(4) + OPEN/READ/WRITE buffers), and the SageApple BEEP
## extension.  Output accumulates in `out`; scripted INPUT uses `inq`.
#########################################################################

import math
import sageapple.graphics

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

## parse a leading decimal integer
proc atoi(s):
    var v = 0
    var i = 0
    while i < len(s) and s[i] >= "0" and s[i] <= "9":
        v = v * 10 + (ord(s[i]) - 48)
        i = i + 1
    return v

## parse a whole decimal number, nil if it does not parse cleanly
proc _num_parse(s):
    let s2 = strip(s)
    if s2 == "":
        return nil
    var i = 0
    var neg = false
    if s2[0] == "-":
        neg = true
        i = 1
    elif s2[0] == "+":
        i = 1
    var v = 0.0
    var seen = false
    while i < len(s2) and s2[i] >= "0" and s2[i] <= "9":
        v = v * 10 + (ord(s2[i]) - 48)
        i = i + 1
        seen = true
    if i < len(s2) and s2[i] == ".":
        i = i + 1
        var fd = 10.0
        while i < len(s2) and s2[i] >= "0" and s2[i] <= "9":
            v = v + (ord(s2[i]) - 48) / fd
            fd = fd * 10.0
            i = i + 1
        seen = true
    if i < len(s2) and (s2[i] == "E" or s2[i] == "e"):
        i = i + 1
        var eneg = false
        if i < len(s2) and s2[i] == "-":
            eneg = true
            i = i + 1
        elif i < len(s2) and s2[i] == "+":
            i = i + 1
        var e = 0
        while i < len(s2) and s2[i] >= "0" and s2[i] <= "9":
            e = e * 10 + (ord(s2[i]) - 48)
            i = i + 1
        if eneg:
            e = 0 - e
        v = v * math.pow(10.0, e)
    if i < len(s2):
        return nil
    if seen == false:
        return nil
    if neg:
        v = 0 - v
    return v

## ---- Applesoft number formatting (9 significant digits) ----
let _SCI_MIN = 0.01
let _SCI_MAX = 1.0e9

proc fmt_num(v):
    if v == 0:
        return "0"
    if v < 0:
        return "-" + fmt_num(0 - v)
    if v >= _SCI_MAX:
        return _fmt_sci(v)
    let exp = math.floor(math.log10(v))
    if exp < -2:
        return _fmt_sci(v)
    var dec = 8 - exp
    if dec < 0:
        dec = 0
    let m = math.pow(10.0, dec)
    let rv = math.floor(v * m + 0.5) / m
    if rv >= _SCI_MAX:
        return _fmt_sci(rv)
    let ip = int(math.floor(rv))
    var s = intstr(ip)
    if dec > 0:
        let frac = int(math.floor(rv * m + 0.5)) - ip * int(m)
        if frac > 0:
            var fs = intstr(frac)
            while len(fs) < dec:
                fs = "0" + fs
            while len(fs) > 0 and fs[len(fs) - 1] == "0":
                fs = slice(fs, 0, len(fs) - 1)
            if fs != "":
                s = s + "." + fs
    return s

proc _fmt_sci(v):
    var av = v
    if av < 0:
        av = 0 - av
    var exp = int(math.floor(math.log10(av)))
    var man = av / math.pow(10.0, exp)
    let m = 1.0e8
    var r = math.floor(man * m + 0.5) / m
    if r >= 10.0:
        r = r / 10.0
        exp = exp + 1
    var ms = intstr(int(math.floor(r)))
    let frac = int(math.floor(r * m + 0.5)) - int(math.floor(r)) * 100000000
    if frac > 0:
        var fs = intstr(frac)
        while len(fs) < 8:
            fs = "0" + fs
        while len(fs) > 0 and fs[len(fs) - 1] == "0":
            fs = slice(fs, 0, len(fs) - 1)
        ms = ms + "." + fs
    var es = intstr(exp)
    if exp < 0:
        es = "-" + intstr(0 - exp)
    else:
        es = "+" + intstr(exp)
    while len(es) < 3:
        es = es[0] + "0" + slice(es, 1, len(es))
    if v < 0:
        return "-" + ms + "E" + es
    return ms + "E" + es

## ---- error codes (PEEK(222)) ----
let ER_NEXT_WITHOUT_FOR = 0
let ER_SYNTAX = 1
let ER_RETURN_WITHOUT_GOSUB = 2
let ER_OUT_OF_DATA = 3
let ER_ILLEGAL_QUANTITY = 4
let ER_OVERFLOW = 5
let ER_OUT_OF_MEMORY = 6
let ER_UNDEFD_STATEMENT = 7
let ER_BAD_SUBSCRIPT = 8
let ER_REDIMD_ARRAY = 9
let ER_DIVISION_BY_ZERO = 10
let ER_TYPE_MISMATCH = 11
let ER_STRING_TOO_LONG = 12
let ER_FORMULA_TOO_COMPLEX = 13
let ER_CANT_CONTINUE = 14
let ER_UNDEFD_FUNCTION = 15
let ER_END_OF_DATA = 16

let _ERR_TEXT = [
    "NEXT WITHOUT FOR",
    "SYNTAX",
    "RETURN WITHOUT GOSUB",
    "OUT OF DATA",
    "ILLEGAL QUANTITY",
    "OVERFLOW",
    "OUT OF MEMORY",
    "UNDEF'D STATEMENT",
    "BAD SUBSCRIPT",
    "REDIM'D ARRAY",
    "DIVISION BY ZERO",
    "TYPE MISMATCH",
    "STRING TOO LONG",
    "FORMULA TOO COMPLEX",
    "CAN'T CONTINUE",
    "UNDEF'D FUNCTION",
    "END OF DATA"]

## ---- tokenizer: [type, value]  n=number(s float) s=string i=ident o=op ----
proc _is_digit(c):
    return c >= "0" and c <= "9"

proc _is_alpha(c):
    let o = ord(c)
    return (o >= 65 and o <= 90) or (o >= 97 and o <= 122)

proc _tok(s):
    let t = []
    var i = 0
    let n = len(s)
    while i < n:
        let c = s[i]
        if c == " ":
            i = i + 1
        elif _is_digit(c) or (c == "." and i + 1 < n and _is_digit(s[i + 1])):
            var v = 0.0
            var fd = 1.0
            var seen = false
            while i < n and (_is_digit(s[i]) or s[i] == "."):
                if s[i] == ".":
                    fd = 10.0
                elif fd == 1.0:
                    v = v * 10.0 + (ord(s[i]) - 48)
                else:
                    v = v + (ord(s[i]) - 48) / fd
                    fd = fd * 10.0
                seen = true
                i = i + 1
            if seen:
                if i < n and (s[i] == "E" or s[i] == "e"):
                    var j = i + 1
                    var sg = 1.0
                    if j < n and (s[j] == "-" or s[j] == "+"):
                        if s[j] == "-":
                            sg = -1.0
                        j = j + 1
                    if j < n and _is_digit(s[j]):
                        var ev = 0.0
                        while j < n and _is_digit(s[j]):
                            ev = ev * 10.0 + (ord(s[j]) - 48)
                            j = j + 1
                        v = v * math.pow(10.0, sg * ev)
                        i = j
                push(t, ["n", v])
        elif c == "\"":
            var st = ""
            i = i + 1
            while i < n and s[i] != "\"":
                st = st + s[i]
                i = i + 1
            i = i + 1
            push(t, ["s", st])
        elif _is_alpha(c):
            var id = ""
            while i < n and (_is_alpha(s[i]) or _is_digit(s[i]) or s[i] == "$" or s[i] == "%" or s[i] == "#"):
                id = id + s[i]
                i = i + 1
            if id == "?":
                push(t, ["i", "PRINT"])
            else:
                push(t, ["i", upper(id)])
        elif c == "<" or c == ">" or c == "=":
            if i + 1 < n and (s[i + 1] == "=" or (c == "<" and s[i + 1] == ">") or (c == ">" and s[i + 1] == "<")):
                push(t, ["o", slice(s, i, i + 2)])
                i = i + 2
            else:
                push(t, ["o", c])
                i = i + 1
        else:
            push(t, ["o", c])
            i = i + 1
    return t

#########################################################################
## the interpreter
#########################################################################

class Basic:
    proc init(self):
        self.prog = []
        self.out = ""
        self.running = 0
        self.sus = false
        self.immed = 0
        self.toks = []
        self.pos = 0
        self.ci = 0
        self.vars = {}
        self.arrs = {}
        self.fn_defs = {}
        self.data = []
        self.di = 0
        self.item_off = 0
        self.gstack = []
        self.forst = []
        self.inq = []
        self.awaiting = []
        self.speaker = nil
        self.machine = nil
        self.dos = nil
        self.onerr = 0
        self.onerr_ln = 0
        self.err_code = 0
        self.err_ln = 0
        self.err_ci = -1
        self.ex_err = -1
        self.trace_on = 0
        self.called_monitor = false
        self.stopped = false
        self.stopped_ci = 0
        self.stopped_pos = 0
        self.print_col = 0
        self.rnd_seed = 1
        self.gmode = 0
        self.hcolor = 3
        self.color = 7
        self.hgr_page = []
        self.gr_page = []
        self._RUN_GUARD = 200000

    proc reset_out(self):
        self.out = ""

    proc drain(self):
        let s = self.out
        self.out = ""
        return s

    ## ---- program store ----
    proc new(self):
        self.prog = []
        self.vars = {}
        self.arrs = {}
        self.fn_defs = {}
        self.running = 0
        self.sus = false
        self.awaiting = []

    proc find_ci(self, ln):
        var i = 0
        while i < len(self.prog):
            if self.prog[i][0] == ln:
                return i
            i = i + 1
        return -1

    proc set_line(self, num, text):
        var i = self.find_ci(num)
        let txt = strip(text)
        if i >= 0:
            if txt == "":
                let np = []
                var k = 0
                while k < len(self.prog):
                    if k != i:
                        push(np, self.prog[k])
                    k = k + 1
                self.prog = np
            else:
                self.prog[i][1] = txt
            return
        if txt == "":
            return
        var ins = []
        var done = false
        var k = 0
        while k < len(self.prog):
            if self.prog[k][0] > num and done == false:
                push(ins, [num, txt])
                done = true
            push(ins, self.prog[k])
            k = k + 1
        if done == false:
            push(ins, [num, txt])
        self.prog = ins

    ## ---- errors ----
    proc _raise(self, code):
        self.err_code = code
        if self.ci >= 0 and self.ci < len(self.prog):
            self.err_ln = self.prog[self.ci][0]
            self.err_ci = self.ci
        if self.machine != nil:
            self.machine.bus.write8(222, code & 0xFF)
            self.machine.bus.write8(218, self.err_ln & 0xFF)
            self.machine.bus.write8(219, (self.err_ln >> 8) & 0xFF)
        if self.onerr:
            self.onerr = 0
            let gi = self.find_ci(self.onerr_ln)
            if gi < 0:
                self.running = 0
                self.out = self.out + "?UNDEF'D STATEMENT ERROR IN " + intstr(self.err_ln) + "\r\n"
                return ["err"]
            self.ci = gi
            self.toks = []
            self.pos = 0
            return ["reset", 0]
        self.running = 0
        var msg = "?" + _ERR_TEXT[code] + " ERROR"
        if len(self.prog) > 0:
            msg = msg + " IN " + intstr(self.err_ln)
        self.out = self.out + msg + "\r\n"
        return ["err"]

    proc _syntax(self):
        return self._raise(ER_SYNTAX)

    proc _type_err(self):
        return self._raise(ER_TYPE_MISMATCH)

    proc _qty_err(self):
        return self._raise(ER_ILLEGAL_QUANTITY)

    proc _sub_err(self):
        return self._raise(ER_BAD_SUBSCRIPT)

    ## evaluator errors (set ex_err, clear, return runner result)
    proc _err_res(self):
        let c = self.ex_err
        self.ex_err = -1
        return self._raise(c)

    ## ---- runner ----
    proc run(self):
        self._start_run(0)

    proc run_at(self, ln):
        let i = self.find_ci(ln)
        if i < 0:
            self.out = self.out + "?UNDEF'D STATEMENT ERROR\r\n"
            return
        self._start_run(i)

    proc _start_run(self, ci):
        self.running = 1
        self.sus = false
        self.immed = 0
        self.ci = ci
        self.toks = []
        self.pos = 0
        self.awaiting = []
        self.gstack = []
        self.forst = []
        self.onerr = 0
        self.vars = {}
        self.arrs = {}
        self.fn_defs = {}
        self.data = []
        var i = 0
        while i < len(self.prog):
            let toks = _tok(self.prog[i][1])
            var j = 0
            while j < len(toks):
                if toks[j][0] == "i" and toks[j][1] == "DATA":
                    push(self.data, [self.prog[i][0], i, j])
                j = j + 1
            i = i + 1
        self.di = 0
        self.item_off = 0
        self._advance()

    proc _after(self, pos):
        while pos < len(self.toks) and self.toks[pos][0] == "o" and self.toks[pos][1] == ":":
            pos = pos + 1
        return pos

    proc _advance(self):
        var steps = 0
        while self.running:
            steps = steps + 1
            if steps > self._RUN_GUARD:
                self._raise(ER_FORMULA_TOO_COMPLEX)
                break
            if self.ci < 0 or self.ci >= len(self.prog):
                self.running = 0
                self._render_gfx()
                break
            if len(self.toks) == 0:
                self.toks = _tok(self.prog[self.ci][1])
                self.pos = 0
                if self.trace_on:
                    self.out = self.out + "#" + intstr(self.prog[self.ci][0])
            let res = self._exec_stmt()
            let code = res[0]
            if code == "next":
                self.pos = res[1]
                if self.pos >= len(self.toks):
                    self.toks = []
                    self.ci = self.ci + 1
            elif code == "goto":
                let g = self.find_ci(res[1])
                if g < 0:
                    self._raise(ER_UNDEFD_STATEMENT)
                    break
                self.ci = g
                self.toks = []
            elif code == "end":
                self.running = 0
                self._render_gfx()
            elif code == "stop":
                self.running = 0
            elif code == "err":
                break
            elif code == "input":
                self.pos = res[1]
                if len(self.inq) > 0:
                    let l = self.inq[0]
                    let nl = []
                    var k = 1
                    while k < len(self.inq):
                        push(nl, self.inq[k])
                        k = k + 1
                    self.inq = nl
                    self._feed(l)
                    if self.sus:
                        break
                else:
                    self.sus = true
                    break
            elif code == "repeat":
                if res[1] >= len(self.prog):
                    self.running = 0
                    break
                self.ci = res[1]
                self.toks = _tok(self.prog[self.ci][1])
                self.pos = res[2]
            elif code == "reset":
                self.toks = _tok(self.prog[self.ci][1])
                self.pos = res[1]
            elif code == "mon":
                self.running = 0
                self.called_monitor = true
                break
            else:
                break

    ## execute one immediate line (self.toks already set)
    proc _run_line(self):
        let lt = self.toks
        var steps = 0
        while steps < 1000:
            steps = steps + 1
            self.toks = lt
            let res = self._exec_stmt()
            let code = res[0]
            if code == "next":
                self.pos = res[1]
                if self.pos >= len(lt):
                    return
            elif code == "goto":
                let g = self.find_ci(res[1])
                if g < 0:
                    self._raise(ER_UNDEFD_STATEMENT)
                    return
                self.running = 1
                self.immed = 0
                self.ci = g
                self.toks = []
                self._advance()
                return
            elif code == "input":
                self.pos = res[1]
                if len(self.inq) > 0:
                    let l = self.inq[0]
                    let nl = []
                    var k = 1
                    while k < len(self.inq):
                        push(nl, self.inq[k])
                        k = k + 1
                    self.inq = nl
                    self._feed(l)
                    if self.sus:
                        return
                else:
                    self.sus = true
                    return
            elif code == "repeat":
                return
            elif code == "err":
                return
            elif code == "mon":
                self.called_monitor = true
                return
            elif code == "run":
                return
            elif code == "end":
                self._render_gfx()
                return
            else:
                return

    ## ---- input feeding (INPUT/GET) ----
    proc _feed(self, text):
        var s = text
        if len(s) > 0 and s[len(s) - 1] == "\r":
            s = slice(s, 0, len(s) - 1)
        var guard = 0
        while len(self.awaiting) > 0 and guard < 100:
            guard = guard + 1
            let req = self.awaiting[0]
            let kind = req[0]
            let name = req[1]
            let is_str = endswith(name, "$")
            if kind == "GET":
                if len(s) == 0:
                    return
                if is_str:
                    self.vars[lower(name)] = s[0]
                else:
                    self.vars[lower(name)] = ord(s[0]) * 1.0
                self.awaiting = slice(self.awaiting, 1, len(self.awaiting))
                s = slice(s, 1, len(s))
            else:
                var piece = s
                var rest = ""
                var ci = 0
                while ci < len(s) and s[ci] != ",":
                    ci = ci + 1
                if ci < len(s):
                    piece = slice(s, 0, ci)
                    rest = slice(s, ci + 1, len(s))
                if is_str:
                    let p2 = strip(piece)
                    if len(p2) >= 2 and p2[0] == "\"" and p2[len(p2) - 1] == "\"":
                        self.vars[lower(name)] = slice(p2, 1, len(p2) - 1)
                    else:
                        self.vars[lower(name)] = p2
                else:
                    let nv = _num_parse(piece)
                    if nv == nil:
                        self.out = self.out + "?REDO FROM START\r\n??"
                        return
                    self.vars[lower(name)] = nv
                self.awaiting = slice(self.awaiting, 1, len(self.awaiting))
                s = rest
                if len(self.awaiting) > 0 and self.awaiting[0][0] == "INPUT" and s == "":
                    self.out = self.out + "??"
                    return
        self.sus = false
        if self.immed:
            self.immed = 0
            self._run_line()
        elif self.running:
            self._advance()
        else:
            self._advance()

    ## ---- public entry ----
    proc input_line(self, line):
        let s = strip(line)
        if s == "":
            return
        if self.sus:
            self._feed(s)
            return
        var i = 0
        while i < len(s) and _is_digit(s[i]):
            i = i + 1
        if i > 0:
            let num = atoi(slice(s, 0, i))
            var text = slice(s, i, len(s))
            if len(text) > 0 and text[0] == " ":
                text = slice(text, 1, len(text))
            self.set_line(num, text)
            return
        self.toks = _tok(s)
        self.pos = 0
        self.ci = 0
        self.immed = 1
        self._run_line()
        self.immed = 0

    ## ---- variable helpers ----
    proc _numvar(self, key):
        if self.vars[key] != nil:
            return self.vars[key]
        return 0.0

    proc _strvar(self, key):
        if self.vars[key] != nil:
            return self.vars[key]
        return ""

    proc _arr_set(self, key, idx, value):
        if idx < 0 or idx > 255:
            self.ex_err = ER_BAD_SUBSCRIPT
            return
        let ii = int(idx)
        if self.arrs[key] != nil == false:
            let arr = []
            var k = 0
            while k < 11:
                if endswith(key, "$"):
                    push(arr, "")
                else:
                    push(arr, 0.0)
                k = k + 1
            self.arrs[key] = arr
        let arr = self.arrs[key]
        if ii >= len(arr):
            self.ex_err = ER_BAD_SUBSCRIPT
            return
        arr[ii] = value

    ## ---- DATA machinery ----
    proc _next_data(self):
        while self.di < len(self.data):
            let cur = self.data[self.di]
            let toks = _tok(self.prog[cur[1]][1])
            var pos = cur[2] + 1
            var item = 0
            while item < self.item_off:
                if pos < len(toks) and toks[pos][0] == "o" and toks[pos][1] == ",":
                    pos = pos + 1
                    item = item + 1
                else:
                    pos = pos + 1
            if pos >= len(toks):
                self.di = self.di + 1
                self.item_off = 0
            else:
                self.item_off = self.item_off + 1
                if toks[pos][0] == "n":
                    return [toks[pos][1], 0]
                if toks[pos][0] == "s":
                    return [toks[pos][1], 1]
                return [toks[pos][1], 1]
        return nil

    ## ---- statements ----
    proc _exec_stmt(self):
        let t = self.toks
        let i = self.pos
        if i >= len(t):
            return ["next", i]
        if t[i][0] != "i":
            if t[i][0] == "o" and t[i][1] == ":":
                return ["next", self._after(i + 1)]
            return self._syntax()
        let k = t[i][1]
        if k == "PRINT":
            return self._st_print(i + 1)
        if k == "LET":
            return self._st_let(i + 1)
        if k == "INPUT":
            return self._st_input(i + 1)
        if k == "GOTO":
            return self._st_goto(i + 1)
        if k == "GOSUB":
            return self._st_gosub(i + 1)
        if k == "RETURN":
            return self._st_return()
        if k == "FOR":
            return self._st_for(i + 1)
        if k == "NEXT":
            return self._st_next(i + 1)
        if k == "IF":
            return self._st_if(i + 1)
        if k == "THEN" or k == "ELSE":
            return self._syntax()
        if k == "REM":
            return ["next", len(t)]
        if k == "DATA":
            return ["next", len(t)]
        if k == "READ":
            return self._st_read(i + 1)
        if k == "RESTORE":
            return self._st_restore(i + 1)
        if k == "DIM":
            return self._st_dim(i + 1)
        if k == "DEF":
            return self._st_def(i + 1)
        if k == "END":
            return ["end"]
        if k == "STOP":
            self.stopped = true
            self.stopped_ci = self.ci
            self.stopped_pos = self.pos
            self.out = self.out + "BREAK IN " + intstr(self.prog[self.ci][0]) + "\r\n"
            return ["stop"]
        if k == "POKE":
            return self._st_poke(i + 1)
        if k == "CALL":
            return self._st_call(i + 1)
        if k == "GET":
            return self._st_get(i + 1)
        if k == "ON":
            return self._st_on(i + 1)
        if k == "ONERR":
            return self._st_onerr(i + 1)
        if k == "RESUME":
            return self._st_resume(i + 1)
        if k == "ERROR":
            return self._st_error(i + 1)
        if k == "TRACE" or k == "NOTRACE":
            if k == "TRACE":
                self.trace_on = 1
            else:
                self.trace_on = 0
            return ["next", self._after(i + 1)]
        if k == "INVERSE" or k == "NORMAL" or k == "FLASH":
            return ["next", self._after(i + 1)]
        if k == "HOME":
            self.gmode = 0
            self.out = self.out + "\x1b[2J\x1b[H"
            return ["next", self._after(i + 1)]
        if k == "VTAB" or k == "HTAB":
            let ev = self._expr(i + 1)
            if self.ex_err >= 0:
                return self._err_res()
            return ["next", self._after(ev[2])]
        if k == "BEEP":
            return self._st_beep(i + 1)
        if k == "SPEED":
            return self._st_speed(i + 1)
        if k == "TEXT" or k == "GR" or k == "HGR" or k == "HGR2" or k == "HCOLOR" or k == "COLOR" or k == "PLOT" or k == "HLIN" or k == "VLIN" or k == "HPLOT":
            return self._st_graph(i + 1, k)
        if k == "STORE" or k == "RECALL":
            return self._st_store(i + 1, k)
        if k == "LIST" or k == "NEW" or k == "RUN" or k == "CONT":
            if self.immed:
                return self._st_shell(i, k)
            return self._syntax()
        if i + 1 < len(t) and t[i + 1][0] == "o" and (t[i + 1][1] == "=" or t[i + 1][1] == "("):
            return self._st_let(i)
        return self._syntax()

    ## ---- PRINT ----
    proc _st_print(self, i):
        let t = self.toks
        var line = ""
        var sep = 0
        var need_sep = 0
        while i < len(t):
            let ty = t[i][0]
            let v = t[i][1]
            if ty == "o" and v == ":":
                break
            if ty == "o" and v == ";":
                sep = 1
                need_sep = 0
                i = i + 1
            elif ty == "o" and v == ",":
                var pad = 16 - (len(line) % 16)
                if pad == 16:
                    pad = 0
                var p = 0
                while p < pad:
                    line = line + " "
                    p = p + 1
                sep = 1
                need_sep = 0
                i = i + 1
            elif ty == "s" or ty == "n" or ty == "i" or ty == "o":
                if need_sep:
                    return self._syntax()
                let ev = self._expr(i)
                if self.ex_err >= 0:
                    return self._err_res()
                if ev[1]:
                    line = line + ev[0]
                else:
                    line = line + fmt_num(ev[0])
                sep = 0
                need_sep = 1
                i = ev[2]
            else:
                return self._syntax()
        self.print_col = len(line)
        if self.dos != nil and self.dos.print_line(line):
            return ["next", self._after(i)]
        if len(line) > 0 and line[0] == "\x04":
            if self.dos != nil:
                self.dos.command(slice(line, 1, len(line)))
            return ["next", self._after(i)]
        self.out = self.out + line
        if sep == 0:
            self.out = self.out + "\r\n"
            self.print_col = 0
        return ["next", self._after(i)]

    ## ---- LET / assignment ----
    proc _st_let(self, i):
        let t = self.toks
        if i >= len(t) or t[i][0] != "i":
            return self._syntax()
        let name = t[i][1]
        var is_arr = false
        var idx = 0.0
        var j = i + 1
        if j < len(t) and t[j][0] == "o" and t[j][1] == "(":
            is_arr = true
            let ev = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            if ev[1]:
                return self._type_err()
            if ev[2] >= len(t) or t[ev[2]][0] != "o" or t[ev[2]][1] != ")":
                return self._syntax()
            idx = ev[0]
            j = ev[2] + 1
        if j >= len(t) or t[j][0] != "o" or t[j][1] != "=":
            return self._syntax()
        let ev2 = self._expr(j + 1)
        if self.ex_err >= 0:
            return self._err_res()
        let is_str = endswith(name, "$")
        if is_arr:
            if is_str:
                if not ev2[1]:
                    return self._type_err()
            elif ev2[1]:
                return self._type_err()
            self._arr_set(lower(name) + "(", idx, ev2[0])
            if self.ex_err >= 0:
                return self._err_res()
            return ["next", self._after(ev2[2])]
        if is_str:
            if not ev2[1]:
                return self._type_err()
            self.vars[lower(name)] = ev2[0]
        else:
            if ev2[1]:
                return self._type_err()
            self.vars[lower(name)] = ev2[0]
        return ["next", self._after(ev2[2])]

    ## ---- INPUT ----
    proc _st_input(self, i):
        let t = self.toks
        var j = i
        if j < len(t) and t[j][0] == "s":
            self.out = self.out + t[j][1]
            j = j + 1
            if j >= len(t) or t[j][0] != "o" or t[j][1] != ";":
                return self._syntax()
            j = j + 1
        else:
            self.out = self.out + "?"
        var reqs = []
        while j < len(t) and t[j][0] == "i":
            push(reqs, ["INPUT", t[j][1]])
            j = j + 1
            if j < len(t) and t[j][0] == "o" and t[j][1] == ",":
                j = j + 1
            else:
                break
        if len(reqs) == 0:
            return self._syntax()
        self.awaiting = reqs
        return ["input", self._after(j)]

    ## ---- GET ----
    proc _st_get(self, i):
        let t = self.toks
        if i >= len(t) or t[i][0] != "i":
            return self._syntax()
        self.awaiting = [["GET", t[i][1]]]
        return ["input", self._after(i + 1)]

    ## ---- GOTO / GOSUB / RETURN ----
    proc _st_goto(self, i):
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        return ["goto", int(ev[0])]

    proc _st_gosub(self, i):
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        let ln = int(ev[0])
        if self.find_ci(ln) < 0:
            return self._raise(ER_UNDEFD_STATEMENT)
        push(self.gstack, [self.ci, self._after(ev[2])])
        return ["goto", ln]

    proc _st_return(self):
        if len(self.gstack) == 0:
            return self._raise(ER_RETURN_WITHOUT_GOSUB)
        let fr = self.gstack[len(self.gstack) - 1]
        let ng = []
        var k = 0
        while k < len(self.gstack) - 1:
            push(ng, self.gstack[k])
            k = k + 1
        self.gstack = ng
        return ["repeat", fr[0], fr[1]]

    ## ---- FOR / NEXT ----
    proc _st_for(self, i):
        let t = self.toks
        if i >= len(t) or t[i][0] != "i":
            return self._syntax()
        let name = t[i][1]
        if endswith(name, "$"):
            return self._syntax()
        var j = i + 1
        if j >= len(t) or t[j][0] != "o" or t[j][1] != "=":
            return self._syntax()
        let ev = self._expr(j + 1)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        let start = ev[0]
        j = ev[2]
        if j >= len(t) or t[j][0] != "i" or t[j][1] != "TO":
            return self._syntax()
        let ev2 = self._expr(j + 1)
        if self.ex_err >= 0:
            return self._err_res()
        if ev2[1]:
            return self._type_err()
        let limit = ev2[0]
        var step = 1.0
        j = ev2[2]
        if j < len(t) and t[j][0] == "i" and t[j][1] == "STEP":
            let ev3 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            if ev3[1]:
                return self._type_err()
            step = ev3[0]
            j = ev3[2]
        self.vars[lower(name)] = start
        push(self.forst, {"var": lower(name), "limit": limit, "step": step, "ci": self.ci, "pos": self._after(j)})
        return ["next", self._after(j)]

    proc _st_next(self, i):
        let t = self.toks
        var j = i
        while true:
            if len(self.forst) == 0:
                return self._raise(ER_NEXT_WITHOUT_FOR)
            if j < len(t) and t[j][0] == "i":
                if lower(t[j][1]) != self.forst[len(self.forst) - 1]["var"]:
                    return self._raise(ER_NEXT_WITHOUT_FOR)
            let fr = self.forst[len(self.forst) - 1]
            let nv = self._numvar(fr["var"]) + fr["step"]
            self.vars[fr["var"]] = nv
            if (fr["step"] > 0 and nv <= fr["limit"]) or (fr["step"] < 0 and nv >= fr["limit"]):
                return ["repeat", fr["ci"], fr["pos"]]
            let nf = []
            var k = 0
            while k < len(self.forst) - 1:
                push(nf, self.forst[k])
                k = k + 1
            self.forst = nf
            if j < len(t) and t[j][0] == "i":
                j = j + 1
                if j < len(t) and t[j][0] == "o" and t[j][1] == ",":
                    j = j + 1
                else:
                    return ["next", self._after(j)]
            else:
                return ["next", self._after(j)]

    ## ---- IF ----
    proc _st_if(self, i):
        let t = self.toks
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        let cond = ev[0] != 0.0
        var j = ev[2]
        if j >= len(t) or t[j][0] != "i" or (t[j][1] != "THEN" and t[j][1] != "GOTO"):
            return self._syntax()
        j = j + 1
        if cond:
            if j < len(t) and t[j][0] == "n":
                return ["goto", int(t[j][1])]
            if j < len(t) and t[j][0] == "i" and t[j][1] == "THEN":
                j = j + 1
            return ["reset", self._after(j)]
        var k = j
        var depth = 0
        while k < len(t):
            if t[k][0] == "o":
                if t[k][1] == "(":
                    depth = depth + 1
                elif t[k][1] == ")":
                    depth = depth - 1
            elif t[k][0] == "i" and t[k][1] == "ELSE" and depth == 0:
                if k + 1 < len(t) and t[k + 1][0] == "n":
                    return ["goto", int(t[k + 1][1])]
                return ["reset", self._after(k + 1)]
            k = k + 1
        return ["next", len(t)]

    ## ---- READ / RESTORE ----
    proc _st_read(self, i):
        let t = self.toks
        var j = i
        while j < len(t) and t[j][0] == "i":
            let name = t[j][1]
            var is_arr = false
            var idx = 0.0
            var k = j + 1
            if k < len(t) and t[k][0] == "o" and t[k][1] == "(":
                is_arr = true
                let ev = self._expr(k)
                if self.ex_err >= 0:
                    return self._err_res()
                if ev[1]:
                    return self._type_err()
                idx = ev[0]
                k = ev[2]
            let item = self._next_data()
            if item == nil:
                return self._raise(ER_OUT_OF_DATA)
            let is_str = endswith(name, "$")
            if is_arr:
                if is_str:
                    if not item[1]:
                        return self._type_err()
                    self._arr_set(lower(name) + "(", idx, item[0])
                else:
                    if item[1]:
                        return self._type_err()
                    self._arr_set(lower(name) + "(", idx, item[0])
                if self.ex_err >= 0:
                    return self._err_res()
            else:
                if is_str:
                    if not item[1]:
                        return self._type_err()
                    self.vars[lower(name)] = item[0]
                else:
                    if item[1]:
                        return self._type_err()
                    self.vars[lower(name)] = item[0]
            if k < len(t) and t[k][0] == "o" and t[k][1] == ",":
                j = k + 1
            else:
                j = k
                break
        if j < len(t) and t[j][0] != "i":
            return self._syntax()
        return ["next", self._after(j)]

    proc _st_restore(self, i):
        let t = self.toks
        if i < len(t) and t[i][0] == "n":
            let ln = int(t[i][1])
            var k = 0
            while k < len(self.data):
                if self.data[k][0] >= ln:
                    self.di = k
                    self.item_off = 0
                    return ["next", self._after(i + 1)]
                k = k + 1
            self.di = len(self.data)
            self.item_off = 0
            return ["next", self._after(i + 1)]
        self.di = 0
        self.item_off = 0
        return ["next", self._after(i)]

    ## ---- DIM ----
    proc _st_dim(self, i):
        let t = self.toks
        var j = i
        while j < len(t):
            if j >= len(t) or t[j][0] != "i":
                return self._syntax()
            let name = t[j][1]
            let key = lower(name) + "("
            j = j + 1
            if j >= len(t) or t[j][0] != "o" or t[j][1] != "(":
                return self._syntax()
            let ev = self._expr(j)
            if self.ex_err >= 0:
                return self._err_res()
            if ev[1]:
                return self._type_err()
            let size = int(ev[0])
            j = ev[2]
            if j >= len(t) or t[j][0] != "o" or t[j][1] != ")":
                return self._syntax()
            j = j + 1
            if self.arrs[key] != nil:
                return self._raise(ER_REDIMD_ARRAY)
            if size < 0:
                return self._raise(ER_BAD_SUBSCRIPT)
            if size > 255:
                return self._raise(ER_OUT_OF_MEMORY)
            let arr = []
            var k = 0
            while k <= size:
                if endswith(name, "$"):
                    push(arr, "")
                else:
                    push(arr, 0.0)
                k = k + 1
            self.arrs[key] = arr
            if j < len(t) and t[j][0] == "o" and t[j][1] == ",":
                j = j + 1
            else:
                break
        return ["next", self._after(j)]

    ## ---- DEF FN ----
    proc _st_def(self, i):
        let t = self.toks
        var j = i
        if j >= len(t) or t[j][0] != "i" or t[j][1] != "FN":
            return self._syntax()
        j = j + 1
        if j >= len(t) or t[j][0] != "i":
            return self._syntax()
        let fname = lower(t[j][1])
        j = j + 1
        if j >= len(t) or t[j][0] != "o" or t[j][1] != "(":
            return self._syntax()
        j = j + 1
        if j >= len(t) or t[j][0] != "i":
            return self._syntax()
        let param = lower(t[j][1])
        j = j + 1
        if j >= len(t) or t[j][0] != "o" or t[j][1] != ")":
            return self._syntax()
        j = j + 1
        if j >= len(t) or t[j][0] != "o" or t[j][1] != "=":
            return self._syntax()
        j = j + 1
        let ex = []
        while j < len(t) and not (t[j][0] == "o" and t[j][1] == ":"):
            push(ex, t[j])
            j = j + 1
        self.fn_defs["FN" + fname] = [param, ex]
        return ["next", self._after(j)]

    ## ---- POKE / CALL ----
    proc _st_poke(self, i):
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        var j = ev[2]
        if j >= len(self.toks) or self.toks[j][0] != "o" or self.toks[j][1] != ",":
            return self._syntax()
        let ev2 = self._expr(j + 1)
        if self.ex_err >= 0:
            return self._err_res()
        if ev2[1]:
            return self._type_err()
        if self.machine != nil:
            self.machine.bus.write8(int(ev[0]) & 0xFFFF, int(ev2[0]) & 0xFF)
        return ["next", self._after(ev2[2])]

    proc _st_call(self, i):
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        let addr = int(ev[0])
        if addr == -151 or addr == 65449:
            return ["mon"]
        if self.machine != nil:
            self.machine.cpu.regs.set_pc(addr & 0xFFFF)
            var n = 0
            while n < 1000000 and self.machine.cpu.halted == false:
                self.machine.cpu.step()
                n = n + 1
        return ["next", self._after(ev[2])]

    ## ---- ON / ONERR / RESUME / ERROR ----
    proc _st_on(self, i):
        let t = self.toks
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        if ev[1]:
            return self._type_err()
        let v = int(ev[0])
        var j = ev[2]
        if j >= len(t) or t[j][0] != "i" or (t[j][1] != "GOTO" and t[j][1] != "GOSUB"):
            return self._syntax()
        let is_gs = t[j][1] == "GOSUB"
        j = j + 1
        var lines = []
        while j < len(t) and t[j][0] == "n":
            push(lines, int(t[j][1]))
            j = j + 1
            if j < len(t) and t[j][0] == "o" and t[j][1] == ",":
                j = j + 1
            else:
                break
        if v >= 1 and v <= len(lines):
            if is_gs:
                push(self.gstack, [self.ci, self._after(j)])
            return ["goto", lines[v - 1]]
        return ["next", self._after(j)]

    proc _st_onerr(self, i):
        let t = self.toks
        if i >= len(t) or t[i][0] != "i" or t[i][1] != "GOTO":
            return self._syntax()
        if i + 1 < len(t) and t[i + 1][0] == "n":
            self.onerr = 1
            self.onerr_ln = int(t[i + 1][1])
            return ["next", self._after(i + 2)]
        return self._syntax()

    proc _st_resume(self, i):
        let t = self.toks
        if i < len(t) and t[i][0] == "n":
            return ["goto", int(t[i][1])]
        if self.err_ci < 0:
            return self._raise(ER_CANT_CONTINUE)
        self.ci = self.err_ci + 1
        return ["reset", 0]

    proc _st_error(self, i):
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        return self._raise(int(ev[0]))

    ## ---- shell-ish statements (immediate only) ----
    proc _st_shell(self, i, k):
        let t = self.toks
        if k == "LIST":
            var out = ""
            var flo = -1
            var to = -1
            var j = i
            if j < len(t) and t[j][0] == "n":
                flo = int(t[j][1])
                j = j + 1
                if j < len(t) and t[j][0] == "o" and t[j][1] == "-":
                    j = j + 1
                    if j < len(t) and t[j][0] == "n":
                        to = int(t[j][1])
                    else:
                        to = 99999
                else:
                    to = flo
            elif j < len(t) and t[j][0] == "o" and t[j][1] == "-":
                j = j + 1
                to = 99999
                if j < len(t) and t[j][0] == "n":
                    to = int(t[j][1])
            if flo < 0:
                flo = -1
                to = -1
            var k2 = 0
            while k2 < len(self.prog):
                let ln = self.prog[k2][0]
                if (flo < 0 or ln >= flo) and (to < 0 or ln <= to):
                    out = out + intstr(ln) + " " + self.prog[k2][1] + "\r\n"
                k2 = k2 + 1
            self.out = self.out + out
            return ["next", len(t)]
        if k == "NEW":
            self.new()
            return ["next", len(t)]
        if k == "RUN":
            if i < len(t) and t[i][0] == "n":
                self.run_at(int(t[i][1]))
            else:
                self.run()
            return ["run"]
        if k == "CONT":
            if self.stopped == false:
                return self._raise(ER_CANT_CONTINUE)
            self.running = 1
            self.immed = 0
            self.ci = self.stopped_ci
            self.toks = _tok(self.prog[self.ci][1])
            self.pos = self.stopped_pos
            self._advance()
            return ["run"]
        return self._syntax()

    ## ---- BEEP / SPEED ----
    proc _st_beep(self, i):
        var freq = 1000
        if i < len(self.toks):
            let ev = self._expr(i)
            if self.ex_err >= 0:
                return self._err_res()
            if ev[1]:
                return self._type_err()
            freq = int(ev[0])
            if self.speaker != nil:
                self.speaker.tone(freq, 100)
            return ["next", self._after(ev[2])]
        if self.speaker != nil:
            self.speaker.tone(freq, 100)
        return ["next", self._after(i)]

    proc _st_speed(self, i):
        if i < len(self.toks) and self.toks[i][0] == "o" and self.toks[i][1] == "=":
            let ev = self._expr(i + 1)
            if self.ex_err >= 0:
                return self._err_res()
            return ["next", self._after(ev[2])]
        let ev = self._expr(i)
        if self.ex_err >= 0:
            return self._err_res()
        return ["next", self._after(ev[2])]

    ## ---- graphics ----
    proc _st_graph(self, i, k):
        let t = self.toks
        if k == "HGR" or k == "HGR2":
            self.gmode = 2
            self.hgr_page = []
            var q = 0
            while q < 280 * 192:
                push(self.hgr_page, 0)
                q = q + 1
            self._render_gfx()
            return ["next", self._after(i)]
        if k == "GR":
            self.gmode = 1
            self.gr_page = []
            var q = 0
            while q < 40 * 48:
                push(self.gr_page, 0)
                q = q + 1
            self._render_gfx()
            return ["next", self._after(i)]
        if k == "TEXT":
            self.gmode = 0
            return ["next", self._after(i)]
        if k == "HCOLOR":
            if i < len(t) and t[i][0] == "o" and t[i][1] == "=":
                let ev = self._expr(i + 1)
                if self.ex_err >= 0:
                    return self._err_res()
                self.hcolor = int(ev[0]) & 7
                return ["next", self._after(ev[2])]
            return self._syntax()
        if k == "COLOR":
            if i < len(t) and t[i][0] == "o" and t[i][1] == "=":
                let ev = self._expr(i + 1)
                if self.ex_err >= 0:
                    return self._err_res()
                self.color = int(ev[0]) & 15
                return ["next", self._after(ev[2])]
            return self._syntax()
        if k == "PLOT":
            let ev = self._expr(i)
            if self.ex_err >= 0:
                return self._err_res()
            if ev[1]:
                return self._type_err()
            let x = int(ev[0])
            var j = ev[2]
            if j >= len(t) or t[j][0] != "o" or t[j][1] != ",":
                return self._syntax()
            let ev2 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            let y = int(ev2[0])
            self._plot_dot(x, y)
            self._render_gfx()
            return ["next", self._after(ev2[2])]
        if k == "HLIN":
            let ev = self._expr(i)
            if self.ex_err >= 0:
                return self._err_res()
            let x1 = int(ev[0])
            var j = ev[2]
            if j >= len(t) or t[j][0] != "o" or t[j][1] != ",":
                return self._syntax()
            let ev2 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            let x2 = int(ev2[0])
            j = ev2[2]
            if j >= len(t) or t[j][0] != "i" or t[j][1] != "AT":
                return self._syntax()
            let ev3 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            let y = int(ev3[0])
            var a = x1
            var b = x2
            if a > b:
                a = x2
                b = x1
            while a <= b:
                self._plot_dot(a, y)
                a = a + 1
            self._render_gfx()
            return ["next", self._after(ev3[2])]
        if k == "VLIN":
            let ev = self._expr(i)
            if self.ex_err >= 0:
                return self._err_res()
            let y1 = int(ev[0])
            var j = ev[2]
            if j >= len(t) or t[j][0] != "o" or t[j][1] != ",":
                return self._syntax()
            let ev2 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            let y2 = int(ev2[0])
            j = ev2[2]
            if j >= len(t) or t[j][0] != "i" or t[j][1] != "AT":
                return self._syntax()
            let ev3 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            let x = int(ev3[0])
            var a = y1
            var b = y2
            if a > b:
                a = y2
                b = y1
            while a <= b:
                self._plot_dot(x, a)
                a = a + 1
            self._render_gfx()
            return ["next", self._after(ev3[2])]
        if k == "HPLOT":
            let ev = self._expr(i)
            if self.ex_err >= 0:
                return self._err_res()
            if ev[1]:
                return self._type_err()
            let x1 = int(ev[0])
            var j = ev[2]
            if j >= len(t) or t[j][0] != "o" or t[j][1] != ",":
                return self._syntax()
            let ev2 = self._expr(j + 1)
            if self.ex_err >= 0:
                return self._err_res()
            let y1 = int(ev2[0])
            j = ev2[2]
            if j < len(t) and t[j][0] == "i" and t[j][1] == "TO":
                let ev3 = self._expr(j + 1)
                if self.ex_err >= 0:
                    return self._err_res()
                let x2 = int(ev3[0])
                var j2 = ev3[2]
                if j2 >= len(t) or t[j2][0] != "o" or t[j2][1] != ",":
                    return self._syntax()
                let ev4 = self._expr(j2 + 1)
                if self.ex_err >= 0:
                    return self._err_res()
                let y2 = int(ev4[0])
                self._hplot_line(x1, y1, x2, y2)
                self._render_gfx()
                return ["next", self._after(ev4[2])]
            self._hplot_dot(x1, y1)
            self._render_gfx()
            return ["next", self._after(j)]
        return self._syntax()

    proc _plot_dot(self, x, y):
        if x < 0 or x > 39 or y < 0 or y > 47:
            return
        if self.color != 0:
            self.gr_page[y * 40 + x] = 1

    proc _hplot_dot(self, x, y):
        if x < 0 or x > 279 or y < 0 or y > 191:
            return
        if self.hcolor != 0:
            self.hgr_page[y * 280 + x] = 1

    proc _hplot_line(self, x0, y0, x1, y1):
        var dx = x1 - x0
        var dy = y1 - y0
        if dx < 0:
            dx = 0 - dx
        if dy < 0:
            dy = 0 - dy
        var sx = 1
        var sy = 1
        if x0 > x1:
            sx = -1
        if y0 > y1:
            sy = -1
        var err = dx - dy
        while true:
            self._hplot_dot(x0, y0)
            if x0 == x1 and y0 == y1:
                return
            let e2 = 2 * err
            if e2 > 0 - dy:
                err = err - dy
                x0 = x0 + sx
            if e2 < dx:
                err = err + dx
                y0 = y0 + sy

    proc _render_gfx(self):
        if self.machine == nil:
            return
        if self.gmode == 0:
            return
        let g = self.machine.bus.gpu
        let gfx = graphics.Gfx(g)
        gfx.clear(0)
        if self.gmode == 2:
            var y = 0
            while y < 192:
                var x = 0
                while x < 280:
                    if self.hgr_page[y * 280 + x] != 0:
                        gfx.put_pixel(int((x * 128) / 280), int((y * 64) / 192), 1)
                    x = x + 1
                y = y + 1
        else:
            var y = 0
            while y < 48:
                var x = 0
                while x < 40:
                    if self.gr_page[y * 40 + x] != 0:
                        gfx.put_pixel(int((x * 128) / 40), int((y * 64) / 48), 1)
                    x = x + 1
                y = y + 1

    ## ---- STORE / RECALL ----
    proc _st_store(self, i, k):
        let t = self.toks
        if i >= len(t) or t[i][0] != "i":
            return self._syntax()
        let name = t[i][1]
        if k == "STORE":
            let key = lower(name) + "("
            let arr = []
            if self.arrs[key] != nil:
                arr = self.arrs[key]
            let lines = []
            var j = 0
            while j < len(arr):
                let v = arr[j]
                if v == "":
                    push(lines, "\"\"")
                else:
                    push(lines, intstr(v))
                j = j + 1
            if self.dos != nil:
                self.dos.st.save_text(name, lines)
            return ["next", self._after(i + 1)]
        let key = lower(name) + "("
        if self.dos != nil:
            let lines = self.dos.st.load_text(name)
            var j = 0
            while j < len(lines):
                let nv = _num_parse(lines[j])
                if nv != nil:
                    self._arr_set(key, j * 1.0, nv)
                j = j + 1
        return ["next", self._after(i + 1)]

    ## ---- expression evaluator ----
    proc _expr(self, i):
        let a = self._and_expr(i)
        if self.ex_err >= 0:
            return nil
        var j = a[2]
        while j < len(self.toks) and self.toks[j][0] == "i" and self.toks[j][1] == "OR":
            let b = self._and_expr(j + 1)
            if self.ex_err >= 0:
                return nil
            if a[1] or b[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            let r = 0.0
            if a[0] != 0.0 or b[0] != 0.0:
                r = 1.0
            a = [r, 0, b[2]]
            j = b[2]
        return a

    proc _and_expr(self, i):
        let a = self._not_expr(i)
        if self.ex_err >= 0:
            return nil
        var j = a[2]
        while j < len(self.toks) and self.toks[j][0] == "i" and self.toks[j][1] == "AND":
            let b = self._not_expr(j + 1)
            if self.ex_err >= 0:
                return nil
            if a[1] or b[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            let r = 0.0
            if a[0] != 0.0 and b[0] != 0.0:
                r = 1.0
            a = [r, 0, b[2]]
            j = b[2]
        return a

    proc _not_expr(self, i):
        if i < len(self.toks) and self.toks[i][0] == "i" and self.toks[i][1] == "NOT":
            let a = self._not_expr(i + 1)
            if self.ex_err >= 0:
                return nil
            if a[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            let r = 0.0
            if a[0] == 0.0:
                r = 1.0
            return [r, 0, a[2]]
        return self._cmp_expr(i)

    proc _cmp_expr(self, i):
        let a = self._add_expr(i)
        if self.ex_err >= 0:
            return nil
        let t = self.toks
        var j = a[2]
        if j < len(t) and t[j][0] == "o" and (t[j][1] == "=" or t[j][1] == "<" or t[j][1] == ">" or t[j][1] == "<=" or t[j][1] == ">=" or t[j][1] == "<>"):
            let op = t[j][1]
            let b = self._add_expr(j + 1)
            if self.ex_err >= 0:
                return nil
            var res = false
            if a[1] or b[1]:
                if not a[1] or not b[1]:
                    self.ex_err = ER_TYPE_MISMATCH
                    return nil
                let c = self._str_cmp(a[0], b[0])
                if op == "=":
                    res = c == 0
                elif op == "<>":
                    res = c != 0
                elif op == "<":
                    res = c < 0
                elif op == ">":
                    res = c > 0
                elif op == "<=":
                    res = c <= 0
                else:
                    res = c >= 0
            else:
                if op == "=":
                    res = a[0] == b[0]
                elif op == "<>":
                    res = a[0] != b[0]
                elif op == "<":
                    res = a[0] < b[0]
                elif op == ">":
                    res = a[0] > b[0]
                elif op == "<=":
                    res = a[0] <= b[0]
                else:
                    res = a[0] >= b[0]
            let r = 0.0
            if res:
                r = 1.0
            return [r, 0, b[2]]
        return a

    proc _str_cmp(self, a, b):
        var i = 0
        while i < len(a) and i < len(b):
            if a[i] != b[i]:
                if a[i] < b[i]:
                    return -1
                return 1
            i = i + 1
        if len(a) == len(b):
            return 0
        if len(a) < len(b):
            return -1
        return 1

    proc _add_expr(self, i):
        let a = self._mul_expr(i)
        if self.ex_err >= 0:
            return nil
        var j = a[2]
        while j < len(self.toks) and self.toks[j][0] == "o" and (self.toks[j][1] == "+" or self.toks[j][1] == "-"):
            let op = self.toks[j][1]
            let b = self._mul_expr(j + 1)
            if self.ex_err >= 0:
                return nil
            if op == "+":
                if a[1] and b[1]:
                    if len(a[0]) + len(b[0]) > 255:
                        self.ex_err = ER_STRING_TOO_LONG
                        return nil
                    a = [a[0] + b[0], 1, b[2]]
                elif (a[1] or b[1]) == false:
                    let r = a[0] + b[0]
                    if math.abs(r) >= 1.7e38:
                        self.ex_err = ER_OVERFLOW
                        return nil
                    a = [r, 0, b[2]]
                else:
                    self.ex_err = ER_TYPE_MISMATCH
                    return nil
            else:
                if a[1] or b[1]:
                    self.ex_err = ER_TYPE_MISMATCH
                    return nil
                let r = a[0] - b[0]
                if math.abs(r) >= 1.7e38:
                    self.ex_err = ER_OVERFLOW
                    return nil
                a = [r, 0, b[2]]
            j = b[2]
        return a

    proc _mul_expr(self, i):
        let a = self._pow_expr(i)
        if self.ex_err >= 0:
            return nil
        var j = a[2]
        while j < len(self.toks) and self.toks[j][0] == "o" and (self.toks[j][1] == "*" or self.toks[j][1] == "/"):
            let op = self.toks[j][1]
            let b = self._pow_expr(j + 1)
            if self.ex_err >= 0:
                return nil
            if a[1] or b[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            var r = 0.0
            if op == "*":
                r = a[0] * b[0]
            else:
                if b[0] == 0:
                    self.ex_err = ER_DIVISION_BY_ZERO
                    return nil
                r = a[0] / b[0]
            if math.abs(r) >= 1.7e38:
                self.ex_err = ER_OVERFLOW
                return nil
            a = [r, 0, b[2]]
            j = b[2]
        return a

    ## unary minus binds looser than ^ (Applesoft: -2^2 = -4)
    proc _pow_expr(self, i):
        let t = self.toks
        if i < len(t) and t[i][0] == "o" and t[i][1] == "-":
            let a = self._pow_expr(i + 1)
            if self.ex_err >= 0:
                return nil
            if a[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            return [0 - a[0], 0, a[2]]
        let a = self._primary(i)
        if self.ex_err >= 0:
            return nil
        var j = a[2]
        if j < len(t) and t[j][0] == "o" and t[j][1] == "^":
            if a[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            let b = self._pow_expr(j + 1)
            if self.ex_err >= 0:
                return nil
            if b[1]:
                self.ex_err = ER_TYPE_MISMATCH
                return nil
            if a[0] == 0 and b[0] < 0:
                self.ex_err = ER_DIVISION_BY_ZERO
                return nil
            if a[0] < 0 and b[0] != int(b[0]):
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            if a[0] != 0 and b[0] > 0 and b[0] * math.log(math.abs(a[0])) > 88.0:
                self.ex_err = ER_OVERFLOW
                return nil
            var r = math.pow(a[0], b[0])
            if math.abs(r) >= 1.7e38:
                self.ex_err = ER_OVERFLOW
                return nil
            return [r, 0, b[2]]
        return a

    proc _primary(self, i):
        let t = self.toks
        if i >= len(t):
            self.ex_err = ER_SYNTAX
            return nil
        let ty = t[i][0]
        let v = t[i][1]
        if ty == "n":
            return [v, 0, i + 1]
        if ty == "s":
            return [v, 1, i + 1]
        if ty == "o" and v == "(":
            let a = self._expr(i + 1)
            if self.ex_err >= 0:
                return nil
            if a[2] >= len(t) or t[a[2]][0] != "o" or t[a[2]][1] != ")":
                self.ex_err = ER_SYNTAX
                return nil
            return [a[0], a[1], a[2] + 1]
        if ty == "i":
            let up = v
            if up == "FN" and i + 1 < len(t) and t[i + 1][0] == "i":
                return self._fn_call(i)
            if up == "CHR$" or up == "LEFT$" or up == "RIGHT$" or up == "MID$" or up == "STR$" or up == "VAL" or up == "ASC" or up == "LEN" or up == "ABS" or up == "SGN" or up == "INT" or up == "RND" or up == "SQR" or up == "EXP" or up == "LOG" or up == "SIN" or up == "COS" or up == "TAN" or up == "ATN" or up == "FRE" or up == "PEEK" or up == "PDL" or up == "POS" or up == "SPC" or up == "TAB":
                return self._func(up, i)
            if i + 1 < len(t) and t[i + 1][0] == "o" and t[i + 1][1] == "(":
                return self._arr_get(i)
            if endswith(up, "$"):
                return [self._strvar(lower(up)), 1, i + 1]
            return [self._numvar(lower(up)), 0, i + 1]
        self.ex_err = ER_SYNTAX
        return nil

    proc _arr_get(self, i):
        let t = self.toks
        let name = t[i][1]
        let key = lower(name) + "("
        let ev = self._expr(i + 2)
        if self.ex_err >= 0:
            return nil
        if ev[2] >= len(t) or t[ev[2]][0] != "o" or t[ev[2]][1] != ")":
            self.ex_err = ER_SYNTAX
            return nil
        let idx = ev[0]
        if idx < 0 or idx > 255:
            self.ex_err = ER_BAD_SUBSCRIPT
            return nil
        let ii = int(idx)
        if self.arrs[key] != nil == false:
            let arr = []
            var k = 0
            while k < 11:
                if endswith(key, "$"):
                    push(arr, "")
                else:
                    push(arr, 0.0)
                k = k + 1
            self.arrs[key] = arr
        let arr = self.arrs[key]
        if ii >= len(arr):
            self.ex_err = ER_BAD_SUBSCRIPT
            return nil
        if endswith(key, "$"):
            return [arr[ii], 1, ev[2] + 1]
        return [arr[ii], 0, ev[2] + 1]

    proc _fn_call(self, i):
        let t = self.toks
        let fname = lower(t[i + 1][1])
        let key = "FN" + fname
        if self.fn_defs[key] == nil:
            self.ex_err = ER_UNDEFD_FUNCTION
            return nil
        let def = self.fn_defs[key]
        if i + 2 >= len(t) or t[i + 2][0] != "o" or t[i + 2][1] != "(":
            self.ex_err = ER_SYNTAX
            return nil
        let ev = self._expr(i + 3)
        if self.ex_err >= 0:
            return nil
        if ev[2] >= len(t) or t[ev[2]][0] != "o" or t[ev[2]][1] != ")":
            self.ex_err = ER_SYNTAX
            return nil
        let param = def[0]
        let old = self.vars[param] != nil
        var oldv = 0.0
        if old:
            oldv = self.vars[param]
        self.vars[param] = ev[0]
        let saved = self.toks
        self.toks = def[1]
        let r = self._expr(0)
        let e = self.ex_err
        self.toks = saved
        if old:
            self.vars[param] = oldv
        else:
            self.vars[param] = 0.0
        if e >= 0:
            self.ex_err = e
            return nil
        return [r[0], r[1], ev[2] + 1]

    proc _func(self, up, i):
        let t = self.toks
        if i + 1 >= len(t) or t[i + 1][0] != "o" or t[i + 1][1] != "(":
            self.ex_err = ER_SYNTAX
            return nil
        let a1 = self._expr(i + 2)
        if self.ex_err >= 0:
            return nil
        var args = [a1]
        var j = a1[2]
        while j < len(t) and t[j][0] == "o" and t[j][1] == ",":
            let b = self._expr(j + 1)
            if self.ex_err >= 0:
                return nil
            push(args, b)
            j = b[2]
        if j >= len(t) or t[j][0] != "o" or t[j][1] != ")":
            self.ex_err = ER_SYNTAX
            return nil
        let next = j + 1
        let n = len(args)
        if up == "ABS":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [math.abs(args[0][0]), 0, next]
        if up == "SGN":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            if args[0][0] > 0:
                return [1.0, 0, next]
            if args[0][0] < 0:
                return [-1.0, 0, next]
            return [0.0, 0, next]
        if up == "INT":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [math.floor(args[0][0]) * 1.0, 0, next]
        if up == "RND":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            if args[0][0] < 0:
                self.rnd_seed = (0 - int(args[0][0])) & 0xFFFF
            self.rnd_seed = (self.rnd_seed * 25173 + 13849) % 65536
            return [(self.rnd_seed * 1.0) / 65536.0, 0, next]
        if up == "SQR":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            if args[0][0] < 0:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            return [math.sqrt(args[0][0]), 0, next]
        if up == "EXP":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            let r = math.exp(args[0][0])
            if r >= 1.7e38:
                self.ex_err = ER_OVERFLOW
                return nil
            return [r, 0, next]
        if up == "LOG":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            if args[0][0] <= 0:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            return [math.log(args[0][0]), 0, next]
        if up == "SIN":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [math.sin(args[0][0]), 0, next]
        if up == "COS":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [math.cos(args[0][0]), 0, next]
        if up == "TAN":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [math.tan(args[0][0]), 0, next]
        if up == "ATN":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [math.atan(args[0][0]), 0, next]
        if up == "FRE":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [30000.0, 0, next]
        if up == "PEEK":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            if self.machine == nil:
                return [0.0, 0, next]
            return [self.machine.bus.read8(int(args[0][0]) & 0xFFFF) * 1.0, 0, next]
        if up == "PDL":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [0.0, 0, next]
        if up == "POS":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [self.print_col * 1.0, 0, next]
        if up == "SPC" or up == "TAB":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [0.0, 0, next]
        if up == "CHR$":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            let c = int(args[0][0])
            if c < 0 or c > 255:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            return [chr(c), 1, next]
        if up == "STR$":
            if n != 1 or args[0][1]:
                return self._fn_arg_err(up)
            return [fmt_num(args[0][0]), 1, next]
        if up == "ASC":
            if n != 1 or not args[0][1]:
                return self._fn_arg_err(up)
            if len(args[0][0]) == 0:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            return [ord(args[0][0][0]) * 1.0, 0, next]
        if up == "LEN":
            if n != 1 or not args[0][1]:
                return self._fn_arg_err(up)
            return [len(args[0][0]) * 1.0, 0, next]
        if up == "VAL":
            if n != 1 or not args[0][1]:
                return self._fn_arg_err(up)
            let nv = _num_parse(args[0][0])
            if nv == nil:
                return [0.0, 0, next]
            return [nv, 0, next]
        if up == "LEFT$":
            if n != 2 or not args[0][1] or args[1][1]:
                return self._fn_arg_err(up)
            let c = int(args[1][0])
            if c < 0:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            let s = args[0][0]
            if c > len(s):
                c = len(s)
            return [slice(s, 0, c), 1, next]
        if up == "RIGHT$":
            if n != 2 or not args[0][1] or args[1][1]:
                return self._fn_arg_err(up)
            let c = int(args[1][0])
            if c < 0:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            let s = args[0][0]
            if c > len(s):
                c = len(s)
            return [slice(s, len(s) - c, len(s)), 1, next]
        if up == "MID$":
            if n < 2 or n > 3 or not args[0][1]:
                return self._fn_arg_err(up)
            if args[1][1] or (n == 3 and args[2][1]):
                return self._fn_arg_err(up)
            let s = args[0][0]
            let a = int(args[1][0])
            var b = len(s) - a + 1
            if n == 3:
                b = int(args[2][0])
            if a < 1:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            if a > len(s):
                return ["", 1, next]
            if b < 0:
                self.ex_err = ER_ILLEGAL_QUANTITY
                return nil
            if b > len(s) - a + 1:
                b = len(s) - a + 1
            return [slice(s, a - 1, a - 1 + b), 1, next]
        self.ex_err = ER_SYNTAX
        return nil

    proc _fn_arg_err(self, up):
        self.ex_err = ER_TYPE_MISMATCH
        return nil
