#########################################################################
## SageApple — SPI master driver (Milestone 10)
##
## Run:  sage tests/display/test_spi.sage   (from the repo root)
#########################################################################

import devices.spi

var failures = 0
var passes = 0

proc check(cond, msg):
    if cond:
        passes = passes + 1
        print("  PASS:", msg)
    else:
        failures = failures + 1
        print("  FAIL:", msg)

## loopback slave: echo MOSI bit straight back to MISO
class Loopback:
    proc init(self):
        self.frames = []
    proc spi_cs(self, level):
        return
    proc spi_clk(self, master, bit_out):
        return bit_out
    proc spi_frame(self, master, byte):
        push(self.frames, byte)

print("== SPI master bit protocol ==")
let s = spi.SPI()
check(s.transfers == 0, "no transfers before use")
check(s.cs == 1, "CS idles high")
let l = Loopback()
s.attach(l)
s.cs_low()
check(s.cs == 0, "CS asserts low")
let back = s.transfer8(0xA5)
s.cs_high()
check(back == 0xA5, "loopback returns the byte sent")
check(s.transfers == 1, "transfer counted")
check(l.frames[0] == 0xA5, "slave received the framed byte")
check(s.miso == 1, "MISO latches last clocked bit")

let s2 = spi.SPI()
check(s2.transfer8(0x00) == 0, "no slave: reads back 0")
check(s2.transfers == 1, "transfer with no slave counted")

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")