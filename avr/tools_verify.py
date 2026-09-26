#!/usr/bin/env python3
"""Compare a built Intel HEX image against flash read back from a board.

    ./tools_verify.py built.hex readback.hex [--strict] [--boot-start=0x7E00]

The pass condition is that every byte the build defines is present and correct
on the chip. That is the property that actually matters for execution.

Bytes between the end of the image and the bootloader are reported separately.
Clone STK500v1 bootloaders frequently fail to erase the whole chip: a fresh
flash may still read 0x00 where it should read 0xFF, or retain fragments of a
previously larger image. That is unreachable by the reset vector, so it is a
warning rather than a failure -- pass --strict to treat it as an error when you
specifically want a clean chip. The bootloader itself is always expected to be
present and is excluded, since it must survive flashing.
"""
import sys


def load(path):
    """Return {address: byte} for every data record in an Intel HEX file."""
    mem = {}
    with open(path) as handle:
        for lineno, raw in enumerate(handle, 1):
            line = raw.strip()
            if not line or not line.startswith(":"):
                continue
            try:
                count = int(line[1:3], 16)
                addr = int(line[3:7], 16)
                rectype = int(line[7:9], 16)
            except ValueError:
                print("%s:%d: malformed record" % (path, lineno), file=sys.stderr)
                raise SystemExit(2)
            if rectype != 0:            # 01 EOF, 04 extended address, ...
                continue
            for i in range(count):
                mem[addr + i] = int(line[9 + 2 * i:11 + 2 * i], 16)
    return mem


def check_checksums(path):
    """Every record must sum to zero mod 256 across all its bytes."""
    bad = 0
    with open(path) as handle:
        for lineno, raw in enumerate(handle, 1):
            line = raw.strip()
            if not line or not line.startswith(":"):
                continue
            if sum(bytearray.fromhex(line[1:])) & 0xFF:
                print("%s:%d: bad Intel HEX checksum" % (path, lineno))
                bad += 1
    return bad


def main():
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    strict = "--strict" in flags
    boot_start = 0x7E00
    for flag in flags:
        if flag.startswith("--boot-start="):
            boot_start = int(flag.split("=", 1)[1], 0)

    if len(args) != 2:
        print(__doc__)
        return 2
    left_path, right_path = args

    for path in (left_path, right_path):
        bad = check_checksums(path)
        if bad:
            print("FAIL %s has %d bad checksum record(s)" % (path, bad))
            return 1

    built, chip = load(left_path), load(right_path)
    if not built:
        print("FAIL %s contains no data records" % left_path)
        return 1
    if not chip:
        print("FAIL %s contains no data records" % right_path)
        return 1

    image_top = max(built)
    print("built    : %d bytes, top address 0x%04X" % (len(built), image_top))
    print("readback : %d bytes, top address 0x%04X" % (len(chip), max(chip)))

    # The image itself must be present and correct.
    missing = [a for a in built if a not in chip]
    wrong = [a for a in built if a in chip and chip[a] != built[a]]
    if missing or wrong:
        print("FAIL image does not match: %d missing, %d wrong"
              % (len(missing), len(wrong)))
        for addr in (missing + wrong)[:8]:
            print("      0x%04X: built %02X, chip %s"
                  % (addr, built[addr], ("absent" if addr not in chip
                                         else "%02X" % chip[addr])))
        return 1
    print("image    : all %d bytes present and correct" % len(built))

    # The bootloader is meant to survive, so it is never "leftover".
    boot = [a for a in chip if a >= boot_start and chip[a] != 0xFF]
    if boot:
        print("boot     : %d byte(s) at 0x%04X-0x%04X (preserved, expected)"
              % (len(boot), min(boot), max(boot)))

    # Anything between the image and the bootloader is leftover.
    leftover = [a for a in chip
                if image_top < a < boot_start and chip[a] != 0xFF]
    if leftover:
        print("leftover : %d byte(s) at 0x%04X-0x%04X between the image and the"
              " bootloader" % (len(leftover), min(leftover), max(leftover)))
        print("          the bootloader did not fully erase; use"
              " `make flash-clean` to clear it")
        if strict:
            print("FAIL --strict: chip is not clean")
            return 1
        print("          unreachable from the reset vector; not a failure")
    else:
        print("leftover : none, clean between the image and the bootloader")

    print()
    print("PASS flash matches the build")
    return 0


if __name__ == "__main__":
    sys.exit(main())
