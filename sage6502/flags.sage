#########################################################################
## SageApple — 6502 Processor Status Register (P)
##
## Bit layout:
##   7 6 5 4 3 2 1 0
##   N V - B D I Z C
#########################################################################

class Status:
    proc init(self):
        self.p = 0x00

    ## raw status byte
    proc get(self):
        return self.p

    proc set(self, v):
        self.p = v & 0xFF

    proc _set(self, mask, val):
        if val:
            self.p = self.p | mask
        else:
            self.p = self.p & (0xFF - mask)

    proc clear_mask(mask):
        self.p = self.p & (0xFF ^ mask)

    ## flag getters
    proc N(self):
        if self.p & 0x80:
            return 1
        return 0

    proc V(self):
        if self.p & 0x40:
            return 1
        return 0

    proc B(self):
        if self.p & 0x10:
            return 1
        return 0

    proc D(self):
        if self.p & 0x08:
            return 1
        return 0

    proc I(self):
        if self.p & 0x04:
            return 1
        return 0

    proc Z(self):
        if self.p & 0x02:
            return 1
        return 0

    proc C(self):
        if self.p & 0x01:
            return 1
        return 0

    ## flag setters (val: truthy -> set)
    proc set_N(self, val):
        self._set(0x80, val)

    proc set_V(self, val):
        self._set(0x40, val)

    proc set_B(self, val):
        self._set(0x10, val)

    proc set_D(self, val):
        self._set(0x08, val)

    proc set_I(self, val):
        self._set(0x04, val)

    proc set_Z(self, val):
        self._set(0x02, val)

    proc set_C(self, val):
        self._set(0x01, val)

    ## set N and Z from a result byte (mirrors the CPU's common flag path)
    proc upd_nz(self, value):
        value = value & 0xFF
        self.set_N(value & 0x80)
        if value == 0:
            self.set_Z(1)
        else:
            self.set_Z(0)

    ## set P register from a stack push/pull byte
    proc from_byte(self, v):
        self.p = v & 0xFF