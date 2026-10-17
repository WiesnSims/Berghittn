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


# The Volksmusik tune (play-test 2026-10-18: the brass band sounded like a circus). Yodel-like broken
# chords, a duet in thirds, B-flat, 2/4.
VOLKS_A = [
    [(77, 1), (74, 1), (70, 1), (74, 1)], [(77, 2), (82, 2)],
    [(81, 1), (79, 1), (77, 1), (75, 1)], [(72, 1), (75, 1), (77, 2)],
    [(81, 1), (84, 1), (81, 1), (77, 1)], [(75, 1), (72, 1), (69, 1), (72, 1)],
    [(74, 1), (77, 1), (82, 1), (86, 1)], [(82, 2), (None, 2)],
]
VOLKS_B = [
    [(75, 1), (79, 1), (82, 1), (79, 1)], [(84, 1), (82, 1), (79, 1), (75, 1)],
    [(74, 1), (77, 1), (82, 1), (77, 1)], [(86, 2), (82, 2)],
    [(84, 1), (81, 1), (77, 1), (81, 1)], [(75, 1), (77, 1), (79, 1), (81, 1)],
    [(82, 1), (77, 1), (74, 1), (77, 1)], [(70, 2), (None, 2)],
]


def flugel(m, dur, vel):
    """Flugelhorn: a round, dark brass voice, softer than a trumpet."""
    s = dur + 0.1
    t = d.t_of(s)
    f = hz(m) * (1 - 0.012 * np.exp(-t / 0.03))
    if dur > 0.3:
        f = f * (1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.3, 0, 1))
    b = d.env_points(s, [(0, 0.15), (0.04, 0.42), (0.2, 0.34), (s, 0.3)])
    amp = d.env_points(s, [(0, 0), (0.03, 1), (dur, 0.8), (s, 0)])
    tone = d.harmonics(f, s, [1, 0.6, 0.35, 0.2, 0.12, 0.07, 0.04], b)
    return (tone + d.bandpass(d.noise(s), 600, 2500) * 0.02) * amp * vel


def guitar(m, vel):
    """A plucked chord tone (the off-beat "zupf" of the guitar); higher partials die first."""
    s = 0.6
    f = hz(m)
    parts = [(f * k, 1.0 / k, 0.35 / k ** 0.7) for k in range(1, 12)]
    return d.partials(s, parts) * d.env_points(s, [(0, 0), (0.003, 1), (s, 1)]) * vel


def tuba(m, dur, vel):
    return brass(m, dur, vel, 0.22, 0.01)


def _section(sc, at_bar, melody, chords, lead, duet):
    """Eight bars: bass on the beats, guitar and accordion chords on the off-beats, the tune on top."""
    e = sc.beat / 2
    for b in range(8):
        at = (at_bar + b) * 2
        root, fifth, chord = chords[b]
        sc.put(at, tuba(root - 12, e * 1.5, 0.75))
        sc.put(at + 1, tuba(fifth - 12, e * 1.5, 0.65))
        for k, m in enumerate(chord):
            sc.put(at + 0.5 + k * 0.012, guitar(m - 12, 0.16))
            sc.put(at + 1.5 + k * 0.012, guitar(m - 12, 0.14))
            sc.put(at + 0.5, reed(m, e * 0.45, 0.06))
            sc.put(at + 1.5, reed(m, e * 0.45, 0.06))
        pos = 0.0
        for m, length in melody[b]:
            if m is not None:
                dur = length * e * 0.92
                if lead == "harmonika":
                    sc.put(at + pos, reed(m, dur, 0.32))
                else:
                    sc.put(at + pos, flugel(m, dur, 0.5))
                if duet:
                    # The Volksmusik duet: clarinet a third below (and the flugelhorn when the harmonika leads).
                    sc.put(at + pos, clarinet(third_below(m), dur, 0.22))
            pos += length * 0.5


def band_intro(bpm: float, madness: float) -> np.ndarray:
    """At the start of a wave: the first eight bars, ending on the home chord (play-test: short)."""
    sc = Score(bpm, 18, 2.5)
    _section(sc, 0, VOLKS_A, A_CHORDS, "flugel", True)
    # The last chord rings out on everything.
    end = 14
    for m in (62, 65, 70):
        sc.put(end, reed(m, sc.beat * 2.5, 0.18))
        sc.put(end, guitar(m - 12, 0.2))
    sc.put(end, tuba(34, sc.beat * 2.5, 0.8))
    x = gramophone_oneshot(sc.buf, madness)
    return d.normalize(d.fade(d.trim(d.reverb(x, 1.0, 0.15))), 0.85)


