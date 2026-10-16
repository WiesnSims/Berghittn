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

WASD / arrows move, mouse look, left click shoot, V melee (shovel), R reload, 1 / 2 / Q / mouse wheel
switch gun, Space jump, Shift sprint (forward only), C crouch (not Ctrl: Ctrl+W closes the browser tab),
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

"Die Hütte" (section 4) is six zone scenes in `scenes/zones/`, joined in a loop by buyable doors
(`ZoneDoor`, `scenes/zones/door.tscn`, placed in `main.tscn` under `World/Doors`):
Stube – Küche – Skiraum – Seilbahn – Schuppen – Terrasse – Stube. Zone names and door costs are in
`data/zone_table.tres`; `ZoneMap` (node `Zones` in main) tracks which are open. Adjacency comes from
the doors, so a door's `zone_a` / `zone_b` is the only layout setting. A door costs what the zone behind
it costs, and opens by itself once both its zones are open (the loop's last door). Each window is a
`scenes/zones/window.tscn` instance (barricade, player blocker, bars, navigation link) on a hole in the
zone's wall CSG. `SpawnPoint` markers outside each zone's windows carry their zone id; the wave manager
only uses those whose zone is open or next to an open one. The Terrasse is open air: a fence with gaps
keeps players in and lets enemies through. Wall-buys (`WallBuy`, a chalk outline per gun) sell the
Jagdflinte (Stube) and the Stutzen (Skiraum), and once you carry the gun, ammo at `ammo_cost` (half price).
Two gun slots: a new gun goes in the free slot, otherwise it replaces the gun in hand.

## Navigation

One `NavigationRegion3D` (`World/Navigation` in main) with `scripts/zones/navmesh_baker.gd` bakes
the whole map at load from the colliding CSG shapes (~16 ms on desktop), and rebakes from cached faces
whenever a door opens. Windows are one-way `NavigationLink3D`s; enemies hop through them when the
agent reaches a link.
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
godot res://tests/zone_tour.tscn -- <out_dir> zones|guns
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
