import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

o.command("catalog")
print("CATALOG 1:", o.drain())

o.command("10 PRINT \"DOS TEST\"")
o.drain()
o.command("save TESTPROG")
o.drain()
o.command("catalog")
print("CATALOG 2:", o.drain())

o.command("lock TESTPROG")
o.drain()
o.command("catalog")
print("CATALOG 3:", o.drain())

o.command("unlock TESTPROG")
o.drain()
o.command("catalog")
print("CATALOG 4:", o.drain())

o.command("rename TESTPROG,NEWNAME")
o.drain()
o.command("catalog")
print("CATALOG 5:", o.drain())

o.command("delete NEWNAME")
o.drain()
o.command("catalog")
print("CATALOG 6:", o.drain())
