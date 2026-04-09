#!/usr/bin/env python3
"""Convert VGM (YM2151) directly to .MOD with FM-rendered instrument samples.

Parses YM2151 register writes to capture 4-operator FM synthesis parameters
(including envelopes) at each key-on, renders actual FM waveforms with
per-operator ADSR simulation and DT1/DT2 detune, and writes a .MOD file
with attack+sustain samples using proper loop points.
"""

import struct
import gzip
import math
import sys
import random
from pathlib import Path

# ---- constants -------------------------------------------------------------

PAL_CLOCK = 7093789.2
MOD_RATE = 8287.0  # Amiga playback rate at period 428 (C-2)

PERIODS = [
    856, 808, 762, 720, 678, 640, 604, 570, 538, 508, 480, 453,
    428, 404, 381, 360, 339, 320, 302, 285, 269, 254, 240, 226,
    214, 202, 190, 180, 170, 160, 151, 143, 135, 127, 120, 113,
]

KC_SEMI = [1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 9, 9, 10, 11, 0, 0]

# YM2151 algorithm routing: ALGO_MOD[alg][op] = sources that modulate op.
# Op indices: 0=M1, 1=M2, 2=C1, 3=C2.  Feedback on M1 handled separately.
ALGO_MOD = [
    {0: [], 2: [0],    1: [2],   3: [1]},     # 0: M1->C1->M2->C2
    {0: [], 2: [],     1: [0,2], 3: [1]},     # 1: (M1+C1)->M2->C2
    {0: [], 2: [],     1: [2],   3: [0, 1]},  # 2: (M1+C1->M2)->C2
    {0: [], 2: [0],    1: [],    3: [1, 2]},  # 3: (M1->C1+M2)->C2
    {0: [], 2: [0],    1: [],    3: [1]},      # 4: M1->C1 + M2->C2
    {0: [], 2: [0],    1: [0],   3: [0]},      # 5: M1->(C1+M2+C2)
    {0: [], 2: [0],    1: [],    3: []},        # 6: M1->C1 + M2 + C2
    {0: [], 2: [],     1: [],    3: []},        # 7: all parallel
]
ALGO_CARRIERS = [
    [3], [3], [3], [3], [2, 3], [1, 2, 3], [1, 2, 3], [0, 1, 2, 3],
]
ALGO_ORDER = [
    [0, 2, 1, 3], [0, 2, 1, 3], [0, 2, 1, 3], [0, 1, 2, 3],
    [0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3], [0, 1, 2, 3],
]

# DT2 coarse detune frequency multipliers
DT2_MULT = [1.0, 1.0595, 1.1892, 1.4142]

# DT1 fine detune in cents (simplified, note-independent)
DT1_CENTS = [0, 8, 17, 25, 0, -8, -17, -25]

# Phase modulation depth at TL=0 (controls FM brightness)
MOD_SCALE = 6.0 * math.pi


# ---- helpers ---------------------------------------------------------------

def kc_to_midi(kc):
    o, nc = (kc >> 4) & 7, kc & 0xF
    if nc >= 14:
        o += 1
    return max(0, min(127, (o + 1) * 12 + KC_SEMI[nc]))


def _base_note(length):
    """MIDI note that sounds at MOD C-2 (period 428) for a 1-cycle sample."""
    freq = PAL_CLOCK / (2 * 428 * length)
    return round(69 + 12 * math.log2(freq / 440))


def _pick_slen(lo, hi):
    """Power-of-2 cycle length whose 3-octave MOD range covers [lo..hi]."""
    center = (lo + hi) / 2
    target_freq = 440 * 2 ** ((center - 6 - 69) / 12)
    L = PAL_CLOCK / (2 * 428 * target_freq)
    return min(512, max(32, 1 << round(math.log2(max(32, L)))))


def _note_to_period(note, bn):
    return PERIODS[max(0, min(35, note - bn + 12))]


def _encode_cell(s, p, e, ep):
    s, p = s & 0xFF, p & 0xFFF
    return bytes([
        (s & 0xF0) | ((p >> 8) & 0x0F), p & 0xFF,
        ((s & 0x0F) << 4) | (e & 0x0F), ep & 0xFF,
    ])

