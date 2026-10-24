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
| `stube` | Gaststube (main room) | yes | – | Spawn point, first wall-buy, fireplace; two-storey hall with gallery, Erker and balcony |
| `kueche` | Küche | no | 500 | Kitchen with a Speis (pantry); Schnaps shrine (perk machine) |
| `lager` | Matratzenlager | no | 1250 | Upstairs dorm over the Küche, door on the Stube gallery and the Küchenstiege down into the Küche; no windows enemies can climb (they come up the stairs); Munitionskiste |
| `terrasse` | Terrasse | no | 750 | Big open terrace, deck and beer garden on one level, long sight lines; the balcony and its Außenstiege belong to it |
| `skiraum` | Skiraum | no | 1000 | Boot corridor behind a partition, good chokepoint, wall-buy |
| `schuppen` | Holzschuppen | no | 1250 | Woodshed, the mystery chest spawns here at fixed spot |
| `seilbahn` | Seilbahn-Station | no | 1500 | Cable car station, the alphorn weapon location in later waves |

Layout (user request, 2026-10-16, before M5): rooms are bigger than the Stube's original 14x10 and
not plain boxes. The Stube is a two-storey hall (7 m) with a gallery along two walls reached by stairs,
an Erker (bay) with the Herrgottswinkel, and a balcony over the Terrasse off the gallery. The Küche
has a pantry, the Skiraum a boot corridor behind a partition (the chokepoint), the Seilbahn-Station a
raised boarding platform with the gondola alongside (it leaves through a big portal in the east wall
under the cable, play-test 2026-10-17; barred for players, too high for enemies), the Holzschuppen a hay loft up a ramp, and the
Terrasse a deck along the hut that runs out over a full-width gentle ramp onto a big, open beer
garden at the level of the alm (play-test 2026-10-17: the sunken garden, down and up again, looked
odd and was crowded), fenced with four 3.5 m gates enemies come in by, with few objects in it. Every change of
level is a ramp (stairs are a ramp with steps on top) with curbs, since enemies cannot climb steps.

