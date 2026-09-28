# Tests — `tests/`

SageApple is validated by **24 SageLang suites: 1016 checks**, each
self-contained (`Results: N passed, 0 failed` + `ALL OK` on success),
each runnable directly:

```bash
sage tests/6502/test_cpu.sage
sage tests/boot/test_monitor.sage
...
```

## The suites

| module | checks | what it proves |
|---|---|---|
| `tests/6502/test_cpu.sage` | 8 | CLI/LDA/TAX/INX/STX/ADC/STA, SBC, branch skip, flags |
| `tests/6502/test_opcodes.sage` | 21 | abs,X / abs,Y addressing, page wrap, stack, JSR/RTS, branches, IRQ/RTI, JMP ($xxFF) page-wrap, cycle-exact page-cross accounting |
| `tests/6502/test_exhaustive.sage` | 20 | ADC binary/decimal, SBC binary, branch cycle timing, page-cross penalties, JMP indirect page-wrap, IRQ/NMI B flags, PHP B flag, PLP bit 5 normalization, NMI priority |
| `tests/compiler/test_asm6502.sage` | 11 | assembler encodes real 6502, labels resolve, program runs on the host emulator |
| `tests/compiler/test_backend.sage` | 22 | compiled BASIC output equality (arithmetic, strings, GOTO/IF, comparisons, div-0) |
| `tests/boot/test_boot.sage` | 6 | power-on banner + prompt |
| `tests/boot/test_uart.sage` | 8 | UART device RX/TX/status + echo-terminal |
| `tests/boot/test_monitor.sage` | 16 | AVR monitor session |
| `tests/boot/test_apple2_boot.sage` | 38 | replacement ROM boot, vectors, serial signature, high-bit text events, live rendering, active display, keyboard echo |
| `tests/bus/test_apple2_map.sage` | 218 | Apple II RAM/ROM map, banking, slot/expansion ROMs, keyboard latch/strobe, serial bridge, text/hi-res events, canonical video state and latches |
| `tests/basic/test_basic.sage` | 49 | Applesoft arithmetic, strings, functions, control flow, errors |
| `tests/display/test_spi.sage` | 9 | SPI framing, CS, loopback, counters |
| `tests/display/test_display.sage` | 29 | OLED decode, windows, pixels/lines/text, 6502-driven |
| `tests/display/test_apple2_text.sage` | 27 | Apple II 40x24 text-page mapping, modes, validation, trimming, isolation, live reads, ANSI markers |
| `tests/display/test_apple2_lores.sage` | 26 | Apple II 40x24/80-cell lo-res mapping, bounds, all 16 colors, palette rendering, validation, holes, isolation, live reads, machine forwarding, read-only bus behavior |
| `tests/display/test_apple2_hires.sage` | 31 | Apple II 280x192 HGR mapping, low-seven-bit pixels, validation, holes, isolation, live reads, rendering, machine forwarding, canonical video state, read-only bus behavior |
| `tests/display/test_apple2_display.sage` | 114 | active page/mode dispatch, mixed text window, text/lo-res/HGR composition, widths, live reads, and read-only behavior |
| `tests/display/test_apple2_shell.sage` | 111 | host a2> screen shell, soft-switch verbs, memory/text commands, frame dimensions, read-only inspection, and repeatability |
| `tests/storage/test_flash.sage` | 21 | flash IDs, WEL, program/read, sector erase, NOR protection, 6502-driven |
| `tests/storage/test_fs.sage` | 29 | SAGEFS v2 round-trips, limits, persistence, overwrite allocation, BASIC save/load |
| `tests/machine/test_speaker.sage` | 12 | speaker model + BASIC/6502 driving |
| `tests/machine/test_os.sage` | 24 | the definition-of-done session |
| `tests/dos/test_dos.sage` | 127 | Apple II DOS 3.3 command processor: verbs, error paths, and the traps that used to mis-parse |
| `tests/machine/test_apple2.sage` | 39 | DOS 3.3 verbs, file types, monitor shell, CALL -151, buffers, EXEC, device errors |
| **Total** | **1016** | |

## How suites assert

Each test file defines a local `check(cond, msg)` (test_cpu uses manual
counters) and ends with:

```text
Results: N passed, 0 failed
ALL OK
```

Two suites (`test_os`, `test_monitor`) boot a full machine via
`sageapple/machine.sage` and compare terminal transcripts; the compiler
suites load produced binaries into the emulator and execute them; the
storage suites instantiate the 64 KB chip model and operate the full 256-block filesystem.

## The oracle / equivalence model

Beyond these checks, the strongest validation is the **host equivalence
oracle** (see [docs/avr.md](avr.md) and [docs/tools.md](tools.md)):
`tools/rom_gen.sage` records the reference session; `make host-test`
replays it byte-for-byte against the compiled C core.

## Running everything

```bash
./sagemake test
```

That is the gate for firmware work. It runs the 24 suites concurrently, builds
**both** firmware images, and runs the LED language test. Expect `all tests
passed (24 suites)`.

The suites are independent, so the run is bounded by the slowest suite rather
than by their sum — 192s wall clock against 827s run one after another. The width
is bounded by **memory**, not cores: a suite peaks around 170MB, and that bound is
what stops a run on a smaller machine being OOM-killed partway through instead of
merely being slow. Measured peak: 667MB against a 2048MB budget.

| knob | effect |
|---|---|
| `TEST_JOBS=1` | serial, in suite order — worth setting when a failure is intermittent |
| `TEST_JOBS=8` | pin the width regardless of the memory budget |
| `TEST_MEM_BUDGET_MB` | the memory ceiling (default 2048) |
| `TEST_SUITE_MB` | assumed per-suite cost (default 200) |

Reporting stays in suite order rather than completion order, so a failing run can
be read against the previous one.

A single suite is directly runnable, which is the right thing to reach for while
working on one:

```bash
sage tests/bus/test_apple2_map.sage
```

## The board tests

Host suites cannot see a single byte that actually reached an ATmega328P, so
firmware changes are checked on hardware:

```bash
cd avr
make                                  # builds both profiles
make chip-test        DEVICE=/dev/ttyUSB0   # Nano,  monitor image
make apple2-chip-test DEVICE=/dev/ttyUSB0   # Nano,  Apple II image
```

`DEVICE` is required and honoured — passing it to the verifier is the whole point,
since a test that silently ran against the wrong port is worse than no test. Both
transcripts are compared byte-for-byte, and the 496-byte bootloader at
`0x7E00-0x7FFF` is expected to survive the flash.

On this machine `/dev/ttyUSB0` is the CH340 Nano and `/dev/ttyACM0` is the
cdc_acm Uno clone. A stock Uno has only D13 safely drivable (D0/D1 belong to the
UART, ON is wired to the supply), so both run the single-LED language; see
[docs/led.md](led.md).
