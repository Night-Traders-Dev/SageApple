# Tests — `tests/`

SageApple is validated by **23 SageLang suites: 817 checks**, each
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
| `tests/boot/test_monitor.sage` | 10 | AVR monitor session |
| `tests/boot/test_apple2_boot.sage` | 26 | replacement ROM boot, vectors, serial signature, high-bit text events, live rendering, active display, keyboard echo |
| `tests/bus/test_apple2_map.sage` | 164 | Apple II RAM/ROM map, banking, slot/expansion ROMs, keyboard latch/strobe, serial bridge, text/hi-res events, canonical video state and latches |
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
| `tests/machine/test_apple2.sage` | 39 | DOS 3.3 verbs, file types, monitor shell, CALL -151, buffers, EXEC, device errors |
| **Total** | **817** | |

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

```
for t in tests/*/*.sage; do sage $t; done
```

Nothing needs an emulator binary or the board: the machine itself runs in
the interpreter.