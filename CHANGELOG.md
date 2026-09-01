# Changelog

## [Unreleased]

### Sage6502 CPU — Phase B/C/D refactoring and verification
- `sage6502/constants.sage` — named instruction IDs (LDA=0, …, BRK=55) and
  addressing modes (M_IMM=0, …, M_IMP=12)
- `sage6502/opcodes.sage` — declarative opcode-to-[id,mode] table (kept
  parallel to cpu.sage for tools; not imported due to scoping)
- `sage6502/cycles.sage` — 256-entry base cycle-count table
- `sage6502/decimal.sage` — pure ADC/SBC decimal helper functions
- `sage6502/cpu.sage` — refactored: imports `registers`, `flags`,
  `constants`; `_build_opcodes()` and `_load_cycles()` defined locally;
  module-level `proc _table()` shim for compatibility
- CPU fix: global `_FETCH_SCRATCH` → per-instance `self._fetch_scratch`
- CPU fix: full 256-entry cycle table (was truncated at 224)
- CPU fix: LDA/LDX/LDY indexed page-cross penalties (was missing)
- `tests/6502/test_exhaustive.sage` — 20 new verification checks:
  ADC binary/decimal, SBC binary, branch timing, page-cross penalties,
  JMP indirect page-wrap, IRQ/NMI B flags, PHP/PLP behavior, NMI priority
- 23 root-level ad-hoc scripts moved to `scratch/`
- docs updated: sage6502.md (new file structure), tests.md (16 suites,
  285 checks), README.md

### AppleCon — board controller
- `tools/applecon.sage` — host-side controller (`sage-c tools/applecon.sage`).
  v1.1: all three boards wired to the OrangePi (og Uno R3 on ttyUSB0,
  Nano R3 on ttyUSB1, 2nd Uno R3 on ttyUSB2). Opens with an artistic TUI,
  then an interactive `sage> ` shell. `con 0/1/2` connect via SSH + screen;
  stale detached screen sessions are automatically killed before connecting;
  truthful status probing; stdin isolation prevents SSH from consuming piped
  input.
- `docs/applecon.md` — new doc; `docs/tools.md`, `README.md` updated.

### Clear screen
- `basic/basic.sage` — `HOME` statement now clears the terminal (ANSI
  `ESC[2J ESC[H`), in programs and immediate mode.
- `sageapple/os.sage` — new `clear` shell command (same ANSI sequence),
  listed in `help`.
- `tests/machine/test_apple2.sage` — 3 new checks (shell clear, immediate
  HOME, HOME in a program); suite is 15 modules, 266 checks.

### Milestone 14 — Apple II software stack
- `basic/basic.sage` — full Applesoft BASIC interpreter (~2160 lines):
  floating-point arithmetic with `^` and scientific notation, string
  functions (ASC/CHR$/LEFT$/RIGHT$/MID$/LEN/STR$/VAL), numeric functions
  (INT/SQR/ABS/SGN/RND/EXP/LOG/SIN/COS/TAN/ATN/FRE/PEEK/PDL/POS/SPC/TAB),
  GOSUB/RETURN, ON GOTO/GOSUB, READ/DATA/RESTORE, DEF FN, DIM arrays,
  GET, POKE, CALL, BEEP, ONERR GOTO/RESUME, `:` statement separators,
  immediate-mode with RUN/GOTO promotion, `RUN n` form, `IF ... GOTO`
  syntax, Applesoft error messages with `IN n` line numbers. Drives the
  machine bus (POKE/PEEK/CALL); `CALL -151`/`CALL 65449` enter the monitor.
- `sageapple/dos.sage` — DOS 3.3 command processor: CATALOG (DOS
  listing with lock markers and zero-padded sector counts), SAVE/LOAD/
  RUN/VERIFY, BSAVE/BLOAD/BRUN with A<addr>/L<len>, DELETE/RENAME/LOCK/
  UNLOCK, MAXFILES (RANGE ERROR), MON/NOMON, PR#/IN# (PR#0/IN#0 handled
  as one word), INIT/OPEN/CLOSE/READ/WRITE/APPEND/POSITION/EXEC/FP/INT.
  DOS-consistent errors: FILE NOT FOUND, FILE TYPE MISMATCH, DIRECTORY
  FULL vs DISK FULL, RANGE ERROR.
- `sageapple/storage.sage` — SAGEFS v2: 20-byte directory entries with
  DOS file types (A/B/T/I) and lock flags, format version 0x02;
  `save_applesoft`, `type_at(i)`/`flags_at(i)`, 20-byte-entry delete.
- `sageapple/monitor.sage` — new host-side Apple II monitor class (`*`
  prompt): forward/backward dumps, byte stores, G/J/C go-call, run
  vector, step/trace, disassembly, display modes, `E` exit; the AVR
  monitor ROM (help/dump/peek/poke/regs/run/reset) is preserved.
- `sageapple/os.sage` — unified `]`/`*` shell: DOS verbs, Applesoft
  lines, monitor interop; RUN routing drains the BASIC interpreter so
  programs suspending at INPUT resume over the shell; `drain()`; prompt
  keeps a single CRLF; ported `run_6502_app` for BINARY apps.
