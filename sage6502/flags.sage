#########################################################################
## SageApple — 6502 Processor Status Register (P)
##
## Bit layout:
##
##   7 6 5 4 3 2 1 0
##   N V 1 B D I Z C
##
## Flags:
##
##   N = Negative
##   V = Overflow
##   - = Unused / bit 5 (normally reads as 1 when pushed)
##   B = Break
##   D = Decimal Mode
##   I = Interrupt Disable
##   Z = Zero
##   C = Carry
##
## Internal representation:
##
##   Bit 5 is preserved internally but normalized to 1 when producing
##   stack/status bytes for authentic 6502 behavior.
#########################################################################

class Status:

    #####################################################################
    ## Flag masks
    #####################################################################

    proc init(self):
        self.p = 0x00


    #####################################################################
    ## Raw status register access
    #####################################################################

    proc get(self):
        return self.p & 0xFF


    proc set(self, v):
        self.p = v & 0xFF


    #####################################################################
    ## Internal flag manipulation
    #####################################################################

    proc _set(self, mask, val):
        if val:
            self.p = (self.p | mask) & 0xFF
        else:
            self.p = self.p & (0xFF ^ mask)


    proc clear_mask(self, mask):
        self.p = self.p & (0xFF ^ mask)


    proc set_mask(self, mask):
        self.p = (self.p | mask) & 0xFF


    #####################################################################
    ## Flag getters
    #####################################################################

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


    #####################################################################
    ## Flag setters
    ##
    ## Any truthy value sets the flag.
    ## Any falsey value clears the flag.
    #####################################################################

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


    #####################################################################
    ## Update Negative and Zero flags
    ##
    ## Used by most 6502 instructions that produce an 8-bit result.
    ##
    ## N = bit 7 of result
    ## Z = result == 0
    ##
    ## All other flags remain unchanged.
    #####################################################################

    proc upd_nz(self, value):

        let v = value & 0xFF

        ## Clear existing N and Z flags.
        ##
        ## 0x7D = 01111101
        ##
        ## Clears:
        ##   bit 7 = N
        ##   bit 1 = Z
        ##
        ## Preserves:
        ##   V, unused, B, D, I, C

        self.p = self.p & 0x7D

        ## Negative flag follows bit 7.
        self.p = self.p | (v & 0x80)

        ## Zero flag.
        if v == 0:
            self.p = self.p | 0x02

        self.p = self.p & 0xFF


    #####################################################################
    ## Create a processor status byte for stack operations.
    ##
    ## The 6502 normally pushes:
    ##
    ##   N V 1 B D I Z C
    ##
    ## Bit 5 is always represented as 1.
    ##
    ## break_flag:
    ##
    ##   1 = PHP / BRK
    ##   0 = IRQ / NMI
    #####################################################################

    proc to_push_byte(self, break_flag):

        var v = self.p & 0xFF

        ## Bit 5 is always set in pushed status bytes.
        v = v | 0x20

        ## Set or clear Break flag depending on push source.
        if break_flag:
            v = v | 0x10
        else:
            v = v & 0xEF

        return v & 0xFF


    #####################################################################
    ## Set processor status from a stack pull.
    ##
    ## Used by:
    ##
    ##   PLP
    ##   RTI
    ##
    ## Bit 5 is normalized to 1.
    #####################################################################

    proc from_byte(self, v):

        self.p = (v & 0xFF) | 0x20


    #####################################################################
    ## Clear all flags
    #####################################################################

    proc clear(self):
        self.p = 0x00


    #####################################################################
    ## Reset status register
    ##
    ## Typical 6502 reset state:
    ##
    ##   I = 1
    ##
    ## Other flags cleared.
    #####################################################################

    proc reset(self):
        self.p = 0x04


    #####################################################################
    ## Debug helper
    ##
    ## Returns status as:
    ##
    ##   NV-BDIZC
    ##
    ## Example:
    ##
    ##   N-B--IZC
    #####################################################################

    proc flags_string(self):

        var result = ""

        if self.N():
            result = result + "N"
        else:
            result = result + "-"

        if self.V():
            result = result + "V"
        else:
            result = result + "-"

        ## Bit 5 placeholder.
        result = result + "-"

        if self.B():
            result = result + "B"
        else:
            result = result + "-"

        if self.D():
            result = result + "D"
        else:
            result = result + "-"

        if self.I():
            result = result + "I"
        else:
            result = result + "-"

        if self.Z():
            result = result + "Z"
        else:
            result = result + "-"

        if self.C():
            result = result + "C"
        else:
            result = result + "-"

        return result
