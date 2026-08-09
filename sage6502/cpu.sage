#########################################################################
## SageApple — Sage6502 CPU core (SageLang)
##
## A table-driven 6502 (NMOS) emulator. Address space goes through a Bus
## object so the same core runs on the host and later on AVR.
##
##   import sage6502.registers
##   import sage6502.flags
##   import cpu
##   let c = cpu.CPU(b)
##   c.reset()
##   c.run(200)
#########################################################################

import sage6502.registers
import sage6502.flags
import dicts

# addressing-mode constants
#   0 imm, 1 zp, 2 zpx, 3 zpy, 4 abs, 5 absx, 6 absy,
#   7 (zp,X), 8 (zp),Y, 9 acc, 10 (abs) indirect, 11 rel, 12 impl
let M_IMM = 0
let M_ZP  = 1
let M_ZPX = 2
let M_ZPY = 3
let M_ABS = 4
let M_ABSX = 5
let M_ABSY = 6
let M_INDX = 7
let M_INDY = 8
let M_ACC = 9
let M_IND = 10
let M_REL = 11
let M_IMP = 12

# canonical NMOS 6502 opcode table: opcode -> (instruction_id, mode)
proc _table():
    let t = []
    var i = 0
    while i < 256:
        push(t, [0, M_IMP])
        i = i + 1
    # LDA
    t[0xA9] = [0, M_IMM]
    t[0xA5] = [0, M_ZP]
    t[0xB5] = [0, M_ZPX]
    t[0xAD] = [0, M_ABS]
    t[0xBD] = [0, M_ABSX]
    t[0xB9] = [0, M_ABSY]
    t[0xA1] = [0, M_INDX]
    t[0xB1] = [0, M_INDY]
    # LDX
    t[0xA2] = [1, M_IMM]
    t[0xA6] = [1, M_ZP]
    t[0xB6] = [1, M_ZPY]
    t[0xAE] = [1, M_ABS]
    t[0xBE] = [1, M_ABSY]
    # LDY
    t[0xA0] = [2, M_IMM]
    t[0xA4] = [2, M_ZP]
    t[0xB4] = [2, M_ZPX]
    t[0xAC] = [2, M_ABS]
    t[0xBC] = [2, M_ABSX]
    # STA
    t[0x85] = [3, M_ZP]
    t[0x95] = [3, M_ZPX]
    t[0x8D] = [3, M_ABS]
    t[0x9D] = [3, M_ABSX]
    t[0x99] = [3, M_ABSY]
    t[0x81] = [3, M_INDX]
    t[0x91] = [3, M_INDY]
    # STX
    t[0x86] = [4, M_ZP]
    t[0x96] = [4, M_ZPY]
    t[0x8E] = [4, M_ABS]
    # STY
    t[0x84] = [5, M_ZP]
    t[0x94] = [5, M_ZPX]
    t[0x8C] = [5, M_ABS]
    # transfers
    t[0xAA] = [6, M_IMP]
    t[0x8A] = [7, M_IMP]
    t[0xA8] = [8, M_IMP]
    t[0x98] = [9, M_IMP]
    t[0xBA] = [10, M_IMP]
    t[0x9A] = [11, M_IMP]
    # stack
    t[0x48] = [12, M_IMP]
    t[0x08] = [13, M_IMP]
    t[0x68] = [14, M_IMP]
    t[0x28] = [15, M_IMP]
    # ADC
    t[0x69] = [16, M_IMM]
    t[0x65] = [16, M_ZP]
    t[0x75] = [16, M_ZPX]
    t[0x6D] = [16, M_ABS]
    t[0x7D] = [16, M_ABSX]
    t[0x79] = [16, M_ABSY]
    t[0x61] = [16, M_INDX]
    t[0x71] = [16, M_INDY]
    # SBC
    t[0xE9] = [17, M_IMM]
    t[0xE5] = [17, M_ZP]
    t[0xF5] = [17, M_ZPX]
    t[0xED] = [17, M_ABS]
    t[0xFD] = [17, M_ABSX]
    t[0xF9] = [17, M_ABSY]
    t[0xE1] = [17, M_INDX]
    t[0xF1] = [17, M_INDY]
    # AND
    t[0x29] = [18, M_IMM]
    t[0x25] = [18, M_ZP]
    t[0x35] = [18, M_ZPX]
    t[0x2D] = [18, M_ABS]
    t[0x3D] = [18, M_ABSX]
    t[0x39] = [18, M_ABSY]
    t[0x21] = [18, M_INDX]
    t[0x31] = [18, M_INDY]
    # ORA
    t[0x09] = [19, M_IMM]
    t[0x05] = [19, M_ZP]
    t[0x15] = [19, M_ZPX]
    t[0x0D] = [19, M_ABS]
    t[0x1D] = [19, M_ABSX]
    t[0x19] = [19, M_ABSY]
    t[0x01] = [19, M_INDX]
    t[0x11] = [19, M_INDY]
    # EOR
    t[0x49] = [20, M_IMM]
    t[0x45] = [20, M_ZP]
    t[0x55] = [20, M_ZPX]
    t[0x4D] = [20, M_ABS]
    t[0x5D] = [20, M_ABSX]
    t[0x59] = [20, M_ABSY]
    t[0x41] = [20, M_INDX]
    t[0x51] = [20, M_INDY]
    # BIT
    t[0x24] = [21, M_ZP]
    t[0x2C] = [21, M_ABS]
    # CMP
    t[0xC9] = [22, M_IMM]
    t[0xC5] = [22, M_ZP]
    t[0xD5] = [22, M_ZPX]
    t[0xCD] = [22, M_ABS]
    t[0xDD] = [22, M_ABSX]
    t[0xD9] = [22, M_ABSY]
    t[0xC1] = [22, M_INDX]
    t[0xD1] = [22, M_INDY]
    # CPX
    t[0xE0] = [23, M_IMM]
    t[0xE4] = [23, M_ZP]
    t[0xEC] = [23, M_ABS]
    # CPY
    t[0xC0] = [24, M_IMM]
    t[0xC4] = [24, M_ZP]
    t[0xCC] = [24, M_ABS]
    # INC / DEC
    t[0xE6] = [25, M_ZP]
    t[0xF6] = [25, M_ZPX]
    t[0xEE] = [25, M_ABS]
    t[0xFE] = [25, M_ABSX]
    t[0xC6] = [26, M_ZP]
    t[0xD6] = [26, M_ZPX]
    t[0xCE] = [26, M_ABS]
    t[0xDE] = [26, M_ABSX]
    # IN / DE registers
    t[0xE8] = [27, M_IMP]
    t[0xCA] = [29, M_IMP]
    t[0xC8] = [28, M_IMP]
    t[0x88] = [30, M_IMP]
    # ASL / LSR / ROL / ROR
    t[0x0A] = [31, M_ACC]
    t[0x06] = [31, M_ZP]
    t[0x16] = [31, M_ZPX]
    t[0x0E] = [31, M_ABS]
    t[0x1E] = [31, M_ABSX]
    t[0x4A] = [32, M_ACC]
    t[0x46] = [32, M_ZP]
    t[0x56] = [32, M_ZPX]
    t[0x4E] = [32, M_ABS]
    t[0x5E] = [32, M_ABSX]
    t[0x2A] = [33, M_ACC]
    t[0x26] = [33, M_ZP]
    t[0x36] = [33, M_ZPX]
    t[0x2E] = [33, M_ABS]
    t[0x3E] = [33, M_ABSX]
    t[0x6A] = [34, M_ACC]
    t[0x66] = [34, M_ZP]
    t[0x76] = [34, M_ZPX]
    t[0x6E] = [34, M_ABS]
    t[0x7E] = [34, M_ABSX]
    # branches
    t[0x90] = [35, M_REL]
    t[0xB0] = [36, M_REL]
    t[0xF0] = [37, M_REL]
    t[0x30] = [38, M_REL]
    t[0xD0] = [39, M_REL]
    t[0x10] = [40, M_REL]
    t[0x50] = [41, M_REL]
    t[0x70] = [42, M_REL]
    # jumps
    t[0x4C] = [43, M_ABS]
    t[0x6C] = [43, M_IND]
    t[0x20] = [44, M_ABS]
    t[0x60] = [45, M_IMP]
    # system
    t[0x00] = [46, M_IMP]
    t[0x40] = [47, M_IMP]
    t[0xEA] = [48, M_IMP]
    # flags
    t[0x18] = [49, M_IMP]
    t[0xD8] = [50, M_IMP]
    t[0x58] = [51, M_IMP]
    t[0xB8] = [52, M_IMP]
    t[0x38] = [53, M_IMP]
    t[0xF8] = [54, M_IMP]
    t[0x78] = [55, M_IMP]
    return t

