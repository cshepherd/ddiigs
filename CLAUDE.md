# DDIIGS

Apple IIgs game/tech demo built in 65816 assembly using Merlin32.

## Build

```
make package
```

This assembles `src/mission1.s` with `merlin32`, creates an 800KB ProDOS volume (`out/ddiigs.po`), and copies all assets and the binary onto it using `cadius`.

```
make clean
```

Removes the `out/` directory.

### Dependencies

- `merlin32` — Merlin32 cross-assembler for 65816
- `cadius` — ProDOS disk image utility

## Project structure

- `src/mission1.s` — Main source file (assembles to `mission1` binary, ORG $2000)
- `assets/` — SHR graphics: `mission11.shr` through `mission15.shr` (background screens), `billy1.shr` (sprite sheet)
- `res/` — ProDOS system files (`PRODOS`, `BASIC.SYSTEM`)
- `out/` — Build output (generated)

## Architecture

The program runs on the Apple IIgs in 320-mode Super Hi-Res. On startup it:

1. Initializes IIgs Toolbox (Tool Locator, Misc Tools, Memory Manager, QuickDraw II)
2. Loads `MISSION11.SHR` into SHR screen memory (`$E1/2000`) and a shadow copy (`$50/2000`) via ProDOS 8
3. Loads `MISSION12.SHR` through `MISSION15.SHR` into banks `$51`-`$54` at `$2000`
4. Draws HUD text via QuickDraw II `DrawCString`
5. Enters the main loop

### Main loop

- Waits for keypress, then erases sprite at old position, processes input, draws sprite at new position
- `8/2/4/6` — Move sprite up/down/left/right
- `r` — Scroll playfield right by 1 byte (2 pixels)
- Moving left sets `IMAGE01_MIRROR` and flips the sprite horizontally (nibble-swap per byte, reverse byte order per line)
- Moving horizontally cycles through 3 animation frames (IMAGE01/02/03) every 5 VBLs

### Key routines

- `toolbox_init` — Starts TL, MT, MM; allocates QD direct page; starts QD
- `load_background` — ProDOS 8 open/read/close, copies 32KB in 4KB chunks to `$E1` and `$50`
- `load_to_bank` — Same pattern, loads a file into a single bank
- `erase` — Restores sprite rectangle from shadow copy (`$50`) to screen (`$E1`)
- `DUMP01` — Plots current animation frame with `$AA` transparency masking (normal or mirrored path)
- `scroll_right` — Shifts playfield left in `$50`, fills right edge from `$51`, blits to `$E1`, redraws sprite
- `advance_frame` — Cycles animation step and updates `FRAME_X`/`FRAME_Y`/`FRAME_ADDR` from lookup tables

### Memory map

| Address | Contents |
|---------|----------|
| `$00/2000` | Program code + data (ORG $2000) |
| `$00/6C00` | ProDOS I/O buffer (1KB) |
| `$00/7000` | File read buffer (4KB) |
| `$50/2000` | Shadow copy of playfield (scrollable) |
| `$51/2000` | MISSION12.SHR (second screen for scrolling) |
| `$52/2000` | MISSION13.SHR |
| `$53/2000` | MISSION14.SHR |
| `$54/2000` | MISSION15.SHR |
| `$55/2000` | Back buffer for scroll compositing |
| `$E1/2000` | SHR screen memory (displayed) |

### Sprite format

Sprites are stored as packed 4-bit pixel data with `$AA` as the transparent color. Masking handles three cases: fully transparent byte (`$AA`), half-transparent high nibble (`$A0`), and half-transparent low nibble (`$0A`).

## Assembly conventions

- Merlin32 syntax: `]` prefix for variable labels, `:` prefix for local labels
- Variable labels (`]LOOP`, `]MLOOP`) are reassigned as encountered — do not use `BEQ`/`BNE` to branch forward to a `]` label that will be redefined later; use local labels (`:label`) for branch targets instead
- `BEQ`/`BNE` have a +/-128 byte range limit; for distant targets use the inverted branch + `JMP` pattern (e.g., `BNE :near` / `JMP far`)
- The main loop runs in emulation mode; `DUMP01`, `erase`, and `copy_*` routines switch to native mode internally and restore emulation on exit
- **Critical MX tracking rule**: Merlin32 tracks MX state linearly through the source, not following control flow. Routines called in native 16-bit mode must have `REP $30` at their entry to sync the assembler's tracking. Routines following native-mode code that run in emulation mode need `MX %11` before their label. Without this, immediate operand sizes (`LDA #`, `LDX #`, `ADC #`) will be assembled for the wrong width, causing instruction misalignment at runtime.
- ProDOS 8 calls require emulation mode; toolbox calls require native 16-bit mode
- `REP`/`SEP` have no effect in emulation mode — use paired 8-bit loads/stores for 16-bit values when in the main loop
- ZP `$F0-$F5` are used as indirect long pointers by copy routines (src at `$F0-$F2`, dst at `$F3-$F5`)

## ProDOS volume

The disk image contains files with cadius type suffixes:
- `#FF0000` — BIN, load at $0000 (PRODOS)
- `#FF2000` — BIN, load at $2000 (BASIC.SYSTEM, MISSION1)
- `#C10000` — PNT/$0000 (SHR graphics)
