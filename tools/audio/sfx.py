"""Sound-effect recipes. Each takes a variant number (0, 1, ...) and returns a mono signal."""
import numpy as np
import dsp as d


# --- building blocks -------------------------------------------------------------------------------

def click(freq: float, decay: float = 0.006, level: float = 1.0, ring: float = 0.0):
    """A short mechanical click, with an optional metal ping."""
    n = d.noise(decay * 6)
    x = d.bandpass(n, freq * 0.6, min(freq * 1.6, 20000)) * d.env_exp(decay * 6, decay)
    if ring > 0:
        ping = d.partials(0.25, [(freq * 1.3, 0.3, 0.05), (freq * 2.1, 0.2, 0.03)])
        x = d.mix(x, ping * ring)
    return x * level


def thud(freq: float, decay: float, level: float = 1.0):
    """A dull knock: a falling sine and a puff of low noise."""
    s = decay * 6
    body = d.sine(d.glide(s, freq, freq * 0.6), s) * d.env_exp(s, decay)
    puff = d.lowpass(d.noise(s), freq * 4) * d.env_exp(s, decay * 0.5) * 0.4
    return (body + puff) * level


def whoosh(length: float, lo: float, hi: float, level: float = 1.0):
    """Air moving past: noise through a band that sweeps up and back down."""
    n = d.pink(length)
    t = np.linspace(0, 1, len(n))
    shape = np.sin(np.pi * t) ** 2
    centre = lo + (hi - lo) * shape
    out = np.zeros_like(n)
    # Five fixed bands weighted by where the sweep is; cheap and smooth enough for a swish.
    bands = np.geomspace(lo, hi, 5)
    for b in bands:
        w = np.exp(-((np.log(centre) - np.log(b)) ** 2) / 0.15)
        out += d.bandpass(n, b * 0.7, b * 1.4) * w
    return out * shape * level


def stick_slip(length: float, rate, bodies, level: float = 1.0):
    """Wood creak: a train of tiny slips (rate per second, may move) ringing wooden resonances."""
    p = d.phase(rate, length)
    impulses = np.zeros_like(p)
    idx = np.nonzero(np.diff(np.floor(p)) > 0)[0]
    impulses[idx] = d.rng.uniform(0.5, 1.0, len(idx))
    out = np.zeros_like(p)
    for f, q, g in bodies:
        out += g * d.resonator(impulses, f, q)
    return out * level


WOOD = [(310, 12, 1.0), (720, 14, 0.7), (1330, 16, 0.45), (2250, 18, 0.25)]


def gunshot(body_lp, body_decay, thump_f, thump_decay, crack, tail, wet, drv, length=1.6):
    crack_s = d.highpass(d.noise(0.03), 2500) * d.env_exp(0.03, 0.003) * crack
    body = d.lowpass(d.noise(length), body_lp) * d.env_exp(length, body_decay)
    mid = d.bandpass(d.noise(length), 400, 1800) * d.env_exp(length, body_decay * 0.6) * 0.6
    boom = d.sine(d.glide(length, thump_f, thump_f * 0.35, 0.5), length) * d.env_exp(length, thump_decay) * 1.3
    x = d.mix(crack_s, body, mid, boom)
    x = d.drive(d.normalize(x), drv)
    x = d.reverb(x, tail, wet, damp=3000)
    return d.fade(d.trim(x), 0.0005, 0.05)


def voice(seconds, f0, path, shift=1.0, breath=0.15, jitter=0.02, rough=0.0, drv=1.5):
    """A groan, moo or scream: buzzy source, vowel filters, a bit of breath."""
    src = d.glottal(f0, seconds, jitter=jitter, shimmer=0.25)
    if rough > 0:
        # Sub-harmonic growl (vocal fry).
        src *= 1.0 + rough * d.square(np.asarray(f0) * 0.5 if np.ndim(f0) else f0 * 0.5, seconds)
    src = src + d.noise(seconds) * breath
    x = d.vowel_morph(src, path, shift)
    return d.drive(d.normalize(x), drv)


def bell(seconds, f, ratios, decays, amps):
    return d.partials(seconds, [(f * r, a, dc) for r, dc, a in zip(ratios, decays, amps)])


# --- player weapons --------------------------------------------------------------------------------

def shot_pistole(v):
    return gunshot(3500, 0.035, 160, 0.05, 1.0, 0.9, 0.22, 2.5)


def shot_jagdflinte(v):
    return gunshot(2200, 0.09, 85, 0.11, 0.8, 1.4, 0.3, 3.5)


def shot_jagdflinte_both(v):
    a = gunshot(2000, 0.12, 70, 0.14, 0.9, 1.8, 0.35, 4.5)
    return d.normalize(d.mix(a, (0.018, a * 0.8)))


def shot_stutzen(v):
    return gunshot(4500, 0.06, 110, 0.08, 1.4, 1.8, 0.32, 3.0)


def shot_repetierer(v):
    return gunshot(3800, 0.05, 130, 0.07, 1.1, 1.4, 0.28, 2.8)


def dry_click(v):
    return d.mix(click(3200, 0.003), (0.03, click(1800, 0.004, 0.5)))


def mag_out(v):
    return d.mix(click(2600, 0.005), (0.05, d.bandpass(d.noise(0.12), 900, 3000) * d.env_exp(0.12, 0.03) * 0.3))


def mag_in(v):
    return d.mix(click(1700, 0.006, 1.0), (0.04, click(2400, 0.004, 0.6)), (0.32, click(3000, 0.004, 0.9)),
                 (0.34, click(1500, 0.006, 0.6)))


