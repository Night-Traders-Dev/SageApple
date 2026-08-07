#########################################################################
## SageApple — Host terminal (PLAN.md §13 / M6)
##
## On the AVR target the 6502 talks to a real UART; on the host we bridge
## scripted input into the device's RX FIFO and read back what the machine
## transmits. This class is the host analogue of the wired-up serial
## terminal that later runs the monitor (M7) and BASIC (M8).
#########################################################################

import sageapple.machine
import sageapple.echo

class Terminal:
    proc init(self):
        self.m = machine.SageApple()
        self.m.boot_rom(echo.build_echo_rom())
        self.offset_tx = 0

    ## push host keyboard input into the UART RX FIFO
    proc feed(self, s):
        self.m.uart_receive(s)

    ## drive the 6502 until input is drained; return newly emitted text
    proc pump(self):
        let m = self.m
        var n = 0
        while n < 4000 and m.bus.uart.rx_ready() == 1:
            m.cpu.step()
            n = n + 1
        var t = 0
        while t < 200 and m.cpu.halted == false:
            m.cpu.step()
            t = t + 1
        let s = self.m.tx_text()
        let idx = self.offset_tx
        self.offset_tx = len(s)
        if idx >= len(s):
            return ""
        return slice(s, idx, len(s))

    ## convenience: feed then pump once
    proc send(self, s):
        self.feed(s)
        return self.pump()

    ## ASCII-escape a lone byte for debugging
    proc last_tx(self):
        return self.m.tx_text()