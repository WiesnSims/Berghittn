# Berghittn — Game Design & Agent Instructions

> This file is the single source of truth for the project. Read it fully before
> writing code. Work milestone by milestone (section 12). Do not skip ahead.
> If something here conflicts with reality (an API changed, a limit was hit),
> stop, report it, and propose a change to this file rather than guessing.

## 0. Your responsibilities as the agent (Claude Code)

You are expected to run the full build loop yourself, without being asked
each time:

1. **Export** the Godot project to web (headless, from the command line).
2. **Deploy** the export to Cloudflare with `wrangler`.
3. **Test** the deployed game: open the live URL in a headless browser
   (Playwright MCP or Chrome DevTools MCP), read the console errors and
   failed network requests, and take a screenshot to confirm the canvas
   renders.
4. **Fix** the errors you find, then export, deploy and test again. Repeat
   until the game loads cleanly or you are blocked by something only the user
   can solve.

Before starting M0, check your tools yourself and set up what you can:
`godot` is available, the Web export templates are installed, Node.js works,
`wrangler whoami` shows a logged-in account, and a browser MCP server is
available. Install or configure whatever you are able to (for example adding
an MCP server or running `npx playwright install`).

### When you need something from the user

If you need anything from the user, say so clearly and stop at that point
instead of guessing or working around it. Start the message with
**ACTION NEEDED:**, then state exactly what you need, why, and the precise
steps or commands the user should run. Continue with any work that does not
depend on it.

Things only the user can do, for example:

- install Godot or its export templates, if missing
- create the Cloudflare account or project and run `wrangler login`
- approve installing an MCP server or other tool
- answer the open questions in section 16
- play-test and give feedback (you cannot judge whether the game is fun)
- approve the networking plan before M7
- approve external assets and their licenses

Never ask the user to paste passwords or API tokens into the chat, and never
store them in the repository. Use login flows (such as `wrangler login`)
instead. Never claim a deploy or test succeeded if you could not run it;
say what failed and why.

## 1. One-paragraph pitch

First-person wave-survival shooter for 1–4 players, playable in the browser.
You are stuck in a remote Alpine hut during a snowstorm while the undead climb
the mountain. Defend the hut, earn points, unlock new areas (kitchen, terrace,
ski room, cable car station), buy weapons and perks, survive as many waves as
possible. Tone: dark humor with affectionate Austrian/Bavarian stereotypes.
Gameplay model: the classic "zombies mode" loop (waves, points, doors,
wall-buys, perks, mystery box). Do not copy any existing game's names, assets,
maps or text. All names and content here are original.

## 2. Design pillars

1. **Small and polished beats big and broken.** One compact map, few enemy
   types, everything works.
2. **Readable chaos.** The player must always understand where enemies come
   from and what to do next.
3. **Dark but funny.** Austrian dialect one-liners, absurd weapons, grim setting.
4. **Browser-first.** Every decision is checked against web export limits.
5. **Single-player first, co-op second.** The game must be fully fun solo
   before any networking is written.

## 3. Hard technical constraints