def break_open(v):
    return d.mix(click(2200, 0.004), (0.06, thud(260, 0.03, 0.6)), (0.07, click(1400, 0.008, 0.5)),
                 (0.35, click(4000, 0.002, 0.3)), (0.45, click(4200, 0.002, 0.3)))


def break_close(v):
    return d.mix(click(1200, 0.01, 0.8), (0.0, thud(200, 0.04, 0.9)), (0.05, click(3000, 0.004, 0.6)))


def bolt_open(v):
    slide = d.bandpass(d.noise(0.15), 1500, 5000) * d.env_points(0.15, [(0, 0), (0.03, 0.4), (0.15, 0)])
    return d.mix(click(2200, 0.004), (0.06, slide))


def bolt_close(v):
    slide = d.bandpass(d.noise(0.12), 1500, 5000) * d.env_points(0.12, [(0, 0), (0.05, 0.4), (0.12, 0)])
    return d.mix(slide, (0.11, click(2000, 0.005, 1.0)), (0.2, click(1600, 0.006, 0.8)))


def lever_open(v):
    return d.mix(click(1900, 0.005), (0.08, click(2600, 0.004, 0.6)), (0.3, click(3800, 0.002, 0.4)))


def lever_close(v):
    return d.mix(click(1700, 0.006), (0.09, click(2200, 0.006, 1.0)), (0.1, thud(400, 0.02, 0.4)))


def load_clunk(v):
    return d.mix(thud(170, 0.05, 1.0), (0.01, click(900, 0.01, 0.6)))


def load_ready(v):
    return d.mix(click(1500, 0.008, 0.7), (0.0, thud(240, 0.03, 0.6)), (0.12, click(2600, 0.004, 0.5)))


def weapon_raise(v):
    return d.mix(d.bandpass(d.noise(0.25), 500, 3000) * d.env_points(0.25, [(0, 0), (0.08, 0.15), (0.25, 0)]),
                 (0.16, click(2100, 0.004, 0.4)))


def hitmarker(v):
    return d.highpass(click(5000, 0.002), 2000) * 0.8 + 0


def headshot(v):
    x = bell(0.35, 2600, [1, 2.4, 3.9], [0.12, 0.06, 0.03], [1, 0.4, 0.2])
    return d.mix(x * 0.7, click(6000, 0.002, 0.5))


def bellows(v):
    """The Harmonika's air button: bellows pulled open, then pressed shut."""
    air = d.bandpass(d.noise(2.6), 300, 2500)
    env = d.env_points(2.6, [(0, 0), (0.6, 0.35), (1.2, 0.1), (1.4, 0.0), (1.6, 0.3), (2.4, 0.25), (2.6, 0)])
    return d.mix(air * env, (2.45, thud(220, 0.03, 0.6)), (2.48, click(1800, 0.006, 0.5)))


def alphorn_load(v):
    inhale = d.bandpass(d.noise(1.4), 400, 2500) * d.env_points(1.4, [(0, 0), (1.1, 0.4), (1.4, 0)])
    return d.mix(thud(140, 0.06, 0.9), (0.02, d.resonator(d.noise(0.2) * d.env_exp(0.2, 0.01), 280, 8) * 0.4),
                 (0.7, inhale))


# --- melee ----------------------------------------------------------------------------------------

def swing(v):
    return whoosh(0.28, 300 + 60 * v, 2600, 0.9)


def throw(v):
    return whoosh(0.32, 450, 3200, 0.8)


def schaufel_hit(v):
    clang = bell(1.0, 410 + 25 * v, [1, 2.71, 4.43, 6.3, 8.9], [0.25, 0.14, 0.08, 0.05, 0.03], [1, 0.6, 0.45, 0.3, 0.2])
    return d.normalize(d.mix(thud(130, 0.04, 1.2), clang * 0.8, click(3500, 0.003, 0.6)))


def pfanne_bonk(v):
    ring = bell(1.6, 300 + 12 * v, [1, 2.32, 3.94, 5.6], [0.6, 0.35, 0.18, 0.1], [1, 0.55, 0.3, 0.2])
    # A short downward wobble sells the cartoon "bonk".
    wob = d.sine(d.glide(0.25, 520, 300), 0.25) * d.env_exp(0.25, 0.06) * 0.6
    return d.normalize(d.mix(thud(150, 0.035, 1.0), ring * 0.9, wob))


def goassl_crack(v):
    # The tip breaks the sound barrier: a whoosh, then a hard broadband snap and its slap off the walls.
    snap = d.highpass(d.noise(0.012), 1200) * d.env_exp(0.012, 0.0015) * 3.0
    x = d.mix(whoosh(0.22, 600, 4000, 0.4), (0.2, snap), (0.2, click(2500, 0.004, 1.0)))
    return d.fade(d.trim(d.reverb(d.drive(d.normalize(x), 2.0), 0.7, 0.25)), 0.001, 0.03)


def mistgabel_stab(v):
    wet = d.lowpass(d.noise(0.2), 700) * d.env_exp(0.2, 0.03)
    tines = bell(0.4, 1900 + 80 * v, [1, 1.07, 1.52], [0.08, 0.07, 0.05], [0.4, 0.3, 0.2])
    return d.normalize(d.mix(whoosh(0.12, 800, 3000, 0.5), (0.08, wet), (0.08, tines), (0.08, thud(180, 0.03, 0.6))))


def rute_hit(v):
    twigs = np.zeros(d.n_of(0.3))
    for _ in range(40):
        i = d.n_of(d.rng.uniform(0.15, 0.2))
        c = click(d.rng.uniform(2000, 6000), 0.002, d.rng.uniform(0.2, 0.6))
        twigs[i:i + len(c)] += c[: len(twigs) - i]
    slap = d.bandpass(d.noise(0.08), 900, 4500) * d.env_exp(0.08, 0.01)
    return d.normalize(d.mix(whoosh(0.18, 1500, 6000, 0.7), twigs, (0.16, slap)))


