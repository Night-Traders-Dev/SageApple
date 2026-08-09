# Applications & OS — `sageapple/`, `apps/`

The OS layer: everything that turns the 6502 + bus into a usable
SageApple computer — boot, monitor, console OS, filesystem, graphics,
and the installed app catalog.

```
sageapple/
├── machine.sage    composition: AppleBus + CPU + power_on()
├── boot.sage       boot ROM builder (banner + reset vector)
├── echo.sage       UART echo ROM (host <-> 6502 proof)
├── terminal.sage   host terminal bridge
├── monitor.sage    AVR monitor ROM ($E000) + host Apple II monitor
├── os.sage         the console OS (`]`/`*` shell)
├── dos.sage        DOS 3.3 command processor (CATALOG/SAVE/LOAD/...)
├── storage.sage    SAGEFS-6502 filesystem
├── graphics.sage   5x7 font + drawing primitives
└── apps/catalog.sage   installed apps (HELLO/COUNTER/BEEP/MACHINE1)
```

## `machine.sage` — everything in one box

```text
SageApple
  ├─ bus    AppleBus (ram, UART, display, flash, storage, speaker)
  └─ cpu    CPU(bus)
power_on()          -> load boot ROM, cpu.reset(), cpu.run()
boot_rom(image)     -> load an arbitrary ROM + reset
uart_receive(s)     -> queue terminal input
console_text()      -> terminal back-buffer (tx_text)
uart_status() / tx_len() / tx_text()
```

`power_on()` is how host demos and tests start the machine.

## `boot.sage` — the boot ROM

A 32 KB image holding:

* at `$8000` — a small program: walk a string with `LDX #0;
  LDA $8040,X; STA $2001; INX`, CSE; when `0` is reached, loop forever;
* at `$8040` — the classic banner:

```text
SageApple Computer
Sage6502 CPU ... OK
OUTPUT ...
```

* reset vector `$FFFC/$FFFD = 00 80` → boot at `$8000`.

## `echo.sage` / `terminal.sage` — proof and bridge

`build_echo_rom()` is an 8-byte poll loop: `LD $2000; AND #1;
BEQ ...; LDA $2001; STA $2001; JMP ...`. `Terminal` wraps a `SageApple`
running that ROM, `feed(s)` queues input, and `pump()` steps the CPU until
stable and returns the *increment* of the TX text — the model for the
host-emulated terminal sessions in the test suite and the transcript
oracle.

## `monitor.sage` — two monitors

Two things live in this file:

**AVR monitor ROM** — written in 6502 assembly and built with `asm6502`
inside an 8 KB window, typically loaded at `$E000`:

```text
help               command list
dump aaaa bbbb      hexdump range
peek aaaa          byte at address
poke aaaa vv       write byte
regs               show P C X Y SP
run                run the user program (stub)
reset              warm restart
```

Dispatch reaches long-distance handlers with absolute `JMP` trampolines
(branch range is only ±127 bytes). The monitor's exact boot + command
session is the byte-for-byte "oracle" transcript (`tools/rom_gen.sage` →
`avr/host_expected.txt`) that the C port must reproduce (`make host-test`
and the on-board terminal).

**Host Apple II monitor** — the interactive `Monitor` class behind the
`*` prompt (entered with `CALL -151` or the `monitor` command), with
real Apple II commands:

```text
* 300.30F       forward dump           * 30F-300   backward dump
* 300:41 42     store bytes            * 300G       go
* 300J / 300C   jsr/call               * R          run reset vector
* S             step (T = trace)       * 300L       disassemble
* E             exit to BASIC          * N / I / F  display mode
```

It drives the CPU directly (steps/executes through `cpu.step()`), so
`G`/`J` run real 6502 code in RAM and `L` disassembles from the opcode
table.

## `os.sage` — the console OS

A unified `]`/`*` shell: DOS 3.3 verbs, Applesoft BASIC at the `]`
prompt, and the Apple II monitor at the `*` prompt:

```text
help                 # OS + DOS + BASIC command summary
info                 # machine summary + port map
apps                 # catalog, [I] = installed
dir                  # = CATALOG (DOS listing)
splash               # OLED: charge pump, mode, flip, offset, on, draw "SageApple"
clear                # clear the terminal (ANSI ESC[2J ESC[H)
basic                # into BASIC ("] ")
monitor              # into the 6502 monitor ("* ")
run <name>           # DOS RUN: run a saved program
exit / quit          # BYE
everything else      # DOS verbs (catalog/save/load/delete/rename/lock/
                     #   unlock/verify/mon/nomon/pr#/in#/maxfiles/init/
                     #   open/close/read/write/append/position/bload/
                     #   bsave/brun/exec/fp/int) or an Applesoft line
```

