import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

# Test all the security fixes
# 1. Divide by zero
o.command("10 PRINT 1/0")
print("1/0:", o.drain())

# 2. BSAVE huge length
o.command("BSAVE TEST,A0,L99999")
print("BSAVE huge:", o.drain())

# 3. EXEC recursion
o.command("EXEC test")
print("EXEC:", o.drain())

# 4. POKE to UART
o.command("10 POKE 2000, 65")
print("POKE $2000:", o.drain())

# 5. CALL -151 -> monitor
o.command("CALL -151")
print("CALL -151:", o.drain())

# 6. Monitor huge dump
o.command("800.FFFFFFFF")
print("huge dump:", o.drain())

# 7. BLOAD to UART
o.command("BLOAD TEST,A2000")
print("BLOAD $2000:", o.drain())

# 8. Valid BSAVE/BLOAD
o.command("BSAVE TEST,A768,L4")
o.drain()
o.command("BLOAD TEST")
print("BLOAD valid:", o.drain())

# 9. Deep FOR loop
o.command("10 FOR I=1 TO 100: PRINT I: NEXT I")
o.drain()
o.command("RUN")
print("FOR loop:", o.drain()[:100])

