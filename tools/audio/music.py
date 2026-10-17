"""The hut's brass band (section 11): an original polka, "Da Berghittn-Polka", played by a synthesised
band through a worn-out gramophone. Rendered once per tempo tier, so it gets faster every wave. Also
the Harmonika's tunes and the short stingers."""
import numpy as np
import dsp as d
import sfx

# --- the tune (B-flat major, 2/4; notes are MIDI numbers, lengths in eighths) ----------------------

A_MELODY = [
    [(77, 1), (74, 1), (77, 1), (74, 1)], [(82, 1), (81, 1), (79, 1), (77, 1)],
    [(75, 1), (72, 1), (75, 1), (72, 1)], [(81, 1), (79, 1), (77, 1), (75, 1)],
    [(72, 1), (75, 1), (79, 1), (77, 1)], [(75, 1), (74, 1), (72, 1), (69, 1)],
    [(70, 1), (74, 1), (77, 1), (82, 1)], [(82, 2), (None, 2)],
]
B_MELODY = [
    [(79, 1), (75, 1), (79, 1), (82, 1)], [(84, 2), (82, 1), (79, 1)],
    [(77, 1), (74, 1), (77, 1), (82, 1)], [(86, 2), (84, 1), (82, 1)],
    [(81, 1), (84, 1), (81, 1), (77, 1)], [(75, 1), (77, 1), (79, 1), (81, 1)],
    [(82, 1), (77, 1), (74, 1), (77, 1)], [(82, 2), (None, 2)],
]
# Chord per bar: (bass root, bass fifth, the "pah" chord).
I = (46, 41, [62, 65, 70])      # B-flat
V = (41, 48, [60, 63, 69])      # F7
IV = (39, 46, [58, 63, 67])     # E-flat
A_CHORDS = [I, I, V, V, V, V, I, I]
B_CHORDS = [IV, IV, I, I, V, V, I, I]
SCALE = [70, 72, 74, 75, 77, 79, 81]  # B-flat major, one octave from B-flat 4


def third_below(m: int) -> int:
    """The second cornet: the melody a diatonic third lower."""
    pc = [s % 12 for s in SCALE]
    while m % 12 not in pc:
        m -= 1
    i = pc.index(m % 12)
    j = i - 2
    target = SCALE[j % 7] % 12
    out = m - 1
    while out % 12 != target:
        out -= 1
    return out


def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


# --- instruments -----------------------------------------------------------------------------------

BRASS = [1, 0.95, 0.85, 0.72, 0.6, 0.5, 0.42, 0.34, 0.27, 0.21, 0.16, 0.12, 0.09, 0.07, 0.05]


def brass(m, dur, vel, bright, scoop=0.025):
    s = dur + 0.08
    t = d.t_of(s)
    f = hz(m) * (1 - scoop * np.exp(-t / 0.035))
    if dur > 0.35:
        f = f * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.2) / 0.3, 0, 1))
    b = d.env_points(s, [(0, bright * 0.3), (0.03, bright), (0.15, bright * 0.82), (s, bright * 0.7)])
    amp = d.env_points(s, [(0, 0), (0.018, 1), (0.08, 0.85), (dur, 0.75), (s, 0)])
    return d.harmonics(f, s, BRASS, b) * amp * vel


def clarinet(m, dur, vel):
    s = dur + 0.06
    t = d.t_of(s)
    f = hz(m) * (1 + 0.004 * np.sin(2 * np.pi * 6 * t))
    tone = d.harmonics(f, s, [1, 0.05, 0.5, 0.04, 0.3, 0.03, 0.18, 0.02, 0.1])
    return tone * d.env_points(s, [(0, 0), (0.03, 1), (dur, 0.8), (s, 0)]) * vel


def kick(vel=1.0):
    return d.mix(d.sine(d.glide(0.3, 90, 45), 0.3) * d.env_exp(0.3, 0.09), sfx.click(1500, 0.002, 0.15)) * vel


