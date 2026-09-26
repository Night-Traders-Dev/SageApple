# SageApple — AVR toolchain & flashing workflow (Milestone 4)

The ATmega328P target is built with the standard **avr-gcc** toolchain plus an
avrdude-based flash step. The 6502 emulator itself is SageLang; the AVR RRT is a
thin C/asm runtime that boots the chip and drives the UART.

## Prerequisites (Linux / Chromebook / aarch64)

```sh
sudo apt-get install gcc-avr avr-libc binutils-avr avrdude
```

Verify: `avr-gcc --version`.

## Build

```sh
cd avr
make            # builds sageapple.elf, sageapple.hex, sageapple.lss
```

`avr.ld` defines the MCU memory layout (32KB flash, 2KB SRAM, 1KB EEPROM).
It places `.vectors` at `0x0000` so the hardware interrupt table lands on the
real vector addresses of the chip (`__vector_6` = WDT at `0x0018`), and it pulls
in `.init0` through `.init9` so the avr-libc startup runs: stack pointer,
`.bss` clear, `.data` copy, then `main()`.

Do not move `.vectors` out of `.text` and do not drop `.init9`. A missing
`.init9` means `main()` is never called; a missing `.vectors` means every
hardware interrupt jumps into application data instead of a handler.

## Generating the boot image via Sage (host toolchain)

```sh
sage ../tools/avr_boot.sage        # assembles + emits boot.hex (Intel HEX)
```

This proves the path: **SageLang -> AVR opcodes -> Intel HEX -> flash**.

## Flash (serial bootloader)

Plug the UNO into the Chromebook and find the port:

```sh
dmesg | grep tty            # or: ls /dev/ttyACM* /dev/ttyUSB*
```

```sh
cd avr
make flash DEVICE=/dev/ttyUSB0 BAUD=115200 PROTO=arduino
```

avrdude invocation used:

```sh
avrdude -p atmega328p -c arduino -P /dev/ttyUSB0 -b 115200 -U flash:w:sageapple.hex:i
```

## Fuse settings (USBasp)

```sh
avrdude -p atmega328p -c usbasp -B 3 -U lfuse:w:0xFF:m -U hfuse:w:0xD9:m -U efuse:w:0xFF:m
```

## Verifying on the board

The monitor ROM is generated once and shared by the host emulator and the AVR
port, so the same command session must come back byte-for-byte from either.
These targets make that checkable instead of assumed:

```sh
make flash                # write the image (retries the flaky clone bootloader)
make verify               # read flash back and compare to the build
make chip-test            # drive the board, diff against host_expected.txt
make flash-clean          # also erase pages the bootloader leaves behind
```

Or all four in one step from the repo root:

```sh
./sagemake chip-test
```

`make verify` reads the chip back in a *fresh* avrdude session, because the
verify built into a write session shares the same link that can drop sync
mid-transfer. It reports bytes above the image separately: clone bootloaders
often fail to erase the whole chip, and that leftover is unreachable from the
reset vector rather than a correctness problem. Pass `--strict` to
`tools_verify.py` to require a clean chip.

Clone STK500v1 bootloaders are also prone to dropping sync during a long
write. `make flash` retries the whole write-and-verify cycle
(`FLASH_RETRIES=4` by default); a single failed avrdude run is not evidence
that the write failed.

## Terminal

```sh
minicom -D /dev/ttyUSB0 -b 9600          # or screen /dev/ttyUSB0 9600
```