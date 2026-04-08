# DDIIGS

Apple IIgs beat-em-up game built in 65816 assembly using Merlin32.

## Build

```
make package
```

Assembles `src/mission1.s` and `src/title.s` with `merlin32`, packs SHR assets with `tools/packbytes.py`, creates an 800KB ProDOS volume (`out/ddiigs.po`), and copies all files onto it using `cadius`.

```
make clean
```

Removes the `out/` directory.

### Dependencies

- `merlin32` — Merlin32 cross-assembler for 65816
- `cadius` — ProDOS disk image utility
- `python3` — for `tools/packbytes.py` (PackBytes compression)

## Project structure

- `src/mission1.s` — Main game source (ORG $2000)
- `src/title.s` — Title screen (ORG $2000)
- `assets/` — SHR graphics (.shr), packed versions (.pak generated at build time), sprite source sheets
- `res/` — ProDOS system files (`PRODOS`, `BASIC.SYSTEM`)
- `tools/` — Build tools (`packbytes.py`)
- `out/` — Build output (generated)

## Architecture

The program runs on the Apple IIgs in 320-mode Super Hi-Res with SHR shadowing enabled (bank $01 writes shadow to $E1). On startup it:

1. Initializes IIgs Toolbox (Tool Locator, Misc Tools, Memory Manager, QuickDraw II)
2. Enables SHR shadowing ($C035 bit 3 cleared) before any screen writes
3. Loads MISSION11.PAK through MISSION15.PAK to bank $4F via ProDOS 8, unpacks each with `_UnPackBytes` ($2703) to banks $50-$54
4. Copies $50 to $01 for initial screen display
5. Draws HUD text via QuickDraw II `DrawCString`
6. Enters the main game loop

### Game loop

```
game_loop:
  wait_for_vbl
  disable_shadowing     ; prevent mid-frame tearing
  erase_all             ; erase dirty sprites at their PREVIOUS positions
  process_input         ; keyboard input for player sprite
  update_npcs           ; Bresenham-based NPC AI seeking toward player
  update_anims          ; advance animation timers, change frames
  draw_all              ; draw dirty sprites at their CURRENT positions
  enable_shadowing      ; atomic screen update via shadow
  loop
```

### Sprite table system

All sprites are managed through `sprite_table` — a null-terminated array of 2-byte pointers to sprite info blocks. The game loop iterates this table for erase, draw, and animation updates. No sprite is special-cased.

**Sprite info block layout (40 bytes):**

| Offset | Field | Description |
|--------|-------|-------------|
| +0 | ypos | Y position on screen |
| +2 | xpos | X position on screen |
| +4 | mirror | 0=normal, 1=flipped horizontally |
| +6 | anim_step | (legacy, unused) |
| +8 | anim_count | (legacy, unused) |
| +10 | frame_x | Current frame width in bytes |
| +12 | frame_y | Current frame height in lines |
| +14 | frame_addr | 2-byte pointer to current frame data |
| +16 | mask | Transparent color byte (e.g. $66 for Billy, $EE for William) |
| +18 | maskhi | High nibble mask (e.g. $60) |
| +20 | masklo | Low nibble mask (e.g. $06) |
| +22 | controller | $01=keyboard player, $00=NPC |
| +24 | anim_ptr | 2-byte pointer to animation descriptor ($0000=none) |
| +26 | anim_frame | Current frame index within animation |
| +28 | anim_timer | VBL countdown for current frame |
| +30 | dirty | Bit flags: bit0=needs_draw, bit1=needs_erase |
| +32 | prev_ypos | Y position where sprite was last drawn |
| +34 | prev_xpos | X position where sprite was last drawn |
| +36 | prev_frame_x | Frame width when last drawn |
| +38 | prev_frame_y | Frame height when last drawn |

### Dirty flag system

Sprites use a 2-bit dirty flag to minimize unnecessary erase/draw:

- **bit 0** (needs_draw): set by `save_sprite`, cleared by `draw_all` after drawing
- **bit 1** (needs_erase): set by `save_sprite`, cleared by `erase_all` after erasing

`save_sprite` copies the current position to prev fields BEFORE writing new values, then sets dirty=$03 (both bits). `erase_all` uses prev position fields to erase at the old drawn location. After erasing, it sets bit 0 to ensure the sprite gets redrawn. `mark_overlapping` checks if the erased rectangle intersects other sprites and marks them for redraw if so.

