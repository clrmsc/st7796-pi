#!/usr/bin/env python3
"""Convert a panel-mipi-dbi command text file into a firmware .bin.

Text format (one entry per line, '#' starts a comment):
    command 0x36 0x28     -> DCS command 0x36 with parameter 0x28
    delay 120             -> sleep 120 ms

Binary format (drivers/gpu/drm/tiny/panel-mipi-dbi.c):
    "MIPI DBI" + 7 zero bytes, version byte (1),
    then [cmd, len, params...]; a delay is cmd 0x00, len 1, ms.

Usage: mkfw.py input.txt output.bin [--madctl 0xNN] [--invert]
"""
import sys

MAGIC = b"MIPI DBI" + bytes(7)
VERSION = 1


def parse(path, madctl=None, invert=False):
    out = bytearray()
    for lineno, raw in enumerate(open(path), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        word, *args = line.split()
        vals = [int(a, 0) for a in args]
        if word == "delay":
            ms = vals[0]
            while ms > 0:
                step = min(ms, 255)
                out += bytes([0x00, 1, step])
                ms -= step
        elif word == "command":
            cmd, params = vals[0], vals[1:]
            if cmd == 0x36 and madctl is not None:
                params = [madctl]
            if cmd == 0x29 and invert:
                out += bytes([0x21, 0])
            if any(not 0 <= v <= 255 for v in vals):
                sys.exit(f"{path}:{lineno}: value out of range")
            out += bytes([cmd, len(params)] + params)
        else:
            sys.exit(f"{path}:{lineno}: unknown keyword '{word}'")
    return MAGIC + bytes([VERSION]) + out


def main():
    args = sys.argv[1:]
    madctl, invert = None, False
    if "--madctl" in args:
        i = args.index("--madctl")
        madctl = int(args[i + 1], 0)
        del args[i:i + 2]
    if "--invert" in args:
        args.remove("--invert")
        invert = True
    if len(args) != 2:
        sys.exit(__doc__)
    data = parse(args[0], madctl, invert)
    with open(args[1], "wb") as f:
        f.write(data)


if __name__ == "__main__":
    main()
