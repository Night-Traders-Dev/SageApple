#########################################################################
## Sage6502 - Exhaustive CPU Verification Suite (Sampled)
#########################################################################

import sage6502.cpu
import bus.bus

var failures = 0
var passes = 0

proc run_cpu(prog, reset_addr, num_instrs):
    let b = bus.bus.Bus()
    let c = cpu.CPU(b)
    let base = 0x0200
    b.load(prog, base)
    b.write8(0xFFFC, base & 0xFF)
    b.write8(0xFFFD, (base >> 8) & 0xFF)
    if reset_addr != base:
        b.write8(0xFFFC, reset_addr & 0xFF)
        b.write8(0xFFFD, (reset_addr >> 8) & 0xFF)
    c.reset()
    c.run(num_instrs)
    return [b, c]

proc run_cpu_simple(prog):
    return run_cpu(prog, 0x0200, len(prog))[1]

proc hex(v):
    let h = "0123456789ABCDEF"
    return "0x" + h[(v >> 4) & 0x0F] + h[v & 0x0F]

#########################################################################
## Phase B.1: ADC Binary Tests (sampled)
#########################################################################

print("ADC binary:")
var failed = 0
var step = 64
var a = 0
while a < 256:
    var carry = 0
    while carry < 2:
        var b = 0
        while b < 256:
            let prog = [0x18, 0xA9, a, 0x69, b, 0xEA, 0xEA]
            if carry == 1:
                prog[0] = 0x38
            let c = run_cpu(prog, 0x0200, 3)[1]
            let sum = a + b + carry
            let expected = sum & 0xFF
            let expect_carry = 0
            if sum > 0xFF:
                expect_carry = 1
            if c.regs.a != expected:
                failed = failed + 1
            if c.status.C() != expect_carry:
                failed = failed + 1
            b = b + step
        carry = carry + 1
    a = a + step

if failed == 0:
    print("  PASS: all sampled ADC binary combinations")
    passes = passes + 1
else:
    print("  FAIL:", failed, "ADC binary failures")
    failures = failures + 1

#########################################################################
## Phase B.2: ADC Decimal Tests (NMOS, sampled)
#########################################################################

print("ADC decimal (NMOS):")
failed = 0
var step = 64
var a = 0
while a < 256:
    var carry = 0
    while carry < 2:
        var b = 0
        while b < 256:
            let prog = [0x18, 0xF8, 0xA9, a, 0x69, b, 0xEA]
            if carry == 1:
                prog[0] = 0x38
            let c = run_cpu(prog, 0x0200, 4)[1]
            var temp = a + b + carry
            if (a & 0x0F) + (b & 0x0F) + carry > 9:
                temp = temp + 6
            if temp > 0x99:
                temp = temp + 0x60
            let expected = temp & 0xFF
            let expect_carry = 0
            if temp > 0xFF:
                expect_carry = 1
            if c.regs.a != expected:
                failed = failed + 1
            if c.status.C() != expect_carry:
                failed = failed + 1
            b = b + step
        carry = carry + 1
    a = a + step

if failed == 0:
    print("  PASS: all sampled ADC decimal combinations")
    passes = passes + 1
else:
    print("  FAIL:", failed, "ADC decimal failures")
    failures = failures + 1

#########################################################################
## Phase B.3: SBC Binary Tests (sampled)
#########################################################################

print("SBC binary:")
var failed = 0
var a = 0
while a < 256:
    var carry = 0
    while carry < 2:
        var b = 0
        while b < 256:
            let prog = [0x18, 0xA9, a, 0xE9, b, 0xEA, 0xEA]
            if carry == 1:
                prog[0] = 0x38
            let c = run_cpu(prog, 0x0200, 3)[1]
            let borrow = 1 - carry
            let diff = a - b - borrow
            let expected = diff & 0xFF
            let expect_carry = 0
            if diff >= 0:
                expect_carry = 1
            if c.regs.a != expected:
                failed = failed + 1
            if c.status.C() != expect_carry:
                failed = failed + 1
            b = b + step
        carry = carry + 1
    a = a + step

if failed == 0:
    print("  PASS: all sampled SBC binary combinations")
    passes = passes + 1
else:
    print("  FAIL:", failed, "SBC binary failures")
    failures = failures + 1

#########################################################################
## Phase B.4: Branch Cycle Tests
#########################################################################

print("Branch cycles:")

