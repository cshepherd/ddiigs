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


def emit_blit(label, data_rows, mask_rows):
    """Emit an immediate-mode 65816 blit blob for one sprite frame.

    The blob is a JSL-callable subroutine that paints the sprite at the
    screen address held in X (16-bit). Per pixel byte (in row-major
    order, by ascending column then descending row), the cheapest
    instruction sequence is emitted:

        mask=$FF  (both nibbles transparent) → nothing
        mask=$00, data=$00 (both opaque black) → STZ off,X        (3B/5c)
        mask=$00, data!=0  (both opaque)      → LDA #d; STA off,X (5B/7c)
        partial mask                          → LDA off,X / AND #m / ORA #d / STA off,X (10B/14c)

    Between rows, X is bumped by $00A0 (one SHR scanline).

    Caller invariants on JSL entry:
      - M=8-bit, X=16-bit
      - DBR=$01 (SHR shadow bank)
      - X = $2000 + ypos*$A0 + xpos  (top-left screen byte of sprite)

    The blob clobbers A and X. On exit, M is 8-bit again, X width
    unchanged. RTL to caller.
    """
    print(label)
    # Trim trailing fully-transparent rows so we don't emit pointless
    # row tails (X += $A0) for areas the sprite never touches.
    height = len(data_rows)
    while height > 0 and all(b == 0xFF for b in mask_rows[height - 1]):
        height -= 1
    if height == 0:
        # Whole sprite is transparent — just RTL.
        print(f" HEX 6B")
        print(f"* {label}: 1 byte (fully transparent)")
        return
    bytes_emitted = 0
    for row_idx in range(height):
        drow = data_rows[row_idx]
        mrow = mask_rows[row_idx]
        for col_idx, (d, m) in enumerate(zip(drow, mrow)):
            if m == 0xFF:
                # fully transparent — emit nothing
                continue
            if m == 0x00:
                if d == 0x00:
                    # STZ abs,X  ($9E)
                    print(f" HEX 9E{col_idx:02X}00")
                    bytes_emitted += 3
                else:
                    # LDA #imm; STA abs,X
                    print(f" HEX A9{d:02X}")
                    print(f" HEX 9D{col_idx:02X}00")
                    bytes_emitted += 5
            else:
                # Partial mask. Always need LDA + AND + STA; ORA only
                # if data is non-zero (ORA #$00 is a no-op).
                print(f" HEX BD{col_idx:02X}00")
                print(f" HEX 29{m:02X}")
                if d != 0x00:
                    print(f" HEX 09{d:02X}")
                    bytes_emitted += 2
                print(f" HEX 9D{col_idx:02X}00")
                bytes_emitted += 8
        if row_idx < height - 1:
            # Row tail: X += $00A0 with M briefly 16-bit.
            # REP #$20; TXA; CLC; ADC #$00A0; TAX; SEP #$20
            print(f" HEX C220")            # REP #$20
            print(f" HEX 8A")              # TXA
            print(f" HEX 18")              # CLC
            print(f" HEX 69A000")          # ADC #$00A0
            print(f" HEX AA")              # TAX
            print(f" HEX E220")            # SEP #$20
            bytes_emitted += 10
    # RTL
    print(f" HEX 6B")
    bytes_emitted += 1
    print(f"* {label}: {bytes_emitted} bytes of compiled blit code")


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
    print()
    emit_blit(f"{name}_BLIT", data_rows, mask_rows)
    print()
    emit_blit(f"{name}_BLIT_MIRROR", mdata_rows, mmask_rows)


if __name__ == "__main__":
    main()
