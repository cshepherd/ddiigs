#!/usr/bin/env python3
"""Split a moved block of game.s into a code-only file (for engine.s)
and a data-only file (which stays PUT-included by game.s).

Engine.s lives in bank $1F but runs with DBR=$00, so any `ds`/`dfb`/
`dw`/`hex` declarations the moved block carried along would land in
bank $1F and then be read/written via absolute mode → wrong bank, then
corruption. This script keeps those declarations in bank $00 by
shoveling them into a companion file we PUT into game.s.

Heuristic for "data line":
  - line matches `^<name>\\s+(ds|dfb|dw|hex)\\b...`
  - we DO NOT split mid-comment-block ownership; data lines move
    individually, surrounding comments stay with the code block.
"""
import re
import sys


DATA_RE = re.compile(
    r"^([a-zA-Z_][a-zA-Z0-9_]*)\s+(ds|dfb|dw|hex)\b", re.IGNORECASE)

# `=` equates and `equ` constants are also extracted into init_data.s
# so game.s sees them too — engine.s lives at $1F and resolves them via
# the PUT included extern table.
EQU_RE = re.compile(
    r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*(=|equ)\s+", re.IGNORECASE)


def split_block(src_lines):
    code = []
    data = []
    for line in src_lines:
        if DATA_RE.match(line) or EQU_RE.match(line):
            data.append(line.rstrip("\n"))
        else:
            code.append(line.rstrip("\n"))
    return code, data


def main():
    if len(sys.argv) != 4:
        print("usage: split_block.py <input.s> <code.s> <data.s>",
              file=sys.stderr)
        sys.exit(2)
    with open(sys.argv[1]) as f:
        src = f.readlines()
    code, data = split_block(src)
    with open(sys.argv[2], "w") as f:
        f.write("\n".join(code))
        f.write("\n")
    with open(sys.argv[3], "w") as f:
        f.write("*----------------------------------------------------------\n")
        f.write("* init_data.s — bank-$00 storage carved out of the init\n")
        f.write("* block that engine.s now houses. Declarations stay here\n")
        f.write("* because game.s reads these caches everywhere (renderer,\n")
        f.write("* hit detection, animations); engine.s only WRITES them\n")
        f.write("* during init.\n")
        f.write("*----------------------------------------------------------\n")
        f.write("\n".join(data))
        f.write("\n")


if __name__ == "__main__":
    main()
