#########################################################################
## SageApple — UART device + terminal (Milestone 6)
##
## Run:  sage tests/boot/test_uart.sage   (from the repo root)
#########################################################################

import devices.uart
import sageapple.terminal

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

print("== device-level ==")
let d = uart.UART()
check(d.rx_ready() == 0, "RX idle when empty")
d.receive_str("AB")
check(d.rx_ready() == 1, "RX ready after feed")
check(d.rx_read() == 65, "RX reads 'A'")
check(d.rx_read() == 66, "RX reads 'B'")
d.tx_write(72)
d.tx_write(105)
check(d.tx_text() == "Hi", "TX renders host-readable text")
check((d.status() & 0x01) == 0x00, "RX flag clears after drain")

print("== 6502 echo terminal ==")
let t = terminal.Terminal()
let out1 = t.send("AB")
check(out1 == "AB", "6502 echoes 'AB' over UART")
t.send("AB")
let out2 = t.send("CD")
check(out2 == "CD", "terminal tracks incremental output")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")