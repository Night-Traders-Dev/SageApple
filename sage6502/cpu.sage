#########################################################################
## SageApple — Sage6502 CPU core (SageLang)
##
## A table-driven NMOS 6502 emulator.
##
## Address space goes through a Bus object so the same core can run
## on the host and later on AVR hardware.
##
## Features:
##
##   - Canonical NMOS 6502 opcode table
##   - NMOS JMP ($xxFF) indirect-page bug
##   - Indexed page-cross cycle penalties
##   - Branch timing penalties
##   - IRQ / NMI support
##   - Correct stack status handling
##   - BRK software interrupt behavior
##   - Full NMOS binary arithmetic
##   - Full NMOS decimal-mode ADC / SBC
##
## Usage:
##
##   import sage6502.registers
##   import sage6502.flags
##   import cpu
##
##   let c = cpu.CPU(bus)
##   c.reset()
##   c.run(200)
#########################################################################

import sage6502.registers
import sage6502.flags
import sage6502.constants


#########################################################################
## CPU instance scratch buffer for fetch()
##
## Avoids allocating a new list for every effective-address calculation.
##
## Layout:
##
##   [0] = effective address
##   [1] = page crossed
##
## Per-instance (not global) so multiple CPU objects can run concurrently.
#########################################################################


#########################################################################
## Canonical NMOS 6502 opcode table
##
## opcode -> [instruction_id, addressing_mode]
##
## Instruction IDs:
##
##   0   LDA
##   1   LDX
##   2   LDY
##   3   STA
##   4   STX
##   5   STY
##
##   6   TAX
##   7   TXA
##   8   TAY
##   9   TYA
##   10  TSX
##   11  TXS
##
##   12  PHA
##   13  PHP
##   14  PLA
##   15  PLP
##
##   16  ADC
##   17  SBC
##   18  AND
##   19  ORA
##   20  EOR
##   21  BIT
##
##   22  CMP
##   23  CPX
##   24  CPY
##
##   25  INC
##   26  DEC
##
##   27  INX
##   28  INY
##   29  DEX
##   30  DEY
##
##   31  ASL
##   32  LSR
##   33  ROL
##   34  ROR
##
##   35  BCC
##   36  BCS
##   37  BEQ
##   38  BMI
##   39  BNE
##   40  BPL
##   41  BVC
##   42  BVS
##
##   43  JMP
##   44  JSR
##   45  RTS
##
##   46  BRK
##   47  RTI
##   48  NOP
##
##   49  CLC
##   50  CLD
##   51  CLI
##   52  CLV
##   53  SEC
##   54  SED
##   55  SEI
#########################################################################

