#!/usr/bin/env python3
"""Hardware-in-the-loop check: the ATmega328P must reproduce the host oracle.

The 6502 monitor ROM is generated once and shared by the host emulator and the
AVR port, so a transcript of the canonical command session should come back
byte-for-byte identical from either. This drives a real board over UART and
diffs what the chip says against the recorded host transcript.

    ./chip_test.py                       # auto-detect the board
    ./chip_test.py --port /dev/ttyUSB0
    ./chip_test.py --cmds host_cmds.txt --expected host_expected.txt

Exit status is 0 only when the two transcripts match.
"""
import argparse
import difflib
import glob
import os
import sys
import time

BAUD = 9600
BANNER = "SageApple Monitor"


def find_port(explicit):
    """Return the first serial node that looks like an ATmega328P board."""
    if explicit:
        return explicit
    nodes = []
    for pattern in ("/dev/ttyUSB*", "/dev/ttyACM*"):
        nodes.extend(sorted(glob.glob(pattern)))
    if not nodes:
        return None
    if len(nodes) > 1:
        print("note: several serial nodes present (%s); using %s"
              % (", ".join(nodes), nodes[0]))
        print("      pass --port to choose explicitly")
    return nodes[0]


def boot_into_application(ser, settle):
    """Reset the board so the bootloader times out into the application.

    DTR must be released first: on the Arduino auto-reset circuit a held DTR
    keeps the STK500v1 bootloader in programming mode instead of running the
    flashed image. RTS is the line that actually drives RESET, so pulse RTS.
    """
    ser.dtr = False
    time.sleep(0.2)
    ser.rts = False
    time.sleep(0.15)
    ser.rts = True
    time.sleep(settle)


def drain(ser, seconds):
    """Collect output for a fixed window, stopping early once quiet."""
    buf = bytearray()
    end = time.time() + seconds
    while time.time() < end:
        try:
            chunk = ser.read(4096)
        except Exception:
            continue
        if chunk:
            buf += chunk
            time.sleep(0.15)
        else:
            # quiet for one poll interval: consider the current command done
            if buf and time.time() > end - seconds + 0.3:
                break
    return bytes(buf)


def normalise(data):
    """The monitor terminates lines with CRLF; the recorded oracle uses LF."""
    return data.replace(b"\r\n", b"\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--port", help="serial device (default: auto-detect)")
    ap.add_argument("--cmds", default=os.path.join(here, "host_cmds.txt"),
                    help="file of commands, one per line")
    ap.add_argument("--expected", default=os.path.join(here, "host_expected.txt"),
                    help="recorded host transcript to match")
    ap.add_argument("--settle", type=float, default=2.0,
                    help="seconds to wait for the bootloader to hand over")
    ap.add_argument("--per-command", type=float, default=0.45,
                    help="settle time after each command")
    ap.add_argument("--timeout", type=float, default=6.0,
                    help="max seconds to wait for the boot banner")
    args = ap.parse_args()

    try:
        import serial
    except ImportError:
        print("FAIL pyserial is required: pip install pyserial", file=sys.stderr)
        return 2

    port = find_port(args.port)
    if not port:
        print("FAIL no serial device found (looked for /dev/ttyUSB* and /dev/ttyACM*)",
              file=sys.stderr)
        return 2
    if not os.path.exists(port):
        print("FAIL %s does not exist" % port, file=sys.stderr)
        return 2

    for path, label in ((args.cmds, "commands"), (args.expected, "expected transcript")):
        if not os.path.exists(path):
            print("FAIL missing %s file: %s" % (label, path), file=sys.stderr)
            return 2

    commands = [l.rstrip("\n") for l in open(args.cmds) if l.strip()]
    expected = open(args.expected, "rb").read()

    print("port     : %s @ %d baud" % (port, BAUD))
    print("commands : %d" % len(commands))

    ser = serial.Serial(port, BAUD, timeout=0.2, write_timeout=2)
    try:
        boot_into_application(ser, args.settle)

        print("waiting for the boot banner ...")
        banner = bytearray()
        deadline = time.time() + args.timeout
        while time.time() < deadline and BANNER.encode() not in bytes(banner):
            try:
                banner += ser.read(4096)
            except Exception:
                pass

        if BANNER.encode() not in bytes(banner):
            print("FAIL no %r banner within %.1fs" % (BANNER, args.timeout))
            print("      got: %r" % bytes(banner))
            print("      the chip may be stuck in the bootloader, or the image is stale")
            return 1
        print("banner   : ok")

        captured = bytearray()
        for command in commands:
            # LF only: the monitor treats a bare CR as an unknown command.
            ser.write((command + "\n").encode())
            ser.flush()
            time.sleep(args.per_command)
            captured += drain(ser, 1.5)
    finally:
        ser.close()

    full = bytes(banner) + bytes(captured)
    if normalise(full) == normalise(expected):
        print()
        print("PASS chip transcript is byte-exact with the host oracle "
              "(%d bytes)" % len(expected))
        return 0

    print()
    print("FAIL chip transcript differs from the host oracle")
    print("      expected %d bytes, captured %d bytes" % (len(expected), len(full)))
    print()
    diff = difflib.unified_diff(
        normalise(expected).decode("ascii", "replace").splitlines(),
        normalise(full).decode("ascii", "replace").splitlines(),
        "host_oracle", "chip", lineterm="", n=1)
    for line in diff:
        print("      " + line)
    return 1


if __name__ == "__main__":
    sys.exit(main())
