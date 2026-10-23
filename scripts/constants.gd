class_name Constants
extends RefCounted
## Single home for gameplay numbers that are not (yet) part of a data resource.

# Player movement, in metres, seconds and radians.
const PLAYER_WALK_SPEED: float = 4.0
const PLAYER_SPRINT_SPEED: float = 6.5
const PLAYER_CROUCH_SPEED: float = 2.0
const PLAYER_JUMP_VELOCITY: float = 4.5
const PLAYER_GROUND_ACCEL: float = 40.0
# Low air control keeps jumps committed but still lets players correct slightly.
const PLAYER_AIR_ACCEL: float = 8.0
const PLAYER_STAND_HEIGHT: float = 1.8
const PLAYER_CROUCH_HEIGHT: float = 1.1
const PLAYER_EYE_BELOW_TOP: float = 0.15
# Crouch blend per second (0 = standing, 1 = crouched).
const PLAYER_CROUCH_BLEND_SPEED: float = 8.0
const PLAYER_MAX_PITCH_DEG: float = 89.0
# Safety net if the player ever clips out of the map.
const PLAYER_FALL_RESPAWN_Y: float = -20.0

# Radians of view rotation per screen pixel of mouse movement.
const DEFAULT_MOUSE_SENSITIVITY: float = 0.002
const DEFAULT_LOCALE: String = "en"
# Settings menu ranges (M6). Volumes are linear 0..1 per audio bus.
const MOUSE_SENSITIVITY_MIN: float = 0.0005
const MOUSE_SENSITIVITY_MAX: float = 0.006
const AIM_SENSITIVITY_MIN: float = 0.2
const AIM_SENSITIVITY_MAX: float = 1.0
const DEFAULT_VOLUME: float = 0.8
const RENDER_SCALE_MIN: float = 0.5

# Chrome refuses a new pointer lock for about a second after the user pressed Esc to exit one.
const POINTER_RELOCK_DELAY: float = 1.2
const DEBUG_OVERLAY_REFRESH: float = 0.25

# Physics layer bitmasks (see README "Physics layers").
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_PLAYER_BLOCKER: int = 8
const LAYER_HITBOX: int = 16

# Player health.
const PLAYER_MAX_HEALTH: int = 100
const PLAYER_REGEN_PER_SECOND: float = 10.0
const PLAYER_REGEN_DELAY: float = 5.0
# Time the camera takes to drop to the floor, and the pause before the death screen shows.
const PLAYER_DEATH_FALL_TIME: float = 0.8
const DEATH_SCREEN_DELAY: float = 1.6

# Enemy AI.
# Re-pathing every physics frame is wasted work with 24 enemies; the player does not move that far in 0.25 s.
const ENEMY_REPATH_INTERVAL: float = 0.25
const ENEMY_TURN_SPEED: float = 8.0
const ENEMY_CORPSE_TIME: float = 5.0
const ENEMY_DEATH_FALL_TIME: float = 0.6
# Ragdolls (M6 part 4, #39): at most this many corpses are simulated at once; each is frozen in the
# pose it came to rest in after RAGDOLL_TIME seconds, or sooner (but not before RAGDOLL_MIN_TIME) to
# make room for a new one; with no room the corpse falls like before. The killing hit pushes it
# away from the shooter at RAGDOLL_PUSH m/s (scaled by the damage, within the RAGDOLL_PUSH_SCALE
# range per 100 damage), a little upward.
const RAGDOLL_MAX: int = 6
const RAGDOLL_TIME: float = 3.0
const RAGDOLL_MIN_TIME: float = 0.8
const RAGDOLL_PUSH: float = 2.5
const RAGDOLL_PUSH_SCALE: Vector2 = Vector2(0.6, 2.0)
const RAGDOLL_LIFT: float = 1.0
# Window entry: height of the window centre above the inside floor (sill 0.9 m + half of the 1.2 m
# opening), how far from the wall centre the enemy stands to start its dive and lands inside,
# and the root height that puts a body lying face down on the floor.
const ENEMY_WINDOW_DIVE_HEIGHT: float = 1.5
const ENEMY_WINDOW_STAND_OFF: float = 0.75
const ENEMY_LYING_HEIGHT: float = 0.2
# Vertical distance beyond which a melee swing cannot reach (player on a table, enemy below).
const ENEMY_ATTACK_MAX_HEIGHT: float = 1.4
# Height of the line between enemy and player that must be clear for a swing to start and land.
const ENEMY_ATTACK_CHEST_HEIGHT: float = 1.2