proc _build_opcodes():

    let t = []

    var i = 0
    while i < 256:
        push(t, [0, M_IMP])
        i = i + 1

    t[0xA9] = [LDA,  M_IMM]
    t[0xA5] = [LDA,  M_ZP]
    t[0xB5] = [LDA,  M_ZPX]
    t[0xAD] = [LDA,  M_ABS]
    t[0xBD] = [LDA,  M_ABSX]
    t[0xB9] = [LDA,  M_ABSY]
    t[0xA1] = [LDA,  M_INDX]
    t[0xB1] = [LDA,  M_INDY]

    t[0xA2] = [LDX,  M_IMM]
    t[0xA6] = [LDX,  M_ZP]
    t[0xB6] = [LDX,  M_ZPY]
    t[0xAE] = [LDX,  M_ABS]
    t[0xBE] = [LDX,  M_ABSY]

    t[0xA0] = [LDY,  M_IMM]
    t[0xA4] = [LDY,  M_ZP]
    t[0xB4] = [LDY,  M_ZPX]
    t[0xAC] = [LDY,  M_ABS]
    t[0xBC] = [LDY,  M_ABSX]

    t[0x85] = [STA,  M_ZP]
    t[0x95] = [STA,  M_ZPX]
    t[0x8D] = [STA,  M_ABS]
    t[0x9D] = [STA,  M_ABSX]
    t[0x99] = [STA,  M_ABSY]
    t[0x81] = [STA,  M_INDX]
    t[0x91] = [STA,  M_INDY]

    t[0x86] = [STX,  M_ZP]
    t[0x96] = [STX,  M_ZPY]
    t[0x8E] = [STX,  M_ABS]

    t[0x84] = [STY,  M_ZP]
    t[0x94] = [STY,  M_ZPX]
    t[0x8C] = [STY,  M_ABS]

    t[0xAA] = [TAX,  M_IMP]
    t[0x8A] = [TXA,  M_IMP]
    t[0xA8] = [TAY,  M_IMP]
    t[0x98] = [TYA,  M_IMP]
    t[0xBA] = [TSX,  M_IMP]
    t[0x9A] = [TXS,  M_IMP]

    t[0x48] = [PHA,  M_IMP]
    t[0x08] = [PHP,  M_IMP]
    t[0x68] = [PLA,  M_IMP]
    t[0x28] = [PLP,  M_IMP]

    t[0x69] = [ADC,  M_IMM]
    t[0x65] = [ADC,  M_ZP]
    t[0x75] = [ADC,  M_ZPX]
    t[0x6D] = [ADC,  M_ABS]
    t[0x7D] = [ADC,  M_ABSX]
    t[0x79] = [ADC,  M_ABSY]
    t[0x61] = [ADC,  M_INDX]
    t[0x71] = [ADC,  M_INDY]

    t[0xE9] = [SBC,  M_IMM]
    t[0xE5] = [SBC,  M_ZP]
    t[0xF5] = [SBC,  M_ZPX]
    t[0xED] = [SBC,  M_ABS]
    t[0xFD] = [SBC,  M_ABSX]
    t[0xF9] = [SBC,  M_ABSY]
    t[0xE1] = [SBC,  M_INDX]
    t[0xF1] = [SBC,  M_INDY]

    t[0x29] = [AND,  M_IMM]
    t[0x25] = [AND,  M_ZP]
    t[0x35] = [AND,  M_ZPX]
    t[0x2D] = [AND,  M_ABS]
    t[0x3D] = [AND,  M_ABSX]
    t[0x39] = [AND,  M_ABSY]
    t[0x21] = [AND,  M_INDX]
    t[0x31] = [AND,  M_INDY]

    t[0x09] = [ORA,  M_IMM]
    t[0x05] = [ORA,  M_ZP]
    t[0x15] = [ORA,  M_ZPX]
    t[0x0D] = [ORA,  M_ABS]
    t[0x1D] = [ORA,  M_ABSX]
    t[0x19] = [ORA,  M_ABSY]
    t[0x01] = [ORA,  M_INDX]
    t[0x11] = [ORA,  M_INDY]

    t[0x49] = [EOR,  M_IMM]
    t[0x45] = [EOR,  M_ZP]
    t[0x55] = [EOR,  M_ZPX]
    t[0x4D] = [EOR,  M_ABS]
    t[0x5D] = [EOR,  M_ABSX]
    t[0x59] = [EOR,  M_ABSY]
    t[0x41] = [EOR,  M_INDX]
    t[0x51] = [EOR,  M_INDY]

    t[0x24] = [BIT,  M_ZP]
    t[0x2C] = [BIT,  M_ABS]

    t[0xC9] = [CMP,  M_IMM]
    t[0xC5] = [CMP,  M_ZP]
    t[0xD5] = [CMP,  M_ZPX]
    t[0xCD] = [CMP,  M_ABS]
    t[0xDD] = [CMP,  M_ABSX]
    t[0xD9] = [CMP,  M_ABSY]
    t[0xC1] = [CMP,  M_INDX]
    t[0xD1] = [CMP,  M_INDY]

    t[0xE0] = [CPX,  M_IMM]
    t[0xE4] = [CPX,  M_ZP]
    t[0xEC] = [CPX,  M_ABS]

    t[0xC0] = [CPY,  M_IMM]
    t[0xC4] = [CPY,  M_ZP]
    t[0xCC] = [CPY,  M_ABS]

    t[0xE6] = [INC,  M_ZP]
    t[0xF6] = [INC,  M_ZPX]
    t[0xEE] = [INC,  M_ABS]
    t[0xFE] = [INC,  M_ABSX]

    t[0xC6] = [DEC,  M_ZP]
    t[0xD6] = [DEC,  M_ZPX]
    t[0xCE] = [DEC,  M_ABS]
    t[0xDE] = [DEC,  M_ABSX]

    t[0xE8] = [INX,  M_IMP]
    t[0xC8] = [INY,  M_IMP]
    t[0xCA] = [DEX,  M_IMP]
    t[0x88] = [DEY,  M_IMP]

    t[0x0A] = [ASL,  M_ACC]
    t[0x06] = [ASL,  M_ZP]
    t[0x16] = [ASL,  M_ZPX]
    t[0x0E] = [ASL,  M_ABS]
    t[0x1E] = [ASL,  M_ABSX]

    t[0x4A] = [LSR,  M_ACC]
    t[0x46] = [LSR,  M_ZP]
    t[0x56] = [LSR,  M_ZPX]
    t[0x4E] = [LSR,  M_ABS]
    t[0x5E] = [LSR,  M_ABSX]

    t[0x2A] = [ROL,  M_ACC]
    t[0x26] = [ROL,  M_ZP]
    t[0x36] = [ROL,  M_ZPX]
    t[0x2E] = [ROL,  M_ABS]
    t[0x3E] = [ROL,  M_ABSX]

    t[0x6A] = [ROR,  M_ACC]
    t[0x66] = [ROR,  M_ZP]
    t[0x76] = [ROR,  M_ZPX]
    t[0x6E] = [ROR,  M_ABS]
    t[0x7E] = [ROR,  M_ABSX]

    t[0x90] = [BCC,  M_REL]
    t[0xB0] = [BCS,  M_REL]
    t[0xF0] = [BEQ,  M_REL]
    t[0x30] = [BMI,  M_REL]
    t[0xD0] = [BNE,  M_REL]
    t[0x10] = [BPL,  M_REL]
    t[0x50] = [BVC,  M_REL]
    t[0x70] = [BVS,  M_REL]

    t[0x4C] = [JMP,  M_ABS]
    t[0x6C] = [JMP,  M_IND]
    t[0x20] = [JSR,  M_ABS]
    t[0x60] = [RTS,  M_IMP]

    t[0x00] = [BRK,  M_IMP]
    t[0x40] = [RTI,  M_IMP]
    t[0xEA] = [NOP,  M_IMP]

    t[0x18] = [CLC,  M_IMP]
    t[0xD8] = [CLD,  M_IMP]
    t[0x58] = [CLI,  M_IMP]
    t[0xB8] = [CLV,  M_IMP]
    t[0x38] = [SEC,  M_IMP]
    t[0xF8] = [SED,  M_IMP]
    t[0x78] = [SEI,  M_IMP]

    return t


var _OPCODES = _build_opcodes()


#############################################################################
## Cycle counts
#############################################################################

proc _atoi(s):

    var v = 0

    for i in range(len(s)):

        let ch = s[i]

        if ch >= "0" and ch <= "9":
            v = v * 10 + (ord(ch) - 48)

    return v


