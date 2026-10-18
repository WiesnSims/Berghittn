# Berghittn — Networking plan (M7)

Status: **approved 2026-10-18** with the answers in section 11 (GAME_DESIGN.md section 12, M7 decision gate). Numbers are from the Cloudflare docs as of 2026-10-18.

## 1. Summary

| Topic | Decision |
|---|---|
| Transport | Browser WebSocket (`WebSocketPeer`), one connection per player, to a relay. ENet is not available on the web; WebRTC is not needed (section 3) |
| Relay | A Cloudflare **Durable Object** (one per room) that only forwards bytes. It lives in a helper Worker `berghittn-relay` with **no public route** (`workers_dev = false`). Players reach it only through a **Pages Function** on `berghittn.pages.dev/api/...`, which hands the WebSocket upgrade to the room's Durable Object |
| Godot side | A small GDScript `RelayPeer` (`MultiplayerPeerExtension`) on top of `WebSocketPeer`, so the game uses Godot's normal multiplayer API (`@rpc`, `multiplayer.get_unique_id()`, peer 1 = host) |
| Authority | **Host-authoritative world**: the host's game runs enemies, waves, points, doors, purchases, chest, perks, events. **Each player owns their own movement, aim and hit detection** and tells the host what they hit (section 4 explains why this deviates from "clients send inputs") |
| Lobby | Create a room, get a 4-digit **room code** (numbers only); join by typing it or by an **invite link** `berghittn.pages.dev/?room=4711`. Up to 4 players. Each player picks a name and dresses their hiker. The host starts the match |
| Cost | **0 €**: stays on the Workers **Free plan** (user decision). About 7 hours of 4-player or 14 hours of 2-player play per day before the daily quota is used up (section 7) |
| Solo | Unchanged: solo still runs entirely offline in the browser, no relay involved |

## 2. Why this transport and relay

- Static Pages hosting cannot run a game server, and Godot's web build has no ENet, so a relay is needed.
- **WebSocket relay over Cloudflare Durable Objects** is the only option that keeps all traffic on
  `berghittn.pages.dev` (user decision: no `workers.dev` URL). One Durable Object per room is one
  single-threaded place in Cloudflare's network that all four sockets connect to, which is exactly a relay.
- **WebRTC** (peer-to-peer) was considered and rejected for now: it still needs a signalling server
  (the same Durable Object), and players behind strict NATs would need a TURN server (Cloudflare
  Calls TURN is a separate paid product). It would also double the code paths to test. WebSocket is
  reliable and ordered (TCP); a lost packet delays the next ones a little. For a co-op PvE game among
  friends in the same region this is fine.
- The Durable Object starts near whoever creates the room (the host), so for players in Austria and
  Germany the relay hop is a few milliseconds.

### How the pieces fit

```
 Browser (host)  ─┐                         ┌─ Durable Object "Room KNDL"
 Browser (2)     ─┼─ wss://berghittn.pages.dev/api/room/KNDL ──► Pages Function ──►│  (in Worker berghittn-relay,
 Browser (3, 4)  ─┘     (WebSocket upgrade)                        (validates)     │   no public route)
                                                                                   └─ forwards frames between the sockets
```

- `functions/api/room/[code].js` (Pages Function): checks the code format, the `Upgrade: websocket`
  header and the build version, then `env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(request)`.
  Invalid requests are refused here, before they cost a Durable Object request.
- `POST /api/room` creates a room: picks a free 4-digit code (1000–9999, user decision: numbers only)
  and returns it. A code is free again once its room closed. Codes are easy to guess, so anyone can
  walk into an open lobby; the host sees every name and can kick before starting.
- `relay/` (new folder, own `wrangler.toml`, deployed with `wrangler deploy` as `berghittn-relay`,
  `workers_dev = false`, `preview_urls = false`): the `Room` Durable Object class, SQLite backend (the
  only kind on the Free plan; we store nothing in it).
- The Pages project gets a `wrangler.toml` with `pages_build_output_dir = "export"` and a
  `[[durable_objects.bindings]] name = "ROOMS", class_name = "Room", script_name = "berghittn-relay"`
  for both `production` and `preview`, so branch previews get co-op too.
