extends Node
## Turns the weapons' greybox parts into low-poly models (M6 part 4b), in place, keeping every node
## (the viewmodel scripts animate them by name); the rules are in reshape.gd.
##
##     godot --headless res://tools/models/build_weapons.tscn
##
## (A scene, not --script: the viewmodel scripts need the autoloads to compile.)

const Reshape := preload("res://tools/models/reshape.gd")
const DIR: String = "res://scenes/weapons"


func _ready() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		if file.ends_with(".tscn"):
			_build(DIR.path_join(file))
	get_tree().quit()


func _build(path: String) -> void:
	var reshape := Reshape.new()
	var root: Node = (load(path) as PackedScene).instantiate()
	var count: int = reshape.meshes(root)
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, path)
	root.free()
	print("%s: %d boxes reshaped" % [path.get_file(), count])