def band(bpm: float) -> np.ndarray:
    """The whole tune, looped under the title screen: A (harmonika), A (duet), B (duet), A (all)."""
    sc = Score(bpm, 64, 2.5)
    _section(sc, 0, VOLKS_A, A_CHORDS, "harmonika", False)
    _section(sc, 8, VOLKS_A, A_CHORDS, "flugel", True)
    _section(sc, 16, VOLKS_B, B_CHORDS, "flugel", True)
    _section(sc, 24, VOLKS_A, A_CHORDS, "harmonika", True)
    return gramophone(sc.looped(), sc.length, 0.0)


def gramophone(x: np.ndarray, length: float, madness: float) -> np.ndarray:
    """The band off an old gramophone: a little saturated and band-limited, a slow wobble and some
    crackle. A touch more worn each wave."""
    x = d.normalize(x)
    x = d.drive(x, 1.2 + madness)
    x = d.bandpass(x, 110, 7000)
    t = np.arange(len(x)) / d.SR
    # Wobble that fits whole cycles into the loop, so the seam stays clean.
    slow = max(1, round(length * 0.55)) / length
    wobble = (0.0009 + 0.0005 * madness) * np.sin(2 * np.pi * slow * t)
    src = (t + wobble) % length
    x = np.interp(src * d.SR, np.arange(len(x)), x, period=len(x))
    crackle = np.zeros_like(x)
    idx = d.rng.integers(0, len(x), int(length * 6))
    crackle[idx] = d.rng.uniform(-1, 1, len(idx))
    x = x + d.lowpass(crackle, 3500) * 0.15
    return d.normalize(x, 0.85)


def gramophone_oneshot(x, madness: float = 0.0):
    x = d.drive(d.normalize(x), 1.2 + madness)
    crackle = np.zeros_like(x)
    idx = d.rng.integers(0, len(x), int(len(x) / d.SR * 6))
    crackle[idx] = d.rng.uniform(-1, 1, len(idx))
    return d.bandpass(x, 110, 7000) + d.lowpass(crackle, 3500) * 0.15


# Tempo per wave: the band starts at a gentle walk and gets out of hand.
TIERS = [100, 110, 120, 130, 140, 150, 160, 172]


def band_tier(i: int):
    return band_intro(TIERS[i], i * 0.2)


def band_menu(_v):
    return band(96)


def game_over(_v):
    """The end of the tune as the gramophone winds down and stops."""
    sc = Score(120, 16, 3.0)
    _section(sc, 0, VOLKS_A, A_CHORDS, "flugel", True)
    # Its last two bars.
    x = gramophone_oneshot(sc.buf[d.n_of(12 * sc.beat):])
    # Speed falls from 1 to about 0.25: pitch and tempo sag together.
    n = len(x)
    rate = np.linspace(1.0, 0.22, n * 2) ** 1.3
    pos = np.cumsum(rate)
    pos = pos[pos < n - 1]
    out = np.interp(pos, np.arange(n), x)[: d.n_of(4.0)]
    out *= d.env_points(len(out) / d.SR, [(0, 1), (len(out) / d.SR * 0.7, 0.9), (len(out) / d.SR, 0)])
    return d.normalize(d.fade(d.trim(out)), 0.85)


def event_call(_v):
    """A flugelhorn call for an event banner: "da-daa!" up a fourth."""
    x = d.mix(flugel(72, 0.18, 0.7), (0.22, flugel(77, 0.7, 0.8)), (0.22, flugel(72, 0.7, 0.4)))
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


MUSIC = {"band_menu": band_menu, "game_over": game_over}
for _i in range(len(TIERS)):
    MUSIC["band_%d" % (_i + 1)] = (lambda i: (lambda _v: band_tier(i)))(_i)
MUSIC_LOOPS = {"band_menu"}

# Played by weapons and events on the Effects bus, but written here because they are music.
MUSICAL_SFX = {"event_call": event_call, "harmonika_polka": harmonika_polka, "harmonika_play": harmonika_play}
MUSICAL_LOOPS = {"harmonika_play"}
