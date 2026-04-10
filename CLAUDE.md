# DDIIGS

Apple IIgs beat-em-up game built in 65816 assembly using Merlin32.

## Build

```
make package
```

Assembles `src/game.s` (engine), `src/mission1.s` (level data), and `src/title.s` (title screen) with `merlin32`, packs SHR assets with `tools/packbytes.py`, creates an 800KB ProDOS volume (`out/ddiigs.po`), and copies all files onto it using `cadius`.

```
make clean
```

Removes the `out/` directory.

### Dependencies

- `merlin32` — Merlin32 cross-assembler for 65816
- `cadius` — ProDOS disk image utility
- `python3` — for `tools/packbytes.py` (PackBytes compression)

## Project structure

- `src/game.s` — Game engine (ORG $2000, bank $00). Rendering, input, animation, AI, file loading. No level-specific data.
- `src/mission1.s` — Level 1 data (ORG $020000, bank $02). Sprite pixel data, sprite info blocks, animation descriptors, screen map, level header.
- `src/title.s` — Title screen (ORG $2000). Self-contained with its own sprites, palette, and file loading for NTP music.
- `assets/` — SHR graphics (.shr), packed versions (.pak generated at build time), sprite source sheets, NTP music
- `res/` — ProDOS system files (`PRODOS`, `BASIC.SYSTEM`), NTP player binary
- `tools/` — Build tools (`packbytes.py`)
- `out/` — Build output (generated)

## Architecture

### Engine / Level Data Separation

The game uses a split architecture:

- **Bank $00** (`game.s`): Reusable game engine. Contains all code (rendering, input, animation, AI, scrolling, file loading) plus mutable runtime state (sprite info blocks, sprite tables, globals). No level-specific pixel data.
- **Bank $02** (`mission1.s`): Level data loaded from disk at startup. Contains sprite pixel data (read-only), animation descriptors, screen map with background art references, and a header with pointers to all sections.

At startup, `init_level` reads a sprite address table from the bank $02 header and patches all frame address pointers in the engine's animation descriptors, sprite info blocks, and walk tables to reference bank $02 addresses. `draw_sprite` uses `sprite_bank` ($02) as the bank byte for indirect long addressing when reading pixel data.

This separation allows different levels (or different games) to ship different level data files with the same engine binary.

### Startup sequence

1. Initialize IIgs Toolbox (Tool Locator, Misc Tools, Memory Manager, QuickDraw II)
2. Enable SHR shadowing ($C035 bit 3 cleared)
3. Load MISSION1 level data to bank $02 via ProDOS 8
4. `init_level`: read sprite address table from $02, patch engine structures
5. Load NTPPLAYER to bank $0F, MISSION1.NTP to banks $10+
6. Load MISSION11-15.PAK, unpack to banks $03-$05 (background art)
7. Copy bank $50 to bank $01 (initial screen via shadowing)
8. Draw HUD text via QuickDraw II
9. Initial `draw_all` to render all sprites
10. Enter main game loop

### Game loop

```
game_loop:
  wait_for_vbl
  disable_shadowing     ; prevent mid-frame tearing
  erase_all             ; erase dirty sprites at PREVIOUS positions
  process_input         ; keyboard input for player sprite
  update_npcs           ; Bresenham NPC AI seeking toward player
  update_anims          ; advance animation timers, change frames
  draw_all              ; draw dirty sprites at CURRENT positions
  enable_shadowing      ; atomic screen update via shadow
  loop
```

### Memory map

