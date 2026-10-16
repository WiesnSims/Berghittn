class_name SnowCannon
extends Node3D
## Schneekanone on the Terrasse deck (user request, 2026-10-17: every room has a purpose): a trap.
## Paid for, it blasts the sunken beer garden with snow for a while: everything down there is slowed
## and frozen a little each second. Then it needs time to build pressure again. Kills give no points.

@export var cost: int = 1000
## Seconds it blows, and seconds after that before it can be bought again.
@export var blow_time: float = 15.0
@export var cooldown: float = 45.0
## Damage per second, and the speed share left, for every enemy in the area.
@export var damage_per_second: int = 40
@export var slow_factor: float = 0.5
## The area it covers, in world space (min and max corner).
@export var area_min: Vector3 = Vector3(-11.0, -2.0, 11.3)
@export var area_max: Vector3 = Vector3(7.0, 0.5, 18.0)

## Bought with one press, not held.
var interact_repeat: float = 0.0
var _blow_left: float = 0.0
var _cooldown_left: float = 0.0
var _tick_left: float = 0.0
@onready var _snow: CPUParticles3D = $Barrel/Snow
@onready var _barrel: Node3D = $Barrel


func _ready() -> void:
	add_to_group("interactables")
	_snow.emitting = false


func is_blowing() -> bool:
	return _blow_left > 0.0


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(Vector3(0.0, 0.0, -0.9))


func get_interact_prompt(player: Node3D) -> String:
	if _blow_left > 0.0:
		return ""
	if _cooldown_left > 0.0:
		return tr("UI_TRAP_WAIT") % ceili(_cooldown_left)
	var buyer := player as Player
	var key: String = "UI_TRAP_BUY" if buyer.points.can_afford(cost) else "UI_TRAP_NEED"
	return tr(key) % cost


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if _blow_left > 0.0 or _cooldown_left > 0.0 or not buyer.points.spend(cost):
		return
	_blow_left = blow_time
	_tick_left = 0.0
	_snow.emitting = true


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
	if _blow_left <= 0.0:
		return
	_blow_left -= delta
	# The barrel sweeps slowly from side to side over the garden.
	_barrel.rotation.y = sin(_blow_left * 0.8) * 0.45
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = 1.0
		_freeze()
	if _blow_left <= 0.0:
		_snow.emitting = false
		_cooldown_left = cooldown


func _freeze() -> void:
	var area := AABB(area_min, area_max - area_min)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.is_alive() and area.has_point(enemy.global_position):
			enemy.apply_slow(slow_factor, 1.2)
			enemy.receive_hit(damage_per_second, false, false, null)
