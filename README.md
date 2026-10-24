# Berghittn

Browser-first wave-survival shooter. Design: see `GAME_DESIGN.md`.

## Toolchain (recorded at project start)

- Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility renderer (WebGL2)
- Web export template variant: single-threaded, no GDExtension (`thread_support=false`)
- Node.js 24.21.0, wrangler 4.151.1 (run via `npx wrangler@latest`)

## Build

```
godot --headless --import      # first run only / after adding assets
node tools/build_web.mjs       # headless export + wasm packing, prints every file size
```

Output goes to `export/` (gitignored). The script exits non-zero if any file is over 20 MiB.

### Why the wasm is packed

The Godot 4.7 engine wasm is ~37.7 MiB, over Cloudflare Pages' 25 MiB per-file limit.
`tools/build_web.mjs` gzips it (~9.7 MiB), splits it into parts if still above 16 MiB,
and writes `index.wasm.parts.json`. `web/wasm_parts_loader.js` (injected via the preset's
`html/head_include`) wraps `fetch` so Godot's loader receives the original wasm.
Gzip is done by us because Pages serves unknown extensions uncompressed.
Needs `DecompressionStream` (Chrome 80+, Firefox 113+, Safari 16.4+).

## Controls

WASD / arrows move, mouse look, left click shoot, right click the gun's secondary mode (pistol: aim
down the sights, Stutzen: scope, Jagdflinte: both barrels), V melee (shovel), R reload, 1 / 2 / 3 (with the Kraxn) / Q / mouse wheel
switch gun, Space jump, Shift sprint (forward only; the gun is lowered and cannot fire until 0.2 s after), C crouch (not Ctrl: Ctrl+W closes the browser tab),
E interact (hold at a window to board it up; press at a door or wall-buy to buy), Esc or P pause,
F3 debug overlay (FPS and position). While the overlay is on, F4 adds 1000 points (testing doors and
wall-buys).

F5, Ctrl/Cmd+R, F11 and F12 go to the browser: `web/browser_shortcuts.js` stops them before
Godot's web runtime, which otherwise calls `preventDefault()` on every key.

In browsers Esc never reaches the game; it releases pointer lock and the game pauses
because the lock is gone. Resume stays disabled for ~1 s since Chrome refuses an
immediate re-lock.

## Physics layers

1 `world`, 2 `player`, 3 `enemy`, 4 `player_blocker` (window openings: blocks players,
lets enemies through), 5 `hitbox` (enemy body/head hurtboxes; hitscan rays test `world` + `hitbox`).

## Map and zones

