# SageApple

![SageApple](assets/SageApple.jpg)

An **Apple II-inspired retrocomputer** implemented primarily in **pure
SageLang**, targeting an inexpensive **ATmega328P / Arduino UNO R3-compatible**
board (the $1.05 US-UK-buy variety).

At its core is a reusable **Sage6502 CPU core** — a table-driven NMOS 6502
interpreter — plus a **SageLang-to-6502 compiler backend**. The machine is
complete end to end: it boots, talks to a terminal, runs a monitor, executes
Tiny BASIC programs, drives an SPI OLED display, stores programs on SPI NOR
flash through a filesystem, beeps a speaker, and loads 6502 applications from
a standalone OS console — all verified by an emulated test suite.

See [`PLAN.md`](PLAN.md) for the full architecture, phases, and milestones.

## Status

**Complete** — Milestones 1–12 are done; the repo is clean and green:
**14 test modules, 211 checks passing.**

| Milestone | Deliverable |
|---|---|
| M1 | Repository, PLAN, README, license |
| M2 | Sage6502 CPU core (instruction table, addressing modes, IRQ/NMI, BRK/RTI) |
| M3 | CPU + opcode validation suites |
| M4 | AVR target (linker, startup, UART runtime, make/avrdude flow) |
| M5 | Boot ROM, reset vector, memory bus, 2KB RAM + 32KB ROM |
| M6 | UART device on `$2000-$2001`, terminal I/O |
| M7 | 6502 monitor (`help dump peek poke regs run reset`) |
| M8 | Tiny BASIC (PRINT/LET/GOTO/IF/FOR/NEXT/INPUT/LIST/RUN/NEW) |
| M9 | 6502 compiler backend (expressions, PRINT/LET/GOTO/IF/END) |
| M10 | SPI SSD1306-style OLED (pixel/line/5x7 text) |
| M11 | SPI NOR flash + SAGEFS-6502 filesystem (BASIC program persistence) |
| M12 | Standalone OS: speaker, boot menu, catalog apps, monitor interop |

The definition of done — the canonical demo:

```text
SageApple Computer
------------------

Sage6502 CPU ........ OK
Memory .............. 2048 bytes
ROM ................. OK
UART ................ OK

SageApple OS 0.1

> run hello

HELLO FROM SAGEAPPLE
RUNNING ON ATMEGA328P

>
```

## Architecture

```
                          SageLang
                             │
            ┌────────────────┴────────────────┐
            │                                 │
            ▼                                 ▼
    SageApple machine                SageLang -> 6502
    (this repo)                     compiler backend
            │                        (compiler/)
            ├── sage6502/    CPU, registers, flags
            ├── bus/         AppleBus memory map + devices
            ├── devices/     UART, SPI, display, flash, speaker
            ├── basic/       Tiny BASIC interpreter
            ├── apps/        catalog (HELLO / COUNTER / BEEP / MACHINE1)
            ├── sageapple/   OS, filesystem, graphics
            └── avr/         ATmega328P host runtime
```

### Memory / I/O map

| Range | Device |
|---|---|
| `$0000-$07FF` | 2KB RAM (writable) |
| `$2000-$2001` | UART (status/RX/TX) |
| `$2002-$2004` | SPI display controller (command/data/status+reset) |
| `$2005-$2006` | SPI flash controller (byte transfer / CS level) |
| `$2007` | PWM speaker (write frequency, 0 = silence) |
| `$8000-$FFFF` | 32KB Program ROM (read-only) |

## Quick start (host emulation)

Both the machine and its suites run directly under the SageLang interpreter
(no emulator binary needed) — from the repo root:

```sh
sage tools/avr_boot.sage        # assemble + emit build/boot.bin / boot.hex
sage tests/machine/test_os.sage # full end-to-end OS check (23 checks)
```

## Test suite

| Module | Checks |
|---|---|
| `tests/6502/test_cpu.sage` | 8 |
| `tests/6502/test_opcodes.sage` | 13 |
| `tests/compiler/test_asm6502.sage` | 11 |
| `tests/compiler/test_backend.sage` | 20 |
| `tests/boot/test_boot.sage` | 6 |
| `tests/boot/test_uart.sage` | 8 |
| `tests/boot/test_monitor.sage` | 10 |
| `tests/basic/test_basic.sage` | 17 |
| `tests/display/test_spi.sage` | 9 |
| `tests/display/test_display.sage` | 29 |
| `tests/storage/test_flash.sage` | 19 |
| `tests/storage/test_fs.sage` | 26 |
| `tests/machine/test_speaker.sage` | 12 |
| `tests/machine/test_os.sage` | 23 |
| **Total** | **211** |

Each prints its own `Results: N passed, 0 failed` footer and `ALL OK` on
success.

## Hardware (ATmega328P / Arduino UNO)

The AVR runtime is a thin C/assembler shim: it boots the ATmega328P, drives
the UART, and hosts the SageLang emulation core. See the
[``avr/README.md``](avr/README.md) workflow:

```sh
cd avr
make                                   # sageapple.hex
make flash DEVICE=/dev/ttyUSB0 BAUD=115200 PROTO=arduino   # serial loader
# or after a USBasp:
avrdude -p atmega328p -c usbasp -B 3 -U lfuse:w:0xFF:m -U hfuse:w:0xD9:m -U efuse:w:0xFF:m
```

Terminal: `screen /dev/ttyUSB0 9600` (see `avr/README.md` for defaults).

## Repository layout

```
apps/catalog.sage      # installable apps (HELLO / COUNTER / BEEP / MACHINE1)
avr/                   # AVR linker, startup, C runtime, Makefile
basic/basic.sage       # Tiny BASIC interpreter
bus/                   # applebus.sage (memory map) + bus.sage helpers
compiler/              # asm6502.sage (assembler) + backend.sage (AST -> 6502)
devices/               # uart, spi, display, flash, speaker models
sageapple/             # os.sage (console), storage.sage (SAGEFS), graphics.sage
sage6502/              # CPU core, registers, flags
tests/                 # 14 suites, 211 checks
tools/                 # hex_dump, rom_builder, avr_boot host helpers
```

## License

MIT — see [`LICENSE`](LICENSE).