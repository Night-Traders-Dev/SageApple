import sageapple.machine
import sageapple.os
import time

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

# Benchmark: FOR loop
var start = time.clock()
o.command("10 FOR I=1 TO 5000: NEXT I")
o.drain()
o.command("RUN")
o.drain()
var end = time.clock()
print("FOR 5000 iterations:", (end - start) * 1000, "ms")

# Benchmark: PRINT in loop
start = time.clock()
o.command("10 FOR I=1 TO 100: PRINT I: NEXT I")
o.drain()
o.command("RUN")
o.drain()
end = time.clock()
print("PRINT 100:", (end - start) * 1000, "ms")

# Benchmark: string concatenation
start = time.clock()
o.command("10 A$=\"\": FOR I=1 TO 100: A$=A$+\"X\": NEXT I")
o.drain()
o.command("RUN")
o.drain()
end = time.clock()
print("string concat 100:", (end - start) * 1000, "ms")

# Benchmark: catalog
start = time.clock()
o.command("CATALOG")
o.drain()
end = time.clock()
print("CATALOG:", (end - start) * 1000, "ms")

# Benchmark: save/load
start = time.clock()
o.command("10 PRINT \"HELLO\"")
o.drain()
o.command("SAVE TEST")
o.drain()
o.command("NEW")
o.drain()
o.command("LOAD TEST")
o.drain()
end = time.clock()
print("SAVE+LOAD:", (end - start) * 1000, "ms")

