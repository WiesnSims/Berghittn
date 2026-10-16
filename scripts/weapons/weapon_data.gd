class_name WeaponData
extends Resource
## Every weapon is one of these. Tune numbers in the .tres files, never in code.

## What right click does (section 6): every weapon gets a mode that suits it.
## AIM: down the sights (hold). SCOPE: through a scope with an overlay (hold).
## ALL_BARRELS: every loaded round in one blast (press).
## FAN: work the action as fast as the hand can, firing from the hip (hold); see rapid_*.
enum Secondary { NONE, AIM, SCOPE, ALL_BARRELS, FAN }

@export var id: StringName
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
@export var cost: int = 0
@export var ammo_cost: int = 0
## Optional id of a behavior script for special weapons (section 6a). Empty = plain hitscan.
@export var behavior: StringName
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


func can_aim() -> bool:
	return secondary == Secondary.AIM or secondary == Secondary.SCOPE


func has_chamber() -> bool:
	return chamber_time > 0.0


## Rounds the gun holds once loaded: a full mag, plus one in the chamber if there was still one in there.
func loaded_capacity(round_chambered: bool) -> int:
	return mag_size + (1 if has_chamber() and round_chambered else 0)
