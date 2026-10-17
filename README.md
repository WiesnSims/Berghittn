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
down the sights, Stutzen: scope, Jagdflinte: both barrels), V melee (shovel), R reload, 1 / 2 / Q / mouse wheel
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

## Tests

```
godot --headless --fixed-fps 60 res://tests/m4_zones.tscn
```

Unlocks all six zones on the real main scene with points from the debug key: prompts and costs at
every door, spawn activation after each purchase against section 4, navmesh paths through opened
doors, the self-opening last door, both wall-buys, ammo refills at half price, gun slots and switching,
the chamber rule for the new guns, and one payout per shotgun blast (not per pellet).

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

The Rodelkanone: a sled run along the pasture (300 to each enemy in its lane once, thrown aside, none
beside the lane or past 15 m), broken by a wall with nothing behind it hurt, the Kehre banking off a
slanted wall to reach round it and banking round the Stube without passing through a wall, the sled
pool, the next sled ready with the gun, and the chest weight.

```
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
godot res://tests/zone_tour.tscn -- <out_dir> zones|guns|motion|aim|m5|alphorn|pfanne|knoedel|glocke|fladen|boeller|rodel
```

Also needs a window: one frame per zone (all doors open), the wall-buys and a door mid-swing; or
the Jagdflinte and Stutzen being drawn, fired and reloaded.

## Deploy

Cloudflare Pages project `berghittn` -> https://berghittn.pages.dev

```
npx wrangler@latest pages deploy export --project-name berghittn --branch main --commit-dirty=true
```

Note: in wrangler 4.15x, `pages project create` delegates to Workers by default; the
project was created once with `--force` to get a classic Pages project. Do not pass
`--force` on deploys.