def block_hit(v):
    return d.normalize(d.mix(thud(160, 0.04, 1.0), click(1500, 0.01, 0.7),
                             bell(0.5, 700, [1, 2.3], [0.08, 0.04], [0.3, 0.15])))


# --- special weapons -------------------------------------------------------------------------------

def _alphorn_note(seconds, f0, scoop=0.15):
    pitch = f0 * d.env_points(seconds, [(0, 0.82), (scoop, 1.0), (seconds, 0.99)])
    pitch = pitch * (1.0 + 0.008 * d.sine(5.2, seconds) * d.env_points(seconds, [(0, 0), (0.4, 0), (1.0, 1), (seconds, 1)]))
    bright = d.env_points(seconds, [(0, 0.2), (0.12, 0.75), (0.5, 0.62), (seconds - 0.2, 0.55), (seconds, 0.2)])
    tone = d.harmonics(pitch, seconds, [1, 0.8, 0.9, 0.7, 0.55, 0.4, 0.3, 0.22, 0.15, 0.1, 0.07, 0.05], bright)
    breath = d.bandpass(d.noise(seconds), 300, 2000) * 0.05
    amp = d.env_points(seconds, [(0, 0), (0.08, 0.9), (0.2, 1.0), (seconds - 0.25, 0.85), (seconds, 0)])
    return d.drive((tone + breath) * amp, 1.6)


def alphorn_blast(v):
    note = _alphorn_note(1.5, 87.3)
    rumble = d.lowpass(d.noise(1.5), 120) * d.env_exp(1.5, 0.5) * 0.6
    return d.normalize(d.fade(d.reverb(note + rumble, 1.5, 0.25, 2500)))


def alphorn_echo(v):
    up = _alphorn_note(1.8, 130.8, 0.25)
    sky = d.echo(up, 0.33, 0.62, 6, 2200)
    return d.normalize(d.fade(d.reverb(sky, 2.2, 0.45, 2000)))


def knoedel_launch(v):
    pop = d.sine(d.glide(0.25, 240, 55), 0.25) * d.env_exp(0.25, 0.05)
    puff = d.lowpass(d.noise(0.3), 1300) * d.env_exp(0.3, 0.04) * 0.7
    return d.normalize(d.mix(pop, puff, click(900, 0.008, 0.5)))


def splat(v, size=1.0):
    base = d.lowpass(d.noise(0.5), 1600 / size) * d.env_exp(0.5, 0.05 * size)
    out = d.mix(base)
    for _ in range(5):
        at = d.rng.uniform(0.0, 0.18) * size
        f = d.rng.uniform(250, 700) / size
        bub = d.sine(d.glide(0.08, f, f * 1.8), 0.08) * d.env_exp(0.08, 0.02) * 0.35
        out = d.mix(out, (at, bub))
    return d.normalize(d.fade(out))


def knoedel_splat(v):
    return splat(v, 1.0)


def rodel_launch(v):
    t = d.t_of(0.7)
    boing = np.sin(2 * np.pi * np.cumsum(180 * (1 + 0.35 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 4))) / d.SR)
    boing *= d.env_exp(0.7, 0.2)
    return d.normalize(d.mix(boing * 0.8, whoosh(0.6, 300, 1500, 0.6), thud(120, 0.05, 0.6)))


def rodel_hit(v):
    out = d.mix(thud(140, 0.05, 1.0))
    for _ in range(6):
        at = d.rng.uniform(0.02, 0.25)
        c = d.resonator(d.noise(0.1) * d.env_exp(0.1, 0.004), d.rng.uniform(600, 1400), 20) * 0.3
        out = d.mix(out, (at, c))
    return d.normalize(out)


def flame_loop(v):
    s = 4.0
    roar = d.lowpass(d.brown(s + 0.5), 900) * (0.8 + 0.3 * d.smooth_noise(s + 0.5, 8))
    hiss = d.bandpass(d.noise(s + 0.5), 1500, 6000) * 0.12 * (0.7 + 0.3 * d.smooth_noise(s + 0.5, 15))
    x = roar + hiss
    for _ in range(40):
        at = d.rng.uniform(0, s)
        c = click(d.rng.uniform(800, 3000), 0.003, d.rng.uniform(0.1, 0.4))
        i = d.n_of(at)
        x[i:i + len(c)] += c[: len(x) - i]
    return d.normalize(d.loopable(x, 0.5), 0.8)


def flame_start(v):
    whoom = d.lowpass(d.noise(0.6), 1200) * d.env_points(0.6, [(0, 0), (0.08, 1), (0.6, 0)])
    return d.normalize(d.mix(click(2500, 0.005, 0.4), whoom))


def boeller_launch(v):
    pop = d.sine(d.glide(0.4, 160, 45), 0.4) * d.env_exp(0.4, 0.08)
    fuse = d.bandpass(d.noise(0.8), 2500, 8000) * d.env_points(0.8, [(0, 0), (0.1, 0.25), (0.8, 0)])
    return d.normalize(d.fade(d.reverb(d.mix(pop * 1.2, d.lowpass(d.noise(0.4), 900) * d.env_exp(0.4, 0.06), fuse), 1.0, 0.25)))


def boeller_bang(v):
    return gunshot(1500, 0.25, 55, 0.35, 1.3, 2.8, 0.42, 5.0, length=2.5)


# --- equipment -------------------------------------------------------------------------------------

