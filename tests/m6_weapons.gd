extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m6_weapons.tscn
## Headless check of the weapon models (M6 part 4b): in every viewmodel no part is a greybox box any
## more (each is a reshaped mesh that remembers its box), every lit colour is a textured material
## projected in the part's own space (so it rides along with a moving bolt or magazine), only
## near-white and near-black parts stay plain, and the weapons and the enemy models together stay
## inside the 3 MB model budget.

const WEAPONS_DIR: String = "res://scenes/weapons"
const ENEMY_MODELS_DIR: String = "res://assets/models"
const MODEL_BUDGET: int = 3 * 1024 * 1024

var failures: Array[String] = []


func _ready() -> void:
	var total: int = _size(ENEMY_MODELS_DIR)
	for file: String in DirAccess.get_files_at(WEAPONS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var path: String = WEAPONS_DIR.path_join(file)
		total += FileAccess.get_file_as_bytes(path).size()
		_weapon(path)
	_check(total < MODEL_BUDGET, "weapon and enemy models take %.2f MiB of the 3 MB budget" % (total / 1048576.0))
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _size(dir: String) -> int:
	var total: int = 0
	for sub: String in DirAccess.get_directories_at(dir):
		total += _size(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		total += FileAccess.get_file_as_bytes(dir.path_join(file)).size()
	return total


func _weapon(path: String) -> void:
	var root: Node = (load(path) as PackedScene).instantiate()
	var boxes: Array[String] = []
	var reshaped: int = 0
	var flat: Array[String] = []
	var textured: int = 0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh is BoxMesh:
			boxes.append(String(instance.name))
		elif instance.mesh is ArrayMesh and instance.mesh.get_meta("source", null) is BoxMesh:
			reshaped += 1
		for i: int in instance.mesh.get_surface_count() if instance.mesh else 0:
			var material := instance.mesh.surface_get_material(i) as StandardMaterial3D
			if material == null or material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
					or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.emission_enabled:
				continue
			if material.albedo_texture:
				textured += 1
				if not material.uv1_triplanar or material.uv1_world_triplanar:
					flat.append("%s (not projected in its own space)" % instance.name)
			else:
				var c: Color = material.albedo_color
				if not (c.v > 0.82 and c.s < 0.25 or c.v < 0.07):
					flat.append("%s (plain %s)" % [instance.name, c.to_html(false)])
	var weapon: String = path.get_file().get_basename()
	_check(boxes.is_empty(), "%s has no greybox boxes left %s" % [weapon, boxes])
	_check(reshaped > 0 or weapon == "alphorn_viewmodel", "%s: %d boxes reshaped" % [weapon, reshaped])
	_check(flat.is_empty() and textured > 0, "%s: %d textured parts, all in their own space%s" % [weapon, textured, "" if flat.is_empty() else " " + str(flat)])
	root.free()
