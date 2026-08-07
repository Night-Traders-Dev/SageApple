#########################################################################
## SageApple — monitor test (Milestone 7)
##
## Run:  sage tests/boot/test_monitor.sage   (from the repo root)
#########################################################################

import sageapple.machine
import sageapple.monitor

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
    if nn == 0: return true
    if nn > hn: return false
    var i = 0
    while i <= hn - nn:
        if slice(hay, i, i + nn) == needle:
            return true
        i = i + 1
    return false

var m = machine.SageApple()
m.boot_rom(monitor.build_monitor_rom())
var cpu = m.cpu
var uart = m.bus.uart

## step a fixed budget (the monitor spins while idle), feeding input first
var CGUARD = 60000
proc drive(in_bytes):
    uart.receive_str(in_bytes)
    var steps = 0
    while steps < CGUARD:
        cpu.step()
        steps = steps + 1

## run a terminal command, returning only the newly printed text
proc run(cmd):
    let start = uart.tx_len()
    drive(cmd + "\r")
    return slice(uart.tx_text(), start, uart.tx_len())

print("== boot ==")
drive("")
let boot = slice(uart.tx_text(), 0, uart.tx_len())
check(contains(boot, "SageApple Monitor"), "banner printed")
check(contains(boot, "MON> "), "prompt printed")

print("== help ==")
let h = run("help")
check(contains(h, "Commands:"), "help lists commands")

print("== poke/peek ==")
run("poke 0500 AA")
let pk = run("peek 0500")
check(contains(upper(pk), "AA"), "peek returns poke value")

print("== dump ==")
let dmp = run("dump 0300 0302")
check(contains(upper(dmp), "0300"), "dump shows start address")
check(contains(dmp, ":"), "dump prints byte line")

print("== unknown ==")
let unk = run("zzzz")
check(contains(upper(unk), "?"), "unknown command flagged")

print("== reg ==")
let rg = run("regs")
check(contains(upper(rg), "A="), "regs shows A")
check(contains(upper(rg), "P="), "regs shows P")

print("== run ==")
let rrun = run("run")
check(contains(rrun, "no user program"), "run stub")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")