| Bank | Address | Contents |
|------|---------|----------|
| $00 | $2000-~$3700 | Engine code (game.s binary) |
| $00 | $6C00-$6FFF | ProDOS I/O buffer (1KB) |
| $00 | $7000-$7FFF | File read buffer (4KB) |
| $00 | various | Sprite info blocks, sprite table, animation descriptors, globals (mutable, patched at init) |
| $01 | $2000-$9FFF | SHR screen memory (via shadowing from bank $01 to $E1) |
| $02 | $0000+ | Level data: header, screen map, sprite pixel data (mission1 binary) |
| $03 | $0000/$8000 | Backgrounds 0,1 (2 per bank, 32KB each) |
| $04 | $0000/$8000 | Backgrounds 2,3 |
| $05 | $0000/$8000 | Backgrounds 4,5 |
| $06-$07 | $0000/$8000 | Room for more backgrounds |
| $0F | $0000+ | NTP player code |
| $10-$12 | $0000+ | NTP music data |
| $4F | $0000+ | Temporary buffer for PAK decompression |
| $50 | $2000-$9FFF | Shadow copy of current playfield (erase source, copied from active background) |
| $55 | $2000-$9FFF | Back buffer for scroll compositing |

### Level data format (bank $02)

**Level header** (18 bytes at $020000):

| Offset | Size | Field |
|--------|------|-------|
| $00 | 1 | num_screens |
| $01 | 1 | initial_screen |
| $02 | 1 | player_spawn_x |
| $03 | 1 | player_spawn_y |
| $04 | 2 | screen_map offset |
| $06 | 2 | sprite_table offset |
| $08 | 2 | sprite_data offset (TBD) |
| $0A | 2 | mask_data offset (TBD) |
| $0C | 2 | anim_descriptors offset |
| $0E | 2 | level_script offset (TBD) |
| $10 | 2 | npc_script offset (TBD) |

**Sprite address table** (34 bytes at $020012): 17 entries of 2-byte bank $02 addresses, one per sprite graphic (IMAGE01, IMAGE02, IMAGE03, JUMP1-3, KICK1-2, PUNCH11/12/21/22, BPUNCHED, WILLIAM1, WPUNCHED, WFALL, WFALLEN). Read by `init_level` to patch engine structures.

**Screen map**: Per-screen entries with bg_bank, bg_half ($00/$80 for low/high 32KB), directional links (right/left/up/down as screen indices, $FFFF=wall), and PAK filename for background art.

### Sprite table system

All sprites are managed through `sprite_table` — a null-terminated array of 2-byte pointers to sprite info blocks. The game loop iterates this table for erase, draw, animation updates, and NPC AI.

**Sprite info block layout (52+ bytes):**

| Offset | Field | Description |
|--------|-------|-------------|
| +0 | ypos | Y position on screen |
| +2 | xpos | X position on screen |
| +4 | mirror | 0=normal, 1=flipped horizontally |
| +6 | (unused) | Legacy anim_step |
| +8 | (unused) | Legacy anim_count |
| +10 | frame_x | Current frame width in bytes |
| +12 | frame_y | Current frame height in lines |
| +14 | frame_addr | 2-byte pointer to current frame pixel data (bank $02 address) |
| +16 | mask | Transparent color byte ($66 for Billy, $EE for William) |
| +18 | maskhi | High nibble mask |
| +20 | masklo | Low nibble mask |
| +22 | controller | $01=keyboard player, $00=NPC |
| +24 | anim_ptr | 2-byte pointer to animation descriptor ($0000=none) |
| +26 | anim_frame | Current frame index within animation |
| +28 | anim_timer | VBL countdown for current frame |
| +30 | dirty | Bit flags: bit0=needs_draw, bit1=needs_erase |
| +32 | prev_ypos | Y where sprite was last drawn |
| +34 | prev_xpos | X where sprite was last drawn |
| +36 | prev_frame_x | Frame width when last drawn |
| +38 | prev_frame_y | Frame height when last drawn |
| +40 | punched_anim | 2-byte pointer to punched animation descriptor |
| +42 | idle_addr | 2-byte pointer to idle frame pixel data (bank $02 address) |
| +44 | idle_x | Idle frame width |
| +46 | idle_y | Idle frame height |
| +48 | punch_count | Times this sprite has been punched |
| +50 | fall_anim | 2-byte pointer to fall animation descriptor |

