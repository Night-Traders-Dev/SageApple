# Tests — `tests/`

SageApple is validated by **15 SageLang suites: 266 checks**, each
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
| `tests/6502/test_opcodes.sage` | 22 | abs,X / abs,Y addressing, page wrap, stack, JSR/RTS, branches, IRQ/RTI, JMP ($xxFF) page-wrap, cycle-exact page-cross accounting |
| `tests/compiler/test_asm6502.sage` | 11 | assembler encodes real 6502, labels resolve, program runs on the host emulator |
| `tests/compiler/test_backend.sage` | 20 | compiled BASIC output equality (arithmetic, strings, GOTO/IF, comparisons, div-0) |
| `tests/boot/test_boot.sage` | 6 | power-on banner + prompt |
| `tests/boot/test_uart.sage` | 8 | UART device RX/TX/status + echo-terminal |
| `tests/boot/test_monitor.sage` | 10 | monitor session (help/poke/peek/dump/regs/run/reset/unknown) |
| `tests/basic/test_basic.sage` | 49 | Applesoft arithmetic, strings, functions, control flow, errors |
| `tests/display/test_spi.sage` | 9 | SPI framing, CS, loopback, counters |
| `tests/display/test_display.sage` | 29 | OLED decode, windows, pixels/lines/text, 6502-driven |
| `tests/storage/test_flash.sage` | 19 | flash IDs, WEL, program/read, sector erase, 6502-driven |
| `tests/storage/test_fs.sage` | 26 | SAGEFS v2 round-trips, limits, persistence, BASIC save/load |
| `tests/machine/test_speaker.sage` | 12 | speaker model + BASIC/6502 driving |
| `tests/machine/test_os.sage` | 24 | the definition-of-done session |
| `tests/machine/test_apple2.sage` | 30 | DOS 3.3 verbs, file types, monitor shell, CALL -151 |
| **Total** | **266** | |

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