proc _load_cycles():

    let raw = "7,6,2,2,1,3,5,2,3,2,2,2,1,4,6,2,2,5,2,2,1,4,6,2,2,4,2,2,1,4,7,2,6,6,2,2,3,3,5,2,4,2,2,2,4,4,6,2,2,5,2,2,1,4,6,2,2,4,2,2,1,4,7,2,6,6,2,2,1,3,5,2,3,2,2,2,3,4,6,2,2,5,2,2,1,4,7,2,2,4,2,2,1,4,7,2,6,6,2,2,1,3,5,2,4,2,2,2,5,4,6,2,2,5,2,2,1,4,7,2,2,4,2,2,1,4,7,2,2,6,2,2,3,3,3,2,2,2,2,2,4,4,4,2,2,6,2,2,4,4,4,2,2,5,2,2,4,5,2,2,2,6,2,2,3,3,3,2,2,2,2,2,4,4,4,2,2,5,2,2,4,4,4,2,2,4,2,2,4,4,4,2,2,6,2,2,3,3,5,2,2,2,2,2,4,4,6,2,2,5,2,2,1,4,6,2,2,4,2,2,1,4,7,2"

    let parts = split(raw, ",")

    let t = []

    var i = 0

    while i < 256:
        if i < len(parts):
            push(t, _atoi(parts[i]))
        else:
            push(t, 0)
        i = i + 1

    return t


var _CYCLES = _load_cycles()