_EMPTY = b'\x00\x00\x00\x00'


# ---- envelope simulation ---------------------------------------------------

def _env_curve(ar, d1r, d1l, num_samples):
    """Per-sample envelope multiplier (0.0 to 1.0).

    Simplified YM2151 model: exponential attack, exponential decay to
    sustain level determined by D1L.
    """
    if ar == 0:
        return [0.0] * num_samples

    def _tc(r):
        if r == 0:
            return 1000.0
        if r >= 31:
            return 0.0003
        return 3.0 / 2 ** (r / 3.0)

    att_tc = _tc(ar)
    dec_tc = _tc(d1r)
    sus = 10 ** (-d1l * 3.0 / 20.0) if d1l < 15 else 0.0
    dt = 1.0 / MOD_RATE

    env = []
    level = 0.0
    phase = 'A'
    for _ in range(num_samples):
        if phase == 'A':
            level += (1.0 - level) * min(1.0, 3.0 * dt / max(att_tc, 1e-6))
            if level >= 0.995:
                level = 1.0
                phase = 'D'
        elif phase == 'D':
            if d1r == 0 or sus >= 0.99:
                level = max(sus, level)
                phase = 'S'
            else:
                level += (sus - level) * min(1.0, 3.0 * dt / max(dec_tc, 1e-6))
                if abs(level - sus) < 0.005:
                    level = sus
                    phase = 'S'
        env.append(max(0.0, min(1.0, level)))
    return env


def _sustain_level(ar, d1r, d1l):
    """Steady-state envelope level (no time dependency)."""
    if ar == 0:
        return 0.0
    if d1r == 0:
        return 1.0
    if d1l >= 15:
        return 0.0
    return 10 ** (-d1l * 3.0 / 20.0)


def _attack_seconds(ar, d1r, d1l):
    """Approximate time until operator envelope reaches sustain."""
    def _tc(r):
        if r == 0:
            return 1000.0
        if r >= 31:
            return 0.0003
        return 3.0 / 2 ** (r / 3.0)
    return _tc(ar) * 3.5 + (_tc(d1r) * 3.5 if d1l > 0 and d1r > 0 else 0)


# ---- FM rendering ----------------------------------------------------------

