#########################################################################
## SageApple — Machine (boot sequence, PLAN.md §12)
#########################################################################

import sage6502.cpu
import bus.applebus
import sageapple.boot

class SageApple:
    proc init(self):
        self.bus = applebus.AppleBus()
        self.cpu = cpu.CPU(self.bus)
        self.booted = false

    ## load ROM, reset 6502, run until it halts/loops
    proc power_on(self):
        self.bus.load_rom(boot.build_boot_rom())
        self.cpu.reset()
        self.cpu.run()
        self.booted = true

    proc console_text(self):
        return self.bus.console_output()