class CPU:


    #####################################################################
    ## Initialization
    #####################################################################

    proc init(self, bus):

        self.bus = bus

        self.regs = registers.Registers()
        self.status = flags.Status()

        self.halted = false

        self.cycles = 0

        self.irq_pending = false
        self.nmi_pending = false

        self._fetch_scratch = [0, 0]


    #####################################################################
    ## Bus access
    #####################################################################

    proc read8(self, addr):

        return self.bus.read8(addr & 0xFFFF)


    proc write8(self, addr, value):

        self.bus.write8(
            addr & 0xFFFF,
            value & 0xFF
        )


    proc read16(self, addr):

        return self.bus.read16(addr & 0xFFFF)


    #####################################################################
    ## Reset
    ##
    ## NMOS 6502 reset state:
    ##
    ##   A  = 00
    ##   X  = 00
    ##   Y  = 00
    ##   SP = FD
    ##
    ##   I = 1
    ##
    ## PC is loaded from:
    ##
    ##   $FFFC = low byte
    ##   $FFFD = high byte
    #####################################################################

    proc reset(self):

        self.regs.a = 0x00
        self.regs.x = 0x00
        self.regs.y = 0x00

        self.regs.sp = 0xFD

        self.regs.pc = self.read16(0xFFFC)

        self.status.reset()

        self.halted = false

        self.cycles = 0

        self.irq_pending = false
        self.nmi_pending = false


    #####################################################################
    ## Execute one instruction
    #####################################################################

    proc step(self):

        if self.halted:
            return


        #################################################################
        ## Fetch opcode
        #################################################################

        let code = self.read8(self.regs.pc)

        self.regs.pc = (
            self.regs.pc + 1
        ) & 0xFFFF


        #################################################################
        ## Decode
        #################################################################

        let d = self.decode(code)

        let id = d[0]
        let mode = d[1]


        #################################################################
        ## Execute
        #################################################################

        let extra = self.exec(id, mode)


        #################################################################
        ## Cycle accounting
        #################################################################

        self.cycles = (
            self.cycles +
            _CYCLES[code] +
            extra
        )


        #################################################################
        ## Interrupts are serviced between instructions
        ##
        ## NMI has priority over IRQ.
        #################################################################

        if self.nmi_pending:

            self.nmi_pending = false

            self.serve_interrupt(0xFFFA)

        elif (
            self.irq_pending and
            self.status.I() == 0
        ):

            self.irq_pending = false

            self.serve_interrupt(0xFFFE)


    #####################################################################
    ## Run CPU
    ##
    ## max_instructions:
    ##
    ##   Number of instructions to execute.
    ##
    ## Example:
    ##
    ##   c.run(200)
    #####################################################################

    proc run(self, max_instructions):

        var n = 0

        while (
            self.halted == false and
            n < max_instructions
        ):

            self.step()

            n = n + 1


    #####################################################################
    ## Run with safety limit
    ##
    ## Useful for compatibility with the older run() behavior.
    #####################################################################

    proc run_forever(self):

        var n = 0

        while (
            self.halted == false and
            n < 1000000
        ):

            self.step()

            n = n + 1


    #####################################################################
    ## Legacy / software interrupt interface
    #####################################################################

    proc interrupt(self):

        self.irq_pending = true


    proc nmi(self):

        self.nmi_pending = true


    #####################################################################
    ## Serve IRQ / NMI
    ##
    ## Stack order:
    ##
    ##   PCH
    ##   PCL
    ##   P
    ##
    ## For IRQ/NMI:
    ##
    ##   bit 5 = 1
    ##   B     = 0
    #####################################################################

    proc serve_interrupt(self, vector):

        self.push16(self.regs.pc)

        self.push(
            self.status.to_push_byte(0)
        )

        self.status.set_I(1)

        self.regs.pc = self.read16(vector)

        self.cycles = self.cycles + 7


    #####################################################################
    ## Stack operations
    ##
    ## Stack range:
    ##
    ##   $0100-$01FF
    #####################################################################

    proc push(self, value):

        self.write8(
            0x0100 | self.regs.sp,
            value & 0xFF
        )

        self.regs.sp = (
            self.regs.sp - 1
        ) & 0xFF


    proc pull(self):

        self.regs.sp = (
            self.regs.sp + 1
        ) & 0xFF

        return self.read8(
            0x0100 | self.regs.sp
        )


    #####################################################################
    ## Push 16-bit value
    ##
    ## 6502 stack order:
    ##
    ##   high byte
    ##   low byte
    #####################################################################

    proc push16(self, value):

        self.push(
            (value >> 8) & 0xFF
        )

        self.push(
            value & 0xFF
        )


    #####################################################################
    ## Pull 16-bit value
    ##
    ## Stack order:
    ##
    ##   low byte
    ##   high byte
    #####################################################################

    proc pull16(self):

        let lo = self.pull()

        let hi = self.pull()

        return (
            (hi << 8) |
            lo
        )


    #####################################################################
    ## Effective address fetch
    ##
    ## Returns:
    ##
    ##   [effective_address, page_crossed]
    #####################################################################

    proc fetch(self, mode):


        #################################################################
        ## Zero page
        #################################################################

        if mode == M_ZP:

            let zp = self.read8(
                self.regs.pc
            )

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            self._fetch_scratch[0] = zp

            self._fetch_scratch[1] = 0

            return self._fetch_scratch


        #################################################################
        ## Zero page,X
        #################################################################

        if mode == M_ZPX:

            let zp = self.read8(
                self.regs.pc
            )

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            self._fetch_scratch[0] = (
                zp + self.regs.x
            ) & 0xFF

            self._fetch_scratch[1] = 0

            return self._fetch_scratch


        #################################################################
        ## Zero page,Y
        #################################################################

        if mode == M_ZPY:

            let zp = self.read8(
                self.regs.pc
            )

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            self._fetch_scratch[0] = (
                zp + self.regs.y
            ) & 0xFF

            self._fetch_scratch[1] = 0

            return self._fetch_scratch


        #################################################################
        ## Absolute
        #################################################################

        if mode == M_ABS:

            let lo = self.read8(
                self.regs.pc
            )

            let hi = self.read8(
                self.regs.pc + 1
            )

            self.regs.pc = (
                self.regs.pc + 2
            ) & 0xFFFF

            self._fetch_scratch[0] = (
                hi << 8
            ) | lo

            self._fetch_scratch[1] = 0

            return self._fetch_scratch


        #################################################################
        ## Absolute,X
        #################################################################

        if mode == M_ABSX:

            let lo = self.read8(
                self.regs.pc
            )

            let hi = self.read8(
                self.regs.pc + 1
            )

            self.regs.pc = (
                self.regs.pc + 2
            ) & 0xFFFF

            let base = (
                hi << 8
            ) | lo

            let eff = (
                base + self.regs.x
            ) & 0xFFFF

            self._fetch_scratch[0] = eff

            self._fetch_scratch[1] = (
                self._pcross(base, eff)
            )

            return self._fetch_scratch


        #################################################################
        ## Absolute,Y
        #################################################################

        if mode == M_ABSY:

            let lo = self.read8(
                self.regs.pc
            )

            let hi = self.read8(
                self.regs.pc + 1
            )

            self.regs.pc = (
                self.regs.pc + 2
            ) & 0xFFFF

            let base = (
                hi << 8
            ) | lo

            let eff = (
                base + self.regs.y
            ) & 0xFFFF

            self._fetch_scratch[0] = eff

            self._fetch_scratch[1] = (
                self._pcross(base, eff)
            )

            return self._fetch_scratch


        #################################################################
        ## (zero page,X)
        #################################################################

        if mode == M_INDX:

            let zp = self.read8(
                self.regs.pc
            )

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            let ptr = (
                zp + self.regs.x
            ) & 0xFF

            let lo = self.read8(ptr)

            let hi = self.read8(
                (ptr + 1) & 0xFF
            )

            self._fetch_scratch[0] = (
                hi << 8
            ) | lo

            self._fetch_scratch[1] = 0

            return self._fetch_scratch


        #################################################################
        ## (zero page),Y
        #################################################################

        if mode == M_INDY:

            let zp = self.read8(
                self.regs.pc
            )

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            let lo = self.read8(zp)

            let hi = self.read8(
                (zp + 1) & 0xFF
            )

            let base = (
                hi << 8
            ) | lo

            let eff = (
                base + self.regs.y
            ) & 0xFFFF

            self._fetch_scratch[0] = eff

            self._fetch_scratch[1] = (
                self._pcross(base, eff)
            )

            return self._fetch_scratch


        #################################################################
        ## Absolute indirect
        ##
        ## Real NMOS 6502 bug:
        ##
        ## JMP ($xxFF)
        ##
        ## reads the high byte from:
        ##
        ## $xx00
        ##
        ## rather than:
        ##
        ## $(xx + 1)00
        #################################################################

        if mode == M_IND:

            let lo = self.read8(
                self.regs.pc
            )

            let hi = self.read8(
                self.regs.pc + 1
            )

            self.regs.pc = (
                self.regs.pc + 2
            ) & 0xFFFF

            let ptr = (
                hi << 8
            ) | lo

            let target_lo = self.read8(ptr)

            let target_hi = self.read8(
                (ptr & 0xFF00) |
                ((ptr + 1) & 0xFF)
            )

            self._fetch_scratch[0] = (
                target_hi << 8
            ) | target_lo

            self._fetch_scratch[1] = 0

            return self._fetch_scratch


        #################################################################
        ## Default
        #################################################################

        self._fetch_scratch[0] = 0
        self._fetch_scratch[1] = 0

        return self._fetch_scratch


    #####################################################################
    ## Page-cross detection
    #####################################################################

    proc _pcross(self, base, eff):

        if (
            (base & 0xFF00) !=
            (eff & 0xFF00)
        ):

            return 1

        return 0


    #####################################################################
    ## Signed value from an 8-bit byte
    #####################################################################

    proc sbyte(self, b):

        b = b & 0xFF

        if b & 0x80:
            return b - 0x100

        return b


    #####################################################################
    ## Execute decoded instruction
    #####################################################################

    proc exec(self, id, mode):


        #################################################################
        ## Immediate
        #################################################################

        if mode == M_IMM:

            let operand = self.read8(
                self.regs.pc
            )

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            self.op1(id, operand)

            return 0


        #################################################################
        ## Accumulator
        #################################################################

        if mode == M_ACC:

            self.shift(
                id,
                self.regs.a,
                nil
            )

            return 0


        #################################################################
        ## Relative branch
        #################################################################

        if mode == M_REL:

            return self.branch(id)


        #################################################################
        ## Implied
        #################################################################

        if mode == M_IMP:

            self.op0(id)

            return 0


        #################################################################
        ## Memory-addressed modes
        #################################################################

        let fa = self.fetch(mode)

        let addr = fa[0]


        #################################################################
        ## Pure stores
        ##
        ## Do not perform a read first.
        ##
        ## Memory-mapped I/O may have read side effects.
        #################################################################

        if (
            id == 3 or
            id == 4 or
            id == 5
        ):

            self.op_with_addr(
                id,
                0,
                addr
            )

        else:

            let operand = self.read8(addr)

            self.op_with_addr(
                id,
                operand,
                addr
            )


        #################################################################
        ## Indexed page-cross penalty
        ##
        ## Applies to indexed READ operations.
        ##
        ## Stores and read-modify-write instructions already have their
        ## timing represented in the base cycle table.
        #################################################################

        if fa[1] == 1:

            if (
                id >= 0 and
                id <= 2
            ):

                return 1

            if (
                id >= 16 and
                id <= 20
            ):

                return 1

            if id == 22:
                return 1


        return 0


    #####################################################################
    ## Decode opcode
    #####################################################################

    proc decode(self, code):

        return _OPCODES[
            code & 0xFF
        ]


    ## Compatibility shim for external code that references cpu._table()
    proc _table(self):
        return _OPCODES


    #####################################################################
    ## Implied instructions
    #####################################################################

    proc op0(self, id):


        #################################################################
        ## TAX
        #################################################################

        if id == 6:

            self.regs.x = (
                self.regs.a
            ) & 0xFF

            self.status.upd_nz(
                self.regs.x
            )


        #################################################################
        ## TXA
        #################################################################

        elif id == 7:

            self.regs.a = (
                self.regs.x
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## TAY
        #################################################################

        elif id == 8:

            self.regs.y = (
                self.regs.a
            ) & 0xFF

            self.status.upd_nz(
                self.regs.y
            )


        #################################################################
        ## TYA
        #################################################################

        elif id == 9:

            self.regs.a = (
                self.regs.y
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## TSX
        #################################################################

        elif id == 10:

            self.regs.x = (
                self.regs.sp
            ) & 0xFF

            self.status.upd_nz(
                self.regs.x
            )


        #################################################################
        ## TXS
        #################################################################

        elif id == 11:

            self.regs.sp = (
                self.regs.x
            ) & 0xFF


        #################################################################
        ## PHA
        #################################################################

        elif id == 12:

            self.push(
                self.regs.a
            )


        #################################################################
        ## PHP
        ##
        ## Stack byte:
        ##
        ##   N V 1 1 D I Z C
        #################################################################

        elif id == 13:

            self.push(
                self.status.to_push_byte(1)
            )


        #################################################################
        ## PLA
        #################################################################

        elif id == 14:

            self.regs.a = (
                self.pull()
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## PLP
        #################################################################

        elif id == 15:

            self.status.from_byte(
                self.pull()
            )


        #################################################################
        ## INX
        #################################################################

        elif id == 27:

            self.regs.x = (
                self.regs.x + 1
            ) & 0xFF

            self.status.upd_nz(
                self.regs.x
            )


        #################################################################
        ## INY
        #################################################################

        elif id == 28:

            self.regs.y = (
                self.regs.y + 1
            ) & 0xFF

            self.status.upd_nz(
                self.regs.y
            )


        #################################################################
        ## DEX
        #################################################################

        elif id == 29:

            self.regs.x = (
                self.regs.x - 1
            ) & 0xFF

            self.status.upd_nz(
                self.regs.x
            )


        #################################################################
        ## DEY
        #################################################################

        elif id == 30:

            self.regs.y = (
                self.regs.y - 1
            ) & 0xFF

            self.status.upd_nz(
                self.regs.y
            )


        #################################################################
        ## RTS
        #################################################################

        elif id == 45:

            let ret = self.pull16()

            self.regs.pc = (
                ret + 1
            ) & 0xFFFF


        #################################################################
        ## BRK
        ##
        ## BRK is a two-byte instruction.
        ##
        ## The opcode fetch has already advanced PC by one.
        ## Advance once more to consume the padding byte before pushing.
        ##
        ## Stack status:
        ##
        ##   bit 5 = 1
        ##   B     = 1
        ##
        ## BRK does NOT halt the CPU.
        #################################################################

        elif id == 46:

            self.regs.pc = (
                self.regs.pc + 1
            ) & 0xFFFF

            self.push16(
                self.regs.pc
            )

            self.push(
                self.status.to_push_byte(1)
            )

            self.status.set_I(1)

            self.regs.pc = self.read16(
                0xFFFE
            )


        #################################################################
        ## RTI
        #################################################################

        elif id == 47:

            self.status.from_byte(
                self.pull()
            )

            self.regs.pc = self.pull16()


        #################################################################
        ## NOP
        #################################################################

        elif id == 48:

            pass


        #################################################################
        ## CLC
        #################################################################

        elif id == 49:

            self.status.set_C(0)


        #################################################################
        ## CLD
        #################################################################

        elif id == 50:

            self.status.set_D(0)


        #################################################################
        ## CLI
        #################################################################

        elif id == 51:

            self.status.set_I(0)


        #################################################################
        ## CLV
        #################################################################

        elif id == 52:

            self.status.set_V(0)


        #################################################################
        ## SEC
        #################################################################

        elif id == 53:

            self.status.set_C(1)


        #################################################################
        ## SED
        #################################################################

        elif id == 54:

            self.status.set_D(1)


        #################################################################
        ## SEI
        #################################################################

        elif id == 55:

            self.status.set_I(1)


    #####################################################################
    ## Immediate operations
    #####################################################################

    proc op1(self, id, operand):


        #################################################################
        ## LDA
        #################################################################

        if id == 0:

            self.regs.a = (
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## LDX
        #################################################################

        elif id == 1:

            self.regs.x = (
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.x
            )


        #################################################################
        ## LDY
        #################################################################

        elif id == 2:

            self.regs.y = (
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.y
            )


        #################################################################
        ## ADC
        #################################################################

        elif id == 16:

            self.adc(operand)


        #################################################################
        ## SBC
        #################################################################

        elif id == 17:

            self.sbc(operand)


        #################################################################
        ## AND
        #################################################################

        elif id == 18:

            self.regs.a = (
                self.regs.a &
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## ORA
        #################################################################

        elif id == 19:

            self.regs.a = (
                self.regs.a |
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## EOR
        #################################################################

        elif id == 20:

            self.regs.a = (
                self.regs.a ^
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## CMP
        #################################################################

        elif id == 22:

            self.compare(
                self.regs.a,
                operand
            )


        #################################################################
        ## CPX
        #################################################################

        elif id == 23:

            self.compare(
                self.regs.x,
                operand
            )


        #################################################################
        ## CPY
        #################################################################

        elif id == 24:

            self.compare(
                self.regs.y,
                operand
            )


    #####################################################################
    ## Memory-addressed operations
    #####################################################################

    proc op_with_addr(
        self,
        id,
        operand,
        addr
    ):


        #################################################################
        ## LDA
        #################################################################

        if id == 0:

            self.regs.a = (
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## LDX
        #################################################################

        elif id == 1:

            self.regs.x = (
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.x
            )


        #################################################################
        ## LDY
        #################################################################

        elif id == 2:

            self.regs.y = (
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.y
            )


        #################################################################
        ## STA
        #################################################################

        elif id == 3:

            self.write8(
                addr,
                self.regs.a
            )


        #################################################################
        ## STX
        #################################################################

        elif id == 4:

            self.write8(
                addr,
                self.regs.x
            )


        #################################################################
        ## STY
        #################################################################

        elif id == 5:

            self.write8(
                addr,
                self.regs.y
            )


        #################################################################
        ## ADC
        #################################################################

        elif id == 16:

            self.adc(operand)


        #################################################################
        ## SBC
        #################################################################

        elif id == 17:

            self.sbc(operand)


        #################################################################
        ## AND
        #################################################################

        elif id == 18:

            self.regs.a = (
                self.regs.a &
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## ORA
        #################################################################

        elif id == 19:

            self.regs.a = (
                self.regs.a |
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## EOR
        #################################################################

        elif id == 20:

            self.regs.a = (
                self.regs.a ^
                operand
            ) & 0xFF

            self.status.upd_nz(
                self.regs.a
            )


        #################################################################
        ## BIT
        ##
        ## Z = A & operand == 0
        ## N = operand bit 7
        ## V = operand bit 6
        #################################################################

        elif id == 21:

            let res = (
                self.regs.a &
                operand
            ) & 0xFF

            if res == 0:

                self.status.set_Z(1)

            else:

                self.status.set_Z(0)

            self.status.set_N(
                operand & 0x80
            )

            self.status.set_V(
                operand & 0x40
            )


        #################################################################
        ## CMP
        #################################################################

        elif id == 22:

            self.compare(
                self.regs.a,
                operand
            )


        #################################################################
        ## CPX
        #################################################################

        elif id == 23:

            self.compare(
                self.regs.x,
                operand
            )


        #################################################################
        ## CPY
        #################################################################

        elif id == 24:

            self.compare(
                self.regs.y,
                operand
            )


        #################################################################
        ## INC
        #################################################################

        elif id == 25:

            let nv = (
                operand + 1
            ) & 0xFF

            self.write8(
                addr,
                nv
            )

            self.status.upd_nz(nv)


        #################################################################
        ## DEC
        #################################################################

        elif id == 26:

            let nv = (
                operand - 1
            ) & 0xFF

            self.write8(
                addr,
                nv
            )

            self.status.upd_nz(nv)


        #################################################################
        ## Memory shifts
        #################################################################

        elif (
            id == 31 or
            id == 32 or
            id == 33 or
            id == 34
        ):

            self.shift(
                id,
                operand,
                addr
            )


        #################################################################
        ## JMP
        #################################################################

        elif id == 43:

            self.regs.pc = (
                addr
            ) & 0xFFFF


        #################################################################
        ## JSR
        ##
        ## Push address of final byte of JSR instruction.
        #################################################################

        elif id == 44:

            self.push16(
                (
                    self.regs.pc - 1
                ) & 0xFFFF
            )

            self.regs.pc = (
                addr
            ) & 0xFFFF


    #####################################################################
    ## ADC
    ##
    ## Selects:
    ##
    ##   Binary mode
    ##
    ## or:
    ##
    ##   NMOS decimal mode
    #####################################################################

    proc adc(self, operand):

        if self.status.D():

            self.adc_decimal_nmos(operand)

        else:

            self.adc_binary(operand)


    #####################################################################
    ## Binary ADC
    ##
    ## A + M + C
    #####################################################################

    proc adc_binary(self, operand):

        let a = self.regs.a & 0xFF

        let b = operand & 0xFF

        let c = self.status.C()

        let sum = a + b + c

        let result = sum & 0xFF


        #################################################################
        ## Carry
        #################################################################

        if sum > 0xFF:

            self.status.set_C(1)

        else:

            self.status.set_C(0)


        #################################################################
        ## Overflow
        ##
        ## Overflow when:
        ##
        ##   inputs have same sign
        ##
        ## and:
        ##
        ##   result has different sign
        #################################################################

        let overflow = (
            ~(a ^ b) &
            (a ^ result) &
            0x80
        )

        self.status.set_V(
            overflow
        )


        #################################################################
        ## N / Z
        #################################################################

        self.status.upd_nz(
            result
        )


        #################################################################
        ## Store result
        #################################################################

        self.regs.a = result


    #####################################################################
    ## NMOS Decimal ADC
    ##
    ## Performs:
    ##
    ##   A + operand + Carry
    ##
    ## using BCD correction.
    ##
    ## NMOS decimal flag behavior:
    ##
    ##   V = binary overflow
    ##   N = bit 7 of binary intermediate result
    ##   Z = binary intermediate result == 0
    ##   C = decimal carry
    ##
    ## This intentionally differs from CMOS 65C02 semantics.
    #####################################################################

    proc adc_decimal_nmos(self, operand):

        let a = self.regs.a & 0xFF

        let b = operand & 0xFF

        let c = self.status.C()


        #################################################################
        ## First perform binary addition.
        ##
        ## NMOS N/Z/V are derived from this binary result.
        #################################################################

        let binary_sum = a + b + c

        let binary_result = (
            binary_sum & 0xFF
        )


        #################################################################
        ## Binary overflow
        #################################################################

        let overflow = (
            ~(a ^ b) &
            (a ^ binary_result) &
            0x80
        )

        self.status.set_V(
            overflow
        )


        #################################################################
        ## NMOS N/Z behavior
        #################################################################

        self.status.upd_nz(
            binary_result
        )


        #################################################################
        ## Decimal correction
        #################################################################

        var decimal_sum = binary_sum


        #################################################################
        ## Low nibble correction
        #################################################################

        if (
            ((a & 0x0F) +
            (b & 0x0F) +
            c) > 9
        ):

            decimal_sum = (
                decimal_sum + 0x06
            )


        #################################################################
        ## High-digit correction
        #################################################################

        if decimal_sum > 0x99:

            decimal_sum = (
                decimal_sum + 0x60
            )


        #################################################################
        ## Decimal carry
        #################################################################

        if decimal_sum > 0xFF:

            self.status.set_C(1)

        else:

            self.status.set_C(0)


        #################################################################
        ## Store corrected BCD result
        #################################################################

        self.regs.a = (
            decimal_sum
        ) & 0xFF


    #####################################################################
    ## SBC
    ##
    ## Selects:
    ##
    ##   Binary mode
    ##
    ## or:
    ##
    ##   NMOS decimal mode
    #####################################################################

    proc sbc(self, operand):

        if self.status.D():

            self.sbc_decimal_nmos(operand)

        else:

            self.sbc_binary(operand)


    #####################################################################
    ## Binary SBC
    ##
    ## A - M - (1 - C)
    ##
    ## Carry semantics:
    ##
    ##   C = 1 -> no borrow
    ##   C = 0 -> borrow occurred
    #####################################################################

    proc sbc_binary(self, operand):

        let a = self.regs.a & 0xFF

        let b = operand & 0xFF

        let c = self.status.C()

        let borrow = 1 - c

        let diff = (
            a - b - borrow
        )

        let result = (
            diff & 0xFF
        )


        #################################################################
        ## Carry = no borrow
        #################################################################

        if diff >= 0:

            self.status.set_C(1)

        else:

            self.status.set_C(0)


        #################################################################
        ## Overflow
        ##
        ## Subtraction overflow when:
        ##
        ##   A and operand have different signs
        ##
        ## and:
        ##
        ##   result sign differs from A
        #################################################################

        let overflow = (
            (a ^ result) &
            (a ^ b) &
            0x80
        )

        self.status.set_V(
            overflow
        )


        #################################################################
        ## N / Z
        #################################################################

        self.status.upd_nz(
            result
        )


        #################################################################
        ## Store result
        #################################################################

        self.regs.a = result


    #####################################################################
    ## NMOS Decimal SBC
    ##
    ## Performs:
    ##
    ##   A - operand - (1 - Carry)
    ##
    ## using BCD correction.
    ##
    ## NMOS decimal behavior:
    ##
    ##   V = binary subtraction overflow
    ##   N = bit 7 of binary intermediate result
    ##   Z = binary intermediate result == 0
    ##   C = decimal no-borrow condition
    ##
    ## The decimal result is BCD-adjusted after binary flag generation.
    #####################################################################

    proc sbc_decimal_nmos(self, operand):

        let a = self.regs.a & 0xFF

        let b = operand & 0xFF

        let c = self.status.C()

        let borrow = 1 - c


        #################################################################
        ## Binary subtraction first.
        ##
        ## NMOS N/Z/V use this binary intermediate result.
        #################################################################

        let binary_diff = (
            a - b - borrow
        )

        let binary_result = (
            binary_diff & 0xFF
        )


        #################################################################
        ## Binary overflow
        #################################################################

        let overflow = (
            (a ^ binary_result) &
            (a ^ b) &
            0x80
        )

        self.status.set_V(
            overflow
        )


        #################################################################
        ## NMOS N/Z behavior
        #################################################################

        self.status.upd_nz(
            binary_result
        )


        #################################################################
        ## Decimal subtraction
        ##
        ## Perform correction nibble by nibble.
        #################################################################

        var low = (
            (a & 0x0F) -
            (b & 0x0F) -
            borrow
        )

        var high = (
            ((a >> 4) & 0x0F) -
            ((b >> 4) & 0x0F)
        )


        #################################################################
        ## Borrow from high BCD digit
        #################################################################

        if low < 0:

            low = low + 10

            high = high - 1


        #################################################################
        ## Final decimal borrow / carry
        #################################################################

        if high < 0:

            high = high + 10

            self.status.set_C(0)

        else:

            self.status.set_C(1)


        #################################################################
        ## Rebuild BCD result
        #################################################################

        self.regs.a = (
            (
                (high << 4) |
                low
            ) & 0xFF
        )


    #####################################################################
    ## Compare
    ##
    ## Performs:
    ##
    ##   reg - operand
    ##
    ## Flags:
    ##
    ##   N/Z from subtraction result
    ##   C set if reg >= operand
    #####################################################################

    proc compare(self, reg_, operand):

        let a = reg_ & 0xFF

        let b = operand & 0xFF

        let r = (
            a - b
        ) & 0xFF

        self.status.upd_nz(r)


        if a >= b:

            self.status.set_C(1)

        else:

            self.status.set_C(0)


    #####################################################################
    ## Shifts / rotates
    ##
    ## addr == nil:
    ##
    ##   Operate on accumulator A.
    ##
    ## addr != nil:
    ##
    ##   Operate on memory.
    #####################################################################

    proc shift(
        self,
        id,
        operand,
        addr
    ):

        let value = (
            operand
        ) & 0xFF

        var result = 0


        #################################################################
        ## ASL
        #################################################################

        if id == 31:

            result = (
                value << 1
            ) & 0xFF

            self.status.set_C(
                value & 0x80
            )


        #################################################################
        ## LSR
        #################################################################

        elif id == 32:

            result = (
                value >> 1
            ) & 0xFF

            self.status.set_C(
                value & 0x01
            )


        #################################################################
        ## ROL
        #################################################################

        elif id == 33:

            let c = self.status.C()

            result = (
                (
                    value << 1
                ) & 0xFF
            ) | c

            self.status.set_C(
                value & 0x80
            )


        #################################################################
        ## ROR
        #################################################################

        elif id == 34:

            let c = self.status.C()

            result = (
                (
                    value >> 1
                ) & 0xFF
            ) | (
                c << 7
            )

            self.status.set_C(
                value & 0x01
            )


        #################################################################
        ## Update N / Z
        #################################################################

        self.status.upd_nz(
            result
        )


        #################################################################
        ## Write result
        #################################################################

        if addr == nil:

            self.regs.a = (
                result
            ) & 0xFF

        else:

            self.write8(
                addr,
                result & 0xFF
            )


    #####################################################################
    ## Relative branches
    ##
    ## Returns extra cycles:
    ##
    ##   0 = branch not taken
    ##   1 = branch taken
    ##   2 = branch taken and page crossed
    #####################################################################

    proc branch(self, id):


        #################################################################
        ## Fetch signed 8-bit offset
        #################################################################

        let off = self.sbyte(
            self.read8(
                self.regs.pc
            )
        )

        self.regs.pc = (
            self.regs.pc + 1
        ) & 0xFFFF


        #################################################################
        ## Determine whether branch is taken
        #################################################################

        var take = false


        #################################################################
        ## BCC
        #################################################################

        if id == 35:

            if self.status.C() == 0:
                take = true


        #################################################################
        ## BCS
        #################################################################

        elif id == 36:

            if self.status.C() == 1:
                take = true


        #################################################################
        ## BEQ
        #################################################################

        elif id == 37:

            if self.status.Z() == 1:
                take = true


        #################################################################
        ## BMI
        #################################################################

        elif id == 38:

            if self.status.N() == 1:
                take = true


        #################################################################
        ## BNE
        #################################################################

        elif id == 39:

            if self.status.Z() == 0:
                take = true


        #################################################################
        ## BPL
        #################################################################

        elif id == 40:

            if self.status.N() == 0:
                take = true


        #################################################################
        ## BVC
        #################################################################

        elif id == 41:

            if self.status.V() == 0:
                take = true


        #################################################################
        ## BVS
        #################################################################

        elif id == 42:

            if self.status.V() == 1:
                take = true


        #################################################################
        ## Execute branch
        #################################################################

        if take:

            let srcpage = (
                self.regs.pc & 0xFF00
            )

            self.regs.pc = (
                self.regs.pc + off
            ) & 0xFFFF


            #################################################################
            ## Page-cross penalty
            #################################################################

            if (
                (self.regs.pc & 0xFF00) !=
                srcpage
            ):

                return 2


            return 1


        return 0


#############################################################################
## Module-level compatibility shim for code that references cpu._table()
#############################################################################

proc _table():
    return _OPCODES
