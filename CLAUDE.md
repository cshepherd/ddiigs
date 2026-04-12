# DDIIGS

Apple IIgs beat-em-up game built in 65816 assembly using Merlin32.

## Build

```
make package
```

Assembles `src/game.s` (engine), `src/mission1.s` (level data), `src/cutscene.s` (cutscene engine), `src/cutscene1.s` (cutscene data), and `src/title.s` (title screen) with `merlin32`, packs SHR assets with `tools/packbytes.py`, creates an 800KB ProDOS volume (`out/ddiigs.po`), and copies all files onto it using `cadius`.

```
make clean
```

Removes the `out/` directory.

### Dependencies

- `merlin32` — Merlin32 cross-assembler for 65816
- `cadius` — ProDOS disk image utility
- `python3` — for `tools/packbytes.py` (PackBytes compression)

## Project structure

- `src/game.s` — Game engine (ORG $2000, bank $00). Rendering, input, animation, AI, level script interpreter, file loading. No level-specific data.
- `src/mission1.s` — Level 1 data (ORG $020000, bank $02). Level script bytecode, sprite pixel data, sprite info block templates, animation descriptors, screen map, level header with sprite address table.
- `src/cutscene.s` — Cutscene rendering engine (ORG $2000). Bytecode interpreter for cutscene scripts, graphics plotting, text rendering via QuickDraw II, palette fade effects.
- `src/cutscene1.s` — Mission 1 cutscene data (ORG $020000, bank $02). Screens playlist, opcode sequences, text display lists, graphics assets, palette data.
- `src/title.s` — Title screen (ORG $2000). Self-contained with sprites, palette, fade effects, and file loading for NTP music and splash graphics.
- `assets/` — SHR graphics (.shr), packed versions (.pak generated at build time), sprite source sheets, NTP music
- `res/` — ProDOS system files (`PRODOS`, `BASIC.SYSTEM`), NTP player binary
- `tools/` — Build tools (`packbytes.py`)
- `out/` — Build output (generated)

## Architecture

### Engine / Level Data Separation

The game uses a split architecture:

- **Bank $00** (`game.s`): Reusable game engine. Contains all code (rendering, input, animation, AI, scrolling, level script interpreter, file loading) plus mutable runtime state (sprite info blocks, sprite tables, NPC buffers, globals). No level-specific pixel data.
- **Bank $02** (`mission1.s`): Level data loaded from disk at startup. Contains level script bytecode, sprite pixel data (read-only), sprite info block templates, animation descriptors, screen map, and a header with pointers to all sections including a sprite address table.

At startup, `init_level` reads the sprite address table offset from the bank $02 header ($02/0012), then reads 17 sprite addresses and patches the engine's animation descriptors, sprite info blocks, and walk tables. `draw_sprite` uses `sprite_bank` ($02) as the bank byte for indirect long addressing when reading pixel data.

This separation allows different levels (or different games) to ship different level data files with the same engine binary.

### Level Script System

Levels are driven by bytecode scripts defined in the level data file. The script interpreter (`run_script`) executes each frame as part of the game loop, using a state machine:

- **SCRIPT_RUN**: Executes opcodes sequentially until hitting a blocking op or END
- **SCRIPT_WAITX/WAITY**: Blocks until player crosses a position threshold
- **SCRIPT_WAITCLR**: Blocks until all NPC sprites are defeated (removed from sprite table)
- **SCRIPT_DONE**: Level complete

**Level script opcodes:**

| Opcode | Value | Params | Description |
|--------|-------|--------|-------------|
| OP_NONE | 0 | none | No operation |
| OP_SCREEN | 1 | 1b: screen index | Set current screen, load background |
| OP_WAITX | 2 | 1b: X threshold | Block until player X >= value |
| OP_NPC | 3 | 2b: sprite ptr, 1b: x, 1b: y, 1b: orient | Spawn NPC from template |
| OP_RIGHT | 4 | 1b: screen index | Enable rightward scrolling to screen |
| OP_LEFT | 5 | 1b: screen index | Enable leftward scrolling to screen |
| OP_UP | 6 | 1b: screen index | Enable upward scrolling |
| OP_DOWN | 7 | 1b: screen index | Enable downward scrolling |
| OP_SCRLOCK | 8 | none | Lock scrolling in current screen |
| OP_END | 9 | none | End of level |
| OP_WAITY | 10 | 1b: Y threshold | Block until player Y >= value |
| OP_WAITCLR | 11 | none | Block until all NPCs defeated |

