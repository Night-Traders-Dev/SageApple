#########################################################################
## SageApple — standalone OS console + application loading (Milestone 12)
##
## Run:  sage tests/machine/test_os.sage   (from the repo root)
#########################################################################

import sageapple.machine
import sageapple.os
import apps.catalog
import sageapple.graphics

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

proc contains(hay, needle):
    let hn = len(hay)
    let nn = len(needle)
    if nn == 0:
        return true
    if nn > hn:
        return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

print("== power-on ==")
let m = machine.SageApple()
let os = os.OS(m)
os.boot()
check(contains(os.out, "SageApple Computer"), "boot banner shows machine name")
check(contains(os.out, "SageApple OS 0.1"), "banner advertises the OS")
check(contains(os.out, "SPI Flash"), "flash reported present")

print("== menu commands ==")
os.command("help")
check(contains(os.out, "run"), "help lists run")
check(contains(os.out, "monitor"), "help lists monitor")
os.command("info")
check(contains(os.out, "$2007"), "info lists the speaker port")

print("== app install ==")
m.bus.storage.format()
check(catalog.install_basic_apps(m.bus.storage, []) == 12, "twelve BASIC apps installed")
check(catalog.install_6502_app(m.bus.storage) == 0, "6502 app installed")
os.command("dir")
check(contains(os.out, "HELLO"), "dir shows HELLO")
check(contains(os.out, "MACHINE1"), "dir shows MACHINE1")
os.command("apps")
check(contains(os.out, "I HELLO"), "apps marks HELLO installed")

print("== definition of done: run hello ==")
os.command("run HELLO")
check(contains(os.out, "HELLO FROM SAGEAPPLE"), "run HELLO prints the hello line")
check(contains(os.out, "RUNNING ON ATMEGA328P"), "run HELLO prints the platform line")
check(contains(os.out, "OK"), "run HELLO finishes normally")
os.command("run COUNTER")
check(contains(os.out, "COUNT 1" + "\r\nCOUNT 2" + "\r\nCOUNT 3"), "run COUNTER counts")

print("== BASIC save / load persistence ==")
os.basic.new()
os.basic.set_line(10, "PRINT \"SAVED PROGRAM\"")
os.basic.set_line(20, "END")
os.command("save MYPROG")
check(m.bus.storage.size_of("MYPROG") != -1, "OS saves the BASIC program (type A)")
os.basic.new()
os.command("run MYPROG")
check(contains(os.out, "SAVED PROGRAM"), "run MYPROG loads and executes")

print("== BEEP app ==")
os.command("run BEEP")
check(m.bus.speaker.count() == 2, "BEEP app played two tones")
let t0 = m.bus.speaker.tone_at(0)
check(t0[0] == 2000, "first BEEP tone 2000Hz")

print("== 6502 application loading ==")
check(os.run_6502_app("MACHINE1", 900000) == 0, "6502 app runs")
check(contains(m.tx_text(), "6502 APP OK"), "6502 app prints via UART")
check(m.bus.speaker.count() == 3, "6502 app beeps the speaker")

print("== monitor reachable from the OS ==")
os.command("CALL -151")
check(contains(os.out, "\r\n* "), "OS switches into the monitor")
os.command("E")
check(contains(os.out, "\r\n] "), "E returns to BASIC")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")