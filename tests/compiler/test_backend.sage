#########################################################################
## SageApple — 6502 compiler backend test (Milestone 9)
##
## Run:  sage tests/compiler/test_backend.sage   (from the repo root)
##
## Each case compiles a BASIC program to 6502, loads it into RAM at
## $0300 via a tiny boot ROM (JMP $0300 at reset), runs it on the
## emulator and compares the UART output.
#########################################################################

import sageapple.machine
import compiler.backend
import compiler.asm6502

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
    if nn == 0: return true
    if nn > hn: return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

proc not_contains(hay, needle):
    if contains(hay, needle):
        return false
    return true

## compile a program, load into RAM at $0300, run to HALT, return output
proc run_prog(prog):
    let c = backend.Compiler()
    let r = c.compile(prog, 0x0300)
    let img = r[0]
    let halt = r[1]
    var m = machine.SageApple()
    var k = 0
    var rom = []
    while k < 32768:
        push(rom, 0)
        k = k + 1
    rom[0] = 0x4C               # JMP $0300
    rom[1] = 0x00
    rom[2] = 0x03
    rom[0x7FFC] = 0x00          # reset vector -> $8000
    rom[0x7FFD] = 0x80
    m.boot_rom(rom)
    var i = 0
    while i < len(img):
        m.bus.write_ram(0x0300 + i, img[i])
        i = i + 1
    var steps = 0
    while steps < 300000 and m.cpu.regs.pc != halt:
        m.cpu.step()
        steps = steps + 1
    return m.tx_text()

print("== arithmetic ==")
let o1 = run_prog([
    "10 LET A=5",
    "20 LET B=7",
    "30 PRINT A+B",
    "40 PRINT A*B",
    "50 PRINT B-A",
    "60 PRINT A/B",
])
check(contains(o1, "12\r\n"), "5+7 = 12")
check(contains(o1, "35\r\n"), "5*7 = 35")
check(contains(o1, "2\r\n"), "7-5 = 2")
check(contains(o1, "0\r\n"), "5/7 = 0 (integer)")

print("== strings / parens / unary ==")
let o2 = run_prog([
    "10 PRINT \"HELLO\"",
    "20 PRINT (3+4)*2",
    "30 PRINT -5+10",
    "40 PRINT 200/2",
])
check(contains(o2, "HELLO\r\n"), "string literal")
check(contains(o2, "14\r\n"), "(3+4)*2 = 14")
check(contains(o2, "5\r\n"), "-5+10 = 5")
check(contains(o2, "100\r\n"), "200/2 = 100")

print("== GOTO / IF loop ==")
let o3 = run_prog([
    "10 LET I=1",
    "20 PRINT I",
    "30 LET I=I+1",
    "40 IF I<4 GOTO 20",
    "50 PRINT \"DONE\"",
])
check(contains(o3, "1\r\n2\r\n3\r\n"), "loop body 1,2,3")
check(contains(o3, "DONE"), "loop exits")

print("== IF/THEN ==")
let o4 = run_prog([
    "10 LET Q=7",
    "20 IF Q=7 THEN PRINT \"YES\"",
    "30 IF Q=8 THEN PRINT \"NOPE\"",
    "40 PRINT \"FIN\"",
])
check(contains(o4, "YES\r\n"), "true branch runs")
check(not_contains(o4, "NOPE"), "false branch skipped")
check(contains(o4, "FIN\r\n"), "execution continues")

print("== comparison operators ==")
let o5 = run_prog([
    "10 IF 5>3 GOTO 40",
    "20 PRINT \"BAD1\"",
    "30 GOTO 50",
    "40 PRINT \"OK1\"",
    "50 IF 5<=3 GOTO 90",
    "60 PRINT \"OK2\"",
    "70 IF 2<>2 GOTO 90",
    "80 PRINT \"OK3\"",
    "90 PRINT \"DONE\"",
])
check(contains(o5, "OK1\r\n"), ">  true branch")
check(contains(o5, "OK2\r\n"), "<= false branch falls through")
check(contains(o5, "OK3\r\n"), "<> false branch falls through")
check(contains(o5, "DONE\r\n"), "all branches converge")

print("== semicolon / blank PRINT ==")
let o6 = run_prog([
    "10 PRINT \"AB\";",
    "20 PRINT \"CD\"",
    "30 PRINT",
    "40 PRINT 1",
])
check(contains(o6, "ABCD\r\n"), "semicolon suppresses newline")
check(contains(o6, "\r\n1\r\n"), "blank PRINT emits newline")

print("== divide by zero ==")
let o7 = run_prog([
    "10 LET A=5",
    "20 PRINT A/0",
])
check(contains(o7, "0\r\n"), "division by zero yields 0")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")