extends NavigationRegion3D
## Bakes the map navmesh at load instead of shipping a baked one, so greybox edits can never
## leave a stale navmesh behind. Rebakes when a door opens, so enemies path through it.
##
## Source geometry comes from CSG collision faces, not Godot's built-in parser: that one reads
## CSG through visual meshes, which stalls on the GPU and warns in the browser console.

## Nodes under this root (default: the parent) are scanned for colliding CSG shapes.
@export var source_root: Node3D

# Faces of every colliding CSG shape, read once: building CSG collision is the slow part, and
# only doors change after load (they stop colliding when opened).
var _shapes: Array[CSGShape3D] = []
var _faces: Array[PackedVector3Array] = []
var _rebake_queued: bool = false


func _ready() -> void:
	Events.zone_unlocked.connect(_queue_rebake.unbind(2))
	# CSG builds its geometry deferred; wait a frame so the walls exist.
	await get_tree().process_frame
	_collect(source_root if source_root else get_parent())
	_bake()


func _queue_rebake() -> void:
	# Deferred: the doors switch their collision off in the same signal, maybe after this handler.
	if not _rebake_queued:
		_rebake_queued = true
		_bake.call_deferred()


func _bake() -> void:
	_rebake_queued = false
	var started: int = Time.get_ticks_usec()
	var source := NavigationMeshSourceGeometryData3D.new()
	for i: int in _shapes.size():
		var csg: CSGShape3D = _shapes[i]
		if is_instance_valid(csg) and csg.use_collision:
			source.add_faces(_faces[i], csg.global_transform)
	var baked: NavigationMesh = navigation_mesh.duplicate()
	# Synchronous: the web build has no thread support.
	NavigationServer3D.bake_from_source_geometry_data(baked, source)
	# Must be a new resource: Godot 4.7 does not push an in-place rebake to the navigation server.
	navigation_mesh = baked
	print_verbose("Navmesh %s baked in %.1f ms, %d polygons" % [name, (Time.get_ticks_usec() - started) / 1000.0, baked.get_polygon_count()])


func _collect(node: Node) -> void:
	var csg := node as CSGShape3D
	if csg and csg.is_root_shape():
		# Child shapes are already merged into their root's faces.
		if csg.use_collision and csg.collision_layer & navigation_mesh.geometry_collision_mask:
			var shape: ConcavePolygonShape3D = csg.bake_collision_shape()
			if shape:
				_shapes.append(csg)
				_faces.append(shape.get_faces())
		return
	for child: Node in node.get_children():
		_collect(child)