| Topic | Rule |
|---|---|
| Engine | Godot 4.x (latest stable 4.x at project start; record exact version in `README.md`) |
| Language | GDScript with static typing everywhere (`var hp: int = 100`) |
| Renderer | **Compatibility (OpenGL/WebGL2)** — required for web export |
| Platform | Web export (HTML5/WASM) is the primary target; desktop runs are for dev |
| Hosting | Cloudflare (static hosting). Verify current limits in the Cloudflare docs before deploy |
| File size | Cloudflare Pages Free rejects single files over **25 MiB**. The engine `.wasm` of a default Godot 4 web export can be near or over this. Check file sizes after the very first export (milestone 0) and report. Options: smaller custom export template, or serving large files from Cloudflare R2. Do not proceed to gameplay work until this is resolved |
| Threads | Prefer exporting **without thread support** (no SharedArrayBuffer needed) unless required. If threads are used, the host must send COOP/COEP headers (`_headers` file on Cloudflare) |
| Art | **Lo-fi realism**: low-poly meshes with low-resolution, photo-based textures (early-2000s look). Default texture size 256x256, 512x512 only for hero assets (weapons, enemy faces). Albedo map only by default, optional normal map at 256x256 for key props. Reuse textures and trim sheets heavily, one material per prop group. No heavy lighting features (the Compatibility renderer supports fewer effects). Get the realistic mood from fog, a dark palette, warm interior light, color grading and a light grain/vignette, not from texture resolution. Use only self-made, CC0, or properly licensed assets (CC0 texture libraries such as ambientCG and Poly Haven exist; verify the license of every asset). Record every external asset and its license in `ASSETS.md` |
| Pack size | All assets end up in the exported `.pck`, which is a **single file** and subject to the same 25 MiB limit. Budget: textures max 10 MB, audio max 8 MB, models max 3 MB, so the `.pck` stays under about 22 MiB. Check the real `.pck` size after every milestone. If the budget cannot be met, stop and propose splitting the pack or hosting large files on R2. Prefer lossless/WebP texture import and check the size result, since GPU texture compression support differs between browsers |
| Audio | Short compressed clips (OGG). Keep total audio under 8 MB |
| Performance | Target 60 FPS on a mid-range laptop. Max enemies alive at once: 24 (solo), 24 total in co-op (not per player). Pool and reuse enemies and projectiles instead of instancing constantly |
| Networking | ENet is not available in web builds. Use `WebSocketMultiplayerPeer` (or WebRTC). Cloudflare static hosting cannot run a game server; a relay is needed (e.g. a Cloudflare Worker). Decide and document in milestone 7, not earlier |
| Secrets | Never commit tokens, API keys or `.env` files. The user runs `wrangler login` themselves |

## 4. Setting and map

Single compact map: **"Die Hütte"**, an Alpine mountain lodge plus surroundings,
snowstorm outside, low visibility, warm interior light.

Zones (each is a separate area scene joined at doors). Costs are in points.

| Zone id | Name | Starts unlocked | Door cost | Notes |
|---|---|---|---|---|
| `stube` | Gaststube (main room) | yes | – | Spawn point, first wall-buy, fireplace |
| `kueche` | Küche | no | 500 | Kitchen; Schnaps shrine (perk machine) |
| `terrasse` | Terrasse | no | 750 | Open snowy terrace, long sight lines |
| `skiraum` | Skiraum | no | 1000 | Narrow room, good chokepoint, wall-buy |
| `schuppen` | Holzschuppen | no | 1250 | Woodshed, the mystery chest spawns here at fixed spot |
| `seilbahn` | Seilbahn-Station | no | 1500 | Cable car station, the alphorn weapon location in later waves |

Enemy spawn points ("Fenster" and "Türen") are placed per zone as `Marker3D`
nodes in group `spawn_points`. A spawn point is **active** only if its zone
is unlocked or adjacent to an unlocked zone. Barricaded windows: enemies
break a barricade in ~3 seconds; players can repair it for +10 points per
board (max 6 boards per window).

## 5. Player

- First-person controller: `CharacterBody3D`, walk, sprint (stamina-free,
  slower aiming), jump, crouch.
- Health 100. Regenerates 10 HP/s after 5 s without damage. Down at 0 HP.
- Solo: down = game over. Co-op: downed player can be revived by a teammate
  holding interact for 4 s (see section 10). Game over when all players are
  downed at the same time.
- Interact key (`E`): open doors, buy, repair, revive, use shrine.
- Points (currency) are per player. Display top-left HUD.

## 6. Weapons

