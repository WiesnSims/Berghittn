extends Node3D

# Spinning cube makes it obvious in a screenshot that the engine is rendering frames, not a static image.
const SPIN_SPEED: float = 0.8

@onready var _cube: MeshInstance3D = $Cube


func _process(delta: float) -> void:
	_cube.rotate_y(SPIN_SPEED * delta)
