#########################################################################
## SageApple — Apple memory bus (PLAN.md §11 map)
##
##   $0000-$07FF  2KB RAM (writable)
##   $0800-$1FFF  reserved (reads 0)
##   $2000-$2001  UART device (M6):
##                  $2000 status (read): bit0 RX-ready, bit1 TX-ready
##                  $2001 read: RX data ; write: TX data
##   $2002-$2004  SPI display controller (M10):
##                  $2002 write: display command (DC low)
##                  $2003 write: display data   (DC high)
##                  $2004 read:  status (bit7 set = ready); write: reset
##   $2005-$2006  SPI flash controller (M11):
##                  $2005 write: transfer byte to flash; read: last reply
##                  $2006 write: CS level (bit0) ; read: CS level
##   $2007        PWM speaker (M12): write frequency (0 = silence)
##   $2008-$3FFF  I/O  (reserved)
##   $4000-$7FFF  expansion (reserved)
##   $8000-$FFFF  32KB Program ROM (read-only to the 6502)
##   $F000-$F0FF  legacy console alias (M5) kept readable on writes
#########################################################################

import devices.uart
import devices.display
import devices.flash
import devices.speaker
import sageapple.storage

class AppleBus:
    proc init(self):
        self.uart = uart.UART()
        self.gpu = display.DisplaySPI()
        self.flashdev = flash.Flash(65536)
        self.flash = flash.FlashSPI(self.flashdev)
        self.storage = storage.Storage(self.flashdev)
        self.speaker = speaker.Speaker()
        self.ram = []
        self.rom = []
        var i = 0
        while i < 2048:
            push(self.ram, 0x00)
            i = i + 1
        var j = 0
        while j < 32768:
            push(self.rom, 0x00)
            j = j + 1

    proc read8(self, addr):
        addr = addr & 0xFFFF
        if addr < 0x0800:
            return self.ram[addr]
        if addr == 0x2000:
            return self.uart.status()
        if addr == 0x2001:
            return self.uart.rx_read()
        if addr == 0x2004:
            return self.gpu.status()
        if addr == 0x2005:
            return self.flash.resp
        if addr == 0x2006:
            return self.flash.cs_level()
        if addr == 0x2007:
            return 0x00
        if addr >= 0x8000 and addr <= 0xFFFF:
            return self.rom[addr - 0x8000]
        return 0x00

    proc write8(self, addr, value):
        addr = addr & 0xFFFF
        value = value & 0xFF
        if addr < 0x0800:
            self.ram[addr] = value
            return
        if addr >= 0x8000 and addr <= 0xFFFF:
            return                      # ROM read-only
        if addr == 0x2001:
            self.uart.tx_write(value)   # UART TX data
        elif addr == 0x2002:
            self.gpu.cmd(value)         # display command
        elif addr == 0x2003:
            self.gpu.dat(value)         # display data
        elif addr == 0x2004:
            self.gpu.reset()            # display reset
        elif addr == 0x2005:
            self.flash.byte(value)      # flash: transfer byte
        elif addr == 0x2006:
            self.flash.csl(value & 1)   # flash: CS level
        elif addr == 0x2007:
            self.speaker.tone(value, 100)   # speaker: frequency
        elif addr == 0x3000:
            self.uart.tx_write(value)   # legacy console alias

    proc read16(self, addr):
        return self.read8(addr) | (self.read8(addr + 1) << 8)

    ## load the 32KB program ROM image
    proc load_rom(self, image):
        var i = 0
        let n = len(image)
        while i < n and i < 32768:
            self.rom[i] = image[i] & 0xFF
            i = i + 1

    proc write_ram(self, addr, value):
        self.ram[addr] = value & 0xFF

    ## 6502 -> UART transmitted bytes, rendered to a string
    proc console_output(self):
        return self.uart.tx_text()