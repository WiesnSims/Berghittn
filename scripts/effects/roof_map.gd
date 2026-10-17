class_name RoofMap
extends Node
## Height of the highest solid surface over every spot of the play area, found once at load by
## casting rays straight down. Snow hides below it (no flakes indoors, under the balcony or the deck
## roof) and the atmosphere uses it to tell whether the camera is inside.

signal built

var texture: ImageTexture
## World-space x, z of the map's corner and its size in metres, for the snow shader.
var rect: Vector4 = Vector4(-Constants.ROOF_MAP_HALF_SIZE, -Constants.ROOF_MAP_HALF_SIZE,
		Constants.ROOF_MAP_HALF_SIZE * 2.0, Constants.ROOF_MAP_HALF_SIZE * 2.0)
var is_built: bool = false

var _heights: PackedFloat32Array = PackedFloat32Array()
var _cells: int = 0


func _ready() -> void:
	add_to_group("roof_map")
	# CSG builds its collision deferred, and the physics space needs a step to see it.
	for i: int in 3:
		await get_tree().physics_frame
	_build()


## Height of the roof over (x, z), or NO_ROOF outside the map.
func height_at(world: Vector3) -> float:
	if not is_built:
		return Constants.ROOF_MAP_NO_ROOF
	var cell := Vector2i(floori((world.x - rect.x) / Constants.ROOF_MAP_CELL),
			floori((world.z - rect.y) / Constants.ROOF_MAP_CELL))
	if cell.x < 0 or cell.y < 0 or cell.x >= _cells or cell.y >= _cells:
		return Constants.ROOF_MAP_NO_ROOF
	return _heights[cell.y * _cells + cell.x]


func is_covered(world: Vector3) -> bool:
	return world.y < height_at(world) - Constants.ROOF_MAP_MARGIN


func _build() -> void:
	var started: int = Time.get_ticks_usec()
	_cells = ceili(rect.z / Constants.ROOF_MAP_CELL)
	var raw := PackedFloat32Array()
	raw.resize(_cells * _cells)
	var space: PhysicsDirectSpaceState3D = get_viewport().find_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = Constants.LAYER_WORLD
	for z: int in _cells:
		for x: int in _cells:
			var at := Vector2(rect.x + (x + 0.5) * Constants.ROOF_MAP_CELL, rect.y + (z + 0.5) * Constants.ROOF_MAP_CELL)
			query.from = Vector3(at.x, Constants.ROOF_MAP_CAST_FROM, at.y)
			query.to = Vector3(at.x, Constants.ROOF_MAP_NO_ROOF, at.y)
			var hit: Dictionary = space.intersect_ray(query)
			raw[z * _cells + x] = (hit.position as Vector3).y if hit else Constants.ROOF_MAP_NO_ROOF
	# Grow every roof by one cell, so flakes near a wall cannot show through it from inside.
	_heights.resize(raw.size())
	for z: int in _cells:
		for x: int in _cells:
			var highest: float = Constants.ROOF_MAP_NO_ROOF
			for dz: int in range(maxi(z - 1, 0), mini(z + 2, _cells)):
				for dx: int in range(maxi(x - 1, 0), mini(x + 2, _cells)):
					highest = maxf(highest, raw[dz * _cells + dx])
			_heights[z * _cells + x] = highest
	var image := Image.create_from_data(_cells, _cells, false, Image.FORMAT_RF, _heights.to_byte_array())
	texture = ImageTexture.create_from_image(image)
	is_built = true
	print("Roof map: %d cells in %.0f ms" % [_cells * _cells, (Time.get_ticks_usec() - started) / 1000.0])
	built.emit()
