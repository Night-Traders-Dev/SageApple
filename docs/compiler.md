# Compiler & assembler — `compiler/`

Two tools turn 6502 assembly and (a subset of) BASIC into 6502 machine code:

```
compiler/
├── asm6502.sage     two-pass 6502 assembler
└── backend.sage     BASIC -> 6502 compiler front-end + runtime
```

## `asm6502.sage` — two-pass assembler

A 139-entry opcode map (`fadd(mnemonic, mode, opcode)`) indexes
mnemonic+mode pairs to bytes. Supported instruction classes:

* loads/stores: LDA/LDX/LDY, STA/STX/STY with the standard memory modes
  (immediate, zero page ±X/Y, absolute ±X/Y, `(zp,X)` and `(zp),Y`
  indirect-indexed for LDA/STA);
* ADC/SBC/AND/ORA/EOR/CMP: immediate/zp/zpX/abs/absX/absY (the
  indirect-indexed forms are not emitted by the assembler);
* BIT, INC/DEC, shifts/rotates (accumulator + memory forms),
  JMP (abs + indirect), JSR, RTS/RTI, the eight branches, flags, stack
  ops, NOP, BRK.

Language features:

* `org <addr>` and `.byte v1, v2, ...` pseudo-ops;
* labels: `name:` (whitespace-free), forward references resolved by a
  **two-pass** size-then-emit strategy;
* `#<label` and `#>label` low/high immediates;
* `(zp),Y` / `(zp,X)` / `(abs)` addressing; `$nn`/`$nnnn` auto-select
  zero page vs absolute;
* relative branch offsets computed as `(target - (start + 2)) & 0xFF`;
* comments after `;`.

Entry point: `asm(source_lines, base) -> [image, labels]`; `hexb(v)`
formats bytes. It is used by the monitor ROM builder, the OS 6502 app
runner, the app catalog, and all compiler tests.

## `backend.sage` — BASIC to 6502

A narrowing compiler: it compiles a *numbered BASIC program* (the
PRINT/LET/GOTO/IF subset; no FOR/NEXT, no INPUT, no user functions) to
standalone 6502 code.

### Memory map of compiled programs

| area | purpose |
|---|---|
| `$20-$3E` | variables A..Z (26 zero-page bytes) |
| `$7C` | expression temp (left operand / lvalue) |
| `$7E` | expression temp (right operand / comparison) |
| `$7D`, `$7F` | decimal-print scratch |
| `$10/$11` | string pointer |
| `$1A-$1C` | multiply scratch |
| `$0300+` (typical) | program + runtime (assembled at caller-chosen base) |

### Compilation flow

1. lines de-duplicated by number (later wins), sorted numerically;
2. `org <base>`, a label `L<n>` per line, statement code;
3. `HALT: JMP HALT`, the runtime, then string data as `.byte` lists
   (`S0: .byte 48,45,...`).
4. output assembled by `asm6502.asm()`; returns `[image, halt_pc,
   labels]`.

### Statement generators

* `gen_print` — strings (into `S#` labels), expressions, blank lines,
  `;` suppresses CRLF;
* `gen_let` — evaluates expr, `STA $20+X`;
* `gen_goto` — `JMP L#`; unknown target prints `?` then halts;
* `gen_if` — THEN / GOTO variants, condition skips/jumps;
* `gen_cmp` — `$7C`/`$7E` temps, `SEC; SBC` compare;
* `gen_expr` — numbers `LDA #`, variables `LDA $zp`, negation via
  `EOR #$FF; CLC; ADC #$01`, `+ - * /` via runtime.

### Emitted runtime (6502 assembly)

`R_OUT`/`R_OUTW` (UART busy-wait `$2000`/`$2001`), `R_PSTR` (zero-terminated
string at `(0x10),Y`), `R_PRINT2` (up-to-3-digit decimal), `R_CRLF`,
`R_MUL` (8-iteration shift-add), `R_DIV` (repeated subtraction; divisor 0
yields 0).

## Test coverage

* `tests/compiler/test_asm6502.sage` — 11 checks (encoding, labels,
  emulator execution)
* `tests/compiler/test_backend.sage` — 20 checks (arithmetic, strings,
  GOTO/IF loops, comparisons, divide-by-zero).