All weapons are data-driven `Resource` files (`WeaponData`), never hardcoded.
Fields: `id`, `display_name`, `damage`, `headshot_multiplier`, `fire_rate`,
`mag_size`, `reserve_ammo`, `reload_time`, `spread`, `range`, `is_auto`,
`pellets`, `cost`, `ammo_cost`, `behavior` (optional id of a script for special
effects, see section 6a).

| Id | Name | Type | Damage | Fire rate (shots/s) | Mag / Reserve | Cost |
|---|---|---|---|---|---|---|
| `pistole` | Dienstpistole | semi-auto pistol | 25 | 4 | 8 / 64 | start weapon |
| `jagdflinte` | Jagdflinte | double-barrel shotgun | 20 x 8 pellets | 1.5 | 2 / 24 | 500 (wall-buy, Stube) |
| `stutzen` | Stutzen | bolt-action rifle | 120 | 0.8 | 5 / 40 | 750 (wall-buy, Skiraum) |
| `repetierer` | Repetierer | lever/repeater rifle | 45 | 3 | 10 / 80 | 1000 (chest only) |
| `schaufel` | Schneeschaufel | melee | 70 | 1.2 | – | 0 (always equipped) |
| `alphorn` | Alphorn | wonder weapon | 200 area | 0.5 | 6 / 18 | chest only, rare |
| `knoedelwerfer` | Knödelwerfer | wonder weapon | 180 area | 1.0 | 12 / 36 | chest only, rare |
| `rodelkanone` | Rodelkanone | wonder weapon | 300 line | 0.4 | 4 / 12 | chest only, rare |
| `brennkessel` | Brennkessel-Werfer | wonder weapon | 15 per tick | 8 ticks/s | 100 fuel / 200 | chest only, rare |
| `harmonika` | Steirische Harmonika | wonder weapon | 20/s while dancing | 0.3 | 3 / 9 | chest only, rare |
| `handboeller` | Handböller | hand mortar | 150 area | 0.7 | 1 / 10 | 1500 (wall-buy, Seilbahn) |
| `schmarrnpfanne` | Schmarrnpfanne | melee | 90 | 1.0 | – | 400 (wall-buy, Küche) |
| `goassl` | Goaßl | melee (whip) | 40 | 1.5 | – | chest only |
| `mistgabel` | Mistgabel | melee (long reach) | 100 | 1.0 | – | chest only |
| `krampusrute` | Krampus-Rute | melee | 150 | 1.4 | – | dropped by the Krampus boss |

Rules:
- Ammo refill from wall-buys costs half the weapon price.
- Slots: 2 gun slots (wonder weapons and the hand mortar use a gun slot),
  1 melee slot (starts with the shovel, can be replaced), 1 equipment slot
  (stackable throwables, see section 6a).
- **Hüttentruhe (mystery chest):** costs 950, gives a random weapon from the
  chest pool, weighted (each wonder weapon weight 1, all others weight 5). Fixed location in
  `schuppen`. Animation: lid opens, weapon floats for 4 s, player must take it.
- **Alphorn:** fires a cone-shaped sound wave that damages and knocks back
  all enemies in a 12 m cone; funny low horn sound, screen shake.

### 6a. Absurd weapons: behaviors and equipment

Each special weapon is a `WeaponData` resource plus a small behavior script
(`behavior` field). Build them one at a time, each in its own script, so a
broken weapon never blocks the others. Names are original parodies of
Alpine folk culture.

**Wonder weapons (chest only)**

- **Knödelwerfer:** launches giant bread dumplings (Semmelknödel) in a ball
  arc. On impact: 3 m explosion for 180 damage and a sticky pile that slows
  enemies by 50% for 4 s. Comic "splat" sound.
- **Rodelkanone:** fires a wooden sled that slides along the ground in a
  straight line for 15 m, hitting every enemy on the path for 300 damage with
  knockback. The sled then disappears with a crash.
- **Brennkessel-Werfer:** a copper schnaps still strapped to the back with a
  hose. Continuous flame cone, 8 m range, 15 damage per tick plus burning
  (10 damage/s for 3 s). Consumes fuel while the trigger is held.
