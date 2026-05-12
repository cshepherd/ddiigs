#!/usr/bin/env python3
"""Build src/engine.s from src/game.s's scroll/blit block.

Reads /tmp/engine_block.s (the verbatim cut from game.s), applies the
transformations needed to make it callable cross-bank:

  * rename `scroll_right`/`scroll_left`/`scroll_up` to `_scroll_right`
    etc., so the JML jump-table at the head of the bank can target them
    directly without label clashes.
  * convert each external entry point's RTS exits to RTL (so JSL
    callers in bank $00 return correctly).
  * convert calls into bank-$00 routines (shadow_off, shadow_on,
    draw_active_sprite, draw_overlay, inc_border, load_screen_bounds)
    to JSL trampolines (`<name>_l`).

Internal calls to push_band / fast_blit_18_01 / compute_up_align stay
JSR — those move with the block and live in the same bank.

The output is wrapped in an ORG / jump-table / PUT engine_externs.s
skeleton.
"""
import re
import sys

# Line numbers in /tmp/engine_block.s where the entry-point routines'
# RTS exits live. Verified by inspection. (Internal helpers
# compute_up_align/push_band keep RTS — their lines are excluded.)
RTS_TO_RTL_LINES = {497, 526, 790, 1382, 2052}

ENTRY_RENAMES = {
    "scroll_right": "_scroll_right",
    "scroll_left":  "_scroll_left",
    "scroll_up":    "_scroll_up",
}

JSL_CALLBACKS = (
    "shadow_off",
    "shadow_on",
    "draw_active_sprite",
    "draw_overlay",
    "inc_border",
    "load_screen_bounds",
)


def transform(src_path):
    out = []
    with open(src_path) as f:
        for idx, line in enumerate(f, start=1):
            stripped = line.rstrip("\n")
            # 1) Rename bare entry-point labels in column 0.
            for old, new in ENTRY_RENAMES.items():
                if stripped == old:
                    stripped = new
                    break
            # 2) RTS → RTL on the entry-point exit lines only.
            if idx in RTS_TO_RTL_LINES:
                stripped = re.sub(r"\brts\b", "rtl", stripped, count=1)
            # 3) JSR <bank-00 routine> → JSL <name>_l. Match either
            #    a bare `jsr name` line or one with a trailing comment.
            for name in JSL_CALLBACKS:
                m = re.match(rf"^(\s+)jsr\s+{re.escape(name)}\b(.*)$",
                             stripped)
                if m:
                    indent, tail = m.group(1), m.group(2)
                    stripped = f"{indent}jsl {name}_l{tail}"
                    break
            out.append(stripped)
    return "\n".join(out)


HEADER = """*----------------------------------------------------------
* engine.s — Bank-$1F engine code: scroll/blit pipeline.
*
* Loaded by game.s at boot from /DDIIGS/ENGINE to $1F:$0000.
* Bank $00 is too full to hold the engine plus all the scroll
* code, so we split the heavy memcpy-style routines off into
* their own bank. They still touch bank-$00 globals (DBR=$00 on
* entry — caller preserves it), so the code reads like normal
* in-bank assembly; only the program counter lives at $1F.
*
* Public entry points (callable via JSL from game.s):
*   $1F/0000  scroll_right
*   $1F/0004  scroll_left
*   $1F/0008  scroll_up
*
* Internal helpers (push_band, fast_blit_18_01, compute_up_align)
* are called intra-bank via JSR and not exposed.
*
* All bank-$00 symbol addresses come from engine_externs.s, which
* tools/extract_externs.py regenerates from game.s's listing on
* every build.
*----------------------------------------------------------

         ORG $1F0000
         mx %11

* JML jump table at the head of the bank — gives game.s fixed
* JSL targets that don't shift when engine.s body changes.
         jml _scroll_right             ; $1F/0000
         jml _scroll_left              ; $1F/0004
         jml _scroll_up                ; $1F/0008

         PUT engine_externs.s

*----------------------------------------------------------
* Moved verbatim from game.s with the following transforms:
*   - scroll_right/_left/_up renamed with leading underscore
*     to match the jump-table targets.
*   - each entry point's RTS exits converted to RTL.
*   - JSRs to bank-$00 helpers (shadow_off, shadow_on,
*     draw_active_sprite, draw_overlay, inc_border,
*     load_screen_bounds) become JSL to their _l trampolines.
*   - everything else (variables, internal helpers, locals)
*     migrates unchanged.
*----------------------------------------------------------

"""


def main():
    if len(sys.argv) != 3:
        print("usage: build_engine_s.py <input.s> <output.s>",
              file=sys.stderr)
        sys.exit(2)
    body = transform(sys.argv[1])
    with open(sys.argv[2], "w") as f:
        f.write(HEADER)
        f.write(body)
        if not body.endswith("\n"):
            f.write("\n")


if __name__ == "__main__":
    main()
