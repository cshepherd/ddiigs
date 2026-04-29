# DDII 2-Player Network Mode

## Goals

Networked 2-player co-op. Both players control a Lee brother — Billy (P1) and
Jimmy (P2, mechanically identical, palette-swapped red pants) — on separate
Apple IIgses connected via Uthernet II (Wiznet 5100S) cards. They fight the
same NPCs cooperatively against the same level script; the level ends when the
boss is defeated. No PvP, no anti-cheat, no spectators, no >2 players, no
support for IIgses without an Uthernet II card.

## Constraints

- Both machines presumed to be 8 MHz IIgses. Mixed-speed matches are out of
  scope.
- Game tick = VBL = 60 Hz. Simulation can't advance faster than display.
- DDII has no explicit RNG and the level script is deterministic, so given
  identical mission data + inputs both machines compute byte-identical state.
- One Uthernet II card per machine; we'll use 2 of its 4 sockets (lobby +
  peer).
- TCP for everything. All protocols are line-based ASCII terminated by `\n`.

## Architecture

Two TCP relationships per match:

1. **Lobby**: client → lobby server. A small Python program at a known address
   that maintains a list of waiting players sorted by ping. Anyone can host
   their own; client lets the user enter an address.
2. **Peer-to-peer**: client ↔ client, established once the lobby pairs them.
   Carries per-frame inputs + positions and hit events for the duration of
   the match. The lobby designates one side as TCP server (listener) and the
   other as TCP client (connector); after the peer link is up the lobby
   connection is dropped.

### Co-op lockstep with input delay K

Each side maintains a ring buffer of local and remote inputs indexed by frame
number.

```
frame N:
  read local controls -> INPUT_LOCAL[N]
  send "INP N <input> <abs_x> <ypos>" to peer
  drain incoming -> populate INPUT_REMOTE[their_frame]
  if INPUT_REMOTE[N - K] not yet received:
      stall this VBL (don't advance simulation, hold render)
  else:
      simulate frame N using INPUT_LOCAL[N - K] and INPUT_REMOTE[N - K]
      override remote player abs_x/ypos with received value
      apply pending HIT events
      render
  N += 1
```

K (in frames) is set during handshake based on measured RTT, roughly
`ceil(half_RTT / 16.7 ms) + 1`. Typical: 2–6. Both sides agree on K so neither
gets ahead of the other. Player feels K frames of constant input lag (~50–
100 ms), no rollback complexity, simulation never desyncs because of network
jitter — it just stalls if the peer is too far behind.

### Determinism + position sync

The simulation is deterministic in principle, so peer position sync would be
redundant if everything were perfect. In practice, we send abs_x/ypos every
frame anyway as belt-and-braces:

- Bandwidth cost: 4 bytes per direction per frame ≈ 2 × 60 × 4 = 480 B/s plus
  TCP/line overhead. Trivial.
- After simulating frame N, override the **remote** player's `abs_x`/`ypos`
  with the value received in their `INP` packet. Local player's position is
  computed locally and authoritative locally.
- Effect: any inadvertent drift (sound IRQ cycle skew, timing-sensitive code
  paths, undiscovered RNG) is bounded to one frame and self-correcting. Level
  script `OP_WAITX` thresholds, NPC AI distance checks, and hit-box collision
  always see the same player positions on both machines.

### Hit events

Position sync covers position drift; hit events cover state convergence. When
the local hitter's machine detects a punch/kick landing, it sends:

```
HIT <victim_idx> <punch_count> <anim_lo> <anim_hi>
```

- `victim_idx` — index into `sprite_table`. Both sides agree on the table
  layout because NPCs are spawned by the deterministic level script.
- `punch_count` — new value to write at sprite info offset +48.
- `anim_lo`/`anim_hi` — new `anim_ptr` (`$FFFF` = death sentinel; sprite gets
  removed next pass).

Receiver applies the state to `sprite_table[victim_idx]` regardless of whether
it had locally detected the same hit. The hitter's machine is always
authoritative for the effects of its own attacks. NPC-on-player hits are
authoritative on the NPC-owning machine, which (because spawn is deterministic)
both machines agree on.

## State machine

```
TITLE
  ├─ "1P"          → CUTSCENE → GAME (single-player, current behaviour)
  └─ "2P NETWORK"  → WAITING_ROOM
        │
        ├─ no Uthernet II detected           → "Uthernet II not found" → TITLE
        ├─ DHCP fail                          → "No network" → TITLE
        ├─ lobby unreachable                  → "Lobby unreachable" → TITLE
        │
        └─ connect to lobby
             │
             ├─ poll player list, render
             ├─ user picks opponent → CHL
             ├─ opponent ACCs → both get PEER details
             │
             └─ HANDSHAKE
                  ├─ open TCP P2P link
                  ├─ exchange VER / mission CRC
                  ├─ exchange ping samples → agree on K
                  ├─ both → RDY → simultaneous tick 0
                  │
                  └─ IN-GAME
                       │
                       ├─ match completes (OP_END + COMPLETE music + fade)
                       │       → BYE → TITLE
                       ├─ peer disconnects                → "Opponent gone" → TITLE
                       └─ user aborts (some hotkey)       → BYE → TITLE
```