var _OPCODES = _table()

## canonical NMOS 6502 base cycle counts (256 entries)
proc _load_cycles():
    let raw = "7,6,0,0,0,3,5,0,3,2,2,0,0,4,6,0,2,5,0,0,0,4,6,0,2,4,0,0,0,4,7,0,6,6,0,0,3,3,5,0,4,2,2,0,4,4,6,0,2,5,0,0,0,4,6,0,2,4,0,0,0,4,7,0,6,6,0,0,0,3,5,0,3,2,2,0,3,4,6,0,2,5,0,0,0,4,6,0,2,4,0,0,0,4,7,0,6,6,0,0,0,3,5,0,4,2,2,0,5,4,6,0,2,5,0,0,0,4,6,0,2,4,0,0,0,4,7,0,0,6,0,0,3,3,3,0,2,0,2,0,4,4,4,0,2,6,0,0,4,4,4,0,2,5,2,0,0,5,0,0,2,6,2,0,3,3,3,0,2,2,2,0,4,4,4,0,2,5,0,0,4,4,4,0,2,4,2,0,4,4,4,0,2,6,0,0,3,3,5,0,2,2,2,0,4,4,6,0,2,5,0,0,0,4,6,0,2,4,0,0,0,4,7,0,2,6,0,0,3,3,5,0,2,2,2,0,4,4,6,0,2,5,0,0,0,4,6,0,2,4,0,0,0,4,7,0"
    let parts = split(raw, ",")
    let t = []
    var i = 0
    while i < 256:
        push(t, _atoi(parts[i]))
        i = i + 1
    return t

