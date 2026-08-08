#########################################################################
## SageApple — regenerate the OP opcode table in avr/sage6502.c
##
## Reads the canonical NMOS table in sage6502/cpu.sage and rewrites the
## OP[] initializer inside avr/sage6502.c so the C port can never drift
## from the reference implementation.
##
## Run:  sage tools/gen_table.sage   (from the repo root)
#########################################################################

import sage6502.cpu
import io

proc h2(a):
    let dig = "0123456789ABCDEF"
    return dig[(a >> 4) & 0xF] + dig[a & 0xF]

proc cv(n):
    return "0123456789"[n]

proc dec(v):
    var hi = 0
    while v >= 10:
        v = v - 10
        hi = hi + 1
    if hi == 0:
        return cv(v)
    return cv(hi) + cv(v)

let MODES = ["M_IMM", "M_ZP", "M_ZPX", "M_ZPY", "M_ABS", "M_ABSX",
             "M_ABSY", "M_INDX", "M_INDY", "M_ACC", "M_IND", "M_REL", "M_IMP"]

var items = []
var i = 0
while i < 256:
    let id = cpu._OPCODES[i][0]
    let mode = cpu._OPCODES[i][1]
    push(items, dec(id) + "<<4|" + MODES[mode])
    i = i + 1

var body = "static const uint16_t OP[256] = {\n"
var r = 0
while r < 16:
    body = body + "    /*" + h2(r * 16) + "*/ "
    var c = 0
    while c < 16:
        body = body + items[r * 16 + c]
        let is_last = r * 16 + c == 255
        if not is_last:
            body = body + ",   "
        c = c + 1
    body = body + "\n"
    r = r + 1
body = body + "};\n"

var s = io.readfile("avr/sage6502.c")
let n = len(s)
var start = -1
var k = 0
while k < n:
    if k + 33 <= n and slice(s, k, k + 33) == "static const uint16_t OP[256] = {":
        start = k
        break
    k = k + 1
if start < 0:
    print("table marker not found — aborted")
else:
    var done = -1
    var j = start + 33
    while j < n:
        if j + 2 <= n and slice(s, j, j + 2) == "};":
            done = j
            break
        j = j + 1
    let tail = slice(s, done + 2, n)
    let outall = slice(s, 0, start) + body + tail
    io.writefile("avr/sage6502.c", outall)
    print("table regenerated")