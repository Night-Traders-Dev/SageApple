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

# Test: monitor huge dump range
o.command("800.FFFFFFFF")
print("huge dump:", o.drain())

# Test: EXEC recursion
o.command("EXEC test")
print("EXEC:", o.drain())

# Test: 1/0 with error check
o.command("PRINT 1/0")
print("PRINT 1/0:", o.drain())

# Test: valid BSAVE/BLOAD roundtrip
o.command("BSAVE TEST,A768,L4")
o.drain()
o.command("BLOAD TEST")
print("BLOAD valid:", o.drain())

# Test: deep FOR loop
o.command("10 FOR I=1 TO 100: PRINT I: NEXT I")
o.drain()
o.command("RUN")
print("FOR loop:", o.drain()[:200])

