extends NavigationRegion3D
## Bakes the zone navmesh at load instead of shipping a baked one, so greybox edits can never
## leave a stale navmesh behind. The Stube bakes in a few milliseconds.
##
## Source geometry comes from CSG collision faces, not Godot's built-in parser: that one reads
## CSG through visual meshes, which stalls on the GPU and warns in the browser console.

## Nodes under this root (default: the parent zone) are scanned for colliding CSG shapes.
@export var source_root: Node3D


func _ready() -> void:
	# CSG builds its geometry deferred; wait a frame so the walls exist.
	await get_tree().process_frame
	var started: int = Time.get_ticks_usec()
	var source := NavigationMeshSourceGeometryData3D.new()
	_add_csg_faces(source_root if source_root else get_parent(), source)
	var baked: NavigationMesh = navigation_mesh.duplicate()
	# Synchronous: the web build has no thread support.
	NavigationServer3D.bake_from_source_geometry_data(baked, source)
	# Must be a new resource: Godot 4.7 does not push an in-place rebake to the navigation server.
	navigation_mesh = baked
	print_verbose("Navmesh %s baked in %.1f ms, %d polygons" % [name, (Time.get_ticks_usec() - started) / 1000.0, baked.get_polygon_count()])


func _add_csg_faces(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	var csg := node as CSGShape3D
	if csg and csg.is_root_shape():
		# Child shapes are already merged into their root's faces.
		if csg.use_collision and csg.collision_layer & navigation_mesh.geometry_collision_mask:
			var shape: ConcavePolygonShape3D = csg.bake_collision_shape()
			if shape:
				source.add_faces(shape.get_faces(), csg.global_transform)
		return
	for child: Node in node.get_children():
		_add_csg_faces(child, source)
