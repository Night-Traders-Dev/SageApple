#########################################################################
## SageApple — boot sequence test (Milestone 5)
##
## Run:  sage tests/boot/test_boot.sage   (from the repo root)
#########################################################################

import sageapple.machine

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
m.power_on()
let text = m.console_text()

print("---- console output ----")
print(text)
print("------------------------")

check(m.booted == true, "machine reached booted state")
check(contains(text, "SageApple Computer"), "banner line 1")
check(contains(text, "Sage6502 CPU"), "banner line 2")
check(contains(text, "ATmega328P"), "banner line 3")
check(contains(text, "SageApple OS"), "banner OS line")
check(contains(text, "> "), "prompt emitted")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")