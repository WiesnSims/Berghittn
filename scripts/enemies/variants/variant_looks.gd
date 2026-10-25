extends Node3D
## What the rare variants (Die Bsundan, 1.2) build in code, in one piece for the shader warm-up: the
## Sprengmeister's fuse sparks, the Influencer's LIVE, the Bergführer's rope.


func _ready() -> void:
	var sparks: CPUParticles3D = preload("res://scripts/enemies/variants/sprengmeister.gd").build_sparks()
	sparks.top_level = false
	add_child(sparks)
	var label: Label3D = preload("res://scripts/enemies/variants/influencer.gd").live_label()
	label.top_level = false
	add_child(label)
	var rope := MeshInstance3D.new()
	rope.mesh = preload("res://scripts/enemies/variants/bergfuehrer.gd").rope_mesh()
	add_child(rope)
