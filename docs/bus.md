# The bus layer — `bus/`

Two modules define how the 6502 sees its memory:

```
bus/
├── bus.sage        flat 64 KB byte-array bus (generic, tests)
└── applebus.sage   the real SageApple memory map + devices
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

## Testing

`tests/boot/*` and every device test drive the bus; the OS tests
(`tests/machine/test_os.sage`) boot a full `AppleBus` system end-to-end.