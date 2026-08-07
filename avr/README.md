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
`start.S` sets the stack pointer, clears `.bss`, copies `.data`, then calls
`main()`.

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

## Terminal

```sh
minicom -D /dev/ttyUSB0 -b 9600          # or screen /dev/ttyUSB0 9600
```