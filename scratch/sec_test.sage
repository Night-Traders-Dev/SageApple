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

# Test 1: divide by zero
o.command("10 PRINT 1/0")
print("1/0:", o.drain())

# Test 2: invalid GOTO
o.command("10 GOTO 99999")
print("invalid GOTO:", o.drain())

# Test 3: POKE to UART ($2000)
o.command("10 POKE 2000, 65")
print("POKE $2000:", o.drain())

# Test 4: CALL -151 -> monitor
o.command("CALL -151")
print("CALL -151:", o.drain())

# Test 5: empty command
o.command("")
print("empty:", o.drain())

# Test 6: BLOAD to UART ($2000)
o.command("BLOAD TEST,A2000")
print("BLOAD $2000:", o.drain())

# Test 7: BSAVE huge length
o.command("BSAVE TEST,A0,L99999")
print("BSAVE huge:", o.drain())

# Test 8: comma in filename
o.command("SAVE \"X,Y\"")
print("comma name:", o.drain())

