import sageapple.machine
import sageapple.os
import sageapple.dos
import sageapple.storage
import sageapple.monitor

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

proc test(cmd, desc):
    o.command(cmd)
    let out = o.drain()
    print("TEST:", desc)
    print("  cmd:", cmd)
    let s = out
    if len(s) > 200:
        s = slice(s, 0, 200)
    print("  out:", s)
    print("  ---")

# 1. Divide by zero
test("10 PRINT 1/0", "divide by zero")

# 2. Invalid GOTO label
test("10 GOTO 99999", "invalid GOTO label")

# 3. Deep FOR loop (finite)
test("10 FOR I=1 TO 1000: PRINT I: NEXT I", "deep FOR loop")

# 4. POKE to device address ($2000 = UART status)
test("10 POKE 2000, 65", "POKE to UART status register")

# 5. CALL to monitor entry (-151)
test("CALL -151", "CALL -151 -> monitor")

# 6. Very long line (tokenizer stress)
var long = "10 REM " + "X" * 50000
test(long, "50KB line")

# 7. Empty command
test("", "empty command")

# 8. Control characters in string
test("10 PRINT CHR$(27)", "ESC char in PRINT")

# 9. BSAVE with huge length (DoS vector)
test("BSAVE TEST,A0,L999999999", "BSAVE huge length")

# 10. DOS catalog with weird name
test("SAVE \"X,Y\"", "comma in name")

# 11. Unterminated quote in INPUT
test("10 INPUT \"unterminated", "unterminated quote in INPUT")

# 12. BLOAD to device register
test("BLOAD TEST,A2000", "BLOAD to UART")

# 13. Monitor dump with huge range
test("800.FFFFFFFF", "monitor huge dump range")

# 14. Self-referencing EXEC (infinite recursion)
test("EXEC test", "EXEC recursion")

