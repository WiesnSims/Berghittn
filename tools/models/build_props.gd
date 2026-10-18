extends Node
## Turns the props' greybox parts into low-poly models (M6 part 4c), in place, keeping every node;
## the rules are in reshape.gd:
##
##     godot --headless res://tools/models/build_props.tscn
##
## (A scene, not --script: the prop scripts need the autoloads to compile.) The zones get looks for
## their furniture CSG boxes; the prop, event and equipment scenes get both.

const Reshape := preload("res://tools/models/reshape.gd")
const DIRS: Array[String] = ["res://scenes/zones", "res://scenes/props", "res://scenes/events", "res://scenes/equipment"]
## Non-metal colours per scene (see Reshape.organic): the animals are fur. (The guest is a character
## model, built by build_enemies.)
const ORGANIC: Dictionary = {
	"resi_model.tscn": &"fur",
	"murmeltier_model.tscn": &"fur",
}


func _ready() -> void:
	for dir: String in DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn"):
				_build(dir.path_join(file))
	get_tree().quit()


func _build(path: String) -> void:
	var reshape := Reshape.new()
	reshape.organic = ORGANIC.get(path.get_file(), &"")
	var root: Node = (load(path) as PackedScene).instantiate()
	var boxes: int = reshape.meshes(root)
	var furniture: int = reshape.csg(root)
	if boxes == 0 and furniture == 0 and not reshape.changed():
		root.free()
		return
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, path)
	root.free()
	print("%s: %d boxes reshaped, %d furniture looks" % [path.get_file(), boxes, furniture])
