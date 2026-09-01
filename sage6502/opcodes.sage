#########################################################################
## Sage6502 - Canonical NMOS 6502 Opcode Table
##
## _OPCODES[opcode_value] = [instruction_id, addressing_mode]
##
## Indexed by opcode byte value (0x00-0xFF)
## Unused opcodes default to [0, M_IMP] (NOP-like)
#########################################################################

import sage6502.constants

proc _build_opcodes():

    let t = []

    var i = 0
    while i < 256:
        push(t, [0, M_IMP])
        i = i + 1

    ## LDA
    t[0xA9] = [LDA,  M_IMM]
    t[0xA5] = [LDA,  M_ZP]
    t[0xB5] = [LDA,  M_ZPX]
    t[0xAD] = [LDA,  M_ABS]
    t[0xBD] = [LDA,  M_ABSX]
    t[0xB9] = [LDA,  M_ABSY]
    t[0xA1] = [LDA,  M_INDX]
    t[0xB1] = [LDA,  M_INDY]

    ## LDX
    t[0xA2] = [LDX,  M_IMM]
    t[0xA6] = [LDX,  M_ZP]
    t[0xB6] = [LDX,  M_ZPY]
    t[0xAE] = [LDX,  M_ABS]
    t[0xBE] = [LDX,  M_ABSY]

    ## LDY
    t[0xA0] = [LDY,  M_IMM]
    t[0xA4] = [LDY,  M_ZP]
    t[0xB4] = [LDY,  M_ZPX]
    t[0xAC] = [LDY,  M_ABS]
    t[0xBC] = [LDY,  M_ABSX]

    ## STA
    t[0x85] = [STA,  M_ZP]
    t[0x95] = [STA,  M_ZPX]
    t[0x8D] = [STA,  M_ABS]
    t[0x9D] = [STA,  M_ABSX]
    t[0x99] = [STA,  M_ABSY]
    t[0x81] = [STA,  M_INDX]
    t[0x91] = [STA,  M_INDY]

    ## STX
    t[0x86] = [STX,  M_ZP]
    t[0x96] = [STX,  M_ZPY]
    t[0x8E] = [STX,  M_ABS]

    ## STY
    t[0x84] = [STY,  M_ZP]
    t[0x94] = [STY,  M_ZPX]
    t[0x8C] = [STY,  M_ABS]

    ## Transfers
    t[0xAA] = [TAX,  M_IMP]
    t[0x8A] = [TXA,  M_IMP]
    t[0xA8] = [TAY,  M_IMP]
    t[0x98] = [TYA,  M_IMP]
    t[0xBA] = [TSX,  M_IMP]
    t[0x9A] = [TXS,  M_IMP]

    ## Stack
    t[0x48] = [PHA,  M_IMP]
    t[0x08] = [PHP,  M_IMP]
    t[0x68] = [PLA,  M_IMP]
    t[0x28] = [PLP,  M_IMP]

    ## ADC
    t[0x69] = [ADC,  M_IMM]
    t[0x65] = [ADC,  M_ZP]
    t[0x75] = [ADC,  M_ZPX]
    t[0x6D] = [ADC,  M_ABS]
    t[0x7D] = [ADC,  M_ABSX]
    t[0x79] = [ADC,  M_ABSY]
    t[0x61] = [ADC,  M_INDX]
    t[0x71] = [ADC,  M_INDY]

    ## SBC
    t[0xE9] = [SBC,  M_IMM]
    t[0xE5] = [SBC,  M_ZP]
    t[0xF5] = [SBC,  M_ZPX]
    t[0xED] = [SBC,  M_ABS]
    t[0xFD] = [SBC,  M_ABSX]
    t[0xF9] = [SBC,  M_ABSY]
    t[0xE1] = [SBC,  M_INDX]
    t[0xF1] = [SBC,  M_INDY]

    ## AND
    t[0x29] = [AND,  M_IMM]
    t[0x25] = [AND,  M_ZP]
    t[0x35] = [AND,  M_ZPX]
    t[0x2D] = [AND,  M_ABS]
    t[0x3D] = [AND,  M_ABSX]
    t[0x39] = [AND,  M_ABSY]
    t[0x21] = [AND,  M_INDX]
    t[0x31] = [AND,  M_INDY]

    ## ORA
    t[0x09] = [ORA,  M_IMM]
    t[0x05] = [ORA,  M_ZP]
    t[0x15] = [ORA,  M_ZPX]
    t[0x0D] = [ORA,  M_ABS]
    t[0x1D] = [ORA,  M_ABSX]
    t[0x19] = [ORA,  M_ABSY]
    t[0x01] = [ORA,  M_INDX]
    t[0x11] = [ORA,  M_INDY]

    ## EOR
    t[0x49] = [EOR,  M_IMM]
    t[0x45] = [EOR,  M_ZP]
    t[0x55] = [EOR,  M_ZPX]
    t[0x4D] = [EOR,  M_ABS]
    t[0x5D] = [EOR,  M_ABSX]
    t[0x59] = [EOR,  M_ABSY]
    t[0x41] = [EOR,  M_INDX]
    t[0x51] = [EOR,  M_INDY]

    ## BIT
    t[0x24] = [BIT,  M_ZP]
    t[0x2C] = [BIT,  M_ABS]

    ## CMP
    t[0xC9] = [CMP,  M_IMM]
    t[0xC5] = [CMP,  M_ZP]
    t[0xD5] = [CMP,  M_ZPX]
    t[0xCD] = [CMP,  M_ABS]
    t[0xDD] = [CMP,  M_ABSX]
    t[0xD9] = [CMP,  M_ABSY]
    t[0xC1] = [CMP,  M_INDX]
    t[0xD1] = [CMP,  M_INDY]

    ## CPX
    t[0xE0] = [CPX,  M_IMM]
    t[0xE4] = [CPX,  M_ZP]
    t[0xEC] = [CPX,  M_ABS]

    ## CPY
    t[0xC0] = [CPY,  M_IMM]
    t[0xC4] = [CPY,  M_ZP]
    t[0xCC] = [CPY,  M_ABS]

    ## INC
    t[0xE6] = [INC,  M_ZP]
    t[0xF6] = [INC,  M_ZPX]
    t[0xEE] = [INC,  M_ABS]
    t[0xFE] = [INC,  M_ABSX]

    ## DEC
    t[0xC6] = [DEC,  M_ZP]
    t[0xD6] = [DEC,  M_ZPX]
    t[0xCE] = [DEC,  M_ABS]
    t[0xDE] = [DEC,  M_ABSX]

    ## Increment / decrement registers
    t[0xE8] = [INX,  M_IMP]
    t[0xC8] = [INY,  M_IMP]
    t[0xCA] = [DEX,  M_IMP]
    t[0x88] = [DEY,  M_IMP]

    ## ASL
    t[0x0A] = [ASL,  M_ACC]
    t[0x06] = [ASL,  M_ZP]
    t[0x16] = [ASL,  M_ZPX]
    t[0x0E] = [ASL,  M_ABS]
    t[0x1E] = [ASL,  M_ABSX]

    ## LSR
    t[0x4A] = [LSR,  M_ACC]
    t[0x46] = [LSR,  M_ZP]
    t[0x56] = [LSR,  M_ZPX]
    t[0x4E] = [LSR,  M_ABS]
    t[0x5E] = [LSR,  M_ABSX]

    ## ROL
    t[0x2A] = [ROL,  M_ACC]
    t[0x26] = [ROL,  M_ZP]
    t[0x36] = [ROL,  M_ZPX]
    t[0x2E] = [ROL,  M_ABS]
    t[0x3E] = [ROL,  M_ABSX]

    ## ROR
    t[0x6A] = [ROR,  M_ACC]
    t[0x66] = [ROR,  M_ZP]
    t[0x76] = [ROR,  M_ZPX]
    t[0x6E] = [ROR,  M_ABS]
    t[0x7E] = [ROR,  M_ABSX]

    ## Branches
    t[0x90] = [BCC,  M_REL]
    t[0xB0] = [BCS,  M_REL]
    t[0xF0] = [BEQ,  M_REL]
    t[0x30] = [BMI,  M_REL]
    t[0xD0] = [BNE,  M_REL]
    t[0x10] = [BPL,  M_REL]
    t[0x50] = [BVC,  M_REL]
    t[0x70] = [BVS,  M_REL]

    ## Jumps / subroutines
    t[0x4C] = [JMP,  M_ABS]
    t[0x6C] = [JMP,  M_IND]
    t[0x20] = [JSR,  M_ABS]
    t[0x60] = [RTS,  M_IMP]

    ## System
    t[0x00] = [BRK,  M_IMP]
    t[0x40] = [RTI,  M_IMP]
    t[0xEA] = [NOP,  M_IMP]

    ## Flags
    t[0x18] = [CLC,  M_IMP]
    t[0xD8] = [CLD,  M_IMP]
    t[0x58] = [CLI,  M_IMP]
    t[0xB8] = [CLV,  M_IMP]
    t[0x38] = [SEC,  M_IMP]
    t[0xF8] = [SED,  M_IMP]
    t[0x78] = [SEI,  M_IMP]

    return t


let _OPCODES = _build_opcodes()

proc get_opcodes():
    return _OPCODES