def snare(vel=1.0):
    rattle = d.bandpass(d.noise(0.2), 1500, 7000) * d.env_exp(0.2, 0.05)
    head = d.sine(190, 0.2) * d.env_exp(0.2, 0.03) * 0.6
    return (rattle + head) * vel


def cymbal(vel=1.0):
    metal = d.partials(1.6, [(f, 0.2, 0.5) for f in (3150, 4270, 5330, 6590, 7810)])
    wash = d.highpass(d.noise(1.6), 5000) * d.env_exp(1.6, 0.4)
    return (metal * 0.4 + wash) * d.env_exp(1.6, 0.6) * vel


def reed(m, dur, vel, s=None):
    """Accordion: three reeds, the outer two tuned apart for the wet musette shimmer."""
    s = s or dur + 0.05
    out = np.zeros(d.n_of(s))
    for cents, g in ((0, 1.0), (14, 0.8), (-12, 0.6)):
        f = hz(m) * 2 ** (cents / 1200)
        out += d.lowpass(d.square(f, s, 0.3), 3200) * g
    # A narrow pulse has a DC offset; take it out.
    return d.highpass(out, 40) * d.env_points(s, [(0, 0), (0.012, 1), (dur, 0.9), (s, 0)]) * vel


# --- sequencing ------------------------------------------------------------------------------------

class Score:
    def __init__(self, bpm: float, beats: float, tail: float = 3.0):
        self.beat = 60.0 / bpm
        self.length = beats * self.beat
        self.buf = np.zeros(d.n_of(self.length + tail))

    def put(self, at_beats: float, sig: np.ndarray, pan_gain: float = 1.0):
        i = d.n_of(at_beats * self.beat)
        n = min(len(sig), len(self.buf) - i)
        if n > 0:
            self.buf[i:i + n] += sig[:n] * pan_gain

    def looped(self) -> np.ndarray:
        """Folds whatever rings past the end back onto the start, for a seamless loop."""
        n = d.n_of(self.length)
        out = self.buf[:n].copy()
        rest = self.buf[n:]
        out[: len(rest)] += rest[: n]
        return out


def band(bpm: float, madness: float) -> np.ndarray:
    sc = Score(bpm, 64)
    e = sc.beat / 2  # one eighth in seconds
    sections = [(A_MELODY, A_CHORDS, False), (A_MELODY, A_CHORDS, True), (B_MELODY, B_CHORDS, True),
                (A_MELODY, A_CHORDS, True)]
    bar = 0
    for si, (mel, chords, full) in enumerate(sections):
        if full or si == 0:
            sc.put(bar * 2, cymbal(0.5 if si else 0.35))
        for b in range(8):
            at = (bar + b) * 2
            root, fifth, pah = chords[b]
            # Oom (tuba) on the beats, pah (horns) on the offbeats.
            sc.put(at, brass(root - 12, e * 1.6, 0.9, 0.35))
            sc.put(at + 1, brass(fifth - 12, e * 1.6, 0.8, 0.35))
            for m in pah:
                sc.put(at + 0.5, brass(m, e * 0.7, 0.22, 0.45, 0.01))
                sc.put(at + 1.5, brass(m, e * 0.7, 0.2, 0.45, 0.01))
            sc.put(at, kick(0.8))
            sc.put(at + 1, kick(0.6))
            sc.put(at + 0.5, snare(0.35))
            sc.put(at + 1.5, snare(0.35))
            pos = 0.0
            for m, length in mel[b]:
                if m is not None:
                    dur = length * e * 0.9
                    sc.put(at + pos, brass(m, dur, 0.55, 0.6))
                    if full:
                        sc.put(at + pos, brass(third_below(m), dur, 0.35, 0.5))
                    if si == 3:
                        sc.put(at + pos, clarinet(m + 12, dur, 0.18))
                pos += length * 0.5
        bar += 8
    # A snare roll into the top of the loop.
    for k in range(8):
        sc.put(62 + k * 0.25, snare(0.25 + 0.05 * k))
    return gramophone(sc.looped(), sc.length, madness)


