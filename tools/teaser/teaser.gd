extends Node
## Renders the title screen's teaser pictures (#77, 1.1.2) from the real game, one scene a run:
##     godot res://tools/teaser/teaser.tscn -- <scene> [out.jpg]
## The scenes (SCENES): stube, the first one (the Stube at night, a Wanderer diving in head first, a
## Perchte in mid-leap, a Knappe, the Krampus and a hiker firing the Jagdflinte); mandl (the
## Venedigermandl running off over the beer garden); dohlen (Bergdohlen round the roof at dawn);
## wilderer (his scope glinting across the Holzschuppen); dengel (the Dengelstock at work in the hay
## loft, a horde coming over it); coop (three hikers back to back in the Stube); krampus (the Krampus in
## the Stube door, a lantern by it). Needs a window. Writes assets/ui/teaser_<scene>.jpg by default
## and prints where the scene's spots are on the picture, for TeaserBackdrop.SCENES.

const OUT: String = "res://assets/ui/teaser_%s.jpg"
const SIZE := Vector2i(1920, 1080)
## Per scene: the camera, where it looks and its field of view.
const SCENES: Dictionary = {
	"stube": [Vector3(-5.4, 1.35, 0.4), Vector3(-10.4, 1.3, 3.3), 62.0],
	"mandl": [Vector3(-1.0, 0.8, 14.0), Vector3(4.5, 0.2, 21.0), 56.0],
	"dohlen": [Vector3(2.0, 0.8, 27.0), Vector3(-1.0, 6.0, 4.0), 66.0],
	"wilderer": [Vector3(8.0, 1.5, 16.8), Vector3(19.5, 1.2, 11.5), 58.0],
	"dengel": [Vector3(21.2, 5.4, 12.6), Vector3(19.2, 3.8, 18.4), 60.0],
	"coop": [Vector3(-5.8, 2.2, -1.0), Vector3(-2.2, 0.8, 2.8), 62.0],
	"krampus": [Vector3(0.8, 1.2, 11.2), Vector3(-2.5, 1.5, 6.6), 58.0],
}
## The first scene's window and hiker (as before 1.1.2).
const WINDOW := Vector3(-11.15, 0.0, 3.0)
const HIKER_AT := Vector3(-6.9, 0.0, 2.1)
const LEAPER_AT := Vector3(-8.4, 0.8, 2.6)
## Hikers' looks (HikerStyle), for the scenes with more than one.
const LOOKS: Array[Dictionary] = [
	{"name": "", "head": 1, "hat": 1, "jacket": 0, "trousers": 0},
	{"name": "", "head": 0, "hat": 2, "jacket": 2, "trousers": 1},
	{"name": "", "head": 2, "hat": 3, "jacket": 4, "trousers": 2},
]
## The arms of a hiker with a long gun at the shoulder.
const SHOULDER: Dictionary = {&"arm_r": Vector3(108, 0, -16), &"forearm_r": Vector3(22, 0, 0), &"arm_l": Vector3(118, 0, 20),
		&"forearm_l": Vector3(8, 0, 0), &"chest": Vector3(8, 30, 0), &"head": Vector3(-14, 22, 0)}
## The same, aimed level (at someone on the ground).
const LEVEL: Dictionary = {&"arm_r": Vector3(90, 0, -16), &"forearm_r": Vector3(22, 0, 0), &"arm_l": Vector3(100, 0, 20),
		&"forearm_l": Vector3(8, 0, 0), &"chest": Vector3(8, 30, 0), &"head": Vector3(-2, 22, 0)}

