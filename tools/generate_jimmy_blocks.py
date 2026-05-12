#!/usr/bin/env python3
"""Pull Billy sprite blocks out of a Merlin source file, color-shift
them via the billy_to_jimmy nibble rule, and emit JIMMY-prefixed
versions ready to paste into the same file.

Handles both compiled-pipeline blocks (NAME_DATA, NAME_MASK,
NAME_DATA_MIRROR, NAME_MASK_MIRROR — only DATA and DATA_MIRROR get
transformed; masks are shared with Billy since transparency is
identical) and legacy single-block sprites (NAME followed by HEX lines,
$66 transparent byte preserved by the nibble rule).
"""
import re
import sys

NIBBLE_MAP = {0xA: 0xF, 0x9: 0x1}


def swap_byte(b):
    hi, lo = (b >> 4) & 0xF, b & 0xF
    hi = NIBBLE_MAP.get(hi, hi)
    lo = NIBBLE_MAP.get(lo, lo)
    return (hi << 4) | lo


HEX_RE = re.compile(r"^(\s*)HEX\s+([0-9A-Fa-f]+)(\s*.*)$")
LABEL_HEX_RE = re.compile(
    r"^([A-Z][A-Z0-9_]*)\s+HEX\s+([0-9A-Fa-f]+)(\s*.*)$")


def jimmy_name(billy):
    """Pick the Jimmy-side label for a Billy-side base name.
      IMAGE0X → JIMMY0X       (special-cased to match the walk frames
                               we already shipped)
      B<name> → J<name>        (B prefix is Billy; J is Jimmy)
      <other> → J<other>       (JUMP1 → JJUMP1, KICK1 → JKICK1, etc.)
    """
    if billy.startswith("IMAGE"):
        return "JIMMY" + billy[5:]
    if billy.startswith("B"):
        return "J" + billy[1:]
    return "J" + billy


def transform_hex_line(line):
    m = HEX_RE.match(line)
    if not m:
        return line
    indent, hex_str, trailing = m.groups()
    out = []
    for i in range(0, len(hex_str), 2):
        pair = hex_str[i:i+2]
        if len(pair) == 2:
            out.append(f"{swap_byte(int(pair, 16)):02X}")
        else:
            out.append(pair)
    return f"{indent}HEX {''.join(out)}{trailing}"


def find_block(lines, label):
    """Return (start_idx, end_idx_exclusive, first_hex_payload) of the
    block whose label is `label`. Supports two shapes:

      Multi-line: `LABEL` on its own, then `HEX ...` rows.
      Single-line: `LABEL HEX <hex>` then optional follow-up HEX rows.

    `first_hex_payload` is None for the multi-line shape, or the hex
    string from the first line for the single-line shape (caller
    re-emits it with the new label).
    """
    n = len(lines)
    for i, line in enumerate(lines):
        s = line.rstrip()
        if s == label:
            # Multi-line shape: consume subsequent HEX rows.
            end = i + 1
            while end < n and HEX_RE.match(lines[end].rstrip()):
                end += 1
            return (i, end, None)
        m = LABEL_HEX_RE.match(s)
        if m and m.group(1) == label:
            # Single-line: header has the first HEX payload.
            end = i + 1
            while end < n and HEX_RE.match(lines[end].rstrip()):
                end += 1
            return (i, end, m.group(2))
    return None


def emit_block(lines, start, end, first_hex_payload, new_label):
    out = []
    if first_hex_payload is None:
        # Multi-line: label on its own line.
        out.append(new_label)
        body_start = start + 1
    else:
        # Single-line: emit `<new_label> HEX <transformed>` for the
        # first row, then continue with the rest.
        transformed = []
        for i in range(0, len(first_hex_payload), 2):
            pair = first_hex_payload[i:i+2]
            if len(pair) == 2:
                transformed.append(f"{swap_byte(int(pair, 16)):02X}")
            else:
                transformed.append(pair)
        out.append(f"{new_label} HEX {''.join(transformed)}")
        body_start = start + 1
    for line in lines[body_start:end]:
        out.append(transform_hex_line(line.rstrip("\n")))
    return out


def main():
    if len(sys.argv) < 4:
        print("usage: generate_jimmy_blocks.py <input.s> <output.s> "
              "<billy-name> [<billy-name>...]", file=sys.stderr)
        sys.exit(2)
    src_path, out_path = sys.argv[1], sys.argv[2]
    names = sys.argv[3:]
    with open(src_path) as f:
        lines = f.readlines()

    blocks = []
    missing = []
    for name in names:
        jbase = jimmy_name(name)
        # Compiled form: NAME_DATA + NAME_MASK + NAME_DATA_MIRROR +
        # NAME_MASK_MIRROR. DATA / DATA_MIRROR get the color-shift
        # transform; MASK / MASK_MIRROR are copied byte-for-byte
        # (transparency is identical between Billy and Jimmy) so the
        # renderer's single-bank read path (sprite_bank reads both
        # DATA and MASK from the same bank) works for Jimmy too.
        d = find_block(lines, f"{name}_DATA")
        if d:
            m = find_block(lines, f"{name}_MASK")
            dm = find_block(lines, f"{name}_DATA_MIRROR")
            mm = find_block(lines, f"{name}_MASK_MIRROR")
            if not (m and dm and mm):
                missing.append(f"{name}_DATA's siblings")
                continue
            blocks.append(("compiled", name, f"{jbase}_DATA",
                           emit_block(lines, *d, f"{jbase}_DATA")))
            blocks.append(("compiled", name, f"{jbase}_MASK",
                           emit_block(lines, *m, f"{jbase}_MASK")))
            blocks.append(("compiled", name, f"{jbase}_DATA_MIRROR",
                           emit_block(lines, *dm, f"{jbase}_DATA_MIRROR")))
            blocks.append(("compiled", name, f"{jbase}_MASK_MIRROR",
                           emit_block(lines, *mm, f"{jbase}_MASK_MIRROR")))
            continue
        # Legacy form: NAME (single hex block, either multi-line or
        # single-line LABEL HEX ...)
        legacy = find_block(lines, name)
        if legacy:
            blocks.append(("legacy", name, jbase,
                           emit_block(lines, *legacy, jbase)))
            continue
        missing.append(name)

    if missing:
        print(f"warning: not found: {missing}", file=sys.stderr)

    with open(out_path, "w") as f:
        f.write("\n")
        f.write("*----------------------------------------------------------\n")
        f.write("* Jimmy color-shifted sprite blocks. Generated by\n")
        f.write("* tools/generate_jimmy_blocks.py from the Billy originals\n")
        f.write("* in this file. Same transform as IMAGE01/02/03: $A → $F,\n")
        f.write("* $9 → $1, all other nibbles (skin $2, hair $F,\n")
        f.write("* transparent $0/$6) preserved. Compiled-pipeline blocks\n")
        f.write("* share masks with their Billy counterparts (transparency\n")
        f.write("* identical), so only DATA / DATA_MIRROR are emitted.\n")
        f.write("*----------------------------------------------------------\n")
        for kind, name, label, body in blocks:
            f.write("\n")
            for line in body:
                f.write(line + "\n")


if __name__ == "__main__":
    main()
