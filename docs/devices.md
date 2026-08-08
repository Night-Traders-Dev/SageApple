# Devices — `devices/`

The five memory-mapped devices of SageApple, modeled in SageLang. All live
behind the `AppleBus` I/O window `$2000-$2007` plus the flash controller at
`$2005-$2006`.

```
devices/
├── uart.sage      UART terminal (RX FIFO + TX transcript)
├── spi.sage       bit-level SPI master with attachable slave
├── display.sage   SSD1306-style 128x64 OLED controller
├── flash.sage     SPI NOR flash chip + bus-side controller
└── speaker.sage   PWM speaker / tone generator
```

## UART (`devices/uart.sage`)

* RX: `receive(ch)` / `receive_str(s)` push bytes into an RX FIFO (the
  keyboard side).
* `status()` — bit0 = RX-ready, bit1 = TX-ready (always set), i.e. `0x02`
  normally, `0x03` when input is waiting.
* `tx_write(ch)` appends to a TX byte list; `rx_read()` pops the FIFO
  (`0x00` when empty).
* Host readback: `tx_len()`, `tx_text()` (renders the TX list, translating
  `\r`/`\n`), and a printable-ASCII filter via the module-local
  `_printable()`.

On the AVR the same port address drives the *real* MCU UART (see
[docs/avr.md](avr.md)).

## SPI master (`devices/spi.sage`)

Bit-level bit-banged master:

```
transfer8(byte)     clocks 8 bits MSB-first on MOSI, samples MISO,
                    calls slave.spi_frame(master, byte) at frame end
cs_low()/cs_high()   active-low chip select, calls slave.spi_cs(level)
```

Slave duck-typing: `spi_cs`, `spi_clk(master, bit_out)`, `spi_frame(master,
byte)`. `transfers` counts frames (assertable in tests). The AVR build
drives the SPCR/SPDR registers instead of this bit model — same protocol.

## OLED display (`devices/display.sage`)

SSD1306-style 128x64 mono controller as a SPI slave:

* 1024-byte page-major framebuffer (8 pages × 128 columns) — the
  framebuffer *lives on the controller*, never in the 6502's RAM;
* byte-level protocol decode: column low/high nibbles (`$00-$1F`)
* page set `$B0-$B7`, display on/off `$AE/$AF`, memory mode (`$20`),
  column/page windows (`$21`, `$22` with params), contrast (`$81`),
  charge pump (`$8D`), all params absorbed correctly;
* data bytes land at `fb[page*128+col]` with auto-increment and window
  wrap in non-page mode.

Default window is full 0..127 columns × 0..7 pages. `DisplaySPI` is the
bus-facing shell: `cmd()` (DC low), `dat()` (DC high), `status() == 0x80`,
`reset()` re-arms the controller.

## NOR flash (`devices/flash.sage`)

Models a 64 KB SPI NOR flash, JEDEC id `EF 40 15` (Winbond-family):

* `$06`/`$04` write-enable latch set/clear; `$05` status register
  (bit1 = WEL);
* `$03` read (3-byte address stream, then data stream);
* `$02` page program (requires WEL);
* `$20` 4K sector erase (requires WEL) — address masked to
  `addr & 0xFFF000`;
* addresses masked with `addr & (size-1)`; erased state is `0xFF`;
* `FlashSPI(gpu, chip)` is the bus controller: `byte(b)` executes a
  transfer; `csl(level)` raises/asserts CS.

## Speaker (`speaker.sage`)

* `tone(freq, duration)` — records a tone (only `freq > 0`, `0` silences
  and is not recorded);
* `silence()`, `beep()` (= `tone(1000, 100)`), `count()`, `tone_at(i)`,
  `last()`.

The AVR would drive a piezo via a TIMER; the host model keeps a transcript
that tests assert against.

## Test coverage

* `tests/display/test_spi.sage` — 9 checks (frame protocol, CS, counters).
* `tests/display/test_display.sage` — 29 checks (decode, addressing
  windows, pixels, lines, glyphs, 6502-driven `$2002/$2003` access).
* `tests/storage/test_flash.sage` — 19 checks (power-on erase, JEDEC,
  WEL/protection, page program/read, 4K erase, 6502-driven `$2005/$2006`).
* `tests/machine/test_speaker.sage` — 12 checks (device, BASIC BEEP, 6502
  `STA $2007`).