def render_fm(mul, dt1, dt2, tl, fb, con, ar, d1r, d1l,
              cycle_len, loop_cycles=1):
    """Render 4-op FM with per-operator envelopes.

    Returns (pcm_bytes, loop_start_words, loop_length_words).
    The sample has an attack+decay prefix, then a looping sustain.
    """
    loop_len = cycle_len * loop_cycles

    # Attack length: enough samples for all envelopes to reach sustain
    max_att = max(_attack_seconds(ar[op], d1r[op], d1l[op]) for op in range(4))
    att_samples = min(4096, max(cycle_len, int(max_att * MOD_RATE)))
    att_samples = ((att_samples + cycle_len - 1) // cycle_len) * cycle_len
    att_cycles = att_samples // cycle_len

    # Frequency ratios: MUL with DT1 fine detune and DT2 coarse detune
    eff_mul = [
        (m if m else 0.5) * DT2_MULT[dt2[i]] * 2 ** (DT1_CENTS[dt1[i]] / 1200.0)
        for i, m in enumerate(mul)
    ]

    # TL to base amplitude
    base_amp = [10 ** (-t * 0.75 / 20) if t < 127 else 0.0 for t in tl]

    # Feedback on M1
    fb_s = 0.0 if not fb else MOD_SCALE * 2 ** (fb - 7)

    route = ALGO_MOD[con]
    cars = ALGO_CARRIERS[con]
    order = ALGO_ORDER[con]

    # Sustain envelope values (steady-state)
    sus_ev = [_sustain_level(ar[op], d1r[op], d1l[op]) for op in range(4)]

    # Attack envelope curves
    att_envs = [_env_curve(ar[op], d1r[op], d1l[op], att_samples)
                for op in range(4)]

    def _render(length, n_cyc, env_fn, p1=0.0, p2=0.0):
        """Render a block of FM.  env_fn(op, sample_idx) -> amplitude mult."""
        buf = []
        for i in range(length):
            base = 2.0 * math.pi * n_cyc * i / length
            oo = [0.0] * 4
            for op in order:
                ph = base * eff_mul[op]
                if op == 0 and fb:
                    ph += (p1 + p2) * 0.5 * fb_s
                for src in route[op]:
                    ph += oo[src] * MOD_SCALE
                oo[op] = math.sin(ph) * base_amp[op] * env_fn(op, i)
            p2, p1 = p1, oo[0]
            buf.append(sum(oo[c] for c in cars))
        return buf, p1, p2

    # 1. Warm-up at sustain level (settle feedback for seamless loop)
    _, wp1, wp2 = _render(loop_len, loop_cycles,
                          lambda op, i: sus_ev[op])

    # 2. Render sustain loop with warm-up feedback
    sus_buf, _, _ = _render(loop_len, loop_cycles,
                            lambda op, i: sus_ev[op], wp1, wp2)

    # 3. Render attack with fresh feedback
    att_buf, _, _ = _render(att_samples, att_cycles,
                            lambda op, i: att_envs[op][i])

    full = att_buf + sus_buf

    # Detect percussive patches (sustain is near-silent → no loop)
    sus_peak = max(abs(s) for s in sus_buf) if sus_buf else 0
    full_peak = max(abs(s) for s in full) or 1.0
    is_perc = sus_peak < full_peak * 0.02

    # Normalize to signed 8-bit
    pcm = bytes(int(max(-128, min(127, s / full_peak * 100))) & 0xFF
                for s in full)
    if len(pcm) % 2:
        pcm += b'\x00'

    if is_perc:
        return pcm, 0, 1  # no loop
    else:
        return pcm, att_samples // 2, loop_len // 2  # words


def render_noise(length):
    """Generate deterministic white noise sample."""
    rng = random.Random(42)
    pcm = bytes(rng.randint(0, 255) for _ in range(length))
    if len(pcm) % 2:
        pcm += b'\x00'
    return pcm, 0, len(pcm) // 2  # loop entire sample


# ---- VGM I/O --------------------------------------------------------------

def read_vgm(filepath):
    data = Path(filepath).read_bytes()
    if Path(filepath).suffix.lower() == '.vgz' or data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data)
    if data[:4] != b'Vgm ':
        raise ValueError("Not a valid VGM file")
    return data


def parse_header(data):
    version = struct.unpack_from('<I', data, 0x08)[0]
    ym2151_clock = struct.unpack_from('<I', data, 0x30)[0]
    if version >= 0x150:
        rel = struct.unpack_from('<I', data, 0x34)[0]
        data_offset = (0x34 + rel) if rel else 0x40
    else:
        data_offset = 0x40
    return version, ym2151_clock, data_offset


# ---- YM2151 state tracker --------------------------------------------------

