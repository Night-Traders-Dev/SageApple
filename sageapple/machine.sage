#########################################################################
## SageApple — Machine (boot sequence, PLAN.md §12)
#########################################################################

import sage6502.cpu
import bus.applebus
import sageapple.boot
import devices.uart

class SageApple:
    proc init(self):
        self.bus = applebus.AppleBus()
        self.cpu = cpu.CPU(self.bus)
        self.booted = false

    ## load ROM, reset 6502, run until it halts/loops
    proc power_on(self):
        self.bus.load_rom(boot.build_boot_rom())
        self.cpu.reset()
        self.cpu.run(1000000)
        self.booted = true

    ## load an arbitrary ROM image (monitor / BASIC) without running
    proc boot_rom(self, image):
        self.bus.load_rom(image)
        self.cpu.reset()
        self.booted = true

    proc console_text(self):
        return self.bus.console_output()

    ## host terminal -> UART RX FIFO
    proc uart_receive(self, s):
        return self.bus.uart.receive_str(s)

    proc uart_status(self):
        return self.bus.uart.status()

    proc tx_text(self):
        return self.bus.uart.tx_text()

    proc tx_len(self):
        return self.bus.uart.tx_len()