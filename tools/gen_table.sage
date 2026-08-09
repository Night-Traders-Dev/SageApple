#########################################################################
## SageApple — regenerate the OP + CY tables in avr/sage6502.c
##
## Reads the canonical NMOS tables in sage6502/cpu.sage (_OPCODES and
## _CYCLES) and rewrites every initializer inside avr/sage6502.c — both
## the PROGMEM and the host variants of OP[] and CY[] — so the C port
## can never drift from the reference implementation.
##
## Run:  sage tools/gen_table.sage   (from the repo root)
#########################################################################

import sage6502.cpu
import io

let DIG = "0123456789ABCDEF"

proc h2(a):
    return DIG[(a >> 4) & 0xF] + DIG[a & 0xF]

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

## ---- row text for a 256-entry initializer body ------------------------
## builder(i) -> the text of entry i
proc rows_for(builder):
    var items = []
    var i = 0
    while i < 256:
        push(items, builder(i))
        i = i + 1
    var rows = "\n"
    var r = 0
    while r < 16:
        rows = rows + "    /*" + h2(r * 16) + "*/ "
        var c = 0
        while c < 16:
            rows = rows + items[r * 16 + c]
            if r * 16 + c < 255:
                rows = rows + ",   "
            c = c + 1
        rows = rows + "\n"
        r = r + 1
    return rows

proc op_text(i):
    let id = cpu._OPCODES[i][0]
    let mode = cpu._OPCODES[i][1]
    return dec(id) + "<<4|" + MODES[mode]

proc cy_text(i):
    return "0x" + h2(cpu._CYCLES[i])

## ---- replace one initializer block (marker .. "};") -------------------
proc find_str(s, needle, frompos):
    let n = len(s)
    var k = frompos
    while k + len(needle) <= n:
        if slice(s, k, k + len(needle)) == needle:
            return k
        k = k + 1
    return -1

proc replace_block(s, marker, body):
    let idx = find_str(s, marker, 0)
    if idx < 0:
        return nil
    let close = find_str(s, "};", idx + len(marker))
    if close < 0:
        return nil
    return slice(s, 0, idx) + marker + body + "};" + slice(s, close + 2, len(s))

## ---- regenerate all four initializers ---------------------------------
var s = io.readfile("avr/sage6502.c")

let op_body = rows_for(op_text)
let cy_body = rows_for(cy_text)

var updated = s
var ok = 1
let r1 = replace_block(updated, "OP[256] PROGMEM = {", op_body)
if r1 == nil:
    print("OP[256] PROGMEM marker not found — aborted")
    ok = 0
else:
    updated = r1
if ok:
    let r2 = replace_block(updated, "OP[256] = {", op_body)
    if r2 == nil:
        print("OP[256] marker not found — aborted")
        ok = 0
    else:
        updated = r2
if ok:
    let r3 = replace_block(updated, "CY[256] PROGMEM = {", cy_body)
    if r3 == nil:
        print("CY[256] PROGMEM marker not found — aborted")
        ok = 0
    else:
        updated = r3
if ok:
    let r4 = replace_block(updated, "CY[256] = {", cy_body)
    if r4 == nil:
        print("CY[256] marker not found — aborted")
        ok = 0
    else:
        io.writefile("avr/sage6502.c", r4)
        print("OP[] and CY[] tables regenerated")
