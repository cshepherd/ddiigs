#!/usr/bin/env python3
"""Convert Billy sprite data to Jimmy by nibble-substituting the palette.

mission1 palette mapping:
  $A  darker blue (Billy's dominant clothing color) → $F (red)
  $9  lighter blue (Billy's highlight/shine)        → $1 (white)
  everything else (skin $2, eyes $F, transparent $0, etc.) unchanged

Operates on either:
  - Raw binary bytes (one file in, one file out — for #040000 assets).
  - Merlin32-style hex blocks in a .s file (parses HEX <hex>...
    directives, rewrites label names with BILLY→JIMMY token swaps if
    --rename is given, and rewrites the hex bytes through the
    substitution table).

The mask byte $66 (Billy) and $EE (William) have no $9 / $A nibbles, so
transparency markers are preserved without a special case.
"""
import argparse
import re
import sys

# Nibble substitution table.
NIBBLE_MAP = {0xA: 0xF, 0x9: 0x1}


def swap_byte(b):
    hi, lo = (b >> 4) & 0xF, b & 0xF
    hi = NIBBLE_MAP.get(hi, hi)
    lo = NIBBLE_MAP.get(lo, lo)
    return (hi << 4) | lo


def transform_bytes(data):
    return bytes(swap_byte(b) for b in data)


HEX_LINE_RE = re.compile(r"^(\s*)HEX\s+([0-9A-Fa-f]+)(\s*.*)$")


def transform_hex_line(line):
    m = HEX_LINE_RE.match(line)
    if not m:
        return line
    indent, hex_str, trailing = m.groups()
    # Process two characters at a time (one byte) so we preserve the
    # source formatting (case, byte grouping).
    out_chars = []
    for i in range(0, len(hex_str), 2):
        pair = hex_str[i:i+2]
        if len(pair) == 2:
            b = swap_byte(int(pair, 16))
            out_chars.append(f"{b:02X}")
        else:
            out_chars.append(pair)
    return f"{indent}HEX {''.join(out_chars)}{trailing}"


def rename_labels(line, renames):
    """Rewrite identifier tokens per renames map. Used for the
    `BILLY → JIMMY` style renames on label/EQU lines."""
    if not renames:
        return line
    # Match identifier tokens; only the first-column label or the
    # operand of EQU directives should be renamed. We do a generous
    # word-boundary rewrite; comments are left alone by limiting the
    # operation to the part of the line before the first `*`.
    if line.lstrip().startswith("*"):
        return line
    head, sep, comment = line.partition(";")
    for old, new in renames.items():
        head = re.sub(rf"\b{re.escape(old)}\b", new, head)
    return head + sep + comment


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=("bytes", "hex"), required=True,
                    help="bytes = raw asset transform; hex = .s file with "
                         "HEX directives")
    ap.add_argument("--rename", action="append", default=[],
                    metavar="OLD=NEW",
                    help="In hex mode, rewrite identifier OLD as NEW. "
                         "Repeatable.")
    ap.add_argument("input")
    ap.add_argument("output")
    args = ap.parse_args()

    if args.mode == "bytes":
        with open(args.input, "rb") as f:
            data = f.read()
        with open(args.output, "wb") as f:
            f.write(transform_bytes(data))
        return

    renames = {}
    for r in args.rename:
        old, _, new = r.partition("=")
        if not old or not new:
            print(f"bad --rename value: {r!r}", file=sys.stderr)
            sys.exit(2)
        renames[old] = new

    with open(args.input) as f:
        src = f.readlines()
    out = []
    for line in src:
        line = line.rstrip("\n")
        line = transform_hex_line(line)
        line = rename_labels(line, renames)
        out.append(line)
    with open(args.output, "w") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