class OPMState:
    """Maintains full YM2151 register state, updated by write()."""

    def __init__(self):
        self.mul = [[0] * 4 for _ in range(8)]
        self.dt1 = [[0] * 4 for _ in range(8)]
        self.dt2 = [[0] * 4 for _ in range(8)]
        self.tl  = [[127] * 4 for _ in range(8)]
        self.ar  = [[0] * 4 for _ in range(8)]
        self.d1r = [[0] * 4 for _ in range(8)]
        self.d1l = [[0] * 4 for _ in range(8)]
        self.fb  = [0] * 8
        self.con = [0] * 8
        self.kc  = [0] * 8
        self.kf  = [0] * 8
        self.noise_en = False
        self.noise_freq = 0

    def write(self, reg, val):
        if 0x20 <= reg <= 0x27:
            ch = reg & 7
            self.con[ch] = val & 7
            self.fb[ch] = (val >> 3) & 7
        elif 0x28 <= reg <= 0x2F:
            self.kc[reg & 7] = val
        elif 0x30 <= reg <= 0x37:
            self.kf[reg & 7] = val
        elif 0x40 <= reg <= 0x5F:
            ch, op = reg & 7, (reg >> 3) & 3
            self.mul[ch][op] = val & 0x0F
            self.dt1[ch][op] = (val >> 4) & 7
        elif 0x60 <= reg <= 0x7F:
            ch, op = reg & 7, (reg >> 3) & 3
            self.tl[ch][op] = val & 0x7F
        elif 0x80 <= reg <= 0x9F:
            ch, op = reg & 7, (reg >> 3) & 3
            self.ar[ch][op] = val & 0x1F
        elif 0xA0 <= reg <= 0xBF:
            ch, op = reg & 7, (reg >> 3) & 3
            self.d1r[ch][op] = val & 0x1F
        elif 0xC0 <= reg <= 0xDF:
            ch, op = reg & 7, (reg >> 3) & 3
            self.dt2[ch][op] = (val >> 6) & 3
        elif 0xE0 <= reg <= 0xFF:
            ch, op = reg & 7, (reg >> 3) & 3
            self.d1l[ch][op] = (val >> 4) & 0x0F
        elif reg == 0x0F:
            self.noise_en = bool(val & 0x80)
            self.noise_freq = val & 0x1F

    def patch_id(self, ch):
        """Timbre identity for deduplication.

        Includes modulator TL and envelope (affects timbre via modulation
        depth over time).  Excludes carrier TL/envelope (volume only).
        """
        con = self.con[ch]
        car_set = set(ALGO_CARRIERS[con])
        mod_tl  = tuple(self.tl[ch][op]  if op not in car_set else 0
                        for op in range(4))
        mod_ar  = tuple(self.ar[ch][op]  if op not in car_set else 0
                        for op in range(4))
        mod_d1r = tuple(self.d1r[ch][op] if op not in car_set else 0
                        for op in range(4))
        mod_d1l = tuple(self.d1l[ch][op] if op not in car_set else 0
                        for op in range(4))
        noise = self.noise_en and ch == 7
        return (tuple(self.mul[ch]), tuple(self.dt1[ch]),
                tuple(self.dt2[ch]), mod_tl, mod_ar, mod_d1r, mod_d1l,
                self.fb[ch], con, noise)

    def render_params(self, ch):
        """Full FM parameters needed to render a sample."""
        return dict(
            mul=list(self.mul[ch]), dt1=list(self.dt1[ch]),
            dt2=list(self.dt2[ch]), tl=list(self.tl[ch]),
            ar=list(self.ar[ch]),   d1r=list(self.d1r[ch]),
            d1l=list(self.d1l[ch]),
            fb=self.fb[ch], con=self.con[ch],
            noise=self.noise_en and ch == 7,
        )

    def carrier_velocity(self, ch):
        """Estimate MIDI-like velocity from carrier TL values."""
        carriers = ALGO_CARRIERS[self.con[ch]]
        avg_tl = sum(self.tl[ch][op] for op in carriers) / len(carriers)
        return max(1, min(127, int(127 - avg_tl)))


# ---- main converter --------------------------------------------------------

