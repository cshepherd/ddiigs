# D.uble Drag.n II: The Revenge (NES) - Apple IIgs

A fan-made recreation of D.uble Drag.n II (NES) for the Apple IIgs, written entirely in 65816 assembly language.

## Overview

This project is a from-scratch implementation of the classic beat-em-up arcade game for the Apple IIgs personal computer. It takes advantage of the IIgs's 65816 processor, Super Hi-Res 320-mode graphics, SHR hardware shadowing for tear-free rendering, and the Ensoniq DOC sound chip for music playback via the NinjaTrackerPlus (NTP) audio engine.

The game features:

- Smooth sprite animation with transparency masking and horizontal mirroring
- Multiple animation types: walking, jumping, kicking, two punch variants, hit reactions, and falling
- Data-driven animation system using compact bytecode descriptors
- Real-time combat with bounding-box hit detection, punch combos, and knockdowns
- Y-sorted sprite rendering for correct overlapping
- Dirty-flag rendering system that only redraws sprites that have changed
- SHR shadow register toggling for atomic screen updates
- Horizontal background scrolling with triple-buffered compositing
- Stack-based and unrolled blitters for high-performance screen updates
- PackBytes-compressed background art with runtime decompression
- Level scripting system for enemy spawning, progression gates, and screen transitions
- Separate cutscene engine with its own bytecode for narrative sequences
- Palette fade effects (fade to/from black) using a gamma-corrected lookup table
- NinjaTrackerPlus integration for background music

## Status

Although an extensive amount of stuff is implemented and many assets have been mastered into the game, this should still be considered a Proof Of Concept. It is known to be both unoptimized and incomplete, with weeks if not months of work necessary to finish, even with LLM assistance.

It is vital that I not be asked about the status of this project, if we wish for it to finish.

## Next Steps 4/12/2026

I think I can get a mostly-complete Level 1 demo complete by May 2026! June at the latest. But there's a whole lot of stuff to do first:

