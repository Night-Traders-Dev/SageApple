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
    print(cmd, "->", out[:150])

# IF/THEN on separate lines (program mode)
test("10 IF 1 THEN 20")
test("20 PRINT \"OK\"")
test("RUN")

# FOR loop in program
test("10 FOR I=1 TO 3")
test("20 PRINT I")
test("30 NEXT I")
test("RUN")

# GOSUB in program
test("10 GOSUB 100")
test("20 END")
test("100 PRINT \"SUB\"")
test("110 RETURN")
test("RUN")

# READ/DATA in program
test("10 READ A,B")
test("20 PRINT A+B")
test("30 DATA 1,2")
test("RUN")

