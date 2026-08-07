#########################################################################
## SageApple — 6502 CPU Registers
##
## A, X, Y  (8-bit), PC (16-bit), SP (8-bit, stack in page $0100)
#########################################################################

class Registers:
    proc init(self):
        self.a = 0x00
        self.y = 0x00
        self.x = 0x00
        self.sp = 0x00
        self.pc = 0x0000

    proc get_pc(self):
        return self.pc

    proc set_pc(self, v):
        self.pc = v & 0xFFFF

    proc get_sp(self):
        return self.sp

    proc set_sp(self, v):
        self.sp = v & 0xFF