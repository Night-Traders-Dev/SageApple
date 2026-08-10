import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

proc test(cmd):
    o.command(cmd)
    let out = o.drain()
    var s = out
    if len(s) > 200:
        s = slice(s, 0, 200)
    print(cmd, "->", s)

# DOS 3.3 commands
test("CATALOG")
test("SAVE TESTPROG")
test("CATALOG")
test("LOAD TESTPROG")
test("RUN TESTPROG")
test("DELETE TESTPROG")
test("CATALOG")
test("SAVE TESTPROG")
test("LOCK TESTPROG")
test("CATALOG")
test("UNLOCK TESTPROG")
test("CATALOG")
test("RENAME TESTPROG,NEWNAME")
test("CATALOG")
test("VERIFY NEWNAME")

# BSAVE/BLOAD/BRUN
test("10 PRINT \"HELLO\"")
test("BSAVE BIN1,A768,L4")
test("CATALOG")
test("BLOAD BIN1")
test("BRUN BIN1")

# MAXFILES
test("MAXFILES 3")
test("MAXFILES 99")

# MON/NOMON
test("MON C,I,O")
test("NOMON C,I,O")

# PR#/IN#
test("PR#0")
test("IN#0")

# Monitor
test("CALL -151")
test("800.")
test("800L")
test("E")