def _cowbell_hit(f, level):
    hit = bell(1.4, f, [1, 1.47, 2.09, 2.76, 3.61, 4.95], [0.5, 0.35, 0.25, 0.15, 0.1, 0.06],
                [1, 0.7, 0.5, 0.35, 0.25, 0.15]) * level
    return d.mix(hit, click(2500, 0.003, 0.3 * level))


def bell_loop(f, seconds, swing_rate):
    """A bell swinging on a neck: strikes come in pairs, a little irregular."""
    x = np.zeros(d.n_of(seconds + 1.5))
    t = 0.05
    while t < seconds:
        h = _cowbell_hit(f * d.rng.uniform(0.995, 1.005), d.rng.uniform(0.5, 1.0))
        i = d.n_of(t)
        x[i:i + len(h)] += h[: len(x) - i]
        t += d.rng.uniform(0.6, 1.4) / swing_rate
    # Fold the tail back into the start so it loops.
    n = d.n_of(seconds)
    x[: len(x) - n] += x[n:]
    return d.normalize(x[:n], 0.8)


def kuhglocke_ring(v):
    return bell_loop(520, 4.0, 3.2)


def resi_bell(v):
    return bell_loop(330, 6.0, 1.4)


def eisstock_slide(v):
    s = 3.0
    rumble = d.bandpass(d.brown(s + 0.4), 80, 700) * (0.8 + 0.2 * d.smooth_noise(s + 0.4, 10))
    grit = d.bandpass(d.noise(s + 0.4), 1500, 5000) * 0.05
    return d.normalize(d.loopable(rumble + grit, 0.4), 0.7)


def eisstock_hit(v):
    return d.normalize(d.mix(thud(110, 0.08, 1.2), bell(0.5, 640, [1, 2.2, 3.3], [0.12, 0.06, 0.04], [0.4, 0.2, 0.1]),
                             click(1800, 0.008, 0.6)))


def kuhfladen_splat(v):
    return splat(v, 1.6)


def kuhfladen_squelch(v):
    sq = d.lowpass(d.noise(0.4), 900) * d.env_points(0.4, [(0, 0), (0.05, 1), (0.4, 0)])
    bub = d.sine(d.glide(0.3, 180, 420), 0.3) * d.env_exp(0.3, 0.08) * 0.5
    return d.normalize(d.mix(sq, (0.05, bub)))


# --- enemies ---------------------------------------------------------------------------------------

def groan_wanderer(v):
    s = d.rng.uniform(1.3, 1.9)
    f0 = d.glide(s, d.rng.uniform(95, 110), d.rng.uniform(75, 85))
    path = [(0.0, "u"), (s * 0.35, "o"), (s * 0.6, "a"), (s, "o")]
    x = voice(s, f0, path, 0.95, 0.2, 0.03, 0.2) * d.env_points(s, [(0, 0), (0.2, 1), (s * 0.7, 0.8), (s, 0)])
    return d.normalize(d.fade(d.reverb(x, 0.6, 0.15)))


def groan_knappe(v):
    s = d.rng.uniform(1.4, 2.0)
    f0 = d.glide(s, d.rng.uniform(78, 86), d.rng.uniform(60, 66))
    path = [(0.0, "m"), (s * 0.2, "o"), (s * 0.7, "u"), (s, "m")]
    x = voice(s, f0, path, 0.85, 0.25, 0.04, 0.45, 2.2) * d.env_points(s, [(0, 0), (0.25, 1), (s * 0.75, 0.8), (s, 0)])
    return d.normalize(d.fade(d.reverb(x, 0.6, 0.15)))


def groan_perchte(v):
    s = d.rng.uniform(0.9, 1.3)
    hiss = d.bandpass(d.noise(s), 2000, 7000) * d.env_points(s, [(0, 0), (0.1, 0.6), (s, 0)])
    f0 = d.glide(s, d.rng.uniform(260, 300), d.rng.uniform(180, 210))
    shriek = voice(s, f0, [(0, "i"), (s * 0.5, "ae"), (s, "a")], 1.15, 0.5, 0.06, 0.3, 3.0)
    shriek *= d.env_points(s, [(0, 0), (0.08, 0.8), (s, 0)])
    jingle = np.zeros(d.n_of(s))
    for _ in range(10):
        b = bell(0.4, d.rng.uniform(2200, 3200), [1, 2.76], [0.08, 0.04], [0.25, 0.1])
        i = d.n_of(d.rng.uniform(0, s - 0.1))
        jingle[i:i + len(b)] += b[: len(jingle) - i]
    return d.normalize(d.fade(d.mix(shriek * 0.8, hiss, jingle * 0.8)))


def groan_tourist(v):
    s = d.rng.uniform(0.8, 1.2)
    f0 = d.glide(s, d.rng.uniform(140, 160), d.rng.uniform(120, 135))
    path = [(0.0, "e"), (s * 0.5, "ae"), (s, "e")]
    x = voice(s, f0, path, 1.1, 0.15, 0.03, 0.1) * d.env_points(s, [(0, 0), (0.1, 1), (s * 0.6, 0.9), (s, 0)])
    return d.normalize(d.fade(x))


def krampus_roar(v):
    s = 2.2
    f0 = d.env_points(s, [(0, 55), (0.3, 72), (1.4, 66), (s, 48)])
    x = voice(s, f0, [(0, "o"), (0.4, "a"), (1.6, "a"), (s, "o")], 0.75, 0.6, 0.05, 0.8, 4.0)
    x = x * d.env_points(s, [(0, 0), (0.25, 1), (1.6, 0.9), (s, 0)])
    sub = d.lowpass(d.noise(s), 150) * d.env_points(s, [(0, 0), (0.3, 0.8), (s, 0)])
    return d.normalize(d.fade(d.reverb(d.mix(x, sub), 1.4, 0.3, 2500)))


