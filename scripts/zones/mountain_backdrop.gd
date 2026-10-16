class_name MountainBackdrop
extends MeshInstance3D
## Rings of jagged peaks far around the hut, generated at load. The storm fog would swallow real
## mountains long before this distance, so these ignore fog and fade from the fog color at their foot
## to pale snow at the ridge: the summits show through the snowstorm, the bases melt into it.

## One ring per entry: x = radius, y = lowest ridge height, z = highest ridge height (metres).
@export var rings: Array[Vector3] = [Vector3(330.0, 30.0, 95.0), Vector3(440.0, 60.0, 150.0)]
## Extra height towards the summit side (north, -Z), as a share of the ridge height: the hut sits
## below its own mountain, while the far side of the valley stays low.
@export var summit_boost: float = 2.2
## How light each ring's ridges get (0 = fog color, 1 = ridge_color); the nearer ring is lighter.
@export var ring_lightness: Array[float] = [0.55, 0.35]
@export var ridge_color: Color = Color(0.72, 0.77, 0.86, 1)
## Degrees between ridge points; smaller = more, narrower peaks.
@export var step_degrees: float = 3.0
## Where the foot of every ring sits, well below the plateau so the valley never shows a gap.
@export var base_height: float = -80.0
@export var noise_seed: int = 2026


func _ready() -> void:
	var fog: Color = _fog_color()
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.9
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for r: int in rings.size():
		var ring: Vector3 = rings[r]
		var top: Color = fog.lerp(ridge_color, ring_lightness[r])
		var count: int = int(360.0 / step_degrees)
		var ridge := PackedVector3Array()
		for i: int in count:
			var angle: float = deg_to_rad(i * step_degrees)
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			# Ridged noise: sharp summits and soft saddles, like real limestone peaks.
			var sharp: float = 1.0 - absf(noise.get_noise_2d(cos(angle) * 3.0 + r * 10.0, sin(angle) * 3.0))
			var north: float = maxf(-direction.z, 0.0)
			var height: float = lerpf(ring.y, ring.z, sharp * sharp) * (1.0 + summit_boost * north * north)
			ridge.append(direction * ring.x + Vector3.UP * height)
		for i: int in count:
			var a: Vector3 = ridge[i]
			var b: Vector3 = ridge[(i + 1) % count]
			var a_foot := Vector3(a.x, base_height, a.z)
			var b_foot := Vector3(b.x, base_height, b.z)
			vertices.append_array([a_foot, a, b, a_foot, b, b_foot])
			colors.append_array([fog, top, top, fog, top, fog])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.disable_fog = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	built.surface_set_material(0, material)
	mesh = built
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _fog_color() -> Color:
	# Taken from the scene's environment, so the feet always match the fog, whatever it is tuned to.
	for node: Node in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		var environment: Environment = (node as WorldEnvironment).environment
		if environment:
			return environment.fog_light_color
	return ridge_color.darkened(0.5)
