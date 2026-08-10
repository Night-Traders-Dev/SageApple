#########################################################################
## SageApple — SPI display controller (PLAN.md §18 / M10)
##
## SSD1306-style 128x64 monochrome OLED attached to the SPI master.
## The framebuffer lives on the display controller (1024 bytes host-side),
## NOT in the 6502's 2KB SRAM.
##
## Decoded commands:
##   $00-$0F / $10-$1F  column address (low/high nibble)
##   $B0-$B7           page address
##   $AE / $AF         display off / on
##   $20 / $21 / $22   memory mode / column window / page window (+params)
##   $81, $8D, $D5 ...  parameter commands (params absorbed as data)
##   $A4-$A7           resume / all-on / normal / inverted
##
## Bus interface (see bus/applebus.sage):
##   $2002  write: display command (DC low)
##   $2003  write: display data   (DC high)
##   $2004  read:  status (0x80 = ready) ; write: reset
#########################################################################

import devices.spi

class OLED:
    proc init(self):
        self.fb = []                 # 8 pages x 128 columns, 1 bit deep
        var i = 0
        while i < 1024:
            push(self.fb, 0)
            i = i + 1
        self.page = 0                # write cursor
        self.col = 0
        self.dc = 0                  # data/command pin level
        self.on = 0
        self.mode = 2                # 0 horizontal, 1 vertical, 2 page
        self.cmd_pending = 0         # parameter bytes owed by a command
        self.cmd_code = 0
        self.col_a = 0
        self.col_b = 127
        self.page_a = 0
        self.page_b = 7
        self.contrast = 0xCF

    ## ---- SPI slave side ----
    proc spi_cs(self, level):
        return

    proc spi_clk(self, master, bit_out):
        return 0

    ## a full byte has been clocked in; decode it
    proc spi_frame(self, master, byte):
        self.byte(byte)

    ## ---- protocol decoder ----
    proc byte(self, b):
        if self.cmd_pending > 0:
            self.param(b)
            return
        if self.dc == 1:
            self.data(b)
            return
        self.command(b)

    proc command(self, b):
        if b >= 0x00 and b <= 0x0F:
            self.col = (self.col & 0xF0) | b
        elif b >= 0x10 and b <= 0x1F:
            self.col = ((b & 0x0F) << 4) | (self.col & 0x0F)
        elif b >= 0xB0 and b <= 0xB7:
            self.page = b & 0x07
            self.col = 0
        elif b == 0xAE:
            self.on = 0
        elif b == 0xAF:
            self.on = 1
        elif b == 0x20 or b == 0x21 or b == 0x22:
            self.cmd_code = b
            if b == 0x20:
                self.cmd_pending = 1
            else:
                self.cmd_pending = 2
        elif b == 0x81 or b == 0x8D or b == 0xD3 or b == 0xD5 or b == 0xA8 or b == 0xDA or b == 0xDB or b == 0xD9:
            self.cmd_code = b
            self.cmd_pending = 1

    proc param(self, b):
        self.cmd_pending = self.cmd_pending - 1
        if self.cmd_code == 0x20:
            self.mode = b & 0x03
        elif self.cmd_code == 0x21:
            if self.cmd_pending == 1:
                self.col_a = b & 0x7F
                self.col = b & 0x7F
            else:
                self.col_b = b & 0x7F
        elif self.cmd_code == 0x22:
            if self.cmd_pending == 1:
                self.page_a = b & 0x07
                self.page = b & 0x07
            else:
                self.page_b = b & 0x07
        elif self.cmd_code == 0x81:
            self.contrast = b

    ## write a data byte at the cursor
    proc data(self, b):
        let idx = self.page * 128 + self.col
        if idx >= 0 and idx < 1024:
            self.fb[idx] = b
        self.col = self.col + 1
        if self.col > self.col_b:
            self.col = self.col_a
            if self.mode != 2:
                self.page = self.page + 1
                if self.page > self.page_b:
                    self.page = self.page_a

#########################################################################
## Bus-facing display controller: drives the SPI master + OLED decoder.
#########################################################################

class DisplaySPI:
    proc init(self):
        self.spi = spi.SPI()
        self.oled = OLED()
        self.spi.attach(self.oled)

    ## $2002: command byte (DC low)
    proc cmd(self, b):
        self.oled.dc = 0
        self.spi.cs_low()
        self.spi.transfer8(b)
        self.spi.cs_high()

    ## $2003: data byte (DC high)
    proc dat(self, b):
        self.oled.dc = 1
        self.spi.cs_low()
        self.spi.transfer8(b)
        self.spi.cs_high()

    ## $2004 read: status (bit7 set = ready)
    proc status(self):
        return 0x80

    ## $2004 write: reset
    proc reset(self):
        self.oled = OLED()
        self.spi.attach(self.oled)
