#!/usr/bin/env python3
"""Merge two SHR sprites from a Merlin .s source into one.

Use case: TITLE6 (the bare 'II' graphic) and TITLE7 (II + blue
Japanese writing) currently get plotted alternately to flash the
writing on and off, with an inline scanline-zap loop wiping the
TITLE7 wings whenever TITLE6 is drawn. Merging them produces a
single sprite that's plotted once; the writing toggles via a
palette swap on the colour indices that appear only in the
larger sprite.

Reads two HEX-block sprites and their width/height labels from
the source file, overlays the smaller onto the larger at the
position given by their plot coordinates (smaller's pixels win
where non-zero), and emits a new HEX block ready to drop in.

Also reports which palette indices are "writing-only" (used by
the larger sprite but not the smaller) — those are the ones
your runtime code toggles to hide/show the writing.

Usage:
  tools/merge_sprites.py
  tools/merge_sprites.py --src src/title.s --small TITLE6 --big TITLE7
  tools/merge_sprites.py --small-pos 68 61 --big-pos 29 60

The defaults match the current title.s setup.
"""

import argparse
import re
import sys
from pathlib import Path


def extract_hex_block(text, label):
    """Concatenate the hex data for `label` and any directly-following
    HEX continuation lines (whitespace-prefixed). Stops at the first
    non-HEX line (typically an EQU or another label).
    Returns the concatenated uppercase hex string.
    """
    lines = text.split('\n')
    label_pat = re.compile(rf'^{re.escape(label)}\s+HEX\s+([0-9A-Fa-f]+)')
    cont_pat = re.compile(r'^\s+HEX\s+([0-9A-Fa-f]+)')

    out = []
    in_block = False
    for line in lines:
        # Strip any inline comment so it doesn't pollute the hex
        clean = line.split(';', 1)[0]
        if not in_block:
            m = label_pat.match(clean)
            if m:
                out.append(m.group(1).upper())
                in_block = True
            continue
        # In block: keep collecting indented HEX lines
        m = cont_pat.match(clean)
        if m:
            out.append(m.group(1).upper())
            continue
        # Anything else terminates the block
        break

    if not out:
        raise ValueError(f"Label {label} not found in source")
    return ''.join(out)


def extract_word(text, label):
    """Find a `LABEL HEX XXYY` line and return the little-endian word."""
    m = re.search(rf'^{re.escape(label)}\s+HEX\s+([0-9A-Fa-f]+)',
                  text, re.MULTILINE)
    if not m:
        raise ValueError(f"{label} not found in source")
    h = m.group(1).upper()
    if len(h) < 4:
        return int(h, 16)
    return int(h[0:2], 16) | (int(h[2:4], 16) << 8)


def hex_to_pixels(hex_str, width_bytes, height):
    """Decode hex nibble stream into a 2D pixel array.
    width_bytes is the row width in bytes; each byte = 2 pixels.
    """
    width_pixels = width_bytes * 2
    expected = width_pixels * height
    if len(hex_str) != expected:
        print(f"warning: data length {len(hex_str)} != expected "
              f"{expected} (width_pixels={width_pixels} height={height})",
              file=sys.stderr)
    pixels = []
    for y in range(height):
        row = []
        for x in range(width_pixels):
            idx = y * width_pixels + x
            row.append(int(hex_str[idx], 16) if idx < len(hex_str) else 0)
        pixels.append(row)
    return pixels


def overlay(big, small, offset_x_pixels, offset_y_lines):
    """Return a copy of `big` with `small` filling its transparent
    (zero) pixels at the given offset. `big` wins everywhere it has
    a non-zero pixel — this is what we want for TITLE6/TITLE7, where
    TITLE7 already has the writing painted on top of the II body
    and TITLE6 just contributes any II pixels outside TITLE7's
    footprint. Anything outside `big`'s bounds is silently dropped.
    """
    out = [row[:] for row in big]
    h_big = len(out)
    w_big = len(out[0]) if out else 0
    for y, row in enumerate(small):
        ty = y + offset_y_lines
        if ty < 0 or ty >= h_big:
            continue
        for x, px in enumerate(row):
            if px == 0:
                continue
            tx = x + offset_x_pixels
            if 0 <= tx < w_big and out[ty][tx] == 0:
                out[ty][tx] = px
    return out


