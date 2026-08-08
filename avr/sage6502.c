/*
 * SageApple — Sage6502 CPU core, ported from sage6502/cpu.sage (M13)
 *
 * Faithful C port of the table-driven NMOS 6502 interpreter used by the
 * Sage reference implementation. Memory accesses go through bus_read8 /
 * bus_write8 so the same core runs on the host (stdio UART) and AVR
 * (hardware UART, PROGMEM ROM, SRAM RAM).
 *
 * Status register bit layout (matches sage6502/flags.sage):
 *   7 6 5 4 3 2 1 0   =  N V - B D I Z C
 */
#include <stdint.h>

#ifndef HOST
#include <avr/io.h>
#include <avr/pgmspace.h>
#endif

/* addressing-mode constants (mirror cpu.sage) */
#define M_IMM   0
#define M_ZP    1
#define M_ZPX   2
#define M_ZPY   3
#define M_ABS   4
#define M_ABSX  5
#define M_ABSY  6
#define M_INDX  7
#define M_INDY  8
#define M_ACC   9
#define M_IND   10
#define M_REL   11
#define M_IMP   12

/* registers */
static uint8_t rA, rX, rY, rSP;
static uint16_t rPC;
static uint8_t rP;              /* status register */
static volatile uint8_t halted;

/* ---- memory interface (defined in bus.c) ---- */
void bus_write(uint16_t addr, uint8_t v);
uint8_t bus_read(uint16_t addr);

/* flags */
#define FL_N 0x80
#define FL_V 0x40
#define FL_B 0x10
#define FL_D 0x08
#define FL_I 0x04
#define FL_Z 0x02
#define FL_C 0x01

static void upd_nz(uint8_t v) {
    if (v & 0x80) rP |= FL_N; else rP &= ~FL_N;
    if (v == 0)   rP |= FL_Z; else rP &= ~FL_Z;
}
static uint8_t F_N(void) { return (rP & FL_N) ? 1 : 0; }
static uint8_t F_V(void) { return (rP & FL_V) ? 1 : 0; }
static uint8_t F_I(void) { return (rP & FL_I) ? 1 : 0; }
static uint8_t F_Z(void) { return (rP & FL_Z) ? 1 : 0; }
static uint8_t F_C(void) { return (rP & FL_C) ? 1 : 0; }