- Pages only runs Functions for `/api/*` (generated `_routes.json`), so loading the game itself does
  not count against the Functions quota.
- `functions/` and `relay/` get a `.gdignore` so Godot does not scan them.

### The relay protocol (kept tiny on purpose)

The Durable Object does not understand the game. It knows sockets, peer ids and who is host.

- The first socket of a room is the host and gets peer id 1; others get 2, 3, 4 (Godot's convention).
  A 5th socket is refused ("room full"). Joining after the host started the match is refused
  ("already running"; user decision Q4: joining only in the lobby).
- Binary frames: `[type u8][peer id u8][payload…]`.
  - Client → relay: `peer id` is the target (0 = everyone, 1 = host, n = that peer).
  - Relay → client: `peer id` is the sender. The relay always rewrites it, so nobody can pretend to be the host.
- Control frames from the relay (JSON text): `welcome` (your id, the code, who is there), `joined`,
  `left`, and `closed` with a reason (`host_left`, `kicked`, `full`, `started`, `version`, `no_room`)
  sent just before the relay closes a socket (built 2026-10-18: a close the relay starts does not
  always arrive as a close event, so the reason travels as a message and as the close reason).
- If the host's socket closes, the room closes for everyone (no host migration; section 8).
- Safety: max 4 sockets, max frame size 64 KiB, and a per-socket rate limit (frames above about 60/s
  are dropped) so a broken client cannot burn the daily quota.
- Uses the **WebSocket Hibernation API** (`ctx.acceptWebSocket`): while a lobby is idle the object
  sleeps and costs no duration. Peer id and role live in `serializeAttachment`, so they survive a sleep.

### `RelayPeer` (Godot)

- A `MultiplayerPeerExtension` in GDScript wrapping `WebSocketPeer`; set as
  `multiplayer.multiplayer_peer`, so all game code uses `@rpc` and `multiplayer.is_server()`.
- **Batching**: every packet Godot queues during a network tick goes out in one WebSocket frame per
  target, 20 times a second. This cuts the billed messages (section 7) and the per-frame overhead.
- Reliable and unreliable channels both map to the one WebSocket (it is always reliable); unreliable
  state snapshots simply carry a sequence number and old ones are dropped on arrival.

## 3. What runs where

| System | Runs on | Others see |
|---|---|---|
| Own movement, mouse look, crouch, sprint, jump | each player | transform + pose at 20 Hz, shown 100 ms behind with interpolation |
| Shooting (hitscan), aim, recoil, spread | the shooter | "player n fired weapon w" (tracer, sound, flash); hits reported to the host |
| Hit detection | the shooter, against the enemies as **they see them** | host applies the damage, kill and points |
| Enemies (AI, pathing, attacks, window breaking, ragdoll start) | host | packed snapshot of all alive enemies at 20 Hz; deaths and attacks as events |
| Ragdolls, particles, impact marks, sounds, screen effects | everyone locally | started by the death/fire events, never synced frame by frame |
| Waves, spawns, break timer, boss wave | host | wave events (`Events.wave_*` are re-emitted on clients) |
| Points (per player), purchases | each player's own game, earned on the host's word (the host passes on every hit, kill and board with who did it) | shared things (doors, the chest) are requests: the buyer pays, the host accepts or pays back |
| Doors / zones (anyone opens, opener pays) | host | zone unlocked |
| Barricades (repairing, boards pulled) | host | board count per window |
| Wall-buys, Munitionskiste, Schnaps, Brettljause | the buyer's own game (they change only the buyer) | nothing |
| Hüttentruhe (opener pays, the gun is for the opener) | the opener's game picks the gun (it knows what they carry), the host lets the roll happen or pays back | the roll animation and the result |
| Player health, damage taken | the player's own game, hit by the host's enemies (the host hands every hit on a hiker to its player) | health per player, alive / downed / out |
| Downed, bleed-out, revive (section 10) | host | state per player |
| Events: Resi, Bierfassl, Murmeltier, Deitscha Tourist | host | positions + state, banners via `Events.event_announced` |
| Special weapons and equipment | see section 5 | |

The existing code already helps: the `Events` bus carries a `source` player for every kill, hit and
repair, enemies already target "the nearest player" via the `player` group, and
`WaveTable.enemy_count` already takes the player count.

## 4. Authority model: why players own their own movement and hits

Section 10 says "clients send inputs and receive state". Done literally, every step and every shot
of a joining player would wait for a round trip to the host (40–100 ms over a relay), and the game
would feel sluggish for everyone except the host. Hiding that needs client prediction and server
rewind, which is a lot of code for a PvE game among friends.

So I propose the standard co-op shortcut:

- **Movement and aim**: each player simulates their own body and sends it to the host. The host trusts it.
- **Hits**: the shooter checks hits against the enemies on their own screen and sends
  `hit(enemy id, part, damage, flags)`. The host checks only that the enemy is alive and the claim is
  plausible (in range of that weapon), then applies it. The shot feels instant for every player.
- **Built 2026-10-18 (part 2)**: each player's own game also keeps their health, perks and points, so
  Sturschädl, Gmiatlichkeit and the Pfanne's guard work as in solo; the host decides what hits them and
  who earned what. Purchases that change only the buyer (wall-buys, Schnaps, Jause, ammo) stay local.
- **Everything with consequences for others stays on the host**: enemy health and death, points, money,
  purchases, doors, waves, chest rolls, events. Players send *requests* ("buy door 3"), the host answers.

Cheating is possible in theory (a modified client could claim hits). With 4 friends, no
leaderboards (out of scope, section 15) and room codes, this does not matter. This is a deviation from
section 10's wording; **question Q1**.

## 5. Special weapons and equipment

These were built for one player, so each needs a look. The rule: whatever only shows something runs
locally from an event; whatever moves or hurts enemies is resolved by the weapon's owner and reported,
like hitscan.

| Weapon / item | Plan |
|---|---|
| Alphorn, Kuhglocke, Handböller, Böllerschuss (perk), Goaßl, Krampus-Rute | area hit: the owner runs `WeaponHolder.area_hit` / `blast` on their view and reports the hit list; host applies damage, knockback, stun, flee |
| Knödelwerfer, Rodelkanone, Brennkessel, Handböller shells, Schnaps blob | projectile simulated by its owner, a copy flies on the other screens from the spawn event; the owner reports hits |
| Brennlacke (fire puddle), Knödel pile, Tanzboden, Harmonika notes, Kuhfladen-Mine, Eisstock | placed things live on the host (they act over time on enemies), shown on clients from a spawn event |
| Mistgabel (lift and carry an enemy) | owner asks the host to lift; while carried the host moves the enemy to the fork position the owner sends; throwing is a request too |
| Harmonika dance, slows, burns (DoTs) | applied on the host from the owner's report; clients see the enemy's state in the snapshot |
| Schmarrnpfanne guard | stays with the blocking player (they take hits on the host, so the host needs the guard state: sent with the transform) |

## 6. Gameplay rules that co-op adds

From section 10, plus what has to be decided now:

- **Downed**: at 0 HP a player goes down, crawls slowly and can only use the Dienstpistole; 30 s bleed-out.
  Schnaps perks are lost on going down (section 9); the Brettljause and the Jagamoasta bonus stay.
  Sturschädl still saves first.
- **Revive**: a teammate holds `E` within 2 m for 4 s.
- **Game over** when every player is down or dead.
- **Bled out**: the player watches a teammate (spectator) and comes back at the start of the next
  wave (user decision Q3) with the Dienstpistole, keeping their points, the Brettljause and the
  Jagamoasta bonus; Schnaps were already lost on going down.
- **Pause**: in co-op, Esc opens the menu but the world keeps running (one player cannot freeze it for
  everyone). Solo still pauses.
- **Points and prices**: unchanged per player; enemy count per wave already scales with players;
  the 24-enemies-alive cap is total, not per player (section 3).
- **Look of other players** (user decision Q5): a low-poly hiker on the same rig as the enemies and
  the Deitscha Tourist, holding a simplified copy of their current gun, with their name above the
  head. In the lobby each player types a name and dresses their hiker on a turning preview: a few
  heads (faces, beards), a few hats (none, felt hat, Bommelmütze, Stirnband, helmet ...) and a colour
  for the jacket and one for the trousers from a small palette. Saved with the settings; the defaults
  give each of the 4 players a different jacket.
- **Version check**: the host's build id is sent on join; a mismatched browser (old cache) is told to reload.

## 7. Costs

Workers **Free plan** (Durable Objects with SQLite backend are available on Free):
100,000 requests per day (Durable Objects; a separate 100,000 per day for Workers/Pages Functions),
13,000 GB-s duration per day. Incoming WebSocket messages are billed at **20 messages = 1 request**;
outgoing messages are free; opening a socket is 1 request.

With the 20 Hz batching from section 2, each player sends about 20 frames per second:

| Players | Incoming frames/s | Billed requests/hour | Hours per day on Free | Duration GB-s/hour |
|---|---|---|---|---|
| 2 | 40 | 7,200 | ~13.9 | ~450 |
| 4 | 80 | 14,400 | ~6.9 | ~450 |

Duration (the object is awake the whole match, 128 MB) is about 450 GB-s per hour, so 13,000 GB-s
allows ~28 room-hours a day; the request count is the limit that bites first. Storage: none.

If the quota runs out, new connections fail until midnight UTC (the game says "co-op is busy, try
later"; solo keeps working). **We stay on the Free plan** (user decision Q6); the Workers Paid plan
(5 $/month) is not used.

## 8. Out of scope for M7

- Host migration (the host leaving ends the match for everyone; a banner says so).
- Joining a match that is already running (only in the lobby; Q4).
- Voice chat, accounts, matchmaking with strangers, more than 4 players (section 15).
- Anti-cheat beyond the plausibility check in section 4.

## 9. Testing

- **Relay**: `wrangler dev` runs the Durable Object locally (Miniflare); small Node tests check
  join, the 4-player cap, sender rewriting, host-leaves-closes-room and the rate limit.
- **Headless Godot**: a test launches a host and a client as two `godot --headless` processes against
  the local relay, each with a bot player, and checks that enemies, kills, points, doors and waves
  match on both sides (like `tests/m5_waves`, but networked). The same test with 4 processes for 4 players.
- **Browser**: after each deploy, two (later four) Playwright browser contexts open the preview URL,
  create and join a room and play with bots; console errors and lag are checked. The acceptance
  (two browsers, 10 waves) is checked this way first, then play-tested by you.
- Bandwidth and frame rate are measured with 4 players and 24 enemies (target: under 10 KiB/s per
  player down, 60 FPS kept).

## 10. Proposed order (one PR each, play-test after each, like M6)

1. **Relay and lobby**: Durable Object, Pages Function, `RelayPeer`, lobby screen (name, create,
   join by code or link, player list with each hiker, host starts), the player hiker model and the
   character editor (head, hat, jacket and trouser colours). Acceptance: two browsers in one room see
   each other's names and hikers, and the host's start takes both into the map.
2. **Two players, core loop**: other player's body, movement and shooting synced; enemies, hitscan
   hits, points, waves, doors, barricades, wall-buys, ammo, Schnaps, Jause, Hüttentruhe; downed and
   revive; co-op game over. Acceptance: two browsers play waves 1–5 together.
3. **Special weapons, equipment and events** in co-op (section 5). Acceptance: every weapon and event
   works with two players.
4. **Four players and acceptance**: 4-player tests, bandwidth and frame rate, polish.
   Acceptance: two browsers play the same match for 10 waves (M7 acceptance), and 4 players join one match.

## 11. Decisions (user, 2026-10-18)

- **Q1 Authority**: each player owns their own movement and hit detection (section 4). Approved.
- **Q2 Lobby**: room code **and** invite link; the code is simple, numbers only (4 digits).
- **Q3 Bled out**: the player comes back at the start of the next wave.
- **Q4 Late join**: only in the lobby.
- **Q5 Look**: a low-poly hiker with a name tag; each player can dress it in the lobby (head, a few
  hats, jacket and trouser colours).
- **Q6 Cost**: stay on the Workers Free plan; the helper Worker `berghittn-relay` (no public URL) is deployed.
