# Changelog

## [Unreleased]

### Milestone 1 — Repository
- Repository scaffold created.
- PLAN.md, README.md, LICENSE added.

### Milestone 2 — Sage6502 CPU core
- `sage6502/registers.sage` — A/X/Y/PC/SP registers.
- `sage6502/flags.sage` — processor status (NV-BDIZC) with byte get/set.
- `sage6502/cpu.sage` — table-driven NMOS 6502 interpreter: full canonical
  opcode table, all addressing modes, load/store, transfers, stack,
  ADC/SBC, logical, compare, inc/dec, shifts/rotates, branches,
  JMP/JSR/RTS, BRK/RTI/NOP, and flag instructions. Reset vector + stack.

### Milestone 4 — Memory Bus
- `bus/bus.sage` — 64 KB virtual byte-array bus with read8/write8/read16/load.

### Milestone 3 — 6502 Validation
- `tests/6502/test_cpu.sage` — smoke suite (8 asserts): loads, STX/STY,
  ADC (carry clear), SBC + branch, stack, and flags.

### Milestone 2 — Sage6502 CPU core (complete)
- IRQ (`$FFFE`) and NMI (`$FFFA`) servicing between instructions.
- Canonical base cycle counts + branch-taken penalty; IRQ/NMI service charge.
- `interrupt()` / `nmi()` soft latches matching the plan's CPU API.

### Milestone 3 — 6502 Validation (complete)
- `tests/6502/test_opcodes.sage` — addressing modes (abs,X / abs,Y, zero page,X
  wraparound), stack push/pull, JSR/RTS round-trip, BEQ/BNE taken paths, and
  IRQ service + RTI return. 13 checks.
- `tests/6502/test_cpu.sage` — smoke suite. 8 checks.
- Combined suite: 21/21 passing.

### Milestone 4 — AVR Target
- `avr/avr.ld` — ATmega328P memory layout (32KB flash / 2KB SRAM / 1KB EEPROM).
- `avr/start.S` — stack init, `.bss` clear, `.data` copy, jump to `main()`.
- `avr/main.c` — AVR runtime: UART init + banner (M5-7 wire the emulator in).
- `avr/Makefile` + `avr/README.md` — avr-gcc build + avrdude flashing workflow.
- `tools/avr_boot.sage` — Sage -> AVR opcodes -> Intel HEX for a UART boot;
  writes `build/boot.hex`.
- `tools/hex_dump.sage`, `tools/rom_builder.sage` — plan tools.

### Milestone 5 — SageApple Boot
- `bus/applebus.sage` — memory map bus: 2KB RAM, 32KB ROM ($8000), I/O console
  TX at $3000 (PLAN.md §11).
- `sageapple/boot.sage` — 6502 boot ROM emitting the banner then looping.
- `sageapple/machine.sage` — Apple machine composition + `power_on()`.
- `tests/boot/test_boot.sage` — banner/prompt boot check (6 checks).

### Milestone 6 — UART Device & Terminal
- `devices/uart.sage` — 6502 UART device ($2000 status, $2001 RX/TX) with
  RX FIFO and TX read-back for the host terminal.
- `bus/applebus.sage` — hosts the UART device in the $2000-$2001 I/O window.
- `sageapple/echo.sage` — 6502 echo-terminal ROM (poll status, echo RX->TX).
- `sageapple/terminal.sage` — host terminal bridging scripted input via the
  device UART and reading back the 6502's transmitted text.
- `sage6502/cpu.sage` — store ops no longer emit a dummy read (an RX I/O
  port must not be consumed by `STA`).
- Banner now transmitted over the real UART path ($2001).
- `tests/boot/test_uart.sage` — device + 6502 echo checks (8 checks).

### Milestone 7 — 6502 Monitor (partial)
- `compiler/asm6502.sage` — two-pass 6502 assembler: opcode table (full NMOS
  set), `.org`/`.byte`, labels with cross-instruction resolution, `#<`/`#>`
  low/high immediates, REL branch offsets, and proper accumulator (`LSR A`)
  encoding.
- `sageapple/monitor.sage` — 6502 command monitor ROM: `help`, `dump`,
  `peek`, `poke`, `regs`, `run`, `reset` over UART. Long dispatch reaches
  its handlers via absolute `JMP` trampolines (beyond ±127-byte branches).
- `tests/compiler/test_asm6502.sage` — assembler encoding + emulator
  execution checks (11 checks).
- `tests/boot/test_monitor.sage` — full monitor ROM pass (10 checks).

### Milestone 8 — BASIC
- `basic/basic.sage` — native Tiny BASIC interpreter: tokenizer, integer
  expression evaluator (precedence, parens, unary minus), comparisons,
  PRINT/LET/GOTO/IF-THEN/FOR-NEXT-STEP/INPUT/LIST/RUN/NEW/END/REM,
  single-letter variables, numbered program store with replace + sorted
  insert. Input via `feed(ch)`; scripted INPUT via an input queue.
- `tests/basic/test_basic.sage` — immediate PRINT, variables, loops,
  conditionals, STEP, INPUT, LIST/NEW checks (17 checks).

### Milestone 9 — 6502 Compiler Backend
- `compiler/backend.sage` — lowers M8 BASIC to standalone 6502 machine
  code: AST parsing (numbers, variables A-Z, `+ - * / ( )`, unary minus,
  relational conditions), instruction selection with value in A, register
  allocation onto zero page (variables $20-$3E, temps $7C/$7E), statements
  compiled to 6502: PRINT (expr/string/blank with `;`), LET, GOTO,
  IF/THEN/GOTO, END.  Runtime appended: UART output, decimal printing,
  string printing, 8x8 multiply, 8-bit divide.
- `compiler/asm6502.sage` — used as assembler+linker for the emitted source
  (labels resolve across user code and runtime), yielding a binary image
  loadable into RAM.
- `tests/compiler/test_backend.sage` — compiles BASIC, loads the image at
  $0300 behind a reset-boot stub, runs on the emulator, checks UART output
  (20 checks).

### Milestone 10 — Graphics
- `devices/spi.sage` — bit-level SPI master driver (SCK per bit, MOSI/MISO,
  CS framing) with an attachable slave protocol (spi_cs/spi_clk/spi_frame).
- `devices/display.sage` — SSD1306-style 128x64 monochrome OLED controller:
  framebuffer lives on the controller (1024 bytes), byte-level protocol
  decode of column/page/display-on commands, parameter commands, and
  addressing windows.
- `sageapple/graphics.sage` — Video API: pixel / Bresenham line / 5x7
  glyphs / text rendering on top of the SPI display.
- `bus/applebus.sage` — display ports: `$2002` command (DC low), `$2003`
  data (DC high), `$2004` read status / write reset.
- `tests/display/test_spi.sage` — SPI loopback, framing, CS, counters
  (9 checks).
- `tests/display/test_display.sage` — protocol decode, addressing windows,
  pixel/line/text rendering, plus a compiled 6502 program driving the
  display through the bus ports (29 checks).

### Milestone 11 — Storage