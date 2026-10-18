extends Node
## Renders the title screen's teaser picture (#77) from the real game: the Stube at night, the west
## window torn open with a Wanderer diving in head first, a Perchte in mid-leap, a Knappe swinging
## his pick, the Krampus behind them, and a hiker in front firing the Jagdflinte. Needs a window:
##     godot res://tools/teaser/teaser.tscn -- [out.jpg]
## Writes assets/ui/teaser.jpg by default and prints where the muzzle and the lamp are, for the
## title screen that animates it (scripts/ui/teaser_backdrop.gd).

const OUT: String = "res://assets/ui/teaser.jpg"
const SIZE := Vector2i(1920, 1080)
const WINDOW := Vector3(-11.15, 0.0, 3.0)
const CAMERA_AT := Vector3(-5.4, 1.35, 0.4)
const LOOK_AT := Vector3(-10.4, 1.3, 3.3)
const HIKER_AT := Vector3(-6.9, 0.0, 2.1)
const LEAPER_AT := Vector3(-8.4, 0.8, 2.6)

var _main: Node
var _waves: WaveManager
var _muzzle: Node3D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(OUT)
	get_window().size = SIZE
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().process_frame
	(_main.get_node("UI") as CanvasLayer).hide()
	(_main.get_node("EventDirector") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	_waves = _main.get_node("WaveManager") as WaveManager
	_waves.process_mode = Node.PROCESS_MODE_DISABLED
	var player := _main.get_node("Player") as Player
	player.global_position = Vector3(-1.0, 0.0, 9.0)
	player.weapons.visible = false
	get_tree().paused = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	add_child(camera)
	camera.look_at_from_position(CAMERA_AT, LOOK_AT)
	camera.current = true
	# The window: most boards already ripped out, the last one going.
	var barricade := _main.get_node("World/Stube/WindowWestSouth") as Barricade
	for i: int in Constants.BARRICADE_MAX_BOARDS - 1:
		barricade.remove_board()
	_stage()
	# Let the boards fly off, the snow fall, the lights settle.
	for i: int in 50:
		await get_tree().process_frame
	_freeze()
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	image.save_jpg(out, 0.88)
	_save_spots(camera)
	print("teaser saved to %s" % out)
	get_tree().quit()


func _enemy(id: String, at: Vector3, facing: Vector3) -> Enemy:
	var enemy: Enemy = _waves._create_enemy()
	enemy.activate(load("res://data/enemies/%s.tres" % id) as EnemyData, 5, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.rotation.y = atan2(-facing.x, -facing.z)
	return enemy


## Plays `action` on the model up to `share` of its length, then holds that pose.
func _pose(enemy: Enemy, action: EnemyRig.Action, share: float, length: float = 1.0) -> void:
	var rig := enemy.get_node("Visual").get_child(-1) as EnemyRig
	rig.play(action, length)
	var steps: int = 40
	for i: int in steps:
		rig.update(length * share / steps, 0.0)


func _stage() -> void:
	var inward := Vector3.RIGHT
	# Head first through the window, half inside.
	var diver: Enemy = _enemy("wanderer", WINDOW + Vector3(0.55, 0.85, 0.0), inward)
	(diver.get_node("Visual") as Node3D).rotation.x = -1.25
	_pose(diver, EnemyRig.Action.CLIMB, 0.5)
	# Mid-leap at the hiker.
	var leaper: Enemy = _enemy("perchte", LEAPER_AT, (HIKER_AT - Vector3(LEAPER_AT.x, 0.0, LEAPER_AT.z)).normalized())
	(leaper.get_node("Visual") as Node3D).rotation.x = -0.45
	_pose(leaper, EnemyRig.Action.LEAP, 0.4)
	# Pick raised high, by the other window.
	var knappe: Enemy = _enemy("knappe", Vector3(-9.9, 0.0, -0.3), (HIKER_AT - Vector3(-9.9, 0.0, -0.3)).normalized())
	_pose(knappe, EnemyRig.Action.STRIKE, 0.45, 1.2)
	# The Krampus coming round the table.
	var krampus: Enemy = _enemy("krampus", Vector3(-10.4, 0.0, 1.1), (HIKER_AT - Vector3(-10.4, 0.0, 1.1)).normalized())
	_pose(krampus, EnemyRig.Action.STRIKE, 0.35, 1.4)
	# A Wanderer behind the diver, staggering under a headshot.
	var shot: Enemy = _enemy("wanderer", Vector3(-9.8, 0.0, 4.6), (HIKER_AT - Vector3(-9.8, 0.0, 4.6)).normalized())
	shot._flinch(true)
	_pose(shot, EnemyRig.Action.STRIKE, 0.2, 1.0)
	_hiker()


## A hiker in front, the Jagdflinte at the shoulder, both barrels going off.
func _hiker() -> void:
	var hiker := (load("res://scenes/net/hiker.tscn") as PackedScene).instantiate() as Hiker
	add_child(hiker)
	hiker.apply({"name": "", "head": 1, "hat": 1, "jacket": 0, "trousers": 0}, 1)
	hiker.show_name(false)
	hiker.global_position = HIKER_AT
	# Aiming at the Perchte in mid-air.
	# Turned a little towards the camera, so the gun shows against the wall.
	var aim: Vector3 = (Vector3(-8.7, 0.0, 0.6) - HIKER_AT).normalized()
	hiker.rotation.y = atan2(-aim.x, -aim.z)
	var rig: EnemyRig = hiker.rig
	rig.stance = {&"arm_r": Vector3(108, 0, -16), &"forearm_r": Vector3(22, 0, 0), &"arm_l": Vector3(118, 0, 20),
			&"forearm_l": Vector3(8, 0, 0), &"chest": Vector3(8, 30, 0), &"head": Vector3(-14, 22, 0)}
	rig.pose_now()
	var gun := _gun_model(load("res://data/weapons/jagdflinte.tres") as WeaponData)
	var hand := BoneAttachment3D.new()
	rig.skeleton.add_child(hand)
	hand.bone_name = "hand_r"
	hand.add_child(gun)
	gun.scale = Vector3.ONE * 1.6
	gun.position = Vector3(0.0, -0.08, -0.1)
	gun.rotation_degrees = Vector3(-118, 0, 0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.75, 0.4)
	flash.light_energy = 1.6
	flash.omni_range = 3.5
	gun.add_child(flash)
	flash.position = Vector3(0.0, 0.05, -0.9)
	_muzzle = flash


func _gun_model(weapon: WeaponData) -> Node3D:
	var viewmodel: Node = weapon.viewmodel.instantiate()
	var model := viewmodel.get_node("Model") as Node3D
	viewmodel.remove_child(model)
	viewmodel.free()
	model.transform = Transform3D.IDENTITY
	for node: Node in model.find_children("*", "Node3D", true, false):
		if node.name.begins_with("MuzzleFlash"):
			(node as Node3D).visible = true
	return model


## Where the muzzle and the lamps are in the picture (0..1), for the title screen's flashes.
func _save_spots(camera: Camera3D) -> void:
	var size := Vector2(SIZE)
	var lamps: Array = []
	for node: Node in _main.find_children("*", "OmniLight3D", true, false):
		var lamp := node as OmniLight3D
		if not lamp.is_visible_in_tree() or camera.is_position_behind(lamp.global_position):
			continue
		var at: Vector2 = camera.unproject_position(lamp.global_position) / size
		if Rect2(0, 0, 1, 1).has_point(at):
			lamps.append([snappedf(at.x, 0.001), snappedf(at.y, 0.001)])
	var muzzle: Vector2 = camera.unproject_position(_muzzle.global_position) / size
	print("Copy into scripts/ui/teaser_backdrop.gd: MUZZLE_AT = %s, lamps (the first is LAMP_AT): %s" % [muzzle.snappedf(0.001), lamps])


func _freeze() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
