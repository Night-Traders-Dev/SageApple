# The AVR port — `avr/`

The hardware milestone (M13): the same SageApple 6502 emulation, running on
a real **ATmega328P / Arduino UNO R3-compatible** board. The 6502 core is
ported to C (`avr/sage6502.c`) and driven by a tiny C/ASM runtime
(`avr/main.c`, `avr/start.S`, `avr/avr.ld`).

```
avr/
├── Makefile        build sageapple.hex, flash, fuse, host-test targets
├── avr.ld          ATmega328P linker script (32K flash / 2K SRAM / 1K EEPROM)
├── start.S         reset → stack init → .bss clear → .data copy → main()
├── main.c          UART init (9600 8N1) + emulator main loop
├── sage6502.c      C port of the 6502 core (table-driven, PROGMEM OP table)
├── bus.c           1 KB RAM + UART/ROM device window on the MCU
├── rom_avr.c        include of the generated monitor ROM (PROGMEM)
├── rom.inc          generated: const MONROM[8192] (monitor at $E000-$FFFF)
├── rom_host.c       same ROM as a plain array for -DHOST builds
├── host_main.c      host equivalence driver (replays the oracle session)
├── host_uart.c      host UART stub (stdio)
├── host_cmds.txt    the canonical session commands
└── host_expected.txt  the oracle transcript (byte-exact expected output)
```

## Hardware footprint (MCU budget)

| resource | used |
|---|---|
| flash | ~12.3 KB of 32 KB (includes 8 KB monitor ROM) |
| SRAM | 1,036 B of 2,048 B (1 KB 6502 RAM + emulator state) |
| UART | USART0, 9600 8N1, 16 MHz |
| clock | 16 MHz (external crystal, CKDIV off: lfuse `0xFF`) |

## How the machine maps to the chip

| 6502 addr | AVR mapping |
|---|---|
| `$0000-$03FF` | 1 KB `ram[]` in SRAM (see note below) |
| `$2000` | `UCSR0A` bit0 = RX-ready, bit1 = TX-ready |
| `$2001` | `UDR0` (RX read / TX write) |
| `$E000-$FFFF` | `MONROM[8192]` in flash PROGMEM (via `pgm_read_byte`) |

Everything else reads `0xFF` and ignores writes.

### SRAM budget juggling

The host model gives the machine 2 KB RAM; the 328P has 2 KB SRAM total.
The 1 KB `$0000-$03FF` mapping leaves the rest for the emulator (registers,
stacks, buffers). This is intentional (see [`docs/bus.md`](bus.md)).

## Build, flash, run

```sh
sudo apt-get install gcc-avr avr-libc binutils-avr avrdude

cd avr
make                                  # -> sageapple.elf / sageapple.hex
make flash                           # avrdude -c arduino -P /dev/ttyUSB0 -b 115200
# if the chip is fuse-locked to an external clock, use a USBasp first:
avrdude -p atmega328p -c usbasp -B 3 -U lfuse:w:0xFF:m -U hfuse:w:0xD9:m -U efuse:w:0xFF:m
```

Terminal (the monitor is 9600 8N1):

```sh
screen /dev/ttyUSB0 9600      # or picocom -b 9600 /dev/ttyUSB0
```

On the board you get the real monitor session:

```text
SageApple MonitorMON> help
Commands: help dump peek poke regs run reset
MON> regs
A=00 X=FD Y=11 SP=FD P=68
MON> peek 0000
0000: 42
...
```

## Regenerating the ROM and the opcode table

```sh
sage ../tools/rom_gen.sage       # rebuild avr/rom.inc + host_expected.txt
sage ../tools/gen_table.sage     # regenerate OP[256] in sage6502.c from the
                                 # canonical Sage _OPCODES table
```

**Why gen_table exists:** `sage6502.c` used to carry a hand-maintained
opcode table that drifted from the core. `tools/gen_table.sage` regenerates
it straight from `sage6502/cpu.sage`'s `_OPCODES`, so the C port can never
drift from the canonical core.

## The host equivalence test

```sh
make host-test
```

Builds the *same* `sage6502.c` + `bus.c` for the host (`-DHOST`), replays
the exact oracle session (`host_cmds.txt`, 60k steps per burst), and diffs
against `avr/host_expected.txt`. This is the mechanical guarantee that the
C port behaves like the SageLang machine.

## Known AVR-specific fixes (worth remembering)

1. **Stack pointer init** — `start.S` must load Z before the `.bss` clear
   loop (`st Z+` was previously writing through a zeroed Z into the
   register file/SP). Fixed.
2. **Opcode table in flash** — `static const uint16_t OP[256]` must be
   declared `PROGMEM` and read with `pgm_read_word`; a plain `ld` on AVR
   reads SRAM, not flash, silently corrupting the dispatch (the host build
   is unaffected).
3. **SRAM size** — the 2 KB RAM model physically cannot coexist with the
   emulator; use the `$0000-$03FF` model.
4. **BRK** — the core halts the machine on BRK (a documented deviation;
   the monitor's `run` reports “no user program” instead of crashing).