#########################################################################
## SageApple — SPI master driver (PLAN.md §18 / M10)
##
## Bit-level model of the ATmega328P SPI hardware: SCK toggles per bit,
## MOSI carries data out MSB-first, MISO shifts data in.  A slave device
## (duck-typed: spi_cs / spi_clk / spi_frame) is driven by the master.
##
## Host emulation only — on the AVR target these same calls drive the
## real USART/SPI registers.
#########################################################################

class SPI:
    proc init(self):
        self.slave = nil
        self.cs = 1                  # idle high (active low)
        self.mosi = 0
        self.miso = 0
        self.transfers = 0           # complete byte transfers

    ## attach a slave device (display, flash, ...)
    proc attach(self, dev):
        self.slave = dev

    proc cs_low(self):
        self.cs = 0
        if self.slave != nil:
            self.slave.spi_cs(0)

    proc cs_high(self):
        self.cs = 1
        if self.slave != nil:
            self.slave.spi_cs(1)

    ## clock out one byte (MSB first), clocking in MISO on the way
    proc transfer8(self, byte):
        byte = byte & 0xFF
        var in_byte = 0
        var i = 0
        while i < 8:
            let bit_out = (byte >> (7 - i)) & 1
            self.mosi = bit_out
            var bit_in = 0
            if self.slave != nil:
                bit_in = self.slave.spi_clk(self, bit_out)
            else:
                bit_in = 0
            self.miso = bit_in
            in_byte = (in_byte << 1) | bit_in
            i = i + 1
        if self.slave != nil:
            self.slave.spi_frame(self, byte)
        self.transfers = self.transfers + 1
        return in_byte