# Seconds to walk the last bit from the link start to the window.
const ENEMY_WINDOW_APPROACH_TIME: float = 0.3
# Horizontal distance (m) from a window link's outside end at which an enemy starts its way in,
# even if the crowd keeps it from reaching the exact point.
const ENEMY_LINK_REACH: float = 1.0
# Unsticking (play-test bug: bodies hung in doorways and at corners, blocked by a wall edge the path
# cuts or by other enemies standing in the way): a chaser that has moved less than ENEMY_STUCK_MOVE
# in ENEMY_STUCK_TIME seconds sidesteps for ENEMY_SIDESTEP_TIME and asks for a fresh path.
const ENEMY_STUCK_TIME: float = 0.8
const ENEMY_STUCK_MOVE: float = 0.3
const ENEMY_SIDESTEP_TIME: float = 0.5
# Knockback (Böllerschuss): how fast a thrown-back body loses its push (m/s per second) and its hop.
const ENEMY_KNOCKBACK_DECAY: float = 24.0
const ENEMY_KNOCKBACK_HOP: float = 2.5

# Lures (die Resi's bell, later the Kuhglocke): how close an enemy must get to count as there.
const ENEMY_LURE_REACH: float = 1.6

# Event markers (section 8a): the light column's opacity, and the distances (m) between which it fades
# in, so it does not hang over the thing it marks when the player is right next to it.
const MARKER_COLUMN_ALPHA: float = 0.22
const MARKER_COLUMN_FADE_NEAR: float = 6.0
const MARKER_COLUMN_FADE_FAR: float = 14.0
# Events (section 8a). Die Resi: first wave, waves between visits, seconds into the wave she arrives,
# how long she stays, how near a player must come before her bell lures at all, how far it carries
# then, seconds of milking, and her walking and bolting speeds.
const RESI_FIRST_WAVE: int = 3
const RESI_EVERY_MIN: int = 3
const RESI_EVERY_MAX: int = 5
const RESI_DELAY: float = 12.0
const RESI_STAY_TIME: float = 45.0
const RESI_NOTICE_RADIUS: float = 10.0
const RESI_LURE_RADIUS: float = 20.0
const RESI_MILK_TIME: float = 2.5
const RESI_WALK_SPEED: float = 1.1
const RESI_BOLT_SPEED: float = 6.0
# Seconds between her moos (random in between).
const RESI_MOO_MIN: float = 7.0
const RESI_MOO_MAX: float = 15.0

# Random events: from which wave, the chance per wave, and when in the wave (seconds).
const RANDOM_EVENT_FIRST_WAVE: int = 2
const RANDOM_EVENT_CHANCE: float = 0.3
const RANDOM_EVENT_DELAY_MIN: float = 8.0
const RANDOM_EVENT_DELAY_MAX: float = 35.0
# Bierfassl: rolling speed (m/s), how close a player stops it and an enemy gets flattened, what a
# boss takes instead, seconds of tapping, how long it waits to be tapped, and the points when the
# tapper already has every Schnaps.
const FASSL_SPEED: float = 8.0
const FASSL_STOP_REACH: float = 1.2
const FASSL_HIT_REACH: float = 1.0
const FASSL_BOSS_DAMAGE: int = 500
const FASSL_TAP_TIME: float = 2.0
const FASSL_REST_TIME: float = 60.0
const FASSL_POINTS_IF_FULL: int = 2000

# Murmeltier: pops per visit, seconds rising/ducking, screaming and hidden between pops, how far from
# the player the first pop is and from one pop to the next (m), and the points for catching it.
const MURMEL_POPS: int = 4
const MURMEL_RISE_TIME: float = 0.25
const MURMEL_SCREAM_TIME: float = 1.8
const MURMEL_HIDE_TIME: float = 1.2
const MURMEL_FIRST_MIN: float = 6.0
const MURMEL_FIRST_MAX: float = 22.0
const MURMEL_HOP_MIN: float = 2.5
const MURMEL_HOP_MAX: float = 7.0
const MURMEL_POINTS: int = 500

# Deitscha Tourist: health, walking speed, how near a player must be for him to walk on, how close
# to the Stube counts as there, and how long he searches before giving up (s).
const GUEST_HEALTH: int = 300
const GUEST_SPEED: float = 1.8
const GUEST_ESCORT_RANGE: float = 10.0
const GUEST_ARRIVE_REACH: float = 1.5
const GUEST_TIME: float = 180.0
# Eisstock: throwing speed (m/s), friction (m/s per s), wall bounces, speed kept per bounce, how close
# an enemy gets hit, and the damage (a boss takes less and is shoved).
const EISSTOCK_SPEED: float = 16.0
const EISSTOCK_FRICTION: float = 4.0
const EISSTOCK_BOUNCES: int = 3
const EISSTOCK_BOUNCE_KEEP: float = 0.85
const EISSTOCK_HIT_REACH: float = 0.75
const EISSTOCK_DAMAGE: int = 5000
const EISSTOCK_BOSS_DAMAGE: int = 1500

