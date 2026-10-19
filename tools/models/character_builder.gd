extends RefCounted
## Builds one low-poly character (M6 part 4): a Skeleton3D, its skinned meshes and the ragdoll's
## physical bones, saved as a scene. Shapes are tubes (rings lofted along a path), balls and boxes,
## each bound to one bone or blended between two, and tinted by vertex colour, so a handful of
## neutral, UV-mapped materials serve every costume. The head is a mesh of its own (group
## "head_part"), so a head pop can hide it.
##
## Positions are given for a figure of model_scale 1 (feet at 0, model facing -Z, its left at -X) and
## scaled on the way out, so the game never scales a physics body.

## Material id: path, texture (null = plain colour), metres per texture repeat, shading.
const MATERIALS: Dictionary = {
	&"wool": ["wool", 0.45],
	&"leather": ["leather", 0.35],
	&"fur": ["fur", 0.3],
	&"skin": ["skin", 0.6],
	&"linen": ["linen", 0.5],
	&"wood": ["painted_wood", 0.6],
	&"metal": ["metal", 0.5],
	&"plain": ["", 1.0],
	&"glow": ["", 1.0],
	# The player hiker's clothes (M7): white in the vertex colour, tinted per player at runtime.
	&"jacket": ["wool", 0.45],
	&"trousers": ["leather", 0.35],
}
const MATERIAL_DIR: String = "res://assets/materials/characters"
## The ragdoll's bodies; hands and feet ride on the forearms and shins.
const RAGDOLL: Array[StringName] = [&"hips", &"chest", &"head", &"arm_l", &"forearm_l", &"arm_r",
		&"forearm_r", &"thigh_l", &"shin_l", &"thigh_r", &"shin_r"]
## Share of the body's mass per bone (a 75 kg figure at scale 1).
const MASS: Dictionary = {&"hips": 12.0, &"chest": 16.0, &"head": 5.0, &"arm_l": 2.5, &"forearm_l": 2.0,
		&"arm_r": 2.5, &"forearm_r": 2.0, &"thigh_l": 8.0, &"shin_l": 4.5, &"thigh_r": 8.0, &"shin_r": 4.5}

var scale: float = 1.0
## Bone name -> [parent name, position at scale 1].
var _bones: Dictionary = {}
var _order: Array[StringName] = []
## Part ("body", "head", or any name set with part()) -> material id -> Surface. Each part becomes
## its own skinned mesh, so the game can swap parts (the hiker's heads and hats).
var _surfaces: Dictionary = {&"body": {}, &"head": {}}
var _part: StringName = &"body"
## Ragdoll body sizes: bone -> radius (limbs: capsules from the bone to its child), or a Vector3 box.
var _shapes: Dictionary = {}


func _init(model_scale: float) -> void:
	scale = model_scale


## The standard skeleton from its joints: pelvis, waist, neck, and on the left (mirrored to the right)
## shoulder, elbow, wrist, hip, knee and ankle. Also where the hand, foot and head end.
func skeleton(pelvis: Vector3, waist: Vector3, neck: Vector3, shoulder: Vector3, elbow: Vector3,
		wrist: Vector3, hip: Vector3, knee: Vector3, ankle: Vector3) -> void:
	_bone(&"hips", &"", pelvis)
	_bone(&"chest", &"hips", waist)
	_bone(&"head", &"chest", neck)
	for side: String in ["l", "r"]:
		var m: Vector3 = Vector3(1, 1, 1) if side == "l" else Vector3(-1, 1, 1)
		_bone(StringName("arm_" + side), &"chest", shoulder * m)
		_bone(StringName("forearm_" + side), StringName("arm_" + side), elbow * m)
		_bone(StringName("hand_" + side), StringName("forearm_" + side), wrist * m)
		_bone(StringName("thigh_" + side), &"hips", hip * m)
		_bone(StringName("shin_" + side), StringName("thigh_" + side), knee * m)
		_bone(StringName("foot_" + side), StringName("shin_" + side), ankle * m)