NPC spawning (`script_spawn_npc`) copies a sprite info block template from bank $02 to a pre-allocated buffer in bank $00 (`npc_buffers`, 8 slots x 52 bytes), patches animation pointers to bank $00 addresses, sets position/orientation, and adds the sprite to the table.

### Cutscene System

Cutscenes use a separate bytecode interpreter (`cutscene.s`) with their own opcodes:

| Opcode | Value | Description |
|--------|-------|-------------|
| OP_CLS | 1 | Clear screen, palettes, and target palette buffer |
| OP_FADEIN | 2 | Fade from black to target palette over 16 VBL steps |
| OP_FADEOUT | 3 | Fade current palette to black over 16 VBL steps |
| OP_TEXT | 4 | Render text display list via QuickDraw II DrawCString |
| OP_GFX | 5 | Plot graphics sprite at x,y position |
| OP_WAIT | 6 | Wait specified number of VBL frames |
| OP_PALETTE | 7 | Load palette data to target buffer (for next FADEIN) |

Cutscene data is organized as a screens playlist (null-terminated list of screen pointers). Each screen is a sequence of opcodes terminated by $FFFF.

### Startup sequence (game.s)

1. Initialize IIgs Toolbox (Tool Locator, Misc Tools, Memory Manager, QuickDraw II)
2. Enable SHR shadowing ($C035 bit 3 cleared)
3. Load MISSION1 level data to bank $02 via ProDOS 8
4. `init_level`: read sprite address table from $02 header, patch engine structures, init level script pointer
5. Load NTPPLAYER to bank $0F, MISSION1.NTP to banks $10+
6. Load MISSION11-15.PAK, unpack to banks $03-$05 (background art)
7. Copy initial background to bank $01 (screen via shadowing)
8. Draw HUD text via QuickDraw II
9. Initial `draw_all` to render player sprite
10. Enter main game loop

### Game loop

```
game_loop:
  wait_for_vbl
  disable_shadowing     ; prevent mid-frame tearing
  erase_all             ; erase dirty sprites at PREVIOUS positions
  process_input         ; keyboard input for player sprite
  run_script            ; advance level script (spawn NPCs, check conditions)
  update_anims          ; advance animation timers, change frames
  draw_all              ; draw dirty sprites at CURRENT positions
  enable_shadowing      ; atomic screen update via shadow
  loop
```

### Memory map

| Bank | Address | Contents |
|------|---------|----------|
| $00 | $2000+ | Engine code (game.s binary) |
| $00 | various | Sprite info blocks, sprite table, NPC buffers (416 bytes), animation descriptors, globals |
| $00 | $6C00-$6FFF | ProDOS I/O buffer (1KB) |
| $00 | $7000-$7FFF | File read buffer (4KB) |
| $01 | $2000-$9FFF | SHR screen memory (via shadowing to $E1) |
| $02 | $0000+ | Level data: header, sprite address table, level script, screen map, sprite pixel data |
| $03 | $0000/$8000 | Backgrounds 0,1 (2 per bank, 32KB each) |
| $04 | $0000/$8000 | Backgrounds 2,3 |
| $05 | $0000/$8000 | Backgrounds 4,5 |
| $06-$07 | $0000/$8000 | Room for more backgrounds |
| $0F | $0000+ | NTP player code |
| $10-$12 | $0000+ | NTP music data |
| $4F | $0000+ | Temporary buffer for PAK decompression |
| $50 | $2000-$9FFF | Shadow copy of current playfield (erase source) |
| $55 | $2000-$9FFF | Back buffer for scroll compositing |

