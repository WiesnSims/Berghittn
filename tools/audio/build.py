"""Renders every sound of Berghittn into assets/audio as OGG Vorbis (M6 part 2).

    pip install numpy scipy soundfile
    python tools/audio/build.py            # everything
    python tools/audio/build.py swing band_3   # only these names

Folders follow the audio buses: sfx/ (Effects), music/ (Music), ambience/ (Ambience). Variants are
numbered name_1.ogg, name_2.ogg ...; the game picks one at random (scripts/autoload/sound.gd).
Files are mono: positional sounds are mono anyway, and the band plays from an old gramophone.
The enemies' voice lines (voices.py) need eSpeak NG; without it they are skipped, the files already
there kept."""
import sys
import zlib
from pathlib import Path

import numpy as np
import soundfile as sf

import dsp
import music
import sfx
import voices

ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio"
AMBIENCE = {"wind_loop", "fire_crackle", "creak"}
# Vorbis quality: 0 = best, 1 = smallest. Music and ambience are long, so they go a little lower.
QUALITY = {"sfx": 0.45, "music": 0.62, "ambience": 0.62}
PEAK = 0.85
LOOPS = sfx.LOOPS | music.MUSIC_LOOPS | music.MUSICAL_LOOPS


def jobs():
    for name, (fn, variants) in sfx.SOUNDS.items():
        yield ("ambience" if name in AMBIENCE else "sfx"), name, fn, variants
    if voices.espeak():
        for name, (fn, variants) in voices.SOUNDS.items():
            yield "sfx", name, fn, variants
    else:
        print("eSpeak NG not found: the voice lines (gredn_*) are left as they are")
    for name, fn in music.MUSICAL_SFX.items():
        yield "sfx", name, fn, 1
    for name, fn in music.MUSIC.items():
        yield "music", name, fn, 1


def render(folder, name, fn, variants):
    out = []
    for v in range(variants):
        # Same name and variant, same sound: rebuilding never changes files nobody touched.
        dsp.seed(zlib.crc32(("%s:%d" % (name, v)).encode()))
        x = np.asarray(fn(v), dtype=np.float64)
        if not np.all(np.isfinite(x)):
            raise ValueError("%s_%d is not finite" % (name, v))
        x = x - np.mean(x)
        if name not in LOOPS:
            # Bell partials and reverb tails must not end on a click.
            x = dsp.fade(x, 0.0005, min(0.03, len(x) / dsp.SR * 0.2))
        # Headroom for the encoder, which overshoots on sharp transients.
        x = x * min(1.0, PEAK / (np.max(np.abs(x)) + 1e-9))
        x = np.clip(x, -1.0, 1.0).astype(np.float32)
        path = ROOT / folder / ("%s_%d.ogg" % (name, v + 1))
        path.parent.mkdir(parents=True, exist_ok=True)
        # In blocks: libsndfile's Vorbis encoder overflows the stack on one long write.
        with sf.SoundFile(str(path), "w", dsp.SR, 1, format="OGG", subtype="VORBIS",
                          compression_level=QUALITY[folder]) as f:
            for i in range(0, len(x), 8192):
                f.write(x[i:i + 8192])
        out.append((path, len(x) / dsp.SR))
    return out


def main(names):
    total = 0
    for folder, name, fn, variants in jobs():
        if names and name not in names:
            continue
        for path, seconds in render(folder, name, fn, variants):
            size = path.stat().st_size
            total += size
            print("%-40s %6.2f s %7.1f KB" % (path.relative_to(ROOT), seconds, size / 1024))
    if not names:
        print("total %.2f MB" % (total / 1024 / 1024))


if __name__ == "__main__":
    main(set(sys.argv[1:]))
