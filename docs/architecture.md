# Architecture

SageApple is an Apple II-inspired retrocomputer whose software is written
almost entirely in **SageLang**, a self-hosted language with its own
interpreter (the `sage` binary). The interesting part is what happens at the
edges:

- a **table-driven NMOS 6502 CPU emulator** written in SageLang
  (`sage6502/`),
- a **SageLang-to-6502 compiler backend** (`compiler/`),
- a **SageLang-implemented computer system** layered on top of that CPU
  (bus, devices, BASIC, monitor, OS, filesystem),
- a **hardware port** of the whole thing to an **ATmega328P (Arduino UNO
  R3-compatible)** board, where the 6502 core is a faithful C port
  (`avr/sage6502.c`) run by a thin AVR runtime.

The result is a system that can be booted either by the host `sage`
interpreter (fully emulated, used by the test suites) or on the real chip
(serial terminal, monitor, BASIC — proven working on silicon).

## System layers

```
 +---------------------------+-----------------------------+
 |  apps/   catalog          |  installed apps: HELLO,     |
 |                           |  COUNTER, BEEP, MACHINE1    |
 +---------------------------+-----------------------------+
 |  sageapple/               |  OS console, SAGEFS        |
 |                           |  filesystem, DOS 3.3,      |
 |                           |  graphics, monitor,        |
 |                           |  boot/terminal             |
 +---------------------------+-----------------------------+
 |  basic/                   |  Applesoft BASIC interpreter     |
 +---------------------------+-----------------------------+
 |  compiler/                |  asm6502 two-pass assembler |
 |                           |  + BASIC -> 6502 backend    |
 +---------------------------+-----------------------------+
 |  bus/   devices/          |  AppleBus memory map, UART, |
 |                           |  SPI, OLED, NOR flash, spkr |
 +---------------------------+-----------------------------+
 |  sage6502/                |  table-driven NMOS 6502 core|
 +---------------------------+-----------------------------+
 |  avr/                     |  C runtime + C port of the |
 |                           |  core for the ATmega328P    |
 +---------------------------+-----------------------------+
```

Every layer above `bus/` executes on top of the 6502 core. The core never
touches host memory directly: all memory access is routed through a `Bus`
interface, so the very same CPU runs inside the host interpreter and on the
AVR chip.

## Component documentation

| Document | Covers |
|---|---|
| [docs/sage6502.md](sage6502.md) | CPU core, registers, flags, instruction set, timing |
| [docs/bus.md](bus.md) | flat bus, AppleBus memory map, I/O ports |
| [docs/devices.md](devices.md) | UART, SPI, OLED display, NOR flash, speaker |
| [docs/basic.md](basic.md) | Applesoft BASIC interpreter |
| [docs/compiler.md](compiler.md) | 6502 assembler + SageLang-to-6502 backend |
| [docs/os.md](os.md) | OS console, monitor, filesystem, graphics, boot |
| [docs/avr.md](avr.md) | ATmega328P port, C runtime, flashing |
| [docs/tools.md](tools.md) | host-side tools (hex, ROM, table generation) |
| [docs/tests.md](tests.md) | the 15 validation suites |

## Key design decisions

1. **The CPU never knows about the host.** All reads/writes go through the
   `Bus`/`AppleBus` interface. This is what lets the identical core run
   under host emulation and on the AVR with a C bus backed by SRAM + flash
   PROGMEM.
2. **BASIC runs natively as SageLang**, not as 6502 code. The interpreter
   lives in `basic/basic.sage` and drives the 6502 machine peripherally; for
   standalone execution on the chip the host side interprets BASIC while the
   system runs under the C port of the CPU. The `compiler/backend` exists
   to *compile* BASIC programs to 6502 for the cases where native 6502
   execution matters.
3. **Framebuffer lives on the display controller** (1024 bytes, page-major),
   never in the 2 KB of SRAM.
4. **Static allocation and bit packing everywhere.** No heap, no dynamic
   resources; data structures are pre-sized to fit the AVR budget.
5. **The same session is the test.** `tools/rom_gen.sage` runs a canonical
   terminal session (help, regs, peek/poke, dump, reset...) and records the
   byte-exact transcript into `avr/host_expected.txt`. The AVR port replays
   the identical session through the C core (`make host-test`) and must
   produce byte-identical output — host bus vs AVR bus equivalence, proven
   mechanically.

## Execution models

| Model | Where | How |
|---|---|---|
| Host (emulated) | `sage` interpreter on the host | `sageapple/machine.sage` composes `AppleBus` + `CPU`; tests drive it directly |
| Host (hard 6502) | compiled C core on the host | `avr/` built with `-DHOST` runs `sage6502.c` natively for equivalence tests |
| Device (silicon) | ATmega328P | `make flash` burns the same core + monitor ROM; the 6502 talks to a real UART |

## Memory map (canonical)

| Range | Device |
|---|---|
| `$0000-$07FF` | 2 KB RAM |
| `$2000-$2001` | UART status/data |
| `$2002-$2004` | SPI display control |
| `$2005-$2006` | SPI flash control |
| `$2007` | speaker tone (0 = silence) |
| `$3000` | legacy console TX alias |
| `$8000-$FFFF` | 32 KB program ROM (read-only) |

(On the AVR target RAM is truncated to `$0000-$03FF` — 1 KB, the second KB of
the host budget belongs to the emulator state; see [docs/avr.md](avr.md).)

## The 6502-centered pieces at a glance

| module | purpose |
|---|---|
| `sage6502/cpu.sage` | 671-line table-driven NMOS 6502 interpreter, 151 canonical opcodes, all 13 addressing modes, cycle counting, interrupts |
| `sage6502/registers.sage` | A/X/Y/SP/PC object |
| `sage6502/flags.sage` | processor status byte NV-BDIZC |
| `bus/bus.sage` | 64 KB flat byte-array bus |
| `bus/applebus.sage` | the AppleBus: RAM + ROM + memory-mapped devices |
| `devices/*.sage` | UART, SPI master, OLED display, NOR flash, speaker models |
| `basic/basic.sage` | Applesoft BASIC interpreter (PRINT/LET/GOTO/IF/FOR/INPUT/GOSUB/DEF FN/READ/DATA...) |
| `compiler/asm6502.sage` | two-pass 6502 assembler |
| `compiler/backend.sage` | BASIC -> 6502 compiler with runtime |
| `sageapple/*.sage` | OS, monitor, storage/SAGEFS, graphics, machine, terminal, echo, boot |
| `apps/catalog.sage` | preinstalled app catalog |
| `avr/*` | C runtime, C port of the core, linker/startup, make/avrdude |

See [PLAN.md](../PLAN.md) for the original plan, phases, and design notes,
and [CHANGELOG.md](../CHANGELOG.md) for the milestone log.