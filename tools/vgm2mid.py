#!/usr/bin/env python3
"""Convert VGM/VGZ files containing YM2151 data to MIDI.

Parses YM2151 register writes (KC, KF, TL, Key On/Off) from VGM streams
and emits corresponding MIDI note-on/off events with velocity derived
from operator total levels.
"""

import struct
import gzip
import sys
from pathlib import Path
import mido

# YM2151 KC note-code to semitone (C=0). The chip encodes 12 notes
# across 16 values with gaps at 3, 7, 11, 15.
KC_TO_SEMITONE = [
#   0:C# 1:D  2:D# 3:=D# 4:E  5:F  6:F# 7:=F#
    1,    2,   3,   3,    4,   5,   6,   6,
#   8:G  9:G# A:A  B:=A  C:A# D:B  E:C+ F:=C+
    7,   8,   9,   9,    10,  11,  0,   0,
]


def kc_to_midi_note(kc):
    """Convert YM2151 KC register value to MIDI note number."""
    octave = (kc >> 4) & 7
    note_code = kc & 0x0F
    semitone = KC_TO_SEMITONE[note_code]
    if note_code >= 14:  # C belongs to next octave
        octave += 1
    # Align so YM2151 octave 4 ≈ MIDI octave 4 (middle C region)
    return max(0, min(127, (octave + 1) * 12 + semitone))


def read_vgm(filepath):
    """Read and decompress VGM/VGZ file."""
    data = Path(filepath).read_bytes()
    if Path(filepath).suffix.lower() == '.vgz' or data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data)
    if data[:4] != b'Vgm ':
        raise ValueError("Not a valid VGM file")
    return data


def parse_header(data):
    """Extract relevant VGM header fields."""
    version = struct.unpack_from('<I', data, 0x08)[0]
    ym2151_clock = struct.unpack_from('<I', data, 0x30)[0]

    if version >= 0x150:
        rel = struct.unpack_from('<I', data, 0x34)[0]
        data_offset = (0x34 + rel) if rel else 0x40
    else:
        data_offset = 0x40

    loop_rel = struct.unpack_from('<I', data, 0x1C)[0]
    loop_offset = (0x1C + loop_rel) if loop_rel else 0

    return {
        'version': version,
        'ym2151_clock': ym2151_clock,
        'data_offset': data_offset,
        'loop_offset': loop_offset,
    }


# Which operators are carriers for each CON (connection/algorithm) 0-7.
# Operator indices: 0=M1, 1=M2, 2=C1, 3=C2
CON_CARRIERS = [
    [3],          # 0: only C2
    [3],          # 1: only C2
    [3],          # 2: only C2
    [3],          # 3: only C2
    [1, 3],       # 4: C1, C2
    [1, 2, 3],    # 5: M2, C1, C2
    [1, 2, 3],    # 6: M2, C1, C2
    [0, 1, 2, 3], # 7: all
]


def velocity_from_tl(tl_vals, con):
    """Estimate MIDI velocity from carrier TL values.

    TL 0 = loudest, 127 = silent on the YM2151. We average the carrier
    operator TLs and invert to get MIDI velocity.
    """
    carriers = CON_CARRIERS[con & 7]
    avg_tl = sum(tl_vals[op] for op in carriers) / len(carriers)
    return max(1, min(127, int(127 - avg_tl)))


