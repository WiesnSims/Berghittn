# Assets and licenses

| Asset | Source | License |
|---|---|---|
| Gunshots `assets/audio/sfx/shot_*.ogg`, and the recorded shotgun under `boeller_*.ogg` (pitched down, layered with synthesised boom and debris): Walther PPQ (Dienstpistole), Tikka T3 (Stutzen), Winchester 1894 and Marlin 336 (Repetierer), Winchester Model 12 and Charles Daly 12 ga (Jagdflinte), near-distance takes, cut, mixed to mono and limited by `tools/audio/recordings.py` | "The Free Firearm Sound Library" by Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney, https://opengameart.org/content/the-free-firearm-sound-library | CC0 |
| All other sounds and music in `assets/audio/` (M6 part 2): reloads, melee, special weapons, equipment, enemy voices, footsteps, purchases, doors, the Hüttentruhe, events, wind, creaks, fire, and the brass band tune "Da Berghittn-Polka" | Self-made: synthesised from oscillators, noise and filters by `tools/audio/` (`python tools/audio/build.py`); an original tune | Our own, part of this project |

## Textures (M6 part 3)

Photo textures from [Poly Haven](https://polyhaven.com/license) (all CC0), downloaded at 1K and turned into the
256x256 files in `assets/textures/` by `tools/textures/build.py`: shrunk, and each albedo brought to the
average colour of the greybox material it replaced (normal maps as they are, OpenGL convention).

| Texture | Poly Haven asset | Authors | License |
|---|---|---|---|
| `wood_wall` (+ normal): walls | [planks_brown_10](https://polyhaven.com/a/planks_brown_10) | Rob Tuytel | CC0 |
| `wood_floor` (+ normal): floors, ceilings, stairs | [wood_floor_worn](https://polyhaven.com/a/wood_floor_worn) | Dimitrios Savva | CC0 |
| `wood_dark`: beams, posts, furniture, fences | [wood_table_worn](https://polyhaven.com/a/wood_table_worn) | Dimitrios Savva, Rico Cilliers | CC0 |
| `board` (+ normal, turned a quarter): barricade boards, shed floor | [weathered_planks](https://polyhaven.com/a/weathered_planks) | Dario Barresi, Dimitrios Savva | CC0 |
| `painted_wood`: locked doors, the gondola, skis | [distressed_painted_planks](https://polyhaven.com/a/distressed_painted_planks) | Rob Tuytel | CC0 |
| `stone` (+ normal): Kachelofen, chimney, worktop | [stone_wall](https://polyhaven.com/a/stone_wall) | Dario Barresi, Charlotte Baglioni | CC0 |
| `rock` (+ normal): rocks and steep terrain | [rock_face_03](https://polyhaven.com/a/rock_face_03) | Dario Barresi, Rico Cilliers | CC0 |
| `snow`: ground, roofs, terrain | [snow_02](https://polyhaven.com/a/snow_02) | Rob Tuytel | CC0 |
| `concrete`: Seilbahn station | [brushed_concrete](https://polyhaven.com/a/brushed_concrete) | Dario Barresi, Dimitrios Savva | CC0 |
| `tile`: Küche floor | [terracotta_floor_tiles](https://polyhaven.com/a/terracotta_floor_tiles) | Dimitrios Savva | CC0 |
| `metal`: cable car mast, cables, handles | [rust_coarse_01](https://polyhaven.com/a/rust_coarse_01) | Dimitrios Savva, Rico Cilliers | CC0 |
| `pine` (tinted green, reads as needles): pines | [thatch_roof_angled](https://polyhaven.com/a/thatch_roof_angled) | Rob Tuytel, Dimitrios Savva | CC0 |
| `hay`: hay bales | [thatch_roof_angled](https://polyhaven.com/a/thatch_roof_angled) | Rob Tuytel, Dimitrios Savva | CC0 |
| `wool`: Lager blankets | [poly_wool_herringbone](https://polyhaven.com/a/poly_wool_herringbone) | colormass, Rico Cilliers | CC0 |
| `linen`: Lager mattresses | [hessian_230](https://polyhaven.com/a/hessian_230) | colormass, Rico Cilliers | CC0 |
| `leather` (M6 part 4, neutral): boots, belts, breeches | [brown_leather](https://polyhaven.com/a/brown_leather) | Rob Tuytel | CC0 |
| `fur` (M6 part 4, neutral): the Perchte, the Krampus, beards | [curly_teddy_natural](https://polyhaven.com/a/curly_teddy_natural) | colormass, Rico Cilliers | CC0 |
| `skin` (M6 part 4, neutral): enemy skin and faces | [grey_plaster_02](https://polyhaven.com/a/grey_plaster_02) | Rob Tuytel | CC0 |

The enemy models (M6 part 4) are self-made: built from tubes, balls and boxes by
`tools/models/build_enemies.gd`, tinted by vertex colour over the neutral textures above (and `wool`,
`linen`, `painted_wood`, `metal`).
