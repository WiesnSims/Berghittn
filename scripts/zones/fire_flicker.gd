extends OmniLight3D
## Fireplace flicker: the warm, moving light is what makes the room feel alive before any art exists.

@export var base_energy: float = 2.0
## Fraction of base_energy the light swings up and down.
@export var flicker_amount: float = 0.3
@export var flicker_speed: float = 6.0

var _noise: FastNoiseLite = FastNoiseLite.new()
var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	# get_noise_1d returns roughly -0.5..0.5, so double it for a -1..1 swing.
	light_energy = base_energy * (1.0 + 2.0 * _noise.get_noise_1d(_time * 10.0) * flicker_amount)
