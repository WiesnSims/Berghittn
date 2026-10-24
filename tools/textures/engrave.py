"""The forged look of a dengelt gun (M9 part 4): gun_steel with engraved scrollwork, our own.

    python tools/textures/engrave.py

Reads assets/textures/gun_steel.png (built by build.py from a CC0 photo) and writes
assets/textures/gun_forged.png: the same steel, a little smoother, with cut vines and curls that tile
like the steel does. It stays neutral grey; the material's albedo_color makes it dark gold."""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets" / "textures"


def main():
    steel = np.asarray(Image.open(OUT / "gun_steel.png").convert("RGB"), dtype=np.float32) / 255.0
    n = steel.shape[0]
    y, x = np.mgrid[0:n, 0:n] / n * 2.0 * np.pi
    # Calmer steel under the engraving, so the lines read.
    mean = steel.mean(axis=(0, 1))
    base = mean + (steel - mean) * 0.6
    # Vines: wavy contour lines in two directions; curls: rings around a grid of points. All periodic
    # on the image, so it tiles.
    vine_a = np.sin(4 * x + 1.6 * np.sin(4 * y))
    vine_b = np.sin(4 * y + 1.6 * np.sin(4 * x + 1.0))
    cx = np.sin(2 * x) * 0.5 + 0.5
    cy = np.sin(2 * y) * 0.5 + 0.5
    curl = np.sin(18 * np.hypot(np.cos(2 * x), np.cos(2 * y)) + 3 * np.arctan2(np.cos(2 * y), np.cos(2 * x)))
    lines = np.maximum(np.exp(-(vine_a / 0.12) ** 2), np.exp(-(vine_b / 0.12) ** 2) * 0.8)
    lines = np.maximum(lines, np.exp(-(curl / 0.25) ** 2) * (cx * cy > 0.55))
    # A cut: dark in the groove, a bright edge beside it (light from the top left).
    edge = np.roll(np.roll(lines, -2, axis=0), -2, axis=1)
    shade = 1.0 - 0.55 * lines + 0.25 * np.clip(edge - lines, 0.0, 1.0)
    out = np.clip(base * shade[..., None], 0.0, 1.0)
    Image.fromarray((out * 255.0 + 0.5).astype(np.uint8)).save(OUT / "gun_forged.png")
    print("wrote", OUT / "gun_forged.png")


if __name__ == "__main__":
    main()
