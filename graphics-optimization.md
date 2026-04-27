# Graphics Optimization Plan

## Goal

Cut the per-frame cost of the animation pipeline by ~30-50%, primarily by eliminating two structural inefficiencies in the current renderer:

1. The branch-heavy transparency test inside `draw_sprite`'s inner loop.
2. The shadow tax (~6 cycles per write to bank `$01` when shadowing is enabled) paid on every sprite byte.

The eventual outcome is a pipeline where:

- Per-sprite draw is **branchless** in the byte loop.
- Per-frame composition runs with shadowing **off**, then a single **stack-PHA push** propagates the result to `$E1`.
- The `$55` scroll back buffer is eliminated, dropping required RAM under 2 MB.

Total expected savings: roughly **6-7k cycles per non-scroll frame** and **60k cycles per scroll frame** (at 2.8 MHz, ~20 ms total per scroll frame, ~3-5 ms per non-scroll frame).

---

## Current state

### Memory map (after the bank `$50 → $18` move)

| Bank | Role |
|---|---|
| `$00` | Engine code + globals (binary ends ~`$67B1`; ProDOS buffers at `$8200/$8600`; ceiling `$9600`) |
| `$01/2000-$9FFF` | Primary draw target. Writes here mirror to `$E1` via SHR shadowing. |
| `$02` | Mission 1 level data (script, sprite pixels, descriptors, pointers) |
| `$03..$10` | Decompressed screen art (one per screen) |
| `$11..$13` | NTP player + music data |
| `$18/2000-$9FFF` | **Clean playfield shadow** — sprite-free copy used as `erase` source |
| `$4F` | Scratch for `_UnPackBytes` decompression |
| `$55/2000-$9FFF` | **Scroll back buffer** — staged compositing during scroll (slated for removal in Phase 2) |
| `$E1/2000-$9D00` | Visible SHR display memory |

### Per-frame pipeline today

Non-scroll frame (game.s `game_loop` at 304):

```
wait_for_vbl
update_overlay
process_input
run_script / update_npcs / update_anims
erase_all       ; for each dirty sprite: copy union rect from $18 → $01
draw_all        ; for each dirty sprite: blit pixels with mask test → $01
draw_overlay
draw_p1_score
```

All `$01` writes pay the shadow tax (~6 cycles each).

Scroll frame (`scroll_right` / `scroll_left` / `scroll_up`):

```
flicker-cover draw_sprite onto $01    ; cosmetic, hides scroll latency
shift $18 by 4 bytes (in place)
fill the new edge from src bank → $18
fast_blit_50_55                       ; ~12 KB copy $18 → $55
draw_sprite + draw_overlay → $55      ; composite on back buffer
stack_blit_55_e1                      ; ~12 KB push $55 → $01 via PHA, shadowed to $E1
```

### Cycle breakdown (steady-state, one moving sprite)

| Stage | Cycles |
|---|---|
| `erase` ~480 bytes (incl. shadow tax) | ~12.5k |
| `draw_sprite` ~360 bytes (mask tests + writes + tax) | ~14.2k |
| Scroll frame additional (shift + fast_blit + stack_blit) | ~150k |

Shadow tax alone accounts for ~5k cycles/frame at 6 cycles/write × ~840 writes.

### Inner loop, current `draw_sprite` (per byte)

```
LDA [4]               ; sprite byte
CMP MASK              ; full transparency?
BEQ skip
AND #$F0
CMP MASKHI            ; left pixel only transparent?
BEQ domaskhi
LDA [4]
AND #$0F
CMP MASKLO            ; right pixel only transparent?
BEQ domasklo
BRA nomask
```

~30-40 cycles/byte depending on which path is taken. Most sprites use only the full-`MASK` form, so the half-nibble paths are dead overhead.

---

## Phase 1: Inverse-mask + AND/ORA pipeline

Phase 1 is being rolled out incrementally so each sub-stage can be visually validated before the next one builds on it. **A1 (POC + Billy walk) is complete and validated**; A2 and A3 remain.

### Concept

Replace the per-byte branch cascade with an unconditional 4-instruction sequence. Compile each sprite frame into **two parallel byte arrays**:

- `sprite_data` — opaque pixels in their nibble positions, `$0` in transparent slots.
- `inv_mask` — `$F` in transparent slots (preserve screen), `$0` in opaque slots (zero screen).

Inner loop (as actually shipped in `draw_sprite_compiled`):

```
LDA [scr],Y           ; current screen byte         (7)
AND [mask],Y          ; preserve transparent, zero opaque (7, long-indirect)
ORA [data],Y          ; merge opaque colors          (7)
STA [scr],Y           ; write back                   (7)
INY / CPY $0A / BCC                                  (8)
```