def gramophone(x: np.ndarray, length: float, madness: float) -> np.ndarray:
    """The band through a worn-out horn: saturated, band-limited, wobbling and crackling. More madness
    each wave."""
    x = d.normalize(x)
    x = d.drive(x, 1.6 + madness)
    x = d.bandpass(x, 140, 5200)
    t = np.arange(len(x)) / d.SR
    # Wobble that fits whole cycles into the loop, so the seam stays clean.
    slow = max(1, round(length * 0.55)) / length
    fast = max(1, round(length * 6.5)) / length
    wobble = (0.0016 + 0.0008 * madness) * np.sin(2 * np.pi * slow * t) + 0.00025 * np.sin(2 * np.pi * fast * t)
    src = (t + wobble) % length
    x = np.interp(src * d.SR, np.arange(len(x)), x, period=len(x))
    crackle = np.zeros_like(x)
    idx = d.rng.integers(0, len(x), int(length * 9))
    crackle[idx] = d.rng.uniform(-1, 1, len(idx))
    x = x + d.lowpass(crackle, 3500) * 0.3 + d.lowpass(d.noise(length)[: len(x)], 2500) * 0.006
    return d.normalize(x, 0.85)


# Tempo per wave: the band starts at a gentle walk and gets out of hand.
TIERS = [100, 110, 120, 130, 140, 150, 160, 172]


def band_tier(i: int):
    return band(TIERS[i], i * 0.35)


def band_menu(_v):
    return band(92, 0.0) * 0.8


# --- stingers --------------------------------------------------------------------------------------

def wave_cleared(_v):
    """A short "ta-da" from the band: F, F, the high B-flat over an F-to-B-flat bass."""
    sc = Score(140, 6, 2.5)
    for at, m, dur in ((0, 77, 0.2), (0.5, 77, 0.2), (1.0, 82, 1.3)):
        sc.put(at, brass(m, dur, 0.6, 0.65))
        sc.put(at, brass(third_below(m), dur, 0.35, 0.5))
    sc.put(0, brass(29, 0.3, 0.9, 0.35))
    sc.put(1.0, brass(34, 1.3, 0.9, 0.35))
    for m in (62, 65, 70):
        sc.put(1.0, brass(m, 1.2, 0.22, 0.45))
    sc.put(1.0, cymbal(0.5))
    sc.put(1.0, kick(1.0))
    return d.normalize(d.fade(gramophone_oneshot(sc.buf)), 0.85)


def gramophone_oneshot(x):
    x = d.drive(d.normalize(x), 2.0)
    return d.bandpass(x, 140, 5200)


def game_over(_v):
    """The end of the tune as the gramophone winds down and stops."""
    sc = Score(120, 8, 3.0)
    for b, (mel, chords) in enumerate(zip(A_MELODY[4:], A_CHORDS[4:])):
        root, fifth, pah = chords
        sc.put(b * 2, brass(root - 12, 0.35, 0.9, 0.35))
        sc.put(b * 2 + 1, brass(fifth - 12, 0.35, 0.8, 0.35))
        for m in pah:
            sc.put(b * 2 + 0.5, brass(m, 0.18, 0.2, 0.45))
            sc.put(b * 2 + 1.5, brass(m, 0.18, 0.2, 0.45))
        pos = 0.0
        for m, length in mel:
            if m is not None:
                sc.put(b * 2 + pos, brass(m, length * 0.22, 0.55, 0.6))
            pos += length * 0.5
    x = gramophone_oneshot(sc.buf)
    # Speed falls from 1 to about 0.25: pitch and tempo sag together.
    n = len(x)
    rate = np.linspace(1.0, 0.22, n * 2) ** 1.3
    pos = np.cumsum(rate)
    pos = pos[pos < n - 1]
    out = np.interp(pos, np.arange(n), x)
    out *= d.env_points(len(out) / d.SR, [(0, 1), (len(out) / d.SR * 0.7, 0.9), (len(out) / d.SR, 0)])
    return d.normalize(d.fade(d.trim(out)), 0.85)