def chains(v):
    s = 1.4
    x = np.zeros(d.n_of(s + 0.4))
    t = 0.0
    while t < s:
        link = bell(0.25, d.rng.uniform(1800, 4200), [1, 1.6, 2.3], [0.04, 0.03, 0.02], [0.5, 0.3, 0.2])
        i = d.n_of(t)
        x[i:i + len(link)] += link[: len(x) - i] * d.rng.uniform(0.3, 1.0)
        t += d.rng.uniform(0.015, 0.09)
    return d.normalize(d.fade(x * d.env_points(len(x) / d.SR, [(0, 0.6), (0.4, 1), (len(x) / d.SR, 0)])))


def enemy_death(v):
    s = d.rng.uniform(1.0, 1.3)
    f0 = d.glide(s, d.rng.uniform(110, 130), 55, 0.7)
    x = voice(s, f0, [(0, "a"), (s * 0.5, "o"), (s, "u")], 1.0, 0.3, 0.04, 0.3) * d.env_points(s, [(0, 0), (0.05, 1), (s, 0)])
    fall = d.mix(thud(90, 0.07, 1.0), (0.08, thud(140, 0.04, 0.5)))
    return d.normalize(d.fade(d.mix(x, (s * 0.75, fall * 1.2))))


def enemy_attack(v):
    s = 0.5
    f0 = d.glide(s, 130, 95)
    grunt = voice(s, f0, [(0, "a"), (s, "o")], 0.9, 0.3, 0.03, 0.4, 2.5) * d.env_points(s, [(0, 0), (0.05, 1), (s, 0)])
    return d.normalize(d.mix(grunt * 0.8, (0.1, whoosh(0.25, 400, 2000, 0.7))))


def board_pull(v):
    s = 0.8
    rate = d.glide(s, d.rng.uniform(40, 60), d.rng.uniform(150, 250))
    creak = stick_slip(s, rate, WOOD) * d.env_points(s, [(0, 0), (0.2, 0.6), (0.55, 1), (0.6, 0)])
    crack = d.mix(click(1200, 0.01, 1.0), (0.01, thud(200, 0.03, 0.8)), (0.02, click(3000, 0.004, 0.6)))
    nail = d.sine(d.glide(0.25, 2400, 3800), 0.25) * d.env_exp(0.25, 0.08) * 0.15
    return d.normalize(d.fade(d.reverb(d.mix(creak * 0.6, (0.55, crack), (0.5, nail)), 0.5, 0.15)))


def board_nail(v):
    hit = d.mix(thud(240, 0.025, 0.8), click(1800, 0.004, 0.8),
                bell(0.3, 2900, [1, 2.4], [0.04, 0.02], [0.15, 0.08]))
    return d.normalize(d.mix(hit, (0.22, hit * 0.9), (0.42, hit)))


def window_climb(v):
    return d.normalize(d.mix(thud(150, 0.05, 1.0), (0.2, d.bandpass(d.noise(0.3), 300, 2000) * d.env_exp(0.3, 0.08) * 0.5),
                             (0.45, thud(110, 0.06, 1.2))))


# --- player ----------------------------------------------------------------------------------------

def player_hurt(v):
    s = 0.35
    f0 = d.glide(s, d.rng.uniform(150, 170), 110)
    grunt = voice(s, f0, [(0, "u"), (s, "o")], 1.0, 0.2, 0.02, 0.1) * d.env_points(s, [(0, 0), (0.02, 1), (s, 0)])
    punch = d.lowpass(d.noise(0.15), 500) * d.env_exp(0.15, 0.025)
    return d.normalize(d.mix(punch, (0.01, grunt * 0.7)))


def player_death(v):
    s = 1.6
    f0 = d.glide(s, 170, 70, 0.8)
    x = voice(s, f0, [(0, "a"), (0.8, "a"), (s, "o")], 1.0, 0.3, 0.03, 0.2) * d.env_points(s, [(0, 0), (0.05, 1), (s, 0)])
    return d.normalize(d.fade(d.reverb(d.mix(x, (1.1, thud(80, 0.1, 1.2))), 1.2, 0.3)))


def step_snow(v):
    s = 0.22
    x = np.zeros(d.n_of(s))
    for _ in range(60):
        c = click(d.rng.uniform(1500, 5000), 0.0015, d.rng.uniform(0.1, 0.5))
        i = d.n_of(d.rng.uniform(0, 0.12) ** 1.4 * 3)
        if i < len(x):
            x[i:i + len(c)] += c[: len(x) - i]
    body = d.lowpass(d.noise(s), 700) * d.env_exp(s, 0.04) * 0.6
    return d.normalize(d.fade(x + body), 0.7)


def step_wood(v):
    knock = d.mix(thud(d.rng.uniform(110, 150), 0.03, 1.0), click(900, 0.006, 0.25))
    if v % 2 == 1:
        knock = d.mix(knock, (0.05, stick_slip(0.15, d.rng.uniform(60, 120), WOOD) * d.env_exp(0.15, 0.05) * 0.4))
    return d.normalize(d.fade(d.reverb(knock, 0.35, 0.12)), 0.7)


def land(v):
    return d.normalize(d.mix(thud(90, 0.06, 1.0), d.lowpass(d.noise(0.2), 800) * d.env_exp(0.2, 0.03) * 0.5), 0.8)


# --- economy ---------------------------------------------------------------------------------------