### Level data format (bank $02)

**Level header** (20 bytes at $020000):

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
| $0E | 2 | level_script offset |
| $10 | 2 | npc_script offset (TBD) |
| $12 | 2 | sprite_address_table offset |

**Sprite address table**: 17 entries of 2-byte bank $02 addresses (IMAGE01-03, JUMP1-3, KICK1-2, PUNCH11/12/21/22, BPUNCHED, WILLIAM1, WPUNCHED, WFALL, WFALLEN). `init_level` reads the table offset from $02/0012, then uses the table to patch engine structures.

**Screen map**: Per-screen entries with bg_bank, bg_half ($00/$80 for low/high 32KB), directional links (right/left/up/down as screen indices, $FFFF=wall), and PAK filename for background art loading.

### Sprite table system

`sprite_table` is a null-terminated array of 2-byte pointers to sprite info blocks. The player (billy_sprite) is always present. NPCs are added dynamically by the level script via `script_spawn_npc`.

**Sprite info block layout (52 bytes):**

| Offset | Field | Description |
|--------|-------|-------------|
| +0 | ypos | Y position on screen |
| +2 | xpos | X position on screen |
| +4 | mirror | 0=normal, 1=flipped horizontally |
| +6 | (unused) | Legacy field |
| +8 | (unused) | Legacy field |
| +10 | frame_x | Current frame width in bytes |
| +12 | frame_y | Current frame height in lines |
| +14 | frame_addr | 2-byte pointer to frame pixel data (bank $02 address) |
| +16 | mask | Transparent color byte ($66=Billy, $EE=William) |
| +18 | maskhi | High nibble mask |
| +20 | masklo | Low nibble mask |
| +22 | controller | $01=keyboard player, $00=NPC |
| +24 | anim_ptr | 2-byte pointer to animation descriptor (bank $00, $0000=none) |
| +26 | anim_frame | Current frame index within animation |
| +28 | anim_timer | VBL countdown for current frame |
| +30 | dirty | Bit flags: bit0=needs_draw, bit1=needs_erase |
| +32 | prev_ypos | Y where sprite was last drawn |
| +34 | prev_xpos | X where sprite was last drawn |
| +36 | prev_frame_x | Frame width when last drawn |
| +38 | prev_frame_y | Frame height when last drawn |
| +40 | punched_anim | 2-byte pointer to punched animation (bank $00) |
| +42 | idle_addr | 2-byte pointer to idle frame pixel data (bank $02) |
| +44 | idle_x | Idle frame width |
| +46 | idle_y | Idle frame height |
| +48 | punch_count | Times this sprite has been punched |
| +50 | fall_anim | 2-byte pointer to fall animation (bank $00) |

### Dirty flag system

- **bit 0** (needs_draw): set by `save_sprite`, cleared by `draw_all`
- **bit 1** (needs_erase): set by `save_sprite`, cleared by `erase_all`

`save_sprite` snapshots current position to prev fields before writing new values. `erase_all` uses prev fields to erase at the old drawn position, then sets bit 0 for redraw. `mark_overlapping` checks if erased area intersects other sprites.

### Data-driven animation system

Animations are descriptors: header (num_frames, max_width, flags) + per-frame data (frame_x, frame_y, duration, frame_addr). `update_anims` iterates sprites, decrements timers, advances frames. Walk uses `advance_walk` (one frame per 2nd keypress). Action animations block input.

### Combat system

`check_punch_hit` iterates sprites for bounding box overlap. On hit: starts punched_anim on target. At punch_count 3: fall_anim. At punch_count 6: fall_anim then death ($FFFF sentinel removes sprite from table).

NPC sprite blocks copied from bank $02 templates get their animation pointers (`punched_anim`, `fall_anim`) patched to bank $00 addresses by `script_spawn_npc`, since animation descriptors are accessed via `(anim_ptr),Y` which only reads bank $00.

