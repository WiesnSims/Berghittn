extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m6_props.tscn
## Headless check of the prop models (M6 part 4c): no greybox box is left in the prop, event and
## equipment scenes; every CSG shape that is no longer drawn has its look, holding all its parts
## (and every look's CSG is hidden, so nothing is drawn twice); the furniture still
## collides where it stands (a ray from above stops on each table top in the Stube); and the
## Deitscha Tourist is a character rig like the enemies.

const DIRS: Array[String] = ["res://scenes/zones", "res://scenes/props", "res://scenes/events", "res://scenes/equipment"]

var failures: Array[String] = []


func _ready() -> void:
	for dir: String in DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn"):
				_scene(dir.path_join(file))
	var guest := (load("res://scenes/events/tourist_guest.tscn") as PackedScene).instantiate()
	_check(guest.get_node("Model") is EnemyRig, "the Deitscha Tourist is a character rig")
	guest.free()
	await _tables()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _scene(path: String) -> void:
	var root: Node = (load(path) as PackedScene).instantiate()
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	var boxes: Array[String] = []
	var bare: Array[String] = []
	var doubled: Array[String] = []
	var looks: int = 0
	for node: Node in nodes:
		if node.owner != root and node != root:
			continue
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
			boxes.append(String(node.name))
		if node.name == &"Look":
			looks += 1
			var top := node.get_parent() as CSGShape3D
			if top == null or not top.is_root_shape() or top.layers != 0:
				doubled.append(String(root.get_path_to(node)))
		var shape := node as CSGShape3D
		if shape and shape.is_root_shape() and shape.layers == 0:
			var look := shape.get_node_or_null("Look") as MeshInstance3D
			var parts: int = shape.find_children("*", "CSGShape3D", true, false).filter(func(n: Node) -> bool: return n is CSGBox3D or n is CSGCylinder3D).size()
			parts += 1 if shape is CSGBox3D or shape is CSGCylinder3D else 0
			# Its look holds every part: at least the chamfered box's 26 faces per part.
			if look == null or look.mesh == null or _faces(look.mesh) < parts * 12:
				bare.append(String(root.get_path_to(node)))
	var name: String = path.get_file().get_basename()
	_check(boxes.is_empty(), "%s: no greybox boxes %s" % [name, boxes])
	_check(bare.is_empty(), "%s: every hidden CSG shape has its look (%d looks) %s" % [name, looks, bare])
	_check(doubled.is_empty(), "%s: no look over a CSG that is still drawn %s" % [name, doubled])
	root.free()


func _faces(mesh: Mesh) -> int:
	var total: int = 0
	for i: int in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _tables() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i: int in 3:
		await get_tree().physics_frame
	var tables: Array[Node] = main.find_children("Table*", "CSGCombiner3D", true, false)
	_check(tables.size() >= 5, "the Stube's tables are there (%d)" % tables.size())
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	for table: Node in tables:
		var top := table.get_node("Top") as CSGBox3D
		var at: Vector3 = top.global_position
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, at + Vector3.DOWN * 1.0, Constants.LAYER_WORLD)
		var hit: Dictionary = space.intersect_ray(query)
		var height: float = at.y + top.size.y * 0.5
		_check(not hit.is_empty() and absf((hit.position as Vector3).y - height) < 0.02,
				"%s still collides at its top (%.2f m)" % [table.name, (hit.position as Vector3).y if not hit.is_empty() else -1.0])
	main.queue_free()
