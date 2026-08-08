#########################################################################
## SageApple — SPI flash storage (PLAN.md §21 / M11)
##
## Model of a SPI NOR flash chip (JEDEC id EF 40 15) behind the SPI
## master.  Host-backed RAM array, so data persists for the lifetime of
## the object (mirrors a real chip on the AVR target).
##
## Supported commands:
##   $06 write enable        $04 write disable
##   $05 read status reg     $9F JEDEC id
##   $03 read data           $02 page program (needs write enable)
##   $20 sector erase 4K     (needs write enable)
##
## Bus interface (see bus/applebus.sage):
##   $2005  write: transfer a byte to the flash ; read: last received
##   $2006  write: CS level (bit0 = assert)     ; read: CS level
## CS must be asserted (low) across a whole command frame.
#########################################################################

import devices.spi

class Flash:
    proc init(self, size):
        self.size = size
        self.mem = []
        var i = 0
        while i < size:
            push(self.mem, 0xFF)
            i = i + 1
        self.wel = 0
        self.expect = 0            # 0=opcode, 3=addr bytes, 10=read stream,
        self.cmd = 0               # 11=program stream, 12=id stream
        self.argv = []
        self.addr = 0
        self.idx = 0
        self.out = 0xFF            # byte available to the master

    ## ---- SPI slave side ----
    proc spi_cs(self, level):
        if level == 0:
            self.expect = 0
            self.cmd = 0
            self.argv = []
            self.idx = 0
        return

    proc spi_clk(self, master, bit_out):
        return 0

    proc spi_frame(self, master, byte):
        self.feed(byte)

    ## ---- command decode ----
    proc feed(self, b):
        if self.expect == 0:
            self.cmd = b
            if b == 0x06:
                self.wel = 1
            elif b == 0x04:
                self.wel = 0
            elif b == 0x9F:
                self.expect = 12
                self.idx = 0
                self.out = 0xEF
            elif b == 0x05:
                self.out = 0x00
                if self.wel:
                    self.out = self.out | 0x02
            elif b == 0x03 or b == 0x02 or b == 0x20:
                self.expect = 3
                self.argv = []
        elif self.expect == 3:
            push(self.argv, b)
            if len(self.argv) == 3:
                self.addr = (self.argv[0] << 16) | (self.argv[1] << 8) | self.argv[2]
                if self.cmd == 0x03:
                    self.expect = 10
                    self.out = self.mem[self.addr & (self.size - 1)]
                elif self.cmd == 0x02:
                    self.expect = 11
                elif self.cmd == 0x20:
                    self.expect = 0
                    if self.wel:
                        var base = self.addr & 0xFFF000
                        var i = 0
                        while i < 4096:
                            if base + i < self.size:
                                self.mem[base + i] = 0xFF
                            i = i + 1
        elif self.expect == 10:
            self.addr = self.addr + 1
            self.out = self.mem[self.addr & (self.size - 1)]
        elif self.expect == 11:
            if self.wel:
                self.mem[self.addr & (self.size - 1)] = b & 0xFF
            self.addr = self.addr + 1
        elif self.expect == 12:
            self.idx = self.idx + 1
            if self.idx == 1:
                self.out = 0x40
            elif self.idx == 2:
                self.out = 0x15
            else:
                self.out = 0x00

#########################################################################
## Bus-facing flash controller: drives the SPI master + flash chip.
#########################################################################

class FlashSPI:
    proc init(self, chip):
        self.chip = chip
        self.spi = spi.SPI()
        self.spi.attach(chip)
        self.resp = 0xFF           # last byte received from the chip

    ## $2005 write: transfer one byte; chip's reply lands in resp
    proc byte(self, b):
        self.spi.transfer8(b)
        self.resp = self.chip.out

    ## $2006 write: CS level (bit0)
    proc csl(self, level):
        if level == 1:
            self.spi.cs_low()
        else:
            self.spi.cs_high()

    ## $2006 read: current CS level
    proc cs_level(self):
        return self.spi.cs
