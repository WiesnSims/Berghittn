class_name AlmTerrain
extends Node3D
## The mountain around the hut, generated at load: a flat Alm (alpine pasture) for the play area that
## climbs towards the summit in the north and drops into the valley in the south, with pines below the
## tree line and rocks above it. Everything here is out of reach of players and enemies, so it has no
## collision; the walkable ground on the plateau is the Ground CSG in exterior.tscn.

## Centre of the plateau (middle of the hut) and the radius that stays flat. Metres.
@export var center: Vector2 = Vector2(7.0, 2.0)
@export var plateau_radius: float = 38.0
## Just below the walkable ground, so the two never flicker against each other.
@export var plateau_height: float = -0.32
## Side length of the generated square and of one grid cell. Metres.
@export var size: float = 300.0
@export var cell: float = 5.0
## Rise per metre beyond the plateau edge: on the sides, extra towards the summit (north) and the
## drop towards the valley (south). The summit side also curves up.
@export var side_slope: float = 0.12
@export var uphill_slope: float = 0.5
@export var downhill_slope: float = 0.6
@export var summit_curve: float = 0.0006
## Metres over which the slope eases in at the plateau edge, so there is no kink.
@export var edge_softness: float = 8.0
## Lumpiness, as a share of the distance beyond the edge.
@export var roughness: float = 0.18
## Faces steeper than this (normal Y below it) show bare rock instead of snow.
@export var rock_steepness: float = 0.8
@export var snow_color: Color = Color(0.78, 0.82, 0.88, 1)
@export var rock_color: Color = Color(0.32, 0.31, 0.3, 1)
## Pines grow only this far below the plateau (the Alm is above the tree line). Metres.
@export var tree_line: float = -5.0
@export var tree_count: int = 320
@export var rock_count: int = 160
@export var pine_material: Material
@export var rock_material: Material
@export var noise_seed: int = 1850

var _noise: FastNoiseLite = FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = noise_seed
	_noise.frequency = 0.012
	_noise.fractal_octaves = 3
	_build_ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	_scatter_trees(rng)
	_scatter_rocks(rng)


func height_at(x: float, z: float) -> float:
	var offset: Vector2 = Vector2(x, z) - center
	var distance: float = offset.length()
	var beyond: float = distance - plateau_radius
	if beyond <= 0.0:
		return plateau_height
	var eased: float = beyond * beyond / (beyond + edge_softness)
	# 1 straight north (towards the summit), -1 straight south (towards the valley).
	var north: float = -offset.y / distance
	var slope: float = side_slope + north * (uphill_slope if north > 0.0 else downhill_slope)
	var rise: float = eased * slope + maxf(north, 0.0) * summit_curve * eased * eased
	return plateau_height + rise + _noise.get_noise_2d(x, z) * roughness * eased


func _build_ground() -> void:
	var steps: int = int(size / cell)
	var origin: Vector2 = center - Vector2(size, size) * 0.5
	var heights := PackedFloat32Array()
	heights.resize((steps + 1) * (steps + 1))
	for iz: int in steps + 1:
		for ix: int in steps + 1:
			heights[iz * (steps + 1) + ix] = height_at(origin.x + ix * cell, origin.y + iz * cell)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var corner := func(ix: int, iz: int) -> Vector3:
		return Vector3(origin.x + ix * cell, heights[iz * (steps + 1) + ix], origin.y + iz * cell)
	for iz: int in steps:
		for ix: int in steps:
			var a: Vector3 = corner.call(ix, iz)
			var b: Vector3 = corner.call(ix + 1, iz)
			var c: Vector3 = corner.call(ix, iz + 1)
			var d: Vector3 = corner.call(ix + 1, iz + 1)
			_add_face(vertices, normals, colors, a, b, c)
			_add_face(vertices, normals, colors, b, d, c)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _add_face(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Flat shaded, one normal per face: the faceted early-2000s look.
	var normal: Vector3 = (c - a).cross(b - a).normalized()
	var color: Color = rock_color if normal.y < rock_steepness else snow_color
	# A little variation per face so the snow does not look like one sheet of plastic.
	color = color.darkened(absf(_noise.get_noise_2d(a.x * 7.0, a.z * 7.0)) * 0.12)
	for v: Vector3 in [a, b, c]:
		vertices.append(v)
		normals.append(normal)
		colors.append(color)


func _scatter_trees(rng: RandomNumberGenerator) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.5
	mesh.height = 6.0
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = pine_material
	var spots: Array[Transform3D] = []
	var tries: int = 0
	while spots.size() < tree_count and tries < tree_count * 20:
		tries += 1
		var at: Vector2 = _random_spot(rng)
		var y: float = height_at(at.x, at.y)
		if y > tree_line:
			continue
		var grow: float = rng.randf_range(0.7, 1.5)
		var turn := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(grow, grow * rng.randf_range(0.9, 1.3), grow))
		spots.append(Transform3D(turn, Vector3(at.x, y + mesh.height * 0.5 * turn.get_scale().y - 0.4, at.y)))
	_add_multimesh("Pines", mesh, spots)


func _scatter_rocks(rng: RandomNumberGenerator) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 3
	mesh.radius = 1.0
	mesh.height = 1.4
	mesh.material = rock_material
	var spots: Array[Transform3D] = []
	var tries: int = 0
	while spots.size() < rock_count and tries < rock_count * 20:
		tries += 1
		var at: Vector2 = _random_spot(rng)
		var y: float = height_at(at.x, at.y)
		# Above the tree line, and a few on the plateau rim.
		if y < tree_line:
			continue
		var stretch := Vector3(rng.randf_range(0.8, 3.5), rng.randf_range(0.6, 2.0), rng.randf_range(0.8, 3.5))
		var turn := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)).scaled(stretch)
		spots.append(Transform3D(turn, Vector3(at.x, y, at.y)))
	_add_multimesh("Rocks", mesh, spots)


## Somewhere off the plateau (with a margin, so nothing grows into the play area) and on the terrain.
func _random_spot(rng: RandomNumberGenerator) -> Vector2:
	var angle: float = rng.randf() * TAU
	var distance: float = rng.randf_range(plateau_radius + 2.0, size * 0.48)
	return center + Vector2(cos(angle), sin(angle)) * distance


func _add_multimesh(node_name: String, mesh: Mesh, spots: Array[Transform3D]) -> void:
	# One draw call for all of them.
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for i: int in spots.size():
		multimesh.set_instance_transform(i, spots[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