# HUD banner: its font size, and the smallest a long line shrinks to before it wraps.
const BANNER_FONT_SIZE: int = 72
const BANNER_MIN_FONT_SIZE: int = 40

# Schnaps perks (section 9). Durchschlag: extra bodies per shot.
const PERK_PIERCE_BONUS: int = 1
# Böllerschuss: blast radius (m), damage at the centre (half at the edge), push, and the wait between blasts.
const PERK_BOELLER_RADIUS: float = 4.5
const PERK_BOELLER_DAMAGE: int = 150
const PERK_BOELLER_DAMAGE_PER_WAVE: int = 20
const PERK_BOELLER_KNOCKBACK: float = 9.0
const PERK_BOELLER_COOLDOWN: float = 6.0
# Sturschädl: seconds of invincibility after cheating death (once per wave).
const PERK_STUR_INVINCIBLE_TIME: float = 4.0
# Gmiatlichkeit: standing still (below this speed) or crouching this long heals this many times faster.
const PERK_COSY_STILL_SPEED: float = 0.3
const PERK_COSY_TIME: float = 2.0
const PERK_COSY_REGEN_MULTIPLIER: float = 3.0
# ...but not while this many different enemies have hit within this many seconds (play-test: a
# crowd could not get through 30 HP/s); then the normal 5 s wait applies.
const PERK_COSY_SWARM_ATTACKERS: int = 2
const PERK_COSY_SWARM_WINDOW: float = 3.0
# Grantler (Obstler): damage share per enemy within the radius, and the most it adds.
const PERK_GRANT_RADIUS: float = 5.0
const PERK_GRANT_PER_ENEMY: float = 0.05
const PERK_GRANT_MAX: float = 0.3
# Jagamoasta: kills ("Kräuter") it takes, and what they pay for good (play-test 2026-10-17: an
# investment, not a 10 s rush): max health added (20 % of the base) and the damage share; seconds of
# green glow when it pays out.
const PERK_HERBS: int = 56
const PERK_HERB_HEALTH: int = 20
const PERK_HERB_DAMAGE: float = 0.2
const PERK_HERB_GLOW_TIME: float = 2.0

# Waves (section 8; the per-wave formula numbers live in data/wave_table.tres).
# Hard performance cap from section 3, shared by all players in co-op.
const MAX_ALIVE_ENEMIES: int = 24
# Countdown before wave 1, so the player can look around first.
const FIRST_WAVE_DELAY: float = 5.0
# Enemies spawn scattered around their marker instead of stacked inside each other.
const SPAWN_SCATTER_RADIUS: float = 1.2
const WAVE_BANNER_TIME: float = 3.0

# Points (section 8).
const POINTS_HIT: int = 10
const POINTS_KILL_BODY: int = 60
const POINTS_KILL_HEADSHOT: int = 100
const POINTS_KILL_MELEE: int = 130
const POINTS_REPAIR_BOARD: int = 10
const POINTS_POPUP_TIME: float = 0.9

# Barricades (section 4).
const BARRICADE_MAX_BOARDS: int = 6
# Seconds per board while E is held.
const BARRICADE_REPAIR_INTERVAL: float = 0.6
# Distance from the repair spot inside the window within which E works.
const INTERACT_RANGE: float = 1.7
# Height difference beyond which E does not reach (the gallery's Lager door is right above the Kueche door).
const INTERACT_MAX_HEIGHT: float = 1.2
# Picking between things in reach: metres of distance one radian of looking away is worth.
const INTERACT_LOOK_WEIGHT: float = 1.0

# Zones (section 4; door costs live in data/zone_table.tres).
const DOOR_OPEN_TIME: float = 0.7
# Where a buyer stands in front of a wall-buy: from the outline's centre down to the floor and into the room.
const WALL_BUY_SPOT: Vector3 = Vector3(0.0, -1.5, -0.7)
# Debug key (F4 while the F3 overlay is on): points added per press, for testing doors and wall-buys.
const DEBUG_POINTS: int = 1000

