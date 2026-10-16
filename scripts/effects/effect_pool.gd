class_name EffectPool
extends Node3D
## Fixed set of one-shot particle effects reused round-robin. The fixed size is the point: a fast gun
## restarts the oldest puff instead of piling more onto the screen, and nothing is instanced mid-fight.

@export var effect: PackedScene
@export var size: int = 8

var _effects: Array[Node3D] = []
var _next: int = 0


func _ready() -> void:
	for i: int in size:
		var instance := effect.instantiate() as Node3D
		# Effects stay where they happened, even if this pool sits under the moving camera.
		instance.top_level = true
		add_child(instance)
		_effects.append(instance)


## Plays at `at`, spraying along `normal`.
func play(at: Vector3, normal: Vector3) -> void:
	var instance: Node3D = _effects[_next]
	_next = (_next + 1) % _effects.size()
	var up: Vector3 = Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# Particles emit along local +Z.
	instance.global_transform = Transform3D(Basis.looking_at(-normal, up), at)
	for node: Node in [instance] + instance.get_children():
		var particles := node as CPUParticles3D
		if particles:
			particles.restart()
