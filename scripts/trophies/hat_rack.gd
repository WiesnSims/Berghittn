class_name HatRack
extends Node3D
## Da Huatständer (1.2, GAME_DESIGN section 12): a board with a peg for every hat in the game under
## the Trophäenwand, the plain enemies' on top, the Bsundan's below, a brass plate with the name under
## each. The first hat of each kind shot off in a match goes up on its peg (a Bsundan's with a
## banner). Each screen keeps its own: every screen hears every hat_shot (Enemy.puppet_hat).
## Built in code; faces -Z like the TrophyWall, so it hangs with the same turn.

## The rack is full (every hat on it) in this match: a Wandernadl.
signal filled

const ROWS: Array = [
	[&"wanderer", &"tourist", &"knappe", &"wilderer", &"venedigermandl"],
	[&"kassier", &"bergfuehrer", &"trailrunner", &"influencer", &"sprengmeister", &"schoenperchte"],
]
const PEG_GAP: float = 0.58
const ROW_GAP: float = 0.62
const WOOD: Material = preload("res://assets/materials/wood_dark.tres")
## A hat is shrunk to fit this (m) across and up (the Schönperchte's Tafel).
const HAT_FIT: float = 0.42
const PLATE_DIM := Color(0.62, 0.52, 0.34, 0.45)
const PLATE_LIT := Color(1.0, 0.84, 0.48, 1.0)

# Enemy id -> [peg node, plate label]; the ids whose hat is up.
var _pegs: Dictionary = {}
var _hung: Array[StringName] = []


func _ready() -> void:
	add_to_group("hat_rack")
	_build()
	Events.hat_shot.connect(_on_hat_shot)


## The ids whose hat hangs here.
func hung() -> Array[StringName]:
	return _hung


func is_full() -> bool:
	return _hung.size() == _pegs.size()


## Every hat up at once, quietly (tests and pictures).
func hang_all() -> void:
	for id: StringName in _pegs:
		_hang(id, false)


## Hangs `id`'s hat if its peg is still empty; `loud`: pop, nail and (a Bsundan's) banner.
func hang(id: StringName, loud: bool = true) -> bool:
	if not _pegs.has(id) or id in _hung:
		return false
	_hang(id, loud)
	return true


func _on_hat_shot(enemy: Node3D, _source: Node3D) -> void:
	var shot := enemy as Enemy
	if shot:
		hang(shot.data.id)


func _hang(id: StringName, loud: bool) -> void:
	if id in _hung:
		return
	_hung.append(id)
	var peg: Node3D = _pegs[id][0]
	var mesh: Mesh = load("res://assets/models/enemies/%s_hat.res" % id)
	var hat := MeshInstance3D.new()
	hat.mesh = mesh
	# Hung by its crown on the peg's tip, tipped a little towards the room.
	var holder := Node3D.new()
	holder.position = Vector3(0.0, 0.02, -0.12)
	holder.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	peg.add_child(holder)
	var bounds: AABB = mesh.get_aabb()
	var fit: float = minf(1.0, HAT_FIT / maxf(bounds.size.x, bounds.size.y))
	hat.scale = Vector3.ONE * fit
	hat.position = -bounds.get_center() * fit
	holder.add_child(hat)
	var plate: Label3D = _pegs[id][1]
	plate.modulate = PLATE_LIT
	if loud:
		holder.scale = Vector3.ONE * 0.01
		create_tween().tween_property(holder, "scale", Vector3.ONE, Constants.TROPHY_POP_TIME) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sound.play_at(&"board_nail", peg.global_position)
		if id in ROWS[1]:
			Events.event_announced.emit(tr("EVENT_HAT_RACK") % tr("ENEMY_" + String(id).to_upper()))
	if is_full():
		filled.emit()


func _build() -> void:
	var widest: int = 0
	for row: Array in ROWS:
		widest = maxi(widest, row.size())
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(widest * PEG_GAP + 0.3, ROWS.size() * ROW_GAP + 0.25, 0.05)
	box.material = WOOD
	board.mesh = box
	board.position = Vector3(0.0, 0.0, 0.035)
	add_child(board)
	var peg_mesh := CylinderMesh.new()
	peg_mesh.top_radius = 0.022
	peg_mesh.bottom_radius = 0.03
	peg_mesh.height = 0.16
	peg_mesh.material = WOOD
	for r: int in ROWS.size():
		var row: Array = ROWS[r]
		var y: float = (ROWS.size() - 1) * ROW_GAP / 2.0 - r * ROW_GAP + 0.08
		for i: int in row.size():
			var id: StringName = row[i]
			# Left to right as seen from the room (it faces -Z, so +X is on the viewer's left).
			var peg := Node3D.new()
			peg.name = "Peg_" + String(id)
			peg.position = Vector3((row.size() - 1) * PEG_GAP / 2.0 - i * PEG_GAP, y, 0.0)
			add_child(peg)
			var stick := MeshInstance3D.new()
			stick.mesh = peg_mesh
			stick.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			stick.position = Vector3(0.0, 0.0, -0.07)
			peg.add_child(stick)
			var plate := Label3D.new()
			plate.text = tr("ENEMY_" + String(id).to_upper())
			plate.pixel_size = 0.0018
			plate.font_size = 32
			plate.outline_size = 8
			plate.modulate = PLATE_DIM
			plate.outline_modulate = Color(0.12, 0.07, 0.03, 1.0)
			plate.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			plate.position = Vector3(0.0, -0.21, -0.02)
			peg.add_child(plate)
			_pegs[id] = [peg, plate]
	var title := Label3D.new()
	title.text = "Huatständer"
	title.pixel_size = 0.004
	title.font_size = 56
	title.outline_size = 10
	title.modulate = Color(0.95, 0.86, 0.66, 1.0)
	title.outline_modulate = Color(0.12, 0.07, 0.03, 1.0)
	title.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	title.position = Vector3(0.0, -(ROWS.size() * ROW_GAP + 0.25) / 2.0 - 0.14, -0.01)
	add_child(title)
