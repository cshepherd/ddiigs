#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple


HEX_LINE_RE = re.compile(
    r"^\s*(?:(?P<label>[A-Za-z_][A-Za-z0-9_]*)\s+)?HEX\s+(?P<data>[0-9A-Fa-f]+)\s*$"
)
BARE_LABEL_RE = re.compile(
    r"^\s*(?P<label>[A-Za-z_][A-Za-z0-9_]*)\s*$"
)


@dataclass
class SpriteBlock:
    base_label: str
    x_label: str
    y_label: str
    x_value: int
    y_value: int
    rows: List[str]


# ----------------------------
# Utilities
# ----------------------------

def parse_le16(hex_text: str) -> int:
    raw = bytes.fromhex(hex_text)
    return int.from_bytes(raw, byteorder="little", signed=False)


def format_le16(value: int) -> str:
    return value.to_bytes(2, byteorder="little", signed=False).hex().upper()


def replace_nibble(rows: List[str], old: str, new: str) -> List[str]:
    """Replace only transparent nibbles that are connected to the sprite
    edge via other transparent nibbles (flood fill from edges).  Interior
    nibbles that happen to match the transparent color are left alone."""
    if old == new:
        return rows
    h = len(rows)
    w = len(rows[0])

    # Build mutable grid
    grid = [list(row) for row in rows]

    # Flood fill from every edge cell that matches `old`
    visited = [[False] * w for _ in range(h)]
    stack: list[tuple[int, int]] = []
    for y in range(h):
        for x in range(w):
            if y == 0 or y == h - 1 or x == 0 or x == w - 1:
                if grid[y][x] == old and not visited[y][x]:
                    stack.append((y, x))
                    visited[y][x] = True

    while stack:
        cy, cx = stack.pop()
        grid[cy][cx] = new
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w:
                if not visited[ny][nx] and grid[ny][nx] == old:
                    visited[ny][nx] = True
                    stack.append((ny, nx))

    return ["".join(row) for row in grid]


# ----------------------------
# Parsing
# ----------------------------

def parse_sprite_block(text: str) -> SpriteBlock:
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    if len(lines) < 3:
        raise ValueError("Sprite block too short")

    m0 = HEX_LINE_RE.match(lines[0])
    m1 = HEX_LINE_RE.match(lines[1])

    if not (m0 and m1):
        raise ValueError("Failed to parse Y/X header lines")

    y_label = m0.group("label")
    x_label = m1.group("label")

    if not (y_label and x_label):
        raise ValueError("Missing Y/X labels")

    y_value = parse_le16(m0.group("data"))
    x_value = parse_le16(m1.group("data"))

    # Line 3 may be "LABEL HEX data" or a bare label with data on line 4+
    m2 = HEX_LINE_RE.match(lines[2])
    if m2 and m2.group("label"):
        base_label = m2.group("label")
        rows = [m2.group("data").upper()]
        data_start = 3
    else:
        bare = BARE_LABEL_RE.match(lines[2])
        if not bare:
            raise ValueError(f"Failed to parse line 3: {lines[2]}")
        base_label = bare.group("label")
        m3 = HEX_LINE_RE.match(lines[3])
        if not m3:
            raise ValueError(f"Failed to parse first data row: {lines[3]}")
        rows = [m3.group("data").upper()]
        data_start = 4

    base = base_label
    if not y_label.startswith(base) or not x_label.startswith(base):
        raise ValueError("Label mismatch")

    for line in lines[data_start:]:
        m = HEX_LINE_RE.match(line)
        if not m:
            raise ValueError(f"Bad row: {line}")
        rows.append(m.group("data").upper())

    width = len(rows[0])
    for r in rows:
        if len(r) != width:
            raise ValueError("Row width mismatch")

    return SpriteBlock(base, x_label, y_label, x_value, y_value, rows)


# ----------------------------
# Cropping
# ----------------------------

def crop_sprite(rows: List[str], transparent: str) -> Tuple[List[str], int, int]:
    height = len(rows)
    width = len(rows[0])

    def row_blank(y):
        return all(ch == transparent for ch in rows[y])

    # Vertical trim
    top = 0
    while top < height and row_blank(top):
        top += 1

    bottom = height - 1
    while bottom >= top and row_blank(bottom):
        bottom -= 1

    if top > bottom:
        return [transparent * 2], 0, 0

    working = rows[top:bottom + 1]
    h = len(working)
    w = len(working[0])

    def col_blank(x):
        return all(working[y][x] == transparent for y in range(h))

    # Count available trims
    left_avail = 0
    while left_avail < w and col_blank(left_avail):
        left_avail += 1

    right_avail = 0
    while right_avail < w and col_blank(w - 1 - right_avail):
        right_avail += 1

    # Choose best trim (maximize total, even total, balanced)
    best_l = 0
    best_r = 0
    best_total = 0

    for l in range(left_avail + 1):
        for r in range(right_avail + 1):
            total = l + r

            if total % 2 != 0:
                continue
            if total >= w:
                continue

            better = False

            if total > best_total:
                better = True
            elif total == best_total:
                if abs(l - r) < abs(best_l - best_r):
                    better = True

            if better:
                best_total = total
                best_l = l
                best_r = r

    cropped = [row[best_l:w - best_r] for row in working]

    if not cropped or len(cropped[0]) == 0:
        cropped = [transparent * 2]

    return cropped, best_l, top


# ----------------------------
# Optimization
# ----------------------------

def optimize_block(
    text: str,
    transparent: str,
    replace_mask: Optional[str],
) -> Tuple[SpriteBlock, int, int]:
    block = parse_sprite_block(text)

    rows, left_trim, top_trim = crop_sprite(block.rows, transparent)

    if replace_mask:
        rows = replace_nibble(rows, transparent, replace_mask)

    block.rows = rows
    block.x_value = len(rows[0]) // 2
    block.y_value = len(rows)

    return block, left_trim, top_trim


# ----------------------------
# Formatting
# ----------------------------

def format_block(block: SpriteBlock) -> str:
    lines = [
        f"{block.y_label} HEX {format_le16(block.y_value)}",
        f"{block.x_label} HEX {format_le16(block.x_value)}",
        f"{block.base_label} HEX {block.rows[0]}",
    ]

    for row in block.rows[1:]:
        lines.append(f" HEX {row}")

    return "\n".join(lines)


# ----------------------------
# Main
# ----------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("-o", "--output")
    ap.add_argument("--transparent", default="4")
    ap.add_argument("--replace-mask")

    args = ap.parse_args()

    transparent = args.transparent.upper()
    if len(transparent) != 1:
        sys.exit("transparent must be 1 hex digit")

    replace_mask = args.replace_mask
    if replace_mask:
        replace_mask = replace_mask.upper()
        if len(replace_mask) != 1:
            sys.exit("replace-mask must be 1 hex digit")

    text = Path(args.input).read_text()

    block, ltrim, ttrim = optimize_block(
        text,
        transparent,
        replace_mask,
    )

    output = (
        f"; trimmed left={ltrim} top={ttrim} "
        f"new_w={len(block.rows[0])} new_h={len(block.rows)}\n"
        + format_block(block)
        + "\n"
    )

    if args.output:
        Path(args.output).write_text(output)
    else:
        print(output)


if __name__ == "__main__":
    main()
