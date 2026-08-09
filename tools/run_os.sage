#########################################################################
## SageApple — host OS runner with persistent flash storage
##
## Boots the OS in the host emulator to an interactive shell.  The SPI
## flash filesystem is backed by a disk image file on the host, so files
## survive across runs (and are written back after every command).
##
## Usage:  sage tools/run_os.sage [--image=PATH] [--format] [--no-save] [--test]
##   --image=PATH   SAGEFS disk image file (default build/flash.img)
##   --format       wipe the filesystem and reinstall the stock apps
##   --no-save      don't write the disk image back after the session
##   --test         run the scripted OS verification session (no prompt)
#########################################################################

import sageapple.machine
import sageapple.os
import apps.catalog
import io
import sys

let _FLASH_SIZE = 65536

var image = "build/flash.img"
var do_format = false
var do_save = true
var do_test = false

let argv = sys.args()
var i = 2
while i < len(argv):
    let a = argv[i]
    if a == "--format":
        do_format = true
    elif a == "--no-save":
        do_save = false
    elif a == "--test":
        do_test = true
    elif startswith(a, "--image="):
        image = slice(a, len("--image="), len(a))
    i = i + 1

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

let m = machine.SageApple()
let os = os.OS(m)

print("== persistent storage ==")
var fresh = true
if not do_format and io.exists(image):
    let blob = io.readbytes(image)
    var k = 0
    while k < len(blob) and k < _FLASH_SIZE:
        m.bus.flashdev.mem[k] = blob[k]
        k = k + 1
    if len(blob) >= 2 and blob[0] == 0x53 and blob[1] == 0x46:
        fresh = false
if fresh:
    m.bus.storage.format()
    let nb = catalog.install_basic_apps(m.bus.storage, [])
    let n6 = catalog.install_6502_app(m.bus.storage)
    if do_test:
        check(nb == 3, "fresh disk: three BASIC apps installed")
        check(n6 == 0, "fresh disk: 6502 app installed")
    else:
        print("  fresh SAGEFS disk -> " + image + " (" + str(nb) + " BASIC apps, 6502 app installed)")
else:
    print("  loaded disk image -> " + image)

os.boot()

if do_test:
    check(contains(os.out, "SageApple Computer"), "boot banner shows machine name")
    check(contains(os.out, "SageApple OS 0.1"), "banner advertises the OS")
    check(contains(os.out, "SPI Flash"), "flash reported present")
    print(os.out)

    print("== menu commands ==")
    os.command("help")
    check(contains(os.out, "run"), "help lists run")
    check(contains(os.out, "monitor"), "help lists monitor")
    os.command("info")
    check(contains(os.out, "$2007"), "info lists the speaker port")

    print("== catalog ==")
    os.command("dir")
    check(contains(os.out, "HELLO"), "dir shows HELLO")
    os.command("apps")
    check(contains(os.out, "I HELLO"), "apps marks HELLO installed")

    print("== run apps ==")
    os.command("run HELLO")
    check(contains(os.out, "HELLO FROM SAGEAPPLE"), "run HELLO prints the hello line")
    check(contains(os.out, "RUNNING ON ATMEGA328P"), "run HELLO prints the platform line")
    check(contains(os.out, "OK"), "run HELLO finishes normally")
    os.command("run COUNTER")
    check(contains(os.out, "COUNT 1\r\nCOUNT 2\r\nCOUNT 3"), "run COUNTER counts")

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

    print("== 6502 application loading ==")
    check(os.run_6502_app("MACHINE1", 900000) == 0, "6502 app runs")
    check(contains(m.tx_text(), "6502 APP OK"), "6502 app prints via UART")
    check(m.bus.speaker.count() == 3, "6502 app beeps the speaker")

    print("== monitor reachable from the OS ==")
    os.command("CALL -151")
    check(contains(os.out, "\r\n* "), "OS switches into the monitor")
    os.command("E")
    check(contains(os.out, "\r\n] "), "E returns to BASIC")

    print("== final catalog ==")
    os.command("dir")
    check(contains(os.out, "MYPROG"), "dir shows persisted MYPROG")

    if do_save:
        io.writebytes(image, m.bus.flashdev.mem)
        check(io.exists(image) and io.filesize(image) == _FLASH_SIZE, "disk image written (" + image + ")")

    print("")
    print("Results:", passes, "passed,", failures, "failed")
    if failures == 0:
        print("ALL OK")
    else:
        sys.exit(1)
else:
    sys.stdout_write(os.out)
    var line = input()
    while line != nil:
        if line == "exit" or line == "quit":
            break
        if len(line) == 0:
            sys.stdout_write("> ")
        else:
            let prev = len(os.out)
            os.command(line)
            sys.stdout_write(slice(os.out, prev, len(os.out)))
            if do_save:
                io.writebytes(image, m.bus.flashdev.mem)
        line = input()
    if do_save:
        io.writebytes(image, m.bus.flashdev.mem)
        print("\r\n[exited — disk image saved -> " + image + "]")