def buy(v):
    ding = bell(1.2, 2093, [1, 2.0, 2.76, 4.1], [0.5, 0.3, 0.15, 0.08], [1, 0.4, 0.3, 0.15])
    drawer = d.mix(d.bandpass(d.noise(0.25), 400, 3000) * d.env_exp(0.25, 0.06) * 0.4, (0.18, thud(200, 0.03, 0.6)))
    return d.normalize(d.mix(click(1500, 0.005, 0.6), (0.05, ding * 0.7), (0.15, drawer)))


def deny(v):
    tone = d.lowpass(d.square(110, 0.12) * 0.5, 900) * d.env_points(0.12, [(0, 0), (0.01, 1), (0.1, 1), (0.12, 0)])
    return d.normalize(d.mix(tone, (0.16, tone)), 0.3)


def door_open(v):
    s = 1.6
    rate = d.env_points(s, [(0, 30), (0.5, 90), (1.0, 60), (1.4, 140), (s, 120)])
    creak = stick_slip(s, rate, [(420, 10, 1.0), (890, 12, 0.7), (1600, 14, 0.4), (2600, 16, 0.2)])
    creak *= d.env_points(s, [(0, 0), (0.2, 0.8), (1.3, 1.0), (s, 0)])
    latch = d.mix(click(1600, 0.006, 1.0), (0.05, click(2400, 0.004, 0.6)))
    return d.normalize(d.fade(d.reverb(d.mix(latch, (0.12, creak * 0.7), (1.65, thud(100, 0.08, 0.9))), 0.8, 0.2)))


def creak(v):
    s = d.rng.uniform(0.5, 1.2)
    rate = d.glide(s, d.rng.uniform(20, 40), d.rng.uniform(60, 120))
    base = d.rng.uniform(0.8, 1.2)
    x = stick_slip(s, rate, [(f * base, q, g) for f, q, g in WOOD]) * d.env_points(s, [(0, 0), (s * 0.3, 1), (s, 0)])
    return d.normalize(d.fade(d.reverb(x, 0.8, 0.25)), 0.8)


def chest_open(v):
    s = 0.9
    lid = stick_slip(s, d.glide(s, 50, 110), WOOD) * d.env_points(s, [(0, 0), (0.2, 0.6), (s, 0)])
    return d.normalize(d.fade(d.mix(click(1300, 0.008, 1.0), (0.08, lid * 0.6))))


def chest_tick(v):
    """A music-box note for each weapon the Hüttentruhe flips through (one variant per pentatonic step)."""
    note = 1046.5 * 2 ** ([0, 2, 4, 7, 9, 12][v] / 12)
    b = bell(0.7, note, [1, 3.0, 5.4], [0.25, 0.08, 0.03], [1, 0.25, 0.08])
    return d.normalize(d.fade(d.reverb(b, 0.6, 0.2)), 0.7)


def chest_reveal(v):
    notes = [784, 988, 1175, 1568]
    x = d.mix(*[(i * 0.06, bell(1.4, f, [1, 2.0, 3.0], [0.5, 0.2, 0.1], [1, 0.3, 0.12])) for i, f in enumerate(notes)])
    return d.normalize(d.fade(d.reverb(x, 1.2, 0.3)), 0.8)


def perk_drink(v):
    cork = d.mix(d.sine(d.glide(0.08, 700, 1400), 0.08) * d.env_exp(0.08, 0.02), click(2500, 0.003, 0.5))
    glug = np.zeros(d.n_of(1.2))
    for k in range(5):
        f = 300 + 40 * k
        b = d.sine(d.glide(0.12, f, f * 1.7), 0.12) * d.env_exp(0.12, 0.04)
        b = d.mix(b, d.lowpass(d.noise(0.12), 600) * d.env_exp(0.12, 0.03) * 0.3)
        i = d.n_of(0.12 + k * 0.17)
        glug[i:i + len(b)] += b[: len(glug) - i]
    aah = voice(0.7, d.glide(0.7, 160, 120), [(0, "a"), (0.7, "a")], 1.0, 0.6, 0.02, 0.0, 1.2)
    aah *= d.env_points(0.7, [(0, 0), (0.1, 0.5), (0.7, 0)])
    return d.normalize(d.fade(d.mix(cork, (0.15, glug), (1.5, aah))))


def jause_eat(v):
    x = np.zeros(d.n_of(1.6))
    for k in range(4):
        at = 0.05 + k * 0.28
        crunch = np.zeros(d.n_of(0.12))
        for _ in range(15):
            c = click(d.rng.uniform(1000, 4000), 0.002, d.rng.uniform(0.2, 0.6))
            i = d.n_of(d.rng.uniform(0, 0.08))
            crunch[i:i + len(c)] += c[: len(crunch) - i]
        chomp = d.lowpass(d.noise(0.12), 500) * d.env_exp(0.12, 0.03)
        i = d.n_of(at)
        seg = crunch + chomp
        x[i:i + len(seg)] += seg[: len(x) - i]
    mmh = voice(0.5, 140, [(0, "m"), (0.5, "m")], 1.0, 0.05, 0.02, 0.0, 1.2) * d.env_points(0.5, [(0, 0), (0.1, 0.5), (0.5, 0)])
    return d.normalize(d.fade(d.mix(x, (1.15, mmh))))


def ammo_crate(v):
    lid = d.mix(thud(180, 0.04, 1.0), click(900, 0.01, 0.5))
    rattle = np.zeros(d.n_of(0.7))
    for _ in range(30):
        c = bell(0.15, d.rng.uniform(2500, 5000), [1, 1.5], [0.02, 0.01], [0.3, 0.1])
        i = d.n_of(d.rng.uniform(0, 0.5))
        rattle[i:i + len(c)] += c[: len(rattle) - i] * d.rng.uniform(0.3, 1)
    return d.normalize(d.fade(d.mix(lid, (0.15, rattle))))


