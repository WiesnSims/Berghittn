class_name TrophyWall
extends Node3D
## Die Trophäenwand (M8, user request 2026-10-19): empty plaques on the Stube's east wall. Every
## Krampus that falls and the first Perchte of a match (then every Constants.TROPHY_PERCHTE_EVERY-th)
## goes up on the next free one, with a banner, until the wall is full. Each screen keeps its own:
## in co-op every peer sees the same kills in the same order (CoopEnemies), so the walls match.

const KRAMPUS: Mesh = preload("res://assets/models/trophies/trophy_krampus.res")
const PERCHTE: Mesh = preload("res://assets/models/trophies/trophy_perchte.res")

var _plaques: Array[Node3D] = []
var _hung: int = 0
var _perchten: int = 0


func _ready() -> void:
	for child: Node in get_children():
		if child.name.begins_with("Plaque"):
			_plaques.append(child as Node3D)
	Events.enemy_killed.connect(_on_killed)


## How many plaques have a trophy.
func hung() -> int:
	return _hung


func _on_killed(enemy: Node3D, _is_headshot: bool, _is_melee: bool, _source: Node3D) -> void:
	var killed := enemy as Enemy
	if killed == null:
		return
	match killed.data.id:
		&"krampus":
			_hang(KRAMPUS, "TROPHY_KRAMPUS")
		&"perchte":
			_perchten += 1
			if _perchten == 1 or _perchten % Constants.TROPHY_PERCHTE_EVERY == 0:
				_hang(PERCHTE, "TROPHY_PERCHTE")


func _hang(mesh: Mesh, key: String) -> void:
	if _hung >= _plaques.size():
		return
	var plaque: Node3D = _plaques[_hung]
	_hung += 1
	var trophy := MeshInstance3D.new()
	trophy.mesh = mesh
	trophy.scale = Vector3.ONE * 0.01
	plaque.add_child(trophy)
	create_tween().tween_property(trophy, "scale", Vector3.ONE, Constants.TROPHY_POP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play_at(&"board_nail", plaque.global_position)
	Events.event_announced.emit(tr(key))
