#########################################################################
## SageApple — Apple II software stack (Milestone 13)
##
## Host Apple II monitor (dumps/disassembly/go), DOS 3.3 command
## processor, and the unified ] BASIC / * monitor shell.
##
## Run:  sage tests/machine/test_apple2.sage   (from the repo root)
#########################################################################

import sageapple.machine
import sageapple.os

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

let m = machine.SageApple()
let os = os.OS(m)
m.bus.storage.format()
os.boot()
os.drain()

print("== DOS 3.3 catalog ==")
os.command("catalog")
check(contains(os.out, "DISK VOLUME 254"), "catalog prints the volume header")
os.command("10 PRINT \"DOS TEST\"")
os.drain()
os.command("save TESTPROG")
os.drain()
os.command("catalog")
check(contains(os.out, " A 002 TESTPROG"), "catalog lists an Applesoft file")
os.command("lock TESTPROG")
os.drain()
os.command("catalog")
check(contains(os.out, "*A 002 TESTPROG"), "locked files show the * marker")
os.command("unlock TESTPROG")
os.drain()
os.command("catalog")
check(contains(os.out, " A 002 TESTPROG"), "unlock clears the marker")
os.command("rename TESTPROG,OTHER")
os.drain()
os.command("catalog")
check(contains(os.out, "OTHER") and not contains(os.out, "TESTPROG"), "rename moves the entry")
os.command("delete OTHER")
os.drain()
os.command("catalog")
check(not contains(os.out, "OTHER"), "delete removes the entry")

print("== DOS file verbs ==")
os.command("10 PRINT \"HELLO DOS\"")
os.command("20 END")
os.drain()
os.command("save PROG1")
os.drain()
os.command("new")
os.drain()
os.command("run PROG1")
check(contains(os.out, "HELLO DOS"), "run FILE loads and executes a program")
os.command("verify PROG1")
check(not contains(os.out, "ERROR"), "verify reports no errors")
os.command("verify MISSING")
check(contains(os.out, "FILE NOT FOUND"), "verify missing file errors")
os.command("run PROG1")
os.drain()
os.command("delete PROG1")
os.drain()
os.command("run PROG1")
check(contains(os.out, "FILE NOT FOUND"), "run missing file errors")
os.command("load PROG1")
check(contains(os.out, "FILE NOT FOUND"), "load missing file errors")

print("== DOS binary files ==")
os.command("bsave BIN1,A768,L4")
os.drain()
os.command("catalog")
check(contains(os.out, " B 002 BIN1"), "bsave stores a binary file")
os.command("bload BIN1")
check(not contains(os.out, "ERROR"), "bload loads it back")
os.command("save PROG1")
os.drain()
os.command("bload PROG1")
check(contains(os.out, "FILE TYPE MISMATCH"), "bload refuses non-binary files")
os.command("delete BIN1")
os.drain()

print("== DOS system commands ==")
os.command("maxfiles 3")
os.drain()
check(not contains(os.out, "ERROR"), "maxfiles accepts 3")
os.command("maxfiles 99")
check(contains(os.out, "RANGE ERROR"), "maxfiles rejects out-of-range")
os.drain()
os.command("mon c,i,o")
os.drain()
check(not contains(os.out, "ERROR"), "mon accepts flags")
os.command("nomon c,i,o")
os.drain()
check(not contains(os.out, "ERROR"), "nomon accepts flags")
os.command("pr#0")
os.drain()
check(not contains(os.out, "ERROR"), "pr#0 accepted")
os.command("in#0")
os.drain()
check(not contains(os.out, "ERROR"), "in#0 accepted")

print("== host Apple II monitor ==")
os.command("CALL -151")
check(contains(os.out, "\r\n* "), "CALL -151 drops into the monitor")
os.command("800.")
check(contains(os.out, "0800- "), "monitor dumps a memory row")
os.command("800L")
check(contains(os.out, "LDA") or contains(os.out, "BRK"), "monitor disassembles")
os.command("")
check(contains(os.out, "\r\n* "), "blank line reprints the * prompt")
os.command("E")
check(contains(os.out, "\r\n] "), "E returns to BASIC")

print("== BASIC program with INPUT over the shell ==")
os.command("10 INPUT \"NAME\";N$")
os.command("20 PRINT \"HELLO \";N$")
os.command("30 END")
os.drain()
os.command("run")
check(contains(os.out, "NAME"), "run prompts for input")
os.command("APPLE")
check(contains(os.out, "HELLO APPLE"), "program resumes and prints")

print("== immediate Applesoft ==")
os.command("PRINT 2^8")
check(contains(os.out, "256\r\n"), "power operator works")
os.command("PRINT 1/0")
check(contains(os.out, "DIVISION BY ZERO"), "errors report properly")
os.drain()

print("== POKE/PEEK reach the machine bus ==")
os.command("10 POKE 1024,65")
os.command("20 PRINT PEEK(1024)")
os.drain()
os.command("RUN")
check(contains(os.out, "65\r\n"), "POKE writes RAM, PEEK reads it back")
os.drain()

print("== clear screen ==")
os.command("clear")
check(contains(os.out, "\x1b[2J\x1b[H"), "shell clear emits the ANSI clear sequence")
os.drain()
os.command("HOME")
check(contains(os.out, "\x1b[2J\x1b[H"), "immediate HOME clears too")
os.drain()
os.command("10 HOME")
os.drain()
os.command("RUN")
check(contains(os.out, "\x1b[2J\x1b[H"), "HOME works inside a program")
os.drain()

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
else:
    print("APPLE2 FAILURES:", failures)