proc test_branch(opcode, setup_taken, setup_not, expected_taken, expected_not_taken):
    let prog_taken = setup_taken
    let c_taken = run_cpu(prog_taken, 0x0200, len(prog_taken) - 1)[1]
    let prog_not = setup_not
    let c_not = run_cpu(prog_not, 0x0200, len(prog_not) - 1)[1]
    if c_taken.cycles == expected_taken and c_not.cycles == expected_not_taken:
        passes = passes + 1
    else:
        failures = failures + 1
        print("  FAIL: branch opcode", opcode, "taken=", c_taken.cycles, "not=", c_not.cycles)

test_branch(0x90, [0x18, 0x90, 0x00, 0xEA, 0xEA, 0xEA, 0xEA], [0x38, 0x90, 0x00, 0xEA, 0xEA, 0xEA, 0xEA], 5, 4)
test_branch(0xB0, [0x38, 0xB0, 0x00, 0xEA, 0xEA, 0xEA, 0xEA], [0x18, 0xB0, 0x00, 0xEA, 0xEA, 0xEA, 0xEA], 5, 4)
test_branch(0xF0, [0xA9, 0x00, 0xF0, 0x00, 0xEA, 0xEA, 0xEA], [0xA9, 0x01, 0xF0, 0x00, 0xEA, 0xEA, 0xEA], 10, 9)
test_branch(0x30, [0xA9, 0x00, 0x30, 0x00, 0xEA, 0xEA, 0xEA], [0xA9, 0x80, 0x30, 0x00, 0xEA, 0xEA, 0xEA], 11, 12)
test_branch(0xD0, [0xA9, 0x01, 0xD0, 0x00, 0xEA, 0xEA, 0xEA], [0xA9, 0x00, 0xD0, 0x00, 0xEA, 0xEA, 0xEA], 12, 11)
test_branch(0x10, [0xA9, 0x00, 0x10, 0x00, 0xEA, 0xEA, 0xEA], [0xA9, 0x80, 0x10, 0x00, 0xEA, 0xEA, 0xEA], 12, 11)
test_branch(0x50, [0xA9, 0x00, 0x50, 0x00, 0xEA, 0xEA, 0xEA], [0xA9, 0x80, 0x50, 0x00, 0xEA, 0xEA, 0xEA], 12, 12)
test_branch(0x70, [0xA9, 0x00, 0x70, 0x00, 0xEA, 0xEA, 0xEA], [0xA9, 0x80, 0x70, 0x00, 0xEA, 0xEA, 0xEA], 11, 11)

#########################################################################
## Phase B.5: Page-Cross Cycle Tests
#########################################################################

print("Page-cross cycles:")

proc test_page_cross(base_addr, idx_val, opcode, expected_cross, expected_same):
    let prog_cross = [0xA2, idx_val, opcode, base_addr & 0xFF, (base_addr >> 8) & 0xFF, 0xEA, 0xEA]
    let c_cross = run_cpu(prog_cross, 0x0200, 2)[1]
    let same_addr = base_addr - idx_val
    let prog_same = [0xA2, idx_val, opcode, same_addr & 0xFF, (same_addr >> 8) & 0xFF, 0xEA, 0xEA]
    let c_same = run_cpu(prog_same, 0x0200, 2)[1]
    if c_cross.cycles == expected_cross and c_same.cycles == expected_same:
        passes = passes + 1
    else:
        failures = failures + 1
        print("  FAIL: opcode", opcode, "cross=", c_cross.cycles, "same=", c_same.cycles, "exp_cross=", expected_cross, "exp_same=", expected_same)

test_page_cross(0x01FA, 0x07, 0xBD, 7, 6)
test_page_cross(0x0200, 0xFF, 0xBC, 6, 7)
test_page_cross(0x01FF, 0x01, 0xBD, 7, 6)

#########################################################################
## Phase B.6: JMP Indirect Page-Wrap Tests
#########################################################################

print("JMP indirect page-wrap:")

let b_jmp = bus.bus.Bus()
let c_jmp = cpu.CPU(b_jmp)
b_jmp.write8(0x12FF, 0x03)
b_jmp.write8(0x1200, 0x01)
b_jmp.load([0x6C, 0xFF, 0x12], 0x0200)
b_jmp.write8(0xFFFC, 0x00)
b_jmp.write8(0xFFFD, 0x02)
c_jmp.reset()
c_jmp.run(1)
if c_jmp.regs.pc == 0x0103:
    print("  PASS: JMP ($12FF) uses $1200 for high byte")
    passes = passes + 1
else:
    print("  FAIL: JMP ($12FF) PC=", hex(c_jmp.regs.pc))
    failures = failures + 1

#########################################################################
## Phase B.7: IRQ Stack B Flag = 0
#########################################################################

