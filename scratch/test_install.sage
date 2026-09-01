import apps.catalog as cat
import sageapple.machine
import sageapple.os

var m = machine.SageApple()
var o = os.OS(m)
m.bus.storage.format()
o.boot()
o.drain()

# Install all apps
var installed = cat.install_basic_apps(m.bus.storage, [])
print("Installed:", installed, "apps")

# Test CATALOG
o.command("CATALOG")
print("CATALOG:", o.drain())

# Test HELLO WORLD
o.command("RUN HELLO.WORLD")
print("HELLO.WORLD:", o.drain())

# Test COUNTER
o.command("RUN COUNTER")
print("COUNTER:", o.drain())

# Test MUSIC DEMO
o.command("RUN MUSIC.DEMO")
print("MUSIC.DEMO:", o.drain())

# Test BEEP
o.command("RUN BEEP")
print("BEEP:", o.drain())

# Test COUNTER
o.command("RUN COUNTER")
print("COUNTER:", o.drain())

# Test APPLESOFT
o.command("RUN APPLESOFT")
print("APPLESOFT:", o.drain())

# Test MASTERCRT
o.command("RUN MASTERCRT")
print("MASTERCRT:", o.drain())

# Test FID
o.command("RUN FID")
print("FID:", o.drain())

# Test COPYA
o.command("RUN COPYA")
print("COPYA:", o.drain())

# Test DISKRECOV
o.command("RUN DISKRECOV")
print("DISKRECOV:", o.drain())

# Test COLOR.DEMO
o.command("RUN COLOR.DEMO")
print("COLOR.DEMO:", o.drain())

# Test SHAPE.DEMO
o.command("RUN SHAPE.DEMO")
print("SHAPE.DEMO:", o.drain())