### Key routines (game.s)

- `init_level` — Reads sprite address table offset from header, patches engine structures
- `run_script` — Level script bytecode interpreter (state machine, called each frame)
- `script_spawn_npc` — Copies sprite template from $02 to NPC buffer, patches pointers, adds to table
- `load_and_unpack` — Loads .PAK, calls `_UnPackBytes` to decompress
- `load_ntp_file` — Multi-bank file loader via ProDOS 8
- `erase` / `draw_sprite` — Sprite rendering with cross-bank pixel data access
- `check_punch_hit` — Hit detection with sprite table iteration
- `mark_overlapping` — Invalidates sprites overlapping erased areas
- `resort_sprite_table` — Y-sort for draw order
- `npc_seek_player` — Bresenham NPC movement (available but currently disabled, pending NPC scripts)

### ZP usage

| Address | Purpose |
|---------|---------|
| $E0-$E1 | `spr_ptr` — current position in sprite_table |
| $E2-$E3 | `info_ptr` — pointer to current sprite info block |
| $E4-$E5 | `anim_ptr` — pointer to animation descriptor |
| $E6-$E7 | `sort_src` — source pointer for sprite table sort |
| $E8-$E9 | `sort_dst` — destination pointer for sprite table sort |
| $EA-$EC | `script_pc` — 3-byte pointer to level script position (bank $02) |
| $F0-$F2 | Indirect long pointer (source) for copy/blit routines |
| $F3-$F5 | Indirect long pointer (destination) for copy/blit routines |

## Assembly conventions

- Merlin32 syntax: `]` prefix for variable labels, `:` prefix for local labels
- Variable labels are reassigned as encountered — never branch forward to a `]` label that will be redefined
- `BEQ`/`BNE`/`BCC`/`BCS` have +/-128 byte range; use inverted branch + `JMP` for distant targets
- **MX tracking**: Merlin32 tracks MX linearly, does NOT track `CLC/XCE` or `SEC/XCE`. Use explicit `MX %00` or `MX %11` directives after mode switches.
- **Emulation mode** (`SEC/XCE`): required for ProDOS 8 calls. Main game loop runs in emulation mode.
- **Native mode** (`CLC/XCE`): required for IIgs Toolbox calls. `erase`, `draw_sprite`, blit routines switch internally.
- `REP`/`SEP` have no effect in emulation mode
- Merlin `*` in expressions means current PC, NOT multiplication. Pre-compute as hex constants.
- **SHR shadowing**: Bit 3 of $C035 cleared = bank $01 shadows to $E1. Toggle off during rendering for atomic updates.
- **`BIT $C019`**: Must use 8-bit A — 16-bit tests wrong bit, infinite loop.
- **ProDOS pathnames**: Count length bytes carefully. Off-by-one = silent OPEN failure.
- **Cross-bank pointers**: `frame_addr`/`idle_addr` hold bank $02 addresses (for draw_sprite via sprite_bank). `anim_ptr`/`punched_anim`/`fall_anim` must hold bank $00 addresses (read via `(dp),Y`). NPC spawn patching is required.
- **Local label scope**: Merlin `:` labels are scoped to nearest global label. Data shared across subroutines must use global labels.
- **Level header indirection**: Always read offsets from the header rather than hardcoding byte positions. Adding fields shifts everything.

## ProDOS volume

| Suffix | Type | Files |
|--------|------|-------|
| `#FF0000` | SYS, load $0000 | PRODOS |
| `#FF2000` | SYS, load $2000 | BASIC.SYSTEM, GAME, CUTSCENE, TITLE |
| `#060000` | BIN, load $0000 | MISSION1, NTPPLAYER |
| `#040000` | BIN, load $0000 | CUTSCENE1 |
| `#C10000` | PNT/$0000 | CCC.SHR (uncompressed SHR) |
| `#C00000` | PIC/$0000 | MISSION11-15.PAK (compressed SHR) |
| `#000000` | unknown | TITLE.NTP, MISSION1.NTP |
