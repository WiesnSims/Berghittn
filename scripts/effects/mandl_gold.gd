class_name MandlGold
extends Node3D
## The Venedigermandl's gold (M9 part 5a): a spark in the air as he appears, a few coins knocked out
## of his sack by each hit, the whole sack spilt in a fountain when he dies, and the puff of gold dust
## he vanishes in. One per Mandl, beside him (not under him, so it outlives his vanishing); each
## burst starts its own emitter over.

var _spark: CPUParticles3D
var _coins: CPUParticles3D
var _fountain: CPUParticles3D
var _dust: CPUParticles3D


func _ready() -> void:
	# Its own, not its parent's: the gold flies while the wave manager is stopped too.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.3)
	gold.metallic = 0.4
	gold.roughness = 0.35
	# Bright enough to catch the eye in the storm.
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.7, 0.2)
	gold.emission_energy_multiplier = 0.8
	var coin := CylinderMesh.new()
	coin.top_radius = 0.05
	coin.bottom_radius = 0.05
	coin.height = 0.01
	coin.radial_segments = 10
	coin.rings = 1
	_coins = _emitter(Constants.MANDL_HIT_COINS, 0.9, coin, gold)
	_coins.spread = 60.0
	_coins.initial_velocity_min = 2.0
	_coins.initial_velocity_max = 3.5
	_fountain = _emitter(Constants.MANDL_KILL_COINS, 1.6, coin, gold)
	_fountain.explosiveness = 0.6
	_fountain.spread = 35.0
	_fountain.initial_velocity_min = 4.0
	_fountain.initial_velocity_max = 7.0
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.4)
	var bit := BoxMesh.new()
	bit.size = Vector3(0.02, 0.06, 0.02)
	_spark = _emitter(36, 0.8, bit, glow)
	_spark.spread = 180.0
	_spark.gravity = Vector3(0.0, -2.0, 0.0)
	_spark.initial_velocity_min = 1.5
	_spark.initial_velocity_max = 3.5
	_spark.particle_flag_align_y = true
	var dust := StandardMaterial3D.new()
	dust.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust.vertex_color_use_as_albedo = true
	var puff := QuadMesh.new()
	puff.size = Vector2(0.5, 0.5)
	_dust = _emitter(40, 1.1, puff, dust)
	_dust.spread = 180.0
	_dust.gravity = Vector3(0.0, 0.6, 0.0)
	_dust.initial_velocity_min = 0.6
	_dust.initial_velocity_max = 1.8
	_dust.damping_min = 1.5
	_dust.damping_max = 2.5
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.85, 0.4, 0.9))
	fade.set_color(1, Color(1.0, 0.75, 0.3, 0.0))
	_dust.color_ramp = fade


func _emitter(amount: int, lifetime: float, mesh: Mesh, material: Material) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.95
	particles.direction = Vector3.UP
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.mesh = mesh
	particles.material_override = material
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tumbling coins.
	particles.particle_flag_rotate_y = true
	particles.angular_velocity_min = -720.0
	particles.angular_velocity_max = 720.0
	add_child(particles)
	return particles


## A gold spark in the air: he is here.
func spark(at: Vector3) -> void:
	_burst(_spark, at)


## A hit knocked coins out of the sack.
func coins(at: Vector3) -> void:
	_burst(_coins, at)
	Sound.play_at(&"mandl_coins", at)


## The whole sack spilt.
func fountain(at: Vector3) -> void:
	_burst(_fountain, at)
	Sound.play_at(&"mandl_fountain", at)


## Gone in a puff of gold dust.
func puff(at: Vector3) -> void:
	_burst(_dust, at)
	_burst(_spark, at)
	Sound.play_at(&"mandl_poof", at)


func _burst(particles: CPUParticles3D, at: Vector3) -> void:
	particles.global_position = at
	particles.restart()
