#!/usr/bin/env python3
"""Convert MIDI to Amiga .MOD (ProTracker-compatible) format.

Quantizes MIDI events to a tracker row grid, generates single-cycle
waveform samples sized per channel to cover each channel's note range,
and writes a .MOD file (8CHN for 8 channels, M.K. for 4).
"""

import struct
import math
import sys
from pathlib import Path
import mido

PAL_CLOCK = 7093789.2

# ProTracker period table, finetune 0, three octaves (C-1 .. B-3)
PERIODS = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,  # oct 1
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,  # oct 2
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,  # oct 3
]

WAVEFORMS = ['square', 'sawtooth', 'pulse25', 'triangle',
             'square', 'sine', 'sawtooth', 'pulse25']


# ---- helpers ---------------------------------------------------------------

def _sample_base_note(length):
    """MIDI note that sounds when this sample is played at MOD C-2 (period 428)."""
    freq = PAL_CLOCK / (2 * 428 * length)
    return round(69 + 12 * math.log2(freq / 440))


def _best_sample_length(lo, hi):
    """Power-of-2 sample length whose 3-octave MOD range covers [lo, hi]."""
    center = (lo + hi) / 2
    target_freq = 440 * 2 ** ((center - 6 - 69) / 12)
    L = PAL_CLOCK / (2 * 428 * target_freq)
    return max(8, min(512, 1 << round(math.log2(L))))


def _midi_note_to_period(note, base_note):
    """Map MIDI note to nearest ProTracker period, clamped to table range."""
    idx = max(0, min(35, note - base_note + 12))
    return PERIODS[idx]


def _make_wave(kind, length, amp=48):
    """One cycle of a waveform as signed 8-bit bytes."""
    buf = bytearray(length)
    for i in range(length):
        p = i / length
        if kind == 'square':
            v = amp if p < 0.5 else -amp
        elif kind == 'pulse25':
            v = amp if p < 0.25 else -amp
        elif kind == 'sawtooth':
            v = int(amp * (1 - 2 * p))
        elif kind == 'triangle':
            v = int(amp * (4 * p - 1)) if p < 0.5 else int(amp * (3 - 4 * p))
        elif kind == 'sine':
            v = int(amp * math.sin(2 * math.pi * p))
        else:
            v = amp if p < 0.5 else -amp
        buf[i] = v & 0xFF
    return bytes(buf)


def _encode_cell(sample, period, effect, param):
    s, p = sample & 0xFF, period & 0xFFF
    return bytes([
        (s & 0xF0) | ((p >> 8) & 0x0F),
        p & 0xFF,
        ((s & 0x0F) << 4) | (effect & 0x0F),
        param & 0xFF,
    ])

_EMPTY = b'\x00\x00\x00\x00'


# ---- conversion ------------------------------------------------------------

