class_name GoasslViewmodel
extends MeleeViewmodel
## Goaßl: a short wooden handle with a braided lash of eight links, thinning to the white cracker at the
## end. The crack is swung overhead: the lash curls back on the wind-up, snaps out straight at the blow
## and hangs after. Held as the lash (hold V), the handle points at the caught body and the lash
## stretches out to it.

## How far the lash curls back on the wind-up and whips past straight at the crack (radians a link).
@export var curl_back: float = 0.38
@export var snap_past: float = -0.12
@export var hang: float = 0.2

@onready var _links: Array[Node3D] = _find_links()
@onready var _lash: Node3D = $Model/Lash

var _lashing: bool = false


func _ready() -> void:
	# Overhead, not sideways: from up over the right shoulder, across the view through the crosshair,
	# on to the lower left.
	start_pose = Transform3D(Basis.looking_at(Vector3(0.25, 1.0, 0.35), Vector3.BACK), Vector3(0.3, -0.12, -0.2))
	hit_pose = Transform3D(Basis.looking_at(Vector3(-0.4, 0.25, -1.0), Vector3.UP), Vector3(0.28, -0.25, -0.3))
	end_pose = Transform3D(Basis.looking_at(Vector3(-0.25, -0.7, -0.6), Vector3.UP), Vector3(0.08, -0.42, -0.3))
	super()


func play_swing(duration: float, hit_time: float) -> void:
	_lashing = false
	_lash.scale = Vector3.ONE
	super(duration, hit_time)
	var crack := create_tween()
	crack.tween_method(_curl, 0.0, curl_back, hit_time * 0.7).set_trans(Tween.TRANS_SINE)
	crack.tween_method(_curl, curl_back, snap_past, hit_time * 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	crack.tween_method(_curl, snap_past, hang, (duration - hit_time) * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_guard() -> void:
	# The lash goes out straight; lash_to aims it every frame from here on.
	if _tween:
		_tween.kill()
	_model.visible = true
	_model.transform = hit_pose
	_curl(0.0)
	_lashing = true


func end_guard() -> void:
	_lashing = false
	_lash.scale = Vector3.ONE
	super()


## Points the handle at `point` (world space) and stretches the lash out to it.
func lash_to(point: Vector3) -> void:
	if not _lashing:
		return
	var from: Vector3 = _model.global_position
	var to: Vector3 = point - from
	if to.length() < 0.2:
		return
	_model.global_basis = Basis.looking_at(to.normalized(), Vector3.UP)
	# The lash's links run 1.2 m from the handle's end; stretched (thinly) to reach the body.
	_lash.scale = Vector3(1.0, 1.0, maxf(1.0, (to.length() - 0.3) / 1.2))


func _curl(amount: float) -> void:
	for i: int in _links.size():
		_links[i].rotation.x = amount * (0.6 + i * 0.12)


func _find_links() -> Array[Node3D]:
	var links: Array[Node3D] = []
	var node: Node = get_node("Model/Lash")
	while node.has_node("Link"):
		node = node.get_node("Link")
		links.append(node as Node3D)
	return links