/* ---- opcode table: (id << 4) | mode ---- */
#ifndef HOST
static const uint16_t OP[256] PROGMEM = {
#else
static const uint16_t OP[256] = {
#endif
    /*00*/ 46<<4|M_IMP,   19<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   19<<4|M_ZP,   31<<4|M_ZP,   0<<4|M_IMP,   13<<4|M_IMP,   19<<4|M_IMM,   31<<4|M_ACC,   0<<4|M_IMP,   0<<4|M_IMP,   19<<4|M_ABS,   31<<4|M_ABS,   0<<4|M_IMP,   
    /*10*/ 40<<4|M_REL,   19<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   19<<4|M_ZPX,   31<<4|M_ZPX,   0<<4|M_IMP,   49<<4|M_IMP,   19<<4|M_ABSY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   19<<4|M_ABSX,   31<<4|M_ABSX,   0<<4|M_IMP,   
    /*20*/ 44<<4|M_ABS,   18<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   21<<4|M_ZP,   18<<4|M_ZP,   33<<4|M_ZP,   0<<4|M_IMP,   15<<4|M_IMP,   18<<4|M_IMM,   33<<4|M_ACC,   0<<4|M_IMP,   21<<4|M_ABS,   18<<4|M_ABS,   33<<4|M_ABS,   0<<4|M_IMP,   
    /*30*/ 38<<4|M_REL,   18<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   18<<4|M_ZPX,   33<<4|M_ZPX,   0<<4|M_IMP,   53<<4|M_IMP,   18<<4|M_ABSY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   18<<4|M_ABSX,   33<<4|M_ABSX,   0<<4|M_IMP,   
    /*40*/ 47<<4|M_IMP,   20<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   20<<4|M_ZP,   32<<4|M_ZP,   0<<4|M_IMP,   12<<4|M_IMP,   20<<4|M_IMM,   32<<4|M_ACC,   0<<4|M_IMP,   43<<4|M_ABS,   20<<4|M_ABS,   32<<4|M_ABS,   0<<4|M_IMP,   
    /*50*/ 41<<4|M_REL,   20<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   20<<4|M_ZPX,   32<<4|M_ZPX,   0<<4|M_IMP,   51<<4|M_IMP,   20<<4|M_ABSY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   20<<4|M_ABSX,   32<<4|M_ABSX,   0<<4|M_IMP,   
    /*60*/ 45<<4|M_IMP,   16<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   16<<4|M_ZP,   34<<4|M_ZP,   0<<4|M_IMP,   14<<4|M_IMP,   16<<4|M_IMM,   34<<4|M_ACC,   0<<4|M_IMP,   43<<4|M_IND,   16<<4|M_ABS,   34<<4|M_ABS,   0<<4|M_IMP,   
    /*70*/ 42<<4|M_REL,   16<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   16<<4|M_ZPX,   34<<4|M_ZPX,   0<<4|M_IMP,   55<<4|M_IMP,   16<<4|M_ABSY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   16<<4|M_ABSX,   34<<4|M_ABSX,   0<<4|M_IMP,   
    /*80*/ 0<<4|M_IMP,   3<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   5<<4|M_ZP,   3<<4|M_ZP,   4<<4|M_ZP,   0<<4|M_IMP,   30<<4|M_IMP,   0<<4|M_IMP,   7<<4|M_IMP,   0<<4|M_IMP,   5<<4|M_ABS,   3<<4|M_ABS,   4<<4|M_ABS,   0<<4|M_IMP,   
    /*90*/ 35<<4|M_REL,   3<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   5<<4|M_ZPX,   3<<4|M_ZPX,   4<<4|M_ZPY,   0<<4|M_IMP,   9<<4|M_IMP,   3<<4|M_ABSY,   11<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   3<<4|M_ABSX,   0<<4|M_IMP,   0<<4|M_IMP,   
    /*A0*/ 2<<4|M_IMM,   0<<4|M_INDX,   1<<4|M_IMM,   0<<4|M_IMP,   2<<4|M_ZP,   0<<4|M_ZP,   1<<4|M_ZP,   0<<4|M_IMP,   8<<4|M_IMP,   0<<4|M_IMM,   6<<4|M_IMP,   0<<4|M_IMP,   2<<4|M_ABS,   0<<4|M_ABS,   1<<4|M_ABS,   0<<4|M_IMP,   
    /*B0*/ 36<<4|M_REL,   0<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   2<<4|M_ZPX,   0<<4|M_ZPX,   1<<4|M_ZPY,   0<<4|M_IMP,   52<<4|M_IMP,   0<<4|M_ABSY,   10<<4|M_IMP,   0<<4|M_IMP,   2<<4|M_ABSX,   0<<4|M_ABSX,   1<<4|M_ABSY,   0<<4|M_IMP,   
    /*C0*/ 24<<4|M_IMM,   22<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   24<<4|M_ZP,   22<<4|M_ZP,   26<<4|M_ZP,   0<<4|M_IMP,   28<<4|M_IMP,   22<<4|M_IMM,   29<<4|M_IMP,   0<<4|M_IMP,   24<<4|M_ABS,   22<<4|M_ABS,   26<<4|M_ABS,   0<<4|M_IMP,   
    /*D0*/ 39<<4|M_REL,   22<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   22<<4|M_ZPX,   26<<4|M_ZPX,   0<<4|M_IMP,   50<<4|M_IMP,   22<<4|M_ABSY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   22<<4|M_ABSX,   26<<4|M_ABSX,   0<<4|M_IMP,   
    /*E0*/ 23<<4|M_IMM,   17<<4|M_INDX,   0<<4|M_IMP,   0<<4|M_IMP,   23<<4|M_ZP,   17<<4|M_ZP,   25<<4|M_ZP,   0<<4|M_IMP,   27<<4|M_IMP,   17<<4|M_IMM,   48<<4|M_IMP,   0<<4|M_IMP,   23<<4|M_ABS,   17<<4|M_ABS,   25<<4|M_ABS,   0<<4|M_IMP,   
    /*F0*/ 37<<4|M_REL,   17<<4|M_INDY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   17<<4|M_ZPX,   25<<4|M_ZPX,   0<<4|M_IMP,   54<<4|M_IMP,   17<<4|M_ABSY,   0<<4|M_IMP,   0<<4|M_IMP,   0<<4|M_IMP,   17<<4|M_ABSX,   25<<4|M_ABSX,   0<<4|M_IMP
};




/* ---- stack helpers ---- */
static void push(uint8_t v) {
    bus_write(0x0100 | rSP, v);
    rSP = (rSP - 1) & 0xFF;
}
static uint8_t pull(void) {
    rSP = (rSP + 1) & 0xFF;
    return bus_read(0x0100 | rSP);
}
static void push16(uint16_t v) { push(v >> 8); push(v & 0xFF); }
static uint16_t pull16(void) {
    uint8_t lo = pull();
    uint8_t hi = pull();
    return (uint16_t)((hi << 8) | lo);
}

/* effective address for non-immediate memory modes; mode==0 (imm) handled
   by the caller, returns addr (pc already advanced) */
static uint16_t fetch(uint8_t mode) {
    switch (mode) {
    case M_ZP: {
        uint8_t zp = bus_read(rPC);
        rPC = (rPC + 1) & 0xFFFF;
        return zp;
    }
    case M_ZPX: {
        uint8_t zp = bus_read(rPC);
        rPC = (rPC + 1) & 0xFFFF;
        return (uint16_t)((zp + rX) & 0xFF);
    }
    case M_ZPY: {
        uint8_t zp = bus_read(rPC);
        rPC = (rPC + 1) & 0xFFFF;
        return (uint16_t)((zp + rY) & 0xFF);
    }
    case M_ABS: {
        uint8_t lo = bus_read(rPC);
        uint8_t hi = bus_read((rPC + 1) & 0xFFFF);
        rPC = (rPC + 2) & 0xFFFF;
        return (uint16_t)((hi << 8) | lo);
    }
    case M_ABSX: {
        uint8_t lo = bus_read(rPC);
        uint8_t hi = bus_read((rPC + 1) & 0xFFFF);
        rPC = (rPC + 2) & 0xFFFF;
        return (uint16_t)((((hi << 8) | lo) + rX) & 0xFFFF);
    }
    case M_ABSY: {
        uint8_t lo = bus_read(rPC);
        uint8_t hi = bus_read((rPC + 1) & 0xFFFF);
        rPC = (rPC + 2) & 0xFFFF;
        return (uint16_t)((((hi << 8) | lo) + rY) & 0xFFFF);
    }
    case M_INDX: {
        uint8_t zp = bus_read(rPC);
        rPC = (rPC + 1) & 0xFFFF;
        uint8_t ptr = (uint8_t)((zp + rX) & 0xFF);
        uint8_t lo = bus_read(ptr);
        uint8_t hi = bus_read((uint8_t)((ptr + 1) & 0xFF));
        return (uint16_t)((hi << 8) | lo);
    }
    case M_INDY: {
        uint8_t zp = bus_read(rPC);
        rPC = (rPC + 1) & 0xFFFF;
        uint8_t lo = bus_read(zp);
        uint8_t hi = bus_read((uint8_t)((zp + 1) & 0xFF));
        return (uint16_t)((((hi << 8) | lo) + rY) & 0xFFFF);
    }
    case M_IND: {
        uint8_t lo = bus_read(rPC);
        uint8_t hi = bus_read((rPC + 1) & 0xFFFF);
        rPC = (rPC + 2) & 0xFFFF;
        uint16_t ptr = (uint16_t)((hi << 8) | lo);
        return (uint16_t)(bus_read(ptr) | (bus_read((uint16_t)((ptr + 1) & 0xFFFF)) << 8));
    }
    }
    return 0;
}

static int8_t sbyte(uint8_t b) { return (b & 0x80) ? (int8_t)(b - 0x100) : (int8_t)b; }

/* ---- arithmetic ---- */
static void adc(uint8_t operand) {
    uint8_t c = F_C();
    uint16_t sum = (uint16_t)rA + operand + c;
    uint8_t masked = sum & 0xFF;
    uint8_t v = (uint8_t)((rA ^ masked) & (operand ^ masked) & 0x80);
    if (sum > 0xFF) rP |= FL_C; else rP &= ~FL_C;
    if (v) rP |= FL_V; else rP &= ~FL_V;
    upd_nz(masked);
    rA = masked;
}
static void sbc(uint8_t operand) {
    uint8_t c = F_C();
    uint8_t complement = operand ^ 0xFF;
    uint16_t sum = (uint16_t)rA + complement + c;
    uint8_t masked = sum & 0xFF;
    uint8_t v = (uint8_t)((rA ^ masked) & (complement ^ masked) & 0x80);
    if (sum < 0x100) rP &= ~FL_C; else rP |= FL_C;
    if (v) rP |= FL_V; else rP &= ~FL_V;
    upd_nz(masked);
    rA = masked;
}
static void compare(uint8_t reg_, uint8_t operand) {
    uint8_t r = (uint8_t)((reg_ - operand) & 0xFF);
    upd_nz(r);
    if (reg_ >= operand) rP |= FL_C; else rP &= ~FL_C;
}

/* shift/rotate on A (addr==0xFFFF marker) or memory */
static void shift(uint8_t id, uint8_t operand, uint16_t addr, uint8_t memop);

static void op_with_addr(uint8_t id, uint8_t operand, uint16_t addr) {
    switch (id) {
    case 0: rA = operand; upd_nz(rA); break;            /* LDA */
    case 1: rX = operand; upd_nz(rX); break;            /* LDX */
    case 2: rY = operand; upd_nz(rY); break;            /* LDY */
    case 3: bus_write(addr, rA); break;                 /* STA */
    case 4: bus_write(addr, rX); break;                 /* STX */
    case 5: bus_write(addr, rY); break;                 /* STY */
    case 16: adc(operand); break;                       /* ADC */
    case 17: sbc(operand); break;                       /* SBC */
    case 18: rA &= operand; upd_nz(rA); break;          /* AND */
    case 19: rA |= operand; upd_nz(rA); break;          /* ORA */
    case 20: rA ^= operand; upd_nz(rA); break;          /* EOR */
    case 21: {                                          /* BIT */
        uint8_t res = rA & operand;
        if (res == 0) rP |= FL_Z; else rP &= ~FL_Z;
        if (operand & 0x80) rP |= FL_N; else rP &= ~FL_N;
        if (operand & 0x40) rP |= FL_V; else rP &= ~FL_V;
        break;
    }
    case 22: compare(rA, operand); break;               /* CMP */
    case 23: compare(rX, operand); break;               /* CPX */
    case 24: compare(rY, operand); break;               /* CPY */
    case 25: { uint8_t nv = (uint8_t)(operand + 1); bus_write(addr, nv); upd_nz(nv); break; } /* INC */
    case 26: { uint8_t nv = (uint8_t)(operand - 1); bus_write(addr, nv); upd_nz(nv); break; } /* DEC */
    case 31: case 32: case 33: case 34: shift(id, operand, addr, 1); break;
    case 43: rPC = addr; break;                         /* JMP */
    case 44: push16((uint16_t)((rPC - 1) & 0xFFFF)); rPC = addr; break; /* JSR */
    }
}

static void shift(uint8_t id, uint8_t operand, uint16_t addr, uint8_t memop) {
    uint8_t c = 0, result = 0;
    switch (id) {
    case 31: result = (uint8_t)(operand << 1); if (operand & 0x80) rP |= FL_C; else rP &= ~FL_C; break; /* ASL */
    case 32: result = (uint8_t)(operand >> 1); if (operand & 0x01) rP |= FL_C; else rP &= ~FL_C; break; /* LSR */
    case 33: c = F_C(); result = (uint8_t)((operand << 1) | c); if (operand & 0x80) rP |= FL_C; else rP &= ~FL_C; break; /* ROL */
    case 34: c = F_C(); result = (uint8_t)((operand >> 1) | (c << 7)); if (operand & 0x01) rP |= FL_C; else rP &= ~FL_C; break; /* ROR */
    }
    upd_nz(result);
    if (memop) bus_write(addr, result); else rA = result;
}

/* branch with extra cycle */
static uint8_t branch(uint8_t id) {
    int8_t off = sbyte(bus_read(rPC));
    rPC = (rPC + 1) & 0xFFFF;
    uint8_t take = 0;
    switch (id) {
    case 35: take = (F_C() == 0); break;
    case 36: take = (F_C() == 1); break;
    case 37: take = (F_Z() == 1); break;
    case 38: take = (F_N() == 1); break;
    case 39: take = (F_Z() == 0); break;
    case 40: take = (F_N() == 0); break;
    case 41: take = (F_V() == 0); break;
    case 42: take = (F_V() == 1); break;
    }
    if (take) rPC = (uint16_t)((rPC + off) & 0xFFFF);
    return take;
}

/* implied-mode operations */
static void op0_op(uint8_t id) {
    switch (id) {
    case 6: rX = rA; upd_nz(rX); break;              /* TAX */
    case 7: rA = rX; upd_nz(rA); break;              /* TXA */
    case 8: rY = rA; upd_nz(rY); break;              /* TAY */
    case 9: rA = rY; upd_nz(rA); break;              /* TYA */
    case 10: rX = rSP; upd_nz(rX); break;            /* TSX */
    case 11: rSP = rX; break;                        /* TXS */
    case 12: push(rA); break;                        /* PHA */
    case 13: push(rP | 0x30); break;                 /* PHP */
    case 14: rA = pull(); upd_nz(rA); break;         /* PLA */
    case 15: rP = pull(); break;                     /* PLP */
    case 27: rX = (uint8_t)(rX + 1); upd_nz(rX); break; /* INX */
    case 28: rY = (uint8_t)(rY + 1); upd_nz(rY); break; /* INY */
    case 29: rX = (uint8_t)(rX - 1); upd_nz(rX); break; /* DEX */
    case 30: rY = (uint8_t)(rY - 1); upd_nz(rY); break; /* DEY */
    case 45: rPC = (uint16_t)((pull16() + 1) & 0xFFFF); break; /* RTS */
    case 46:                                           /* BRK */
        push16(rPC);
        push((uint8_t)(rP | 0x30));
        rP |= FL_I;
        rPC = (uint16_t)(bus_read(0xFFFE) | (bus_read(0xFFFF) << 8));
        halted = 1;
        break;
    case 47: rP = pull(); rPC = pull16(); break;     /* RTI */
    case 49: rP &= ~FL_C; break;                     /* CLC */
    case 50: rP &= ~FL_D; break;                     /* CLD */
    case 51: rP &= ~FL_I; break;                     /* CLI */
    case 52: rP &= ~FL_V; break;                     /* CLV */
    case 53: rP |= FL_C; break;                      /* SEC */
    case 54: rP |= FL_D; break;                      /* SED */
    case 55: rP |= FL_I; break;                      /* SEI */
    }
}

/* immediate-mode operands */
static void op_imm(uint8_t id, uint8_t operand) {
    switch (id) {
    case 0: rA = operand; upd_nz(rA); break;        /* LDA */
    case 1: rX = operand; upd_nz(rX); break;        /* LDX */
    case 2: rY = operand; upd_nz(rY); break;        /* LDY */
    case 16: adc(operand); break;
    case 17: sbc(operand); break;
    case 18: rA &= operand; upd_nz(rA); break;
    case 19: rA |= operand; upd_nz(rA); break;
    case 20: rA ^= operand; upd_nz(rA); break;
    case 22: compare(rA, operand); break;
    case 23: compare(rX, operand); break;
    case 24: compare(rY, operand); break;
    }
}

/* decode one instruction */
static void exec_step(void) {
    uint8_t code = bus_read(rPC);
    rPC = (rPC + 1) & 0xFFFF;
#ifdef HOST
    uint16_t op_ent = OP[code];
#else
    uint16_t op_ent = pgm_read_word(&OP[code]);
#endif
    uint8_t id = (uint8_t)((op_ent >> 4) & 0x3F);
    uint8_t mode = op_ent & 0x0F;

    if (mode == M_IMM) {
        uint8_t operand = bus_read(rPC);
        rPC = (rPC + 1) & 0xFFFF;
        op_imm(id, operand);
    } else if (mode == M_ACC) {
        shift(id, rA, 0, 0);
    } else if (mode == M_REL) {
        branch(id);
    } else if (mode == M_IMP) {
        op0_op(id);
    } else {
        uint16_t addr = fetch(mode);
        if (id == 3 || id == 4 || id == 5) {        /* pure stores */
            bus_write(addr, (id == 3) ? rA : (id == 4 ? rX : rY));
        } else {
            uint8_t operand = bus_read(addr);
            op_with_addr(id, operand, addr);
        }
    }
}

void cpu_reset(void) {
    rSP = 0xFD;
    rPC = (uint16_t)(bus_read(0xFFFC) | (bus_read(0xFFFD) << 8));
    rP = 0x00;
    rP |= FL_B;
    rP |= FL_I;
    rA = 0; rX = 0; rY = 0;
    halted = 0;
}

void cpu_step(void) { if (!halted) exec_step(); }
uint8_t cpu_halted(void) { return halted; }

/* accessors used by the AVR port to show registers */
uint16_t cpu_pc(void) { return rPC; }
uint8_t cpu_a(void) { return rA; }
uint8_t cpu_x(void) { return rX; }
uint8_t cpu_y(void) { return rY; }
uint8_t cpu_sp(void) { return rSP; }
uint8_t cpu_p(void) { return rP; }

const uint16_t *cpu_op_table(void) { return OP; }

