#!/usr/bin/env python3
"""Compile an Apple IIgs SHR 320-mode sprite into AND/ORA pipeline form.

Each output pixel byte becomes two parallel bytes:

    inv_mask: $F nibble where the source was transparent (preserve screen),
              $0 nibble where opaque (zero screen so OR fills it).
    data:     $0 nibble where transparent (don't OR anything in),
              original color where opaque.

The renderer uses:

    LDA [scr],Y
    AND inv_mask,X
    ORA data,X
    STA [scr],Y

…so the transparency test costs zero branches in the inner loop.

Mirror variants are pre-computed (bytes reversed, nibbles swapped) so the
mirror draw path uses the same inner loop with different array pointers.

Usage:
    python3 tools/compile_sprite.py <NAME> <TRANSPARENT_NIBBLE_HEX>

Reads HEX rows from stdin (one per line, with or without `HEX ` prefix).
Writes Merlin-syntax data/mask blocks to stdout.
"""

import re
import sys


def parse_rows(text):
    rows = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(("*", ";")):
            continue
        line = re.sub(r"^(?:HEX|hex)\s+", "", line)
        hexstr = re.sub(r"\s+", "", line)
        if not re.fullmatch(r"[0-9A-Fa-f]+", hexstr):
            continue
        if len(hexstr) % 2:
            sys.exit(f"odd hex length: {raw!r}")
        rows.append(bytes.fromhex(hexstr))
    if not rows:
        sys.exit("no hex rows found on stdin")
    width = len(rows[0])
    if any(len(r) != width for r in rows):
        sys.exit("rows have inconsistent byte widths")
    return rows


def compile_pair(rows, transparent):
    """Per byte: split into data nibble (color or 0) and mask nibble (F or 0)."""
    data_rows = []
    mask_rows = []
    for row in rows:
        d = bytearray()
        m = bytearray()
        for byte in row:
            hi = (byte >> 4) & 0xF
            lo = byte & 0xF
            d_hi = 0 if hi == transparent else hi
            d_lo = 0 if lo == transparent else lo
            m_hi = 0xF if hi == transparent else 0
            m_lo = 0xF if lo == transparent else 0
            d.append((d_hi << 4) | d_lo)
            m.append((m_hi << 4) | m_lo)
        data_rows.append(bytes(d))
        mask_rows.append(bytes(m))
    return data_rows, mask_rows


def mirror_byte(byte):
    """Swap high and low nibbles."""
    return ((byte & 0x0F) << 4) | ((byte >> 4) & 0x0F)


def mirror_row(row):
    """Horizontal flip in pixel space = reverse bytes + swap each byte's nibbles."""
    return bytes(mirror_byte(b) for b in reversed(row))


def emit_block(label, rows):
    print(label)
    for r in rows:
        print(f" HEX {r.hex().upper()}")


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: compile_sprite.py <NAME> <TRANSPARENT_NIBBLE_HEX>")
    name = sys.argv[1]
    transparent = int(sys.argv[2], 16)
    if not 0 <= transparent <= 0xF:
        sys.exit(f"transparent must be a single hex nibble (0-F), got {sys.argv[2]}")

    rows = parse_rows(sys.stdin.read())
    height = len(rows)
    width_bytes = len(rows[0])

    data_rows, mask_rows = compile_pair(rows, transparent)
    mirror_src = [mirror_row(r) for r in rows]
    mdata_rows, mmask_rows = compile_pair(mirror_src, transparent)

    print(f"{name}_Y HEX {height:02X}00")
    print(f"{name}_X HEX {width_bytes:02X}00")
    print()
    emit_block(f"{name}_DATA", data_rows)
    print()
    emit_block(f"{name}_MASK", mask_rows)
    print()
    emit_block(f"{name}_DATA_MIRROR", mdata_rows)
    print()
    emit_block(f"{name}_MASK_MIRROR", mmask_rows)


if __name__ == "__main__":
    main()