def ui_click(v):
    return d.normalize(d.mix(thud(700, 0.008, 0.6), click(2400, 0.003, 0.5)), 0.5)


# --- waves -----------------------------------------------------------------------------------------

def _hut_bell(f, level=1.0):
    # Ratios of a small cast bell: hum, prime, minor third, fifth, nominal and up.
    return bell(4.0, f, [0.5, 1.0, 1.19, 1.5, 2.0, 2.52, 3.0], [2.0, 1.4, 1.0, 0.8, 0.7, 0.4, 0.3],
                [0.6, 1.0, 0.6, 0.35, 0.5, 0.25, 0.15]) * level


def wave_start(v):
    x = d.mix(_hut_bell(587), (0.9, _hut_bell(587, 0.8)))
    return d.normalize(d.fade(d.reverb(x, 2.5, 0.35, 3000)), 0.8)


def boss_wave(v):
    x = d.mix(_hut_bell(294), (1.1, _hut_bell(294, 0.9)), (2.2, _hut_bell(294, 0.8)), (0.3, chains(0) * 0.5))
    return d.normalize(d.fade(d.reverb(x, 3.0, 0.4, 2500)), 0.9)


# --- events ----------------------------------------------------------------------------------------

def resi_moo(v):
    s = d.rng.uniform(1.6, 2.2)
    f0 = d.env_points(s, [(0, 120), (0.3, 150), (s * 0.7, 140), (s, 105)])
    x = voice(s, f0, [(0, "m"), (0.3, "u"), (s * 0.6, "o"), (s, "u")], 0.8, 0.2, 0.02, 0.1, 1.5)
    x *= d.env_points(s, [(0, 0), (0.15, 0.8), (s * 0.8, 1), (s, 0)])
    return d.normalize(d.fade(d.reverb(x, 1.2, 0.25)))


def milk(v):
    x = np.zeros(d.n_of(2.4))
    for k in range(8):
        sq = d.bandpass(d.noise(0.15), 1500, 6000) * d.env_exp(0.15, 0.04)
        ping = bell(0.4, 900 + 20 * k, [1, 2.2], [0.1, 0.05], [0.3, 0.1])
        i = d.n_of(0.1 + k * 0.28)
        seg = d.mix(sq, ping)
        x[i:i + len(seg)] += seg[: len(x) - i]
    return d.normalize(d.fade(x), 0.8)


def fassl_roll(v):
    s = 2.0
    rumble = d.bandpass(d.brown(s + 0.4), 50, 400) * (0.7 + 0.3 * d.smooth_noise(s + 0.4, 6))
    x = rumble.copy()
    # Staves knocking once a turn, and the beer sloshing inside.
    for k in range(4):
        th = thud(d.rng.uniform(70, 100), 0.06, 1.0)
        i = d.n_of(k * 0.5 + 0.1)
        x[i:i + len(th)] += th[: len(x) - i] * 0.8
    slosh = d.lowpass(d.noise(s + 0.4), 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * d.t_of(s + 0.4))) * 0.15
    return d.normalize(d.loopable(x + slosh, 0.4), 0.85)


def fassl_tap(v):
    knock = d.mix(thud(160, 0.04, 1.0), (0.3, thud(160, 0.04, 1.0)), (0.32, click(1500, 0.008, 0.6)))
    pour = d.lowpass(d.noise(1.6), 2500) * d.env_points(1.6, [(0, 0), (0.1, 0.5), (1.3, 0.4), (1.6, 0)])
    fizz = d.highpass(d.noise(2.0), 4000) * d.env_points(2.0, [(0, 0), (0.5, 0.15), (2.0, 0)])
    return d.normalize(d.fade(d.mix(knock, (0.5, pour), (0.9, fizz))))


def murmeltier_scream(v):
    s = 1.7
    f0 = d.env_points(s, [(0, 520), (0.12, 820 + 60 * v), (1.3, 780), (s, 640)])
    f0 = f0 * (1.0 + 0.02 * d.sine(7.0, s))
    x = voice(s, f0, [(0, "ae"), (0.15, "a"), (s, "a")], 1.35, 0.35, 0.03, 0.0, 3.0)
    x *= d.env_points(s, [(0, 0), (0.06, 1), (1.4, 0.95), (s, 0)])
    return d.normalize(d.fade(d.reverb(x, 1.0, 0.2)))


def murmeltier_pop(v):
    rustle = d.bandpass(d.noise(0.3), 1500, 6000) * d.env_exp(0.3, 0.06) * 0.6
    return d.normalize(d.mix(rustle, d.sine(d.glide(0.06, 400, 900), 0.06) * d.env_exp(0.06, 0.02)), 0.7)


def murmeltier_hit(v):
    s = 0.4
    squeak = voice(s, d.glide(s, 1100, 1500), [(0, "i"), (s, "i")], 1.4, 0.1, 0.01, 0.0, 2.0)
    return d.normalize(d.mix(thud(200, 0.03, 0.8), squeak * d.env_points(s, [(0, 0), (0.03, 1), (s, 0)])))


def camera(v):
    return d.normalize(d.mix(click(2800, 0.004, 1.0), (0.06, click(2000, 0.006, 0.8)),
                             (0.1, d.bandpass(d.noise(0.25), 2000, 6000) * d.env_exp(0.25, 0.08) * 0.25)), 0.7)


# --- ambience --------------------------------------------------------------------------------------