## Ragdoll thickness: limb capsule radius, torso box sizes, head radius (scale 1).
func ragdoll(limb_radii: Dictionary, hips_box: Vector3, chest_box: Vector3, head_radius: float) -> void:
	_shapes = limb_radii.duplicate()
	_shapes[&"hips"] = hips_box
	_shapes[&"chest"] = chest_box
	_shapes[&"head"] = head_radius


## The following shapes go on the head mesh (true) or the body (false).
func head(on: bool) -> void:
	part(&"head" if on else &"body")


## The following shapes go on the named part's mesh (parts named head* are in group "head_part").
func part(name: StringName) -> void:
	_part = name
	if not _surfaces.has(name):
		_surfaces[name] = {}


## Rings lofted along `path`; radii[i] is ring i's half width (x) and half depth (y). `rig` is a
## bone name for all rings, or one entry per ring: a bone name or [bone_a, bone_b, share_of_b].
func tube(path: Array, radii: Array, material: StringName, color: Color, rig: Variant, sides: int = 8,
		caps: bool = true, side_axis: Vector3 = Vector3.RIGHT) -> void:
	var s: Surface = _surface(material)
	var tile: float = MATERIALS[material][1]
	var rings: Array = []
	var length: float = 0.0
	for i: int in path.size():
		var p: Vector3 = path[i]
		var t: Vector3 = ((path[mini(i + 1, path.size() - 1)] as Vector3) - (path[maxi(i - 1, 0)] as Vector3)).normalized()
		var side: Vector3 = (side_axis - t * t.dot(side_axis)).normalized()
		if side.length_squared() < 0.5:
			side = (Vector3.BACK - t * t.dot(Vector3.BACK)).normalized()
		var depth: Vector3 = t.cross(side)
		if i > 0:
			length += p.distance_to(path[i - 1])
		var r: Vector2 = radii[i]
		var weights: Array = _weights(rig if rig is StringName or rig is String else (rig as Array)[i])
		var ring: Array[int] = []
		for k: int in sides + 1:
			var a: float = TAU * float(k) / float(sides)
			var offset: Vector3 = side * cos(a) * r.x + depth * sin(a) * r.y
			var normal: Vector3 = (side * cos(a) / maxf(r.x, 0.001) + depth * sin(a) / maxf(r.y, 0.001)).normalized()
			var around: float = PI * (r.x + r.y)
			ring.append(s.vertex(p + offset, normal, Vector2(float(k) / float(sides) * around, length) / tile, color, weights))
		rings.append(ring)
	for i: int in rings.size() - 1:
		for k: int in sides:
			s.quad(rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k])
	if not caps:
		return
	for end: int in [0, path.size() - 1]:
		var r: Vector2 = radii[end]
		if r.x < 0.002 and r.y < 0.002:
			continue
		var p: Vector3 = path[end]
		var out: Vector3 = (p - (path[1 if end == 0 else end - 1] as Vector3)).normalized()
		var weights: Array = _weights(rig if rig is StringName or rig is String else (rig as Array)[end])
		var centre: int = s.vertex(p, out, Vector2.ZERO, color, weights)
		var rim: Array[int] = []
		for k: int in sides + 1:
			var v: Vector3 = s.positions[rings[end][k]]
			rim.append(s.vertex(v, out, Vector2(v.x, v.z) / tile, color, weights))
		for k: int in sides:
			s.triangle(centre, rim[k], rim[k + 1])


