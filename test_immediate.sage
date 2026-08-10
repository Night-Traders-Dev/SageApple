import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

# Test immediate IF/THEN
o.command("IF 1 THEN PRINT \"OK\"")
print("IF 1 THEN:", o.drain())

# Test immediate FOR
o.command("FOR I=1 TO 3: PRINT I: NEXT I")
print("FOR:", o.drain())

# Test immediate GOSUB
o.command("GOSUB 100")
print("GOSUB:", o.drain())

# Test immediate ON GOTO
o.command("ON 2 GOTO 10,20,30")
print("ON GOTO:", o.drain())

# Test immediate READ/DATA
o.command("READ A,B: PRINT A+B")
o.drain()
o.command("DATA 1,2")
print("READ/DATA:", o.drain())

