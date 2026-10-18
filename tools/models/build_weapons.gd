extends Node
## Turns the weapons' greybox parts into low-poly models (M6 part 4b), in place, keeping every node
## (the viewmodel scripts animate them by name):
##
##     godot --headless res://tools/models/build_weapons.tscn
##
## (A scene, not --script: the viewmodel scripts need the autoloads to compile.)
##
## - A long thin box (a barrel, rod, shaft or handle) becomes an eight-sided tube in the same box.
## - A box named Stock that runs along the gun gets a rifle stock's side profile: the wrist behind
##   the action, the comb, and the butt dropping to its toe.
## - Every other box gets chamfered edges.
## - Every lit colour becomes a textured material by what it looks like: brown is walnut, metal is
##   worn steel (tinted brass or copper where it was yellow or orange), other colours are painted
##   wood; near-white and near-black stay plain. Textures are projected in each part's own space, so
##   they ride along when a part moves.
## Each new mesh and material remembers the primitive or colour it came from (metadata "source"),
## so running this again rebuilds from the originals.

const DIR: String = "res://scenes/weapons"
## Material kind: texture, metres per repeat, metallic, roughness.
const KINDS: Dictionary = {
	&"wood": ["res://assets/textures/gun_wood.png", 0.35, 0.0, 0.7],
	&"steel": ["res://assets/textures/gun_steel.png", 0.3, 0.55, 0.45],
	&"brass": ["res://assets/textures/gun_steel.png", 0.3, 0.75, 0.35],
	&"paint": ["res://assets/textures/painted_wood.png", 0.4, 0.0, 0.85],
}
## A box is a rod when its length is this many times its thickness, and its two thin sides are close.
const ROD_LENGTH: float = 4.5
## Blocky parts that stay boxes, however long (a pistol's slide, a receiver).
const BLOCKS: Array[String] = ["Slide", "Receiver", "Magazine", "Body", "Box", "Action", "Breech", "Case"]
const ROD_ROUND: float = 1.8
const ROD_SIDES: int = 8
## Chamfer: this share of the box's thinnest side.
const BEVEL: float = 0.16

var _materials: Dictionary = {}


func _ready() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		if file.ends_with(".tscn"):
			_build(DIR.path_join(file))
	get_tree().quit()


func _build(path: String) -> void:
	_materials.clear()
	var root: Node = (load(path) as PackedScene).instantiate()
	var meshes: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.owner != root:
			continue
		var source: Mesh = instance.mesh.get_meta("source") if instance.mesh and instance.mesh.has_meta("source") else instance.mesh
		if not source is PrimitiveMesh or source is QuadMesh or source is PlaneMesh or source is TextMesh:
			continue
		var primitive := source as PrimitiveMesh
		var material: Material = _upgrade(primitive.material)
		if source is BoxMesh:
			instance.mesh = _box(source as BoxMesh, String(instance.name), material)
			meshes += 1
		elif primitive.material != material:
			var copy := primitive.duplicate() as PrimitiveMesh
			copy.material = material
			copy.set_meta("source", source)
			instance.mesh = copy
		if instance.material_override is StandardMaterial3D:
			instance.material_override = _upgrade(instance.material_override)
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, path)
	root.free()
	print("%s: %d boxes reshaped, %d materials" % [path.get_file(), meshes, _materials.size()])


## The textured material a greybox colour becomes (shared within a weapon), or the same one.
func _upgrade(material: Material) -> Material:
	var standard := material as StandardMaterial3D
	if standard == null:
		return material
	if standard.has_meta("source"):
		standard = standard.get_meta("source")
	if standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or standard.emission_enabled or standard.albedo_texture != null:
		return standard
	if _materials.has(standard):
		return _materials[standard]
	var kind: StringName = _kind(standard)
	if kind == &"":
		_materials[standard] = standard
		return standard
	var spec: Array = KINDS[kind]
	var textured := StandardMaterial3D.new()
	textured.albedo_texture = load(spec[0])
	# Neutral textures (light grey, average 0.8): 1.25 brings the tint back to the old colour.
	textured.albedo_color = Color(standard.albedo_color.r * 1.25, standard.albedo_color.g * 1.25, standard.albedo_color.b * 1.25)
	textured.metallic = spec[2]
	textured.roughness = spec[3]
	textured.uv1_triplanar = true
	textured.uv1_triplanar_sharpness = 4.0
	textured.uv1_scale = Vector3.ONE / float(spec[1])
	textured.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	textured.set_meta("source", standard)
	_materials[standard] = textured
	return textured