def convert(midi_path, output_path=None, num_channels=8):
    mid = mido.MidiFile(midi_path)

    # ---- collect note events with absolute time (seconds) ------------------
    ch_events = {}
    tempo = 500000
    tpb = mid.ticks_per_beat
    sec = 0.0

    for msg in mido.merge_tracks(mid.tracks):
        if msg.time > 0:
            sec += mido.tick2second(msg.time, tpb, tempo)
        if msg.type == 'set_tempo':
            tempo = msg.tempo
        elif msg.type == 'note_on' and msg.velocity > 0:
            ch_events.setdefault(msg.channel, []).append(
                (sec, 'on', msg.note, msg.velocity))
        elif msg.type == 'note_off' or (msg.type == 'note_on' and msg.velocity == 0):
            ch_events.setdefault(msg.channel, []).append(
                (sec, 'off', msg.note, 0))

    if not ch_events:
        raise ValueError("No notes found in MIDI")

    # ---- MOD timing --------------------------------------------------------
    speed, bpm = 3, 125                         # 16.67 rows/sec
    rows_per_sec = bpm * 2.0 / 5.0 / speed

    max_sec = max(t for evs in ch_events.values() for t, *_ in evs)
    total_rows = int(math.ceil(max_sec * rows_per_sec)) + 1
    total_pats = min(128, (total_rows + 63) // 64)
    total_rows = total_pats * 64                 # pad to full patterns

    # map MIDI channels → MOD channels (keep top N by note count)
    ranked = sorted(ch_events, key=lambda c: -sum(1 for e in ch_events[c] if e[1] == 'on'))
    active = sorted(ranked[:num_channels])
    ch_map = {mc: i for i, mc in enumerate(active)}

    print(f"Duration : {max_sec:.1f}s")
    print(f"Rows     : {total_rows}  Patterns: {total_pats}")
    print(f"Timing   : speed {speed}  BPM {bpm}  ({rows_per_sec:.1f} rows/s)")

    if len(ch_events) > num_channels:
        dropped = sorted(set(ch_events) - set(active))
        print(f"Dropped MIDI channels (not enough MOD channels): {dropped}")

    # ---- build samples -----------------------------------------------------
    samples = []          # (name, data, volume)
    base_notes = {}       # mod_ch → base MIDI note

    for mod_ch, midi_ch in enumerate(active):
        notes = [n for _, t, n, _ in ch_events[midi_ch] if t == 'on']
        if not notes:
            samples.append(("", b'\x00' * 8, 0))
            base_notes[mod_ch] = 60
            continue

        slen = _best_sample_length(min(notes), max(notes))
        bn = _sample_base_note(slen)
        wf = WAVEFORMS[mod_ch % len(WAVEFORMS)]
        samples.append((f"Ch{midi_ch} {wf[:4]} {slen}b", _make_wave(wf, slen), 64))
        base_notes[mod_ch] = bn

        clamped = sum(1 for n in notes if (n - bn + 12) < 0 or (n - bn + 12) > 35)
        extra = f"  ({clamped} clamped)" if clamped else ""
        print(f"  MIDI ch {midi_ch} → MOD ch {mod_ch}: {wf} {slen}b, "
              f"notes {min(notes)}-{max(notes)}, base={bn}{extra}")

    # ---- quantise to row grid ----------------------------------------------
    # grid[ch][row] = (sample_1based, period, effect, param) | None
    grid = [[None] * total_rows for _ in range(num_channels)]

    for midi_ch in active:
        mod_ch = ch_map[midi_ch]
        bn = base_notes[mod_ch]
        snum = mod_ch + 1

        for t, typ, note, vel in ch_events[midi_ch]:
            row = max(0, min(total_rows - 1, round(t * rows_per_sec)))
            if typ == 'on':
                per = _midi_note_to_period(note, bn)
                mvol = max(1, min(64, vel * 64 // 127))
                grid[mod_ch][row] = (snum, per, 0x0C, mvol)
            else:
                # note-off → volume 0, but never overwrite a note-on
                if grid[mod_ch][row] is None:
                    grid[mod_ch][row] = (0, 0, 0x0C, 0)

    # ---- inject Fxx tempo effects on row 0 ---------------------------------
    # Without these the player defaults to speed=6/BPM=125 regardless of our
    # quantisation rate.  Fxx with xx<=0x1F sets speed, xx>=0x20 sets BPM.
    # Place on the last two channels to avoid clobbering note data.
    def _set_row0_effect(ch, eff, param):
        cell = grid[ch][0]
        if cell is None:
            grid[ch][0] = (0, 0, eff, param)
        else:
            # keep sample+period, replace the effect
            grid[ch][0] = (cell[0], cell[1], eff, param)

    _set_row0_effect(num_channels - 1, 0x0F, speed)     # Fxx speed
    _set_row0_effect(num_channels - 2, 0x0F, bpm)       # Fxx BPM

    # per-channel stats
    for mod_ch, midi_ch in enumerate(active):
        placed = sum(1 for c in grid[mod_ch] if c and c[1] > 0)
        total = sum(1 for _, t, *_ in ch_events[midi_ch] if t == 'on')
        if placed < total:
            print(f"  MOD ch {mod_ch} (MIDI {midi_ch}): {placed}/{total} notes placed")

    # ---- write .MOD --------------------------------------------------------
    out = Path(output_path) if output_path else Path(midi_path).with_suffix('.mod')

    with open(str(out), 'wb') as f:
        # title
        f.write(Path(midi_path).stem.encode('ascii', 'replace')[:20].ljust(20, b'\x00'))

        # 31 sample headers
        for i in range(31):
            if i < len(samples):
                nm, sd, vol = samples[i]
                wlen = len(sd) // 2
                llen = wlen if vol else 1
            else:
                nm, sd, vol, wlen, llen = "", b"", 0, 0, 1
            f.write(nm.encode('ascii', 'replace')[:22].ljust(22, b'\x00'))
            f.write(struct.pack('>H', wlen))      # length (words)
            f.write(b'\x00')                       # finetune
            f.write(struct.pack('B', min(64, vol)))
            f.write(struct.pack('>HH', 0, llen))   # loop start, loop length

        f.write(struct.pack('BB', total_pats, 127))   # song length, restart

        order = bytes(range(total_pats)).ljust(128, b'\x00')
        f.write(order)

        # format tag
        if num_channels == 4:
            f.write(b'M.K.')
        else:
            f.write(f'{num_channels}CHN'.encode('ascii'))

        # pattern data
        for p in range(total_pats):
            for row in range(64):
                arow = p * 64 + row
                for ch in range(num_channels):
                    cell = grid[ch][arow] if arow < total_rows else None
                    f.write(_encode_cell(*cell) if cell else _EMPTY)

        # sample waveform data
        for i in range(min(31, len(samples))):
            f.write(samples[i][1])

    note_count = sum(1 for ch in grid for c in ch if c and c[1] > 0)
    print(f"Wrote {out} ({total_pats} patterns, {note_count} notes)")
    return out


# ---- CLI -------------------------------------------------------------------

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input.mid> [output.mod] [--channels 4|8]")
        sys.exit(1)

    args = sys.argv[1:]
    nch = 8
    if '--channels' in args:
        idx = args.index('--channels')
        nch = int(args[idx + 1])
        args = args[:idx] + args[idx + 2:]

    convert(args[0], args[1] if len(args) > 1 else None, num_channels=nch)
