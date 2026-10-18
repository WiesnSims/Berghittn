"""Builds the world textures of Berghittn from CC0 photo textures (M6 part 3).

    pip install pillow numpy
    python tools/textures/build.py              # everything
    python tools/textures/build.py stone snow   # only these

Every texture comes from Poly Haven (https://polyhaven.com, CC0). The 1K maps are downloaded once
into tools/textures/cache/ (gitignored); the game gets 256x256 copies in assets/textures/, the
default size of section 3 in GAME_DESIGN.md. Each albedo is brought to a target average colour
(mostly the greybox colour it replaces, so the lighting and grade of M6 part 1 still fit) while
keeping the photo's detail. Neutral ones (TINTED) are made light grey and coloured by the material's
albedo_color, so one texture serves several materials. Prints the table for ASSETS.md."""
import io
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
CACHE = HERE / "cache"
OUT = HERE.parents[1] / "assets" / "textures"
SIZE = 256

# name: Poly Haven asset, target average colour (sRGB), and options:
#   normal: also build <name>_normal.png (OpenGL convention, what Godot expects)
#   sat: how much of the photo's own colour variation stays (1 = all, 0 = grey detail only)
#   contrast: scales the detail around the average (below 1 = calmer)
#   dark: scales only the detail darker than the average (below 1 = fewer dark specks)
#   turn: a quarter turn, so the grain runs across (barricade boards are long and flat)
TEXTURES = {
    "wood_wall": ("planks_brown_10", (0.58, 0.42, 0.27), {"normal": True, "sat": 0.6}),
    "wood_floor": ("wood_floor_worn", (0.36, 0.24, 0.15), {"normal": True}),
    "wood_dark": ("wood_table_worn", (0.24, 0.15, 0.09), {}),
    "board": ("weathered_planks", (0.5, 0.36, 0.22), {"normal": True, "sat": 0.5, "turn": True}),
    "painted_wood": ("distressed_painted_planks", (0.8, 0.8, 0.8), {"sat": 0.25, "contrast": 1.4}),
    "stone": ("stone_wall", (0.42, 0.4, 0.37), {"normal": True, "sat": 0.5}),
    "rock": ("rock_face_03", (0.36, 0.35, 0.34), {"normal": True, "sat": 0.3, "contrast": 1.3}),
    # Its dark marks repeat like scratches across the ground, so they are mostly lifted out.
    "snow": ("snow_02", (0.78, 0.82, 0.88), {"sat": 0.0, "contrast": 0.8, "dark": 0.2}),
    "concrete": ("brushed_concrete", (0.46, 0.47, 0.49), {"sat": 0.3}),
    "tile": ("terracotta_floor_tiles", (0.5, 0.3, 0.22), {"sat": 0.7}),
    "metal": ("rust_coarse_01", (0.32, 0.34, 0.36), {"sat": 0.35, "contrast": 1.5}),
    "pine": ("thatch_roof_angled", (0.1, 0.18, 0.13), {"sat": 0.0, "contrast": 1.6}),
    "hay": ("thatch_roof_angled", (0.72, 0.58, 0.28), {"sat": 0.0, "contrast": 1.3}),
    "wool": ("poly_wool_herringbone", (0.8, 0.8, 0.8), {"sat": 0.0, "contrast": 1.6}),
    "linen": ("hessian_230", (0.78, 0.74, 0.66), {"sat": 0.3, "contrast": 0.7}),
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "berghittn-textures/1.0"})
    return urllib.request.urlopen(req, timeout=120).read()


def source(asset, kind):
    """The 1K map (kind is Diffuse or nor_gl) from the cache, downloaded on first use."""
    path = CACHE / f"{asset}_{kind}_1k.png"
    if not path.exists():
        files = json.loads(get("https://api.polyhaven.com/files/" + asset))
        CACHE.mkdir(exist_ok=True)
        path.write_bytes(get(files[kind]["1k"]["png"]["url"]))
    return Image.open(path).convert("RGB")


def info(asset):
    path = CACHE / f"{asset}_info.json"
    if not path.exists():
        CACHE.mkdir(exist_ok=True)
        path.write_bytes(get("https://api.polyhaven.com/info/" + asset))
    return json.loads(path.read_text(encoding="utf8"))


def shrink(img):
    """Down to SIZE, seamless: resampled as a 3x3 tiling so the edges see their wrapped neighbours."""
    w, h = img.size
    tiled = Image.new("RGB", (w * 3, h * 3))
    for x in range(3):
        for y in range(3):
            tiled.paste(img, (x * w, y * h))
    tiled = tiled.resize((SIZE * 3, SIZE * 3), Image.LANCZOS)
    return tiled.crop((SIZE, SIZE, SIZE * 2, SIZE * 2))


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def albedo(img, target, sat=1.0, contrast=1.0, dark=1.0):
    lin = to_linear(np.asarray(img, dtype=np.float64) / 255.0)
    luma = lin @ np.array([0.2126, 0.7152, 0.0722])
    grey = np.repeat(luma[..., None], 3, axis=2)
    lin = grey + (lin - grey) * sat
    mean = lin.mean(axis=(0, 1))
    lin = mean + (lin - mean) * contrast
    lin = np.where(lin < mean, mean + (lin - mean) * dark, lin)
    lin = np.maximum(lin, 0.0)
    lin *= to_linear(np.array(target)) / lin.mean(axis=(0, 1))
    return Image.fromarray((to_srgb(lin) * 255.0 + 0.5).astype(np.uint8))


def normal(img, turn=False):
    n = np.asarray(img, dtype=np.float64) / 255.0 * 2.0 - 1.0
    if turn:
        # The picture turned a quarter left turns its slopes with it: right becomes up.
        n = np.rot90(n).copy()
        n[..., 0], n[..., 1] = -n[..., 1].copy(), n[..., 0].copy()
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-9
    return Image.fromarray(((n * 0.5 + 0.5) * 255.0 + 0.5).astype(np.uint8))


def build(name):
    asset, target, opts = TEXTURES[name]
    OUT.mkdir(parents=True, exist_ok=True)
    turn = opts.get("turn", False)
    img = albedo(shrink(source(asset, "Diffuse")), target, opts.get("sat", 1.0), opts.get("contrast", 1.0),
                 opts.get("dark", 1.0))
    if turn:
        img = img.transpose(Image.Transpose.ROTATE_90)
    img.save(OUT / f"{name}.png", optimize=True)
    if opts.get("normal"):
        normal(shrink(source(asset, "nor_gl")), turn).save(OUT / f"{name}_normal.png", optimize=True)


def main():
    names = sys.argv[1:] or list(TEXTURES)
    for name in names:
        build(name)
        print("built", name)
    print("\n| Texture | Poly Haven asset | Real size | Authors |\n|---|---|---|---|")
    for name in names:
        asset = TEXTURES[name][0]
        meta = info(asset)
        dims = meta.get("dimensions") or [0, 0]
        authors = ", ".join(meta.get("authors", {}))
        print(f"| {name} | [{asset}](https://polyhaven.com/a/{asset}) | {dims[0] / 1000:g} x {dims[1] / 1000:g} m | {authors} |")


if __name__ == "__main__":
    main()