def remap_writing(big, small, offset_x_pixels, offset_y_lines,
                   palette, free_indices):
    """Build a remapped sprite where any pixel that differs between
    big (TITLE7, writing-on) and small (TITLE6, writing-off) is
    assigned a new palette index from `free_indices`. The new index
    encodes the (writing-on color, writing-off color) pair so the
    writing can be hidden completely just by re-pointing those
    palette slots at the underlying II colour (or 0 for pixels that
    extend past the II body).

    `palette` is a list of 16 16-bit IIgs colour words.
    Returns: (pixels, remap)
      pixels: 2D array of palette indices (sprite-shaped)
      remap:  list of (idx, on_color, off_color) tuples, in
              allocation order (smallest free index first).
    """
    h_big = len(big)
    w_big = len(big[0]) if big else 0
    h_small = len(small)
    w_small = len(small[0]) if small else 0

    # Pass 1: collect every pair we'd need and how many pixels each
    # covers, so we can allocate indices to the most common pairs and
    # spill the rare ones onto existing allocations.
    pair_counts = {}
    for ty in range(h_big):
        for tx in range(w_big):
            W = big[ty][tx]
            sy = ty - offset_y_lines
            sx = tx - offset_x_pixels
            B = 0
            if 0 <= sy < h_small and 0 <= sx < w_small:
                B = small[sy][sx]
            if W == B or W == 0:
                continue
            pair_counts[(W, B)] = pair_counts.get((W, B), 0) + 1

    # Allocate the most common pairs first.
    sorted_pairs = sorted(pair_counts.items(), key=lambda kv: -kv[1])
    free = list(free_indices)
    pair_to_idx = {}
    remap = []
    for (W, B), _n in sorted_pairs:
        if not free:
            break
        idx = free.pop(0)
        pair_to_idx[(W, B)] = idx

    # Spill the remaining pairs onto an existing index that matches
    # their off-colour (B). This keeps the writing-off state pixel-
    # exact; only the writing-on colour for those pixels shifts to
    # whichever W was already allocated for the same B.
    for (W, B), _n in sorted_pairs:
        if (W, B) in pair_to_idx:
            continue
        # Pick the allocated pair with the most pixels among those
        # that share this B. Falls through to None if nothing matches.
        candidates = [
            (Wp, Bp) for (Wp, Bp) in pair_to_idx
            if Bp == B]
        if not candidates:
            raise ValueError(
                f"no allocation with B=${B:X} to spill (W=${W:X},B=${B:X}) onto")
        # Prefer the candidate with the highest pixel count.
        candidates.sort(key=lambda k: -pair_counts[k])
        pair_to_idx[(W, B)] = pair_to_idx[candidates[0]]

    # Build the remap report (only the "real" pair per allocated idx).
    seen_idx = set()
    for (W, B), _n in sorted_pairs:
        idx = pair_to_idx[(W, B)]
        if idx in seen_idx:
            continue
        seen_idx.add(idx)
        on_color = palette[W]
        off_color = palette[B] if B != 0 else 0
        remap.append((idx, on_color, off_color, W, B,
                      pair_counts[(W, B)]))

    out = [row[:] for row in big]

    for ty in range(h_big):
        for tx in range(w_big):
            W = big[ty][tx]
            sy = ty - offset_y_lines
            sx = tx - offset_x_pixels
            B = 0
            if 0 <= sy < h_small and 0 <= sx < w_small:
                B = small[sy][sx]

            if W == B:
                continue
            if W == 0 and B != 0:
                out[ty][tx] = B
                continue
            out[ty][tx] = pair_to_idx[(W, B)]

    return out, remap


def extract_palette(text, label='PALETTE', count=16):
    """Read 16 little-endian 16-bit words from a Merlin HEX block
    starting at `label`. Returns a list of 16 ints."""
    lines = text.split('\n')
    label_pat = re.compile(rf'^{re.escape(label)}\s*(?:HEX\s+([0-9A-Fa-f]+))?')
    cont_pat = re.compile(r'^\s+HEX\s+([0-9A-Fa-f]+)')
    out = []
    in_block = False
    for line in lines:
        clean = line.split(';', 1)[0]
        if not in_block:
            m = label_pat.match(clean)
            if m:
                if m.group(1):
                    out.append(m.group(1).upper())
                in_block = True
            continue
        m = cont_pat.match(clean)
        if m:
            out.append(m.group(1).upper())
            continue
        break
    s = ''.join(out)
    if len(s) < count * 4:
        raise ValueError(f"palette block too short: {len(s)} chars")
    words = []
    for i in range(count):
        lo = int(s[i*4:i*4+2], 16)
        hi = int(s[i*4+2:i*4+4], 16)
        words.append(lo | (hi << 8))
    return words


def pixels_to_hex(pixels):
    return ''.join('{:X}'.format(px) for row in pixels for px in row)


def palette_difference(small, big):
    """Colours present in `big` but not `small` (writing-only)."""
    sc = {px for row in small for px in row}
    bc = {px for row in big for px in row}
    return bc - sc


def emit_hex_block(label, hex_str, width_bytes, line_chars=64):
    """Format the hex stream as Merlin HEX statements. The first line
    has `LABEL HEX <data>`; subsequent lines start with a single space
    and continue with HEX. Lines wrap at `line_chars` chars (default 64),
    matching the style already in title.s for wide sprites.
    """
    parts = []
    for i in range(0, len(hex_str), line_chars):
        chunk = hex_str[i:i + line_chars]
        if i == 0:
            parts.append(f'{label} HEX {chunk}')
        else:
            parts.append(f' HEX {chunk}')
    return '\n'.join(parts)