### Dirty flag system

- **bit 0** (needs_draw): set by `save_sprite`, cleared by `draw_all` after drawing
- **bit 1** (needs_erase): set by `save_sprite`, cleared by `erase_all` after erasing

`save_sprite` copies current position to prev fields BEFORE writing new values, then sets dirty=$03. `erase_all` uses prev fields to erase at the old position, then sets bit 0 to ensure redraw. `mark_overlapping` checks if the erased area intersects other sprites and marks them for redraw.

### Data-driven animation system

Animations are descriptors (data), not code:

```
anim_jump:
  dfb 3          ; num_frames
  dfb $0F        ; max_width (widest frame, for erase)
  dfb $01        ; flags: bit0=advance position per VBL, bit1=loop
  ; per frame (5 bytes each):
  dfb $0A,$28,3  ; frame_x, frame_y, duration_vbls
  da JUMP1       ; frame_addr (2 bytes, bank $02 address)
  ...
```

`update_anims` iterates sprites, decrements timers, advances frames, handles looping/termination. `start_anim` begins an animation. Walk uses `advance_walk` (one frame per keypress with 2nd-press toggle).

Action animations (jump, kick, punch1, punch2) block all input. Walk allows interruption.

### Y-sort sprite ordering

`resort_sprite_table` rebuilds the table sorted by Y ascending when a sprite changes Y position. `process_input` finds the player by scanning for `controller=$01`.

### NPC AI

`npc_seek_player` uses Bresenham's line algorithm to move NPCs toward the player. `update_npcs` calls it for every `controller=$00` sprite.

### Hit detection and combat

`check_punch_hit` iterates sprites checking bounding box overlap with the punching sprite. On hit: increments border color, increments target's `punch_count`, starts punched_anim on target. At punch_count 3: fall_anim plays. At punch_count 6: fall_anim plays, then sprite is removed ($FFFF death sentinel).

Immunity: sprites playing fall_anim cannot be punched.

### Key routines (game.s)

- `init_level` — Reads sprite address table from bank $02 header, patches animation descriptors/sprite blocks/walk tables with bank $02 addresses
- `load_and_unpack` — Loads .PAK file to bank $4F, calls `_UnPackBytes` to decompress to target bank
- `load_ntp_file` — Loads file to specified bank via ProDOS 8 in 4KB chunks, handles multi-bank wrapping
- `erase` — Restores sprite rectangle from shadow copy ($50) to screen ($01)
- `draw_sprite` — Plots current frame with transparency masking (normal or mirrored). Reads pixel data from bank $02 via `sprite_bank`.
- `scroll_right` — Shifts playfield left in $50, fills right edge from scroll source bank, triple-buffers via $55
- `fast_blit_50_55` — Unrolled LDAL/STAL blit using LUP macro
- `stack_blit_55_e1` — Stack-based blit via WrCardRAM ($C005), SEI required
- `check_punch_hit` — Bounding box hit detection, starts punched/fall animations on target
- `mark_overlapping` — After erasing, marks intersecting sprites for redraw
- `resort_sprite_table` — Insertion-sorts sprite table by Y position
- `remove_from_sprite_table` — Shifts entries down to remove a dead sprite
- `npc_seek_player` — Bresenham NPC movement toward player
- `advance_walk` — Advances walk frame with 2nd-keypress toggle and extra step on IMAGE02 frames

### ZP usage

| Address | Purpose |
|---------|---------|
| $E0-$E1 | `spr_ptr` — current position in sprite_table |
| $E2-$E3 | `info_ptr` — pointer to current sprite info block |
| $E4-$E5 | `anim_ptr` — pointer to animation descriptor |
| $E6-$E7 | `sort_src` — source pointer for sprite table sort |
| $E8-$E9 | `sort_dst` — destination pointer for sprite table sort |
| $F0-$F2 | Indirect long pointer (source) for copy/blit routines |
| $F3-$F5 | Indirect long pointer (destination) for copy/blit routines |