def convert(vgm_path, output_path=None, num_channels=8):
    data = read_vgm(vgm_path)
    version, ym_clock, data_offset = parse_header(data)
    if not ym_clock:
        raise ValueError("No YM2151 clock in this VGM")

    print(f"YM2151 @ {ym_clock} Hz, VGM version {version:#06x}")

    # ---- parse VGM stream, collect events and patch snapshots --------------
    opm = OPMState()
    events = []           # (sample_time, ch, 'on'|'off', midi_note, patch_id, vel)
    patch_params = {}     # patch_id -> render_params (first occurrence)
    ch_active = [None] * 8

    pos, now = data_offset, 0
    while pos < len(data):
        cmd = data[pos]
        if cmd == 0x54:  # YM2151 register write
            reg, val = data[pos + 1], data[pos + 2]
            pos += 3
            opm.write(reg, val)
            if reg == 0x08:  # key on/off
                ch = val & 7
                ops = (val >> 3) & 0x0F
                if ops:  # key ON
                    if ch_active[ch] is not None:
                        events.append((now, ch, 'off', ch_active[ch], None, 0))
                    note = kc_to_midi(opm.kc[ch])
                    pid = opm.patch_id(ch)
                    if pid not in patch_params:
                        patch_params[pid] = opm.render_params(ch)
                    vel = opm.carrier_velocity(ch)
                    events.append((now, ch, 'on', note, pid, vel))
                    ch_active[ch] = note
                else:  # key OFF
                    if ch_active[ch] is not None:
                        events.append((now, ch, 'off', ch_active[ch], None, 0))
                        ch_active[ch] = None
        elif cmd == 0x61:
            now += struct.unpack_from('<H', data, pos + 1)[0]; pos += 3
        elif cmd == 0x62:
            now += 735; pos += 1
        elif cmd == 0x63:
            now += 882; pos += 1
        elif 0x70 <= cmd <= 0x7F:
            now += (cmd & 0x0F) + 1; pos += 1
        elif cmd == 0x66:
            break
        else:
            if cmd in (0x30, 0x3F, 0x4F, 0x50):
                pos += 2
            elif (0x51 <= cmd <= 0x5F) or (0xA0 <= cmd <= 0xBF):
                pos += 3
            elif 0xC0 <= cmd <= 0xDF:
                pos += 4
            elif 0xE0 <= cmd <= 0xFF:
                pos += 5
            else:
                pos += 1

    for ch in range(8):
        if ch_active[ch] is not None:
            events.append((now, ch, 'off', ch_active[ch], None, 0))

    note_count = sum(1 for e in events if e[2] == 'on')
    print(f"{note_count} notes, {len(patch_params)} unique FM patches")

    # ---- render a MOD sample for each unique patch -------------------------
    patch_notes = {pid: [] for pid in patch_params}
    for _, _, typ, note, pid, _ in events:
        if typ == 'on' and pid in patch_notes:
            patch_notes[pid].append(note)

    patch_list = list(patch_params.keys())[:31]
    pid_to_sample = {pid: i + 1 for i, pid in enumerate(patch_list)}

    samples = []      # (name, pcm_data, volume, loop_start_words, loop_len_words)
    pid_base = {}     # patch_id -> base MIDI note

    for pid in patch_list:
        pp = patch_params[pid]
        notes = patch_notes[pid]
        if not notes:
            samples.append(("unused", b'\x00' * 8, 0, 0, 1))
            pid_base[pid] = 60
            continue

        cycle_len = _pick_slen(min(notes), max(notes))

        # MUL=0 means x0.5 — need 2 fundamental cycles for a clean loop.
        # Halve cycle_len to compensate for the doubled loop length.
        has_half = any(m == 0 for m in pp['mul'])
        loop_cycles = 2 if has_half else 1
        if has_half:
            cycle_len = max(16, cycle_len // 2)

        # Base note determined by the actual loop length heard by the player
        loop_byte_len = cycle_len * loop_cycles
        bn = _base_note(loop_byte_len)
        pid_base[pid] = bn

        if pp['noise']:
            pcm, ls, ll = render_noise(max(256, loop_byte_len))
            name = f"Noise {len(pcm)}b"
        else:
            pcm, ls, ll = render_fm(
                pp['mul'], pp['dt1'], pp['dt2'], pp['tl'],
                pp['fb'], pp['con'],
                pp['ar'], pp['d1r'], pp['d1l'],
                cycle_len, loop_cycles)
            muls = ','.join(str(m) for m in pp['mul'])
            loop_info = "perc" if ll <= 1 else f"lp@{ls*2}"
            name = f"a{pp['con']}f{pp['fb']} [{muls}] {loop_info}"

        samples.append((name[:22], pcm, 64, ls, ll))
        clamped = sum(1 for n in notes if (n - bn + 12) < 0
                      or (n - bn + 12) > 35)
        print(f"  S{len(samples):02d} {name:22s}  {len(pcm):5d}b  "
              f"{len(notes):4d} notes  {min(notes):3d}-{max(notes):3d}  "
              f"base={bn}" + (f"  ({clamped} clamped)" if clamped else ""))

    if len(patch_params) > 31:
        print(f"  Warning: {len(patch_params)} patches exceeds 31-sample MOD "
              f"limit; {len(patch_params) - 31} dropped")

    # ---- quantise events to MOD row grid -----------------------------------
    speed, bpm = 3, 125
    rows_per_sec = bpm * 2.0 / 5.0 / speed

    max_sec = max(e[0] for e in events) / 44100.0
    total_rows = int(math.ceil(max_sec * rows_per_sec)) + 1
    total_pats = min(128, (total_rows + 63) // 64)
    total_rows = total_pats * 64

    active_chs = sorted(set(e[1] for e in events if e[2] == 'on'))[:num_channels]
    ch_map = {ym: i for i, ym in enumerate(active_chs)}

    print(f"\n{max_sec:.1f}s, {total_rows} rows, {total_pats} patterns "
          f"(speed {speed}, BPM {bpm}, {rows_per_sec:.1f} rows/s)")

    grid = [[None] * total_rows for _ in range(num_channels)]

    for ts, ch, typ, note, pid, vel in events:
        if ch not in ch_map:
            continue
        mc = ch_map[ch]
        row = max(0, min(total_rows - 1, round(ts / 44100.0 * rows_per_sec)))

        if typ == 'on' and pid in pid_to_sample:
            sn = pid_to_sample[pid]
            per = _note_to_period(note, pid_base[pid])
            mvol = max(1, min(64, vel * 64 // 127))
            grid[mc][row] = (sn, per, 0x0C, mvol)
        elif typ == 'off':
            if grid[mc][row] is None:
                grid[mc][row] = (0, 0, 0x0C, 0)

    # Inject Fxx tempo effects on row 0
    def _set_row0_fx(ch, effect, param):
        cell = grid[ch][0]
        if cell:
            grid[ch][0] = (cell[0], cell[1], effect, param)
        else:
            grid[ch][0] = (0, 0, effect, param)

    _set_row0_fx(num_channels - 1, 0x0F, speed)
    _set_row0_fx(num_channels - 2, 0x0F, bpm)

    # ---- write .MOD file ---------------------------------------------------
    out = Path(output_path) if output_path else Path(vgm_path).with_suffix('.mod')

    with open(str(out), 'wb') as f:
        f.write(Path(vgm_path).stem.encode('ascii', 'replace')[:20]
                .ljust(20, b'\x00'))

        # 31 sample headers
        for i in range(31):
            if i < len(samples):
                nm, pcm, vol, ls, ll = samples[i]
                wlen = len(pcm) // 2
            else:
                nm, pcm, vol, wlen, ls, ll = "", b"", 0, 0, 0, 1
            f.write(nm.encode('ascii', 'replace')[:22].ljust(22, b'\x00'))
            f.write(struct.pack('>H', wlen))       # sample length (words)
            f.write(b'\x00')                        # finetune
            f.write(struct.pack('B', min(64, vol)))
            f.write(struct.pack('>HH', ls, ll))    # loop start, loop length

        f.write(struct.pack('BB', total_pats, 127))
        f.write(bytes(range(total_pats)).ljust(128, b'\x00'))

        if num_channels == 4:
            f.write(b'M.K.')
        else:
            f.write(f'{num_channels}CHN'.encode('ascii'))

        for p in range(total_pats):
            for row in range(64):
                arow = p * 64 + row
                for ch in range(num_channels):
                    cell = grid[ch][arow] if arow < total_rows else None
                    f.write(_encode_cell(*cell) if cell else _EMPTY)

        for i in range(min(31, len(samples))):
            f.write(samples[i][1])

    placed = sum(1 for ch_grid in grid for c in ch_grid if c and c[1] > 0)
    total_pcm = sum(len(s[1]) for s in samples)
    print(f"Wrote {out} ({total_pats} patterns, {placed} notes, "
          f"{len(samples)} samples, {total_pcm} bytes PCM)")


# ---- CLI -------------------------------------------------------------------

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <input.vgm|.vgz> [output.mod] "
              f"[--channels 4|8]")
        sys.exit(1)

    args = sys.argv[1:]
    nch = 8
    if '--channels' in args:
        idx = args.index('--channels')
        nch = int(args[idx + 1])
        args = args[:idx] + args[idx + 2:]

    convert(args[0], args[1] if len(args) > 1 else None, num_channels=nch)