## Lobby protocol

Line-based ASCII, `\n` terminated. 3-letter command tags.

### Client → Server

| Tag | Args            | Meaning                                          |
|-----|-----------------|--------------------------------------------------|
| `HEL` | `<name>`        | Hello, my display name is `<name>`.              |
| `LST` |                 | Send current waiting list.                       |
| `CHL` | `<id>`          | Challenge player `<id>`.                         |
| `ACC` | `<id>`          | Accept incoming challenge from `<id>`.           |
| `DEC` | `<id>`          | Decline incoming challenge.                      |
| `PNG` |                 | Ping; server echoes for RTT measurement.         |
| `BYE` |                 | Disconnect cleanly.                              |

### Server → Client

| Tag | Args                     | Meaning                                          |
|-----|--------------------------|--------------------------------------------------|
| `WEL` | `<your_id>`              | Welcome; your assigned id is `<your_id>`.       |
| `PLR` | `<id> <name> <ping_ms>`  | One player line in response to `LST`.           |
| `END` |                          | End of player list.                             |
| `INV` | `<id> <name>`            | Incoming challenge from `<id>`.                 |
| `PEER` | `<ip> <port> <role>`    | Match made; connect to `<ip>:<port>`. `<role>` is `SRV` (you listen) or `CLI` (you connect). |
| `PNG` |                          | Server echo of client `PNG`.                    |
| `ERR` | `<code> <msg>`           | Error; `<msg>` displayable.                     |

### Ping

Lobby server sends a `PNG` to each client every ~2 seconds; client echoes
immediately. Server uses a rolling average for the `<ping_ms>` field of `PLR`
broadcasts.

## Peer protocol

Same line-based ASCII style. Single TCP connection between the two clients.

### Handshake (one-time)

| Tag | Args                             | Direction | Meaning                              |
|-----|----------------------------------|-----------|--------------------------------------|
| `VER` | `<proto> <mission> <crc>`       | both      | Protocol version, mission ID, CRC of `$02/0000-$02/00FF` for sanity. |
| `RTT` | `<sample_ms>`                   | both      | A single ping sample (sent ~5×, used to compute K). |
| `TIK` | `<K>`                           | server    | Agreed input delay frames.           |
| `RDY` |                                  | both      | Ready to start; tick 0 begins on next mutual VBL. |

`VER` mismatch → both abort with "VERSION MISMATCH" → return to lobby.

### Per-frame (steady state)

Each side sends one `INP` per frame. Receiver buffers by frame number.

```
INP <frame> <input> <abs_x> <ypos>
```

- `<frame>` — decimal 16-bit frame number (rolls over at 65536; matches don't
  last that long).
- `<input>` — 2-char hex byte:
  - bit 0 = up
  - bit 1 = down
  - bit 2 = left
  - bit 3 = right
  - bit 4 = punch
  - bit 5 = kick / jump (per current control mapping)
  - bits 6-7 = reserved