### Sprite pixel format

Sprites are packed 4-bit pixel data in bank $02. Each sprite has its own transparent color (mask byte). Billy uses $66, William uses $EE. Masking handles: fully transparent (both nibbles match), half-transparent high nibble, half-transparent low nibble.

The mirrored draw path reads sprite bytes in reverse order per line and swaps nibbles.

## Assembly conventions

- Merlin32 syntax: `]` prefix for variable labels, `:` prefix for local labels
- Variable labels (`]LOOP`) are reassigned as encountered — never branch forward to a `]` label that will be redefined
- `BEQ`/`BNE`/`BCC`/`BCS` have +/-128 byte range; use inverted branch + `JMP` for distant targets
- **MX tracking**: Merlin32 tracks MX state linearly, not following control flow. Use `MX %00` after `CLC/XCE/REP $30` to force 16-bit tracking. Use `MX %11` before emulation-mode code that follows native-mode code. Merlin32 does NOT track `CLC/XCE` or `SEC/XCE` as mode switches — you MUST use explicit `MX` directives.
- **Emulation mode** (`SEC/XCE`): required for ProDOS 8 calls. Main game loop runs in emulation mode.
- **Native mode** (`CLC/XCE`): required for IIgs Toolbox calls. `erase`, `draw_sprite`, blit routines switch to native internally.
- **`SEP $20` vs `SEC/XCE`**: Use `SEP` when you only need 8-bit A in native mode. Only use `SEC/XCE` when emulation mode is required.
- `REP`/`SEP` have no effect in emulation mode — use paired 8-bit loads/stores for 16-bit values
- **Merlin `*` in expressions**: `*` means current program counter, NOT multiplication. Pre-compute multiplied values as hex constants.
- **SHR shadowing**: Bit 3 of $C035 cleared = writes to $01 shadow to $E1. Toggle off during erase/draw for atomic updates.
- **`BIT $C019` for VBL**: Must use 8-bit accumulator — 16-bit mode tests wrong bit, causing infinite loops.
- **`_NewHandle` parameters**: result space (4), blockSize (Long), userID (Word), attributes (Word). No location parameter.
- **ProDOS pathname length bytes**: Count carefully. Off-by-one causes silent OPEN failures (`bcs :err` skips silently).

## Common pitfalls

- **Erase at OLD position**: `save_sprite` snapshots current to prev before writing new values. `erase_all` loads prev fields.
- **Overlapping sprite invalidation**: `mark_overlapping` detects bounding box intersection after erase and marks affected sprites dirty.
- **Wide erase for animations**: `erase_all` uses animation descriptor's `max_width` instead of current frame width.
- **Subroutine register clobber**: `erase` and `draw_sprite` use X/Y internally. Save loop variables to memory.
- **Stack blit** (TN.IIGS.070): WrCardRAM ($C005) redirects bank $00 writes to $01. Use SEI. LDAL/STAL bypasses bank switches.
- **Sprite table ordering**: `resort_sprite_table` after Y changes. `process_input` finds player by controller field.
- **Cross-bank sprite data**: Sprite pixel data in bank $02. `draw_sprite` sets DP+6 from `sprite_bank`. `init_level` patches all frame address pointers from the level header's sprite address table at offset $12.
- **Level header offsets**: The sprite address table starts at offset $12 (18 bytes), NOT $18. Count header fields carefully (mix of dfb and dw).

## ProDOS volume

| Suffix | Type | Files |
|--------|------|-------|
| `#FF0000` | SYS, load $0000 | PRODOS |
| `#FF2000` | SYS, load $2000 | BASIC.SYSTEM, GAME |
| `#060000` | BIN, load $0000 | MISSION1, NTPPLAYER |
| `#C00000` | PIC/$0000 | MISSION11-15.PAK (compressed SHR) |
| `#000000` | unknown | TITLE.NTP, MISSION1.NTP |
