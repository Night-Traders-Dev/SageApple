#########################################################################
## SageApple — Apple memory bus (PLAN.md §11 map)
##
##   $0000-$07FF  2KB RAM (writable)
##   $0800-$1FFF  reserved (reads 0)
##   $2000-$3FFF  I/O  (reserved)
##   $4000-$7FFF  expansion (reserved)
##   $8000-$FFFF  32KB Program ROM (read-only to the 6502)
##   $F000-$F0FF  console I/O window (M5/M6 UART device)
#########################################################################

class AppleBus:
    proc init(self):
        self.ram = []
        self.rom = []
        self.console = []
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
        if addr >= 0x8000 and addr <= 0xFFFF:
            return self.rom[addr - 0x8000]
        return 0x00

    proc write8(self, addr, value):
        addr = addr & 0xFFFF
        if addr < 0x0800:
            self.ram[addr] = value & 0xFF
        elif addr >= 0x8000 and addr <= 0xFFFF:
            return                      # ROM read-only
        elif addr == 0x3000:
            push(self.console, value & 0xFF)  # I/O TX

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

    proc console_output(self):
        var s = ""
        var i = 0
        let n = len(self.console)
        while i < n:
            let b = self.console[i]
            if b == 13:
                s = s + "\r"
            elif b == 10:
                s = s + "\n"
            else:
                s = s + _chr(b)
            i = i + 1
        return s

proc _chr(v):
    let ch = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
    if v >= 32 and v < 127:
        let idx = v - 32
        return ch[idx]
    return " "