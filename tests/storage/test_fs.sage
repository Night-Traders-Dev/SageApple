#########################################################################
## SageApple — SAGEFS-6502 filesystem + BASIC persistence (Milestone 11)
##
## Run:  sage tests/storage/test_fs.sage   (from the repo root)
#########################################################################

import devices.flash
import sageapple.storage
import basic.basic

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc contains(hay, needle):
    let hn = len(hay)
    let nn = len(needle)
    if nn == 0:
        return true
    if nn > hn:
        return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

proc find_char(s, ch):
    var i = 0
    while i < len(s):
        if s[i] == ch:
            return i
        i = i + 1
    return -1

let chip = flash.Flash(65536)
let st = storage.Storage(chip)

print("== format ==")
check(st.format() == 0, "format succeeds")
check(len(st.list()) == 0, "directory empty after format")

print("== text files ==")
check(st.save_text("HELLO", ["LINE FROM SAGEAPPLE"]) == 0, "save_text saves")
check(st.size_of("HELLO") == 19, "HELLO size = 19 bytes")
let names = st.list()
check(len(names) == 1 and names[0] == "HELLO", "directory lists HELLO")
let back = st.load_text("HELLO")
check(len(back) == 1 and back[0] == "LINE FROM SAGEAPPLE", "load_text round-trips")

print("== binary files ==")
var blob = []
var b = 0
while b < 300:                       # spans two blocks
    push(blob, (b * 7 + 1) & 0xFF)
    b = b + 1
check(st.save_blob("DATA", blob) == 0, "save_blob saves 300 bytes")
let got = st.load_blob("DATA")
let eq = len(got) == len(blob)
var k = 0
while k < len(blob):
    if got[k] != blob[k]:
        break
    k = k + 1
check(eq and k == len(blob), "load_blob round-trips 300 bytes")
check(st.size_of("DATA") == 300, "DATA size reported")
check(st.size_of("MISSING") == -1, "missing file reports -1")

print("== overwrite / delete ==")
check(st.save_text("HELLO", ["V2"]) == 0, "overwrite succeeds")
let back2 = st.load_text("HELLO")
check(len(back2) == 1 and back2[0] == "V2", "overwritten contents")
check(st.delete("HELLO") == 0, "delete succeeds")
check(st.size_of("HELLO") == -1, "deleted file gone")
check(st.delete("HELLO") == -1, "double delete fails")

print("== directory full ==")
check(st.delete("DATA") == 0, "remove DATA to free the directory")
var i = 0
var fit = true
while i < 16:
    let nm = "FILE" + basic.intstr(i + 1)
    if st.save_text(nm, "x") != 0:
        fit = false
    i = i + 1
check(fit, "16 files fit in the directory")
check(st.save_text("EXTRA", "x") == -1, "17th file rejected")
check(len(st.list()) == 16, "directory counts 16 stored files")
check(st.delete("FILE9") == 0, "free a slot for the next section")

print("== BASIC program persistence ==")
let lines = [
    "10 PRINT \"HELLO FROM STORAGE\"",
    "20 FOR I = 1 TO 3",
    "30 PRINT I",
    "40 NEXT I",
    "50 END"]
check(st.save_text("BASIC1", lines) == 0, "BASIC program saved")
let b1 = basic.Basic()
let loaded = st.load_text("BASIC1")
var l = 0
while l < len(loaded):
    let line = loaded[l]
    let sp = find_char(line, " ")
    if sp > 0:
        let num = basic.atoi(line)
        let text = slice(line, sp + 1, len(line))
        b1.set_line(num, text)
    l = l + 1
b1.reset_out()
b1.run()
check(contains(b1.out, "HELLO FROM STORAGE"), "persisted program RUNs and prints")
check(not b1.running, "program finishes and returns to immediate mode")
check(contains(b1.out, "1\r\n2\r\n3"), "loop executes its body")

print("== persistence across a fresh filesystem instance ==")
let st2 = storage.Storage(chip)
check(len(st2.list()) == 16, "second instance sees all 16 files (15 FILEs + BASIC1)")
let reloaded = st2.load_text("BASIC1")
check(len(reloaded) == 5 and reloaded[0] == "10 PRINT \"HELLO FROM STORAGE\"", "BASIC1 readable through second instance")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")