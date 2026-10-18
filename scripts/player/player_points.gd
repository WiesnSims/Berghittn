class_name PlayerPoints
extends Node
## This player's points (section 8). Listens to the event bus and only counts what its own player caused,
## so every player in co-op earns (and spends) separately.

signal changed(total: int, gained: int)

var total: int = 0
@onready var _player: Node3D = get_parent()


func _ready() -> void:
	Events.enemy_damaged.connect(_on_enemy_damaged)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.board_repaired.connect(_on_board_repaired)


func add(amount: int) -> void:
	total += amount
	changed.emit(total, amount)


func can_afford(cost: int) -> bool:
	return total >= cost


## Takes the points if there are enough; false (and nothing taken) otherwise. Every purchase comes
## through here, so this is where the till rings (or the buyer hears they are short).
func spend(cost: int) -> bool:
	if not can_afford(cost):
		Sound.play(&"deny")
		return false
	total -= cost
	changed.emit(total, -cost)
	Sound.play(&"buy")
	return true


func _on_enemy_damaged(_enemy: Node3D, _amount: int, _is_headshot: bool, source: Node3D) -> void:
	if source == _player:
		add(Constants.POINTS_HIT)


func _on_enemy_killed(_enemy: Node3D, is_headshot: bool, is_melee: bool, source: Node3D) -> void:
	if source != _player:
		return
	if is_melee:
		add(Constants.POINTS_KILL_MELEE)
	elif is_headshot:
		add(Constants.POINTS_KILL_HEADSHOT)
	else:
		add(Constants.POINTS_KILL_BODY)


func _on_board_repaired(_barricade: Node3D, source: Node3D) -> void:
	if source == _player:
		add(Constants.POINTS_REPAIR_BOARD)
