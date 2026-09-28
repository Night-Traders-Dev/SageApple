# The bus layer — `bus/`

Two modules define how the 6502 sees its memory:

```
bus/
├── bus.sage          flat 64 KB byte-array bus (generic, tests)
├── applebus.sage     the real SageApple memory map + devices
└── apple2bus.sage    isolated Apple II compatibility profile
```

## `bus.sage` — the flat bus

`Bus` wraps a single 65,536-byte array:

```text
read8(addr)      masked 8-bit read
write8(a, v)     masked 8-bit write
read16(addr)     little-endian
load(image, base)  bulk-load a byte list at a base address
```

This is the minimal interface the CPU core needs. `AppleBus` (below)
subclasses the same contract with memory-mapped devices — the CPU does not
care which one it is attached to, which is what keeps the core portable to
the AVR.

## `AppleBus` — the canonical memory map

`applebus.sage` instantiates the device set and owns:

- `ram` — 2048 bytes (host) at `$0000-$07FF`
- `rom` — 32768 bytes at `$8000-$FFFF`
- a `UART()`, `DisplaySPI()`, `Flash()` chip, `FlashSPI()` controller,
  `Storage()` filesystem, `Speaker()`

read/write dispatch:

| address | read | write |
|---|---|---|
| `$0000-$07FF` | RAM | RAM (also `write_ram()`) |
| `$2000` | UART status (bit0 RX-ready, bit1 TX-ready) | — |
| `$2001` | UART RX data | UART TX data |
| `$2002` | — | display command (DC low) |
| `$2003` | — | display data (DC high) |
| `$2004` | display status (always `$80`) | display reset |
| `$2005` | flash response byte | flash byte transfer |
| `$2006` | flash CS level | flash CS level set |
| `$2007` | `$00` | speaker tone (0 = silence) |
| `$3000` | — | legacy console TX alias |
| `$8000-$FFFF` | ROM (loads via `load_rom()`) | dropped (read-only) |
| anything else | `$00` | ignored |

Convenience paths used by the host side: `read16()`, `load_rom(image)`,
`console_output()` → `uart.tx_text()`.

### Why RAM is 2 KB on host, 1 KB on the AVR

The host emulator gives the machine a full 2 KB `$0000-$07FF`. The AVR
target has only 2 KB of physical SRAM: the emulator state (registers, the C
stack, trace buffers) must share it with the 6502's own RAM, so `avr/bus.c`
maps `$0000-$03FF` (1 KB) — the monitor, BASIC workspace and current
programs fit comfortably. See [docs/avr.md](avr.md).

## `Apple2Bus` — staged Apple II profile

## Which Apple ][ this is