~36 cycles/byte (long-indirect was needed because data + mask live in bank `$02` while screen is bank `$01`). Compared to the old `draw_sprite` (~36 c on transparent byte, ~62 c on opaque byte), this is **flat-cost regardless of pixel content** — the win shows up on opaque-heavy frames (most of them).

Mirror is baked into pre-rotated `_DATA_MIRROR` / `_MASK_MIRROR` arrays at compile time; `draw_sprite_compiled` has **no mirror branch** at all, you just hand it different pointers.

### Compilation rules

For each source byte at compile time (transparent nibble varies per sprite — `$7` for `POINT_*`, `$6` for Billy, `$E` for William, etc.):

| Source nibble | `_MASK` nibble | `_DATA` nibble |
|---|---|---|
| transparent | `$F` (preserve) | `$0` (don't OR in) |
| any other (opaque) | `$0` (zero) | original color |

Examples (transparent = `$7`):
- Source `$77` (fully transparent) → mask=`$FF`, data=`$00`
- Source `$AB` (fully opaque) → mask=`$00`, data=`$AB`
- Source `$7C` (left transparent, right opaque) → mask=`$F0`, data=`$0C`

Mirror variants: bytes reversed with nibbles pre-swapped, then the same data/mask split applied. Same inner loop, different pointers.

### Tool

`tools/compile_sprite.py <NAME> <TRANSPARENT_NIBBLE_HEX>` — reads a `HEX` block from stdin, emits Merlin-syntax `<NAME>_DATA` / `<NAME>_MASK` / `<NAME>_DATA_MIRROR` / `<NAME>_MASK_MIRROR` blocks. Validated against POINT_RIGHT and IMAGE01-03 before any engine integration.

### Sub-stage A1 — POC + Billy walk (✅ shipped)

**What was converted:**

- POINT_RIGHT (overlay sprite, transparent `$7`)
- POINT_UP (rotated POINT_RIGHT, transparent `$7`)
- IMAGE01, IMAGE02, IMAGE03 (Billy's three walk frames, transparent `$6`)

**Engine changes that landed:**

- New routine `draw_sprite_compiled` in `game.s` — 11-byte DP carve-out (`[0]` screen, `[4]` data, `[7]` mask, `$0A` end_x), branchless inner loop, advances all three pointers in lockstep per row.
- Sprite-address-table extension: existing `spr_image01..03` and `spr_pointright`/`spr_pointup` slots (offsets +0…+76) point at the `_DATA` arrays via `IMAGE0N EQU IMAGE0N_DATA` aliases. New entries at offsets +86..+114 expose `_MASK` / `_DATA_MIRROR` / `_MASK_MIRROR` for each converted sprite.
- `init_level` reads the new offsets into engine globals (`spr_image01_mask`, etc.) and patches:
  - `walk_addr_tbl` / `walk_mask_tbl` — non-mirror data + mask pairs for the 4-frame walk cycle.
  - `walk_addr_tbl_mirror` / `walk_mask_tbl_mirror` — pre-rotated counterparts.
  - `billy_sprite+14` (frame_addr) ← `IMAGE01_DATA`, `+42` (idle_addr) ← `IMAGE01_DATA`, `+52` (mask_addr) ← `IMAGE01_MASK`. `MASK_ADDR` global also seeded.
- `advance_walk` selects data + mask table pair from `IMAGE01_MIRROR`, writes both `FRAME_ADDR` and `MASK_ADDR` globals.
- Sprite info block: `+52` repurposed as `mask_addr` for Billy. NPC slots' `+52`/`+54` continue to mean `walk_anim`/`atk_anim` — dispatch gates on `controller == 1` so the meaning of `+52` stays sprite-type-specific.
- `load_sprite` reads `info+52` → `MASK_ADDR` (always; for NPCs the value is harmless).
- `save_sprite` and `save_anim_state` persist `MASK_ADDR` → `info+52` **only when `controller == 1`** (Billy), so NPC `walk_anim` is preserved.
- `draw_all` dispatch (and `draw_active_sprite` used by the 7 scroll-pipeline call sites): `controller == 1 AND MASK_ADDR != 0 → draw_sprite_compiled`, else `draw_sprite`.
- Three idle-restore call sites all set `MASK_ADDR` mirror-aware before yielding back to compiled draws:
  - `update_anims :anim_done` (after a punch/kick/jump completes).
  - `snap_transition` climb-reset (when Billy reaches the top of a ladder).
  - `init_level` (initial seed).
- `MASK_ADDR` clears (so dispatch falls to legacy) in two places where Billy's frames are still uncompiled: `start_anim` (animation system frames) and `advance_climb` (BCLIMB1/2).

**Validated end-to-end:** Billy idle, walking right, walking left (mirror), entering and exiting punch/kick/jump animations, scrolling right/left/up, climbing ladders bottom-to-top in both orientations.

### Sub-stage A2 — Convert Billy's animation-system frames (next)

**Sprites to convert** (transparent nibble `$6` for all):
- `JUMP1`, `JUMP2`, `JUMP3`
- `KICK1`, `KICK2`
- `PUNCH11`, `PUNCH12`, `PUNCH21`, `PUNCH22`
- `BPUNCHED`
- `BCLIMB1`, `BCLIMB2`

**Animation descriptor format change**: extend each frame entry from 5 bytes (`frame_x, frame_y, duration, frame_addr_lo, frame_addr_hi`) to **11 bytes** (`frame_x, frame_y, duration, data_lo, data_hi, mask_lo, mask_hi, dmir_lo, dmir_hi, mmir_lo, mmir_hi`). Mark these descriptors with a flag bit (e.g., bit 7 of the header `flags` byte) so `update_anims :load_frame` knows to use the 11-byte stride.

**Affected anim descriptors (all in game.s, since `init_level` patches them from the bank `$02` sprite address table):** `anim_jump`, `anim_kick`, `anim_punch1`, `anim_punch2`, `anim_bpunched`, `anim_bfall`. (Walking still uses `walk_*_tbl` directly, not an animation descriptor.)

**Engine changes:**
- `update_anims :load_frame`: detect the compiled flag, advance `anim_frame * 11` bytes into the descriptor, load 4 pointers, pick `(data, mask)` or `(dmir, mmir)` based on `IMAGE01_MIRROR`. Set `MASK_ADDR` accordingly so dispatch routes to `draw_sprite_compiled`.
- `start_anim`: drop the `MASK_ADDR = 0` clear (now redundant — the compiled animation will set it correctly via the new `:load_frame`).
- `advance_climb`: drop the `MASK_ADDR = 0` clear (BCLIMB1/2 are now compiled). Set `MASK_ADDR` from `spr_bclimb1_mask`/`spr_bclimb2_mask` directly.
- `:anim_done` idle-restore: same logic as A1, no change needed (already mirror-aware).
- The two `MASK_ADDR` clears in A1's `start_anim`/`advance_climb` go away entirely — every Billy frame is compiled.

**Sprite memory cost**: ~12 frames × 4 arrays × ~360 bytes ≈ 17 KB additional bank `$02` use. Mission 1 currently sits at ~27 KB; A2 pushes it to ~45 KB. Still fits in a 64 KB bank.

### Sub-stage A3 — Cleanup (after A2)

- Delete `MASK / MASKHI / MASKLO` fields from `billy_sprite` (and any other compiled sprite blocks). Leave them on NPC blocks until those get converted.
- Drop `start_anim`'s and `advance_climb`'s `MASK_ADDR` clears (rendered moot by A2).
- The dispatch in `draw_all` and `draw_active_sprite` can simplify to `MASK_ADDR != 0` (drop the `controller == 1` check) once *every* compiled sprite has its `+52` populated correctly. Still need the controller check for as long as legacy NPCs coexist.
- Eventually convert NPCs (William, Linda, Roper) and retire `draw_sprite`, `MASK / MASKHI / MASKLO` globals, and the `controller == 1` gate. That's a future sub-stage (call it A4) and basically completes Phase 1.

### Lessons from A1

- **Pre-rotated mirror arrays are a clear win.** Removing the per-byte mirror branch means the inner loop has zero conditional flow per pixel. The 3× sprite memory cost is a non-issue at this scale.
- **`MASK_ADDR != 0` is the right dispatch signal**, not `anim_ptr == 0`. It cleanly handles climb (uncompiled BCLIMB1/2) and animation states without coupling to the animation system. A2 will remove the explicit clears once everything is compiled, leaving a one-signal model.
- **Mirror state carries across action boundaries.** Three places restore Billy's idle frame after a transient state — `:anim_done`, `snap_transition` climb-reset, and `init_level`. All three need to consult `IMAGE01_MIRROR` and pick from `_DATA`/`_MASK` vs `_DATA_MIRROR`/`_MASK_MIRROR`. Easy to miss one (the climb-end black box at the top of ladders was the third spot, found in playtest after A1's first cut).
- **NPC info-block layout collision was the trickiest part.** `+52`/`+54` on NPC slots were already used as `walk_anim`/`atk_anim`. Reusing `+52` for Billy's `mask_addr` works only because dispatch gates on `controller == 1` — the meaning of the byte differs by sprite type. Any future field added to compiled sprites needs the same care, or NPC slots need to grow.
- **Compiled sprites must use long-indirect addressing.** Data/mask in bank `$02`, screen in bank `$01` — same-bank `(DP),Y` would need DBR=$01 (screen) AND DBR=$02 (sprite) at the same time, which isn't possible. The 1-cycle-per-byte penalty for long-indirect (vs same-bank indirect) is the cost of admission. Phase 3g would address this by moving sprite data into bank `$00`, but the bank `$00` ceiling makes that infeasible without first eliminating other consumers.

### Cost estimate (full Phase 1, after A2)

- Sprite memory: ~3× current per-frame size. Mission 1 reaches ~50-60 KB of bank `$02`. Future levels with more art may need to split sprite data and level data across banks.
- Bank `$00` engine code: A1 added ~250 bytes; A2 will add ~150 more (descriptor format change). Headroom is ~6 KB before the IOBUF ceiling.
- Build pipeline: `tools/compile_sprite.py` is the only new step.

### Realized savings (A1) and projected savings (A2 done)

Measured wins from A1 alone are limited to Billy's walk + idle frames (~50% of his on-screen time). A2 extends compiled rendering to **every** Billy frame.

- Per-byte: **~30-40%** speedup on opaque-heavy bytes, neutral on fully-transparent bytes. The wash on transparent bytes doesn't hurt — masks for transparent areas are tiny anyway.
- Per non-scroll frame, A2 done: ~3-5 k cycles saved on Billy alone.
- Per scroll frame, A2 done: same savings on the back-buffer composite + flicker-cover.

---

## Phase 2: Shadowing-off render + push

### Concept

The IIgs SHR shadow controller adds ~6 cycles per write to bank `$01` when shadowing is enabled (it has to arbitrate a slow-RAM cycle on `$E1`). The current pipeline pays this on every sprite byte and every erase byte.

New pattern:

1. Turn shadowing **off** (`STA $C035` with bit 3 set).
2. Run `erase_all` and `draw_all` normally — writing to `$01` without the shadow tax. `$E1` (visible) is untouched during this phase.
3. Turn shadowing **on** (`STA $C035` with bit 3 clear).
4. **Push** the dirty rows: re-write a contiguous range of `$01` bytes; shadowing mirrors them to `$E1` atomically.

For non-scroll frames, the push covers `[ymin..183]` where `ymin` is the topmost row touched by any erase or draw this frame. For scroll frames, the push covers the full 183-row playfield.

### Why this eliminates the `$55` back buffer

The `$55` buffer existed solely so the scroll pipeline could produce a clean composite **without partial states being visible**. With shadowing off, `$01` itself becomes the staging area — partial writes are not visible because `$E1` is decoupled from `$01` until shadowing flips back on.

The scroll pipeline collapses from:

```
shift $18 → fast_blit_50_55 → composite on $55 → stack_blit_55_e1
```

to:

```
shadow OFF
shift $18 → copy shifted band $18 → $01 → composite sprites/overlay on $01
shadow ON
push_full 183 rows                         ; PHA-blit, shadow mirrors to $E1
```

`$50/$18` (clean playfield) **stays** — it remains the source for `erase`. Only `$55` goes away.

### Push routine

Generalization of the existing `stack_blit_55_e1`:

```
push_dirty_band(ymin, ymax):
  shadow ON  (already on at entry)
  STA $C005  (WrCardRAM: bank $00 stack writes redirect to $01)
  for line in [ymin..ymax]:
    TCS = $01/(2000 + line*$A0 + 109)
    LUP 55: LDAL $012000+]idx,X / PHA      ; read from $01, write to $01 via stack
            (each PHA → shadow → $E1)
  STA $C004  (WrMainRAM)
```

Reads from `$01` and writes to `$01` looks redundant, but the read goes through normal memory while the write goes through the stack-redirected path that triggers shadowing. The write is what propagates to `$E1`.

A 110-byte row × 5 cycles/PHA × 55 PHAs/row = 275 cycles/row + ~30 cycles overhead. Full-screen push (183 rows) ≈ 56 k cycles, comparable to today's `stack_blit_55_e1`. Partial push (~50 rows) ≈ 15 k cycles.

### Tracking dirty rows

Track `ymin_dirty` (and `ymax_dirty` if useful) across `erase_all` and `draw_all`:

- `erase_all` already iterates dirty sprites and computes a union rect per sprite. Maintain a frame-level `min(ymin_dirty, sprite_top)` accumulator.
- `draw_all` does the same against `current_y`.
- Reset to `183` (no dirty) at the top of the frame.

If `ymin_dirty < 183`, push `[ymin_dirty..182]`. Otherwise skip the push entirely (no work was done — possible during pause).

For coalescing multiple disjoint dirty bands, V1 ships with a single `[ymin..ymax]` strip; V2 can split into multiple pushes if measurement shows benefit.

### Implementation

**Add helpers** (game.s):

```
shadow_off:
  sep $20
  ldal $C035
  ora #%00001000
  stal $C035
  rts

shadow_on:
  sep $20
  ldal $C035
  and #%11110111
  stal $C035
  rts

push_band:
  ; in: ymin (1 byte), ymax (1 byte)
  ; rewrites $01/(2000+ymin*$A0)..$01/(2000+ymax*$A0+109) onto itself
  ; with shadowing on, propagating to $E1
```

**Modify `game_loop`**:

```
game_loop:
  wait_for_vbl
  check_pause
  bne game_loop                    ; skip everything when paused
  jsr update_overlay
  jsr process_input
  jsr run_script / update_npcs / update_anims
  lda #183                         ; reset dirty tracker
  sta dirty_ymin
  jsr shadow_off
  jsr erase_all                    ; updates dirty_ymin
  jsr draw_all                     ; updates dirty_ymin
  jsr draw_overlay
  jsr draw_p1_score                ; QuickDraw paths bypass shadow flag
  jsr shadow_on
  lda dirty_ymin
  cmp #183
  beq :no_push
  jsr push_band                    ; push [dirty_ymin..183]
:no_push
  bra game_loop
```

**Modify scroll routines**:

- Drop the `flicker-cover` `jsr draw_sprite` at top of each scroll routine. With shadowing off, no flicker is possible.
- Drop `fast_blit_50_55` calls.
- Replace `stack_blit_55_e1` with `push_band(0, 182)` (full playfield).
- Composite directly on `$01` (set `draw_bank = $01` instead of `$55`).
- Drop `draw_bank` global entirely once all paths use `$01`.

**QuickDraw considerations**:

`draw_p1_score`, `draw_pause_text`, the startup HUD, and cutscenes all use `_DrawCString` / `_DrawString` which write to `$E1` directly via QuickDraw. They don't go through `$01`, so shadow state doesn't affect them. They can run inside or outside the shadow-off window without changing behavior. **However**: the push step might overwrite QuickDraw output if the push range covers the HUD line at row 195. Solution: keep push range to `[0..182]` (playfield only), exclude HUD area.

### Validation

- Visual: run one scroll, then 10 seconds of combat, look for tearing or stale pixels.
- Capture frame counter via `$C019` VBL polling and confirm scroll frames complete inside one or two VBLs (they should — savings are large enough that scroll fits comfortably in a 16.7 ms window).
- Watch for shadow-toggle race conditions during interrupt handlers (NTP plays via interrupt). The push window is brief enough that a stray interrupt landing during shadow-off should be invisible — but verify by stress-testing.

### Cost estimate

- Removed: one global `draw_bank` (2 bytes).
- Removed: `fast_blit_50_55` routine (small, ~120 bytes).
- Modified: `stack_blit_55_e1` → `push_band` (similar size, more parameterized).
- New: `shadow_off` / `shadow_on` (~10 bytes each), `dirty_ymin` tracker (1 byte).
- Net code size: roughly neutral.
- RAM: `$55` becomes unused (32 KB freed). Highest required bank drops from `$55` to `$E1` (effectively `$18` plus screen art). System now functions on **2 MB IIgs** without changes.

### Expected savings

- Per-write shadow tax eliminated during composition: ~5 k cycles/non-scroll frame.
- Scroll pipeline: drop `fast_blit_50_55` (~70 k cycles) + drop double-blit overhead → **~60 k cycles saved per scroll frame**.
- Non-scroll frame net (after adding the push): ~3-4 k cycles saved (push isn't free; partial-band amortizes well).

---

## Phase 3: Optional follow-ups

These are further wins available after Phases 1 and 2 land. Each is an independent small change.

### 3a. Specialized `draw_sprite` per mask pattern

If Phase 1 (inverse mask) ships, this is moot — the mask cascade is already gone.

### 3b. Precomputed scanline LUT

Replace `lda y; asl×7; clc; adc #$2000; sta dp` with `lda yline_lut,Y` (200-entry word table = 400 bytes in bank `$00`). Saves ~10 cycles per scanline pointer setup.

Multiple inner loops benefit: `erase`, `draw_sprite`, the scroll shifters, push.

### 3c. Tighter erase rects

Today `erase` wipes the full union of `prev` and `current` sprite rects. For 1-2 px walks, the wiped area is ~3× larger than necessary. A trailing-edge-only erase (the strip the sprite vacated) saves ~20% on erase. More bookkeeping; modest gain.

### 3d. Combined erase+draw pass

Walk the sprite table once, doing erase-prev → draw-current per sprite, instead of two full passes. Keeps `info_ptr` warm on direct page; small but free win.

### 3e. Dirty list / sparse iteration

For 16 NPC slots + Billy, today's pipeline iterates the whole table every frame (load + dirty test on each entry, even clean ones). A maintained "dirty list" (linked or compact) skips clean entries entirely. Becomes meaningful only when many NPCs are alive; not urgent now.

### 3f. Compiled sprites for hot frames

For the 4-8 most-drawn frames (Billy idle, walks, punches), generate per-frame "draw code": a sequence of `LDA #imm; STA $xxxx` per pixel, no loop, no mask test, no pointer arithmetic. 5-10× speedup on those specific frames; large code-size cost. Worth it only if Phase 1 doesn't deliver enough on the hottest frames.

### 3g. Move sprite data into bank `$00`

Long-indirect `[4]` (7 cycles) → direct-page indexed `(4),Y` (6 cycles). Saves ~1 cycle per pixel byte. Blocked by the bank `$00` ceiling (`$9600`); not pursuable without first moving level data or eliminating the engine's memory budget pressure another way.

### 3h. Asymmetric-mirror anchor fix (deferred from A2)

**Status**: known issue, deferred during A2.

Mirror-flipped asymmetric sprite frames (PUNCH11/12, PUNCH21/22, KICK2, JUMP2/3, BPUNCHED) draw with Billy's body shifted to the right edge of the sprite instead of the left. Visually his feet "slide backwards" during a left-facing attack as the punch frame's wider extension wraps to the right of `IMAGE01_XPOS`. This is **legacy behavior** — the original `draw_sprite` mirror path had the same artifact; A2 just makes it more visible by surfacing more compiled mirror frames.

The fix is non-trivial: the renderer needs a per-frame "draw anchor" distinct from the logical `IMAGE01_XPOS`. Either:

- **Pipeline approach**: extend the compiled animation descriptor to 12-byte frames carrying a `mirror_x_shift` byte. Add a `DRAW_XPOS` global and `prev_draw_xpos` info-block field. `draw_sprite_compiled` and `erase` consume `DRAW_XPOS` / `prev_draw_xpos` instead of `IMAGE01_XPOS` / `prev_xpos`. `save_sprite` / `save_anim_state` snapshot the new field. Hand-tune `mirror_x_shift` per frame by visual inspection.
- **In-place adjustment**: `start_anim` mirror-compiled branch saves the original `IMAGE01_XPOS` to a side variable and subtracts `mirror_x_shift`. Per-frame `:load_frame` recomputes from saved original + new shift. `:anim_done` restores. Cheaper but `IMAGE01_XPOS` reads weird values mid-animation; OK because input is blocked during action animations.

Pick the cleaner pipeline approach when revisiting. Touch points: descriptor format, init_level patching, `draw_sprite_compiled`, `erase`, `save_sprite`, `save_anim_state`, `info` block layout, plus per-frame `mirror_x_shift` measurements for every asymmetric Billy frame.

---

## Order of execution

| Phase | Status | Notes |
|---|---|---|
| 1.A1 — POC + Billy walk | ✅ shipped | POINT_RIGHT, POINT_UP, IMAGE01-03 compiled. `draw_sprite_compiled`, `draw_active_sprite`, `MASK_ADDR != 0` dispatch, mirror-aware idle restore, scroll-pipeline wiring all in place and validated. |
| 1.A2 — Billy animation frames | ✅ shipped | JUMP/KICK/PUNCH/BPUNCHED/BCLIMB compiled; animation-descriptor format extended to 11-byte frames; `update_anims :load_frame` and `start_anim` dispatch on flags bit 7. All three sub-stages (A2.1 BCLIMB, A2.2 anim_punch1, A2.3 remaining anims) validated. Asymmetric-mirror anchor artifact deferred to 3h. |
| 1.A3 — Cleanup | ✅ shipped | Dead `MASK_ADDR=0` clears removed from `start_anim`'s and `:load_frame`'s legacy branches (Billy never reaches them — every Billy animation is compiled). `MASK / MASKHI / MASKLO` info-block fields stay on Billy — removing them would shift NPC-slot offsets, no real cost to leaving them as ignored bytes. `advance_climb`'s `MASK_ADDR=0` clear was already dropped in A2.1 when BCLIMB became compiled. |
| 1.A4 — NPCs | **deferred** | Cost overflows bank `$02` (~14 KB over the 64 KB limit; see § "A4 deferral"). Win-per-byte is low — NPCs are visible in bursts during fights, while Billy is on screen every frame. Pick this back up only if a concrete reason emerges (e.g., the legacy `draw_sprite` becomes a maintenance burden, or another mission with heavier NPC art surfaces). |
| 2. Shadow-off render + push, eliminate `$55` | not started | Bigger absolute win; cross-cutting (game loop, scroll routines, QuickDraw interactions). |
| 3a-3g (optional) | not started | Each independent. Pick based on profiling after Phase 2 lands. |

Phases 1 and 2 are independent — neither blocks the other — but Phase 1 is lower-risk, so completing it first builds confidence in the harness and validates the asset compile pipeline before we touch frame timing.

---

## A4 deferral — cost analysis and options

**Status as of A3 completion**: Phase 1 ships with NPCs (William, Linda, Roper) on the legacy `draw_sprite` path. The engine carries both renderers; dispatch in `draw_all` and `draw_active_sprite` gates on `controller == 1` to route Billy to compiled and everyone else to legacy. This is intentional, not an oversight.

### Why A4 was deferred

**Memory cost overflows bank `$02`.** Mission 1 has 26 NPC sprite frames totalling ~10,150 bytes raw:

| NPC | Frames | Approx raw bytes |
|---|---|---|
| William | WILLIAM1/2/3, WPUNCH1/2, WPUNCHED, WFALL, WFALLEN | ~3,400 |
| Roper | ROPER1/2/3, RPUNCH1/2, RPUNCHED, RFALL1/2 | ~3,050 |
| Linda | LINDA1/2/3, LPUNCH1/2, LPUNCHED, LCLIMB1/2, LFALL1/2 | ~3,700 |

Compiled form is 4× original (`_DATA + _MASK + _DATA_MIRROR + _MASK_MIRROR`):

| | Bytes |
|---|---|
| `mission1` after A3 | 48,750 |
| Replace ~10,150 NPC originals with ~40,600 compiled | +30,500 |
| **Projected** | **~79,250** |

Bank `$02` ceiling is 65,536 bytes. A4 overflows by ~14 KB. Future levels with more NPC variety would overflow further.

**Win-per-byte is low compared to Billy.** Billy is on screen 100% of the time and his mirror flips constantly with player input. His per-byte cycle savings show up in *every* frame. NPCs are on-screen in bursts during fights — at most three at once in mission 1, often zero — and their mirror state changes only when their behavior pivots them, not per-frame. Phase 1's main goal was getting the inner-loop refactor proven; that goal is met by A1+A2+A3.

**Engine carry-cost is low.** Keeping legacy alongside compiled costs ~200 lines of engine code (`draw_sprite`, `MASK / MASKHI / MASKLO` globals, the controller gate in `draw_all` / `draw_active_sprite`, the legacy 5-byte stride in `:load_frame` / `start_anim`). None of it is hot — once Billy goes through compiled, the legacy path is reached only for NPC draws, which are infrequent.

### Options if A4 becomes worth doing

These are listed roughly cheapest-to-tackle first.

**Option A — Selective NPC frames.** Compile only the walk frames (`WILLIAM1-3`, `ROPER1-3`, `LINDA1-3`), skip everything else. ~3 KB raw → ~12 KB compiled, +9 KB net. Fits comfortably in bank `$02`. Captures most of the on-screen NPC rendering volume since NPCs spend most of their visible time walking. Punched/fall/climb states stay legacy.

**Option B — Skip mirror variants for NPCs.** Emit only `_DATA + _MASK` for NPCs (no `_MIRROR` arrays). Use the legacy `draw_sprite` mirror path (byte-reverse + nibble-swap) for NPC mirrored draws. Cuts NPC compiled-size cost from 4× to 2× → +10 KB net for all NPCs, fits in bank `$02`. Cost: a third draw routine that combines compiled `AND/ORA` with runtime byte-reversal. Medium engine effort.

**Option C — Split mission1 across two banks.** Keep header + script + Billy data in `$02`, push NPC sprite data into a separate bank (e.g., `$03` or wherever fits in the existing bank layout). Engine gains a per-sprite bank field, or a second `sprite_bank` global for NPCs. Cross-bank dispatch in `draw_sprite_compiled` adds ~3-4 cycles per byte (long-indirect load with a different bank). ~50 lines of engine changes, more nuanced because `draw_sprite_compiled` reads via DP `[4]` and `[7]` long-indirect; the bank byte at DP `+6` and `+9` would need to be set per-sprite from the info block. Tractable but the most invasive option.

**Option D — Move NPC sprite art outside `mission1.s` entirely.** Treat NPC sprites like background art — a separate `.PAK`-style file loaded into its own bank at startup. Same engine consequences as Option C plus disk-side packaging changes. Useful long-term if multiple missions share NPC art (William and Roper might appear across many levels), but overkill for current scope.

### Triggers that would prompt picking A4 back up

- A future mission requires significantly more NPC frames or unique NPCs, pushing total sprite art beyond what fits with Billy fully compiled.
- Profiling shows NPC drawing as a measurable bottleneck during multi-NPC fights (currently it's not — the legacy path is fine for 2-3 NPCs at a time).
- Eliminating the legacy renderer becomes desirable for code clarity (e.g., before a major engine refactor), at which point Option B looks cleanest because it keeps NPC sprite memory bounded.
- Phase 2 (shadow-off render) lands and exposes a need for `controller == 1` dispatch removal — currently the `controller == 1 + MASK_ADDR != 0` check is two instructions, but if dispatch becomes part of the per-frame push path, simplifying it might matter.

Until one of those triggers fires, NPCs stay on legacy and Phase 1 is "complete enough."

---

## Risks and unknowns

- **Shadow-off interaction with NTP interrupts** (Phase 2). The NTP player runs from interrupts and reads from `$11..$13`. It doesn't touch `$01` or `$E1`, so there should be no conflict, but verify by running an NTP-heavy scene through the new path.
- **QuickDraw behavior with shadowing off** (Phase 2). QuickDraw writes directly to `$E1` and shouldn't care about shadow state. The HUD and PAUSED text should still draw correctly during shadow-off windows. Verify in cutscene and pause flows.
- **`$50`/`$18` rename completeness**. Already done — verified no remaining `lda #$50` or `LDAL $502xxx` references in code; comments updated.
- **Sprite memory tripling under Phase 1**. Mission 1 currently uses ~27 KB of bank `$02`. After A1 (3 walk frames + 2 overlay sprites compiled) it's ~33 KB. After A2 (all of Billy) it'll reach ~50 KB. Still fits in one bank but leaves little headroom for level script growth. May need to split sprite data and level data into separate banks for future levels. Address if/when it bites.
- **Idle-restore points are easy to miss.** A1 found three (`:anim_done`, `snap_transition` climb-reset, `init_level`); each must consult `IMAGE01_MIRROR` and pick the right `_DATA`/`_MASK` vs `_DATA_MIRROR`/`_MASK_MIRROR` pair. Any future code path that resets Billy's frame to idle from outside `advance_walk` needs the same treatment. Candidate for a shared `restore_billy_idle_compiled` helper if a fourth site appears.
- **NPC info-block field reuse.** Billy's `+52` is `mask_addr`; NPC slots' `+52` is `walk_anim`. Dispatch gates on `controller == 1` to keep the meanings separate. Adding more compiled-only fields to Billy means either growing NPC slots to match or carefully gating each new offset.
- **Push range during pause** (Phase 2). While paused, no dirty work happens, so push is skipped. Confirmed correct in the proposed `game_loop`.
- **Dirty tracker corruption** (Phase 2). If any rendering path forgets to update `dirty_ymin`, a row goes un-pushed and stale pixels persist on screen. Add an assert that runs in debug builds: after the push, the on-screen `$E1` rect should match `$01` for `[ymin..182]`.

---

## Reference: file inventory

- `src/game.s` — engine. All rendering code lives here. Key routines:
  - Legacy: `erase`, `draw_sprite`, `erase_all`, `draw_all` (now with compiled-vs-legacy dispatch), scroll routines (`scroll_right`, `scroll_left`, `scroll_up`, `snap_transition`), blit routines (`fast_blit_50_55`, `stack_blit_55_e1`).
  - Compiled (A1): `draw_sprite_compiled`, `draw_active_sprite`, `MASK_ADDR` global, mirror-aware idle-restore in `:anim_done` and `snap_transition`, `walk_addr_tbl_mirror`/`walk_mask_tbl`/`walk_mask_tbl_mirror` and the corresponding `init_level` patches.
- `src/mission1.s` — sprite pixel data and address table. After A1: POINT_RIGHT, POINT_UP, IMAGE01-03 are compiled (replaced with `_DATA`/`_MASK`/`_DATA_MIRROR`/`_MASK_MIRROR` quartets, with `IMAGE0N EQU IMAGE0N_DATA` aliases for vestigial references). Sprite-address-table extends to offset +114 with the new pointers. All other sprites still uncompiled.
- `tools/compile_sprite.py` — sprite compiler. Reads `HEX` rows from stdin with a transparent-nibble argument, emits the four compiled blocks. Used for every sprite conversion in Phase 1.
- `tools/rotate_sprite.py` — 90° CCW rotation; used to derive POINT_UP from POINT_RIGHT before compiling.
- `CLAUDE.md` — project overview; memory map updated to reflect bank `$50 → $18`.
