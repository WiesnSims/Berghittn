"""Real gunshots (play-test 2026-10-18: the synthesised ones did not sound real) from "The Free
Firearm Sound Library" (CC0, opengameart.org/content/the-free-firearm-sound-library). Cuts each
shot out of the near-distance takes, mixes it to mono at 44.1 kHz and writes it next to the synthesised
sounds. The Handböller's launch and blast are a shotgun pitched far down under a synthesised sub
boom, debris and a rolling tail.

    python tools/audio/recordings.py "<path to the extracted 'Prepared SFX Library'>"
"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

import build
import dsp

# Sound id: takes (folder/file in the library). Every shot in a take becomes one variant.
TAKES = {
    "shot_pistole": ["Walther PPQ/X_39P.wav"],
    "shot_stutzen": ["Tikka/W_29P.wav"],
    "shot_repetierer": ["Model 1894/L_23P.wav", "Marlin 336/I_22P.wav"],
    "shot_jagdflinte": ["Model 12/K_22P.wav", "CD/H_21P.wav"],
}
SHOT_LENGTH = 1.6
# Soft-clip drive that brings the body of a shot up under its peak.
LIMIT = 5.0
# Onsets closer than this belong to one shot (its echo off the range).
MERGE = 0.5


def load(library: Path, take: str) -> np.ndarray:
    x, sr = sf.read(str(library / take), always_2d=True)
    mono = x.mean(axis=1)
    mono = signal.resample_poly(mono, dsp.SR, sr) if sr != dsp.SR else mono
    # Wind on the range rumbles under some takes.
    return dsp.highpass(mono, 70, 4)


def shots(x: np.ndarray) -> list:
    env = np.convolve(np.abs(x), np.ones(441) / 441, "same")
    above = env > env.max() * 0.3
    onsets = list(np.nonzero(np.diff(above.astype(int)) == 1)[0])
    merged = []
    for o in onsets:
        if not merged or o - merged[-1] > MERGE * dsp.SR:
            merged.append(o)
    out = []
    for i, o in enumerate(merged):
        start = max(0, o - dsp.n_of(0.004))
        end = min(len(x), start + dsp.n_of(SHOT_LENGTH))
        if i + 1 < len(merged):
            end = min(end, merged[i + 1] - dsp.n_of(0.02))
        cut = x[start:end].copy()
        cut = dsp.fade(cut, 0.001, min(0.4, len(cut) / dsp.SR * 0.4))
        # Limited hard, as game guns are: the raw takes are one huge spike and a quiet body.
        out.append(dsp.normalize(dsp.drive(dsp.normalize(cut), LIMIT)))
    return out


def pitched(x: np.ndarray, factor: float) -> np.ndarray:
    """Slowed down by `factor` (< 1 = lower and longer), like a tape."""
    n = int(len(x) / factor)
    return np.interp(np.arange(n) * factor, np.arange(len(x)), x)


def boom(core: np.ndarray, length: float, size: float) -> np.ndarray:
    """A black-powder blast: the recorded shot far down, a sub thump, debris and a rolling tail."""
    body = pitched(core, 0.42 / size)
    body = dsp.lowpass(body, 2500)
    sub = dsp.sine(dsp.glide(length, 70 * size, 28, 0.6), length) * dsp.env_exp(length, 0.35 * size) * 1.4
    rumble = dsp.lowpass(dsp.brown(length), 180) * dsp.env_exp(length, 0.9 * size) * 0.9
    debris = np.zeros(dsp.n_of(length))
    for _ in range(60):
        at = dsp.n_of(dsp.rng.uniform(0.05, 1.2) ** 1.5)
        c = dsp.bandpass(dsp.noise(0.03), 1500, 6000) * dsp.env_exp(0.03, 0.004) * dsp.rng.uniform(0.05, 0.25)
        debris[at:at + len(c)] += c[: len(debris) - at]
    x = dsp.mix(dsp.normalize(body) * 1.0, sub, rumble, debris)
    x = dsp.drive(dsp.normalize(x), 2.5)
    x = dsp.echo(x, 0.42, 0.25, 3, 900)
    return dsp.normalize(dsp.fade(dsp.trim(dsp.reverb(x, 2.5, 0.3, 1800))))


def write(name: str, variants: list) -> None:
    for i, x in enumerate(variants):
        x = x - np.mean(x)
        x = x * min(1.0, build.PEAK / (np.max(np.abs(x)) + 1e-9))
        path = build.ROOT / "sfx" / ("%s_%d.ogg" % (name, i + 1))
        with sf.SoundFile(str(path), "w", dsp.SR, 1, format="OGG", subtype="VORBIS",
                          compression_level=build.QUALITY["sfx"]) as f:
            for k in range(0, len(x), 8192):
                f.write(x[k:k + 8192].astype(np.float32))
        print("%-32s %5.2f s %6.1f KB" % (path.name, len(x) / dsp.SR, path.stat().st_size / 1024))


def main(library: Path) -> None:
    for old in (build.ROOT / "sfx").glob("shot_*.ogg"):
        old.unlink()
    cut = {}
    for name, takes in TAKES.items():
        cut[name] = [s for take in takes for s in shots(load(library, take))]
        write(name, cut[name])
    flinte = cut["shot_jagdflinte"]
    both = [dsp.normalize(dsp.mix(a * 0.9, (0.015, b * 0.9))) for a, b in zip(flinte, flinte[1:] + flinte[:1])]
    write("shot_jagdflinte_both", both[:2])
    dsp.seed(1809)
    write("boeller_bang", [boom(flinte[0], 3.5, 1.0), boom(flinte[-1], 3.5, 1.05)])
    launch = [dsp.normalize(dsp.mix(boom(flinte[1], 2.0, 1.5) * 0.8,
                                     dsp.bandpass(dsp.noise(0.5), 2500, 8000) * dsp.env_points(0.5, [(0, 0), (0.05, 0.03), (0.5, 0)])))]
    write("boeller_launch", launch)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