# Weapons: carried gun slots (section 6) and the time to draw a gun after switching or buying.
const GUN_SLOTS: int = 2
const WEAPON_SWITCH_TIME: float = 0.45
# Seconds from the end of a sprint until the raised gun can fire again (section 5: slower aiming).
const SPRINT_TO_FIRE_TIME: float = 0.2
# Scope (section 6): aim blend at which the overlay replaces the gun model, and the slow drift of the
# aim while scoped (degrees and cycles per second; halved while crouched).
const SCOPE_SHOW_AT: float = 0.95
const SCOPE_SWAY_DEGREES: float = 0.35
const SCOPE_SWAY_SPEED: float = 0.35
# Aiming (any aimed secondary) multiplies the mouse sensitivity by this, on top of the zoom scaling
# (play-test #17). A player setting since M6.
const DEFAULT_AIM_SENSITIVITY: float = 0.6
# Fully aimed, the muzzle flash shrinks to this size and its light to this share, so it does not
# cover the target in front of the sights (play-test #16).
const AIM_FLASH_SCALE: float = 0.35
const AIM_FLASH_LIGHT: float = 0.5

# Seconds a semi-auto click is remembered while the gun still cycles, so fast clicking always fires.
const FIRE_BUFFER_TIME: float = 0.12
# Loading round by round (WeaponData.reload_round_time): the share of the reload's own time spent
# bringing the gun up to load (the rest takes it back), and of each round's time until it is in.
const RELOAD_LIFT_SHARE: float = 0.45
const RELOAD_ROUND_IN_AT: float = 0.65
# Most bodies plus the wall one shot's ray is traced through (penetration).
const MAX_RAY_STEPS: int = 12

# Weapon feedback.
const MUZZLE_FLASH_TIME: float = 0.07
# Where a streak drawn from the gun starts, from the eye (right, up, ahead; metres).
const MUZZLE_OFFSET: Vector3 = Vector3(0.15, -0.15, -0.8)
# Camera recoil: how fast the kick snaps in and how fast the view settles back (per second).
# Ejected casings: how many can be in the air at once, and seconds each one flies.
const CASING_POOL_SIZE: int = 8
const CASING_LIFETIME: float = 0.6
const RECOIL_SNAP_SPEED: float = 30.0
const RECOIL_RECOVER_SPEED: float = 9.0
# Enemy hit reaction: lean-back angle (radians) for body and head hits, its recovery time,
# and how long the white hit flash takes to fade.
const ENEMY_FLINCH_BODY: float = 0.12
const ENEMY_FLINCH_HEAD: float = 0.3
const ENEMY_FLINCH_TIME: float = 0.2
const ENEMY_HIT_FLASH_TIME: float = 0.12
const IMPACT_MARK_COUNT: int = 32
const IMPACT_MARK_LIFETIME: float = 8.0
const HIT_MARKER_TIME: float = 0.15

# Hit and kill feedback (M9 part 2). First numbers, tuned by play-test.
## The kill marker (a bigger X: red, gold for a headshot kill) shows this long (s).
const KILL_MARKER_TIME: float = 0.4
## A kill chain breaks when the next kill takes longer than this (s).
const KILL_STREAK_GAP: float = 4.0
## Kills this close together count as one shot or blast (s).
const KILL_MULTI_WINDOW: float = 0.1
## Bonus points: chain of 3, 5 and 8, each enemy after the first with one shot, every third
## headshot kill in a row.
const STREAK_BONUS_3: int = 50
const STREAK_BONUS_5: int = 150
const STREAK_BONUS_8: int = 300
const STREAK_BONUS_MULTI: int = 50
const STREAK_HEADSHOTS: int = 3
const STREAK_BONUS_HEADSHOTS: int = 100
## The streak banner under the crosshair (s).
const STREAK_BANNER_TIME: float = 1.6
## The headshot kill's "Bumm" climbs this much pitch per kill of the chain, for at most this many.
const KILL_PITCH_STEP: float = 0.05
const KILL_PITCH_STEPS: int = 7
## A headshot kill kicks the view (degrees up, and at most this much sideways).
const KILL_KICK_PITCH: float = 1.2
const KILL_KICK_YAW: float = 0.4
## Any kill bumps the gun back and up (m).
const KILL_BUMP: float = 0.018
## Damage numbers (setting, off by default): height over the enemy's feet (m), how far they rise
## (m), how long they last (s) and their size on screen.
const DAMAGE_NUMBER_HEIGHT: float = 2.0
const DAMAGE_NUMBER_RISE: float = 0.6
const DAMAGE_NUMBER_TIME: float = 0.8
const DAMAGE_NUMBER_PIXEL_SIZE: float = 0.0012

