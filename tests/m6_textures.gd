extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m6_textures.tscn
## Headless check of the world textures (M6 part 3) on the real main scene: every texture is at most
## 256x256 and listed in ASSETS.md, all of them together stay inside the 10 MB budget, every lit world
## material is textured and projected from the axes (triplanar; moving boards and doors in their own
## space), the props that borrowed a world colour have their own material, and the terrain shows its
## snow and rock textures.

const TEXTURES_DIR: String = "res://assets/textures"
const MATERIALS_DIR: String = "res://assets/materials"
const TEXTURE_SIZE_MAX: int = 256
## Hero assets (section 3: the weapons) may be 512.
const HERO: Array[String] = ["gun_wood.png", "gun_steel.png", "gun_forged.png"]
const HERO_SIZE_MAX: int = 512
const TEXTURE_BUDGET: int = 10 * 1024 * 1024
## Plain paint: the trail sign and the Speck keep a flat colour (props get models in M6 part 4).
const PLAIN: Array[String] = ["sign", "speck"]
## Parts that move (barricade boards ripped out, doors swinging open) keep their texture on them.
const MOVING: Array[String] = ["board", "door_locked"]
## Props that used to borrow a world material, and the ones they must not use any more.
const PROPS: Dictionary = {
	"Lager/Mattresses": ["snow", "pine", "door_locked"],
	"Schuppen/Hay": ["sign"],
	"Skiraum": ["pine", "stone"],
}

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _run() -> void:
	await get_tree().process_frame
	_textures()
	_materials()
	_props()
	_terrain()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _textures() -> void:
	var assets: String = FileAccess.get_file_as_string("res://ASSETS.md")
	var total: int = 0
	var count: int = 0
	for file: String in DirAccess.get_files_at(TEXTURES_DIR):
		if not file.ends_with(".png"):
			continue
		count += 1
		var path: String = TEXTURES_DIR.path_join(file)
		var texture := load(path) as Texture2D
		var most: int = HERO_SIZE_MAX if file in HERO else TEXTURE_SIZE_MAX
		_check(texture != null and texture.get_width() <= most and texture.get_height() <= most,
				"%s loads and is at most %d px (%s)" % [file, most, texture.get_size() if texture else "missing"])
		var base: String = file.get_basename().trim_suffix("_normal")
		_check(assets.contains("`%s`" % base), "%s is listed in ASSETS.md" % base)
		# The headless renderer does not report mipmaps, so this asks the import settings.
		var config := ConfigFile.new()
		config.load(path + ".import")
		_check(config.get_value("params", "mipmaps/generate", false), "%s has mipmaps" % file)
		_check(config.get_value("params", "detect_3d/compress_to", 1) == 0,
				"%s stays as imported (no GPU compression, which browsers support unevenly)" % file)
		var imported := FileAccess.open(config.get_value("remap", "path", ""), FileAccess.READ)
		total += imported.get_length() if imported else 0
	_check(count > 0, "there are textures (%d)" % count)
	_check(total > 0 and total < TEXTURE_BUDGET, "all textures take %.2f MiB, inside the 10 MB budget" % (total / 1048576.0))


func _materials() -> void:
	for file: String in DirAccess.get_files_at(MATERIALS_DIR):
		var name: String = file.get_basename()
		var material := load(MATERIALS_DIR.path_join(file)) as BaseMaterial3D
		if material == null or material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or name in PLAIN:
			continue
		_check(material.albedo_texture != null, "%s is textured" % name)
		_check(material.uv1_triplanar, "%s is projected from the axes" % name)
		_check(material.uv1_world_triplanar != (name in MOVING),
				"%s is projected in %s space" % [name, "its own" if name in MOVING else "world"])
		if material.normal_enabled:
			_check(material.normal_texture != null, "%s has its normal map" % name)


func _props() -> void:
	var zones: Node = main.get_node("World")
	for path: String in PROPS:
		var root: Node = zones.get_node_or_null(path)
		_check(root != null, "%s is in the map" % path)
		if root == null:
			continue
		var borrowed: Array[String] = []
		for node: Node in root.find_children("*", "CSGShape3D", true, false):
			var material: Material = node.get("material")
			if material and material.resource_path.get_file().get_basename() in PROPS[path]:
				borrowed.append(node.name)
		_check(borrowed.is_empty(), "%s has its own materials (still borrowed: %s)" % [path, borrowed])


func _terrain() -> void:
	var terrain := get_tree().get_first_node_in_group("alm_terrain") as AlmTerrain
	var ground := terrain.get_node_or_null("Ground") as MeshInstance3D if terrain else null
	var material := ground.mesh.surface_get_material(0) as ShaderMaterial if ground else null
	_check(material != null, "the terrain has its ground material")
	if material:
		_check(material.get_shader_parameter(&"snow_texture") is Texture2D
				and material.get_shader_parameter(&"rock_texture") is Texture2D, "the terrain shows snow and rock textures")
		_check(is_equal_approx(material.get_shader_parameter(&"rock_steepness"), terrain.rock_steepness),
				"the terrain turns to rock where the faces are steep")