- Tests: `tests/basic/test_basic.sage` (49 checks), `tests/machine/
  test_apple2.sage` (new, 30 checks), `tests/machine/test_os.sage`
  (24), `tests/storage/test_fs.sage` (26), `tools/run_os.sage` `--test`
  session (23). Full suite: 15 suites, 263 checks, all passing.
- Docs: README.md, docs/basic.md (rewritten for Applesoft), docs/os.md
  (DOS + monitor + SAGEFS v2), docs/tests.md, docs/architecture.md
  updated; test-count text refreshed everywhere.

### Fixes — post-M13 audit
- `sageapple/os.sage` — splash text typo (`SAGEAAPPLE` → `SAGEAPPLE`).
- `sageapple/monitor.sage` — removed the dead first `pad32k` definition.
- `sage6502/cpu.sage` — cycle-exact page-cross penalties: +1 for indexed
  reads (`abs,X` `abs,Y` `(zp),Y`) and +1 more for a taken branch whose
  target crosses a page; `JMP ($xxFF)` now reproduces the NMOS quirk
  (high byte read back on the same page). Mirrored in `avr/sage6502.c`.
- `sage6502/cpu.sage` — `_CYCLES` base cycle table was corrupted (rows
  `$20`/`$30`/`$40`–`$7F` garbled, 284 tokens instead of 256, e.g. `PLP`,
  `RTI`, `RTS`, `JMP abs`, `JMP ind` all wrong); rebuilt from the canonical
  NMOS timings (all 151 official opcodes verified against the 6502
  reference, unofficial opcodes stay cycle-free) and regenerated the C
  port's `CY[]` table via `tools/gen_table.sage`.
- `avr/sage6502.c` — the C port now also counts cycles and exposes
  IRQ/NMI soft latches (`cpu_interrupt()`/`cpu_nmi()`, `cpu_cycle_count()`),
  matching the Sage reference; table restructured so the PROGMEM and host
  variants are regenerated independently.
- `tools/gen_table.sage` — regenerates both the `OP[]` and the new `CY[]`
  (base cycle counts) tables, PROGMEM + host variants, so the C port
  cannot drift.
- `avr/bus.c` — `$3000` legacy console TX alias, matching `applebus.sage`.
- `tests/6502/test_opcodes.sage` — 9 new checks: JMP-indirect page-wrap and
  cycle-exact page-cross accounting (abs,X / (zp),Y / branch, crossing and
  same-page).
- `docs/sage6502.md` — fidelity notes updated to match.

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
- `devices/flash.sage` — SPI NOR flash model (64KB, JEDEC EF 40 15):
  write-enable protection, status register, page program, 4K sector
  erase, read streaming; `FlashSPI` controller on bus ports `$2005`
  (byte transfer) / `$2006` (CS level).
- `sageapple/storage.sage` — SAGEFS-6502 minimal filesystem on the
  flash: 16-entry directory (name/size/start), first-fit contiguous
  allocation, format/save/load/delete/list, text files (CRLF-joined
  lines) for BASIC program persistence.
- `bus/applebus.sage` — flash ports `$2005`/`$2006`.
- `tests/storage/test_flash.sage` — chip protocol (id, WEL, program,
  erase, read stream) plus a compiled 6502 program programming and
  reading the flash through the bus ports (19 checks).
- `tests/storage/test_fs.sage` — filesystem round-trips, directory
  limits, overwrite/delete, BASIC program save → load → RUN equality
  and persistence across a second filesystem instance (26 checks).

### Milestone 12 — Standalone SageApple
- `devices/speaker.sage` — PWM speaker model: `tone(freq, duration)`
  frequency control (0 = silence, not recorded), `beep()`, tone
  transcript/spin for testing.
- `bus/applebus.sage` — speaker port `$2007`: write frequency (0 =
  silence), read 0x00.
- `basic/basic.sage` — `BEEP [freq]` statement (default 1000 Hz) driving
  the attached speaker; PRINT `;` suppression now applies only to a
  statement-final semicolon (fixes `PRINT "COUNT "; I` dropping the
  newline).
- `apps/catalog.sage` — app catalog: BASIC programs (HELLO / COUNTER /
  BEEP) installable to the filesystem, plus the compiled 6502 demo
  (MACHINE1: UART \"6502 APP OK\" + speaker tone) built with the
  assembler.
- `sageapple/os.sage` — standalone OS: power-on banner (CPU/flash/uart/
  display checks), menu commands (`help dir apps info basic monitor
  run save del beep splash`), BASIC program editing → save → load →
  RUN persistence, 6502 application loading into RAM ($0300) with the
  ROM boot stub + reset vector, and display splash.
- `tests/machine/test_speaker.sage` — speaker device, BASIC (BEEP),
  and a compiled 6502 program driving the port (12 checks).
- `tests/machine/test_os.sage` — definition of done: power-on banner,
  monitor reachable from the OS, app installs, end-to-end RUN of the
  Hello app/counter, save/load round-trips, BEEP app, and the 6502
  MACHINE1 app over UART (23 checks).
- Full suite: 14 modules, 211 checks passing.