extends Node3D
## The Repetierer's Querschläger: the bullet's path as a bright streak, one leg from hop to hop, each
## lit a moment after the last and fading out, then gone. `points` (world space) are set before it
## enters the tree.

const COLOR := Color(1.0, 0.85, 0.45)
const WIDTH: float = 0.03
## Seconds between one leg lighting up and the next, and how long each takes to fade.
const LEG_DELAY: float = 0.035
const FADE_TIME: float = 0.4

var points: PackedVector3Array = []


func _ready() -> void:
	global_transform = Transform3D.IDENTITY
	var tween: Tween = create_tween().set_parallel()
	for i: int in points.size() - 1:
		var from: Vector3 = points[i]
		var to: Vector3 = points[i + 1]
		var length: float = from.distance_to(to)
		if length < 0.05:
			continue
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = COLOR
		var mesh := BoxMesh.new()
		mesh.size = Vector3(WIDTH, WIDTH, length)
		var leg := MeshInstance3D.new()
		leg.mesh = mesh
		leg.material_override = material
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leg.visible = false
		add_child(leg)
		var along: Vector3 = (to - from) / length
		var up: Vector3 = Vector3.RIGHT if absf(along.y) > 0.99 else Vector3.UP
		leg.global_transform = Transform3D(Basis.looking_at(along, up), (from + to) * 0.5)
		var start: float = i * LEG_DELAY
		tween.tween_callback(leg.show).set_delay(start)
		tween.tween_property(material, "albedo_color:a", 0.0, FADE_TIME).set_delay(start).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
