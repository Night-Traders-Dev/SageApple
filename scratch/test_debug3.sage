import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
print("After boot, o type:", o)
o.drain()
print("After first drain")

o.command("catalog")
print("After command, o type:", o)
o.drain()
print("After second drain")
