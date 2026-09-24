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

`apple2bus.sage` is isolated from the legacy `AppleBus`. It provides a 48 KiB host RAM view at `$0000-$BFFF`, a strict 12 KiB read-only ROM at `$D000-$FFFF`, Apple keyboard/speaker/video soft switches, and a `$C080/$C081` serial bridge. The keyboard path keeps a stable encoded latch at `$C000`; `$C010` reads and writes acknowledge the pending key, promote queued input in order, and clear the latch high bit when the queue is empty. String `keyboard_input()` values encode `A-Z` (case-normalized), `0-9`, space, CR, and LF; numeric and array values are already encoded keycodes and pass through unchanged. The host UART bridge remains independent of the keyboard latch. Text/lo-res and hi-res writes are recorded as ordered events rather than stored in a framebuffer.

The canonical video state is `text`, `mixed`, `page2`, and `hires`, initialized and reset to `[true, false, false, false]`. Reads and writes of `$C050-$C057` apply the corresponding soft switch; written values are ignored by the canonical state. Reads update that state while retaining the legacy address-latch return, and writes continue to update `video_switches[8]`, `video_values[8]`, and `video_events`. `video_snapshot()` returns the four canonical fields, `video_mode()` returns `text`, `lores`, or `hires`, and `video_page()` returns 1 or 2. `reset()` clears volatile state, while `clear_events()` only clears logs. `sageapple/apple2_text.sage`, `sageapple/apple2_lores.sage`, and `sageapple/apple2_hires.sage` remain explicit host-only read-only projections. The lo-res view follows the text-page interleave and maps even and odd horizontal cells to the high and low nibbles, producing 80 color cells per 40x24 row from an exact 16-entry palette. None adds active-display dispatch, a framebuffer, a RAM copy, event mutation, or bus writes. `sageapple/apple2_machine.sage` forwards the page views and video state API, and `sageapple/apple2_rom.sage` builds the replacement ROM.

The language-card model uses `$C300-$C30B` to select its two 4 KiB `$D000` banks and shared `$E000-$F7FF` RAM; ROM mode uses the loaded main ROM as a deterministic fallback. Strict 256-byte slot ROMs for slots 1-7 map through `$C100-$C7FF`, and a strict 2 KiB expansion ROM maps `$C800-$CFFF`. The reduced AVR profile mirrors the four video fields in one packed byte exposed by `bus_video_state()` while retaining the same latch arrays and write-event behavior.

The reduced AVR profile uses 1 KiB of guest RAM, a 512-byte partial language-card backing store, the banking soft switches, and ignores video-memory payloads while retaining the serial bridge. It is a compatibility slice, not a complete Apple II hardware implementation.

## Testing

`tests/boot/*` and every device test drive the bus; the OS tests
(`tests/machine/test_os.sage`) boot a full `AppleBus` system end-to-end.