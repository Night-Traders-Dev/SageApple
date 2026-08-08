# SageApple

![SageApple](assets/SageApple.jpg)

An **Apple II-inspired retrocomputer** implemented primarily in **pure SageLang**, targeting an inexpensive **ATmega328P / Arduino UNO R3-compatible** board.

At its core is a reusable **Sage6502 CPU core** and a **SageLang-to-6502 compiler backend**. The machine is complete end to end: a booting 6502 with UART terminal, monitor, Tiny BASIC interpreter, SPI OLED graphics, SPI NOR flash storage with a filesystem, a PWM speaker, and a standalone OS console with application loading — all verified by an emulated test suite.

See [`PLAN.md`](PLAN.md) for the full architecture, phases, and milestones.

## Status

**Complete** — milestones 1 through 12 done, 14 test modules / 211 checks passing
(CPU, opcodes, assembler, compiler backend, boot, UART, monitor, BASIC, SPI
display, graphics, flash, filesystem, speaker, OS end-to-end).

## Test suite

Run any suite from the repo root:

```sh
sage tests/6502/test_cpu.sage
sage tests/6502/test_opcodes.sage
sage tests/compiler/test_asm6502.sage
sage tests/compiler/test_backend.sage
sage tests/boot/test_boot.sage
sage tests/boot/test_uart.sage
sage tests/boot/test_monitor.sage
sage tests/basic/test_basic.sage
sage tests/display/test_spi.sage
sage tests/display/test_display.sage
sage tests/storage/test_flash.sage
sage tests/storage/test_fs.sage
sage tests/machine/test_speaker.sage
sage tests/machine/test_os.sage
```

The definition of done — the canonical demo:

```text
SageApple Computer
------------------

Sage6502 CPU ........ OK
Memory .............. 2048 bytes
ROM ................. OK
UART ................ OK

SageApple OS 0.1

> run hello

HELLO FROM SAGEAPPLE
RUNNING ON ATMEGA328P

>
```