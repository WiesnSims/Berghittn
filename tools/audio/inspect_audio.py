"""Checks the rendered sounds without ears: level, clipping, DC, brightness, loop seams, and a
spectrogram sheet per folder (written next to this script's output folder argument).

    python tools/audio/inspect_audio.py <out_dir> [name_prefix ...]"""
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"


def stats(x, sr):
    peak = np.max(np.abs(x))
    rms = np.sqrt(np.mean(x ** 2))
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    centroid = np.sum(freqs * spec) / (np.sum(spec) + 1e-9)
    clipped = np.mean(np.abs(x) > 0.995) * 100
    # Seam: the jump from the last sample to the first, against the typical sample-to-sample step.
    seam = abs(x[-1] - x[0]) / (np.mean(np.abs(np.diff(x))) + 1e-9)
    return peak, 20 * np.log10(rms + 1e-9), np.mean(x), centroid, clipped, seam


def main(out_dir, prefixes):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    files = sorted(ROOT.rglob("*.ogg"))
    if prefixes:
        files = [f for f in files if any(f.stem.startswith(p) for p in prefixes)]
    print("%-28s %5s %6s %7s %6s %5s %5s" % ("name", "peak", "rms", "dc", "cent", "clip%", "seam"))
    for f in files:
        x, sr = sf.read(str(f))
        p, r, dc, c, cl, seam = stats(x, sr)
        print("%-28s %5.2f %6.1f %7.4f %6.0f %5.2f %5.1f" % (f.stem, p, r, dc, c, cl, seam))
    # Spectrogram sheets, 24 per page.
    for page in range(0, len(files), 24):
        chunk = files[page:page + 24]
        fig, axes = plt.subplots(6, 4, figsize=(16, 14))
        for ax, f in zip(axes.flat, chunk):
            x, sr = sf.read(str(f))
            seg = x[: sr * 6]
            if len(seg) < 1024:
                seg = np.pad(seg, (0, 1024 - len(seg)))
            spec, _, _, im = ax.specgram(seg + 1e-9, NFFT=1024, Fs=sr, noverlap=768, cmap="magma")
            top = 10 * np.log10(np.max(spec) + 1e-20)
            im.set_clim(top - 70, top)
            ax.set_ylim(0, 8000)
            ax.set_title(f.stem, fontsize=9)
            ax.tick_params(labelsize=6)
        for ax in list(axes.flat)[len(chunk):]:
            ax.axis("off")
        fig.tight_layout()
        fig.savefig(out / ("spec_%02d.png" % (page // 24)), dpi=60)
        plt.close(fig)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2:])