- **Steirische Harmonika:** an accordion. Firing plays a short polka that
  makes all enemies within 8 m "dance": they stop attacking for 4 s, take
  20 damage per second, and take double damage from other weapons while
  dancing. Bosses are immune to the dance but take the damage.

**Regular absurd weapons**

- **Handböller:** a hand-held black-powder mortar like the ones used at
  Schützen celebrations. One loud shot, 3 m explosion, very long reload.
- **Schmarrnpfanne:** a heavy frying pan. Satisfying "bonk" sound, small
  knockback, fastest strong melee.
- **Goaßl:** a long whip (Goaßlschnalzen). Cracks loudly, hits in a short
  cone, and stuns enemies for 1.5 s.
- **Mistgabel:** pitchfork with long reach; pierces and hits two enemies in
  a line.
- **Krampus-Rute:** birch rod dropped by the Krampus boss. Hits cause enemies
  in a small radius to flee for 3 s.

**Equipment (1 slot, stackable, thrown or placed with a key)**

| Id | Name | Effect | Cost | Max carried | Where |
|---|---|---|---|---|---|
| `kuhglocke` | Kuhglocke | Thrown decoy cowbell; rings for 10 s and attracts all enemies within 20 m | 300 | 2 | wall-buy, Stube |
| `kuhfladen` | Kuhfladen-Mine | Placed on the floor; enemies stepping in it are slowed 60% for 5 s and take 40 damage | 250 | 3 | wall-buy, Schuppen |

Balance notes: wonder weapons must feel exciting but not make the game trivial.
Tune damage numbers by playtesting, and keep every number in the data
resources so changes never require code edits.

## 7. Enemies

All enemies share a base `Enemy` scene and are configured by `EnemyData`
resources. Navigation uses `NavigationAgent3D` with a baked navmesh per zone.
Enemy AI is simple: move to nearest player; if a barricade is in the way,
attack it; attack in melee range.

| Id | Name | HP formula | Speed | Damage | Notes |
|---|---|---|---|---|---|
| `wanderer` | Wanderer (hiker zombie) | 100 + 15·wave | 2.5 m/s | 20 | Basic enemy, matching hiking outfit |
| `tourist` | Tourist | 60 + 10·wave | 5.0 m/s | 15 | Fast runner, appears from wave 3, wears a camera |
| `knappe` | Bergknappe (miner) | 400 + 50·wave | 1.8 m/s | 45 | Tank, appears from wave 6 |
| `perchte` | Perchte | 250 + 30·wave | 4.0 m/s | 30 | Wooden-mask monster, appears from wave 8, short lunge attack |
| `krampus` | Krampus (boss) | 3000 + 500·(wave/5) | 3.0 m/s | 60 | Boss wave every 5th wave starting wave 5, spawns with 6 wanderers |

Headshots deal `headshot_multiplier` x damage (default 2.0).
Death: ragdoll-lite (simple fall animation or particle puff), disappears
after 5 s. No gore beyond stylized effects. Keep it comic-horror.
Stylized head pop (user request, 2026-10-16): a headshot kill dealing at least
`head_pop_damage` (EnemyData) in one hit hides the head and bursts it into a red cloud of
blocky particles. No anatomy, no lingering remains.

## 8. Waves and points

Wave formulas (n = wave number, starting at 1):

- Total enemies in wave: `6 + 2*n` (solo). Co-op: multiply by `1 + 0.5*(players - 1)`.
- Max alive at once: 24.
- Spawn interval: `max(0.6, 2.5 - 0.1*n)` seconds.
- Between waves: 10 s break, a message "Welle N" appears, barricades can be repaired.
- Enemy type mix: determined by `wave_table.tres` (data resource), not hardcoded.

Points:

