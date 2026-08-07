#########################################################################
## SageApple — 6502 Memory Bus
##
## Virtual 64KB address space backed by a fixed 65536-byte array. The same
## core runs identically on the host (tests) and later on AVR, where this
## implementation can be swapped for SRAM/Flash-backed storage without
## touching the CPU.
#########################################################################

class Bus:
    proc init(self):
        self.mem = []
        var i = 0
        while i < 65536:
            push(self.mem, 0x00)
            i = i + 1

    ## read a single byte from the 16-bit address space
    proc read8(self, addr):
        return self.mem[addr & 0xFFFF]

    ## write a single byte
    proc write8(self, addr, value):
        self.mem[addr & 0xFFFF] = value & 0xFF

    ## read two bytes little-endian
    proc read16(self, addr):
        return self.read8(addr) | (self.read8(addr + 1) << 8)

    ## bulk-write a byte list (program/ROM image) at a base 16-bit address
    proc load(self, image, base):
        var i = 0
        let n = len(image)
        while i < n:
            self.mem[(base + i) & 0xFFFF] = image[i] & 0xFF
            i = i + 1