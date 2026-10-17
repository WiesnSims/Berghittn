extends Node3D
## The Harmonika's tune made visible: a ring rolling out over the floor to the edge of its reach, and
## golden notes rising and swaying all around the player. Placed at the camera; built in code, gone
## after a moment. The polka itself comes with the M6 sounds.

const LIFETIME: float = 1.6
const RING_TIME: float = 0.5
const COLOR := Color(1.0, 0.85, 0.45, 0.85)
const RING_COLOR := Color(1.0, 0.85, 0.45, 0.2)
# Notes for a full polka; the Landler's puffs show a share of them (amount).
const NOTES: int = 16
const RISE: float = 1.3
# Below the eye: the floor, and where the notes start.
const FEET: float = -1.5

## Metres the tune reaches, and how much of it to show (1 = a full polka).
var reach: float = 8.0
var amount: float = 1.0


func _ready() -> void:
	# Level with the world, whatever the aim.
	basis = Basis.IDENTITY
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = COLOR
	if amount >= 1.0:
		_ring()
	for i: int in maxi(roundi(NOTES * amount), 1):
		_note(material)
	var fade := create_tween()
	fade.tween_interval(LIFETIME * 0.5)
	fade.tween_property(material, "albedo_color:a", 0.0, LIFETIME * 0.5)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 4
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = RING_COLOR
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, FEET + 0.1, 0.0)
	ring.scale = Vector3(0.5, 0.3, 0.5)
	add_child(ring)
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(reach, 0.3, reach), RING_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, RING_TIME).set_delay(RING_TIME * 0.5)


## An eighth note: an oval head, a stem and a flag, turned to face the player.
func _note(material: Material) -> void:
	var note := Node3D.new()
	var head := SphereMesh.new()
	head.radius = 0.07
	head.height = 0.1
	head.radial_segments = 8
	head.rings = 4
	_part(note, head, Vector3.ZERO, Vector3(1.0, 0.75, 0.4), material).rotation.z = 0.4
	var stem := BoxMesh.new()
	stem.size = Vector3(0.018, 0.26, 0.018)
	_part(note, stem, Vector3(0.06, 0.13, 0.0), Vector3.ONE, material)
	var flag := BoxMesh.new()
	flag.size = Vector3(0.1, 0.03, 0.018)
	_part(note, flag, Vector3(0.1, 0.22, 0.0), Vector3.ONE, material).rotation.z = -0.6
	add_child(note)
	var angle: float = randf() * TAU
	var out: float = lerpf(1.2, reach, sqrt(randf()))
	var start := Vector3(cos(angle) * out, FEET + randf_range(0.3, 1.2), sin(angle) * out)
	note.position = start
	note.scale = Vector3.ONE * randf_range(1.2, 2.0)
	# Its face towards the player (the effect's origin), seen from where the note stands.
	note.rotation.y = atan2(start.x, start.z)
	var sway: float = randf_range(0.2, 0.4) * (1.0 if randf() < 0.5 else -1.0)
	var delay: float = randf() * 0.3
	var tween := create_tween().set_parallel()
	tween.tween_property(note, "position:y", start.y + RISE, LIFETIME - delay).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(note, "rotation:z", sway, LIFETIME * 0.5).set_delay(delay).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(note, "rotation:z", -sway, LIFETIME * 0.5).set_trans(Tween.TRANS_SINE)


func _part(note: Node3D, mesh: Mesh, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.scale = size
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	note.add_child(part)
	return part
