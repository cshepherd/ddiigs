# Camera Drift Problem (Apple IIGS Double Dragon)

## Overview

This document explains a fundamental issue encountered in push-to-scroll camera systems, why it cannot be solved purely mathematically, and the correct architectural solution.

---

## The Core Problem

We track two key values:

- `abs_x` → Player position in world coordinates  
- `world_offset` (WO) → Camera position (left edge of screen in world coordinates)

We also derive:

- `IMAGE01_XPOS = abs_x - world_offset` → Player position on screen

---

## The Incorrect Assumption

It is tempting to assume:

> If we know `abs_x`, we can determine `world_offset`.

This is **false**.

---

## Why It Fails

Because the game allows different per-frame deltas:

- Walking without scrolling: `xpos` changes by ±1 byte per frame (= ±2px in 320 mode); `world_offset` unchanged.
- Scrolling: `world_offset` changes by ±4 bytes per frame (chunky 8px scroll); `xpos` clamped at the scroll threshold (`LEFT_SCROLL_THRESH = 30` for left, similar for right).
- Walking backward after scrolling: the player can walk left/right within the playfield without ever scrolling back, leaving `world_offset` "stuck" at a higher/lower value than the symmetric path would produce.

These three together create multiple valid histories that lead to the same `abs_x`.

### Result:

Same abs_x ≠ same world_offset

This mismatch is called:

**Camera Drift**

Drift is not limited to `world_offset`. Other per-frame accumulators also diverge across histories — `scroll_src_bank`, `scroll_src_off`, `scroll_lsrc_bank`, `scroll_lsrc_off`, and `scroll_up_off`. A complete Golden State has to restore all of them.

---

## Why This Is Hard

You are trying to compute:

world_offset = f(abs_x)

But this function does not exist.

The missing information is **history** — how the player moved to reach that position.

Therefore:

The problem is not solvable from `abs_x` alone.

---

## The Correct Model

The camera is **independent state**:

abs_x         = player position (gameplay truth)  
world_offset  = camera position (rendering truth)

They are related, but one does not determine the other.

---

## The Solution: Golden State Snap

At important gameplay transitions (e.g. ladders), we enforce a known-good state.

Instead of asking:

Where should the camera be?

We do:

The correct camera state is already known. Apply it.

---

## Golden State Definition

A Golden State includes:

- `world_offset`
- `abs_x`
- `IMAGE01_XPOS`
- `current_screen`
- `scroll_src_bank` / `scroll_src_off` (right-scroll source)
- `scroll_lsrc_bank` / `scroll_lsrc_off` (left-scroll source)
- `scroll_up_anchor`, `scroll_up_off`
- `scroll_min_wo`, `scroll_max_wo` (script clamps)
- Optional repaint regions (see below)

In this codebase: 17 bytes of engine state for `OP_SNAPSTATE`; 25 bytes for `OP_SNAPSTATE_DEFER` (17 engine + 8 repaint = two 4-byte regions of `bank, byte, count, dst`).

### Repaint regions

Restoring the engine state alone fixes future bookkeeping but does not retroactively repaint the playfield buffers (`$50` shadow, `$01` visible). Whatever drifted pixels were last painted stay on screen. Repaint regions copy bytes from a source bank (typically a screen's PAK-loaded art) to a destination column range so the visible playfield matches the canonical engine state.

A typical pre-climb deferred snap defines two regions: the left-of-center screen art on cols `0..N-1` and the right-of-center screen art on cols `N..109`, where `N` is determined by `world_offset` and each screen's world origin.

---

## How It Works

### 1. Pre-transition (Deferred Snap)

Before climbing:

- Queue a known-good state via `OP_SNAPSTATE_DEFER`. The opcode itself only sets a pending flag — it does not modify engine state when the script reaches it.
- The pending state is applied at the *first* `scroll_up` call (i.e., the moment the climb actually starts). Deferring matters: applying the snap immediately would teleport the player visibly. Applying it at climb-start hides the (small) corrective shift inside the climb's vertical motion, where the eye is forgiving.

---

### 2. Transition (Climbing)

- Camera behavior is temporarily overridden
- Normal push-scroll logic is suspended

---

### 3. Post-transition (Commit State)

After climbing:

- Apply a second Golden State via `OP_SNAPSTATE` (immediate, no defer).
- This runs after `snap_transition` has already run the climb's natural cleanup, and overwrites engine state with the canonical post-climb values.
- This becomes the new baseline.

### Engine fixes that are NOT solved by Golden States alone

Some drift sources are structural rather than historical and require engine-side fixes:

- **Linear-layout assumption**: `snap_transition` originally set `scroll_lsrc_bank = $02 + current_screen`, which assumes screens are arranged linearly by bank index. For non-linear layouts (e.g., scr10's actual left-neighbor is scr8 = bank `$0B`, not scr9 = `$0C`), the snap must use `scroll_up_lbank` from `OP_UP` instead, with `scroll_lsrc_off = lwidth - up_dst_start - 1` so left-scroll continues seamlessly from where the climb's lgap fill stopped.
- **`OP_LEFT` clobbering snap state**: an `OP_LEFT,N` after the climb would reset `scroll_lsrc_off` to 109, undoing the snap's careful continuation. Fix: `OP_LEFT` preserves `scroll_lsrc_off` when the requested target bank already matches the current `scroll_lsrc_bank`.

---

## Why This Works

Ladders are not free-movement scenarios. They are:

**Authored transitions**

---

## Key Insight

You cannot reconstruct the camera from the player.  
So you restore the camera when correctness matters.

---

## Mental Model

Free movement:
    camera = dynamic, history-dependent

Critical transitions:
    camera = authored, deterministic

---

## Invariant (Always Enforce)

abs_x == world_offset + IMAGE01_XPOS

This is checked every frame by `assert_abs_x` (game.s) after every position-mutating pass (`process_input`, `update_anims`). Any code that updates one of these three values must update at least one other to preserve the invariant.

---

## Summary (One Line)

Camera drift exists because the camera has memory.  
Golden States remove ambiguity by restoring known-good memory.