# Talking enemies, "Gredn" (M9 part 3). First numbers, tuned by play-test.
## One line per enemy at most every this many seconds, and one overall every GAP_MIN..GAP_MAX.
const GREDN_ENEMY_GAP: float = 20.0
const GREDN_GAP_MIN: float = 2.5
const GREDN_GAP_MAX: float = 3.5
## Lines are said (and shown, heard) only within this many metres of a player.
const GREDN_REACH: float = 15.0
## At most this many lines shown at once (the nearest win).
const GREDN_SHOWN: int = 2
## The chance that a moment brings a line: spotting a player, a groan, starting on a barricade, a
## hard hit, the Perchte's lunge, dying.
const GREDN_CHANCE_SPOT: float = 0.6
const GREDN_CHANCE_IDLE: float = 0.3
const GREDN_CHANCE_BARRICADE: float = 0.5
const GREDN_CHANCE_HIT: float = 0.4
const GREDN_CHANCE_LUNGE: float = 0.6
const GREDN_CHANCE_DEATH: float = 0.35
## A hit "hard" enough for a line takes at least this share of the enemy's health and leaves it alive.
const GREDN_HARD_HIT: float = 0.3
## The text over the head: height over the feet (m, at model scale 1), size on screen, the seconds
## it stays at least (else as long as the voice) and fades out.
const GREDN_HEIGHT: float = 2.25
const GREDN_PIXEL_SIZE: float = 0.0016
const GREDN_TIME_MIN: float = 1.6
const GREDN_FADE_TIME: float = 0.5
## How loud the voices are (dB).
const GREDN_VOLUME: float = -3.0
# Ready ring at the crosshair (play-test, Alphorn): seconds the pulse takes when the gun is ready again.
const READY_PULSE_TIME: float = 0.3
const DAMAGE_FLASH_TIME: float = 0.4

