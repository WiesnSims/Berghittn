extends Node3D
## The sticky heap a Knödel leaves where it bursts, pooled. Every enemy that wades into it is slowed
## (EnemyData speed times the factor) for as long as it stands in it and a few seconds after. Sinks
## away at the end. Built in code: a flattened mound of dough with crumbs on top.

const SINK_TIME: float = 0.6

## Co-op (M7): another player's heap, as we see it: it slows nobody here (their game does that).
var harmless: bool = false
var _left: float = 0.0
var _radius: float = 0.0
var _slow_factor: float = 1.0
var _slow_time: float = 0.0
var _mound: Node3D


func _ready() -> void:
	_mound = Node3D.new()
	add_child(_mound)
	var dough := StandardMaterial3D.new()
	dough.albedo_color = Color(0.98, 0.88, 0.55)
	dough.roughness = 1.0
	# A faint glow of its own, so the heap still reads in the dark hut and the storm.
	dough.emission_enabled = true
	dough.emission = Color(0.35, 0.28, 0.12)
	var heap := SphereMesh.new()
	heap.radius = 1.0
	heap.height = 2.0
	heap.radial_segments = 14
	heap.rings = 5
	heap.material = dough
	var body := MeshInstance3D.new()
	body.mesh = heap
	# Flat and wide: a puddle of soggy bread, not a ball.
	body.scale = Vector3(1.0, 0.12, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mound.add_child(body)
	var crust := StandardMaterial3D.new()
	crust.albedo_color = Color(0.62, 0.42, 0.2)
	SharedLook.adopt(crust)
	var lump := BoxMesh.new()
	lump.size = Vector3(0.14, 0.08, 0.12)
	lump.material = crust
	for i: int in 6:
		var bit := MeshInstance3D.new()
		bit.mesh = lump
		var angle: float = i * 1.9
		bit.position = Vector3(cos(angle), 0.0, sin(angle)) * (0.25 + 0.1 * i) + Vector3.UP * 0.1
		bit.rotation.y = angle
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mound.add_child(bit)
	visible = false


func is_busy() -> bool:
	return _left > 0.0


func lay(at: Vector3, radius: float, time: float, slow_factor: float, slow_time: float) -> void:
	global_position = at
	_radius = radius
	_left = time
	_slow_factor = slow_factor
	_slow_time = slow_time
	_mound.scale = Vector3.ONE * radius
	visible = true


func radius() -> float:
	return _radius


func _physics_process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if not harmless:
		_slow_waders()
	if _left < SINK_TIME:
		_mound.scale = Vector3(_radius, _radius * maxf(_left / SINK_TIME, 0.01), _radius)
	if _left <= 0.0:
		visible = false


func _slow_waders() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var offset: Vector3 = enemy.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= _radius and absf(offset.y) < 1.0:
			enemy.apply_slow(_slow_factor, _slow_time)
