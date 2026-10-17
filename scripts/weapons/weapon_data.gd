class_name WeaponData
extends Resource
## Every weapon is one of these. Tune numbers in the .tres files, never in code.

## What right click does (section 6): every weapon gets a mode that suits it.
## AIM: down the sights (hold). SCOPE: through a scope with an overlay (hold).
## ALL_BARRELS: every loaded round in one blast (press).
## FAN: work the action as fast as the hand can, firing from the hip (hold); see rapid_*.
## BEHAVIOR: the special weapon's own second shot from its behavior script (press); see secondary_*.
## BLOCK (melee): melee lives on V, not in hand, so its mode is holding V past the blow: the weapon
## stays up as a guard against hits from the front; see block_*.
enum Secondary { NONE, AIM, SCOPE, ALL_BARRELS, FAN, BEHAVIOR, BLOCK }

@export var id: StringName
## Goes in the melee slot (quick melee on V) instead of a gun slot.
@export var is_melee: bool = false
## Translation key, not display text.
@export var display_name: String
@export var damage: int = 10
@export var headshot_multiplier: float = 2.0
## Shots per second.
@export var fire_rate: float = 1.0
@export var mag_size: int = 1
@export var reserve_ammo: int = 0
## Seconds.
@export var reload_time: float = 1.0
## Extra seconds to chamber a round when reloading from an empty mag. 0 = this weapon has no chamber.
## With a chamber, a reload while a round is still chambered loads mag_size + 1.
@export var chamber_time: float = 0.0
## View kick per shot in degrees: straight up, and the most it may also wander left or right.
@export var recoil_pitch: float = 0.0
@export var recoil_yaw: float = 0.0
## Cone half-angle in degrees.
@export var spread: float = 0.0
## Bloom: degrees each shot adds to the spread, the most it can add, and how fast it settles (deg/s).
## The crosshair opens up by the same amount.
@export var bloom_per_shot: float = 0.0
@export var bloom_max: float = 0.0
@export var bloom_recover: float = 4.0
## Metres.
@export var range: float = 50.0
@export var is_auto: bool = false
@export var pellets: int = 1
## Big calibres go through (user request, 2026-10-17): how many enemies behind the first one a shot
## can still hit, and the share of damage left after each body it passes (0.5 = half, then a quarter...).
@export var penetration: int = 0
@export var penetration_falloff: float = 0.5
## Metres from the muzzle within which a shot still goes through (0 = any distance). Buckshot only
## punches through up close (play-test, 2026-10-17).
@export var penetration_range: float = 0.0
@export var cost: int = 0
@export var ammo_cost: int = 0
## Optional id of a behavior script for special weapons (section 6a), a file in
## scripts/weapons/behaviors/. Empty = plain hitscan.
@export var behavior: StringName
## Area weapons (read by their behavior): the half-angle of the cone a shot fills (degrees, 180 = all
## around; its length is `range`), how hard it throws the survivors back (m/s right at the muzzle,
## half at the far end; heavy enemies less, by the root of their flinch_multiplier), and the screen shake it gives the
## shooter (degrees).
@export var area_angle: float = 0.0
@export var knockback: float = 0.0
@export var shake: float = 0.0
## Launched weapons (the Knödelwerfer, read by their behavior): launch speed (m/s) and the gravity the
## shot falls with (m/s²), the blast radius where it lands (m), and the sticky pile it leaves: its
## radius (m), how long it lies (s), and the slow it puts on enemies in it (speed factor, and seconds
## it lasts after they step out).
@export var projectile_speed: float = 0.0
@export var projectile_gravity: float = 9.8
@export var area_radius: float = 0.0
@export var pile_radius: float = 0.0
@export var pile_time: float = 0.0
@export var slow_factor: float = 1.0
@export var slow_time: float = 0.0
## Show the ready ring at the crosshair while the gun cycles between shots (play-test: only for the
## Alphorn's long gap; other guns show it in their animation, and fire again as it ends).
@export var cycle_ring: bool = false
## Translation key of a comic word that pops up where a melee blow lands (the pan's "BONK!"), until
## the M6 sounds; empty = none.
@export var hit_text: String = ""
@export var viewmodel: PackedScene
@export var secondary: Secondary = Secondary.NONE
## Aiming (AIM and SCOPE): field of view when fully aimed (degrees), seconds to get there, and the
## spread and walking speed as a share of hip fire.
@export var aim_fov: float = 60.0
@export var aim_time: float = 0.18
@export var aim_spread_multiplier: float = 0.3
@export var aim_move_multiplier: float = 0.6
## Fanning (FAN): shots per second while right click is held, degrees of spread it adds, and how much
## harder each shot kicks.
@export var rapid_fire_rate: float = 0.0
@export var rapid_spread: float = 0.0
@export var rapid_recoil_multiplier: float = 1.0
## Behavior secondary (BEHAVIOR): rounds it uses, and its damage, reach (m), knockback (m/s) and shake.
@export var secondary_rounds: int = 1
@export var secondary_damage: int = 0
@export var secondary_range: float = 0.0
@export var secondary_knockback: float = 0.0
@export var secondary_shake: float = 0.0
## Guard (BLOCK): half-angle (degrees) of the front it covers, and the share of a hit that still gets
## through. The attacker is shoved back by secondary_knockback; walking slows to aim_move_multiplier.
@export var block_angle: float = 60.0
@export var block_share: float = 0.0


func can_aim() -> bool:
	return secondary == Secondary.AIM or secondary == Secondary.SCOPE


func has_chamber() -> bool:
	return chamber_time > 0.0


## Rounds the gun holds once loaded: a full mag, plus one in the chamber if there was still one in there.
func loaded_capacity(round_chambered: bool) -> int:
	return mag_size + (1 if has_chamber() and round_chambered else 0)
