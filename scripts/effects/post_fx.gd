extends ColorRect
## Grade, vignette and film grain over the 3D view; the grain follows the settings toggle.

var _grain: float = 0.0


func _ready() -> void:
	var post := material as ShaderMaterial
	_grain = post.get_shader_parameter("grain")
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func _on_settings_changed() -> void:
	(material as ShaderMaterial).set_shader_parameter("grain", _grain if Settings.film_grain else 0.0)