def wind_loop(v):
    s = 24.0
    total = s + 3.0
    gust = 0.55 + 0.45 * d.smooth_noise(total, 0.35)
    body = d.lowpass(d.brown(total), 450) * gust
    rush = d.bandpass(d.pink(total), 500, 2200) * 0.35 * np.clip(gust - 0.35, 0, 1) ** 1.5
    # The storm whistling round the eaves: narrow bands that come and go, their pitch drifting.
    howl = np.zeros(d.n_of(total))
    for f in (380, 520, 700, 950):
        g = np.clip(d.smooth_noise(total, 0.3), 0, 1) ** 2
        drift = f * (1 + 0.06 * d.smooth_noise(total, 0.5))
        tone = d.sine(drift, total) * (0.6 + 0.4 * d.smooth_noise(total, 6))
        howl += d.resonator(d.noise(total), f, 40) * 0.5 * g + tone * g * 0.05
    x = d.lowpass(body + rush + howl * gust, 2500)
    return d.normalize(d.loopable(x, 3.0), 0.8)


def fire_crackle(v):
    s = 8.0
    total = s + 0.6
    x = d.lowpass(d.brown(total), 300) * 0.25 + d.bandpass(d.noise(total), 2000, 6000) * 0.02
    t = 0.0
    while t < total:
        c = click(d.rng.uniform(800, 4000), d.rng.uniform(0.001, 0.004), d.rng.uniform(0.2, 1.0))
        i = d.n_of(t)
        x[i:i + len(c)] += c[: len(x) - i]
        t += d.rng.exponential(0.12)
    return d.normalize(d.loopable(x, 0.6), 0.7)


# name: (recipe, variants, folder). Folder picks the import loop flag in build.py.
SOUNDS = {
    "shot_pistole": (shot_pistole, 2), "shot_jagdflinte": (shot_jagdflinte, 2),
    "shot_jagdflinte_both": (shot_jagdflinte_both, 1), "shot_stutzen": (shot_stutzen, 2),
    "shot_repetierer": (shot_repetierer, 2), "dry_click": (dry_click, 1),
    "mag_out": (mag_out, 1), "mag_in": (mag_in, 1), "break_open": (break_open, 1),
    "break_close": (break_close, 1), "bolt_open": (bolt_open, 1), "bolt_close": (bolt_close, 1),
    "lever_open": (lever_open, 1), "lever_close": (lever_close, 1), "load_clunk": (load_clunk, 1),
    "load_ready": (load_ready, 1), "weapon_raise": (weapon_raise, 1), "hitmarker": (hitmarker, 1),
    "headshot": (headshot, 1), "bellows": (bellows, 1), "alphorn_load": (alphorn_load, 1),
    "swing": (swing, 3), "throw": (throw, 1), "schaufel_hit": (schaufel_hit, 2),
    "pfanne_bonk": (pfanne_bonk, 2), "goassl_crack": (goassl_crack, 2), "mistgabel_stab": (mistgabel_stab, 2),
    "rute_hit": (rute_hit, 2), "block_hit": (block_hit, 1),
    "alphorn_blast": (alphorn_blast, 1), "alphorn_echo": (alphorn_echo, 1),
    "knoedel_launch": (knoedel_launch, 1), "knoedel_splat": (knoedel_splat, 3),
    "rodel_launch": (rodel_launch, 1), "rodel_hit": (rodel_hit, 2),
    "flame_loop": (flame_loop, 1), "flame_start": (flame_start, 1),
    "boeller_launch": (boeller_launch, 1), "boeller_bang": (boeller_bang, 2),
    "kuhglocke_ring": (kuhglocke_ring, 1), "resi_bell": (resi_bell, 1),
    "eisstock_slide": (eisstock_slide, 1), "eisstock_hit": (eisstock_hit, 1),
    "kuhfladen_splat": (kuhfladen_splat, 1), "kuhfladen_squelch": (kuhfladen_squelch, 2),
    "groan_wanderer": (groan_wanderer, 4), "groan_knappe": (groan_knappe, 3),
    "groan_perchte": (groan_perchte, 3), "groan_tourist": (groan_tourist, 3),
    "krampus_roar": (krampus_roar, 2), "chains": (chains, 2), "enemy_death": (enemy_death, 4),
    "enemy_attack": (enemy_attack, 2), "board_pull": (board_pull, 3), "board_nail": (board_nail, 2),
    "window_climb": (window_climb, 1),
    "player_hurt": (player_hurt, 3), "player_death": (player_death, 1),
    "step_snow": (step_snow, 5), "step_wood": (step_wood, 5), "land": (land, 1),
    "buy": (buy, 1), "deny": (deny, 1), "door_open": (door_open, 1), "creak": (creak, 5),
    "chest_open": (chest_open, 1), "chest_tick": (chest_tick, 6), "chest_reveal": (chest_reveal, 1),
    "perk_drink": (perk_drink, 1), "jause_eat": (jause_eat, 1), "ammo_crate": (ammo_crate, 1),
    "ui_click": (ui_click, 1), "wave_start": (wave_start, 1), "boss_wave": (boss_wave, 1),
    "resi_moo": (resi_moo, 3), "milk": (milk, 1), "fassl_roll": (fassl_roll, 1), "fassl_tap": (fassl_tap, 1),
    "murmeltier_scream": (murmeltier_scream, 2), "murmeltier_pop": (murmeltier_pop, 1),
    "murmeltier_hit": (murmeltier_hit, 1), "camera": (camera, 1),
    "wind_loop": (wind_loop, 1), "fire_crackle": (fire_crackle, 1),
}

LOOPS = {"flame_loop", "kuhglocke_ring", "resi_bell", "eisstock_slide", "fassl_roll", "wind_loop", "fire_crackle"}
