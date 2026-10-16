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