proc _atoi(s):
    var v = 0
    for i in range(len(s)):
        let ch = s[i]
        if ch >= "0" and ch <= "9":
            v = v * 10 + (ord(ch) - 48)
    return v

var _CYCLES = _load_cycles()

class CPU:
    proc init(self, bus):
        self.bus = bus
        self.regs = registers.Registers()
        self.status = flags.Status()
        self.halted = false
        self.cycles = 0
        self.irq_pending = false
        self.nmi_pending = false

    proc read8(self, addr):
        return self.bus.read8(addr)

    proc write8(self, addr, value):
        self.bus.write8(addr, value)

    proc read16(self, addr):
        return self.bus.read16(addr)

    proc reset(self):
        self.regs.sp = 0xFD
        self.regs.pc = self.read16(0xFFFC)
        self.status.set(0x00)
        self.status.set_B(1)
        self.status.set_I(1)
        self.regs.a = 0
        self.regs.x = 0
        self.regs.y = 0
        self.halted = false

    proc step(self):
        if self.halted:
            return
        let code = self.read8(self.regs.pc)
        self.regs.pc = (self.regs.pc + 1) & 0xFFFF
        let d = self.decode(code)
        let extra = self.exec(d[0], d[1])
        self.cycles = self.cycles + _CYCLES[code] + extra
        # service interrupts between instructions
        if self.nmi_pending:
            self.nmi_pending = false
            self.serve_interrupt(0xFFFA)
        elif self.irq_pending and self.status.I() == 0:
            self.irq_pending = false
            self.serve_interrupt(0xFFFE)

    proc run(self):
        var n = 0
        while self.halted == false and n < 1000000:
            self.step()
            n = n + 1

    # ---- legacy/soft interrupt interface (plan API) ----
    proc interrupt(self):
        self.irq_pending = true

    proc nmi(self):
        self.nmi_pending = true

    proc serve_interrupt(self, vector):
        self.push16(self.regs.pc)
        self.push(self.status.get() | 0x30)
        self.status.set_I(1)
        self.regs.pc = self.read16(vector)
        self.cycles = self.cycles + 7

    proc push(self, value):
        self.write8(0x0100 | self.regs.sp, value & 0xFF)
        self.regs.sp = (self.regs.sp - 1) & 0xFF

    proc pull(self):
        self.regs.sp = (self.regs.sp + 1) & 0xFF
        return self.read8(0x0100 | self.regs.sp)

    proc push16(self, value):
        self.push((value >> 8) & 0xFF)
        self.push(value & 0xFF)

    proc pull16(self):
        let lo = self.pull()
        let hi = self.pull()
        return (hi << 8) | lo

    # effective address for non-immediate memory modes; returns
    # [addr, page_crossed] so indexed modes can charge the extra cycle
    proc fetch(self, mode):
        if mode == 1:
            let zp = self.read8(self.regs.pc)
            self.regs.pc = (self.regs.pc + 1) & 0xFFFF
            return [zp, 0]
        if mode == 2:
            let zp = self.read8(self.regs.pc)
            self.regs.pc = (self.regs.pc + 1) & 0xFFFF
            return [(zp + self.regs.x) & 0xFF, 0]
        if mode == 3:
            let zp = self.read8(self.regs.pc)
            self.regs.pc = (self.regs.pc + 1) & 0xFFFF
            return [(zp + self.regs.y) & 0xFF, 0]
        if mode == 4:
            let lo = self.read8(self.regs.pc)
            let hi = self.read8(self.regs.pc + 1)
            self.regs.pc = (self.regs.pc + 2) & 0xFFFF
            return [(hi << 8) | lo, 0]
        if mode == 5:
            let lo = self.read8(self.regs.pc)
            let hi = self.read8(self.regs.pc + 1)
            self.regs.pc = (self.regs.pc + 2) & 0xFFFF
            let base = (hi << 8) | lo
            let eff = (base + self.regs.x) & 0xFFFF
            return [eff, self._pcross(base, eff)]
        if mode == 6:
            let lo = self.read8(self.regs.pc)
            let hi = self.read8(self.regs.pc + 1)
            self.regs.pc = (self.regs.pc + 2) & 0xFFFF
            let base = (hi << 8) | lo
            let eff = (base + self.regs.y) & 0xFFFF
            return [eff, self._pcross(base, eff)]
        if mode == 7:
            let zp = self.read8(self.regs.pc)
            self.regs.pc = (self.regs.pc + 1) & 0xFFFF
            let ptr = (zp + self.regs.x) & 0xFF
            let lo = self.read8(ptr)
            let hi = self.read8((ptr + 1) & 0xFF)
            return [(hi << 8) | lo, 0]
        if mode == 8:
            let zp = self.read8(self.regs.pc)
            self.regs.pc = (self.regs.pc + 1) & 0xFFFF
            let lo = self.read8(zp)
            let hi = self.read8((zp + 1) & 0xFF)
            let base = (hi << 8) | lo
            let eff = (base + self.regs.y) & 0xFFFF
            return [eff, self._pcross(base, eff)]
        if mode == 10:
            let lo = self.read8(self.regs.pc)
            let hi = self.read8(self.regs.pc + 1)
            self.regs.pc = (self.regs.pc + 2) & 0xFFFF
            # real 6502 bug: JMP ($xxFF) reads the high byte back on the
            # same page ($xx00), not from the next page
            let ptr = (hi << 8) | lo
            return [self.read8(ptr) | (self.read8((ptr & 0xFF00) | ((ptr + 1) & 0xFF)) << 8), 0]
        return [0, 0]

    # page boundary crossed by an indexed effective address?
    proc _pcross(self, base, eff):
        if (base & 0xFF00) != (eff & 0xFF00):
            return 1
        return 0

    # signed value from an 8-bit byte
    proc sbyte(self, b):
        b = b & 0xFF
        if b & 0x80:
            return b - 0x100
        return b

    proc exec(self, id, mode):
        # immediate operand
        if mode == 0:
            let operand = self.read8(self.regs.pc)
            self.regs.pc = (self.regs.pc + 1) & 0xFFFF
            self.op1(id, operand)
            return 0
        # accumulator shifts operate on register A
        if mode == 9:
            self.shift(id, self.regs.a, nil)
            return 0
        # branch
        if mode == 11:
            return self.branch(id)
        # implied: nothing to fetch
        if mode == 12:
            self.op0(id)
            return 0
        # memory modes
        let fa = self.fetch(mode)
        let addr = fa[0]
        if id == 3 or id == 4 or id == 5:
            # pure stores: write without a dummy read (input ports have side effects)
            self.op_with_addr(id, 0, addr)
        else:
            let operand = self.read8(addr)
            self.op_with_addr(id, operand, addr)
        # page-cross penalty: NMOS 6502 charges +1 for indexed reads that
        # cross a page (loads/arith/compare/logical in abs,X abs,Y (zp),Y);
        # stores and read-modify-writes already include it in their base
        if fa[1] == 1:
            if id == 0 or id == 1 or id == 2:
                return 1
            if id >= 16 and id <= 20:
                return 1
            if id == 22:
                return 1
        return 0

    proc decode(self, code):
        return _OPCODES[code]

    # ------------------------------------------------------------------
    # implied mode
    # ------------------------------------------------------------------
    proc op0(self, id):
        if id == 6:            # TAX
            self.regs.x = self.regs.a & 0xFF
            self.status.upd_nz(self.regs.x)
        elif id == 7:          # TXA
            self.regs.a = self.regs.x & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 8:          # TAY
            self.regs.y = self.regs.a & 0xFF
            self.status.upd_nz(self.regs.y)
        elif id == 9:          # TYA
            self.regs.a = self.regs.y & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 10:         # TSX
            self.regs.x = self.regs.sp & 0xFF
            self.status.upd_nz(self.regs.x)
        elif id == 11:         # TXS
            self.regs.sp = self.regs.x & 0xFF
        elif id == 12:         # PHA
            self.push(self.regs.a)
        elif id == 13:         # PHP
            self.push(self.status.get() | 0x30)
        elif id == 14:         # PLA
            self.regs.a = self.pull() & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 15:         # PLP
            self.status.set(self.pull())
        elif id == 27:         # INX
            self.regs.x = (self.regs.x + 1) & 0xFF
            self.status.upd_nz(self.regs.x)
        elif id == 28:         # INY
            self.regs.y = (self.regs.y + 1) & 0xFF
            self.status.upd_nz(self.regs.y)
        elif id == 29:         # DEX
            self.regs.x = (self.regs.x - 1) & 0xFF
            self.status.upd_nz(self.regs.x)
        elif id == 30:         # DEY
            self.regs.y = (self.regs.y - 1) & 0xFF
            self.status.upd_nz(self.regs.y)
        elif id == 45:         # RTS
            let ret = self.pull16()
            self.regs.pc = (ret + 1) & 0xFFFF
        elif id == 46:         # BRK
            self.push16(self.regs.pc)
            self.push(self.status.get() | 0x30)
            self.status.set_I(1)
            self.regs.pc = self.read16(0xFFFE)
            self.halted = true
        elif id == 47:         # RTI
            self.status.set(self.pull())
            self.regs.pc = self.pull16()
        elif id == 49:         # CLC
            self.status.set_C(0)
        elif id == 50:         # CLD
            self.status.set_D(0)
        elif id == 51:         # CLI
            self.status.set_I(0)
        elif id == 52:         # CLV
            self.status.set_V(0)
        elif id == 53:         # SEC
            self.status.set_C(1)
        elif id == 54:         # SED
            self.status.set_D(1)
        elif id == 55:         # SEI
            self.status.set_I(1)

    # ------------------------------------------------------------------
    # immediate mode operands
    # ------------------------------------------------------------------
    proc op1(self, id, operand):
        if id == 0:            # LDA
            self.regs.a = operand & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 1:          # LDX
            self.regs.x = operand & 0xFF
            self.status.upd_nz(self.regs.x)
        elif id == 2:          # LDY
            self.regs.y = operand & 0xFF
            self.status.upd_nz(self.regs.y)
        elif id == 16:         # ADC
            self.adc(operand)
        elif id == 17:         # SBC
            self.sbc(operand)
        elif id == 18:         # AND
            self.regs.a = (self.regs.a & operand) & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 19:         # ORA
            self.regs.a = (self.regs.a | operand) & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 20:         # EOR
            self.regs.a = (self.regs.a ^ operand) & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 22:         # CMP
            self.compare(self.regs.a, operand)
        elif id == 23:         # CPX
            self.compare(self.regs.x, operand)
        elif id == 24:         # CPY
            self.compare(self.regs.y, operand)

    # ------------------------------------------------------------------
    # memory-addressed operations
    # ------------------------------------------------------------------
    proc op_with_addr(self, id, operand, addr):
        if id == 0:            # LDA
            self.regs.a = operand & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 1:          # LDX
            self.regs.x = operand & 0xFF
            self.status.upd_nz(self.regs.x)
        elif id == 2:          # LDY
            self.regs.y = operand & 0xFF
            self.status.upd_nz(self.regs.y)
        elif id == 3:          # STA
            self.write8(addr, self.regs.a)
        elif id == 4:          # STX
            self.write8(addr, self.regs.x)
        elif id == 5:          # STY
            self.write8(addr, self.regs.y)
        elif id == 16:         # ADC
            self.adc(operand)
        elif id == 17:         # SBC
            self.sbc(operand)
        elif id == 18:         # AND
            self.regs.a = (self.regs.a & operand) & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 19:         # ORA
            self.regs.a = (self.regs.a | operand) & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 20:         # EOR
            self.regs.a = (self.regs.a ^ operand) & 0xFF
            self.status.upd_nz(self.regs.a)
        elif id == 21:         # BIT
            let res = (self.regs.a & operand) & 0xFF
            if res == 0:
                self.status.set_Z(1)
            else:
                self.status.set_Z(0)
            self.status.set_N(operand & 0x80)
            self.status.set_V(operand & 0x40)
        elif id == 22:         # CMP
            self.compare(self.regs.a, operand)
        elif id == 23:         # CPX
            self.compare(self.regs.x, operand)
        elif id == 24:         # CPY
            self.compare(self.regs.y, operand)
        elif id == 25:         # INC
            let nv = (operand + 1) & 0xFF
            self.write8(addr, nv)
            self.status.upd_nz(nv)
        elif id == 26:         # DEC
            let nv = (operand - 1) & 0xFF
            self.write8(addr, nv)
            self.status.upd_nz(nv)
        elif id == 31 or id == 32 or id == 33 or id == 34:   # shifts on memory
            self.shift(id, operand, addr)
        elif id == 43:         # JMP (absolute or indirect)
            self.regs.pc = addr & 0xFFFF
        elif id == 44:         # JSR
            self.push16((self.regs.pc - 1) & 0xFFFF)
            self.regs.pc = addr & 0xFFFF

    proc adc(self, operand):
        let c = self.status.C()
        let sum = self.regs.a + (operand & 0xFF) + c
        let masked = sum & 0xFF
        let vbits = (self.regs.a ^ masked) & ((operand & 0xFF) ^ masked) & 0x80
        if sum > 0xFF:
            self.status.set_C(1)
        else:
            self.status.set_C(0)
        self.status.set_V(vbits)
        self.status.upd_nz(masked)
        self.regs.a = masked

    proc sbc(self, operand):
        let c = self.status.C()
        let complement = (operand & 0xFF) ^ 0xFF
        let sum = self.regs.a + complement + c
        let masked = sum & 0xFF
        let vbits = (self.regs.a ^ masked) & (complement ^ masked) & 0x80
        if sum < 0x100:
            self.status.set_C(0)
        else:
            self.status.set_C(1)
        self.status.set_V(vbits)
        self.status.upd_nz(masked)
        self.regs.a = masked

    proc compare(self, reg_, operand):
        let r = (reg_ - (operand & 0xFF)) & 0xFF
        self.status.upd_nz(r)
        if reg_ >= (operand & 0xFF):
            self.status.set_C(1)
        else:
            self.status.set_C(0)

    # ------------------------------------------------------------------
    # shifts / rotates: operate on A (addr nil) or memory
    # ------------------------------------------------------------------
    proc shift(self, id, operand, addr):
        var result = 0
        if id == 31:           # ASL
            result = (operand << 1) & 0xFF
            self.status.set_C(operand & 0x80)
        elif id == 32:         # LSR
            result = (operand >> 1) & 0xFF
            self.status.set_C(operand & 0x01)
        elif id == 33:         # ROL
            let c = self.status.C()
            result = ((operand << 1) & 0xFF) | c
            self.status.set_C(operand & 0x80)
        elif id == 34:         # ROR
            let c = self.status.C()
            result = ((operand >> 1) & 0xFF) | (c << 7)
            self.status.set_C(operand & 0x01)
        self.status.upd_nz(result)
        if addr == nil:
            self.regs.a = result & 0xFF
        else:
            self.write8(addr, result & 0xFF)

    # ------------------------------------------------------------------
    # relative branches; returns extra cycles: 1 taken, 2 taken + page
    # crossing (the NMOS 6502 charges +1 when the target crosses a page)
    # ------------------------------------------------------------------
    proc branch(self, id):
        let off = self.sbyte(self.read8(self.regs.pc))
        self.regs.pc = (self.regs.pc + 1) & 0xFFFF
        var take = false
        if id == 35:           # BCC
            if self.status.C() == 0:
                take = true
        elif id == 36:         # BCS
            if self.status.C() == 1:
                take = true
        elif id == 37:         # BEQ
            if self.status.Z() == 1:
                take = true
        elif id == 38:         # BMI
            if self.status.N() == 1:
                take = true
        elif id == 39:         # BNE
            if self.status.Z() == 0:
                take = true
        elif id == 40:         # BPL
            if self.status.N() == 0:
                take = true
        elif id == 41:         # BVC
            if self.status.V() == 0:
                take = true
        elif id == 42:         # BVS
            if self.status.V() == 1:
                take = true
        if take:
            let srcpage = self.regs.pc & 0xFF00
            self.regs.pc = (self.regs.pc + off) & 0xFFFF
            if (self.regs.pc & 0xFF00) != srcpage:
                return 2
            return 1
        return 0