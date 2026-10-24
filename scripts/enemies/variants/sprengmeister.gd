extends EnemyVariant
## Da Sprengmeister (Die Bsundan, 1.2): with a player within SPRENG_LIGHT_RANGE in sight he lights
## the fuse, hurries on and goes up SPRENG_FUSE_TIME later; he goes up whenever he dies, lit or not.
## The blast hurts players in it (nothing solid between) and every enemy in it, paid to his killer.

const BLAST: Script = preload("res://scripts/perks/boeller_blast.gd")

var lit: bool = false
var fuse_left: float = 0.0
var _sparks: CPUParticles3D


func activated() -> void:
	super()
	lit = false
	fuse_left = 0.0
	_burning(false)


func tick(delta: float) -> void:
	if lit:
		fuse_left -= delta
		if fuse_left <= 0.0:
			enemy.kill_self()
		return
	var target: Node3D = enemy.target()
	if not is_instance_valid(target) or not enemy.free_to_act():
		return
	var offset: Vector3 = target.global_position - enemy.global_position
	if Vector2(offset.x, offset.z).length() > Constants.SPRENG_LIGHT_RANGE:
		return
	if not clear(enemy.mouth(), target.global_position + Vector3.UP * 1.2):
		return
	light()


## The fuse is lit (also used by tests).
func light() -> void:
	lit = true
	fuse_left = Constants.SPRENG_FUSE_TIME
	enemy.speed_scale = Constants.SPRENG_FUSE_SPEED / enemy.data.speed
	Gredn.now(enemy, Gredn.Moment.FUSE)
	signal_cue(&"fuse")


func died(source: Node3D) -> void:
	_burning(false)
	var at: Vector3 = enemy.global_position
	var blast := Node3D.new()
	blast.set_script(BLAST)
	blast.set("radius", Constants.SPRENG_RADIUS)
	enemy.get_parent().add_child(blast)
	blast.global_position = at
	if not deciding():
		return
	var middle: Vector3 = at + Vector3.UP
	for body: Node3D in targets():
		var chest: Vector3 = body.global_position + Vector3.UP
		var distance: float = middle.distance_to(chest)
		if distance > Constants.SPRENG_RADIUS or not clear(middle, chest):
			continue
		var share: float = lerpf(1.0, Constants.SPRENG_EDGE, distance / Constants.SPRENG_RADIUS)
		body.take_damage(roundi(Constants.SPRENG_PLAYER_DAMAGE * share), enemy)
	for other: Enemy in others():
		var chest: Vector3 = other.global_position + Vector3.UP
		if middle.distance_to(chest) <= Constants.SPRENG_RADIUS and clear(middle, chest):
			other.receive_hit(Constants.SPRENG_ENEMY_DAMAGE, false, false, source)


func show_cue(cue: StringName, _arg: Variant) -> void:
	if cue == &"fuse":
		lit = true
		_burning(true)
		Sound.play_at(&"fuse_hiss", enemy.mouth())


func _process(_delta: float) -> void:
	if _sparks and _sparks.emitting and enemy.rig():
		_sparks.global_position = enemy.rig().point_on(&"hand_r", Constants.SPRENG_FUSE_POINT * enemy.rig().build_scale)


func _burning(on: bool) -> void:
	if on and _sparks == null:
		_sparks = build_sparks()
		add_child(_sparks)
	if _sparks:
		_sparks.emitting = on


## The fuse's sparks (also drawn by the shader warm-up).
static func build_sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.top_level = true
	sparks.amount = 30
	sparks.lifetime = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.5
	sparks.gravity = Vector3(0, -6, 0)
	var spark := BoxMesh.new()
	spark.size = Vector3(0.025, 0.025, 0.025)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.8, 0.35)
	spark.material = material
	sparks.mesh = spark
	sparks.emitting = false
	return sparks
