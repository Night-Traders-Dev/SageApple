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
├── monitor.sage    the command monitor ROM ($E000)
├── os.sage         the console OS
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

## `monitor.sage` — the command monitor

A monitor ROM written in 6502 assembly and built with `asm6502` inside an
8 KB window, typically loaded at `$E000`:

```text
help               command list
dump aaaa bbbb      hexdump range
peek aaaa          byte at address
poke aaaa vv       write byte
regs               show P C X Y SP
run                run the user program (stub)
reset               warm restart
```

Dispatch reaches long-distance handlers with absolute `JMP` trampolines
(branch range is only ±127 bytes). The monitor's exact boot + command
session is the byte-for-byte “oracle” transcript (`tools/rom_gen.sage` →
`avr/host_expected.txt`) that the C port must reproduce (`make host-test`
and the on-board terminal).

## `os.sage` — the console OS

The standalone OS (M12) with menu:

```text
help                 # help dir apps info basic monitor run save del beep splash
dir                  # SAGEFS listing with sizes
apps                 # catalog, [I] = installed
info                 # machine summary + port map
basic                # into BASIC ("READY")
monitor              # into the 6502 monitor
run <name>           # run a saved BASIC program
run-6502             # run a compiled 6502 app (MACHINE1 <name>, alias run <name>)
save <name>          # persist current BASIC program
del <name>           # remove a program
beep                 # speaker tone
splash               # OLED: charge pump, mode, flip, offset, on, draw "SageApple"
```

On boot the OS self-checks CPU / memory / ROM / UART / SPI display /
flash and prints `SageApple OS 0.1` before the `> ` prompt.

## `storage.sage` — SAGEFS-6502

A minimal filesystem over the SPI NOR flash:

| constant | value |
|---|---|
| block size | 256 bytes |
| directory entries | 16 |
| data blocks | 254 (block 2 .. 255) |

Layout:

- block 0 `[0..1]` magic `"SF"`, byte 2 version `0x01`, then 16 entries
  of 16 bytes: name (12 bytes NUL-padded), size (u16 LE), start block
  (u16 LE); the directory spills 16 bytes into block 1, so data begins
  at block 2 — ~62 KB usable.

API: `format()`, `save_blob(name, bytes)`, `load_blob(name)`,
`delete(name)`, `list()`, `size_of(name)`, plus `save_text`/`load_text`
(CRLF-joined lines) for BASIC workspace persistence. First-fit contiguous
allocation; a full directory fails cleanly (-1).

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
| `tests/boot/test_monitor.sage` | 10 | monitor session |
| `tests/machine/test_os.sage` | 23 | the definition of done |
| `tests/machine/test_speaker.sage` | 12 | speaker from BASIC + 6502 |
| `tests/storage/*` | 45 | flash + filesystem |