Layout pass (play-test 2026-10-17, issue #53, plan approved by the user the same day): every room
has at least two ways in and out, and the doors make four loops instead of one ring.
- Doors are 2.6 m double doors (2.0 m on the balcony and at the top of the Küchenstiege, 2.4 m
  between Terrasse and Schuppen). Costs did not change.
- Stube - Seilbahn: a door in the Stube's east wall, south of the fireplace, onto the Seilbahn's
  west platform ramp. The Seilbahn (1500) can be opened straight from the Stube, and its spawns are
  active from wave 1 (user: OK, cost stays 1500). The Kuhglocke wall-buy sits just south of it.
- Küchenstiege: a 2 m stair along the Küche's south wall up to a landing in the Lager, open to the
  Küche on its side (handrail) and walled in from the Lager (play-test #64, 2026-10-17): full walls
  along its long side and its lower end, and the Lager - Küche door (1.9 m) at the top on the left
  as you climb, off the landing. It looks like a stair (20 steps); underneath it is a ramp. Indoor loop:
  Stube, stairs, gallery, Lager, Küchenstiege, Küche, Stube. The Munitionskiste stays in the Lager
  (user decision); the middle bunks were shortened to keep the way to the landing wide.
- Außenstiege: an outside stair from the west end of the balcony down into the beer garden. The
  balcony door on the gallery is a second Stube - Terrasse door, so enemies from the garden can
  come up to the gallery.
- Tor Ost: a fourth garden gate in the east fence, south of the Schuppen.
- Skiraum: the openings into the boot corridor are 3 m wide; the corridor stays (user decision).
- Holzschuppen: the hay loft has no rail, so players can jump down and see the whole Schuppen
  (user request with the approval).

Every room has a purpose (user request, 2026-10-17), something worth going there for:

| Zone | Purpose |
|---|---|
| `stube` | Start, Jagdflinte wall-buy, later the Kuhglocke wall-buy |
| `kueche` | Schnaps shrine (perks) and the Brettljause in the Speis (stats), section 9; later the Schmarrnpfanne wall-buy |
| `lager` | **Munitionskiste** (1000): refills the reserve of every carried gun at once; the only refill for chest guns. The safe-ish room: no climbable windows |
| `terrasse` | Long sight lines over the open beer garden, the Repetierer wall-buy (1000) on the hut wall of the deck, and **die Resi**, the lost Almkuh (section 8a) who turns up in the garden. The Schneekanone trap was cut after play-testing (2026-10-17, "unfun and useless"); buyable traps or obstacles stay an idea for later |
| `skiraum` | Chokepoint, Stutzen wall-buy |
| `schuppen` | Hüttentruhe (mystery chest), later the Kuhfladen-Mine wall-buy |
| `seilbahn` | Handböller wall-buy, and from wave 10 the Alphorn wall-buy (announced when it appears). The gondola portal stays barred: every neighbour is already a door away, so a way out there would only be a new entrance (2026-10-17) |

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
effects, see section 6a), `secondary` (what right click does, see the rules below).

| Id | Name | Type | Damage | Fire rate (shots/s) | Mag / Reserve | Cost |
|---|---|---|---|---|---|---|
| `pistole` | Dienstpistole | semi-auto pistol | 25 | up to 10 (as fast as you click) | 8 / 64 | start weapon |
| `jagdflinte` | Jagdflinte | double-barrel shotgun | 20 x 8 pellets | 3.3 (the recoil settles in 0.3 s) | 2 / 24 | 500 (wall-buy, Stube) |
| `stutzen` | Stutzen | bolt-action rifle | 120 | 1.33 (the bolt is worked in 0.75 s) | 5 / 40 | 750 (wall-buy, Skiraum) |
| `repetierer` | Repetierer | lever/repeater rifle | 90 (two shots for small enemies, play-test 2026-10-17) | 3 | 10 / 80 | 1000 (wall-buy, Terrasse; it was chest only until the chest went specials-only, #52) |
| `schaufel` | Schneeschaufel | melee | 70 | 1.2 | – | 0 (always equipped) |
| `alphorn` | Alphorn | wonder weapon | 200 area | 0.5 | 6 / 18 | chest (rare); from wave 10 also 4000 at the Seilbahn wall (user decision, 2026-10-17) |
| `knoedelwerfer` | Knödelwerfer | wonder weapon | 180 area | 1.0 | 12 / 36 | chest only, rare |
| `rodelkanone` | Rodelkanone | wonder weapon | 300 line | 0.4 | 4 / 12 | chest only, rare |
| `brennkessel` | Brennkessel-Werfer | wonder weapon | 15 per tick | 8 ticks/s | 100 fuel / 200 | chest only, rare |
| `harmonika` | Steirische Harmonika | wonder weapon | 20/s while dancing | 0.3 | 4 / 12 | chest only, rare |
| `handboeller` | Handböller | hand mortar | 150 area | 0.7 | 1 / 10 | 1500 (wall-buy, Seilbahn) |
| `schmarrnpfanne` | Schmarrnpfanne | melee | 90 | 1.0 | – | 400 (wall-buy, Küche) |
| `goassl` | Goaßl | melee (whip) | 40 | 1.5 | – | chest only |
| `mistgabel` | Mistgabel | melee (long reach) | 100 | 1.0 | – | chest only |
| `krampusrute` | Krampus-Rute | melee | 150 | 1.4 | – | dropped by the Krampus boss (where he falls, E to take) |

Rules:
- Ammo refill from wall-buys costs half the weapon price.
- Magazine weapons with a chamber hold magazine + 1 (user rule, 2026-10-16): reloading with a
  round still chambered loads mag + 1, reloading from empty loads mag (the rack chambers one
  from the new mag). Weapons start fully loaded and chambered. Guns without a chamber
  (`chamber_time` 0) stay at mag size.
- The Repetierer's tube is loaded a round at a time through the gate (user request, 2026-10-24):
  the reload takes 0.5 s to bring the gun up and back plus 0.22 s for each round missing (three
  after two shots: 1.16 s; from empty ten and the lever worked: 3.05 s). Each round counts the
  moment it is in, so a reload cut short (a swing, a switch) keeps what went in.
- **Right click = the weapon's secondary mode** (user decision, 2026-10-16). Every weapon gets
  one that suits it, chosen per weapon in `WeaponData.secondary`; not every gun just aims.
  Every new weapon, including the wonder weapons and melee weapons of section 6a, must get its own
  fitting secondary mode when it is added.
  - `pistole`: aim down the sights (hold): slight zoom, much tighter spread, slower walking,
    no sprinting, weapon bob mostly gone, mouse sensitivity lowered (user request, 2026-10-16;
    applies to every aimed mode, the scope too), muzzle flash shrunk so it does not cover the target.
  - `stutzen`: hunting scope (Zielfernrohr, hold): strong zoom, scope overlay with crosshair,
    almost no spread, a slow sway of the aim while scoped.
  - `jagdflinte`: fire both barrels at once (press): all loaded shells in one blast, recoil per
    shell; the gun is then empty.
  - `repetierer`: the Querschläger (press, 3 rounds; user request 2026-10-24, replacing fanning the
    lever, which was only faster, wilder shooting): one shot that glances off whatever it hits, a
    body or a wall, on to the nearest enemy it can see within 8 m that it has not hit yet, and on,
    less with every body: 90, 75, 60, 55, 50 (user request 2026-10-24; a head hit first counts
    double, the hops strike bodies). It stops after 5 bodies or once it has flown 12 m from body to
    body: a bunch close together takes all five, enemies 6 m
    apart three. Needs 3 rounds in the gun. Then 2 s until the next shot (play-test 2026-10-24: not to be
    spammed): the gun is turned to look at, the barrel smoking, the lever jams half open and is
    rattled loose, then thrown and shut; the ready ring at the crosshair fills meanwhile. A bright streak shows the path and the bullet whines off ("pjiuu").
  - `alphorn`: the Echo (press): the bell swings up to the sky and the note comes down all around
    the player, 200 damage within 6 m in every direction and a harder shove; uses two notes. The
    panic button when surrounded.
  - `knoedelwerfer`: the Knödeltris (press): three smaller dumplings in a fan (9° apart) for three
    rounds, each bursting for 100 within 2 m with a smaller pile; covers a doorway or a crowd's width.
  - `handboeller`: the Doppelladung (press): a second measure of powder poured in, the loaded round
    plus one from the reserve; the shell flies 1.5 times as fast and flatter, bursts for 260 within
    4.5 m, and the kick shoves the shooter back.
  - `harmonika`: the Tanzboden (press, 2 rounds; play-test 2026-10-18, replacing the held Landler,
    which felt useless): a round wooden dance floor 5 m across is laid where the player aims (up to
    15 m away, on the floor below the aim). For 10 s the Landler plays from it and everyone on it
    dances like at a polka (walls shield; newcomers too, and a second after stepping off), taking 20
    a second and twice the damage from other hits; bosses take the damage only. Up to three lie at
    once. Turns a doorway or a window into a trap while the player fights elsewhere.
  - `brennkessel`: the Brennlacke (press): a gulp of 20 fuel squirted in an arc; where it comes down
    it spreads into a burning puddle 4 m across that sets alight whoever walks through it for 6 s
    (10 a second, 3 s after leaving it). Covers a doorway or a window while the flame works elsewhere.
  - `rodelkanone`: the Kehre (press): a sled shot with a double charge (two rounds) that banks off
    walls up to three times instead of breaking and runs 25 m; for rooms and corridors where a
    straight 15 m never fits. After each bank it turns 60 % of the way towards the nearest enemy
    it can see on its side of the wall (play-test 2026-10-19).
  - Melee weapons live on V, not in hand, so their mode is **holding V past the blow** (M5): tap V
    swings as before, keep it held and the weapon stays up.
  - `goassl`: the lash (hold V): the whip wraps round the first body along the aim within 7 m and
    drags it to the player (5 m/s, stopping 1.6 m short) for as long as V is held, 3 s at most,
    dazed all the while; let go, it stays stunned for 1.5 s. Pulls a Perchte out of a crowd or one
    off a window. Bosses are too heavy; with nothing in reach the whip just drops.
  - `mistgabel`: Aufgabeln (hold V): the first body the thrust skewered is lifted up on the fork and
    carried over the player's head (3 s at most; the player walks slowly); let go and it is hurled
    where the player looks (11 m/s, a little up). Where it comes down it bowls over everything within
    2 m, itself included: 80 and thrown back, "PLUMPS!". Bosses are too heavy to lift.
  - `krampusrute`: the Larve (hold V): the rod raised high, rattling; every enemy within 8 m and 35°
    either side of the aim (walls shield) flees for as long as it is held and a second after. Clears
    a doorway to walk through, or turns a crowd round while a teammate shoots them in the back.
  - `schmarrnpfanne`: the pan as a shield (hold V): hits from the front (60° each side) are caught and
    the attacker is bonked back; you walk at 60 % and cannot shoot until you let go. Hits from the side
    or behind still land, so you keep turning to face them.
- Ready ring (play-test 2026-10-17): a ring around the crosshair fills while the gun reloads (amber)
  and, for the Alphorn and the Rodelkanone (play-test 2026-10-17), between shots (white), and pulses
  once when the gun is ready again.
- An emptied gun reloads by itself as soon as its last shot has cycled (play-test 2026-10-17: a
  click on the empty gun during the cycle could be lost, so R was needed). Guns that
  work an action after a shot fire again the moment the animation ends (play-test: the Stutzen's bolt
  and the Jagdflinte's recoil had finished well before the gun could fire; fire rates set to match).
- Semi-auto guns fire once per click, as fast as the player clicks, up to `fire_rate` (user request,
  2026-10-17); holding the button does not auto-fire. A click during the cycle is remembered for a
  moment and fires as soon as the gun is ready, so fast clicking is never swallowed.
- Penetration (user request, 2026-10-17): big calibres go through bodies. `penetration` is how many
  enemies behind the first one a shot can still hit; each body passed costs part of the damage
  (`penetration_falloff`, the share left). Stutzen: 3 more at 0.75 (100 %, 75 %, 56 %, 42 %; user
  request 2026-10-23), Repetierer: 1 more at 0.5, pistol: none. A shot into a head behind still
  counts the headshot multiplier. Jagdflinte pellets go through 2 more, but only within 6 m of the muzzle
  (`penetration_range`, play-test 2026-10-17): up close a blast hits the whole front of a crowd.
- Bloom (user request, 2026-10-16): each shot widens the spread a little (`bloom_per_shot`, capped
  at `bloom_max`), and it settles back; the crosshair arms move apart by the same amount, so it stays
  honest about where shots can go. Kept small: rapid fire loosens the aim, it does not ruin it.
  Exception, the pistol (play-test 2026-10-17): spam-clicking must cost accuracy, so each shot adds
  1.5° (up to 6°) and it settles at 4°/s. Clicking about twice a second stays precise, ten a
  second sprays.
- Slots: 2 gun slots (wonder weapons and the hand mortar use a gun slot); a third with **die Kraxn**
  (#95, user request 2026-10-24): the Alm farmers' wooden carrying frame on a hook in the
  Matratzenlager, 2500, bought once, any weapon in the third slot (key 3), never lost (not when
  going down, not when bleeding out). In co-op the others see it on the hiker's back with the guns
  not in hand strapped to it. Banner: "Jetzt bist a richtiger Tragl!".
  1 melee slot (starts with the shovel, can be replaced), 1 equipment slot
  (stackable throwables, see section 6a).
- **Hüttentruhe (mystery chest):** costs 1500, gives a random special weapon from the
  chest pool, weighted (each weight 1). Fixed location in `schuppen`. Animation: lid opens, weapon
  floats for 4 s, player must take it.
  Play-test 2026-10-17 (#52): the chest gave the wall-buy guns too often (5 in 6 spins), so it now
  holds only special weapons and costs 1500 instead of 950 (to be tested). The Repetierer, chest
  only until then, got a wall-buy on the Terrasse.
  Details (M5): the pool lives in `data/chest_pool.tres`; it never offers a gun the buyer already
  carries. The guns cycle for 2.5 s, slowing down, before one settles. Taking it fills a free slot or
  swaps out the gun in hand; not taken in 4 s, it sinks back and the points are gone.
  The pool is each special weapon as it is built (Alphorn, Knödelwerfer, Rodelkanone, ...).
- **Alphorn:** fires a cone-shaped sound wave that damages and knocks back
  all enemies in a 12 m cone; funny low horn sound, screen shake.
  Details (M5): the cone is 30° each side of the aim; 200 damage to every body in it with a clear
  line from the horn (walls stop it, no headshots), and survivors are thrown back (16 m/s at the bell,
  half at 12 m; heavy enemies by the root of their flinch, so a Knappe slides about a metre and the
  Krampus barely moves). Pale rings of sound roll out along the cone. 6 notes, 18 spare; the reload is
  catching your breath (2.5 s). In the chest at weight 1.

### 6a. Absurd weapons: behaviors and equipment

Each special weapon is a `WeaponData` resource plus a small behavior script
(`behavior` field). Build them one at a time, each in its own script, so a
broken weapon never blocks the others. Names are original parodies of
Alpine folk culture.

**Wonder weapons (chest only)**

- **Knödelwerfer:** launches giant bread dumplings (Semmelknödel) in a ball
  arc. On impact: 3 m explosion for 180 damage and a sticky pile that slows
  enemies by 50% for 4 s. Comic "splat" sound.
  Details (M5): 20 m/s launch under normal gravity; it bursts on the first wall, floor or body (in
  the air after 4 s), walls shield what is behind them, survivors are shoved a little. The pile is
  2 m in radius and lies 6 s; whoever wades in moves at half speed while in it and 4 s
  after. A wet splat where it bursts (M6 sound). The next dumpling slides into the muzzle
  as the gun is ready again (1 s; the pot's lid hops as it drops through, it plops into the muzzle, and
  the ready ring at the crosshair shows it, play-test 2026-10-18). 12 / 36, reload 3 s (the lid of the Knödeltopf on top opens and
  three drop in). In the chest at weight 1. Dumplings and piles are pooled.
- **Rodelkanone:** fires a wooden sled that slides along the ground in a
  straight line for 15 m, hitting every enemy on the path for 300 damage with
  knockback. The sled then disappears with a crash.
  Details (M5): the sled leaves the muzzle at 14 m/s where the player aims and flies in an arc
  (heavy: 18 m/s² gravity, so level it comes down about 6 m out, aimed up about 12 m); it strikes
  bodies it flies through, breaks on a wall, drops off a ceiling. Where it comes down on a floor it
  runs its 15 m along the ground at 14 m/s, over steps up to 0.4 m,
  up and down slopes and off edges (lost after a 4 m drop). Everything in its lane (0.7 m around its
  middle at body height) is struck once and thrown forward and sideways out of the lane; the first
  wall breaks it early (a louder crash and flying planks), nothing behind a wall is touched. A wooden
  thud and clatter on each hit (M6). The next sled slides forward in the open chute as the
  gun is ready again (2.5 s). 4 / 12, reload 3.5 s (the chute tips up and two sleds drop in). In the
  chest at weight 1. Sleds are pooled.
- **Brennkessel-Werfer:** a copper schnaps still strapped to the back with a
  hose. Continuous flame cone, 8 m range, 15 damage per tick plus burning
  (10 damage/s for 3 s). Consumes fuel while the trigger is held.
  Details (M5): 8 ticks a second while held, one unit of fuel each (100 / 200, about 12 s of
  flame); the cone is narrow (12° each side of the aim), walls shield, and the stream is drawn only
  as far as the first wall. Burning lasts 3 s after a body last stood in the flame, and bosses burn
  too. Hit points come once a second per body, not once a tick (play-test economy). Burning bodies
  carry flames. The gauge on the lance shows the fuel left; the reload is four strokes of the pump on
  the still (3.5 s) while the needle climbs back. In the chest at weight 1.
- **Steirische Harmonika:** an accordion. Firing plays a short polka that
  makes all enemies within 8 m "dance": they stop attacking for 4 s, take
  20 damage per second, and take double damage from other weapons while
  dancing. Bosses are immune to the dance but take the damage.
  Details (M5): walls shield, all around the player (not a cone). A dancer hops and spins on the
  spot; a swing it had started is dropped. The 20 a second is paid as one hit per second (a flash and
  the usual hit points to the player who played), and is not doubled itself. A fiery 4-bar polka
  plays on the musette accordion (M6) while golden notes rise all around (3D shapes, user decision
  2026-10-17: quarters, eighths, sixteenths, beamed pairs and hollow half notes, mixed), with a ring
  rolling out to the 8 m edge; the Tanzboden plays the Landler, a slow tune in three. The bellows pump through the polka and close as the next can start (3.3 s, with the white
  ready ring). 4 / 12 (play-test 2026-10-19; was 3 / 9), reload 3 s (the air button: bellows pulled wide open and pressed shut). In the
  chest at weight 1.

**Regular absurd weapons**

- **Handböller:** a hand-held black-powder mortar like the ones used at
  Schützen celebrations. One loud shot, 3 m explosion, very long reload.
  Details (M5): 1500 at the Seilbahn's north wall (ammo 750). The iron shell is lobbed at 22 m/s and
  bursts like the Böllerschuss (the same smoke, sparks and shock ring) for 150 within 3 m, shoving
  survivors, with the Böller bang (M6). 1 / 10, a 4.5 s reload: muzzle up, the ball dropped in, two
  strokes of the ramrod. No self-damage.
- **Schmarrnpfanne:** a heavy frying pan. Satisfying "bonk" sound, small
  knockback, fastest strong melee.
  Details (M5): bought at the Küche east wall for 400; it replaces the shovel in the melee slot. 90 per
  blow, a shove of 4 m/s (heavy enemies less), and a ringing cartoon "bonk" where it lands (M6). A
  Kaiserschmarrn is still in it.
- **Goaßl:** a long whip (Goaßlschnalzen). Cracks loudly, hits in a short
  cone, and stuns enemies for 1.5 s.
  Details (M5): on V in place of the shovel (chest only, weight 1; the chest hands a melee weapon
  into the melee slot, never in place of a gun). 40 to everything within 3.5 m and 30° either side of
  the aim (walls shield), 1.5 crack-blows a second; stunned enemies stand dazed, swaying, and cannot
  attack; bosses take the blow but are not stunned. The crack sounds at the tip, hit or miss (M6).
- **Mistgabel:** pitchfork with long reach; pierces and hits two enemies in
  a line.
  Details (M5): on V in place of the shovel (chest only, weight 1). A thrust, not a swing: 3 m
  straight along the aim (10° either side, measured on the ground), through the first two bodies,
  100 each and a small push; once a second, with a stab and a ring of the tines (M6).
- **Krampus-Rute:** birch rod dropped by the Krampus boss. Hits cause enemies
  in a small radius to flee for 3 s.
  Details (M5): when the Krampus falls he leaves the Rute on the floor there, turning over a red glow,
  announced ("Da Krampus hat sei Rute verlorn!"); E takes it onto V in place of the shovel (or the
  melee weapon carried); it stays until someone takes it. Swung sideways like the shovel (2 m, the
  shovel's arc), 150 a blow, 1.4 a second, a swish and a slap of twigs; every body it strikes, and every enemy within
  2.5 m of one, runs away from the player for 3 s and attacks nobody. Bosses are not scared.

**Equipment (1 slot, stackable, thrown or placed with G or the middle mouse button; one kind at a
time, shown on the HUD above the gun name)**

| Id | Name | Effect | Cost | Max carried | Where |
|---|---|---|---|---|---|
| `kuhglocke` | Kuhglocke | Thrown decoy cowbell; rings for 10 s and attracts all enemies within 20 m | 300 | 2 | wall-buy, Stube |

Kuhglocke details (M5): thrown in an arc where the player looks (gallery and garden reachable), it
bounces off walls and rings once it lies still. Enemies within 20 m walk to it and stand round it,
leaving players alone, also those already inside the hut; the Krampus ignores it (bosses are immune
to crowd control). A ring pulses on the floor and the bell clanks as it swings (M6). The wall-buy
on the Stube east wall fills the slot to two for 300 and warns when it would replace an Eisstock.
Equipment keeps G as its only action, no second mode.

Kuhfladen details (M5): placed on the floor a step ahead (at the feet if a wall is in the way). Each
enemy that steps in it, once, takes 40 and moves at 40 % for 5 s ("PFLATSCH!"); bosses take the
damage but shrug off slows, from the Knödel pile too (immune to crowd control). After four enemies,
or two minutes, it is trodden flat; at most six lie about, placing another removes the oldest. Best
in a doorway: in the open, enemies' paths often pass beside it. The wall-buy on the Schuppen west
wall fills the slot to three for 250.
| `kuhfladen` | Kuhfladen-Mine | Placed on the floor; enemies stepping in it are slowed 60% for 5 s and take 40 damage | 250 | 3 | wall-buy, Schuppen |
| `eisstock` | Eisstock | Thrown low, slides along the floor like a curling stone, bounces off walls up to 3 times and damages every enemy it slides through (5000, a boss 1500 and a shove; 16 m/s, slows down over about 30 m). Deliberately overpowered (user request, 2026-10-17) | – | 2 | only as an event reward (section 8a): no wall-buy, no refill |

Balance notes: wonder weapons must feel exciting but not make the game trivial.
Tune damage numbers by playtesting, and keep every number in the data
resources so changes never require code edits.

## 7. Enemies

All enemies share a base `Enemy` scene and are configured by `EnemyData`
resources. Navigation uses `NavigationAgent3D` with a baked navmesh per zone.
Enemy AI is simple: move to nearest player; if a barricade is in the way,
attack it; attack in melee range. An enemy that stops making headway while chasing (pressed into a
door edge or a corner, or blocked by other bodies) sidesteps and repaths after 0.8 s, and an enemy
never rides on top of another one (play-test bug, 2026-10-17).

| Id | Name | HP formula | Speed | Damage | Notes |
|---|---|---|---|---|---|
| `wanderer` | Wanderer (hiker zombie) | 100 + 15·wave | 2.5 m/s | 20 | Basic enemy, matching hiking outfit |
| `tourist` | Tourist | 60 + 10·wave | 5.0 m/s | 15 | Fast runner, appears from wave 3, wears a camera |
| `knappe` | Bergknappe (miner) | 400 + 50·wave | 1.8 m/s | 45 | Tank, appears from wave 6 |
| `perchte` | Perchte | 250 + 30·wave | 4.0 m/s | 30 | Wooden-mask monster, appears from wave 8, short lunge attack |
| `krampus` | Krampus (boss) | 3000 + 500·(wave/5) | 3.0 m/s | 60 | Boss wave every 5th wave starting wave 5, spawns with 6 wanderers |

Boss waves (M5): from wave 5, every 5th wave is the Krampus plus 6 wanderers instead of the usual
mix, announced with "Da Krampus kummt!" and a boss health bar. The Perchte lunge: from up to 4.5 m
with a clear line it crouches (0.35 s, the moment to side-step) and leaps, striking on contact; then
3 s until the next one. Heavy enemies (Knappe, Krampus) are drawn bigger and barely flinch.
Enemy mix weights (`wave_table.tres`): wanderer 6, tourist 2 (from wave 3), knappe 0.8 (from 6),
perchte 1.2 (from 8).

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
- Between waves: 30 s break (play-test 2026-10-17, was 10 s), a message "Welle N" appears, barricades can be repaired.
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

## 8a. Events (user request, 2026-10-17)

Funny, typically Austrian things that happen now and then between and during waves. Each one is
announced to every player with a banner and stays findable from anywhere on the map: a tall light
column over it, an arrow at the screen edge pointing to it, and a label that shows through walls.
Their sounds came with M6 part 2 (Resi's bell and moos, the rolling barrel and the tapping, the
Murmeltier's scream, the tourist's camera, a flugelhorn call with each banner); the Murmeltier's
scream is our own synthesised take on the meme, not the clip itself.

**Die Resi (main event, Terrasse).** "Die Resi hat si verlaufen!" A lost Almkuh with a flower wreath
and a huge bell wanders into the beer garden. She only comes while the Terrasse is open, every 3 to 5
waves from wave 3 (never on a boss wave: then she comes the wave after), arrives 12 s into the wave
and stays 45 s.
- Hold E next to her to milk her: fresh Almmilch heals fully and gives a free helping from the
  Brettljause (one not yet at five).
- 5 s after a player first came within 10 m of her, her bell draws every enemy within 20 m to her,
  so getting the milk is a fight. Until then the enemies leave her alone, so she is never chased off
  before anyone got to her (play-test #70; the 5 s grace #94).
- Enemies that reach her strike her, each once every 1.5 s; after 3 blows (a bar over her back) she
  bolts off mooing and the milk is gone (#94: before, the first touch did it, so she was unwinnable).

**Random events.** At most one per wave, a 30 % chance each wave from wave 2, 8 to 35 s into it (not
every wave, never on a boss wave or a wave Resi comes); the same one does not come twice in a row
when another one could come.
- **"Bierfassl kert onzapft!"** A beer barrel breaks loose up on the alm to the north-west and rolls
  down the slope, in at the beer garden's west gate and across the garden (8 m/s), bouncing,
  flattening every enemy in its way (a boss takes 500 and is shoved). It stops at the first wall,
  fence or table, or when a player steps in its way. Tap it (hold E for 2 s) for Freibier: a random
  Schnaps the tapper does not own yet, for free (2000 points if they have them all). Only while the
  Terrasse is open; an untapped barrel is gone after 60 s.
- **The Murmeltier.** A marmot pops out of a hole in the floor 6 to 22 m from a player, anywhere
  players can walk (indoors too, never beyond a fence or outside a shut zone), stands up with its
  arms raised and screams our own take on the meme scream (synthesised in M6), ducks away,
  and pops up again 2.5 to 7 m away, four times in all (about 13 s). Hit it while it is up (shot or
  shovel) for 500 points and a full refill of the gun in hand (magazine and reserve).
- **"Deitscha Tourist"** A lost German tourist (sunburnt, souvenir Tirolerhut, socks in sandals,
  fanny pack, a big map) gets off the gondola at the Seilbahn and heads for the Stube the long way
  round the door ring, through the Schuppen and over the Terrasse (play-test #71), or the direct
  way while one of those is shut. Only while the Seilbahn is open and the way to the Stube through
  open zones. He walks (1.8 m/s) only while a
  player is within 10 m ("Wo geht es denn hier zur Hütte?"), never climbs through windows, and
  enemies go for him like for a player (300 health, shown over his head; players cannot hurt him).
  Escort him to the Stube alive and he hands the nearest player two Eisstöcke, the only ones in
  the game ("Das ist ja total urig hier!"). He gives up after 3 minutes.

## 9. Perks: the Schnaps shrine (Küche) and the Brettljause (Speis)

One shrine in the kitchen sells perks, each once per life. Costs in points. Every Schnaps gives one
signature effect you notice in a fight, not a plain stat (play-test, 2026-10-17); plain stats come
from the Brettljause below. Tuning numbers are `PERK_*` in constants.gd.

| Schnaps | Perk | Cost | Effect |
|---|---|---|---|
| Jagertee | **Gmiatlichkeit** | 1500 | Stand still or crouch for 2 s: health regenerates at once (no 5 s wait) and three times as fast; a warm glow shows it. Not while two or more different enemies have hit you within 3 s (play-test 2026-10-23: standing still was near invincible at wave 42) |
| Enzian | **Sturschädl** | 2000 | Once per wave a deadly hit leaves 1 HP and 4 s of invincibility: pulsing gold screen glow, banner "Na, sicher ned!" |
| Marillenbrand | **Böllerschuss** | 2500 | Starting a reload on an empty magazine sets off a Schützen black-powder Böller at your feet: 150 + 20·wave damage within 4.5 m (half at the edge, walls block it), survivors are thrown back; 6 s to pack the next charge |
| Obstler | **Grantler** | 2500 | +5 % damage for every enemy within 5 m, up to +30 %; the tile shows the bonus |
| Zirbenschnaps | **Durchschlag** | 3000 | Every gun goes through one more enemy (on top of section 6's penetration; buckshot still only up close) |
| Jagamoasta | **56 gsunde Kräuter** | 3500 | Every kill is a herb; at 56 you are fully healed and keep +20 % max health (+20) and +20 % damage for good, kept even when you go down (a green flash; the tile counts the herbs, then shows +20 %). An investment: once paid out it is not sold again. Play-test 2026-10-17: was a 10 s double-damage rush, which felt too little for 56 kills |

Perks are lost when the player is downed (solo: irrelevant, game over).
The shrine (M5) is a painted wall cabinet with one bottle per Schnaps, cheapest on the left; the
bottle you look at is the one E buys (with several things in reach, the one looked at most directly
wins). Owned perks show as coloured tiles above the health bar with a short badge and what the perk
is doing (cooldown, bonus, herbs); a spent or idle one is greyed out.

**Brettljause** (play-test, 2026-10-17): a wooden board on a table in the Speis. Each thing on it can
be bought again and again, five helpings each, every helping costing more; the gains stay for the
whole run, even when downed.

| Jause | Per helping | First helping | Each further one |
|---|---|---|---|
| Speck | +20 max health | 750 | +750 |
| Germknedl | +10 % reload speed | 750 | +750 |
| Pinzgauer Kasnockn | +10 % weapon damage | 1000 | +1000 |

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
- Added by user request (2026-10-16): the surroundings must read as an Alm in the mountains: the
  hut on a flat pasture plateau, the slope rising to the summit behind it and dropping into a
  forested valley in front, snowy peaks showing through the storm, pitched snowy roofs, a yellow
  trail sign, the cable car line, a hay barn, a wayside cross and a crossed-rail fence. Greybox
  only; the art pass stays in M6.

**M5 — Shrine, chest, more enemies**
- Perks, Hüttentruhe, `tourist`, `knappe`, `perchte`, `krampus` boss wave.
- Events (section 8a), one at a time: die Resi first (with the event director and the map-wide
  markers), then the Bierfassl, the Murmeltier, and the Deitscha Tourist with the Eisstock (which
  brings the equipment slot).
- Special weapons from section 6a, one at a time in this order: alphorn,
  Schmarrnpfanne, Knödelwerfer, Kuhglocke, Kuhfladen-Mine, then the rest.
  Report after each one; the user may stop adding weapons at any point.
- Map layout pass from section 4 (#53): done 2026-10-17, before M6.
- Acceptance: all items purchasable, wave 10 reachable.
  Checked 2026-10-17 by `tests/m5_acceptance` (every weapon and piece of equipment has a way in, and
  every wall-buy, Schnaps, Brettljause item, the Munitionskiste and the Hüttentruhe can be walked to
  and bought, the chest handing out its whole pool) and `tests/m5_waves` (waves 1 to 10).

**M6 — Art and audio pass**
- Replace greybox with low-poly assets, lighting, snow effects, sounds,
  German/English strings, settings menu (sensitivity, volume).
- Ragdolls for dead enemies (user decision, 2026-10-17): skeletal ragdolls on the rigged M6 models,
  capped to the last few corpses (older ones keep the fall animation), colliding with the world only;
  check the browser frame rate with a crowd (Jolt if Godot Physics is too slow).
- Acceptance: file sizes within budget, 60 FPS target met.
- Done in parts, one PR each (2026-10-17), reporting after each:
  1. Look and settings: grade (cool shadows) and vignette, fog and ambient light that change between
     the storm outside and the warm hut inside, a frost that creeps in from the screen edges
     outdoors and thaws indoors, snowfall that stays out from under roofs, settings menu
     (sensitivity, aiming sensitivity, invert Y, volume per bus, language, render resolution), saved
     in the browser. No film grain (play-test 2026-10-17).
  2. Audio: every sound and the brass band tune, self-made (synthesised), OGG. Built from oscillators,
     noise and filters by `tools/audio` (numpy, scipy, soundfile), mono OGG Vorbis, about 4.7 MB in
     all. The band plays an original polka ("Da Berghittn-Polka", B-flat) as alpine Volksmusik off an
     old gramophone (play-test 2026-10-18: Steirische Harmonika, flugelhorn and clarinet in thirds,
     guitar off-beats and tuba, not a circus brass band): the whole tune under the title screen; at the
     start of each wave the hut bell rings and the band plays only its first eight bars, one tempo
     tier faster each wave (100 bpm in wave 1 up to 172 bpm from wave 8, then 2 % higher and faster
     every wave up to +20 %); no music for the rest of the wave or the break; the record winding down
     at game over. The music sits 25 % lower than at first. The gunshots are real recordings (CC0,
     ASSETS.md), and the Handböller's launch and blast are a recorded shotgun pitched far down under a
     synthesised boom; the Murmeltier screams like a man and is heard across the whole map. The storm wind is muffled and quieter under a roof, the timbers creak
     indoors and the fire crackles. Every gun, reload, swing and hit has its sound, as do enemies
     (groans per type, attack grunts, death cries, boards ripped out and climbing through), footsteps
     (boards indoors, snow outdoors), purchases (till or a short "no"), doors, the Hüttentruhe (a
     music-box note per weapon it flips to), the Schnaps and the Jause, the equipment and the events.
     The comic hit words ("BONK!", "BIMM!", "AAAAAAH!" ...) are gone now that the sounds are in.
  3. Textures: low-resolution photo textures (CC0, user approved 2026-10-17: ambientCG, Poly Haven and
     other CC0 sources). All 15 come from Poly Haven, 256x256, made by `tools/textures`: plank walls,
     worn floorboards, dark wood for beams and furniture, weathered barricade boards, a fieldstone
     Kachelofen, terracotta tiles in the Küche, concrete in the Seilbahn, rusty steel, painted
     planks for doors and skis, wool blankets and linen mattresses in the Lager, hay, snow, rock and
     needle-dark pines; the terrain picks snow or rock by slope. Each keeps the average colour of
     the greybox it replaced, so the lighting and grade of part 1 still fit. 0.82 MiB in all.
  4. Low-poly models for props, enemies and weapons, and the ragdolls. Itself split into three PRs
     (2026-10-18), each play-tested: 4a the enemies and ragdolls, 4b the weapons, 4c the props.
     4a: the five enemies are self-made low-poly models (`tools/models`, no external assets), each on
     a 15-bone skeleton with the greybox palette and silhouette (the Wanderer's felt hat and rucksack,
     the tourist's socks in sandals and camera, the Knappe's helmet lamp and pick, the Perchte's carved
     mask and cowbells, the Krampus's horns, tongue, chains and Rute), textured with CC0 wool, leather,
     fur and skin tinted per costume; 0.2 MiB. Their limbs move in code: a walk, a two-armed (Knappe,
     Krampus: one-armed) swing, reaching in for a board, the head-first dive through a window, the
     Perchte's crouch and leap, a Schuhplattler to the Harmonika, dazed, and flailing on the Mistgabel.
     A kill turns the body into a ragdoll thrown away from the shooter, colliding with the world only;
     at most 6 are simulated at once and each freezes where it fell after 3 s (with no room, a corpse
     falls the old way).
     4b: the weapons keep their parts and animations; every greybox box is reshaped (barrels and
     handles round, stocks with a real profile, everything else chamfered) and every colour is a
     texture: walnut for wood, worn steel for metal and brass, painted wood for the rest (two CC0
     textures at 512, allowed for weapons as hero assets). The Handböller was redone after the
     play-test: its bronze barrel bedded in a short wooden stock with a band round both, a short
     handle, and a big hammer that falls on the shot and is cocked again in the reload.
     4c: the props get the same: the chest, shrine, crate, Jause, the Bierfassl, Resi and the
     Murmeltier (in fur), and the equipment are reshaped and textured; every piece of CSG furniture
     (tables, benches, stairs, posts, racks, the gondola) is drawn as chamfered meshes while its CSG
     keeps the collision and the navmesh; the Deitscha Tourist is a character model like the
     enemies; the Handböller's chalk outline shows its new shape.

**M7 — Co-op (decision gate)**
- Before coding, write `NETWORKING.md`: chosen transport, relay approach on
  Cloudflare, authority model, expected costs. The user approves first.
- Then implement lobby, 2-player sync, then 4 players.
- Acceptance: two browsers can play the same match for 10 waves.
- `NETWORKING.md` approved 2026-10-18 (PR #75): WebSocket relay in a Durable Object behind a Pages
  Function on berghittn.pages.dev, Workers Free plan only; each player owns their movement and hits,
  the host runs the world. Lobby with a 4-digit room code and an invite link, joining only in the
  lobby; each player names and dresses their hiker there (head, hats, jacket and trouser colours).
  Bled-out players come back at the start of the next wave. Done in four PRs, play-tested each:
  1 relay and lobby with the character editor, 2 two players and the core loop with downed/revive,
  3 special weapons, equipment and events, 4 four players and the acceptance.
  Part 1 (2026-10-18): the relay Worker `berghittn-relay` and the Pages Function, the lobby (name,
  5 heads, 5 hats, 8 jacket and 6 trouser colours, room code, invite link, remove, start from 2
  players), and walking the hut together as hikers with name tags; waves and events wait for part 2.
  Part 2 (2026-10-18): the host runs the waves and enemies, guests see copies moved by its snapshots;
  each player's hits go to the host, which pays the points to whoever earned them; doors, barricades
  and the Hüttentruhe are shared; enemies go for the nearest player; downed (crawling, Dienstpistole
  only, Schnaps gone, 30 s), revived by a teammate holding E for 4 s (back at half health), bled out
  until the next wave (then back with the starting guns, points, Jause and herbs kept); everyone down
  is game over and the room goes back to its lobby. The events and the special weapons' effects for
  the others wait for part 3.
  Part 3 (2026-10-18): every hiker holds a copy of their gun and a ghost of their guns replays their
  shots, swings and specials on the other screens (impacts and muzzle flash, the Alphorn's rings,
  shells, Knödel and their heaps, sleds, puddles and flames, the Tanzboden, notes, the Böllerschuss),
  harmless there; thrown equipment flies as harmless copies (a Kuhglocke still lures the host's
  enemies). Burning enemies burn on every screen; a guest's Mistgabel lifts, carries and hurls the
  host's enemy; the Krampus-Rute drop goes to whoever takes it first. The host runs the events and
  every guest sees copies of Resi, the Bierfassl, the Murmeltier and the Tourist; milking, tapping
  and catching go to the host, the reward to the player who did it, with a banner for the others.
  Part 4 (2026-10-19): four players in one match (each undressed hiker gets its own default jacket,
  name tags keep one size on screen); under the 10 KiB/s target with 4 players and 24 enemies
  (8-9 KiB/s: broadcasts sent once, packed poses and shots, still enemies left out of snapshots),
  which also keeps the relay at about 20 billed frames a second per player; two players clear waves
  1 to 10 together in the headless test, and two browsers stay in one match through 10 waves.

**M8 — Stuffed animals (cosmetics, user request 2026-10-19)**
After the milestones, the user asked for stuffed-animal cosmetics and approved all of the
suggestions, with an Edelmarder (marten) added:
- After the play-test (approved 2026-10-19) the Stirnband, Skihelm and Schildkappe were dropped as
  too boring: the lobby has no hat, the Tirolerhut, the Bommelmütz and the seven below.
- Stuffed hats in the lobby: Mankei-Haubn (a Murmeltier lying on the head), Fuchspelz (fox-fur
  hat with the fox's head and tail), Auerhahn-Huat (a felt hat with a displaying Auerhahn on top),
  Marder-Haubn (an Edelmarder curled round the head, biting its tail).
- Earned hats, kept in this browser only (accounts stay out of scope): the Raurakl-Kappl (find the
  Raurakl in the Stube and shoot it), the Perchtn-Haubn (5 Perchten fallen in our matches, all
  together), the Krampus-Hörndl (survive wave 10). The lobby shows a locked hat on our own hiker
  with what it takes; the others see it only once it is earned.
- The Stube has stuffed animals:
  - a Gamskopf on the chimney;
  - an Edelmarder stalking along a branch on the mantel;
  - a Hirsch skull with antlers over the bar, and a Mankei on the bar;
  - an Auerhahn on a shelf by the Erker;
  - up on the gallery, the Raurakl (a Wolpertinger: a hare with antlers, wings and fangs). Shot or
    struck, it spins and grumbles. This is decoration, so only the shooter's own screen shows it.
- The Trophäenwand on the Stube's east wall has six empty plaques. Every Krampus that falls, and
  the first Perchte of a match (then every 5th), goes up on the next free plaque with a banner.
  Each screen counts the kills itself, and co-op shows every kill on every screen in the same
  order, so all the walls match.

**Death screen stats (user request 2026-10-23)**
The game-over screen shows the run under the wave and points: kills, headshot kills (with their
share), the favourite weapon (the one with the most kills; a kill goes to the weapon in hand, a
melee kill to the melee weapon) and how many Schnaps went down (shrine and Freibier, again after
going down). Each screen counts only its own player's run. The personal best (furthest wave, then
more points on the same wave) is kept in this browser, solo and co-op alike; a better run says
"New personal best!", otherwise the best is shown below.

**M9 — Hüttenabend (plan, proposed 2026-10-23; all questions answered the same day)**
User request 2026-10-23: a "play again" button for easier co-op sharing, hit and kill feedback,
talking enemies, weapon upgrades and two new enemies, and room for more ideas. Five parts, one PR
each (part 4 two, part 5 three), play-tested after each one, cheapest first. The user's answers are
worked in below; nothing is built before the plan is approved.

*Part 1 — "Nomoi!": play again and sharing*
- Co-op game over: every player's end screen shows **Nomoi!** (play again) at once, next to Back to
  lobby (Q1). Each player who presses it is ready ("2 / 3 wolln nomoi"); once everyone still in the
  room is ready, the host starts the next match by itself (Net.start_match; guests already follow
  a host restart through GameState.pending_match). Whoever presses Back to lobby or leaves no
  longer counts, so the rest are not held up; with nobody else left in the room, Nomoi! is greyed
  out.
- The co-op end screen shows a **Hüttenwertung**: one row per player (name, wave, points, kills,
  headshots, favourite weapon, Schnaps) from the PlayerStats of #86, sent once at game over.
- Sharing: the room code and **Copy invite link** on the co-op end screen and in the pause menu
  during a co-op match. Joining stays lobby-only: a friend who opens the link mid-match waits in
  the lobby ("Match running, you're in the next one") and plays from the next Nomoi!.
- Solo end screen: **Play with friends** next to Try again, which creates a room and opens its
  lobby with the invite link ready.
- Built (2026-10-23, branch m9-nomoi): the wave is shown once above the Hüttenwertung (it is the
  same for everyone), rows sorted by points, ours in gold. The room becomes a lobby again at the
  moment of game over, and the host stops spawning behind the end screen. A friend whose link finds
  the match running knocks again every 4 s (NET_KNOCK_INTERVAL) until it is let in; the relay is
  unchanged. A match started by Nomoi! opens behind "Join match" for everyone (the host has no
  click to lock the pointer with). Tests: tests/death_stats, tests/net_nomoi (host, guest and a
  late friend over the local relay).

*Part 2 — Hit and kill feedback*
Today: a hit marker cross, a headshot sound and the points popups. Added:
- Kill marker: a bigger red X on a kill, gold for a headshot kill, each with its own short
  sound (a dull "thock"; a "Bumm" for the headshot, rising in pitch through a streak).
- Kill streaks in dialect, a small banner under the crosshair, each with bonus points (Q3; first
  numbers, tuned by play-test, in constants.gd): 3 kills within 4 s "Dreierlei!" +50, 5
  "Gmetzl!" +150, 8 "A echtes Kroatenjoahr!" +300; two or more with one shot or blast "Zwoa
  Detschn mid oamoi aushoin!" +50 for each enemy after the first; three headshot kills in a row "Schädlweh!" +100.
  The bonus shows in the points popup like any other gain.
- A little punch: the camera kicks on a headshot kill, the viewmodel bumps on any kill, and hit
  enemies flash briefly (only where that stays cheap in the Compatibility renderer).
- Damage numbers over the enemy, off by default, with a setting to turn them on (Q2).
- Each screen shows only its own player's feedback; co-op hits are already confirmed by the host.
- Built (2026-10-23, branch m9-feedback): KillFeedback on the Player. A chain means each kill
  within 4 s of the one before (KILL_STREAK_GAP), so 8 is reachable; each tier pays once per chain.
  "One shot or blast" is kills within 0.1 s of each other (KILL_MULTI_WINDOW). Schädlweh pays on
  every third headshot kill in a row. The kill X shows for every kill of ours, whatever did it
  (mines, flames, thrown things too). Enemies already flashed on a hit (M5), so that stays. Sounds
  kill_thock and kill_bumm are synthesised in tools/audio/sfx.py. Test: tests/m9_feedback.

*Part 3 — Talking enemies ("Gredn")*
Now and then enemies say a short dialect line: when they spot a player, while breaking a
barricade, when hit hard and when dying. The line shows as text over the head (Label3D, fading,
at most two at a time, nearest within 15 m) with a voice (Q4). At most one line per enemy every
20 s and one every ~3 s overall, and a setting turns the chatter off. In co-op the host picks the
line and sends a 1-byte line id with the actions it already relays. Lines stay in dialect in both
languages. Voices (Q4): every line is spoken by eSpeak NG (installed on the dev machine, GPL-3;
the audio it makes is ours) and run through an undead filter per enemy type, generated by a script
in tools/audio like the other sounds: the Wanderer low, slow, a bit muffled and warm, and the
Tourist quick and thin like a phone speaker, both clean (no breath hiss: in the first samples it
sounded like a mistuned radio); the Knappe very deep with a mine-shaft echo, the Perchte
whispering over a trembling growl, the Krampus very deep on a growl in a big room. The user
approved the samples 2026-10-23 (Wanderer version A "clean", Tourist made clean the same way,
Perchte and Krampus as first sampled). First draft of the lines (all our own):
- Wanderer: "Griaß di… griaß di…", "Is no weit bis zur Hüttn?", "Mei Fuaß…", "I hob an Hunger…";
  at a barricade "Mach auf, i bin's, da Hüttnwirt!"; dying "Servas…"
- Tourist: "Nur no a Foto!", "Hashtag Gipfelglück!", "Wo is des WLAN?"
- Bergknappe: "Glück auf!", "Do geht's eini!"; at a barricade "Des is a weicher Fels."
- Perchte: growls and "Hö-hö-hö!"; before the lunge "Jetzt kimmst!"
- Krampus: "Warst a brav?", "In mei Sackl mit dir!"
- Built (2026-10-24, branch m9-gredn): Gredn (scripts/enemies/gredn.gd) holds every line (enemy,
  moment, text, sound); the voices are made by tools/audio/voices.py (python tools/audio/build.py,
  skipped without eSpeak NG). The moments: seeing a player (once a life, within 15 m, no wall
  between), a groan (now and then a line instead), starting on a barricade, a hit taking at least
  30 % of its health, the Perchte's lunge, dying (last words instead of the death cry); each with
  its own chance (constants.gd, GREDN_*). A line is only picked with a player within 15 m; while it
  plays the enemy does not groan. The text is a Label3D riding over the head as long as the voice
  (at least 1.6 s), then fading; with two showing, a nearer line takes the farther one's place.
  Setting "Enemy chatter" / "Gegner reden", on by default. Play-test 2026-10-24 (more chatter): one
  line per enemy every 10 s, one overall every 1.5 to 2.5 s, and higher chances per moment. Co-op: the host sends the line index
  (CoopEnemies._said) before the enemy's death. Lines added to the draft (our own, play-test
  them): Wanderer hit "Mei Fuaß…"; Tourist at a barricade "Hallo? Is des Zimmer no frei?", hit
  "Aua! Des gibt a schlechte Bewertung!", dying "Tschüss!" (the German goodbye every Austrian winces at); Knappe hit "Geh bitte…",
  dying
  "Schicht is…"; Krampus hit "Des wirst ma büßn!", dying "I kimm wieder… nächsts Joahr!". Tests:
  tests/m9_gredn, tests/net_specials.

*Part 4 — Weapon upgrades: da Dengelstock*
Our own take on the upgrade machine of zombie modes. A Dengelstock is the little anvil an Alm
farmer hammers his scythe sharp on; here it is the Schmied's corner (anvil, hammer, glowing forge)
up in the Holzschuppen's hay loft (Q5): reached by its one ramp and with no rail, so standing at
it means being seen from the whole Schuppen. The forge needs a fire-safe corner: a stone slab and
a sheet-metal hood, so it reads as safe in a hay loft.
- It is cold until wave 5 ("Da Schmied is wieder nüchtern!", banner and light column like the
  events), then open for the rest of the match.
- 5000 points: hand over the gun in your hand. Ten seconds of hammering (sparks, clanging, you
  hold only your melee weapon), then take it back within 30 s or it is gone. One gun at a time per
  player.
- A second upgrade, **doppelt dengelt** (Q6), for 10000 on a gun already upgraded once: it doubles
  every effect of the first one (damage x4 against the base gun, bosses x2.25; magazine +100 %;
  reserve x4; a special's twist twice as strong, e.g. the Alphorn's four rings, Knödel bursting
  into six) and a brighter forged look. No third level.
- Upgraded guns: double damage (bosses x1.5), +50 % magazine, double reserve, a full refill, a
  dialect name ("Jagdflinte" -> "Wilderer-Flinte", "Stutzen" -> "Kaiserjäger-Stutzen",
  "Dienstpistole" -> "Gendarmen-Pistole", …), a forged look (dark-gold tint and engraving, a
  material variant) and a deeper shot sound. The Munitionskiste refills them as usual.
- Special weapons and melee weapons get an extra twist each on top of the numbers, for example the
  Alphorn's double ring, Knödel that burst into three, a Goaßl crack that jumps to three enemies, a
  Mistgabel throw that leaves a Kuhfladen. Each twist is designed and play-tested in its PR.
- Data: WeaponData.upgrade points to the upgraded WeaponData resource, so the numbers stay in
  data. Ghost weapons in co-op show the forged look; the death screen shows the upgraded name.
- Split into 4a (the Dengelstock, the guns and the Schaufel) and 4b (the special weapons).
- Built 4a (2026-10-24, branch m9-dengelstock): the Schmied's corner in the loft's south-east
  corner (stone slab, hearth with a rim of coals, sheet-metal hood and pipe, anvil on its stump), lit
  3.5 s into wave 5 so its banner follows the wave's; the light column stays for that wave. The
  hammer works by itself (sparks and a clang every 0.5 s). The melee weapon goes on at a grindstone
  beside the anvil (it is never in hand); meanwhile V does nothing and the guns are in hand. During
  the 10 s with a gun on the anvil, the other gun is put away too and comes up after. A weapon
  not taken in 30 s is gone: with no gun left the plain Dienstpistole comes back, and the melee
  slot gets the Schneeschaufel. Names: Gendarmen-Pistole, Wilderer-Flinte (three shells, four
  doppelt), Kaiserjäger-Stutzen, Oberförster-Repetierer (its Querschläger hops hit twice as hard),
  Schneefräsn-Schaufl; doppelt dengelt adds ", doppelt dengelt". Easter egg (user, 2026-10-24): the
  Dienstpistole doppelt dengelt is the **Golden Gun**, gold all over, and every hit kills (bosses
  too), since nobody would otherwise put 15000 into the pistol. The Schaufl's twist: a survivor of
  its blow stands dazed 1.2 s (2.4 s doppelt). The numbers are written by tools/weapons/dengel.py
  from the base .tres. Wall-buys and the Munitionskiste fill a dengelt gun's own reserve at the
  usual price; the chest and wall-buys count it as its base gun. Forged look: the steel gold on an
  engraved texture (tools/textures/engrave.py), the wood darker and redder, brighter doppelt; shots
  pitched down (x0.85, x0.75). Co-op: the host's word on the anvil (CoopWorld), the others see the
  owner's empty hands and then the forged gun. Tests: tests/m9_dengel, tests/net_specials.

- Built 4b (2026-10-24, branch m9-dengel-specials): every special weapon can be dengelt too, with the
  same numbers as the guns and one twist each (WeaponData.twist, doubled doppelt dengelt):
  Großglockner-Alphorn (one more ring 0.35 s later that hits again; doppelt two), Knödelhagel-Werfer
  (the big Knödel bursts into 3 small ones; 6), Pranger-Böller (3 small bangs round the burst; 6),
  Doppelsitzer-Kanone (a second sled beside the first; 3 sleds), Musikantenstadl-Harmonika (each
  dancer heals 5; 10), Feuerwasser-Kessel (the fire jumps 1.5 m from a burning body; 3 m),
  Donner-Goaßl (the crack jumps on to 3 more enemies within 5 m; 6), Fladen-Gabel (a hurled body
  leaves a Kuhfladen; 2), Kaiserschmarrn-Pfanne (a blocked attacker stands dazed 1.5 s; 3 s),
  Höllen-Rute (a struck body burns 3 s; 6 s). Their area and melee hits pay bosses the boss share
  too. Test: tests/m9_twists.

*Part 5 — Neue Gäste: two new enemies (user request 2026-10-23)*
Both are EnemyData resources on the shared Enemy scene, with their own model (tools/models), rig
poses, ragdoll, voice lines (eSpeak NG, as in part 3) and a co-op puppet like the others. Three
PRs: 5a the Venedigermandl, 5b the Wilderer, 5c the Bergdohlen (the user wants both, Q7).

**5a — Das Venedigermandl** (a treasure enemy, like the gold scarabs in Elden Ring). In Alpine
legend the Venedigermandl are little men from Venice who sneak into the mountains to dig for gold.
Ours is a small hunched man in a long dark coat and a pointed hat, with a pick and a fat sack of
gold, glowing faintly gold so he is easy to spot in the storm.
- He never attacks. Once a player is within 15 m he runs away from the nearest player (5.5 m/s,
  away along the navmesh, through open zones only, never through windows), darting from side to
  side as he runs, and giggles; out of reach he goes back to digging.
- The challenge is to hit him, not to wear him down (user, 2026-10-23): he is small, darts, and
  has 150 + 25·wave health, more than a Wanderer but well under a Bergknappe, so a few good hits
  kill him (wave 4: 3 Stutzen body hits or 2 headshots; wave 10: 4 or 2). Slows, stuns and the
  Goaßl work on him, lures do not.
- He talks (eSpeak NG like the others, a quick, high, giggly voice, clean without hiss): on
  appearing "Do glanzt wos!", running "Des Gold g'hert mir!", "Mamma mia!", "Ciao,
  Bergsteiger!", hit "Au, mei Gold!", vanishing "Arrivederci!", dying "Porca miseria…".
- 10 s after he first appears (a gold spark in the air and a little jingle; "Do glanzt wos!"
  banner) he vanishes in a puff of gold dust ("Arrivederci!"): kill him before that.
- Each hit knocks gold coins out of the sack (+10 as usual, plus a small coin burst); the kill
  pays 1000 + 100·wave to the killer and spills the whole sack (a big coin fountain).
- He comes now and then on his own, outside the wave count (the wave still ends without him):
  from wave 4, a 25 % chance a wave, never on a boss wave, at a spawn point in an open zone at
  least 20 m from every player. At most one at a time. All numbers in constants.gd.
- Built (2026-10-24, branch m9-venedigermandl): EnemyData.treasure on the shared Enemy;
  WaveManager.send_mandl spawns him outside the wave count (6 to 20 s into the wave; at a spawn point
  of an open zone 20 m from every player and walkable from one, or else such a navmesh spot; none
  while only the Stube is open, as nothing there is 20 m off). Running away he picks, every 0.6 s,
  the spot 7 m off (straight away or up to 110° to the side) that is farthest from the players and
  walkable without a window or player blocker, and darts hard left and right about once a second.
  Model 0.72 of a man (hat, white beard, pick, a sack glowing at the seams), a gold OmniLight and a
  map marker; the dig is a new rig action. Hits knock coins from the sack, the kill spills it in a
  fountain, he vanishes in a puff of gold dust (MandlGold). His Italian ("Mamma mia!",
  "Arrivederci!", "Porca miseria…") is spoken by eSpeak's Italian voice; "Ciao" is said "Tschau".
  His lines always come (no dice), at most every 2.5 s, heard from 40 m; between them he giggles.
  Co-op: puppet as usual, CoopEnemies._vanished for his vanishing. Tests: tests/m9_mandl,
  tests/net_specials.

**5b and 5c — two new fighters with abilities no enemy has yet** (Q7: the user wants both):
- (5b) **Da Wilderer**, a ranged enemy: a zombie poacher with an old rifle, from wave 7
  (wave_table weight 1.0, 250 + 30·wave health, 3.0 m/s). He keeps 12 to 25 m off, stops where he
  can see a player, aims for 1.2 s (a glint from his scope and a click: the moment to get into
  cover) and fires once (25 damage, a visible tracer, walls block it), then moves on. Close up he
  clubs with the stock. He makes the long sight lines of the Terrasse and the Schuppen dangerous
  and gives cover a purpose. Lines: "Des is mei Revier!", "Hob di!".
- (5c) **Die Bergdohlen**, flying enemies: Alpine choughs with dead white eyes, in flocks of 3 to 5
  from wave 6. Small, 60 + 8·wave health (one good hit), 6 m/s, they fly over fences and through
  broken windows without stopping at barricades, peck (8 damage) and flutter off for a moment.
  They make you look and shoot up. They fly outdoors and through open doors and windows, not on
  the navmesh (a simple steering flight with ceiling and wall checks). They count towards the
  24 alive at once, so a flock is a few of the slots.

*Open pool: more ideas (not planned; any of these can become a part once the user picks it, and
new ones are added here)*
- Power-ups from enemies (section 8, never built): Doppelte Punkte, Sofort-Kill, Nachschub, maybe
  our own "Jausnzeit" (everyone healed) and "Schneesturm" (all enemies slowed).
- Buyable traps or obstacles (#27).
- An enemy with its own way in (#2): a Kaminkehrer down the Stube's chimney, or an avalanche
  event that breaks in a wall.
- Funny reload animations for the absurd weapons (#3) and visible hands (#10).
- Replayability: a pick of 1 from 3 small bonuses between waves; run modifiers in the lobby
  (Föhnsturm, Nur Nahkampf, Krampusnacht); a Hüttenbuch in the Stube with records, hats and
  trophies; a daily seed.
- First-visit hints (where the shrine is, how doors and wall-buys work).
- A hidden quest: three Enzian bottles hidden on the map unlock a secret song and a free Schnaps.
- Night and weather: the storm gets heavier through the waves, a Föhn wave with clear sight.
- Bergtour, a procedural mode reshuffling the rooms (needs section 15 changed first).

*Questions for the user*
- Q1 (answered): Nomoi! shows at once on every end screen; the match restarts when everyone in
  the room pressed it.
- Q2 (answered): damage numbers off by default, with a setting.
- Q3 (answered): kill streaks give bonus points.
- Q4 (answered): all voices from eSpeak NG with an undead filter per enemy type (samples
  approved: Wanderer and Tourist clean, without hiss; Perchte and Krampus as sampled).
- Q5 (answered): the Dengelstock is up in the Holzschuppen's hay loft.
- Q6 (answered): a second upgrade that doubles the effect of the first.
- Q7 (answered): both new fighters, the Wilderer (5b) and the Bergdohlen (5c).


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
- ~~Whether co-op should use a lobby with room codes or direct invite links.~~ Answered: both, the
  code is 4 digits.