"Die Hütte" (section 4) is seven zone scenes in `scenes/zones/`, joined by buyable doors
(`ZoneDoor`, `scenes/zones/door.tscn`, placed in `main.tscn` under `World/Doors`): a loop
Stube – Küche – Skiraum – Seilbahn – Schuppen – Terrasse – Stube, plus the Matratzenlager upstairs off
the Stube gallery. The Küche scene owns the outer walls of the Küche + Lager wing (two storeys);
`lager.tscn` holds what is inside the Lager. Upper-floor windows are `window_upper.tscn` (bars and a
player blocker, no barricade). Windows facing the terrace deck set `outside_floor` so their navigation
link starts on the deck. Zone names and door costs are in
`data/zone_table.tres`; `ZoneMap` (node `Zones` in main) tracks which are open. Adjacency comes from
the doors, so a door's `zone_a` / `zone_b` is the only layout setting. A door costs what the zone behind
it costs, and opens by itself once both its zones are open (the loop's last door). Each window is a
`scenes/zones/window.tscn` instance (barricade, player blocker, bars, navigation link) on a hole in the
zone's wall CSG. `SpawnPoint` markers outside each zone's windows carry their zone id; the wave manager
only uses those whose zone is open or next to an open one. The Terrasse is open air: a fence with gaps
keeps players in and lets enemies through. Wall-buys (`WallBuy`, a chalk outline per gun) sell the
Jagdflinte (Stube) and the Stutzen (Skiraum), and once you carry the gun, ammo at `ammo_cost` (half price).
Two gun slots: a new gun goes in the free slot, otherwise it replaces the gun in hand.
All viewmodels hang under `WeaponMotion` (`Motion` under the `WeaponHolder`): walk bob, the sprint pose,
lag behind mouse turns, strafe lean, and lift/dip on jumps and landings, all turning around the grip.
Right click is `WeaponData.secondary` (section 6: every weapon gets its own fitting mode): `AIM` and
`SCOPE` zoom to `aim_fov`, tighten the spread and slow walking (no sprint); the scope shows
`ScopeOverlay` with a slow sway; `ALL_BARRELS` fires every loaded round in one blast. Quick shots add
bloom (`bloom_*` in `WeaponData`) to the spread, and the crosshair arms move out by the same amount.

Outside (`scenes/zones/exterior.tscn`) the hut stands on an Alm: the walkable snow is a flat CSG
disc (radius 37 m around the hut), and `AlmTerrain` generates the mountain beyond it at load
(flat-shaded, rock on steep faces, pines below the tree line and rocks above as two MultiMeshes,
no collision since nobody can get there). `MountainBackdrop` draws two rings of far peaks that
ignore fog and fade into the fog color at their foot, so the summits show through the storm.

## Navigation

One `NavigationRegion3D` (`World/Navigation` in main) with `scripts/zones/navmesh_baker.gd` bakes
the whole map, both floors, at load from the colliding CSG shapes (~25 ms on desktop), and rebakes from cached faces
whenever a door opens. Windows are one-way `NavigationLink3D`s; enemies hop through them when the
agent reaches a link. Enemies have no step climbing, so every level change is a ramp with side curbs,
`agent_max_climb` is 0.2 (two cells: a 35° ramp rises 0.14 per cell) and agents follow waypoints
within 0.3 m; looser, they cut corners onto ramps and get stuck.
`navigation/world/region_use_async_iterations` is off: with it on, Godot 4.7 never pushes
the runtime-baked mesh to the navigation server (paths come back empty).

## Waves, barricades, points

`scripts/waves/wave_manager.gd` runs the waves from `data/wave_table.tres` (section 8 formulas and the
enemy mix). Every window has a `Barricade` (`scripts/zones/barricade.gd`) with 6 boards: an enemy that
reaches the window's navigation link tears them off (`board_break_time` per board, in `EnemyData`), and
only climbs in once they are all gone; one enemy works a window at a time, the rest queue. Players hold
E at the repair spot inside to nail boards back on. Points live per player in `PlayerPoints`, which
listens to `Events` and credits only its own player (`source` on every hit, kill and repair).

## Look and settings (M6)

- `RoofMap` (`scripts/effects/roof_map.gd`) casts rays down over the play area once at load
  (about 60 ms) and keeps the height of the highest solid surface per 0.4 m cell, grown by a cell so
  walls never leak. Snow hides below it and `Atmosphere` uses it to tell indoors from outdoors.
- `Atmosphere` eases the one global fog and the ambient light between the cold storm outside and the
  warm, clear Stube inside. The `Environment` in `main.tscn` holds the outdoor look, because the
  mountain backdrop reads its fog colour at load.
- `Snowfall` is a `GPUParticles3D` whose box follows the camera while the flakes stay in world space;
  `assets/shaders/snowflake.gdshader` drops every flake under a roof.
- `PostFX` (a `CanvasLayer` under the HUD) grades and vignettes, and draws the frost
  (`assets/shaders/post_fx.gdshader`); `Atmosphere` sets its `frost` amount, building up over
  `FROST_BUILD_TIME` outdoors and thawing over `FROST_THAW_TIME` indoors.
- `Settings` (autoload) holds sensitivity, aiming sensitivity, invert Y, the volume of each bus in
  `default_bus_layout.tres` (Master, Music, Effects, Ambience), language and render resolution,
  saved to `user://settings.cfg` (IndexedDB in the browser). The menu
  (`scenes/ui/settings_menu.tscn`) opens from the start screen and the pause menu, applies changes
  live and saves on Back.

## Sound (M6)

Every sound is synthesised by `tools/audio/` (no samples). To change one, edit its recipe in
`tools/audio/sfx.py` (effects) or `tools/audio/music.py` (the band, the Harmonika, the stingers) and
rebuild:

```
pip install numpy scipy soundfile
python tools/audio/build.py               # everything, prints sizes
python tools/audio/build.py swing band_3  # only these
python tools/audio/inspect_audio.py <out_dir>   # levels, clipping, DC, loop seams, spectrograms
python tools/audio/recordings.py "<extracted Prepared SFX Library>"  # the real gunshots
```

The gunshots (and the core of the Böller) are real recordings from the CC0 "Free Firearm Sound
Library" (see ASSETS.md); `recordings.py` cuts every shot out of its near-distance takes. The
library itself (344 MB) is not in the repo; download it from OpenGameArt to rebuild them.

- Files are `assets/audio/<folder>/<id>_<n>.ogg`; `_n` are variants, picked at random. The folder is
  the bus: `sfx` Effects, `music` Music, `ambience` Ambience (the wind goes through its own `Wind`
  bus into Ambience, whose low-pass muffles it indoors).
- `Sound` (autoload, `scripts/autoload/sound.gd`) loads them all at start. `play(id)` for the
  player's own sounds, `play_at(id, position)` for sounds in the world, `attach(id, node)` for a
  loop that rides on a node. `MIX` sets each sound's level, `VOICES` how many may play at once,
  `LOOPS` which loop. Every button clicks.
- Weapons name their sounds in their `.tres` (`fire_sound`, `fire_loop_sound`, `secondary_sound`,
  `play_sound`, `reload_sound`, `reload_end_sound`, `swing_sound`, `hit_sound`), enemies theirs in
  `data/enemies` (`groan_sounds`, `death_sound`, `voice_pitch`).
- `BandDirector` (`scripts/audio/band_director.gd`) plays the band: the whole tune looped in the
  menu, and at the start of each wave only its first eight bars, one tempo tier per wave (`band_1`
  to `band_8`), pitched up past the last; `Ambience` (`scripts/audio/ambience.gd`) the
  storm and the creaks.

## Textures (M6)

The world's surfaces are CC0 photo textures from Poly Haven (see ASSETS.md), made by
`tools/textures/build.py`: it downloads each 1K map once into `tools/textures/cache/` (gitignored),
shrinks it to 256x256 and brings the albedo to a target average colour. To swap or retune one, edit
its line in `TEXTURES` and rebuild:

```
pip install pillow numpy
python tools/textures/build.py              # everything, prints the ASSETS.md table
python tools/textures/build.py stone snow   # only these
godot --headless --import                   # then reimport
```

- The materials are in `assets/materials/` (one per surface: `wood_wall`, `wood_floor`, `stone`,
  `snow` ...). The map is built from CSG boxes without useful UVs, so the textures are projected
  from the world axes (triplanar) at their real size (`uv1_scale` = 1 / metres per repeat), which
  keeps them even across boxes of any size. The parts that move (barricade `board`s, `door_locked`
  panels) project in their own space so the texture rides along.
- Neutral textures (`painted_wood`, `wool`) are light grey and coloured by the material's
  `albedo_color`, so one file serves several materials (red doors, green and grey skis, red and
  green blankets).
- Imports: albedo lossy WebP (quality 0.85), normal maps lossless, mipmaps on, and no GPU texture
  compression (browsers support it unevenly). All together 0.82 MiB of the 10 MB budget.
- The terrain (`AlmTerrain`) uses `assets/shaders/terrain.gdshader`: snow on gentle faces, rock on
  steep ones, both triplanar.
- `ShaderWarmup` draws every material in `assets/materials/` behind the start screen, so a room is
  not compiled the first time its door opens.

## Title screen and loading (#77, #78)

- The title (`StartScreen`) has Solo, Co-op and Settings; nothing starts on a click elsewhere. Until
  the shaders are built it shows only the still picture, "Preparing the hut ..." and a progress bar:
  each new shader blocks the browser's main thread (up to ~0.7 s), so a live menu stuttered
  (play-test). Then the menu fades in and the picture comes alive. An invite link waits too.
- Behind it, `TeaserBackdrop` animates a still from the game in 2D (drift, snow, lamp flicker, the
  Jagdflinte firing now and then), so it needs no 3D shaders. The still is rendered by
  `godot res://tools/teaser/teaser.tscn` into `assets/ui/teaser.jpg` (lossy import); the tool prints
  where the muzzle and the lamp are, for `MUZZLE_AT` / `LAMP_AT`.
- Loading (measured 2026-10-18, Edge on Windows, first visit): downloads 1.9 s, Godot running by 2 s,
  scene built by ~4.5 s; then the browser compiles ~150 WebGL programs, ~16 s on a first visit (one
  per material setup and light pass; the lit ones take ~0.7 s each, built twice, with and without
  instancing). The browser keeps them in its shader cache: a returning visit is ready in ~2 s.
- So `ShaderWarmup` starts with the camera drawing only its own render layer (20): the first frame is
  cheap and the title shows at ~5 s. It then shows a few items per frame (every material in the
  world, every weapon, enemy, the hiker and the code-built effects) and reports `progress`; at the end
  the camera gets the world back with everything compiled. A co-op start before that finishes it at
  once (`finish_now`). It runs once per session (a restart skips it).
- `SharedLook.adopt` puts plain lit colours on a white texture with the props' triplanar setup (the
  same look) so they share shaders; `godot --headless res://tests/material_report.tscn` lists the
  material setups (17, 8 of them lit). Visual check: `godot res://tests/title_view.tscn -- <dir>`.