- `<abs_x>` — decimal world-absolute X (matches engine's `abs_x`).
- `<ypos>` — decimal Y position.

### Hit events (occasional)

```
HIT <victim_idx> <punch_count> <anim_lo> <anim_hi>
```

Sent by the hitter's machine the instant `check_punch_hit` registers a hit on
the local player's behalf. Receiver writes the new state to
`sprite_table[victim_idx]` and re-runs the death-cleanup path on the next
`erase_all` if `anim_ptr == $FFFF`.

### Termination

| Tag | Meaning                                    |
|-----|--------------------------------------------|
| `BYE` | Match over, clean shutdown.              |
| (TCP RST / FIN unexpected) | Treated as opponent disconnect. |

## Game engine changes

### `mission1.s`

- Spawn second player sprite (Jimmy template = Billy template with red-pants
  palette swap). Add to `sprite_table` after Billy.
- Level script semantics unchanged. `OP_WAITCLR` already iterates the table
  ignoring controller-1 sprites, so two player sprites just naturally both
  count as players.

### `game.s`

- Two input bytes per frame: local from controls, remote from
  `INPUT_REMOTE[current_frame - K]`. Map to billy_sprite / jimmy_sprite based
  on this machine's role (P1 = local-is-billy; P2 = local-is-jimmy).
- New "network step" at top of game loop, before `process_input`:
  1. Pump TCP recv on the peer socket.
  2. Parse any complete lines into the input ring buffer / hit-event queue.
  3. If `INPUT_REMOTE[N - K]` not yet present, stall this VBL.
  4. Apply received remote position to remote player sprite.
  5. Apply pending HIT events to `sprite_table`.
- After running `check_punch_hit` for the local player, emit `HIT` packets for
  any landed hits.
- After OP_END's fade completes, emit `BYE`, close TCP, fall through to the
  TITLE jump (`jmp $1000`) instead of sitting at black.

### Bank `$00` memory layout

- Launcher (DDII.SYSTEM) lives at `$1000-$13FF` after relocation; we keep it
  resident so the post-match return-to-title path (`jmp $1000`) works.
- That leaves `$1400-$1FFF` (~3 KB) free in bank `$00` user RAM. Use it for:
  - Wiznet 5100S socket TX/RX windows (or buffer pointers if windows live in
    the card's own RAM — depends on which Wiznet driver pattern is used).
  - INPUT_LOCAL / INPUT_REMOTE ring buffers (256 frames × 4 bytes each = 2 KB
    if we keep a generous history; can be smaller).
  - HIT-event queue (small).
  - Line-parser scratch buffers.

### Title screen

After the writing flash completes, show a small menu (text via QuickDraw II):

```
            1 PLAYER
            2 PLAYERS NETWORK

         press 1 or 2 to begin
```

`1` → existing flow → cutscene → game. `2` → waiting room.

### Waiting room screen

Plain-text screen rendered with QuickDraw II `_DrawCString`. Refreshed every
~1 s.

```
    DOUBLE DRAGON II - WAITING ROOM

    YOUR IP:   192.168.1.42
    LOBBY:     ddii.example.com   (45 ms)

    PLAYERS:
      > FOO         42 ms          [SPACE = challenge]
        BAR        180 ms
        QUUX       320 ms

    UP/DOWN move highlight  ESC = back to title
```

If no Uthernet II card is detected, replace the body with:

```
    UTHERNET II NOT FOUND

    Insert an Uthernet II card and reboot.

    ESC = back to title
```

## Failure modes

| Symptom                            | Handling                                       |
|------------------------------------|------------------------------------------------|
| No Uthernet II card                | "Uthernet II not found" message, ESC → TITLE.  |
| DHCP fails                         | "No network" message, ESC → TITLE.             |
| Lobby unreachable                  | "Lobby unreachable" message, retry / ESC.      |
| Lobby drops mid-listing            | Fall back to "Lobby unreachable".              |
| Peer connection refused            | "Peer unreachable", back to lobby.             |
| Version / CRC mismatch             | "Version mismatch", both back to lobby.        |
| Peer disconnects mid-match         | "Opponent disconnected", fade, → TITLE.        |
| Network stall > some threshold     | Render frozen frame; if still stalled after N seconds, treat as disconnect. |
| HIT for nonexistent sprite_idx     | Ignore (sprite already removed locally).       |

## Implementation phases

Each phase produces something you can demo / commit standalone.

### Phase 1: card detection + DHCP

Goal: from a tiny test program (or temporary path off the title screen),
detect the Uthernet II card, run DHCP, print obtained IP. No game logic.

### Phase 2: lobby + waiting-room UI

Goal: Python lobby server + IIgs HEL/LST/CHL flow. Render waiting-room
screen with live player list. Two IIgses can see each other in the lobby and
exchange CHL/ACC. No peer link yet.

### Phase 3: peer-to-peer handshake

Goal: TCP connection between two IIgses driven by lobby's `PEER` message.
Exchange VER / RTT / TIK / RDY. Print the result on a text screen. No game
yet.

### Phase 4: lockstep input + position sync

Goal: spawn jimmy_sprite, wire two-input-per-frame loop, run mission 1 co-op
end-to-end. Verify both sides see identical sprite positions throughout.

### Phase 5: hit events

Goal: `HIT` packets on local hit detection, applied on receive. Boss fight
ends consistently on both sides; both players see the COMPLETE fanfare and
fade.

### Phase 6: failure handling + polish

Goal: disconnect detection, every error UX path above, rematch-or-title flow,
clean exit.

## Open questions

1. **Lobby address.** Hardcode a default (`lobby.ddiigs.example`) and let the
   user override at startup, or always require the user to type one in?
2. **Lobby host language.** Python's the obvious choice; do we ship a sample
   server in the repo (`tools/lobby.py`)?
3. **Music sync.** NTP IRQs run free on each machine; the music will be
   slightly out of phase between players. Each only hears their own —
   acceptable as-is, no need to sync.
4. **Mid-match rage-quit.** Probably want an ESC-during-game "give up" hotkey
   that sends `BYE` and fades cleanly, instead of forcing a rematch every
   time.
5. **Replay / spectator.** Out of scope for V1, mention as future work.
6. **Wiznet driver.** Pull from your existing Apple II Uthernet II code? Or
   write it inline against the 5100S registers? Depends on what's portable.

## References

- Wiznet 5100S datasheet (the SPI-mode register set we'll be talking to).
- DDII engine architecture: `CLAUDE.md`.
- Level-script dispatcher: `src/game.s::run_script`.
- Sprite info block layout: `CLAUDE.md` §"Sprite info block layout".
- DDII.SYSTEM launcher (relocates to `$1000`, exposes title/cutscene/game
  jump table at `$1000`/`$1002`/`$1004`): `src/ddii.s`.
