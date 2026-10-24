class_name ForgedLook
extends RefCounted
## The look of a dengelt weapon (M9 part 4): its steel and paint dark gold with engraved scrollwork, its wood
## darker and redder; doppelt dengelt brighter and more polished. Only colours, numbers and the
## steel's texture change, never the material's setup, so no new shader has to be built in the
## browser. One forged copy per material and level, shared by every model (kept on the material).

const ENGRAVED: Texture2D = preload("res://assets/textures/gun_forged.png")
const STEEL: String = "gun_steel"
# Painted parts (the Alphorn's bands, the Harmonika's case, the Rodel) are gilded like the steel, so
# the mostly wooden special weapons show it too.
const PAINTED: String = "painted_wood"


## Dresses every mesh under `model` for `level` (0 leaves it as it is).
static func apply(model: Node, level: int, golden: bool = false) -> void:
	if level <= 0 or model == null:
		return
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		# The muzzle flash stays fire.
		if mesh.mesh == null or _in_flash(mesh, model):
			continue
		for i: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i) as StandardMaterial3D
			if material:
				mesh.set_surface_override_material(i, forged(material, level, golden))


## Dresses `model` as `data` looks: forged by its level, all gold for the Golden Gun.
static func dress(model: Node, data: WeaponData) -> void:
	apply(model, data.level, data.golden)


static func _in_flash(node: Node, root: Node) -> bool:
	while node and node != root:
		if node.name == &"MuzzleFlash":
			return true
		node = node.get_parent()
	return false


## (`golden`: every part gold and engraved, wood and grip too.)
static func forged(material: StandardMaterial3D, level: int, golden: bool = false) -> StandardMaterial3D:
	var key: StringName = StringName("golden" if golden else "forged_%d" % level)
	if material.has_meta(key):
		return material.get_meta(key)
	var copy := material.duplicate() as StandardMaterial3D
	if golden:
		# Textured or not (plain ones already draw on a white texture), each keeps its setup.
		if material.albedo_texture:
			copy.albedo_texture = ENGRAVED
		copy.albedo_color = Constants.FORGED_GOLD[1]
		copy.metallic = Constants.FORGED_METALLIC[1]
		copy.roughness = Constants.FORGED_ROUGHNESS[1]
		material.set_meta(key, copy)
		return copy
	var texture: String = material.albedo_texture.resource_path if material.albedo_texture else ""
	var steel: bool = texture.contains(STEEL) or texture.contains(PAINTED)
	var metal: bool = steel or material.metallic >= 0.3
	var gold: Color = Constants.FORGED_GOLD[level - 1]
	if metal:
		if steel:
			copy.albedo_texture = ENGRAVED
		copy.albedo_color = gold
		copy.metallic = maxf(material.metallic, Constants.FORGED_METALLIC[level - 1])
		copy.roughness = minf(material.roughness, Constants.FORGED_ROUGHNESS[level - 1])
	else:
		# Wood and the rest: darker, a warmer red-brown, so the gold stands out.
		copy.albedo_color = material.albedo_color * Constants.FORGED_WOOD[level - 1]
	material.set_meta(key, copy)
	return copy