# Quick melee: share of the swing time before the blow lands, the width of the arc in front of the
# player that it sweeps (degrees), the most enemies it checks, and where on a body box it aims its
# line-of-sight test (metres above the box origin, which is at the feet; high enough to clear a sill).
const MELEE_HIT_FRACTION: float = 0.3
const MELEE_ARC_DEGREES: float = 110.0
const MELEE_MAX_TARGETS: int = 32
const MELEE_AIM_HEIGHT: float = 1.3
# Guard (Schmarrnpfanne): seconds to bring the gun back up after lowering the guard.
const BLOCK_LOWER_TIME: float = 0.25
# Longest a weapon may be shown floating over the Hüttentruhe (metres); longer ones are shrunk.
const CHEST_DISPLAY_MAX_LENGTH: float = 1.2
# Area weapons (Alphorn, section 6a): the most hit boxes one blast checks (two per enemy), where on a
# body box it aims (metres above its origin at the feet, times the model scale), and how far beyond
# the reach or off the cone a body still counts, since bodies have width.
const AREA_MAX_TARGETS: int = 64
const AREA_AIM_HEIGHT: float = 1.1
const AREA_BODY_MARGIN: float = 0.5
# Kuhglocke (section 6a): throw speed (m/s, along the view, a little upwards), the share of speed kept
# on bouncing off a wall, seconds it rings, and the reach it draws enemies from (m).
const KUHGLOCKE_THROW_SPEED: float = 11.0
const KUHGLOCKE_BOUNCE_KEEP: float = 0.35
const KUHGLOCKE_RING_TIME: float = 10.0
const KUHGLOCKE_LURE_RADIUS: float = 20.0
# Handböller (section 6a): the double charge flies this many times faster, and shoves the player
# back this hard (m/s, flat).
const HANDBOELLER_DOUBLE_SPEED: float = 1.5
const HANDBOELLER_DOUBLE_SHOVE: float = 5.0
# Kuhfladen-Mine (section 6a): how far ahead it is placed (m), its reach (m: the 0.6 m pat plus a foot
# stepping in at its edge, measured to the enemy's middle), what it does to each
# enemy that steps in (damage, speed factor, seconds), how many it catches before it is trodden flat,
# seconds it lies at most, and how many can lie about at once.
const KUHFLADEN_PLACE_DISTANCE: float = 0.6
const KUHFLADEN_RADIUS: float = 1.0
const KUHFLADEN_DAMAGE: int = 40
const KUHFLADEN_SLOW_FACTOR: float = 0.4
const KUHFLADEN_SLOW_TIME: float = 5.0
const KUHFLADEN_CATCHES: int = 4
const KUHFLADEN_LIFETIME: float = 120.0
const KUHFLADEN_MAX_ACTIVE: int = 6
# Knödelwerfer: dumplings and piles kept in pools (oldest reused when all are out). Lobbed shots
# (Knödel, Böller shell): seconds one may fly before it bursts in the air.
const KNOEDEL_POOL: int = 12
const KNOEDEL_PILE_POOL: int = 10
const LOBBED_MAX_FLIGHT: float = 4.0
# Rodelkanone: sleds kept in a pool; the lane a sled sweeps (metres either side of its runners' line,
# measured at body height), how high a step or kerb it rides over, how far it can drop before
# it is lost, and how hard it throws what it hits sideways out of its lane (times its forward push).
const RODEL_POOL: int = 4
const RODEL_LANE: float = 0.7
const RODEL_STEP: float = 0.4
const RODEL_MAX_DROP: float = 4.0
const RODEL_SIDE_PUSH: float = 1.2
# The Kehre's aim after each bank: how far of the way it turns towards the nearest enemy it can see
# (0 not at all, 1 straight at it), and the height it looks from and at.
const RODEL_KEHRE_AIM: float = 0.6
const RODEL_AIM_EYE: float = 0.8
# Steirische Harmonika: seconds a polka makes enemies dance, how much harder other hits land on a
# dancer, and how long a dancer keeps dancing after stepping off a Tanzboden.
const DANCE_TIME: float = 4.0
const DANCE_DAMAGE_MULTIPLIER: int = 2
const DANCE_LINGER: float = 1.0
# The Tanzboden (Harmonika right click): seconds it lies, the farthest it can be laid (m), how often
# it looks for dancers (s), the Landler's bar for its pulsing rim (s), and how many can lie at once.
const TANZBODEN_TIME: float = 10.0
const TANZBODEN_REACH: float = 15.0
const TANZBODEN_SCAN: float = 0.1
const TANZBODEN_BEAT: float = 1.5
const TANZBODEN_POOL: int = 3
# How a dancer turns (radians per second), hops (metres) and how many hops a second.
const DANCE_SPIN: float = 5.0
const DANCE_HOP: float = 0.18
const DANCE_HOP_RATE: float = 2.5
# Brennkessel-Werfer: how often the flame's ticks pay hit points (seconds; it hits 8 times a second),
# and how a body it reaches burns: damage a second, for how long after it last caught fire.
const SCORCH_PAY_INTERVAL: float = 1.0
const BURN_DPS: int = 10
const BURN_TIME: float = 3.0
# Brennlacke: puddles kept in a pool, how long one burns, how often it sets what stands in it alight.
const LACKE_POOL: int = 4
const LACKE_TIME: float = 6.0
const LACKE_INTERVAL: float = 0.25
# Melee behaviors: degrees either side of the aim that count as "straight along it" (the Goaßl's
# lash, the Mistgabel's thrust), and how far ahead a fleeing enemy aims its run (metres).
const LINE_HALF_ANGLE: float = 10.0
const FLEE_LOOKAHEAD: float = 5.0
# Goaßl: seconds a crack (and letting go of the lash) stuns, the longest a lash can hold, and how near
# the player a lashed enemy is pulled before it stops.
const GOASSL_STUN_TIME: float = 1.5
const GOASSL_HOLD_MAX: float = 3.0
const GOASSL_PULL_STOP: float = 1.6
# Mistgabel: bodies one thrust goes through, the longest one can be held up on the fork, and where it
# is carried (metres ahead of the eye, and of its feet above it).
const MISTGABEL_PIERCE: int = 2
const MISTGABEL_HOLD_MAX: float = 3.0
const MISTGABEL_CARRY_AHEAD: float = 1.5
const MISTGABEL_CARRY_UP: float = 0.15
# Krampus-Rute: seconds a swat makes enemies flee, and how far around each body it strikes the panic
# spreads; the Larve (hold V) looks for faces every LARVE_SCAN and they flee on LARVE_LINGER after.
const RUTE_FLEE_TIME: float = 3.0
const RUTE_FLEE_RADIUS: float = 2.5
const LARVE_SCAN: float = 0.2
const LARVE_LINGER: float = 1.0
# Screen shake from blasts: seconds it lasts and how fast it trembles (cycles per second).
const SHAKE_TIME: float = 0.45
const SHAKE_FREQUENCY: float = 18.0

