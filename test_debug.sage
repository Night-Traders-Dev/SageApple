import sageapple.machine
import sageapple.os

print("Creating machine...")
var m = machine.SageApple()
print("Machine created:", m)

print("Creating OS...")
var o = os.OS(m)
print("OS created:", o)

print("Formatting storage...")
m.bus.storage.format()
print("Storage formatted")

print("Booting OS...")
o.boot()
print("OS booted")

print("Draining...")
o.drain()
print("Drained, out:", o.out)