func _kind(material: StandardMaterial3D) -> StringName:
	var c: Color = material.albedo_color
	if c.v > 0.82 and c.s < 0.25 or c.v < 0.07:
		return &""
	if material.metallic >= 0.25:
		return &"brass" if c.s > 0.35 and c.h > 0.03 and c.h < 0.17 else &"steel"
	if c.h > 0.02 and c.h < 0.12 and c.s > 0.3 and c.v < 0.7:
		return &"wood"
	if c.s < 0.15 and c.v < 0.35:
		return &"steel"
	return &"paint"


func _box(source: BoxMesh, name: String, material: Material) -> ArrayMesh:
	var size: Vector3 = source.size
	var axis: int = 0 if size.x >= size.y and size.x >= size.z else 1 if size.y >= size.z else 2
	var others: Array[float] = []
	for i: int in 3:
		if i != axis:
			others.append(size[i])
	var thick: float = maxf(others[0], others[1])
	var thin: float = minf(others[0], others[1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if name.begins_with("Stock") and axis == 2 and size.z > size.y * 1.8:
		_stock(st, size)
	elif size[axis] >= thick * ROD_LENGTH and thick <= thin * ROD_ROUND and not BLOCKS.any(func(b: String) -> bool: return name.begins_with(b)):
		_rod(st, size, axis)
	else:
		_chamfered(st, size, minf(size.x, minf(size.y, size.z)) * BEVEL)
	st.set_material(material)
	var mesh: ArrayMesh = st.commit()
	mesh.set_meta("source", source)
	return mesh


## Godot's front faces wind clockwise: each triangle is turned to face along `normal`.
func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var points: Array = [a, b, c] if (b - a).cross(c - a).dot(normal) < 0.0 else [a, c, b]
	for p: Vector3 in points:
		st.set_normal(normal)
		st.add_vertex(p)


func _flat(st: SurfaceTool, points: Array[Vector3], centre: Vector3) -> void:
	# A convex face, fanned from its first corner, facing away from the centre.
	var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	if normal.dot(points[0] - centre) < 0.0:
		normal = -normal
	for i: int in range(1, points.size() - 1):
		_triangle(st, points[0], points[i], points[i + 1], normal)


func _chamfered(st: SurfaceTool, size: Vector3, bevel: float) -> void:
	var h: Vector3 = size * 0.5
	var inner: Vector3 = h - Vector3.ONE * bevel
	var corner := func(sx: float, sy: float, sz: float, cut: int) -> Vector3:
		# The corner of the given signs, pulled in by the bevel on every axis but `cut`.
		var p := Vector3(sx * inner.x, sy * inner.y, sz * inner.z)
		p[cut] = (Vector3(sx, sy, sz)[cut]) * h[cut]
		return p
	for a: int in 3:
		var b: int = (a + 1) % 3
		var c: int = (a + 2) % 3
		for s: float in [-1.0, 1.0]:
			# The face square to axis a.
			var face: Array[Vector3] = []
			for q: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := Vector3.ZERO
				p[a] = s * h[a]
				p[b] = q.x * inner[b]
				p[c] = q.y * inner[c]
				face.append(p)
			_flat(st, face, Vector3.ZERO)
			# The bevel along the edge between axis a and axis b, on both sides of c.
			for t: float in [-1.0, 1.0]:
				var signs := Vector3.ZERO
				signs[a] = s
				signs[b] = t
				var p0 := Vector3.ZERO
				p0[a] = s * h[a]
				p0[b] = t * inner[b]
				var p1 := Vector3.ZERO
				p1[a] = s * inner[a]
				p1[b] = t * h[b]
				var edge: Array[Vector3] = []
				for e: Vector3 in [p0, p1]:
					var lo: Vector3 = e
					lo[c] = -inner[c]
					edge.append(lo)
				for e: Vector3 in [p1, p0]:
					var hi: Vector3 = e
					hi[c] = inner[c]
					edge.append(hi)
				_flat(st, edge, Vector3.ZERO)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var tri: Array[Vector3] = [corner.call(sx, sy, sz, 0), corner.call(sx, sy, sz, 1), corner.call(sx, sy, sz, 2)]
				_flat(st, tri, Vector3.ZERO)


## An eight-sided tube filling the box along `axis`, with flat ends.
func _rod(st: SurfaceTool, size: Vector3, axis: int) -> void:
	var b: int = (axis + 1) % 3
	var c: int = (axis + 2) % 3
	var half: float = size[axis] * 0.5
	var ring := func(t: float, k: int) -> Vector3:
		var angle: float = TAU * (float(k) + 0.5) / float(ROD_SIDES)
		var p := Vector3.ZERO
		p[axis] = t
		# Out to the box's corners' middle: an octagon touching the box's sides.
		p[b] = cos(angle) * size[b] * 0.5 / cos(PI / ROD_SIDES)
		p[c] = sin(angle) * size[c] * 0.5 / cos(PI / ROD_SIDES)
		p[b] = clampf(p[b], -size[b] * 0.5, size[b] * 0.5)
		p[c] = clampf(p[c], -size[c] * 0.5, size[c] * 0.5)
		return p
	for k: int in ROD_SIDES:
		var a0: Vector3 = ring.call(-half, k)
		var a1: Vector3 = ring.call(-half, k + 1)
		var b0: Vector3 = ring.call(half, k)
		var b1: Vector3 = ring.call(half, k + 1)
		var mid0 := Vector3(a0.x, a0.y, a0.z)
		mid0[axis] = 0.0
		var mid1 := Vector3(a1.x, a1.y, a1.z)
		mid1[axis] = 0.0
		# Smooth sides: each corner keeps its own outward normal.
		var n0: Vector3 = mid0.normalized()
		var n1: Vector3 = mid1.normalized()
		var face: Vector3 = (n0 + n1).normalized()
		var winding: bool = (a1 - a0).cross(b0 - a0).dot(face) < 0.0
		var quad: Array = [[a0, n0], [a1, n1], [b1, n1], [b0, n0]] if winding else [[a0, n0], [b0, n0], [b1, n1], [a1, n1]]
		for tri: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
			for v: Array in tri:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	for end: float in [-half, half]:
		var cap: Array[Vector3] = []
		for k: int in ROD_SIDES:
			cap.append(ring.call(end, k))
		var centre := Vector3.ZERO
		centre[axis] = -end
		_flat(st, cap, centre)


## A rifle stock's side profile in the box (length along Z, the butt at +Z towards the shoulder),
## a little narrower at the wrist than at the butt.
func _stock(st: SurfaceTool, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	# (along 0..1 from the action to the butt, height 0..1 from the bottom), going round.
	var outline: Array[Vector2] = [Vector2(0.0, 0.5), Vector2(0.0, 1.0), Vector2(0.55, 0.97), Vector2(1.0, 0.9),
			Vector2(1.0, 0.0), Vector2(0.96, 0.0), Vector2(0.4, 0.38), Vector2(0.18, 0.42)]
	var profile := PackedVector2Array()
	for p: Vector2 in outline:
		profile.append(Vector2(lerpf(-h.z, h.z, p.x), lerpf(-h.y, h.y, p.y)))
	var width := func(z: float) -> float: return h.x * lerpf(0.75, 1.0, inverse_lerp(-h.z, h.z, z))
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(profile)
	for side: float in [-1.0, 1.0]:
		var normal := Vector3(side, 0.0, 0.0)
		for i: int in range(0, triangles.size(), 3):
			var points: Array[Vector3] = []
			for k: int in 3:
				var p: Vector2 = profile[triangles[i + k]]
				points.append(Vector3(side * width.call(p.x), p.y, p.x))
			_triangle(st, points[0], points[1], points[2], normal)
	# Which way the outline winds decides which side of each edge is outside.
	var area: float = 0.0
	for i: int in profile.size():
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[(i + 1) % profile.size()]
		area += p.x * q.y - q.x * p.y
	var turn: float = 1.0 if area > 0.0 else -1.0
	for i: int in profile.size():
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[(i + 1) % profile.size()]
		var quad: Array[Vector3] = [Vector3(-width.call(p.x), p.y, p.x), Vector3(width.call(p.x), p.y, p.x),
				Vector3(width.call(q.x), q.y, q.x), Vector3(-width.call(q.x), q.y, q.x)]
		var out: Vector2 = Vector2(q.y - p.y, -(q.x - p.x)).normalized() * turn
		var normal := Vector3(0.0, out.y, out.x)
		_triangle(st, quad[0], quad[1], quad[2], normal)
		_triangle(st, quad[0], quad[2], quad[3], normal)