On boot the OS self-checks CPU / memory / ROM / UART / SPI display /
flash and prints `SageApple OS 0.1` before the `] ` prompt. `RUN <file>`
output from the DOS path is drained from the BASIC interpreter too, so
programs prompting for input resume correctly over the shell.

## `dos.sage` — the DOS 3.3 command processor

`dos.command(cmd)` parses a DOS verb and drives BASIC/storage:

* `CATALOG` — real DOS listing (`DISK VOLUME 254`, ` A 002 HELLO`, `*A`
  lock marker, zero-padded 3-digit sectors, sequential sector counts);
* `SAVE`/`LOAD`/`RUN`/`VERIFY` — Applesoft programs (type `A`);
* `BSAVE`/`BLOAD`/`BRUN` — binary files with `A<addr>`/`L<len>` args
  (type `B`); `RUN`/`BRUN` position the CPU and execute;
* `DELETE`/`RENAME`/`LOCK`/`UNLOCK` — directory maintenance;
* `MAXFILES n` — 1..16, else `RANGE ERROR`;
* `MON`/`NOMON`, `PR#n`/`IN#n`, `INIT` — standard DOS behaviour
  (PR#/IN# with a slot argument, `PR#0`/`IN#0` treated as one word);
* `OPEN`/`CLOSE`/`READ`/`WRITE`/`APPEND`/`POSITION`/`EXEC`/`FP`/`INT` —
  accepted and error-checked (file operations map to SAGEFS).

Errors follow DOS conventions: `FILE NOT FOUND`, `FILE TYPE MISMATCH`,
`DIRECTORY FULL` vs `DISK FULL` (an empty slot scan distinguishes them),
`RANGE ERROR`.

## `storage.sage` — SAGEFS-6502

A minimal filesystem over the SPI NOR flash:

| constant | value |
|---|---|
| block size | 256 bytes |
| directory entries | 16 (20 bytes each) |
| data blocks | 254 (block 2 .. 255) |

Layout:

- block 0 `[0..1]` magic `"SF"`, byte 2 format version `0x02`, then 16
  entries of 20 bytes: name (12 bytes NUL-padded), size (u16 LE), start
  block (u16 LE), type byte, flags byte; the directory spans block 0 plus
  16 bytes of block 1, so data begins at block 2 — ~62 KB usable.

File types follow DOS: `A` Applesoft (0x41), `B` binary (0x42), `T`
text (0x54), `I` integer (0x49); flags carry the lock bit.

API: `format()`, `save_blob(name, bytes)` (first-fit contiguous),
`load_blob(name)`, `delete(name)` (zeroes the entry), `list()`,
`size_of(name)`, `find(name)`, `name_at(i)`, `type_at(i)`,
`flags_at(i)`, `file_type(name)`, `sectors_of(name)`, `is_locked(name)`,
`lock_file(name)`, `unlock_file(name)`, `rename_file(old, new)`, plus
`save_text`/`load_text` and `save_applesoft` (CRLF-joined lines) for
BASIC workspace persistence. A full directory fails cleanly (-1).

## `graphics.sage` — drawing on the OLED

- `_FONT` — packed 5x7 bitmap font for ASCII 0x20..0x7A (91 glyphs, 5
  bits per row);
- `Gfx` over the display controller: `clear()`, `put_fb()`, `pixel/get`,
  Bresenham `line()`, `char()`, `text()` with 6-pixel advance (max 21
  chars per line at 128 px).

## `apps/catalog.sage` — the app catalog

- BASIC programs installed into SAGEFS: **HELLO**, **COUNTER** (`FOR …
  TO 3 … NEXT`), **BEEP** (2000/4000 Hz tones);
- **MACHINE1** — a *compiled* 6502 app ([compiler](compiler.md)) that
  prints `6502 APP OK` over UART and plays a 60 Hz tone — native 6502
  execution proof in the OS.

## Test coverage

| suite | checks | covers |
|---|---|---|
| `tests/boot/test_boot.sage` | 6 | boot ROM wiring |
| `tests/boot/test_uart.sage` | 8 | echo / terminal |
| `tests/boot/test_monitor.sage` | 10 | AVR monitor session |
| `tests/machine/test_os.sage` | 24 | the definition of done |
| `tests/machine/test_apple2.sage` | 33 | DOS verbs, file types, monitor shell, CALL -151, POKE/PEEK |
| `tests/machine/test_speaker.sage` | 12 | speaker from BASIC + 6502 |
| `tests/storage/*` | 45 | flash + filesystem |