def convert(filepath, output_path=None):
    """Parse VGM and write MIDI file."""
    data = read_vgm(filepath)
    header = parse_header(data)

    if not header['ym2151_clock']:
        raise ValueError("No YM2151 clock in this VGM")

    print(f"VGM version: {header['version']:#06x}")
    print(f"YM2151 clock: {header['ym2151_clock']} Hz")

    # Per-channel state
    ch_kc = [0] * 8
    ch_kf = [0] * 8
    ch_con = [0] * 8
    ch_tl = [[127] * 4 for _ in range(8)]
    ch_active_note = [None] * 8  # MIDI note currently sounding, or None

    # Collected events: (time_samples, channel, 'on'|'off', note, velocity)
    events = []
    pos = header['data_offset']
    now = 0  # time in samples @ 44100 Hz

    while pos < len(data):
        cmd = data[pos]

        if cmd == 0x54:  # YM2151 register write
            reg, val = data[pos + 1], data[pos + 2]
            pos += 3

            if 0x28 <= reg <= 0x2F:
                ch_kc[reg - 0x28] = val
            elif 0x30 <= reg <= 0x37:
                ch_kf[reg - 0x30] = val
            elif 0x20 <= reg <= 0x27:
                ch_con[reg - 0x20] = val & 0x07
            elif 0x60 <= reg <= 0x7F:
                op = (reg - 0x60) // 8
                ch = (reg - 0x60) % 8
                ch_tl[ch][op] = val & 0x7F
            elif reg == 0x08:
                ch = val & 0x07
                ops = (val >> 3) & 0x0F

                if ops:  # Key ON
                    # If already sounding, send note-off first (retrigger)
                    if ch_active_note[ch] is not None:
                        events.append((now, ch, 'off', ch_active_note[ch], 0))

                    note = kc_to_midi_note(ch_kc[ch])
                    vel = velocity_from_tl(ch_tl[ch], ch_con[ch])
                    events.append((now, ch, 'on', note, vel))
                    ch_active_note[ch] = note
                else:  # Key OFF
                    if ch_active_note[ch] is not None:
                        events.append((now, ch, 'off', ch_active_note[ch], 0))
                        ch_active_note[ch] = None

        elif cmd == 0x61:
            now += struct.unpack_from('<H', data, pos + 1)[0]
            pos += 3
        elif cmd == 0x62:
            now += 735; pos += 1
        elif cmd == 0x63:
            now += 882; pos += 1
        elif 0x70 <= cmd <= 0x7F:
            now += (cmd & 0x0F) + 1; pos += 1
        elif cmd == 0x66:
            break
        else:
            # Skip unsupported commands by their known sizes
            if cmd in (0x30, 0x3F, 0x4F, 0x50):
                pos += 2
            elif (0x51 <= cmd <= 0x5F) or (0xA0 <= cmd <= 0xBF):
                pos += 3
            elif 0xC0 <= cmd <= 0xDF:
                pos += 4
            elif 0xE0 <= cmd <= 0xFF:
                pos += 5
            else:
                pos += 1  # unknown single-byte

    # Close any still-open notes
    for ch in range(8):
        if ch_active_note[ch] is not None:
            events.append((now, ch, 'off', ch_active_note[ch], 0))

    # --- Build MIDI file ---
    # 120 BPM, 480 ticks/beat → 960 ticks/sec → ~45.94 samples/tick
    ticks_per_beat = 480
    bpm = 120
    samples_per_tick = 44100.0 / (ticks_per_beat * bpm / 60)

    mid = mido.MidiFile(ticks_per_beat=ticks_per_beat, type=1)

    # Track 0: conductor track (tempo + time signature only)
    conductor = mido.MidiTrack()
    mid.tracks.append(conductor)
    conductor.append(mido.MetaMessage('track_name', name='Tempo', time=0))
    conductor.append(mido.MetaMessage('time_signature', numerator=4, denominator=4,
                                      clocks_per_click=24,
                                      notated_32nd_notes_per_beat=8, time=0))
    conductor.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(bpm), time=0))

    # Group events by channel
    by_ch = {}
    for ev in events:
        by_ch.setdefault(ev[1], []).append(ev)

    for ch in sorted(by_ch):
        track = mido.MidiTrack()
        mid.tracks.append(track)
        track.append(mido.MetaMessage('track_name', name=f'YM2151 Ch {ch}', time=0))
        # Program change — default to piano so every player has a voice loaded
        track.append(mido.Message('program_change', channel=ch, program=0, time=0))

        prev_tick = 0
        for time_s, _ch, typ, note, vel in by_ch[ch]:
            tick = int(time_s / samples_per_tick)
            delta = max(0, tick - prev_tick)
            prev_tick = tick
            msg_type = 'note_on' if typ == 'on' else 'note_off'
            track.append(mido.Message(msg_type, channel=ch, note=note,
                                      velocity=vel, time=delta))

    if output_path is None:
        output_path = Path(filepath).with_suffix('.mid')

    mid.save(str(output_path))
    total_notes = sum(1 for e in events if e[2] == 'on')
    print(f"Wrote {output_path} ({len(mid.tracks)} tracks, {total_notes} notes)")
    return output_path


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input.vgm|.vgz> [output.mid]")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