- Finish level scripts for mission 1, with implementation of all necessary operations (this week)
- Master at least the bare minimum sprites for Mission 1 NPCs: Roper, Linda Lash, Burnov (this is tedious work but at least the sprite sheets exist, 1-3 days)
- Remaster the terrible music; It sucks and we must do a lot better (1-2 days)
- (Probably) convert title.s to a cutscene script, implementing whatever cutscene script ops are necessary for that (1 day)
- Marry cutscene engine to game engine and let them live together in bank $00 from $2000-$8000 (1 day)
- NPC behavior scripts (this requires ALL of an NPC's sprites to be cut, ugh) (a week)
- At least try to pack everything into banks $00 through $10, I'd like for this to be a 1-meg game (optional, 1 day)
- Alternative title sequence with streaming audio (Dead Or Alive from DDII OST), for proposed mass-storage version of game (optional, 2 days)

## Architecture

The game is built with a clean separation between the engine and level data:

- **Game engine** (`game.s`) - The reusable core that handles rendering, input, animation, AI, combat, scrolling, and the level script interpreter. Contains no level-specific data. Runs from bank $00.
- **Level data** (`mission1.s`) - All data for a specific level: sprite pixel art, animation descriptors, sprite templates, screen map with background references, and the level script that controls enemy spawns and progression. Loaded to bank $02 at runtime.
- **Cutscene engine** (`cutscene.s`) - A separate bytecode interpreter for narrative sequences between levels, with graphics plotting, text rendering via QuickDraw II, and palette fading.
- **Cutscene data** (`cutscene1.s`) - Screens, text, graphics, and palettes for the Mission 1 intro cutscene.
- **Title screen** (`title.s`) - Self-contained title screen with animated logo reveal, palette effects, and music loading.

This architecture means a different beat-em-up game (or additional levels) can be created by providing new level data files — the engine binary doesn't change.

### Memory Layout

The game is designed to fit within a 1MB Apple IIgs RAM configuration:

| Bank(s) | Purpose |
|---------|---------|
| $00 | Engine code + runtime state |
| $01 | SHR screen (shadowed from $E1) |
| $02 | Level data (scripts, sprites, animation descriptors) |
| $03-$07 | Background art (2 screens per bank) |
| $0F | NinjaTrackerPlus audio engine |
| $10-$12 | Music data |
| $4F | Temporary decompression buffer |
| $50 | Playfield shadow (erase source) |
| $55 | Scroll compositing back buffer |

### Level Scripting

Levels are controlled by a simple bytecode language that runs one opcode per frame. The interpreter supports:

- Setting the active screen and loading backgrounds
- Spawning NPC enemies from sprite templates with position and facing direction
- Waiting for the player to reach a position threshold
- Waiting for all enemies to be defeated before proceeding
- Enabling directional scrolling between screens
- Locking scroll to the current screen

This allows level designers to script enemy encounters, progression gates, and screen transitions entirely through data.

### Rendering Pipeline

Each frame follows this sequence:

1. Wait for vertical blank
2. Disable SHR shadowing (writes go to bank $01 but aren't mirrored to $E1 yet)
3. Erase dirty sprites at their **previous** drawn positions using the playfield shadow
4. Check for overlapping sprites that need redrawing
5. Process player input
6. Execute level script (may spawn enemies, enable scrolling)
7. Advance animation timers and update frames
8. Draw dirty sprites at their **current** positions
9. Re-enable SHR shadowing (bank $01 atomically mirrors to $E1)

The dirty flag system ensures only sprites that actually changed are erased and redrawn, reducing flicker. Sprites track their previous position separately from their current position so erasing happens at the correct location.

## Building

### Requirements

- [Merlin32](https://github.com/lroathe/merlin32) - 65816 cross-assembler
- [CiderPress II / cadius](https://github.com/fadden/CiderPress2) - ProDOS disk image utility
- Python 3 - for the PackBytes compression tool

### Build Commands

```bash
# Build the disk image
make package

# Clean build artifacts
make clean
```

The build process:
1. Assembles all source files with Merlin32
2. Compresses background art SHR files using PackBytes
3. Creates an 800KB ProDOS disk image
4. Copies all binaries, compressed art, music, and system files to the volume

### Running

The output disk image (`out/ddiigs.po`) can be run in any Apple IIgs emulator (such as [GSplus](https://apple2.gs/plus/) or [KEGS](https://kegs.sourceforge.net/)) or transferred to real hardware via a storage device like a CFFA3000 or Floppy Emu.

Boot the disk image. BASIC.SYSTEM will load and you can run the programs:

- `TITLE` - Title screen with animated logo and music
- `CUTSCENE` - Mission 1 intro cutscene
- `GAME` - The main game

### Controls

| Key | Action |
|-----|--------|
| 8 | Move up |
| 2 | Move down |
| 4 | Move left (face left) |
| 6 | Move right (face right) |
| j | Jump |
| k | Kick |
| p | Punch (type 1) |
| P | Punch (type 2) |
| r | Scroll screen right |

## Technical Details

### Sprite System

Sprites use packed 4-bit SHR pixel data with per-sprite transparent colors. Each sprite byte contains two pixels. The renderer handles three transparency cases per byte: fully transparent, half-transparent high nibble, and half-transparent low nibble. The mirrored draw path reverses byte order per scanline and swaps nibbles within each byte.

Sprite data lives in bank $02 (loaded from the level file) and is accessed via indirect long addressing with a configurable bank byte. Animation descriptors define frame sequences with per-frame dimensions, duration, and pixel data pointers.

### Performance Optimizations

- **SHR shadowing**: All screen writes go to bank $01 (fast RAM) instead of bank $E1 (slow RAM with wait states). The hardware shadows writes to the video output.
- **Dirty flag rendering**: Only changed sprites are erased/redrawn each frame.
- **Shadow toggle**: Shadowing is disabled during the erase/draw pass and re-enabled after, providing atomic screen updates.
- **Unrolled blitters**: The scrolling engine uses Merlin's LUP macro to unroll 55 word copies per scanline, eliminating inner loop overhead.
- **Stack-based blitting**: The scroll compositing back-buffer blit remaps the stack to the SHR screen via WrCardRAM ($C005) and uses PHA for high-throughput writes.
- **PackBytes compression**: Background art is compressed on disk and decompressed at load time using the IIgs Toolbox `_UnPackBytes` call.

## Credits

Built with love for the Apple IIgs platform by [cCc], moggers of the iigsmaxxing scene.

Tools and libraries: Merlin32 cross-assembler, CiderPress II / cadius, NinjaTrackerPlus audio engine, II-Pix, UnSHR, Spriters Resource (Tomisaurus, Boberatu, broli1230).
