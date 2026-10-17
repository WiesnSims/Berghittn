class_name Snowfall
extends GPUParticles3D
## The storm around the camera. The emitter box rides along with the camera while the flakes live
## in world space, so walking never drags the snow along; the flake shader hides them under roofs.

@export var roof_map: RoofMap

var _material: ShaderMaterial


func _ready() -> void:
	_material = (draw_pass_1 as PrimitiveMesh).material as ShaderMaterial
	if roof_map.is_built:
		_on_roof_built()
	else:
		roof_map.built.connect(_on_roof_built)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position + Vector3.UP * Constants.SNOW_EMITTER_ABOVE


func _on_roof_built() -> void:
	_material.set_shader_parameter("roof_heights", roof_map.texture)
	_material.set_shader_parameter("roof_rect", roof_map.rect)
	_material.set_shader_parameter("roof_ready", 1.0)