var _main: Node
var _waves: WaveManager
var _camera: Camera3D
# The scene's spots by name, a node or a point, put on the picture (0..1) when it is saved.
var _spots: Dictionary = {}


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "stube"
	if not SCENES.has(scene):
		push_error("no teaser scene %s (%s)" % [scene, ", ".join(SCENES.keys())])
		get_tree().quit(1)
		return
	var out: String = args[1] if args.size() > 1 else ProjectSettings.globalize_path(OUT % scene)
	get_window().size = SIZE
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await get_tree().process_frame
	(_main.get_node("UI") as CanvasLayer).hide()
	# No frost on the lens out in the snow: the picture is the scene, not the player's view of it.
	var atmosphere := _main.get_node("Atmosphere") as Atmosphere
	((atmosphere.post_fx as CanvasItem).material as ShaderMaterial).set_shader_parameter("frost", 0.0)
	atmosphere.post_fx = null
	(_main.get_node("EventDirector") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	_waves = _main.get_node("WaveManager") as WaveManager
	_waves.process_mode = Node.PROCESS_MODE_DISABLED
	var player := _main.get_node("Player") as Player
	player.global_position = Vector3(-1.0, 0.0, 9.0)
	player.weapons.visible = false
	get_tree().paused = false
	var shot: Array = SCENES[scene]
	_camera = Camera3D.new()
	_camera.fov = shot[2]
	add_child(_camera)
	_camera.look_at_from_position(shot[0], shot[1])
	_camera.current = true
	call("_stage_" + scene)
	# Let the boards fly off, the snow fall, the lights settle.
	for i: int in 50:
		await get_tree().process_frame
	_freeze()
	for i: int in 3:
		await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	image.save_jpg(out, 0.88)
	_save_spots(scene)
	print("teaser saved to %s" % out)
	get_tree().quit()


func _enemy(id: String, at: Vector3, facing: Vector3) -> Enemy:
	var enemy: Enemy = _waves._create_enemy()
	enemy.activate(load("res://data/enemies/%s.tres" % id) as EnemyData, 5, Transform3D(Basis.IDENTITY, at))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.rotation.y = atan2(-facing.x, -facing.z)
	return enemy


## An enemy at `at` turned towards `target` (on the level).
func _facing(id: String, at: Vector3, target: Vector3) -> Enemy:
	return _enemy(id, at, Vector3(target.x - at.x, 0.0, target.z - at.z).normalized())


## Plays `action` on the model up to `share` of its length, then holds that pose.
func _pose(enemy: Enemy, action: EnemyRig.Action, share: float, length: float = 1.0) -> void:
	_pose_rig(enemy._rig, action, share, length)


func _pose_rig(rig: EnemyRig, action: EnemyRig.Action, share: float, length: float = 1.0) -> void:
	rig.play(action, length)
	var steps: int = 40
	for i: int in steps:
		rig.update(length * share / steps, 0.0)


## Mid-stride: the walk (or the wing beat) run on for `seconds` at `speed`.
func _stride(enemy: Enemy, seconds: float, speed: float) -> void:
	var rig: EnemyRig = enemy._rig
	for i: int in 20:
		rig.update(seconds / 20.0, speed)


func _unlock(zones: Array[StringName]) -> void:
	var map := get_tree().get_first_node_in_group("zone_map") as ZoneMap
	for id: StringName in zones:
		map.unlock(id, null)


## A hiker at `at` aiming `weapon` (at the shoulder) at `target`, its muzzle flashing if `flash`. The
## muzzle's light is the hiker's meta "muzzle" (a spot for the title screen's flash).
func _hiker(at: Vector3, target: Vector3, weapon: String, look: int = 0, flash: bool = true, stance: Dictionary = LEVEL) -> Hiker:
	var hiker := (load("res://scenes/net/hiker.tscn") as PackedScene).instantiate() as Hiker
	add_child(hiker)
	hiker.apply(LOOKS[look], 1)
	hiker.show_name(false)
	hiker.global_position = at
	var aim: Vector3 = Vector3(target.x - at.x, 0.0, target.z - at.z).normalized()
	hiker.rotation.y = atan2(-aim.x, -aim.z)
	var rig: EnemyRig = hiker.rig
	rig.stance = stance
	rig.pose_now()
	var gun := _gun_model(load("res://data/weapons/%s.tres" % weapon) as WeaponData, flash)
	var hand := BoneAttachment3D.new()
	rig.skeleton.add_child(hand)
	hand.bone_name = "hand_r"
	hand.add_child(gun)
	gun.scale = Vector3.ONE * 1.6
	gun.position = Vector3(0.0, -0.08, -0.1)
	gun.rotation_degrees = Vector3(-118, 0, 0)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 1.6 if flash else 0.0
	light.omni_range = 3.5
	gun.add_child(light)
	light.position = Vector3(0.0, 0.05, -0.9)
	hiker.set_meta("muzzle", light)
	return hiker


func _muzzle(hiker: Hiker) -> Node3D:
	return hiker.get_meta("muzzle") as Node3D


func _gun_model(weapon: WeaponData, flash: bool) -> Node3D:
	var viewmodel: Node = weapon.viewmodel.instantiate()
	var model := viewmodel.get_node("Model") as Node3D
	viewmodel.remove_child(model)
	viewmodel.free()
	model.transform = Transform3D.IDENTITY
	for node: Node in model.find_children("*", "Node3D", true, false):
		if node.name.begins_with("MuzzleFlash"):
			(node as Node3D).visible = flash
	return model


## A warm light where the scene has none of its own (the lantern by the door).
func _light(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = true
	add_child(light)
	light.global_position = at
	return light


# --- The scenes ----------------------------------------------------------------------------------

func _stage_stube() -> void:
	# The window: most boards already ripped out, the last one going.
	var barricade := _main.get_node("World/Stube/WindowWestSouth") as Barricade
	for i: int in Constants.BARRICADE_MAX_BOARDS - 1:
		barricade.remove_board()
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
	# The hiker in front aiming at the Perchte in mid-air, turned a little towards the camera so
	# the gun shows against the wall.
	_spots["muzzle"] = _muzzle(_hiker(HIKER_AT, Vector3(-8.7, 0.0, 0.6), "jagdflinte", 0, true, SHOULDER))
	_spots["lamp"] = _brightest_lamp()


## The Venedigermandl off over the snow of the beer garden, a hiker after him with the Stutzen.
func _stage_mandl() -> void:
	_unlock([&"terrasse"])
	var mandl_at := Vector3(2.1, -0.3, 18.0)
	var mandl: Enemy = _facing("venedigermandl", mandl_at, mandl_at + Vector3(1.0, 0.0, 0.6))
	_stride(mandl, 0.35, 6.0)
	_spots["gold"] = mandl_at + Vector3.UP * 0.9
	_spots["muzzle"] = _muzzle(_hiker(Vector3(-0.9, -0.3, 16.7), mandl_at, "stutzen", 1))


## Bergdohlen round the Stube roof at first light, one coming down at a hiker in the garden.
func _stage_dohlen() -> void:
	_unlock([&"terrasse"])
	_dawn()
	var roof := Vector3(-1.0, 6.0, 14.0)
	var camera: Vector3 = SCENES["dohlen"][0]
	camera.y = 0.0
	var ahead := Vector3(-0.13, 0.0, -0.99)
	var right := Vector3(0.99, 0.0, -0.13)
	# How far ahead of the camera, how high and how far to the side.
	var flock: Array[Vector3] = [
		Vector3(10, 6.5, -2), Vector3(12, 8, 1), Vector3(9, 5, 3), Vector3(14, 9, -4),
		Vector3(11, 7.2, 4.5), Vector3(13, 5.8, -0.5), Vector3(8, 7.5, 1.5),
	]
	for i: int in flock.size():
		var at: Vector3 = camera + ahead * flock[i].x + right * flock[i].z
		at.y = flock[i].y
		# Round the roof, each its own way.
		var round_way := (at - roof).cross(Vector3.UP).normalized()
		var bird: Enemy = _enemy("bergdohle", at, round_way)
		(bird.get_node("Visual") as Node3D).rotation.z = 0.35 * (1.0 if i % 2 == 0 else -1.0)
		_stride(bird, 0.1 + 0.07 * i, 3.0)
	var hiker_at: Vector3 = camera + ahead * 3.2 + right * 1.6 + Vector3.DOWN * 0.3
	var diver_at: Vector3 = camera + ahead * 4.5 + right * -0.6 + Vector3.UP * 2.2
	var diver: Enemy = _enemy("bergdohle", diver_at, (hiker_at - diver_at).normalized())
	_pose(diver, EnemyRig.Action.STRIKE, 0.3)
	_spots["flock"] = roof
	_spots["muzzle"] = _muzzle(_hiker(hiker_at, diver_at, "jagdflinte", 2, false, SHOULDER))


## Across the Holzschuppen: the Wilderer's scope glinting from the far end, a hiker crouched behind
## the wood pile with the Repetierer.
func _stage_wilderer() -> void:
	_unlock([&"seilbahn", &"schuppen", &"terrasse"])
	var wilderer_at := Vector3(17.6, 0.0, 12.2)
	var hiker_at := Vector3(10.3, 0.0, 16.7)
	var wilderer: Enemy = _facing("wilderer", wilderer_at, hiker_at)
	_pose(wilderer, EnemyRig.Action.AIM, 0.6, wilderer.data.aim_time)
	wilderer._update_glint()
	# A cold light from the window on him, so he shows against the dark.
	_light(Vector3(16.8, 2.2, 13.4), Color(0.6, 0.7, 1.0), 1.2, 4.0)
	_spots["glint"] = wilderer._rig.point_on(&"hand_r", Constants.WILDERER_SCOPE * wilderer._rig.build_scale)
	_spots["muzzle"] = _muzzle(_hiker(hiker_at, wilderer_at, "repetierer", 1, false))
	_spots["lamp"] = _brightest_lamp()


## Up in the hay loft the Dengelstock rings away at a Stutzen while the horde comes over the loft.
func _stage_dengel() -> void:
	_unlock([&"seilbahn", &"schuppen", &"terrasse"])
	var stock := get_tree().get_first_node_in_group("dengelstocks") as Dengelstock
	stock.open()
	var owner := Node3D.new()
	add_child(owner)
	stock.start(owner, load("res://data/weapons/stutzen_dengelt.tres") as WeaponData, false)
	_spots["anvil"] = stock.get("_sparks") as Node3D
	_spots["fire"] = stock.global_position + Vector3.UP * 1.2
	var hiker_at := Vector3(18.3, 3.5, 16.4)
	# Over the top of the ramp and across the loft at the hiker.
	var horde: Array[Vector3] = [Vector3(16.0, 3.5, 15.4), Vector3(15.8, 3.5, 16.9), Vector3(16.6, 3.5, 14.2)]
	var ids: Array[String] = ["wanderer", "perchte", "tourist"]
	for i: int in horde.size():
		_stride(_facing(ids[i], horde[i], hiker_at), 0.3 + 0.2 * i, 3.0)
	var knappe: Enemy = _facing("knappe", Vector3(16.5, 3.5, 18.0), hiker_at)
	_pose(knappe, EnemyRig.Action.STRIKE, 0.45, 1.2)
	_spots["muzzle"] = _muzzle(_hiker(hiker_at, Vector3(16.0, 3.5, 15.6), "pistole"))


## Three hikers back to back in the middle of the Stube, Perchten from every side.
func _stage_coop() -> void:
	var middle := Vector3(-2.6, 0.0, 2.2)
	var targets: Array[Vector3] = [Vector3(-4.8, 0.0, 3.6), Vector3(-0.2, 0.0, 3.4), Vector3(-2.4, 0.0, 4.9)]
	var guns: Array[String] = ["jagdflinte", "repetierer", "stutzen"]
	for i: int in 3:
		var out: Vector3 = (targets[i] - middle).normalized()
		_spots["muzzle%d" % i] = _muzzle(_hiker(middle + out * 0.55, targets[i], guns[i], i))
		var perchte: Enemy = _facing("perchte", targets[i] + Vector3(0.0, 0.6 if i == 1 else 0.0, 0.0), middle)
		if i == 1:
			(perchte.get_node("Visual") as Node3D).rotation.x = -0.45
			_pose(perchte, EnemyRig.Action.LEAP, 0.4)
		else:
			_pose(perchte, EnemyRig.Action.STRIKE, 0.4)
	_pose(_facing("wanderer", Vector3(-5.6, 0.0, 5.2), middle), EnemyRig.Action.STRIKE, 0.3)
	_pose(_facing("krampus", Vector3(0.6, 0.0, 0.6), middle), EnemyRig.Action.STRIKE, 0.35, 1.4)
	_spots["lamp"] = _brightest_lamp()


## The Krampus in the open Stube door, out of the storm, a lantern hanging by it.
func _stage_krampus() -> void:
	_unlock([&"terrasse"])
	var door := Vector3(-2.5, 0.0, 6.4)
	var krampus: Enemy = _enemy("krampus", door + Vector3(0.0, 0.0, 0.6), Vector3(0.45, 0.0, 1.0).normalized())
	_pose(krampus, EnemyRig.Action.STRIKE, 0.3, 1.4)
	var lantern_at := door + Vector3(1.9, 2.2, 0.3)
	var lantern := CSGBox3D.new()
	lantern.size = Vector3(0.22, 0.32, 0.22)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.75, 0.4)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.65, 0.3)
	glass.emission_energy_multiplier = 2.5
	lantern.material = glass
	add_child(lantern)
	lantern.global_position = lantern_at
	_light(lantern_at + Vector3(0.0, -0.1, 0.4), Color(1.0, 0.62, 0.32), 2.2, 6.0)
	_spots["lantern"] = lantern_at
	_spots["pivot"] = lantern_at + Vector3.UP * 0.5