# Atmosphere (M6). The roof map covers the play area (the navmesh bake box is 60 m wide) in cells
# this size; heights are cast down from ROOF_MAP_CAST_FROM, and NO_ROOF marks a miss.
const ROOF_MAP_HALF_SIZE: float = 32.0
const ROOF_MAP_CELL: float = 0.4
const ROOF_MAP_CAST_FROM: float = 60.0
const ROOF_MAP_NO_ROOF: float = -50.0
# The camera counts as indoors this far below a roof (so standing in a doorway does not flicker).
const ROOF_MAP_MARGIN: float = 0.1
# Seconds for the fog and ambient light to change over between outdoors and indoors.
const ATMOSPHERE_BLEND_TIME: float = 1.2
const ATMOSPHERE_CUT_DISTANCE: float = 3.0
# Seconds outdoors until the screen is frozen over at the edges, and indoors until it has thawed.
const FROST_BUILD_TIME: float = 10.0
const FROST_THAW_TIME: float = 3.0
# Shader warm-up at load: frames the weapon models are drawn for, their size, and where (metres ahead
# of the camera and apart).
## The warmup's render layer (20): the only one the camera draws until the shaders are built (#78).
const WARMUP_LAYER: int = 1 << 19
## Warmup items shown per frame; one with a new shader stalls its frame, the others are cheap.
const WARMUP_PER_FRAME: int = 3
## Share of the progress the items stand for; the rest is the world's first full frame.
const WARMUP_ITEMS_SHARE: float = 0.95
const WARMUP_SCALE: float = 0.02
const WARMUP_DISTANCE: float = 0.5
const WARMUP_SPACING: float = 0.02
# The snow emitter box is centred this far above the camera.
const SNOW_EMITTER_ABOVE: float = 4.0

# Sound (M6 part 2): players in the pools (own sounds, menu sounds, sounds out in the world), the
# distance a world sound is at full level and the farthest it carries (m), the cutoff it is
# muffled to far away (Hz), and the random pitch spread of each play (share).
const SOUND_POOL_2D: int = 12
const SOUND_POOL_UI: int = 4
const SOUND_POOL_3D: int = 32
const SOUND_UNIT_SIZE: float = 3.0
const SOUND_MAX_DISTANCE: float = 50.0
const SOUND_DISTANCE_CUTOFF: float = 5000.0
const SOUND_PITCH_JITTER: float = 0.05
# Seconds within which the same sound started again is dropped instead of stacking up.
const SOUND_STACK_TIME: float = 0.06
# A far-reaching sound (Sound.attach with a reach) stays at full level out to this share of its reach.
const SOUND_FAR_UNIT_SHARE: float = 0.12
# The Murmeltier's scream carries over the whole map (play-test 2026-10-18).
const MURMEL_SCREAM_REACH: float = 120.0
# A sled breaking apart at a wall sounds this much louder (dB) than one knocking into a body.
const SLED_CRASH_LOUDER: float = 3.0
# Footsteps: metres walked per step (longer strides sprinting), and the fall speed (m/s) that makes
# a landing audible.
const STEP_DISTANCE: float = 1.7
const STEP_DISTANCE_SPRINT: float = 2.4
# Sprinting steps land harder (dB louder).
const STEP_SPRINT_LOUDER: float = 5.0
const LAND_SOUND_SPEED: float = 4.0
# Seconds between two hurt grunts, however fast the hits come.
const HURT_SOUND_GAP: float = 0.35
# Seconds between an enemy's groans (random in between).
const GROAN_MIN: float = 3.0
const GROAN_MAX: float = 9.0
# Where an enemy's voice comes from, above its feet (m, at model scale 1).
const ENEMY_MOUTH_HEIGHT: float = 1.6
# The storm indoors: how much quieter (dB) and how muffled (Hz) the wind gets under a roof, and the
# cutoff outdoors (open).
const WIND_INDOOR_DB: float = -12.0
const WIND_INDOOR_CUTOFF: float = 650.0
const WIND_OUTDOOR_CUTOFF: float = 20000.0
# Indoors the hut creaks now and then (seconds between, random) somewhere this far from the player.
const CREAK_MIN: float = 6.0
const CREAK_MAX: float = 16.0
const CREAK_DISTANCE: float = 4.0
# The band: seconds to fade between tunes, and past its fastest tier how much higher (and faster) it
# plays each further wave, up to a limit.
const BAND_FADE_TIME: float = 1.5
# The wave-in is never longer than this (s, play-test 2026-10-18: music only at the start of a wave).
const BAND_INTRO_MAX: float = 15.0
const BAND_PITCH_PER_WAVE: float = 0.02
const BAND_PITCH_MAX: float = 1.2