## An ellipsoid, optionally turned by `basis`.
func ball(centre: Vector3, radii: Vector3, material: StringName, color: Color, rig: Variant,
		segments: int = 8, rings: int = 6, basis: Basis = Basis.IDENTITY) -> void:
	var s: Surface = _surface(material)
	var tile: float = MATERIALS[material][1]
	var weights: Array = _weights(rig)
	var rows: Array = []
	for j: int in rings + 1:
		var v: float = PI * float(j) / float(rings)
		var row: Array[int] = []
		for k: int in segments + 1:
			var u: float = TAU * float(k) / float(segments)
			var unit := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
			var normal: Vector3 = basis * Vector3(unit.x / radii.x, unit.y / radii.y, unit.z / radii.z).normalized()
			var uv := Vector2(float(k) / float(segments) * PI * (radii.x + radii.z), v * radii.y) / tile
			row.append(s.vertex(centre + basis * (unit * radii), normal, uv, color, weights))
		rows.append(row)
	for j: int in rings:
		for k: int in segments:
			s.quad(rows[j][k], rows[j][k + 1], rows[j + 1][k + 1], rows[j + 1][k])


## A box with flat faces; `taper` shrinks its top (+Y) face, so it also makes wedges and frustums.
func box(centre: Vector3, size: Vector3, material: StringName, color: Color, rig: Variant,
		basis: Basis = Basis.IDENTITY, taper: Vector2 = Vector2.ONE) -> void:
	var s: Surface = _surface(material)
	var tile: float = MATERIALS[material][1]
	var weights: Array = _weights(rig)
	var h: Vector3 = size * 0.5
	var corner := func(x: float, y: float, z: float) -> Vector3:
		var top: bool = y > 0.0
		var c := Vector3(x * h.x * (taper.x if top else 1.0), y * h.y, z * h.z * (taper.y if top else 1.0))
		return centre + basis * c
	var faces: Array = [
		[corner.call(-1, -1, -1), corner.call(1, -1, -1), corner.call(1, 1, -1), corner.call(-1, 1, -1)],
		[corner.call(1, -1, 1), corner.call(-1, -1, 1), corner.call(-1, 1, 1), corner.call(1, 1, 1)],
		[corner.call(-1, -1, 1), corner.call(-1, -1, -1), corner.call(-1, 1, -1), corner.call(-1, 1, 1)],
		[corner.call(1, -1, -1), corner.call(1, -1, 1), corner.call(1, 1, 1), corner.call(1, 1, -1)],
		[corner.call(-1, 1, -1), corner.call(1, 1, -1), corner.call(1, 1, 1), corner.call(-1, 1, 1)],
		[corner.call(-1, -1, 1), corner.call(1, -1, 1), corner.call(1, -1, -1), corner.call(-1, -1, -1)],
	]
	for face: Array in faces:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		var d: Vector3 = face[3]
		var normal: Vector3 = (b - a).cross(d - a).normalized()
		if normal.dot((a + c) * 0.5 - centre) < 0.0:
			normal = -normal
		var u: Vector3 = (b - a).normalized()
		var w: Vector3 = normal.cross(u)
		var ids: Array[int] = []
		for p: Vector3 in face:
			ids.append(s.vertex(p, normal, Vector2((p - a).dot(u), (p - a).dot(w)) / tile, color, weights))
		s.quad(ids[0], ids[1], ids[2], ids[3])


## A horn, claw, tooth or tuft: a tube that tapers to a point along `path`.
func spike(path: Array, base: float, material: StringName, color: Color, rig: Variant, sides: int = 6) -> void:
	var radii: Array = []
	for i: int in path.size():
		var r: float = base * (1.0 - float(i) / float(path.size() - 1)) + 0.001
		radii.append(Vector2(r, r))
	tube(path, radii, material, color, rig, sides)


