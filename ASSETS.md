# Assets and licenses

| Asset | Source | License |
|---|---|---|
| Gunshots `assets/audio/sfx/shot_*.ogg`, and the recorded shotgun under `boeller_*.ogg` (pitched down, layered with synthesised boom and debris): Walther PPQ (Dienstpistole), Tikka T3 (Stutzen), Winchester 1894 and Marlin 336 (Repetierer), Winchester Model 12 and Charles Daly 12 ga (Jagdflinte), near-distance takes, cut, mixed to mono and limited by `tools/audio/recordings.py` | "The Free Firearm Sound Library" by Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney, https://opengameart.org/content/the-free-firearm-sound-library | CC0 |
| All other sounds and music in `assets/audio/` (M6 part 2): reloads, melee, special weapons, equipment, enemy voices, footsteps, purchases, doors, the Hüttentruhe, events, wind, creaks, fire, and the brass band tune "Da Berghittn-Polka" | Self-made: synthesised from oscillators, noise and filters by `tools/audio/` (`python tools/audio/build.py`); an original tune | Our own, part of this project |
| Engraved gun steel `assets/textures/gun_forged.png` (M9 part 4): the forged look of a dengelt weapon | Made by `tools/textures/engrave.py` from our `gun_steel` (CC0 photo, see below) with our own procedural scrollwork | CC0 base, our own engraving |
| Enemy voice lines `assets/audio/sfx/gredn_*.ogg` (M9 part 3): our own dialect lines | Spoken by [eSpeak NG](https://github.com/espeak-ng/espeak-ng) on the dev machine and run through our own filters by `tools/audio/voices.py`. eSpeak NG (GPL-3) is only used as a tool and is not part of the game; the audio it makes is ours | Our own, part of this project |

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
| `gun_wood` (M6 part 4b, neutral, 512): stocks, grips, handles | [european_walnut_veneer_04](https://polyhaven.com/a/european_walnut_veneer_04) | Jenelle van Heerden | CC0 |
| `gun_steel` (M6 part 4b, neutral, 512): barrels, actions, brass and copper | [rust_coarse_01](https://polyhaven.com/a/rust_coarse_01) | Dimitrios Savva, Rico Cilliers | CC0 |

The enemy models (M6 part 4) are self-made: built from tubes, balls and boxes by
`tools/models/build_enemies.gd`, tinted by vertex colour over the neutral textures above (and `wool`,
`linen`, `painted_wood`, `metal`). The weapon models (M6 part 4b) are the greybox parts reshaped by
`tools/models/build_weapons.tscn` (tubes, chamfers, stock profiles), textured with `gun_wood`,
`gun_steel` and `painted_wood`. The props (M6 part 4c) are reshaped the same way by
`tools/models/build_props.tscn`, with the textures above (the animals in `fur`); the Deitscha Tourist
is built like the enemies, and so is the co-op player hiker (M7, `tools/models/build_hiker.gd`: its
jacket and trousers reuse the `wool` and `leather` textures, tinted per player), and so are the
stuffed animals and trophies (M8, `tools/models/stuffed.gd`, `build_trophies.gd`). No external models
anywhere.

The title screen's teaser picture (`assets/ui/teaser.jpg`, #77) is rendered from the game itself by
`tools/teaser/teaser.tscn`; `assets/textures/white.png` (4x4 white, #78) is self-made. Both are our own.