# Co-op (M7, NETWORKING.md).
## The live site; the relay sits behind it at /api/room/<code>.
const NET_SITE: String = "https://berghittn.pages.dev"
const NET_CODE_LENGTH: int = 4
## The host can start once this many are in the lobby.
const NET_MIN_PLAYERS: int = 2
const NET_MAX_PLAYERS: int = 4
## A friend whose invite link finds the match running knocks again this often (s) until the room is
## a lobby again (M9 "Nomoi!"); each knock is one request to the relay.
const NET_KNOCK_INTERVAL: float = 4.0
## Queued packets go out at most this long after they were queued: about 20 frames a second, which
## is what the Free plan's quota is planned around (NETWORKING.md section 7).
const NET_FLUSH_INTERVAL_MS: int = 50
const NET_PING_INTERVAL_MS: int = 20000
## Frames stay under the relay's 64 KiB limit.
const NET_FRAME_SOFT_LIMIT: int = 48 * 1024
const NET_SOCKET_BUFFER: int = 1 << 20
## Other players are drawn this far in the past, between two received poses.
const NET_INTERPOLATION_DELAY: float = 0.1
## Players stand this far apart at the start of a co-op match (m, along the spawn's right).
const NET_SPAWN_SPACING: float = 1.2
## How often a player sends where they are (s).
const NET_POSE_INTERVAL: float = 0.05
## Section 10: bleeding out takes this long (s) unless a teammate holds E within reach for the time.
const COOP_BLEED_OUT_TIME: float = 30.0
const COOP_REVIVE_TIME: float = 4.0
const COOP_REVIVE_RANGE: float = 2.0
## Seconds between revive ticks while E is held; a gap longer than COOP_REVIVE_HEARD_TIME starts over.
const COOP_REVIVE_TICK: float = 0.1
const COOP_REVIVE_HEARD_TIME: float = 0.35
## Revived with this share of the maximum health.
const COOP_REVIVE_HEALTH: float = 0.5
const COOP_CRAWL_SPEED: float = 1.2
## Height of a downed player's capsule (m); the eyes sit near the floor.
const COOP_DOWNED_HEIGHT: float = 0.8
## A spectator watches a teammate from behind and above (m).
const COOP_SPECTATE_OFFSET: Vector3 = Vector3(0.0, 2.2, 3.4)
## Co-op: the first wave waits this long after the host starts, so every guest can click in (s).
const COOP_FIRST_WAVE_DELAY: float = 15.0
## Another player's flame (their Brennkessel as we see it): seconds a flame lives on its way out.
const GHOST_FLAME_LIFETIME: float = 0.45
## Where a hiker holds their gun (m, from their feet; -Z ahead) and how big it is drawn there.
const HIKER_GUN_AT: Vector3 = Vector3(0.16, 1.26, -0.42)
const HIKER_GUN_SCALE: float = 1.3
# A teammate's name tag in the match, fixed on screen: about 18 px high at 720p.
const HIKER_TAG_SCREEN_SIZE: float = 0.0008
## The hiker's arms while holding a gun (degrees per bone, as EnemyRig.stance).
const HIKER_HOLD_STANCE: Dictionary = {
	&"arm_r": Vector3(45.0, 0.0, 6.0), &"forearm_r": Vector3(40.0, 0.0, 0.0),
	&"arm_l": Vector3(50.0, 0.0, -22.0), &"forearm_l": Vector3(45.0, 0.0, 0.0),
}
## Co-op guests: a slow that is held on a puppet (it stands in a Knödel heap) goes to the host at
## most this often (s); each lasts its own seconds, so the host's enemy stays slowed.
const NET_SLOW_RELAY_INTERVAL: float = 0.25
## Clicks right after the mouse is taken (a menu click) do not fire for this long (s).
const CAPTURE_FIRE_GRACE: float = 0.25

# --- Stuffed animals and trophies (M8, user request 2026-10-19) -----------------------------------
## The trophy wall hangs the first Perchte that falls in a match, then every this many.
const TROPHY_PERCHTE_EVERY: int = 5
## A trophy pops onto its plaque in this long (s).
const TROPHY_POP_TIME: float = 0.35
## Perchten that have to fall in our matches (all together) for the Perchtn-Haubn.
const UNLOCK_PERCHTEN: int = 5
## Survive this wave for the Krampus-Hörndl.
const UNLOCK_WAVE: int = 10
## The Raurakl, when hit: two turns in this long (s), and its grumble shows this long after.
const RAURAKL_SPIN_TIME: float = 0.8
const RAURAKL_BUBBLE_TIME: float = 2.5