print("IRQ stack B flag = 0:")

let b_irq = bus.bus.Bus()
let c_irq = cpu.CPU(b_irq)
b_irq.load([0x58, 0xEA, 0x00], 0x0200)
b_irq.load([0xA9, 0x42, 0x28, 0x40], 0x0300)
b_irq.write8(0xFFFC, 0x00)
b_irq.write8(0xFFFD, 0x02)
b_irq.write8(0xFFFE, 0x00)
b_irq.write8(0xFFFF, 0x03)
c_irq.reset()
c_irq.interrupt()
let stack_byte = b_irq.read8(0x01FE)
if (stack_byte & 0x10) == 0:
    print("  PASS: IRQ pushed B=0")
    passes = passes + 1
else:
    print("  FAIL: IRQ B=1 byte=", hex(stack_byte))
    failures = failures + 1

#########################################################################
## Phase B.8: NMI Stack B Flag = 0
#########################################################################

print("NMI stack B flag = 0:")

let b_nmi = bus.bus.Bus()
let c_nmi = cpu.CPU(b_nmi)
b_nmi.load([0x58, 0xEA, 0x00], 0x0200)
b_nmi.load([0xA9, 0x42, 0x28, 0x40], 0x0300)
b_nmi.write8(0xFFFC, 0x00)
b_nmi.write8(0xFFFD, 0x02)
b_nmi.write8(0xFFFA, 0x00)
b_nmi.write8(0xFFFB, 0x03)
c_nmi.reset()
c_nmi.nmi()
let nmi_stack = b_nmi.read8(0x01FE)
if (nmi_stack & 0x10) == 0:
    print("  PASS: NMI pushed B=0")
    passes = passes + 1
else:
    print("  FAIL: NMI B=1 byte=", hex(nmi_stack))
    failures = failures + 1

#########################################################################
## Phase B.9: PHP Stack B Flag = 1
#########################################################################

print("PHP stack B flag = 1:")

let b_php = bus.bus.Bus()
let c_php = cpu.CPU(b_php)
b_php.load([0x08, 0xEA, 0xEA, 0xEA, 0xEA], 0x0200)
b_php.write8(0xFFFC, 0x00)
b_php.write8(0xFFFD, 0x02)
c_php.reset()
c_php.run(1)
let php_stack = b_php.read8(0x01FD)
if (php_stack & 0x10) != 0:
    print("  PASS: PHP pushed B=1")
    passes = passes + 1
else:
    print("  FAIL: PHP B=0 byte=", hex(php_stack))
    failures = failures + 1

#########################################################################
## Phase B.10: PLP Bit 5 Normalization
#########################################################################

print("PLP/RTI bit 5 normalization:")

let b_plp = bus.bus.Bus()
let c_plp = cpu.CPU(b_plp)
b_plp.load([0xA9, 0x00, 0x48, 0x28, 0x00], 0x0200)
b_plp.write8(0xFFFC, 0x00)
b_plp.write8(0xFFFD, 0x02)
b_plp.write8(0x01FD, 0x00)
c_plp.reset()
c_plp.run(3)
let plp_status = c_plp.status.get()
if (plp_status & 0x20) != 0:
    print("  PASS: PLP normalizes bit 5 = 1")
    passes = passes + 1
else:
    print("  FAIL: PLP bit5=0 status=", hex(plp_status))
    failures = failures + 1

#########################################################################
## Phase B.11: NMI Priority Over IRQ
#########################################################################

print("NMI priority over IRQ:")

let b_priority = bus.bus.Bus()
let c_priority = cpu.CPU(b_priority)
b_priority.load([0x58, 0xEA, 0x00], 0x0200)
b_priority.load([0xA9, 0x99, 0x40], 0x0300)
b_priority.load([0xA9, 0x66, 0x40], 0x0400)
b_priority.write8(0xFFFE, 0x00)
b_priority.write8(0xFFFF, 0x03)
b_priority.write8(0xFFFA, 0x00)
b_priority.write8(0xFFFB, 0x04)
c_priority.reset()
c_priority.interrupt()
c_priority.nmi()
c_priority.run(1000)
if c_priority.regs.a == 0x99:
    print("  PASS: NMI takes priority over IRQ")
    passes = passes + 1
else:
    print("  FAIL: IRQ took priority A=", hex(c_priority.regs.a))
    failures = failures + 1

#########################################################################
## Results
#########################################################################

print("")
print("Results:", passes, "passed,", failures, "failed")
if failures == 0:
    print("ALL OK")
