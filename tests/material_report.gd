extends Node
## Which material setups the game draws with (#78): every material of the world, the weapons, the
## enemies, the hikers and the effects, grouped by the settings that make Godot generate a different
## shader for it. Each group is one set of shaders the browser compiles on a first visit.
##   godot --headless res://tests/material_report.tscn

const WEAPONS_DIR: String = "res://data/weapons"
const ENEMIES_DIR: String = "res://data/enemies"
# Properties that only feed uniforms, not the shader code.
const UNIFORMS: Array[String] = ["albedo_color", "roughness", "metallic", "metallic_specular", "emission",
	"emission_energy_multiplier", "uv1_scale", "uv1_offset", "uv2_scale", "uv2_offset", "uv1_triplanar_sharpness",
	"uv2_triplanar_sharpness", "render_priority", "grow_amount", "alpha_scissor_threshold", "point_size",
	"normal_scale", "rim", "rim_tint", "clearcoat", "clearcoat_roughness", "anisotropy", "ao_light_affect",
	"heightmap_scale", "subsurf_scatter_strength", "refraction_scale", "distance_fade_min_distance",
	"distance_fade_max_distance", "proximity_fade_distance", "msdf_pixel_range", "msdf_outline_size",
	"alpha_hash_scale", "alpha_antialiasing_edge", "particles_anim_h_frames", "particles_anim_v_frames",
	"stencil_reference", "stencil_color", "stencil_outline_thickness", "emission_intensity", "backlight",
	"z_clip_scale", "fov_override", "next_pass", "resource_name", "resource_path", "resource_local_to_scene",
	"resource_scene_unique_id", "script", "emission_energy", "roughness_texture_channel", "metallic_texture_channel"]


func _ready() -> void:
	var materials: Dictionary = {}
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	_collect(main, "world", materials)
	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		var weapon := load(WEAPONS_DIR.path_join(file)) as WeaponData
		if weapon and weapon.viewmodel:
			var model: Node = weapon.viewmodel.instantiate()
			_collect(model, "weapon " + String(weapon.id), materials)
			model.free()
	for file: String in DirAccess.get_files_at(ENEMIES_DIR):
		var enemy := load(ENEMIES_DIR.path_join(file)) as EnemyData
		if enemy and enemy.model:
			var model: Node = enemy.model.instantiate()
			_collect(model, "enemy " + String(enemy.id), materials)
			model.free()
	var hiker: Node = (load("res://scenes/net/hiker.tscn") as PackedScene).instantiate()
	_collect(hiker, "hiker", materials)
	hiker.free()
	var groups: Dictionary = {}
	for material: Material in materials:
		var key: String = _key(material)
		if not groups.has(key):
			groups[key] = []
		groups[key].append("%s (%s)" % [_name(material), materials[material]])
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a].size() > groups[b].size())
	print("%d materials in %d shader setups" % [materials.size(), keys.size()])
	for key: String in keys:
		print("\n[%d] %s" % [groups[key].size(), key])
		for entry: String in groups[key] as Array:
			print("     " + entry)
	get_tree().quit()


func _collect(root: Node, where: String, into: Dictionary) -> void:
	for node: Node in [root] + root.find_children("*", "", true, false):
		var found: Array[Material] = []
		var geometry := node as GeometryInstance3D
		if geometry and geometry.material_override:
			found.append(geometry.material_override)
		var mesh_instance := node as MeshInstance3D
		if mesh_instance and mesh_instance.mesh:
			for i: int in mesh_instance.mesh.get_surface_count():
				found.append(mesh_instance.get_active_material(i))
		var multimesh := node as MultiMeshInstance3D
		if multimesh and multimesh.multimesh and multimesh.multimesh.mesh:
			for i: int in multimesh.multimesh.mesh.get_surface_count():
				found.append(multimesh.multimesh.mesh.surface_get_material(i))
		var csg := node as CSGPrimitive3D
		if csg and "material" in csg:
			found.append(csg.get("material"))
		var particles := node as CPUParticles3D
		if particles and particles.mesh:
			found.append(particles.mesh.surface_get_material(0))
		for material: Material in found:
			if material and not into.has(material):
				into[material] = where + " " + String(node.name)


func _key(material: Material) -> String:
	var shader_material := material as ShaderMaterial
	if shader_material:
		return "ShaderMaterial " + (shader_material.shader.resource_path if shader_material.shader else "?")
	var parts: PackedStringArray = []
	for property: Dictionary in material.get_property_list():
		var name: String = property["name"]
		if name in UNIFORMS or not (property["usage"] & PROPERTY_USAGE_STORAGE):
			continue
		var value: Variant = material.get(name)
		match typeof(value):
			TYPE_BOOL, TYPE_INT:
				parts.append("%s=%s" % [name, value])
			TYPE_OBJECT:
				if value is Texture:
					parts.append("%s" % name)
	return " ".join(parts)


func _name(material: Material) -> String:
	if material.resource_path != "" and not material.resource_path.contains("::"):
		return material.resource_path.get_file()
	return material.resource_name if material.resource_name != "" else material.resource_path.get_file()
