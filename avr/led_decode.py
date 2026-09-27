#!/usr/bin/env python3
"""
SageApple -- read the LED language.

The LED carries a pattern rather than a message, so this is the reference for
turning what you see back into what it means. Everything here mirrors led.c; the
numbers are repeated rather than imported so a drift between the two shows up as
a wrong table rather than silently agreeing with itself.

    ./led_decode.py table          every pattern, as beats and as words
    ./led_decode.py stage UART     what one boot stage looks like
    ./led_decode.py fault 3        what three long pulses mean
    ./led_decode.py watch          a live tally, for counting by eye
"""
import sys

BEAT_MS = 125
SHORT_PULSE = 2      # beats lit
LONG_PULSE = 6       # beats lit
BETWEEN = 2          # beats dark, inside a group
GROUP_GAP = 8        # beats dark, after a group

STAGES = [
    ("POWER", "MCU out of reset, reset source latched"),
    ("UART", "serial port configured"),
    ("CPU", "6502 reset, vector fetched, running"),
    ("MONITOR", "monitor ROM has spoken on the serial port"),
]

FAULTS = [
    (0, "none", "nothing wrong"),
    (1, "brownout", "supply dipped below the operating floor"),
    (2, "watchdog", "the last reset came from the watchdog"),
    (3, "external-reset", "reset pin, or a power-down brownout"),
    (4, "uart-overrun", "a byte arrived while the last was unread"),
    (5, "uart-framing", "the line was not framed as expected"),
]


def group(count, pulse):
    """The beat string for a group of `count` pulses, trailing gap included."""
    out = []
    for i in range(count):
        if i:
            out.append("." * BETWEEN)
        out.append("#" * pulse)
    out.append("." * GROUP_GAP)
    return "".join(out)


def describe(count, pulse, repeats):
    """`repeats` is a flag, not a count: whether the group comes round again."""
    unit = "short" if pulse == SHORT_PULSE else "long"
    gap = f"{GROUP_GAP * BEAT_MS}ms"
    sep = f"{BETWEEN * BEAT_MS}ms"
    tail = ", then repeating forever" if repeats else ", then dark"
    return (f"{count} {unit} pulse{'s' if count != 1 else ''} of "
            f"{pulse * BEAT_MS}ms, {sep} apart, {gap} after{tail}")


def show(label, meaning, count, pulse, repeats):
    beats = group(count, pulse)
    print(f"  {label:<10} {meaning}")
    print(f"             {beats}")
    print(f"             {describe(count, pulse, repeats)}")
    print()


def table():
    print("SageApple LED language")
    print()
    print(f"One beat is {BEAT_MS}ms. '#' is a beat lit, '.' a beat dark.")
    print()
    print("BOOT -- one LED, no fault. A stage completing is a burst that grows by")
    print("one pulse each stage, so the longest burst you saw is the last stage")
    print("reached. The burst for the last stage is followed by darkness.")
    print()
    for i, (name, meaning) in enumerate(STAGES):
        show(name, meaning, i + 1, SHORT_PULSE, False)
    print("IDLE -- booted, healthy, waiting. The LED is simply on:")
    print(f"             {'#' * 16}  steady")
    print()
    print("FAULT -- long pulses, counted. The count is the code, and the group")
    print("repeats so the fault stays visible without catching a window.")
    print()
    for code, name, meaning in FAULTS:
        if code == 0:
            continue
        show(f"fault {code}", f"{name}: {meaning}", code, LONG_PULSE, True)


def stage(name):
    for i, (sname, meaning) in enumerate(STAGES):
        if sname.lower() == name.lower():
            print(f"{sname}: {meaning}")
            print(f"  {group(i + 1, SHORT_PULSE)}")
            print(f"  {describe(i + 1, SHORT_PULSE, False)}")
            return 0
    print(f"no stage called {name}", file=sys.stderr)
    return 1


def fault(code):
    for c, name, meaning in FAULTS:
        if c == code:
            if c == 0:
                print("0: none, nothing wrong")
                return 0
            print(f"{c}: {name} -- {meaning}")
            print(f"  {group(c, LONG_PULSE)}")
            print(f"  {describe(c, LONG_PULSE, True)}")
            return 0
    print(f"no fault code {code}", file=sys.stderr)
    return 1


def watch():
    """Tally long pulses as you count them, and name the code when you stop."""
    print("Counting long pulses. Press Enter when the group is complete.")
    n = 0
    while True:
        try:
            line = input(f"  pulses so far: {n} (Enter to finish, or type a number) > ")
        except EOFError:
            break
        line = line.strip()
        if line:
            try:
                n = int(line)
                break
            except ValueError:
                continue
        n += 1
        if n > 10:
            break
    print()
    for code, name, meaning in FAULTS:
        if code == n:
            print(f"{n} long pulses: {name} -- {meaning}")
            return 0
    print(f"{n} long pulses is not a code this firmware emits "
          f"(it has 1 to {max(c for c, _, _ in FAULTS)})")
    return 1


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help", "help"):
        print(__doc__.strip())
        return 0
    cmd = argv[1]
    if cmd == "table":
        table()
        return 0
    if cmd == "stage" and len(argv) > 2:
        return stage(argv[2])
    if cmd == "fault" and len(argv) > 2:
        try:
            return fault(int(argv[2]))
        except ValueError:
            print("fault takes a number", file=sys.stderr)
            return 1
    if cmd == "watch":
        return watch()
    print(__doc__.strip())
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
