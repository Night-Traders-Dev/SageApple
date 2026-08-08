# Host tools — `tools/`

SageLang host-side utilities that build, flash, and validate artifacts.
All run with the `sage` interpreter from the repo root.

| tool | purpose |
|---|---|
| `tools/avr_boot.sage` | Sage → AVR opcodes → Intel HEX boot image |
| `tools/rom_builder.sage` | Intel HEX record emitter for 6502 ROMs |
| `tools/rom_gen.sage` | builds the monitor ROM + oracle transcript |
| `tools/gen_table.sage` | regenerates the C opcode table from the core |
| `tools/hex_dump.sage` | dumps `build/boot.bin` for inspection |

## `avr_boot.sage`

* AVR instruction encoders (`enc_ldi`, `enc_out`, `enc_rjmp`,
  `enc_in`) proven correct against the ATmega328P;
* a `emit_hex()` Intel-HEX record writer (checksums included);
* `build_boot()` emits a standalone AVR UART-init + TX blob (UDR0
  written with `'H'`, then a self-loop) and writes `build/boot.hex`.

This was milestone-4 proof that **SageLang → AVR opcodes → Intel HEX →
flash** works.

## `rom_builder.sage`

`emit_8_hex(bytes, base)` — records of 16 bytes with an EOF record —
shared by the ROM-generating tools.

## `rom_gen.sage`

The canonical **oracle** generator. It:

1. assembles `sageapple/monitor.sage` into an 8 KB window (normally
   `$E000-$FFFF`); writes `avr/rom.inc` (PROGMEM array) and
   `avr/rom_host.c` (host array);
2. builds a 32 KB ROM (monitor at `$E000`, reset vector `$E000`);
3. **drives a real machine session** — help, regs, peek 0000, poke 0000
   42, peek 0000, dump 0030 0030, xyz, run, reset, help — with a 60,000
   step budget per command and writes the verbatim UART transcript to
   `avr/host_expected.txt`.

That transcript is the byte-exact equivalence target for the AVR port
(`make host-test`), exactly as the on-chip monitor must reproduce it.

## `gen_table.sage`

Reads `sage6502.cpu._OPCODES` (the canonical 256-entry `[id, mode]`
table) and rewrites the `OP[256]` initializer inside `avr/sage6502.c`.
Rerun it (from the repo root):

```sh
sage tools/gen_table.sage
```

and the C port's opcode table is rewritten to agree with the Sage core —
the fix for the drift that silently broke the on-chip dispatch.

## `hex_dump.sage`

Small helper that reads `build/boot.bin` and prints 16 bytes per line
with offsets, for eyeballing generated binaries.