**The video and memory-management switches follow the original Apple ][ (1977).**
The text encoding follows the IIe. Those are not the same machine, and the
difference is load-bearing, so it is written down rather than inferred.

| subsystem | follows | evidence |
|---|---|---|
| video soft switches | original ][ | `$C054`/`$C055` are PAGE2 off/on and `$C056`/`$C057` are HIRES off/on. On a IIe those two pairs are LORES/PAGESIZE and PREWRITE/TEXTCLR |
| text encoding | IIe | `apple2_text.sage` treats `$00-$3F` as inverse and `$40-$7F` as flash. The original ][ text page is plain ASCII with bit 7 as inverse |
| main RAM | neither | 48 KiB at `$0000-$BFFF`. A ][ has 4 KiB; a IIe has 64 KiB |
| language card | 16 KiB at `$D000-$F7FF` | an add-on rather than a ][- ][ or IIc, and standard on a IIe |
| auxiliary memory | absent | there is none, so `$D000-$DFFF` can only be bank 1 |

The practical consequence: **80-column text cannot be added to this machine as it
stands.** It is a IIe feature, and reaching it means moving the video map to IIe
semantics — putting PREWRITE and TEXTCLR at `$C055`/`$C056`, which are currently
PAGE2-on and HIRES-off — plus writing the 80-column firmware ROM at `$C800`. That
changes guest-visible behaviour and the byte-exact board transcripts with it, so
it is a deliberate change of model rather than an addition.

Anything that is the same on both revisions can be added freely. The keyboard work
(arrow keys at `$08`/`$15`/`$0A`, RESET reported at `$C010` with bit 7 clear) is
such a change and touches nothing else.

### Soft switches

| range | function |
|---|---|
| `$C030` | speaker toggle |
| `$C050-$C057` | text, mixed, page 2, page 1, hi-res — original ][ order, not IIe; see above |
| `$C058-$C05B` | annunciators 0-3, read-modify-write |
| `$C061` / `$C062` / `$C063` | OPEN APPLE / CLOSED APPLE / either button |
| `$C064` / `$C065` | RTC seconds / minutes counters |
| `$C070-$C077` | paddle ports 0-7, position with the button in bit 7 |
| `$C000` / `$C010` | keyboard latch / strobe; RESET reads as `$00`, the one way to see it |
| `$C0E8` / `$C0E9` | RDROM / RDRAM — latches; no main RAM behind `$D000` to select |
| `$C0EA` / `$C0EB` | RAMRD / RAMWR — RAMWR guards the `$0200-$03FF` page |
| `$C080` / `$C081` | serial bridge |
| `$C100-$C7FF` | slot ROMs |
| `$C300-$C30B` | language card |
| `$C800+` | expansion ROM |

The annunciators and the paddle trigger are written as well as read, since a
switch that can be polled but never set is indistinguishable from absent
hardware. Paddles are a pot of 0-255 with bit 7 given over to the button, so they
rest at 64 and `paddle_input()` masks to seven bits. A paddle read returns the
position OR'd with the button while the trigger is standing, which is what lets
software sample once per frame and see a press for exactly one frame. The RTC is
derived from the host clock rather than free-running from read to read.

**Not decoded, and why.** `$C032`/`$C033` vertical blanking has no cycle-level
video timing to hang off. `$C0E0-$C0EF` 80-column text needs auxiliary memory,
and this is a 40-column machine with no aux RAM behind `$C000`. `$C0EC-$C0EF` and
a `$C600` boot ROM would be the Disk ][ controller: DOS 3.3 here is a host-side
shim over flash storage (`sageapple/dos.sage`), not a guest slot ROM talking to a
drive. Language-card banking falls back to the flat main ROM in ROM mode rather
than modelling the card's ROM/RAM select.

`apple2bus.sage` is isolated from the legacy `AppleBus`. It provides a 48 KiB host RAM view at `$0000-$BFFF`, a strict 12 KiB read-only ROM at `$D000-$FFFF`, Apple keyboard/speaker/video soft switches, and a `$C080/$C081` serial bridge. The keyboard path keeps a stable encoded latch at `$C000`; `$C010` reads and writes acknowledge the pending key, promote queued input in order, and clear the latch high bit when the queue is empty. String `keyboard_input()` values encode `A-Z` (case-normalized), `0-9`, space, CR, and LF; numeric and array values are already encoded keycodes and pass through unchanged. The host UART bridge remains independent of the keyboard latch. Text/lo-res and hi-res writes are recorded as ordered events rather than stored in a framebuffer.

The canonical video state is `text`, `mixed`, `page2`, and `hires`, initialized and reset to `[true, false, false, false]`. Reads and writes of `$C050-$C057` apply the corresponding soft switch; written values are ignored by the canonical state. Reads update that state while retaining the legacy address-latch return, and writes continue to update `video_switches[8]`, `video_values[8]`, and `video_events`. `video_snapshot()` returns the four canonical fields, `video_mode()` returns `text`, `lores`, or `hires`, and `video_page()` returns 1 or 2. `reset()` clears volatile state, while `clear_events()` only clears logs. `sageapple/apple2_text.sage`, `sageapple/apple2_lores.sage`, and `sageapple/apple2_hires.sage` remain explicit host-only read-only projections. The lo-res view follows the text-page interleave and maps even and odd horizontal cells to the high and low nibbles, producing 80 color cells per 40x24 row from an exact 16-entry palette. The HGR view maps seven contiguous pixels per byte (bits 0–6) and deliberately ignores the palette bit 7. `sageapple/apple2_display.sage` composes those views from the canonical state, selecting the active page and reserving the bottom four rows for text in mixed mode. `sageapple/apple2_shell.sage` exposes that composition through a host `a2>` REPL with state, soft-switch, memory, and key commands. None adds a framebuffer, a RAM copy, event mutation, or bus writes. `sageapple/apple2_machine.sage` forwards the page views, active display, and video state API, and `sageapple/apple2_rom.sage` builds the replacement ROM.

The language-card model uses `$C300-$C30B` to select its two 4 KiB `$D000` banks and shared `$E000-$F7FF` RAM; ROM mode uses the loaded main ROM as a deterministic fallback. Strict 256-byte slot ROMs for slots 1-7 map through `$C100-$C7FF`, and a strict 2 KiB expansion ROM maps `$C800-$CFFF`. The reduced AVR profile mirrors the four video fields in one packed byte exposed by `bus_video_state()` while retaining the same latch arrays and write-event behavior.

The reduced AVR profile uses 1 KiB of guest RAM, a 512-byte partial language-card backing store, the banking soft switches, and ignores video-memory payloads while retaining the serial bridge. It is a compatibility slice, not a complete Apple II hardware implementation.

## Testing

`tests/boot/*` and every device test drive the bus; the OS tests
(`tests/machine/test_os.sage`) boot a full `AppleBus` system end-to-end.

### Write protection

`$0200-$03FF` is write-protected at power-on, which is what a ][ does, and RAMWR
(`$C0EB`) releases it. The language card is *not* gated by RAMWR: it has its own
`$C300-$C30B` protection, and requiring both would stop a program using the card
the way every real program does. There is no main RAM behind `$D000` on this
machine, so `$C0E8`/`$C0E9` are readable and settable latches that change no
access — a property of the memory map, not a missing feature.

The `a2>` shell is a debugger, so its `poke` brackets the write: it clears RAMWR,
stores, and restores it, which is what the Monitor's own write command does. A
debugger that silently dropped writes to a protected page, or left the machine
unprotected for whatever ran next, would be wrong in both directions.
### Autostart

RESET held while any of `$C050-$C057` is written enters the autostart
monitor, whose entry the firmware publishes at `$3F4`. That is a ][ feature and
it needed three pieces, none of which existed: the switches, the vector, and the
monitor itself.

The bus cannot perform the jump -- the program counter belongs to the CPU -- so a
soft-switch write under RESET raises a flag and the CPU consumes it at the top of
`step()`, loading the PC from `$3F4` before the fetch. Checking it there rather
than after an instruction is what puts the jump between instructions, as it is on
hardware.

`$3F4` is inside the write-protected `$0200-$03FF` page, so the boot program clears
RAMWR before storing the vector. Without that the store is correctly discarded and
the entry stays zero, which is a decent argument that the protection belongs where
it is: the boot vector is not something software should scribble over by accident.

The monitor at `$FA62` sets text mode page 1, clears the 960-byte text page to
screen spaces, prints `AUTOSTART` over the serial console, and echoes typed
characters. The hardware reset vector at `$FFFA` still enters the boot program at
`$D000`; the two are deliberately different.
### The language card's ROM

A card carries its own 12 KiB ROM over `$D000-$F7FF`. Fitted and in read-ROM
mode (`$C302`/`$C303`) it shadows the firmware there; `$F800-$FFFF` is always
firmware, so the autostart monitor at `$FA62` behaves the same whether a card is
present or not. With no card fitted, `$D000` answers from the firmware, which is
a 12 KiB ROM at `$D000-$FFFF` on a real ][.

The card does not replace the firmware, it shadows it. I had that backwards first
and called the firmware fallback a fiction; eight existing tests were right to
object. The card ROM is built by `apple2_rom.sage build_card()` from its own
assembled signature program, and fitted with `load_card_rom()` -- separate from
`load_rom()` because a card is a plug-in and the firmware is soldered on.