## Dawn over the Alm: the storm thinned to a pink haze, the moon gone warm.
func _dawn() -> void:
	var atmosphere := _main.get_node("Atmosphere") as Atmosphere
	atmosphere.outdoor_fog_color = Color(0.72, 0.52, 0.5)
	atmosphere.outdoor_fog_density = 0.02
	atmosphere.outdoor_ambient_color = Color(0.85, 0.62, 0.55)
	atmosphere.outdoor_ambient_energy = 0.7
	var sun := _main.get_node("Moonlight") as DirectionalLight3D
	sun.light_color = Color(1.0, 0.68, 0.45)
	sun.light_energy *= 1.6


## The brightest lamp on the right of the picture, for its flicker.
func _brightest_lamp() -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_energy: float = -1.0
	for node: Node in _main.find_children("*", "OmniLight3D", true, false):
		var lamp := node as OmniLight3D
		if not lamp.is_visible_in_tree() or _camera.is_position_behind(lamp.global_position):
			continue
		var at: Vector2 = _camera.unproject_position(lamp.global_position) / Vector2(SIZE)
		if Rect2(0.3, 0.0, 0.7, 1.0).has_point(at) and lamp.light_energy > best_energy:
			best = lamp.global_position
			best_energy = lamp.light_energy
	return best


## Where the scene's spots are on the picture (0..1), for TeaserBackdrop.SCENES.
func _save_spots(scene: String) -> void:
	var parts: PackedStringArray = []
	for key: String in _spots:
		var spot: Variant = _spots[key]
		var at: Vector3 = (spot as Node3D).global_position if spot is Node3D else spot
		if at == Vector3.INF or _camera.is_position_behind(at):
			continue
		var on: Vector2 = _camera.unproject_position(at) / Vector2(SIZE)
		parts.append('"%s": Vector2(%.3f, %.3f)' % [key, on.x, on.y])
	print('Copy into TeaserBackdrop.SCENES["%s"]: {%s}' % [scene, ", ".join(parts)])


func _freeze() -> void:
	for node: Node in _main.find_children("*", "MapMarker", true, false):
		(node as Node3D).visible = false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in get_tree().get_nodes_in_group("dengelstocks"):
		node.process_mode = Node.PROCESS_MODE_DISABLED
