class_name Barricade
extends Node3D
## Boarded-up window. Sits at the centre of the opening with -Z pointing into the room.
## Enemies tear boards off before they can climb through; players nail them back on for points.
## One enemy works a window at a time, so bodies do not pile up inside each other in the opening.

signal boards_changed(count: int)

## Visual layout of the boards, nailed in this order: height offset (m), roll (degrees), length (m).
const BOARD_LAYOUT: Array[Vector3] = [
	Vector3(-0.42, 6.0, 1.45),
	Vector3(0.40, -5.0, 1.45),
	Vector3(-0.12, -9.0, 1.5),
	Vector3(0.14, 8.0, 1.5),
	Vector3(0.0, 38.0, 1.7),
	Vector3(0.0, -38.0, 1.7),
]
const BOARD_SIZE: Vector2 = Vector2(0.15, 0.035)
# Boards are nailed to the inside face of the wall, where the player stands while repairing.
const BOARD_DEPTH: float = -0.2
# Repair spot on the floor in front of the window: below the centre of the opening and into the room.
const REPAIR_SPOT: Vector3 = Vector3(0.0, -1.5, -0.7)
const ANIM_TIME: float = 0.25

@export var board_material: Material
## Height of the ground outside below the window centre (metres, negative). The navigation link that
## enemies climb in by starts there: snow is 1.8 m below, a terrace deck at floor height 1.5 m.
@export var outside_floor: float = -1.8

## Seconds between boards while interact is held (read by the player's Interactor).
var interact_repeat: float = Constants.BARRICADE_REPAIR_INTERVAL
var boards: int = Constants.BARRICADE_MAX_BOARDS
var _occupant: Node3D
var _board_nodes: Array[MeshInstance3D] = []
var _rests: Array[Transform3D] = []
var _tweens: Array[Tween] = []


func _ready() -> void:
	add_to_group("barricades")
	add_to_group("interactables")
	var link := get_node_or_null("Link") as NavigationLink3D
	if link:
		link.start_position.y = outside_floor
	for layout: Vector3 in BOARD_LAYOUT:
		var board := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.material = board_material
		mesh.size = Vector3(layout.z, BOARD_SIZE.x, BOARD_SIZE.y)
		board.mesh = mesh
		var rest := Transform3D(Basis(Vector3.BACK, deg_to_rad(layout.y)), Vector3(0.0, layout.x, BOARD_DEPTH))
		board.transform = rest
		add_child(board)
		_board_nodes.append(board)
		_rests.append(rest)
		_tweens.append(null)


func is_open() -> bool:
	return boards <= 0


## An enemy asks to work this window. False while another one is still at it.
func claim(enemy: Node3D) -> bool:
	if _occupant != null and _occupant != enemy:
		return false
	_occupant = enemy
	return true


func release(enemy: Node3D) -> void:
	if _occupant == enemy:
		_occupant = null


func remove_board() -> void:
	if boards <= 0:
		return
	boards -= 1
	Sound.play_at(&"board_pull", global_position)
	var board: MeshInstance3D = _board_nodes[boards]
	# Yanked out through the opening and dropped outside.
	var gone: Transform3D = _rests[boards].translated(Vector3(0.0, -1.2, 1.1)).rotated_local(Vector3.RIGHT, 1.2)
	_animate(boards, gone, false)
	boards_changed.emit(boards)


func add_board() -> bool:
	if boards >= Constants.BARRICADE_MAX_BOARDS:
		return false
	var index: int = boards
	boards += 1
	Sound.play_at(&"board_nail", global_position)
	var board: MeshInstance3D = _board_nodes[index]
	# Swung in from the player's side and slammed onto the frame.
	board.transform = _rests[index].translated(Vector3(0.0, 0.0, -0.45)).rotated_local(Vector3.UP, 0.5)
	board.visible = true
	_animate(index, _rests[index], true)
	boards_changed.emit(boards)
	return true


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(REPAIR_SPOT)


func get_interact_prompt(_player: Node3D) -> String:
	return tr("UI_REPAIR_HINT") if boards < Constants.BARRICADE_MAX_BOARDS else ""


func interact(player: Node3D) -> void:
	# Co-op: the host nails it on and pays the points out.
	if Coop.is_guest():
		Coop.world.request_board(self)
		return
	if add_board():
		Events.board_repaired.emit(self, player)


## Co-op guests: the host's board count, nailed on or pulled off here to match.
func set_boards(count: int) -> void:
	while boards < count and add_board():
		pass
	while boards > count:
		remove_board()


func _animate(index: int, to: Transform3D, visible_after: bool) -> void:
	var board: MeshInstance3D = _board_nodes[index]
	if _tweens[index]:
		_tweens[index].kill()
	var tween: Tween = create_tween()
	_tweens[index] = tween
	if visible_after:
		tween.tween_property(board, "transform", to, ANIM_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(board, "transform", to, ANIM_TIME * 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(board.hide)