| Event | Points |
|---|---|
| Hit (non-lethal) | 10 |
| Kill, body | 60 |
| Kill, headshot | 100 |
| Kill, melee | 130 |
| Repair a board | 10 |
| Revive teammate (co-op) | 100 |

Optional power-ups dropped from enemies (random 3%): **Doppelte Punkte** (30 s),
**Sofort-Kill** (20 s), **Nachschub** (full ammo). Implement only after
milestone 5.

## 9. Perks: the Schnaps shrine (Küche)

One shrine in the kitchen sells perks, each once per life. Costs in points.

| Perk | Cost | Effect |
|---|---|---|
| Enzian | 2000 | +50 max health |
| Marillenbrand | 2500 | Revive speed x2, reload speed +25% |
| Jagertee | 1500 | Movement speed +15% |
| Zirbenschnaps | 3000 | Weapon damage +20% |

Perks are lost when the player is downed (solo: irrelevant, game over).

## 10. Co-op (1–4 players) — design only, build late

- Each player has own health, points, weapons, perks.
- Enemies target the nearest player. Host-authoritative model: host simulates
  enemies, clients send inputs and receive state.
- Downed state: player crawls, can only use pistol; bleed-out timer 30 s.
- Revive: teammate holds `E` within 2 m for 4 s.
- Shared: waves, doors (anyone can open, the opener pays), chest (opener pays).
- Lobby: create/join game with a short room code. Max 4 players.
- Voice chat is out of scope.

## 11. Look, feel, sound, text

- Art: gritty lo-fi realism. Low-poly meshes with low-resolution photo-based
  textures (wood, stone, snow, fabric), warm orange interior light, cold blue
  exterior, fog and snow particles outside, slight film grain and vignette.
  Enemies must stay readable by silhouette and color even in the dark.
  Texture size rules are in section 3.
- Audio: storm wind ambience, creaking wood, a distorted brass band version of
  a folk-style tune that gets faster per wave (original composition or CC0
  only, no existing songs), gunshots, alphorn blast.
- Language: UI and dialog strings live in `strings_de.tres` (German/Austrian)
  and `strings_en.tres` (English). Never hardcode display text in scripts.
- Character one-liners (examples, extend freely): "Geh, des gibt's jo ned!",
  "Na, des is ka Wanderweg mehr.", "Servus, du Gfrast!", "Jetzt brauch i
  an Schnaps."
- Use no real brand names, logos or trademarked products. Invent parody labels.

## 12. Milestones (work in this order)

Each milestone ends with: export to web, run the browser check (section 14),
fix console errors, commit. Stop and report after each milestone.

**M0 — Pipeline proof (no gameplay)**
- Create empty Godot 4 project with Compatibility renderer, one scene with a
  cube and a label.
- Web export works from the command line (headless).
- Deploy to Cloudflare, URL loads, no console errors.
- Report the size of every exported file. If any file exceeds 25 MiB, stop and
  propose a solution before continuing.
- Acceptance: public URL shows the scene, console shows no errors.

**M1 — Player and one room**
- First-person controller, the `stube` room with greybox geometry, mouse look,
  pointer lock on click, pause menu.
- Acceptance: walk around the room at 60 FPS in the browser.

**M2 — Shooting and one enemy**
- `WeaponData` resource, pistol, hitscan shooting, reload, HUD ammo.
- `wanderer` enemy walks toward the player and attacks; player health and
  death screen.
- Acceptance: kill an enemy, die to an enemy, restart.

**M3 — Waves, points, barricades**
- Wave manager with formulas from section 8, spawn points, windows with
  barricades, points and HUD, break between waves.
- Acceptance: survive and reach wave 3, points counted correctly.
- Added by user decision (2026-10-16): the Schneeschaufel as quick melee (V). The 72 starting
  pistol rounds cannot clear waves 1–3 before M4 brings ammo refills, and it makes the
  melee-kill points testable.

