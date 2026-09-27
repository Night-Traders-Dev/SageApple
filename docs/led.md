# SageApple — the LED language

The firmware has one LED it can drive and uses it to say three things: how far
the boot got, that it is alive and healthy, and what went wrong if something
did. Nothing here touches the serial port, so none of it disturbs the monitor
session — the transcript oracle is unaffected, and the LED keeps working when
the serial port does not.

```
./avr/led_decode.py table      the whole language
./avr/led_decode.py fault 3    what three long pulses mean
./avr/led_decode.py watch      count pulses by eye
make -C avr led-test           the patterns, checked on the host
```

## One beat is 125ms

The watchdog divides its 128kHz oscillator by 8 to give a 125ms tick, and that
tick is the beat. `#` is a beat lit, `.` a beat dark.

| shape | beats | what it means |
|---|---|---|
| short pulse | 2 lit (250ms) | a boot stage |
| long pulse | 6 lit (750ms) | a fault code |
| between pulses | 2 dark (250ms) | inside a group |
| after a group | 8 dark (1s) | group finished |

The three durations are deliberately far apart: a long pulse is three times a
short one, and the long gap is twice the short one, so the language is readable
without measuring anything.

## How many LEDs you actually have

Worth being blunt about this, because it is a hardware fact rather than a
preference:

- **A stock Nano has one LED**, on D13.
- **A stock Uno R3 has four**, but only one of them is usable. `L` is on D13;
  `TX` and `RX` are on D0 and D1, which belong to the UART and cannot be driven
  as indicators without fighting the serial port; and `ON` is wired straight to
  the supply.

So both boards run the single-LED language, which is why it is the one that
carries the full information. The multi-LED language is available for anyone who
wires extra LEDs to free pins — D2 to D6 are unused by this firmware and have no
SPI or UART function.

## One LED: boot

Each stage completing is a burst that grows by one pulse, so the longest burst
you see is the furthest the boot got.

| stage | pattern | meaning |
|---|---|---|
| POWER | `##` | MCU out of reset, reset source latched |
| UART | `##..##` | serial port configured |
| CPU | `##..##..##` | 6502 reset, vector fetched, running |
| MONITOR | `##..##..##..##` | the monitor ROM has spoken |

Then one second of dark, and the LED stays on. **A steady light means booted
and idle.** It replaced the old heartbeat, which lit once every ten seconds and
proved only that the firmware was alive.

MONITOR is observed rather than assumed: the boot code watches for the first
byte to arrive on the serial port, which is the ROM announcing itself. A boot
that reaches CPU but never sees that byte is a real failure and shows as a
three-pulse burst followed by darkness.

## One LED: faults

A fault is a group of **long** pulses, and the count is the code. The group
repeats, so the fault stays visible without anyone having to catch a window.

| pulses | code |
|---|---|
| 1 | brownout — the supply dipped below the operating floor |
| 2 | watchdog — the last reset came from the watchdog |
| 3 | external reset — the reset pin, or a power-down brownout |
| 4 | UART overrun — a byte arrived while the last was unread |
| 5 | UART framing — the line was not framed as expected |

Every one of these is something the firmware can actually observe. There is no
code for a condition it cannot detect — in particular there is no "CPU halted",
because `halted` is never set in this port, so such a code could never fire.

The first three come from `MCUSR`, latched before anything else runs, which is
the useful part: a board that rebooted on a watchdog or a brownout says so on
the next boot instead of looking like a normal one. A plain power-on is not a
fault.

## Several LEDs: the same thing as a progress bar

With `LED_COUNT` above 1, one LED per stage and the array reads directly:

| LED state | meaning |
|---|---|
| off | that stage has not been reached |
| flashing | that stage is in progress |
| solid | that stage completed |
| flashing, alone | that stage is where it failed |

A board stuck with stages 1 and 2 solid and stage 3 flashing is telling you
exactly where it died without saying a word. The multi-LED language carries
stage identity in the LEDs themselves, so the burst count is not needed.

## How this is tested

An LED that blinks is the one thing the transcript oracle cannot check, because
it never touches the serial port. So the sequencer is tested on the host instead:
`avrtest/avr/io.h` provides the port registers as ordinary memory, `led.c` is
compiled unmodified against it, and the beat is advanced by calling the watchdog
handler directly. A pattern becomes a string of `#` and `.` that can be asserted
on rather than watched for.

```
make -C avr led-test     # 31 checks
```

Two things that test caught while it was being written, both of which had been
shipping in the first draft:

- a "short" pulse ran five beats and a fault was solid on, because a pulse and a
  gap were tracked by two counters that were both live at once;
- `led_init()` never cleared the latched fault, so the first fault of the first
  boot stuck forever and every later boot reported that one.

`led_decode.py` is a second, independent implementation of the same language,
because a decoder that shares code with the thing it decodes is not a check.
The two are diffed, and the expected patterns in the host test are built from
the stage and fault *values* rather than written out beside their names — an
earlier version of that test expected one pulse for a stage that emits two, and
five for a fault whose code is four.

## Cost

18 bytes of SRAM and about 100 bytes of flash. On a part with 2KB of SRAM and
1041 bytes already in `.bss`, that leaves roughly 970 bytes for the stack.

The timing comes from the watchdog, which this firmware uses as a free-running
beat rather than as a reset watchdog. That is a deliberate trade: an 8MHz part
emulating a 1MHz 6502 has no better timer to spend, and the beat is what makes
the language possible at all. The cost is that the driver must keep servicing it
— a fault that stopped the beat would look like a watchdog reset on the next
boot — so nothing in it is allowed to block.