### Data-driven animation system

Animations are descriptors, not code:

```
anim_jump:
  dfb 3          ; num_frames
  dfb $0F        ; max_width (widest frame, for erase)
  dfb $01        ; flags: bit0=advance position per VBL, bit1=loop
  ; per frame (5 bytes each):
  dfb $0A,$28,3  ; frame_x, frame_y, duration_vbls
  da JUMP1       ; frame_addr (2 bytes)
  ...
```

`update_anims` iterates the sprite table, decrements timers, advances frames, handles looping/termination, position advancement, and punch hit detection. `start_anim` begins an animation by setting anim_ptr, loading the first frame, and setting the timer.

Walk animation uses a separate `advance_walk` subroutine (one frame per keypress, not timer-driven) with a toggle for advancing every 2nd keypress.

Action animations (jump, kick, punch1, punch2) block all input while active. Walk allows interruption.

### Y-sort sprite ordering

When a sprite changes Y position, `resort_sprite_table` rebuilds the table sorted by Y (ascending). Sprites higher on screen are drawn first and appear behind sprites lower on screen, providing correct Z-ordering. Uses insertion sort into `sprite_table_copy`, then copies back.

`process_input` finds the player sprite by scanning for `controller=$01` rather than assuming table position.

### NPC AI

`npc_seek_player` uses Bresenham's line algorithm to move an NPC one step toward the keyboard player each frame. The error accumulator persists between calls for smooth diagonal movement. `update_npcs` calls this for every sprite with `controller=$00`.

### Key routines

- `toolbox_init` — Starts TL, MT, MM; allocates QD direct page; starts QD
- `load_and_unpack` — Loads .PAK file to bank $4F via ProDOS 8, calls `_UnPackBytes` to decompress to target bank. Uses GET_EOF for accurate source length.
- `load_to_bank` — ProDOS 8 open/read(4KB chunks)/close into a single bank
- `erase` — Restores sprite rectangle from shadow copy ($50) to screen ($01)
- `draw_sprite` — Plots current frame with transparency masking (normal or mirrored path)
- `scroll_right` — Shifts playfield left in $50, fills right edge from scroll source bank, triple-buffers via $55 to prevent tearing
- `fast_blit_50_55` — Unrolled LDAL/STAL blit using LUP macro
- `stack_blit_55_e1` — Stack-based blit via WrCardRAM ($C005), SEI required
- `check_punch_hit` — Iterates sprite table checking bounding box overlap with the punching sprite. Changes border color on hit.
- `mark_overlapping` — After erasing, checks if erased area intersects other sprites and marks them dirty
- `resort_sprite_table` — Insertion-sorts sprite table by Y position
- `npc_seek_player` — Bresenham NPC movement toward player

### Memory map

| Address | Contents |
|---------|----------|
| `$00/2000` | Program code + data (ORG $2000) |
| `$00/6C00` | ProDOS I/O buffer (1KB) |
| `$00/7000` | File read buffer (4KB) |
| `$01/2000` | SHR screen memory (via shadowing from bank $01 to $E1) |
| `$4F/2000` | Temporary buffer for packed file loading |
| `$50/2000` | Shadow copy of playfield (scrollable, erased from) |
| `$51/2000` | MISSION12 (second screen for scrolling) |
| `$52/2000` | MISSION13 |
| `$53/2000` | MISSION14 |
| `$54/2000` | MISSION15 |
| `$55/2000` | Back buffer for scroll compositing |

### ZP usage

| Address | Purpose |
|---------|---------|
| `$E0-$E1` | `spr_ptr` — current position in sprite_table |
| `$E2-$E3` | `info_ptr` — pointer to current sprite info block |
| `$E4-$E5` | `anim_ptr` — pointer to animation descriptor |
| `$E6-$E7` | `sort_src` — source pointer for sprite table sort |
| `$E8-$E9` | `sort_dst` — destination pointer for sprite table sort |
| `$F0-$F2` | Indirect long pointer (source) for copy/blit routines |
| `$F3-$F5` | Indirect long pointer (destination) for copy/blit routines |

### Sprite format

Sprites are packed 4-bit pixel data. Each sprite has its own transparent color (mask byte). Billy uses $66, William uses $EE. Masking handles three cases: fully transparent (both nibbles match mask), half-transparent high nibble, half-transparent low nibble.