def event_call(_v):
    """A flugelhorn call for an event banner: "da-daa!" up a fourth."""
    x = d.mix(brass(72, 0.18, 0.7, 0.55), (0.22, brass(77, 0.7, 0.8, 0.6)), (0.22, brass(72, 0.7, 0.4, 0.5)))
    return d.normalize(d.fade(d.reverb(gramophone_oneshot(x), 1.2, 0.25)), 0.8)


# --- the Harmonika ---------------------------------------------------------------------------------

def _accordion(bpm, bars, melody_bars, chords, tail):
    sc = Score(bpm, bars * 2, tail)
    e = sc.beat / 2
    for b in range(bars):
        root, fifth, pah = chords[b % len(chords)]
        at = b * 2
        sc.put(at, reed(root, e * 0.9, 0.5))
        sc.put(at + 1, reed(fifth if fifth < 52 else fifth - 12, e * 0.9, 0.45))
        for m in pah:
            sc.put(at + 0.5, reed(m - 12, e * 0.5, 0.15))
            sc.put(at + 1.5, reed(m - 12, e * 0.5, 0.15))
        pos = 0.0
        for m, length in melody_bars[b % len(melody_bars)]:
            if m is not None:
                # Sixteenth flourishes: each eighth becomes the note and a quick neighbour.
                if length == 1:
                    sc.put(at + pos, reed(m, e * 0.45, 0.4))
                    sc.put(at + pos + 0.25, reed(m + 2 if m + 2 in SCALE + [84, 86] else m + 1, e * 0.45, 0.35))
                else:
                    sc.put(at + pos, reed(m, length * e * 0.9, 0.4))
            pos += length * 0.5
    return sc


def harmonika_polka(_v):
    """Left click: a fiery 4-bar polka (3.2 s, one shot's worth)."""
    sc = _accordion(150, 4, A_MELODY[:2] + A_MELODY[6:8], [I, I, V, I], 1.0)
    return d.normalize(d.fade(d.reverb(d.drive(d.normalize(sc.buf), 1.4), 0.8, 0.18)), 0.85)


# The Landler (right click held): a slow tune in three, four bars of um-pa-pa (6 s, looped).
LANDLER = [
    [(77, 2), (74, 1), (77, 1), (82, 2)],
    [(81, 3), (79, 1), (75, 2)],
    [(72, 2), (75, 1), (79, 1), (81, 2)],
    [(82, 4), (74, 2)],
]
LANDLER_CHORDS = [I, V, V, I]


def harmonika_play(_v):
    """Right click held: the Landler plays on, slow and swaying."""
    sc = Score(120, 12, 1.5)
    for b in range(4):
        root, fifth, pah = LANDLER_CHORDS[b]
        at = b * 3
        sc.put(at, reed(root if b % 2 == 0 else fifth, sc.beat * 0.9, 0.45))
        for k in (1, 2):
            for m in pah:
                sc.put(at + k, reed(m - 12, sc.beat * 0.5, 0.13))
        pos = 0.0
        for m, length in LANDLER[b]:
            # Lengths in eighths; a little swell on each note, as the bellows breathe.
            sc.put(at + pos, reed(m, length * sc.beat * 0.5 * 0.95, 0.42))
            pos += length * 0.5
    return d.normalize(sc.looped(), 0.8)


MUSIC = {"band_menu": band_menu, "wave_cleared": wave_cleared, "game_over": game_over}
for _i in range(len(TIERS)):
    MUSIC["band_%d" % (_i + 1)] = (lambda i: (lambda _v: band_tier(i)))(_i)
MUSIC_LOOPS = {"band_menu"} | {"band_%d" % (i + 1) for i in range(len(TIERS))}

# Played by weapons and events on the Effects bus, but written here because they are music.
MUSICAL_SFX = {"event_call": event_call, "harmonika_polka": harmonika_polka, "harmonika_play": harmonika_play}
MUSICAL_LOOPS = {"harmonika_play"}