## Builds the scene and saves it (and its meshes) next to `path`.
func save(path: String, root_name: String, rig_script: Script, settings: Dictionary) -> void:
	var root := Node3D.new()
	root.name = root_name
	root.set_script(rig_script)
	for key: String in settings:
		root.set(key, settings[key])
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	root.add_child(skeleton)
	for bone: StringName in _order:
		skeleton.add_bone(bone)
	for bone: StringName in _order:
		var index: int = skeleton.find_bone(bone)
		var parent: StringName = _bones[bone][0]
		var local: Vector3 = _bones[bone][1]
		if parent != &"":
			skeleton.set_bone_parent(index, skeleton.find_bone(parent))
			local -= _bones[parent][1]
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, local * scale))
	skeleton.reset_bone_poses()
	var skin: Skin = skeleton.create_skin_from_rest_transforms()
	for part: StringName in _surfaces:
		if (_surfaces[part] as Dictionary).is_empty():
			continue
		var mesh := ArrayMesh.new()
		for material: StringName in _surfaces[part]:
			var s: Surface = _surfaces[part][material]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s.arrays(scale, skeleton, _order))
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material(material))
		var mesh_path: String = path.get_basename() + "_" + part + ".res"
		ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
		mesh.take_over_path(mesh_path)
		var instance := MeshInstance3D.new()
		instance.name = String(part).to_pascal_case()
		instance.mesh = mesh
		instance.skin = skin
		skeleton.add_child(instance)
		instance.skeleton = NodePath("..")
		if String(part).begins_with("head"):
			instance.add_to_group(&"head_part", true)
	skeleton.add_child(_ragdoll(skeleton))
	for node: Node in root.find_children("*", "", true, false):
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, path)
	root.free()


## Saves every part as a plain, unskinned mesh at `prefix` + "_" + part + ".res", for props that never
## move (the Stube's stuffed animals); bones given to the shapes are ignored.
func save_static(prefix: String) -> void:
	for part: StringName in _surfaces:
		if (_surfaces[part] as Dictionary).is_empty():
			continue
		var mesh := ArrayMesh.new()
		for material: StringName in _surfaces[part]:
			var s: Surface = _surfaces[part][material]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s.static_arrays(scale))
			mesh.surface_set_material(mesh.get_surface_count() - 1, _material(material))
		var mesh_path: String = prefix + "_" + part + ".res"
		ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
		mesh.take_over_path(mesh_path)


func _ragdoll(skeleton: Skeleton3D) -> PhysicalBoneSimulator3D:
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	# Off until death: no bodies in the physics space while it walks.
	simulator.process_mode = Node.PROCESS_MODE_DISABLED
	for bone: StringName in RAGDOLL:
		var origin: Vector3 = _bones[bone][1]
		var child: Vector3 = _child_position(bone)
		var direction: Vector3 = child - origin
		var body := PhysicalBone3D.new()
		body.name = String(bone)
		body.bone_name = bone
		body.mass = MASS[bone] * scale * scale * scale
		body.friction = 0.9
		body.linear_damp = 0.3
		body.angular_damp = 3.0
		body.collision_layer = 0
		body.collision_mask = 1
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var size: Variant = _shapes[bone]
		var centre: Vector3 = (origin + child) * 0.5
		if bone == &"head":
			var sphere := SphereShape3D.new()
			sphere.radius = size * scale
			shape.shape = sphere
			centre = origin + Vector3(0.0, size, 0.0)
		elif size is Vector3:
			var cube := BoxShape3D.new()
			cube.size = size * scale
			shape.shape = cube
		else:
			var capsule := CapsuleShape3D.new()
			capsule.radius = size * scale
			capsule.height = maxf(direction.length() * scale, capsule.radius * 2.0 + 0.01)
			shape.shape = capsule
		body.add_child(shape)
		# The body sits mid-bone with its Y along the bone; the joint is at the bone's own origin.
		var y: Vector3 = direction.normalized() if bone != &"head" else Vector3.UP
		var x: Vector3 = (Vector3.RIGHT - y * y.dot(Vector3.RIGHT)).normalized()
		if x.length_squared() < 0.5:
			x = (Vector3.BACK - y * y.dot(Vector3.BACK)).normalized()
		var basis := Basis(x, y, x.cross(y))
		body.body_offset = Transform3D(basis, (centre - origin) * scale)
		body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		# Twist axis (X) along the bone.
		body.joint_offset = Transform3D(Basis(Vector3.UP, Vector3.LEFT, Vector3.BACK), basis.inverse() * ((origin - centre) * scale))
		var swing: float = 30.0 if bone == &"chest" else 50.0 if bone == &"head" else 70.0
		body.set("joint_constraints/swing_span", swing)
		body.set("joint_constraints/twist_span", 20.0)
		body.set("joint_constraints/softness", 0.8)
		body.set("joint_constraints/relaxation", 1.0)
		simulator.add_child(body)
	return simulator