The mirrored draw path reads sprite bytes in reverse order per line and swaps nibbles (high<->low) since SHR packs two pixels per byte.

## Assembly conventions

- Merlin32 syntax: `]` prefix for variable labels, `:` prefix for local labels
- Variable labels (`]LOOP`) are reassigned as encountered — never branch forward to a `]` label that will be redefined; use local labels instead
- `BEQ`/`BNE`/`BCC`/`BCS` have +/-128 byte range; for distant targets use the inverted branch + `JMP` pattern
- **MX tracking**: Merlin32 tracks MX state linearly through source, not following control flow. Routines entered in native mode must have `REP $30` (or appropriate REP/SEP) at entry to sync the assembler. Code following native-mode routines that runs in emulation mode needs `MX %11` before its label. Getting this wrong silently assembles immediate operands at the wrong width, causing instruction misalignment.
- **Emulation mode** (`SEC/XCE`): required for ProDOS 8 calls. The main game loop runs in emulation mode.
- **Native mode** (`CLC/XCE`): required for IIgs Toolbox calls. `erase`, `draw_sprite`, blit routines switch to native internally and restore emulation on return.
- **`SEP $20` vs `SEC/XCE`**: Use `SEP $20` when you only need 8-bit accumulator but want to stay in native mode (avoids unnecessary mode switches). Only use `SEC/XCE` when emulation mode is actually required (ProDOS calls, main loop re-entry).
- `REP`/`SEP` have no effect in emulation mode — use paired 8-bit loads/stores for 16-bit values when in emulation mode
- **Merlin `*` in expressions**: `*` means current program counter, NOT multiplication. Pre-compute multiplied values as hex constants (e.g. `#$4620` not `#$2000+61*$A0`).
- **SHR shadowing**: With bit 3 of $C035 cleared, writes to bank $01 automatically mirror to $E1. All screen writes go to bank $01 for speed (fast RAM vs slow $E1). Shadowing can be toggled off during erase/draw and re-enabled afterward for atomic screen updates.
- **`BIT $C019` for VBL**: Must use 8-bit accumulator (`SEP $20`) — in 16-bit mode, BIT tests bit 15 of a 2-byte read instead of bit 7 of the VBL flag byte, causing infinite loops.
- **`_NewHandle` parameters**: Takes result space (4 bytes), blockSize (Long), userID (Word), attributes (Word). Does NOT take a location parameter — don't push extra values or the stack will be corrupted.
- **Toolbox call numbers**: Tool number in X register format: low byte = tool number, high byte = toolset number (e.g. $0202 = _MMStartup, toolset $02 tool $02).

## Common pitfalls

- **Erase at OLD position**: `save_sprite` copies current block values to prev fields before writing new values. `erase_all` loads prev fields into globals before erasing. This ensures erase happens where the sprite was actually drawn, not where it moved to.
- **Overlapping sprite invalidation**: When erasing sprite A wipes pixels belonging to sprite B, `mark_overlapping` detects the bounding box intersection and marks sprite B for redraw.
- **Wide erase for animations**: When an animation is active, `erase_all` uses the animation descriptor's `max_width` instead of the current frame width. This prevents trails when transitioning between frames of different widths.
- **Subroutine register clobber**: `erase` and `draw_sprite` both use X/Y internally. Callers must save loop variables to memory (not registers) across these calls.
- **Stack blit technique** (TN.IIGS.070): WrCardRAM ($C005) redirects all bank $00 writes to bank $01. Use SEI while stack is remapped. LDAL/STAL long addressing bypasses the bank switches.
- **Unrolled LUP blocks and branch range**: LUP-generated code easily exceeds +/-128 byte branch range. Use inverted branch + JMP.
- **Sprite table ordering**: After Y position changes, `resort_sprite_table` must be called. `process_input` finds the player by controller field, not table position.

## ProDOS volume

The disk image contains files with cadius type suffixes:
- `#FF0000` — SYS, load at $0000 (PRODOS)
- `#FF2000` — SYS, load at $2000 (BASIC.SYSTEM, MISSION1, TITLE)
- `#C10000` — PNT/$0000 (SHR graphics, uncompressed)
- `#C00000` — PIC/$0000 (PackBytes compressed SHR)