def word_le_hex(value):
    """Format a 16-bit value as 4 hex chars little-endian (low first)."""
    return f'{value & 0xFF:02X}{(value >> 8) & 0xFF:02X}'


def main():
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--src', default='src/title.s',
                    help='source file containing the sprites')
    ap.add_argument('--small', default='TITLE6',
                    help='label of the smaller sprite (overlaid on top)')
    ap.add_argument('--big', default='TITLE7',
                    help='label of the larger sprite (the merge canvas)')
    ap.add_argument('--small-pos', type=int, nargs=2, metavar=('X', 'Y'),
                    default=[68, 61],
                    help='plot byte-position of the small sprite (default '
                         '68 61, matching writing_off in title.s)')
    ap.add_argument('--big-pos', type=int, nargs=2, metavar=('X', 'Y'),
                    default=[29, 60],
                    help='plot byte-position of the big sprite (default '
                         '29 60, matching writing_on in title.s)')
    ap.add_argument('--out-label', default='TITLE_MERGED',
                    help='label name for the emitted merged sprite')
    args = ap.parse_args()

    src_path = Path(args.src)
    text = src_path.read_text()

    small_hex = extract_hex_block(text, args.small)
    big_hex = extract_hex_block(text, args.big)
    small_w = extract_word(text, f'{args.small}_X')
    small_h = extract_word(text, f'{args.small}_Y')
    big_w = extract_word(text, f'{args.big}_X')
    big_h = extract_word(text, f'{args.big}_Y')

    print(f'; {args.small}: {small_w} bytes wide x {small_h} lines tall '
          f'({len(small_hex)} nibbles)', file=sys.stderr)
    print(f'; {args.big}:   {big_w} bytes wide x {big_h} lines tall '
          f'({len(big_hex)} nibbles)', file=sys.stderr)

    small_pixels = hex_to_pixels(small_hex, small_w, small_h)
    big_pixels = hex_to_pixels(big_hex, big_w, big_h)

    off_x_bytes = args.small_pos[0] - args.big_pos[0]
    off_y_lines = args.small_pos[1] - args.big_pos[1]
    off_x_pixels = off_x_bytes * 2
    print(f'; offset of {args.small} within {args.big}: '
          f'{off_x_bytes} bytes ({off_x_pixels} pixels) right, '
          f'{off_y_lines} lines down', file=sys.stderr)

    palette = extract_palette(text)
    # Free palette indices in title.s: $1-$5 are 0000 in the source
    # palette and unused by any sprite. $C-$E are reserved by the
    # palette but unused by sprites. $9, $A are used by REVENGE.
    # $B, $F are used by TITLE1. So: 1..5, C..E are safe targets.
    free_indices = [0x1, 0x2, 0x3, 0x4, 0x5, 0xC, 0xD, 0xE]

    merged, remap = remap_writing(
        big_pixels, small_pixels,
        off_x_pixels, off_y_lines,
        palette, free_indices)

    merged_hex = pixels_to_hex(merged)
    block = emit_hex_block(args.out_label, merged_hex, big_w)

    print(f'; Merged sprite — plot once at ({args.big_pos[0]}, '
          f'{args.big_pos[1]}). Writing visibility toggles via the')
    print(f'; palette entries listed below — the merged sprite stores')
    print(f'; a per-pixel "writing-or-underlying-II" palette index so')
    print(f'; the off-state reveals exactly the II colour underneath.')
    print(f';')
    print(f'; Pairs allocated (palette index : on-colour / off-colour):')
    for idx, on_c, off_c, W, B, n in remap:
        print(f';   ${idx:X} : ${on_c:04X} / ${off_c:04X}  '
              f'(W=${W:X}, B=${B:X})  {n} px')
    print(f';')
    print(f'{args.out_label}_Y HEX {word_le_hex(big_h)}')
    print(f'{args.out_label}_X HEX {word_le_hex(big_w)}')
    print(block)
    print(f'{args.out_label}LEN EQU *-{args.out_label}')
    print()
    print(f'; --- writing_on / writing_off palette tweaks ---')
    print(f'; Initial PALETTE table should hold the WRITING-ON values for')
    print(f'; these indices so the merged sprite renders correctly the')
    print(f'; first time it is plotted.')
    print(f';')
    for idx, on_c, off_c, W, B, n in remap:
        addr = 0xE19E00 + idx * 2
        print(f';   palette[${idx:X}] @ ${addr:06X}: '
              f'on=${on_c:04X}  off=${off_c:04X}')


if __name__ == '__main__':
    main()
