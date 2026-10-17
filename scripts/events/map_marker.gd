class_name MapMarker
extends Node3D
## Makes an event findable from anywhere on the map (section 8a): a tall light column over it and a
## name label, both drawn through walls, plus an arrow at the screen edge (MarkerArrows on the HUD)
## while it is off screen. Put it under the thing it marks.

## Translation key of the label.
@export var text: String = ""
@export var color: Color = Color(1.0, 0.85, 0.4)
@export var column_height: float = 40.0
## Where the label floats, above the marker's origin.
@export var label_height: float = 2.4

var _label: Label3D


func _ready() -> void:
	add_to_group("map_markers")
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.28
	mesh.height = column_height
	mesh.radial_segments = 10
	mesh.cap_top = false
	mesh.cap_bottom = false
	column.mesh = mesh
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.no_depth_test = true
	glow.albedo_color = Color(color.r, color.g, color.b, 0.22)
	column.material_override = glow
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Starts above the label, so up close it does not hide what it marks.
	column.position = Vector3.UP * (label_height + 0.6 + column_height * 0.5)
	add_child(column)
	_label = Label3D.new()
	_label.text = tr(text)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0012
	_label.font_size = 44
	_label.outline_size = 8
	_label.modulate = color
	_label.position = Vector3.UP * label_height
	add_child(_label)


## The point arrows and labels aim at.
func focus() -> Vector3:
	return global_position + Vector3.UP * label_height
