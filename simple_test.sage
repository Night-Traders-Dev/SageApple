import sageapple.machine
import sageapple.os

var m = sageapple.machine.SageApple()
print("machine:", m)
var o = sageapple.os.OS(m)
print("os:", o)
m.bus.storage.format()
o.boot()
print("booted")
o.drain()
print("drained")

# test 1
o.command("10 PRINT 1/0")
print("after 1/0")
print(o.drain())

# test 2
o.command("10 GOTO 10")
print("after infinite GOTO")
print(o.drain())
