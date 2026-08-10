import apps.catalog
import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

print("Testing catalog apps...")
let apps = apps.catalog.basic_apps()
var i = 0
while i < len(apps):
    print("App: ", apps[i][0])
    i = i + 1
