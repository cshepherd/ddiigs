# D.uble Drag.n II: The Revenge (NES) - Apple IIgs

A fan-made recreation of D.uble Drag.n II (NES) for the Apple IIgs, written entirely in 65816 assembly language.

## Overview

As you may know, there are two main lineages for this game: Arcade / PC (including Amiga, ST, et al), and NES / PCE. The former is what the Apple IIGS probably would have gotten in 1990 if the promised port ever happened. The latter is considered to be more playable (by me at least), and I found the assets to be quite useable, so this is a port of the latter, and I'm happy about that.

Despite my well-known fondness for Lucas' GTE tile engine, this is not a tiled game. It is simply captured artworks run through my special branch of ii-pix to lock palettes, then packed with _PackBytes and stitched together by the engine at runtime. You wouldn't guess it, but it works really well.

The engine holds a source-of-truth at bank \$18 (currently) that has the background in its currently-scrolled state with no sprites plotted. The rest of the story is something you've heard before: 'Erase' by copying sections of \$18 to \$01 while shadowing is off, then plot (hopefully compiled) sprites in $01, then turn shadowing on, and fast blit \$01 to \$01 after waiting for VBL.

Currently the engine supports both fast (compiled) and slow (not-compiled) sprites. The compiled sprites have a reverse AND mask and therefore support the usual LDA / AND / ORA / STA pipeline. The slow sprites have a designated 'transparent' color in addition to being soft-reversible, which all costs extra cycles. As you'd imagine, you can derive 80% of the benefit of compiled sprites (which are expensive on disk and in RAM) by compiling the 20% most-used sprites.

You should check out camera_drift_problem.md if you want to know about the major problem that anyone would face, tiled or not, when building a push-to-scroll game engine. This was the major problem I had to solve: That the background (art) state actually is not predictable for a given player X position, leading us to define certain "Golden States" and snap to them while climbing ladders. I'm proud of the solution.

## Status

We have a solid game engine with a great graphics pipeline; Make no mistake, the hard part is done and Mission 1 will likely ship in under a month! But boy-oh-boy there's plenty more stuff to do:
- A lot more character behaviors (sprites and scripts)
- A lot more encounters
- Sound engine: To begin with, this will likely be me loading the DOCRAM up with sounds and banging on the DOC registers. I've fiddled with BGM via NTPPlayer but the main problem is that my NES music conversions (made by ad-hoc Python scripts to convert VGM or MID to MOD which is then converted to NTP) are awful. BGM is thus deferred.
- Store 2 backgrounds per bank instead of one. Currently there's only one per bank which greatly simplifies scrolling math, but is wasteful and I'd like to try to reduce requirements to 1.25MB of RAM (currently we're sitting at 2MB).

You can check on things for yourself by booting the 800KB disk image at out/ddiigs.po, it boots to BASIC.SYSTEM.
- `-TITLE` to see Title Sequence (PoC)
- `-CUTSCENE` to see Mission 1 Cutscene (probably final, it uses the Cutscene Engine)
- `-GAME` to see the gameplay (about 25% of assets for Mission 1 are done, uses the new Level Scripting Engine at least)

It is vital that I not be asked about the status of this project, if we wish for it to finish.

### Level Scripting

Levels are controlled by a simple bytecode language that runs one opcode per frame. The interpreter supports:

- Setting the active screen and loading backgrounds
- Spawning NPC enemies from sprite templates with position and facing direction
- Waiting for the player to reach a position threshold
- Waiting for all enemies to be defeated before proceeding
- Enabling directional scrolling between screens
- Locking scroll to the current screen

This allows level designers to script enemy encounters, progression gates, and screen transitions entirely through data.

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
| p | Punch |

## Credits

Built with love for the Apple IIgs platform by [cCc], moggers of the iigsmaxxing scene.

Tools and libraries: Merlin32 cross-assembler, CiderPress II / cadius, NinjaTrackerPlus audio engine, II-Pix, UnSHR, Spriters Resource (Tomisaurus, Boberatu, broli1230).
