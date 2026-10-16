class_name WeaponData
extends Resource
## Every weapon is one of these. Tune numbers in the .tres files, never in code.

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
## Metres.
@export var range: float = 50.0
@export var is_auto: bool = false
@export var pellets: int = 1
@export var cost: int = 0
@export var ammo_cost: int = 0
## Optional id of a behavior script for special weapons (section 6a). Empty = plain hitscan.
@export var behavior: StringName
@export var viewmodel: PackedScene


func has_chamber() -> bool:
	return chamber_time > 0.0


## Rounds the gun holds once loaded: a full mag, plus one in the chamber if there was still one in there.
func loaded_capacity(round_chambered: bool) -> int:
	return mag_size + (1 if has_chamber() and round_chambered else 0)