**M4 — Zones, doors, wall-buys**
- All six zones greybox-connected, door purchasing, spawn activation rules,
  shotgun and rifle wall-buys, ammo refill.
- Acceptance: unlock all zones in a test run (debug key may add points).

**M5 — Shrine, chest, more enemies**
- Perks, Hüttentruhe, `tourist`, `knappe`, `perchte`, `krampus` boss wave.
- Special weapons from section 6a, one at a time in this order: alphorn,
  Schmarrnpfanne, Knödelwerfer, Kuhglocke, Kuhfladen-Mine, then the rest.
  Report after each one; the user may stop adding weapons at any point.
- Acceptance: all items purchasable, wave 10 reachable.

**M6 — Art and audio pass**
- Replace greybox with low-poly assets, lighting, snow effects, sounds,
  German/English strings, settings menu (sensitivity, volume).
- Acceptance: file sizes within budget, 60 FPS target met.

**M7 — Co-op (decision gate)**
- Before coding, write `NETWORKING.md`: chosen transport, relay approach on
  Cloudflare, authority model, expected costs. The user approves first.
- Then implement lobby, 2-player sync, then 4 players.
- Acceptance: two browsers can play the same match for 10 waves.

## 13. Project structure

```
res://
  scenes/        # player, enemies, zones, ui, main
  scripts/       # gameplay code, grouped by feature
  data/          # WeaponData, EnemyData, wave_table, strings (.tres)
  assets/        # models, textures, audio (with ASSETS.md for licenses)
  export/        # web export output (gitignored)
README.md
ASSETS.md
GAME_DESIGN.md  # this file
```

Code conventions:
- One responsibility per script, small scripts, signals over direct references.
- Autoloads only for `GameState`, `Events`, `Settings`.
- No magic numbers in code: gameplay numbers come from data resources or a
  single `constants.gd`.
- Comment the "why", not the "what".

## 14. Build, deploy and test loop

The agent runs this loop itself (see section 0). The user may need to install
Godot, the Web export templates and Node.js, and to run `wrangler login`
once. If any of that is missing, report it as **ACTION NEEDED**.

1. Export: `godot --headless --export-release "Web" export/index.html`
   (adapt path/preset name to the project; record the working command in
   `README.md`).
2. Check file sizes in `export/`; flag anything above 20 MiB.
3. Deploy: `wrangler pages deploy export --project-name <name>`
   (verify current Cloudflare/Wrangler docs; the recommended command can change).
4. Open the deployed URL in a headless browser using Playwright MCP or Chrome
   DevTools MCP. Read console errors and failed network requests. Take a
   screenshot to confirm the canvas renders.
5. Fix errors, re-export, re-deploy. Repeat until clean.
6. Report: what changed, what is still broken, what the user should play-test.

Known pitfalls to check first:
- `SharedArrayBuffer is not defined` → threads enabled without COOP/COEP
  headers; disable thread support or add `_headers`.
- Black screen → renderer not Compatibility, or WebGL unavailable in the
  headless browser (try software-rendering flags).
- 404 on `.pck` or `.wasm` → wrong output path or file over host size limit.
- Audio does not start → browsers require a user click before audio; use a
  start screen.

The agent cannot judge fun. After each milestone, ask the user to play-test
and wait for feedback.

## 15. Out of scope (do not build unless asked)

Voice chat, accounts/login, leaderboards, in-app purchases, mobile controls,
more than one map, more than four players, procedural levels.

## 16. Open questions for the user

- ~~Exact name of the Cloudflare project and whether a custom domain is wanted.~~
  Answered: classic Pages project `berghittn` at https://berghittn.pages.dev, no
  `workers.dev` URL. Co-op relay must be reachable through this domain.
- ~~Preferred language for the default UI (German or English).~~ Answered: English
  is the default; German stays available via `strings_de.tres`.
- Whether co-op should use a lobby with room codes or direct invite links.
