extends Node
## Run: godot --headless --fixed-fps 60 res://tests/window_attack.tscn
## A player pressed against a window must not be hit while the enemy outside tears the boards off,
## and must be hit once it has climbed in.

# Members, not locals: GDScript lambdas capture locals by value.
var hits_outside: int = 0
var hits_inside: int = 0
var climbed: bool = false


func _ready() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	for marker: Node in get_tree().get_nodes_in_group("spawn_points"):
		if marker.name != "WestSouth":
			marker.remove_from_group("spawn_points")
	get_tree().paused = false
	var player := main.get_node("Player") as Player
	var enemy: Enemy = null
	player.health.damaged.connect(func(_a: int) -> void:
		if climbed: hits_inside += 1
		else: hits_outside += 1)
	var t: float = 0.0
	while t < 60.0 and hits_inside == 0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		# Right against the inside of the window, the spot that used to get swiped through it.
		player.global_position = Vector3(-6.55, 0.0, 2.5)
		player.health._health = 100.0
		if enemy == null:
			enemy = get_tree().get_first_node_in_group("enemies") as Enemy
		elif enemy._state == Enemy.State.CLIMBING:
			climbed = true
	print("hits while outside: %d, hits after climbing in: %d (t=%.1f)" % [hits_outside, hits_inside, t])
	var ok: bool = hits_outside == 0 and hits_inside > 0
	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
