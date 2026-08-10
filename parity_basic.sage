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
    if len(s) > 100:
        s = slice(s, 0, 100)
    print(cmd, "->", s)

test("PRINT 1+2")
test("PRINT 10/3")
test("LET A=5: PRINT A")
test("A=10: PRINT A")
test("IF 1 THEN PRINT \"OK\"")
test("IF 0 THEN PRINT \"NO\"")
test("IF 1 GOTO 99")
test("FOR I=1 TO 3: PRINT I: NEXT I")
test("10 GOSUB 100: END: 100 PRINT \"SUB\": RETURN")
test("ON 2 GOTO 10,20,30")
test("10 READ A,B: PRINT A+B: DATA 1,2: RUN")
test("DEF FN F(X)=X*X: PRINT FN F(5)")
test("PRINT INT(3.7)")
test("PRINT SQR(16)")
test("PRINT ABS(-5)")
test("PRINT SGN(-3)")
test("PRINT ASC(\"A\")")
test("PRINT CHR$(65)")
test("PRINT LEFT$(\"HELLO\",2)")
test("PRINT RIGHT$(\"HELLO\",2)")
test("PRINT LEN(\"ABC\")")
test("PRINT STR$(123)")
test("PRINT VAL(\"42\")")
test("PRINT 1/0")
test("PRINT 2^1000")

