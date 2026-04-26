#!/usr/bin/env python3
"""Rotate an Apple IIgs SHR 320-mode sprite 90 degrees counter-clockwise.

Input is a sequence of HEX rows (the body of a `HEX ...` block in Merlin
syntax). Each byte holds two 4-bit pixels: high nibble = left pixel,
low nibble = right pixel. Rotation is lossless because nibbles map 1:1.

Usage:
    python3 tools/rotate_sprite.py <name>

Reads the sprite body from stdin (one HEX row per line, with or without
the `HEX ` prefix; whitespace/comments tolerated) and prints a Merlin
block for the rotated sprite to stdout.
"""

import sys
import re


def parse_rows(text):
    rows = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(("*", ";")):
            continue
        m = re.match(r"(?:HEX|hex)?\s*([0-9A-Fa-f]+)", line)
        if not m:
            continue
        hexstr = m.group(1)
        if len(hexstr) % 2:
            sys.exit(f"odd hex length: {raw!r}")
        rows.append(bytes.fromhex(hexstr))
    if not rows:
        sys.exit("no hex rows found on stdin")
    width = len(rows[0])
    if any(len(r) != width for r in rows):
        sys.exit("rows have inconsistent byte widths")
    return rows


def to_pixels(rows):
    """Return a 2D list pixels[y][x] where x is in pixels (0=left)."""
    grid = []
    for row in rows:
        line = []
        for byte in row:
            line.append((byte >> 4) & 0x0F)  # high nibble = left pixel
            line.append(byte & 0x0F)         # low nibble  = right pixel
        grid.append(line)
    return grid


def rotate_ccw(pixels):
    h_old = len(pixels)
    w_old = len(pixels[0])
    # new[ny][nx] = old[nx][w_old - 1 - ny]
    h_new = w_old
    w_new = h_old
    out = [[0] * w_new for _ in range(h_new)]
    for ny in range(h_new):
        for nx in range(w_new):
            out[ny][nx] = pixels[nx][w_old - 1 - ny]
    return out


def to_hex_rows(pixels):
    rows = []
    for line in pixels:
        if len(line) % 2:
            sys.exit(f"row pixel count not even: {len(line)}")
        bs = []
        for i in range(0, len(line), 2):
            bs.append((line[i] << 4) | line[i + 1])
        rows.append("".join(f"{b:02X}" for b in bs))
    return rows


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "ROTATED"
    rows = parse_rows(sys.stdin.read())
    pixels = to_pixels(rows)
    rotated = rotate_ccw(pixels)
    hex_rows = to_hex_rows(rotated)

    h_new = len(rotated)
    w_new_bytes = len(rotated[0]) // 2
    print(f"{name}_Y HEX {h_new:02X}00")
    print(f"{name}_X HEX {w_new_bytes:02X}00")
    print(name)
    for r in hex_rows:
        print(f" HEX {r}")


if __name__ == "__main__":
    main()
