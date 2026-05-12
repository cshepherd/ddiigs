#!/usr/bin/env python3
"""Transform a block of game.s code so it can run from bank $1F.

Same playbook as build_engine_s.py but parameterised — different
migrations rename different entry points and call back into different
bank-$00 helpers. Reads `<block>.txt` (a config file) to know what to
do, then emits the transformed source on stdout (or to the given output
path).

Config file format (key=value, one per line; lists are comma-separated):

    entries: scroll_right, scroll_left, scroll_up
    rts_lines: 497, 526, 790, 1382, 2052
    callbacks: shadow_off, shadow_on, draw_active_sprite

Each entry in `entries` gets renamed `name` → `_name` so the JML
jump-table targets at the head of engine.s can use the underscored
form without clashing.
"""
import re
import sys


def parse_cfg(path):
    cfg = {}
    with open(path) as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if not line or ":" not in line:
                continue
            key, val = line.split(":", 1)
            cfg[key.strip()] = [v.strip() for v in val.split(",") if v.strip()]
    return cfg


def transform(src_lines, entries, rts_lines, callbacks):
    out = []
    for idx, line in enumerate(src_lines, start=1):
        stripped = line.rstrip("\n")
        # 1) rename bare entry-point labels
        for name in entries:
            if stripped == name:
                stripped = "_" + name
                break
        # 2) RTS → RTL on the marked lines
        if idx in rts_lines:
            stripped = re.sub(r"\brts\b", "rtl", stripped, count=1)
        # 3) JSR <bank-00 routine> → JSL <name>_l
        for name in callbacks:
            m = re.match(rf"^(\s+)jsr\s+{re.escape(name)}\b(.*)$", stripped)
            if m:
                stripped = f"{m.group(1)}jsl {name}_l{m.group(2)}"
                break
        out.append(stripped)
    return "\n".join(out)


def main():
    if len(sys.argv) != 4:
        print("usage: transform_block.py <src.s> <config> <out.s>",
              file=sys.stderr)
        sys.exit(2)
    cfg = parse_cfg(sys.argv[2])
    entries = cfg.get("entries", [])
    rts_lines = {int(s) for s in cfg.get("rts_lines", [])}
    callbacks = cfg.get("callbacks", [])
    with open(sys.argv[1]) as f:
        src = f.readlines()
    out = transform(src, entries, rts_lines, callbacks)
    with open(sys.argv[3], "w") as f:
        f.write(out)
        if not out.endswith("\n"):
            f.write("\n")


if __name__ == "__main__":
    main()
