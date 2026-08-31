#########################################################################
## SageApple — 6502 CPU Registers
##
## Register layout:
##
##   A   Accumulator        8-bit
##   X   Index Register X   8-bit
##   Y   Index Register Y   8-bit
##   SP  Stack Pointer      8-bit
##   PC  Program Counter    16-bit
##
## Stack memory:
##
##   $0100 - $01FF
##
## Actual stack address:
##
##   $0100 | SP
#########################################################################

class Registers:


    #####################################################################
    ## Initialize CPU registers
    ##
    ## Typical 6502 reset values:
    ##
    ##   A  = $00
    ##   X  = $00
    ##   Y  = $00
    ##   SP = $FD
    ##   PC = loaded from reset vector by CPU reset logic
    #####################################################################

    proc init(self):

        self.a = 0x00
        self.x = 0x00
        self.y = 0x00

        ## Typical 6502 post-reset stack pointer.
        self.sp = 0xFD

        ## PC should normally be loaded from $FFFC/$FFFD.
        self.pc = 0x0000


    #####################################################################
    ## Accumulator A
    #####################################################################

    proc get_a(self):
        return self.a & 0xFF


    proc set_a(self, v):
        self.a = v & 0xFF


    #####################################################################
    ## Index Register X
    #####################################################################

    proc get_x(self):
        return self.x & 0xFF


    proc set_x(self, v):
        self.x = v & 0xFF


    #####################################################################
    ## Index Register Y
    #####################################################################

    proc get_y(self):
        return self.y & 0xFF


    proc set_y(self, v):
        self.y = v & 0xFF


    #####################################################################
    ## Stack Pointer
    ##
    ## Range:
    ##
    ##   $00 - $FF
    ##
    ## Stack address:
    ##
    ##   $0100 | SP
    #####################################################################

    proc get_sp(self):
        return self.sp & 0xFF


    proc set_sp(self, v):
        self.sp = v & 0xFF


    #####################################################################
    ## Stack address helper
    ##
    ## Returns:
    ##
    ##   $0100 | SP
    ##
    ## Example:
    ##
    ##   SP = $FD
    ##
    ##   Address = $01FD
    #####################################################################

    proc stack_addr(self):
        return 0x0100 | (self.sp & 0xFF)


    #####################################################################
    ## Program Counter
    ##
    ## Range:
    ##
    ##   $0000 - $FFFF
    #####################################################################

    proc get_pc(self):
        return self.pc & 0xFFFF


    proc set_pc(self, v):
        self.pc = v & 0xFFFF


    #####################################################################
    ## Increment Program Counter
    ##
    ## Automatically wraps:
    ##
    ##   $FFFF + 1 = $0000
    #####################################################################

    proc inc_pc(self):

        self.pc = (self.pc + 1) & 0xFFFF


    #####################################################################
    ## Add to Program Counter
    ##
    ## Useful for:
    ##
    ##   instruction lengths
    ##   branch offsets
    ##   addressing operations
    #####################################################################

    proc add_pc(self, value):

        self.pc = (self.pc + value) & 0xFFFF


    #####################################################################
    ## Increment Stack Pointer
    ##
    ## Used for:
    ##
    ##   PLA
    ##   PLP
    ##   RTS
    ##   RTI
    #####################################################################

    proc inc_sp(self):

        self.sp = (self.sp + 1) & 0xFF


    #####################################################################
    ## Decrement Stack Pointer
    ##
    ## Used for:
    ##
    ##   PHA
    ##   PHP
    ##   JSR
    ##   BRK
    ##   IRQ
    ##   NMI
    #####################################################################

    proc dec_sp(self):

        self.sp = (self.sp - 1) & 0xFF


    #####################################################################
    ## Reset registers
    ##
    ## PC is set to zero here.
    ##
    ## The CPU reset procedure should subsequently load PC from:
    ##
    ##   $FFFC = low byte
    ##   $FFFD = high byte
    #####################################################################

    proc reset(self):

        self.a = 0x00
        self.x = 0x00
        self.y = 0x00

        self.sp = 0xFD

        self.pc = 0x0000


    #####################################################################
    ## Debug helper
    ##
    ## Returns a compact register snapshot.
    #####################################################################

    proc debug_string(self):

        return (
            "A=" + str(self.a & 0xFF) +
            " X=" + str(self.x & 0xFF) +
            " Y=" + str(self.y & 0xFF) +
            " SP=" + str(self.sp & 0xFF) +
            " PC=" + str(self.pc & 0xFFFF)
        )