func _child_position(bone: StringName) -> Vector3:
	match bone:
		&"hips":
			return _bones[&"chest"][1]
		&"chest":
			return _bones[&"head"][1]
		&"head":
			return _bones[&"head"][1] + Vector3.UP * 0.25
	for other: StringName in _order:
		if _bones[other][0] == bone:
			return _bones[other][1]
	return _bones[bone][1] + Vector3.DOWN * 0.2


func _bone(name: StringName, parent: StringName, at: Vector3) -> void:
	_bones[name] = [parent, at]
	_order.append(name)


func _weights(rig: Variant) -> Array:
	if rig is Array:
		return [[StringName(rig[0]), 1.0 - float(rig[2])], [StringName(rig[1]), float(rig[2])]]
	return [[StringName(rig), 1.0]]


func _surface(material: StringName) -> Surface:
	var surfaces: Dictionary = _surfaces[_part]
	if not surfaces.has(material):
		surfaces[material] = Surface.new()
	return surfaces[material]


## The shared character material: a neutral texture (light grey, average 0.8) tinted by the vertex
## colour, so the 1.25 brightness brings a tint back to its own colour.
func _material(id: StringName) -> StandardMaterial3D:
	var path: String = MATERIAL_DIR.path_join(String(id) + ".tres")
	if ResourceLoader.exists(path):
		return load(path)
	DirAccess.make_dir_recursive_absolute(MATERIAL_DIR)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	if id == &"glow":
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif String(MATERIALS[id][0]) != "":
		material.albedo_texture = load("res://assets/textures/%s.png" % MATERIALS[id][0])
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var neutral: bool = String(MATERIALS[id][0]) in ["wool", "leather", "fur", "skin", "painted_wood"]
		material.albedo_color = Color(1.25, 1.25, 1.25) if neutral else Color.WHITE
	if id == &"metal":
		material.metallic = 0.4
		material.roughness = 0.6
	ResourceSaver.save(material, path)
	material.take_over_path(path)
	return material


## One material's triangles: vertices with up to two bones each.
class Surface:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var bones: Array = []
	var indices := PackedInt32Array()

	func vertex(at: Vector3, normal: Vector3, uv: Vector2, color: Color, weights: Array) -> int:
		positions.append(at)
		normals.append(normal)
		uvs.append(uv)
		colors.append(color)
		bones.append(weights)
		return positions.size() - 1

	## Godot's front faces wind clockwise: each triangle is turned to face along its vertex normals.
	func triangle(a: int, b: int, c: int) -> void:
		var face: Vector3 = (positions[b] - positions[a]).cross(positions[c] - positions[a])
		if face.dot(normals[a] + normals[b] + normals[c]) > 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		triangle(a, b, c)
		triangle(a, c, d)

	func arrays(scale: float, skeleton: Skeleton3D, order: Array[StringName]) -> Array:
		var scaled := PackedVector3Array()
		var bone_ids := PackedInt32Array()
		var weights := PackedFloat32Array()
		for i: int in positions.size():
			scaled.append(positions[i] * scale)
			var entry: Array = bones[i]
			for k: int in 4:
				if k < entry.size():
					bone_ids.append(skeleton.find_bone(entry[k][0]))
					weights.append(entry[k][1])
				else:
					bone_ids.append(0)
					weights.append(0.0)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = scaled
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_BONES] = bone_ids
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		return arrays

	func static_arrays(scale: float) -> Array:
		var scaled := PackedVector3Array()
		for p: Vector3 in positions:
			scaled.append(p * scale)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = scaled
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		return arrays
