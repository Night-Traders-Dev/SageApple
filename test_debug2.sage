import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

# Test 1: catalog
o.command("catalog")
print("CATALOG:", o.drain())