## Enemy models and ragdolls (M6)

The five enemies are self-made low-poly models, built by a script into `assets/models/enemies/`:

```
godot --headless --script res://tools/models/build_enemies.gd
```

- `tools/models/character_builder.gd` lofts tubes (rings along a path), balls and boxes, binds each
  to one bone or blends it between two, and saves a scene: a `Skeleton3D` (hips, chest, head, and
  per side arm, forearm, hand, thigh, shin, foot), the skinned `Body` and `Head` meshes (the head
  apart so a head pop can hide it) and a `PhysicalBoneSimulator3D` with 11 bodies. Each model is
  built at its `EnemyData.model_scale`, so no physics body is ever scaled.
- Costumes are vertex colours over a few shared, neutral, UV-mapped materials in
  `assets/materials/characters/` (wool, leather, fur, skin, linen, wood, metal, plain, glow).
- `EnemyRig` (`scripts/enemies/enemy_rig.gd`, on the model's root) poses the bones in code: the
  stance and walk the builder sets per type, plus one action at a time (`STRIKE`, `PULL`, `CLIMB`,
  `CROUCH`, `LEAP`, `DANCE`, `DAZED`, `CARRIED`) that `Enemy` starts from its states. The head
  hurtbox follows the head bone.
- Ragdolls (#39): a kill hands the bones to physics, pushed away from the shooter. They collide
  with the world only. At most `RAGDOLL_MAX` (6) are simulated at once; each freezes in the pose
  it fell into after `RAGDOLL_TIME`, and with no room left a corpse falls the old way. While it
  walks the ragdoll is switched off (its bodies out of the physics space), so it costs nothing.

## Weapon models (M6)

The weapons keep their viewmodel scenes (the scripts animate the parts by name); a script reshapes
the greybox parts and textures them in place:

```
godot --headless res://tools/models/build_weapons.tscn
```

- A long thin box (barrel, rod, handle) becomes an eight-sided tube, a box named `Stock` along the gun
  gets a rifle stock's profile, every other box gets chamfered edges.
- Colours become textured materials by what they look like: brown is walnut (`gun_wood`), metal is
  worn steel (`gun_steel`, tinted brass where it was yellow), other colours painted wood;
  near-white and near-black stay plain. They are projected in each part's own space, so the texture
  moves with a bolt or magazine.
- Each new mesh and material keeps its greybox original as metadata (`source`), so the script can be
  rerun after changing a rule. It runs as a scene, not with `--script`: the viewmodel scripts need the
  autoloads to compile. The rules live in `tools/models/reshape.gd`, shared with the props.

## Weapon upgrades: da Dengelstock (M9 part 4)

The Dengelstock (`scripts/zones/dengelstock.gd`, in the Holzschuppen's hay loft) forges a weapon
into the WeaponData its `upgrade` points to. The dengelt (`<id>_dengelt.tres`) and doppelt dengelt
(`<id>_doppelt.tres`) weapons are written from their base by a script, so retune the base and run it
again:

```
python tools/weapons/dengel.py      # every upgradable weapon, both levels
python tools/textures/engrave.py    # the engraved steel of the forged look (gun_forged.png)
```

- The rules (damage, magazine, reserve, boss share, shot pitch, a melee or special weapon's twist,
  `WeaponData.twist`, its meaning per behavior) are in
  `dengel.py`; `tests/m9_dengel` checks the files against them.
- A dengelt weapon keeps its base's `family`, so wall-buys, the chest and the slots count it as
  that gun. `ForgedLook` (`scripts/weapons/forged_look.gd`) dresses its model: copies of the same
  materials with gold steel on the engraved texture and darker wood, so no new shader is built.

## Prop models (M6)

```
godot --headless res://tools/models/build_props.tscn
```

- The prop, event and equipment scenes (the Hüttentruhe, Schnaps shrine, ammo crate, Brettljause,
  Bierfassl, Resi, the Murmeltier, Eisstock, Kuhfladen, Kuhglocke) get the weapons' treatment: tubes,
  chamfers and textures (the animals in fur).
- Furniture is CSG (its collision and the navmesh come from it), so it stays: every CSG shape made
  only of union boxes and cylinders, none wall-sized (over 3.2 m) or unshaded, is no longer drawn
  (render layers 0) and each part gets a child `Look`, a chamfered (or round) mesh with the same
  material. Walls with holes, floors and chalk outlines stay as they are.
- The Deitscha Tourist is a character model like the enemies (`assets/models/guest.tscn`, built by
  `build_enemies.gd`); `TouristGuest` walks him with the rig.

## Co-op (M7)

Plan and decisions: `NETWORKING.md`. All four parts are in: relay and lobby, the core loop with
downed and revive, the special weapons, equipment and events, and four players with the bandwidth
work (measured in `NETWORKING.md` section 9).

- **Relay**: `relay/` is the helper Worker `berghittn-relay` with the `Room` Durable Object (one per
  4-digit room code). It has no public route; `functions/api/room/[code].js` (Pages Function on
  berghittn.pages.dev) hands it the WebSocket. Both share `relay/src/route.js`. Binary frames
  `[peer i8][payload]` are forwarded with the sender rewritten; text frames are JSON control messages
  (`welcome`, `joined`, `left`, `closed` with a reason, and from the host `start`, `kick`). Nothing is
  stored; the host's socket attachment holds the room's build and started flag.
- **Godot**: `RelayPeer` (`scripts/net/relay_peer.gd`, a `MultiplayerPeerExtension`) puts Godot's
  multiplayer on that socket, batching packets into frames every 50 ms. Godot sends an `rpc()` to
  everyone as one copy per peer in a row; RelayPeer sends such a packet once (target 0, or -n for
  all but n) and starts a new frame only where the target changes, so the order holds for each peer.
  It counts bytes both ways (`Net.traffic()`, shown on the F3 overlay in co-op). The `Net`
  autoload (`scripts/autoload/net.gd`) is the session: create/join, the roster of names and hikers,
  the host's start, and why a session ended. It is an autoload (beside `Sound`) because the session
  must survive a scene reload. Solo never touches it.
- **Lobby** (`scripts/ui/lobby.gd`, the Co-op button on the title): name, head, hat, jacket and
  trouser colour (`HikerStyle`), saved with the settings; create a room or join by code; the invite
  link `?room=<code>` opens the lobby straight into that room. The host sees everyone on the stage,
  can remove players and starts with at least 2. Until a player changes something there, their
  hiker is their peer's default (`Settings.profile_for`), so four players never look alike.
- **Match**: main adds four nodes on every peer (the same paths, so RPCs match):
  - `CoopPlayers`: our pose, life (alive / downed / out) and health 20 times a second (16 packed
    bytes, like each shot's aim); the others as
    `Hiker`s 100 ms in the past (`PoseBuffer`). On the host the hikers are in group `player`, so enemies
    go for them; a hit is sent to that player (`take_damage` there, with the attacking puppet for the
    Pfanne's guard). Downed teammates get a `ReviveSpot` (hold E, 4 s) and a `MapMarker`; out players
    watch a teammate from behind and come back on the next `wave_started`.
    Part 3: each hiker `arm()`s a ghost `WeaponHolder` (`scenes/net/ghost_weapons.tscn`, `ghost =
    true`) and holds a copy of the gun in hand (`WeaponPickup.model_of`, pitched with the aim sent in
    the pose). Our holder's `acted` (shot, special, swing, blow, hold, release) goes out with the aim
    transform and the ghost `replay`s it through the weapon's own behavior: in ghost mode
    `_bodies_in` finds nothing and `strike` hits nothing, so only the look and the sound happen
    (plain guns: impacts and a muzzle flash; the flame: a stream of `Flames`). Thrown equipment
    (`PlayerEquipment.threw`) is copied with `harmless` set; a copied Kuhglocke still lures, so a
    guest's bell pulls the host's enemies. The Böllerschuss is passed on as its blast.
  - `CoopEnemies`: on the host it numbers the WaveManager's enemies and sends spawns,
    snapshots at 20 Hz (14 bytes each: id, position, yaw, lean, a burning flag; an enemy whose entry
    did not change is left out), actions
    (`Enemy.posed`), damage and kills with the hitting peer. Guests keep puppets (`Enemy.puppet`)
    under it; a hit on a puppet goes to the host through `Enemy.hit_relay` (receive_hit, scorch,
    ignite, dance, slows, stuns, flee, knockback, and the Mistgabel's lift, carry_to and hurl) and
    flashes at once. A puppet on a guest's fork is moved by that guest (`puppet_driven`), and the
    host's enemy follows its carry and hurl.
  - `CoopWorld`: waves, doors (`request_unlock`, refunds), barricades (board counts, `request_board`),
    the Hüttentruhe (`rolled` / `roll_for` / `taken`), dropped weapons (the Krampus-Rute: the host's
    `share_drop`, a guest's `request_drop`, first come), and game over (`Net.back_to_lobby`, relay
    `lobby`).
  - `CoopEvents`: the host's EventDirector sends the events; each actor is shared with an id and the
    guests get a copy (`copy = true`) moved by 20 Hz snapshots, its state set by `net_state` /
    `net_apply`. Milking, tapping and catching on a copy are `request`s; the host's actor decides
    (`net_request`) and the asker's game pays the reward (`net_granted`). `Coop.announce` shows a
    banner on every screen (the reward's own banner stays with the one who got it).
  - `Coop` (static) says where they are and `is_guest()`; `Player.life`, `WeaponHolder.set_downed` /
    `reset_loadout` carry downed and bled out. In co-op the world never pauses; the click that takes
    the mouse locks the trigger until it is let go.
- **Build id**: `tools/build_web.mjs` writes `build_id.txt` (gitignored, packed via the preset's
  include filter); the relay turns away a browser whose build differs from the host's.
- **Hiker**: `godot --headless --script res://tools/models/build_hiker.gd` builds
  `assets/models/hiker.tscn` (body, Head0-4, Hat1-9 as separate skinned parts; the jacket and trousers
  use their own neutral materials that `Hiker` tints per player). Visual check:
  `godot res://tests/hiker_view.tscn -- <dir>`, the lobby: `godot res://tests/lobby_view.tscn -- <dir>`.
- **Stuffed animals (M8)**:
  - `tools/models/stuffed.gd` draws each animal once in its own frame, and a transform places it
    on a hat (`build_hiker.gd`, Hat3-9) or in the Stube.
  - `godot --headless --script res://tools/models/build_trophies.gd` builds the Stube's meshes into
    `assets/models/trophies/` as plain unskinned meshes (`CharacterBuilder.save_static`).
  - `HatUnlocks` (a node in main) earns the locked hats (`HikerStyle.LOCKED`) into
    `Settings.unlocks` / `Settings.perchten`.
  - `Settings.profile_for` leaves out a hat that is not earned yet, while `edit_profile` (the
    lobby) keeps it.
  - `TrophyWall` and `Raurakl` live in `scenes/props/`.
  - Test: `godot --headless --fixed-fps 60 res://tests/m8_trophies.tscn`.
  - Look: `godot res://tests/zone_tour.tscn -- <dir> trophies` and `hiker_view` (close-ups of
    each stuffed hat).

Tests (the relay runs locally in `wrangler dev`, or set `RELAY_URL=wss://<preview>.berghittn.pages.dev`):

```
node --test relay/test/relay.test.mjs           # ids, cap of 4, routing, kick, refusals
node tools/net_test.mjs                         # tests/net_lobby: roster, hiker change, start, late joiner refused
node tools/net_test.mjs res://tests/net_match.tscn   # two main scenes: invite join, each sees the other's hiker
node tools/net_test.mjs res://tests/net_core.tscn    # enemies + kill points, door, board, chest, down/revive, out/back, game over
node tools/net_test.mjs res://tests/net_specials.tscn  # held gun, replayed Alphorn, copied bell, burning, fork, Rute drop, all four events
node tools/net_test.mjs res://tests/net_four.tscn      # 4 players: default jackets, everyone sees everyone, 24 enemies: KiB/s and frame time
NET_TEST_TIMEOUT_MS=1500000 node tools/net_test.mjs res://tests/net_waves.tscn  # two players clear waves 1-10 (about 10 min)
```

With browsers on a deployed build, the bots take its id and the browsers join by the room link:
`godot --headless res://tests/net_four.tscn -- --relay=wss://<site> --role=host --players=4 --bench=60 --build=<id>`
(and `--role=guest1 --room=<code>`), or `tests/net_waves.tscn` with `--players=4 --browsers=1`.

## Tests

```
godot --headless --fixed-fps 60 res://tests/m4_zones.tscn
```

Unlocks all six zones on the real main scene with points from the debug key: prompts and costs at
every door, spawn activation after each purchase against section 4, navmesh paths through opened
doors, the self-opening last door, the Jagdflinte, Stutzen and Repetierer wall-buys, ammo refills at half price, gun slots and switching,
the chamber rule for the new guns, and one payout per shotgun blast (not per pellet).

```
godot --headless --fixed-fps 60 res://tests/m6_audio.tscn
```

The sound: every sound the weapons, enemies and scripts ask for exists and the loops loop, the audio
stays under 8 MB, the band's title tune, one faster tier per wave and the quiet break, guns, reloads,
footsteps on boards and snow, groans, purchases, and the storm muffled indoors.

```
godot --headless --fixed-fps 60 res://tests/m6_textures.tscn
```

The textures: each at most 256x256, with mipmaps, listed in ASSETS.md and inside the 10 MB budget;
every lit world material textured and triplanar (moving parts in their own space); the props that
used to borrow a world colour have their own material; the terrain shows snow and rock.

```
godot --headless --fixed-fps 60 res://tests/m6_ragdoll.tscn
```

The enemy models: each one a rig at its size with a skinned body, a poppable head and an 11-body
ragdoll that is off while it walks, inside the 3 MB model budget; the head hurtbox on the head; a
swing that raises the arms; every type going limp when killed, its joints holding, thrown away from
the shooter, frozen after a while and standing again from the pool; and a crowd of 12 killed at
once simulating no more than 6 ragdolls.

```
godot --headless --fixed-fps 60 res://tests/m6_weapons.tscn
```

The weapon models: no greybox box left in any viewmodel, every lit colour textured and projected in
its part's own space (only near-white and near-black plain), weapons and enemies inside the 3 MB
model budget.

```
godot --headless --fixed-fps 60 res://tests/m6_props.tscn
```

The prop models: no greybox box left in a prop, event or equipment scene, every hidden CSG part
with its look and no look over a CSG still drawn, the Stube's tables still colliding at their tops,
and the Deitscha Tourist a character rig.

```
godot --headless --fixed-fps 60 res://tests/m5_core.tscn
godot --headless --fixed-fps 60 res://tests/m5_events.tscn
godot --headless --fixed-fps 60 res://tests/stuck_hunt.tscn
```

`m5_core`: the enemy mix per wave, boss waves, the Perchte lunge, bullet penetration, every Schnaps perk
and the Brettljause, the Hüttentruhe (specials only, take, let sink, swap), the Repetierer's fanning and
the Munitionskiste. `m5_events`: die Resi, the Bierfassl, the Murmeltier and the Deitscha Tourist with
the Eisstock (section 8a). `stuck_hunt`: all zones open, a crowd of every enemy type chasing a player
who hops about the map; flags enemies that stop making headway.

```
godot --headless --fixed-fps 60 res://tests/m5_alphorn.tscn
```

The Alphorn: what its cone blast hits (reach, angle, the wall in between) and how far it throws a
wanderer and a Knappe, the Echo all around for two notes, ammo and reload, and the Hüttentruhe
offering it at weight 1. Special weapons are a `WeaponData` plus a behavior script in
`scripts/weapons/behaviors/` (named by `behavior`, see `WeaponBehavior`); the WeaponHolder keeps ammo,
reloads and recoil and calls the behavior instead of the hitscan ray.

```
godot --headless --fixed-fps 60 res://tests/m5_pfanne.tscn
```

The Schmarrnpfanne: its Küche wall-buy replacing the shovel, the blow and its shove, and the guard on
a held V (front hits caught and bonked back, hits from behind not, slower walking, a real enemy's
swings against it).

```
godot --headless --fixed-fps 60 res://tests/m5_knoedel.tscn
```

The Knödelwerfer: a dumpling into a crowd (180 within 3 m, not beyond, and a ground burst), the sticky
pile slowing an enemy in it and for 4 s after, the Knödeltris, the dumpling pool, the muzzle showing
the next dumpling as the gun is ready, and the chest weight.

```
godot --headless --fixed-fps 60 res://tests/m5_kuhglocke.tscn
```

The Kuhglocke: the Stube wall-buy (300 for two, the Eisstock warning, refill), the throw, the lure
(wanderers within 20 m, one already inside, leave the player for the bell; one further out and the
Krampus do not), and the end after 10 s.

```
godot --headless --fixed-fps 60 res://tests/m5_kuhfladen.tscn
```

The Kuhfladen-Mine: the Schuppen wall-buy (250 for three), one placed in the Schuppen doorway, a
wanderer coming through (40 and slowed, once), the Krampus (hurt, not slowed), trodden flat after
four, at most six lying about.

```
godot --headless --fixed-fps 60 res://tests/m5_handboeller.tscn
```

The Seilbahn wall-buys: the Handböller (1500, ammo 750, the shell's burst radius, the 4.5 s reload,
the Doppelladung from the reserve and its kick) and the Alphorn, hidden until wave 10, then
announced and on sale for 4000. Lobbed shots share `LobbedShot` (Knödel, Böller shell).

```
godot --headless --fixed-fps 60 res://tests/m5_rodelkanone.tscn
```

The Rodelkanone: a sled shot a little down that flies, comes down about 4 m out and runs 15 m along
the pasture from there (300 to each enemy in its lane once, thrown aside, none beside the lane or
past its run), one aimed high that flies over a body close by and strikes the one past its landing, broken by a wall with nothing behind it hurt, the Kehre banking off a
slanted wall to reach round it and banking round the Stube without passing through a wall, the sled
pool, the next sled ready with the gun, and the chest weight.

```
godot --headless --fixed-fps 60 res://tests/m5_harmonika.tscn
```

The Steirische Harmonika: a polka making everyone within 8 m dance all around (not 11 m out, not
behind a wall): dancers stay on the spot, the one right next to the player never swings, a hit on a
dancer lands twice as hard, 20 a second for 4 s; the Krampus takes the damage but does not dance;
the Tanzboden (two rounds, laid where the player aims, everyone on it dancing, newcomers too, not
beside it, gone with the dance after 10 s); the polka animation length
and the chest weight.

```
godot --headless --fixed-fps 60 res://tests/m5_brennkessel.tscn
```

The Brennkessel-Werfer: two seconds of flame (16 fuel) on a crowd, 15 a tick to everyone in the cone
(not beside it, not past 8 m, not behind a wall), set on fire and burning 10 a second until 3 s after
the flame, hit points once a second instead of per tick, the Krampus burning too; the Brennlacke
(20 fuel, a burning puddle that lights whoever stands in it, not someone 4 m off, gone after 6 s);
the tick animation length and the chest weight.

```
godot --headless --fixed-fps 60 res://tests/m5_goassl.tscn
```

The Goaßl: on V in place of the shovel; the crack hits its 3.5 m cone for 40 and stuns (the Knappe
right in front does not swing, a stunned one stands still, free again after 1.5 s), not 60° aside or
5 m out; the Krampus takes the crack unstunned; V held past the crack lashes and drags in a wanderer
6 m out (slow walk, dazed, stunned after letting go), nothing to lash 9 m out; the chest handing it
into the melee slot.

```
godot --headless --fixed-fps 60 res://tests/m5_mistgabel.tscn
```

The Mistgabel: the thrust through the first two in a line (100 each), not a third, not one 40° aside,
not 4 m out; V held lifts the skewered one over the player's head, letting go hurls it (more than 5 m)
and it and the crowd where it lands take 80, the others nothing; the Krampus too heavy to lift; held
3 s, the fork throws by itself.

```
godot --headless --fixed-fps 60 res://tests/m5_krampusrute.tscn
```

The Krampus-Rute: dropped where the Krampus falls (announced) and taken with E onto V; the swat (150)
sends the struck one and the one behind it running from the player for 3 s, attacking nobody, not one
6 m off, not the Krampus; the Larve (V held) makes the one 6 m ahead flee for as long as it is held,
not one behind; not in the chest.

```
godot --headless --fixed-fps 60 res://tests/m5_acceptance.tscn
```

M5 acceptance "all items purchasable": every weapon and piece of equipment in `data/` has a way in
(the start, a wall-buy, the Hüttentruhe, the Krampus's drop, the Deitscha Tourist); then, with all
seven doors bought through the real doors, every wall-buy (the Alphorn once wave 10 comes), Schnaps
bottle, Brettljause item, the Munitionskiste and the Hüttentruhe can be walked to from the start, E
finds it and buying it gives what it sells, and the chest hands out every weapon in its pool. "Wave 10
reachable" is `m5_waves` (the real wave manager, waves 1 to 10 with both boss waves, against an
immortal bot; every enemy type shows up and none gets stuck).

```
godot --headless --fixed-fps 60 res://tests/m5_waves.tscn
godot --headless --fixed-fps 60 res://tests/upstairs.tscn
godot --headless --fixed-fps 60 res://tests/spawn_paths.tscn
```

`upstairs`: the player walks up the hall stairs, and an enemy follows a player up every level change
(gallery stairs, garden steps, hay-loft ramp, gondola platform). `spawn_paths`: from every spawn point
active at the start, an enemy makes it into the Stube. Both catch spots where bodies get stuck that the
navmesh thinks are fine.

```
godot --headless --fixed-fps 60 res://tests/m3_smoke.tscn
```

A bot holds the middle of the Stube and plays to wave 3 (shooting head and body, shovel kills, repairing
in the break). Checks wave sizes, spawn interval and break length against the formulas, that no enemy
climbs through a window that still has boards, and that the points (and the HUD) match the bot's own
hits, kills and repairs. Exits non-zero on failure.

```
godot --headless --fixed-fps 60 res://tests/melee_arc.tscn
```

One shovel swing must hit every enemy in the arc in front of the player and none behind.

```
godot --headless --fixed-fps 60 res://tests/window_attack.tscn
godot --headless --fixed-fps 60 res://tests/chamber.tscn
```

`window_attack`: a player pressed against a window takes no hits while the enemy outside tears it
open, and is hit once it has climbed in. `chamber`: guns with a chamber hold mag + 1 (start, reload
with a round chambered) and mag after a reload from empty.

```
godot --headless --fixed-fps 60 res://tests/fire_after_reload.tscn
```

A click buffered from before a reload, a click during it, and a trigger held through it must not
fire once the reload is done; only a new pull afterwards does (#73).

```
godot --headless --fixed-fps 60 res://tests/m2_smoke.tscn
```

Drives the real main scene: navmesh bake, an enemy pathing in through a window and hitting the
player, killing it with the pistol, regeneration, player death and the death screen.
`tests/` is excluded from the web export.

```
godot res://tests/climb_view.tscn -- <out_dir> inside|outside|break|reload|melee|hud|shoot
```

Needs a real window (not `--headless`): saves PNG frames of an enemy's window entry, seen from
inside or outside, of it tearing the boards off, of the pistol reload or the shovel swing, one
frame with the HUD, or shooting an enemy (wall puffs, hit flash, casings, head pop), for checking
visuals without playing.

```
godot res://tests/model_view.tscn -- <out_dir>
```

Needs a window: the enemy models in a plain studio, from the front and the back, their faces, every
action pose and a ragdoll fall.

```
godot res://tests/weapon_view.tscn -- <out_dir> [weapon id ...]
```

Needs a window: every weapon model in a plain studio from the side and at an angle, and as held.

```
godot res://tests/prop_view.tscn -- <out_dir>
```

Needs a window: the prop models (chest, shrine, crate, Jause, table set, door, window, equipment,
event models) in a plain studio, from the front and at an angle.

```
godot res://tests/crowd_bench.tscn
```

Frame rate with a full crowd: 24 enemies walking at the player, the six nearest killed every 3 s
(six ragdolls at once); prints FPS and the worst frame every 2 s. For the browser, export it as the
main scene with `tests/*` left in the export (2026-10-18: 144 FPS, worst frame 13.8 ms).

```
godot res://tests/zone_tour.tscn -- <out_dir> zones|guns|motion|aim|m5|trophies|alphorn|pfanne|knoedel|glocke|fladen|boeller|rodel|harmonika|brennkessel|goassl|mistgabel|rute
```

Also needs a window: one frame per zone (all doors open), the wall-buys and a door mid-swing; or
the Jagdflinte and Stutzen being drawn, fired and reloaded.

```
godot res://tests/hitch_probe.tscn
```

Needs a window too: frame times around first-time moments (a door bought, the Hüttentruhe's glow
and roll, taking a weapon, each enemy type turning up), printing every frame over 25 ms. A first
draw compiles shaders, which stalls far longer in the browser than on desktop, so
`ShaderWarmup` (`scripts/effects/shader_warmup.gd`) draws every weapon model once behind the start
screen; without it the first chest roll took 77 ms on desktop and 1-2 s in the browser.

## Deploy

Cloudflare Pages project `berghittn` -> https://berghittn.pages.dev

```
npx wrangler@latest pages deploy export --project-name berghittn --branch main --commit-dirty=true
```

The deploy also uploads `functions/` (the co-op Function) with the Durable Object binding from the
root `wrangler.toml`. The relay Worker is deployed on its own, only when `relay/` changed:

```
cd relay && npx wrangler@latest deploy      # "No targets deployed" is right: it has no public URL
```

Note: in wrangler 4.15x, `pages project create` delegates to Workers by default; the
project was created once with `--force` to get a classic Pages project. Do not pass
`--force` on deploys.
