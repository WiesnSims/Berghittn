extends SceneTree
## Builds the player hiker (M7) into assets/models/hiker.tscn: one body in a jacket and trousers that
## the game tints per player, every head (Head0..) and every hat (Hat1..) of HikerStyle as parts of
## their own, so the lobby can dress it by switching parts on and off:
##
##     godot --headless --script res://tools/models/build_hiker.gd
##
## Same skeleton and proportions as the enemies (build_enemies.gd), living eyes, gloves for the storm.

const Builder := preload("res://tools/models/character_builder.gd")
const Stuffed := preload("res://tools/models/stuffed.gd")
const RIG := preload("res://scripts/enemies/enemy_rig.gd")
const OUT: String = "res://assets/models/hiker.tscn"

const PELVIS := Vector3(0.0, 0.95, 0.0)
const WAIST := Vector3(0.0, 1.12, 0.0)
const NECK := Vector3(0.0, 1.5, 0.0)
const SHOULDER := Vector3(-0.22, 1.43, 0.0)
const ELBOW := Vector3(-0.25, 1.15, 0.0)
const WRIST := Vector3(-0.26, 0.9, 0.0)
const HIP := Vector3(-0.1, 0.92, 0.0)
const KNEE := Vector3(-0.11, 0.5, 0.0)
const ANKLE := Vector3(-0.11, 0.09, 0.0)

## The skull every head and hat is fitted to.
const SKULL := Vector3(0.0, 1.63, -0.02)
const SKULL_RADII := Vector3(0.115, 0.14, 0.125)
## Tinted clothes: white, and a shade darker for seams and collar.
const CLOTH := Color(1.0, 1.0, 1.0)
const SEAM := Color(0.72, 0.72, 0.72)
const BOOT := Color(0.24, 0.16, 0.1)
const GLOVE := Color(0.16, 0.14, 0.13)


func _init() -> void:
	var b := Builder.new(1.0)
	b.skeleton(PELVIS, WAIST, NECK, SHOULDER, ELBOW, WRIST, HIP, KNEE, ANKLE)
	_body(b)
	_heads(b)
	_hats(b)
	b.part(&"body")
	b.ragdoll({&"arm_l": 0.068, &"forearm_l": 0.05, &"arm_r": 0.068, &"forearm_r": 0.05,
			&"thigh_l": 0.09, &"shin_l": 0.06, &"thigh_r": 0.09, &"shin_r": 0.06},
			Vector3(0.36, 0.22, 0.26), Vector3(0.44, 0.38, 0.3), 0.13)
	b.save(OUT, "HikerModel", RIG, {
		"build_scale": 1.0,
		"stance": {&"arm_l": Vector3(8, 0, 6), &"arm_r": Vector3(8, 0, -6), &"forearm_l": Vector3(18, 0, 0),
				&"forearm_r": Vector3(18, 0, 0)},
		"stride": 28.0, "arm_swing": 16.0, "cadence": 1.5})
	print("hiker built")
	quit()


func _both(f: Callable) -> void:
	f.call(Vector3.ONE, "_l")
	f.call(Vector3(-1.0, 1.0, 1.0), "_r")


func _torso(b: Builder, rings: Array, material: StringName, color: Color) -> void:
	var path: Array = []
	var radii: Array = []
	var rig: Array = []
	for ring: Array in rings:
		var y: float = ring[0]
		path.append(Vector3(0.0, y, ring[3] if ring.size() > 3 else 0.0))
		radii.append(Vector2(ring[1], ring[2]))
		if absf(y - WAIST.y) < 0.04:
			rig.append([&"hips", &"chest", 0.5])
		else:
			rig.append(&"hips" if y < WAIST.y else &"chest")
	b.tube(path, radii, material, color, rig, 8)


func _limb(b: Builder, from: Vector3, to: Vector3, r_from: Vector2, r_to: Vector2, material: StringName,
		color: Color, bone: String, parent: String) -> void:
	_both(func(m: Vector3, s: String) -> void:
		var p := StringName(parent if parent in ["hips", "chest"] else parent + s)
		var own := StringName(bone + s)
		b.tube([from * m, from.lerp(to, 0.5) * m, to * m], [r_from, r_from.lerp(r_to, 0.5), r_to],
				material, color, [[p, own, 0.5], own, own], 7))


func _body(b: Builder) -> void:
	b.part(&"body")
	# A hiking jacket down over the hips, a stand-up collar and a dark zip.
	_torso(b, [[0.82, 0.18, 0.13], [0.95, 0.175, 0.125], [WAIST.y, 0.175, 0.125], [1.26, 0.205, 0.135],
			[1.4, 0.225, 0.13], [1.47, 0.16, 0.1], [1.5, 0.08, 0.07]], &"jacket", CLOTH)
	b.tube([Vector3(0.0, 1.46, 0.0), Vector3(0.0, 1.55, -0.005)], [Vector2(0.085, 0.08), Vector2(0.08, 0.075)],
			&"jacket", SEAM, [&"chest", [&"chest", &"head", 0.5]], 8, false)
	b.box(Vector3(0.0, 1.13, -0.128), Vector3(0.018, 0.62, 0.012), &"plain", Color(0.1, 0.1, 0.1), [&"hips", &"chest", 0.5])
	# Hem and hip pockets a shade darker (the pack's straps run over the chest).
	b.tube([Vector3(0.0, 0.81, 0.0), Vector3(0.0, 0.85, 0.0)], [Vector2(0.185, 0.135), Vector2(0.183, 0.133)], &"jacket", SEAM, &"hips", 8, false)
	_both(func(m: Vector3, _s: String) -> void:
		b.box(Vector3(-0.1, 0.98, -0.128) * m, Vector3(0.09, 0.1, 0.02), &"jacket", SEAM, &"hips"))
	_limb(b, SHOULDER + Vector3(0.0, 0.03, 0.0), ELBOW, Vector2(0.07, 0.07), Vector2(0.062, 0.062), &"jacket", CLOTH, "arm", "chest")
	_limb(b, ELBOW, WRIST, Vector2(0.06, 0.06), Vector2(0.05, 0.05), &"jacket", CLOTH, "forearm", "arm")
	_both(func(m: Vector3, s: String) -> void:
		# Cuff, then a glove.
		b.tube([(WRIST + Vector3(0, 0.03, 0)) * m, WRIST * m], [Vector2(0.054, 0.054), Vector2(0.054, 0.054)], &"jacket", SEAM, StringName("forearm" + s), 7, false)
		b.ball((WRIST + Vector3(0.0, -0.07, 0.0)) * m, Vector3(0.05, 0.07, 0.04), &"leather", GLOVE, StringName("hand" + s), 6, 4))
	# Trousers (Kniebundhose) down into the boots.
	_torso(b, [[0.74, 0.18, 0.13], [0.86, 0.182, 0.132]], &"trousers", CLOTH)
	_limb(b, HIP + Vector3(0.0, 0.05, 0.0), KNEE, Vector2(0.092, 0.097), Vector2(0.075, 0.08), &"trousers", CLOTH, "thigh", "hips")
	_limb(b, KNEE + Vector3(0.0, 0.03, 0.0), ANKLE + Vector3(0.0, 0.1, 0.0), Vector2(0.072, 0.076), Vector2(0.055, 0.058), &"trousers", CLOTH, "shin", "thigh")
	_both(func(m: Vector3, s: String) -> void:
		var foot := StringName("foot" + s)
		var shin := StringName("shin" + s)
		b.tube([(ANKLE + Vector3(0, 0.14, 0)) * m, (ANKLE + Vector3(0, -0.02, 0)) * m], [Vector2(0.062, 0.066), Vector2(0.065, 0.07)], &"leather", BOOT, shin, 7, false)
		b.box(Vector3(ANKLE.x * m.x, 0.055, -0.05), Vector3(0.12, 0.11, 0.27), &"leather", BOOT, foot, Basis.IDENTITY, Vector2(0.85, 0.8))
		b.box(Vector3(ANKLE.x * m.x, 0.012, -0.05), Vector3(0.13, 0.024, 0.285), &"plain", Color(0.08, 0.07, 0.06), foot))
	# A small day pack.
	b.box(Vector3(0.0, 1.22, 0.19), Vector3(0.3, 0.38, 0.14), &"wool", Color(0.28, 0.3, 0.32), &"chest", Basis.IDENTITY, Vector2(0.9, 0.85))
	b.box(Vector3(0.0, 1.37, 0.195), Vector3(0.29, 0.06, 0.155), &"wool", Color(0.2, 0.21, 0.23), &"chest")
	_both(func(m: Vector3, _s: String) -> void:
		b.box(Vector3(-0.11, 1.28, -0.128) * m, Vector3(0.04, 0.34, 0.016), &"plain", Color(0.15, 0.15, 0.15), &"chest"))


## A living face on the skull, with a neck; the rest of a head is hair and beard.
func _face(b: Builder, skin: Color) -> void:
	var c: Vector3 = SKULL
	var r: Vector3 = SKULL_RADII
	var front: float = c.z - r.z
	b.tube([Vector3(0.0, 1.46, 0.0), Vector3(0.0, 1.56, -0.01)], [Vector2(0.055, 0.055), Vector2(0.05, 0.05)], &"skin", skin, [[&"chest", &"head", 0.5], &"head"], 6, false)
	b.ball(c, r, &"skin", skin, &"head", 10, 7)
	b.box(Vector3(0.0, c.y - 0.01, front - 0.015), Vector3(0.035, 0.06, 0.05), &"skin", skin.darkened(0.08), &"head", Basis.IDENTITY, Vector2(0.4, 0.3))
	for x: float in [-1.0, 1.0]:
		b.box(Vector3(0.048 * x, c.y + 0.022, front + 0.008), Vector3(0.04, 0.022, 0.012), &"plain", Color(0.92, 0.9, 0.86), &"head")
		b.box(Vector3(0.048 * x, c.y + 0.022, front + 0.002), Vector3(0.016, 0.016, 0.006), &"plain", Color(0.12, 0.2, 0.3), &"head")
		b.ball(Vector3(r.x * x, c.y, c.z + 0.01), Vector3(0.02, 0.04, 0.03), &"skin", skin.darkened(0.1), &"head", 5, 3)
	b.box(Vector3(0.0, c.y - 0.07, front + 0.018), Vector3(0.06, 0.014, 0.02), &"plain", Color(0.45, 0.2, 0.18), &"head")


func _brows(b: Builder, color: Color, thick: float = 0.016) -> void:
	for x: float in [-1.0, 1.0]:
		b.box(Vector3(0.048 * x, SKULL.y + 0.05, SKULL.z - SKULL_RADII.z + 0.012), Vector3(0.05, thick, 0.02), &"fur", color, &"head")


## Hair over the crown and the back, leaving the face free.
func _hair(b: Builder, color: Color, volume: float = 1.0) -> void:
	b.ball(SKULL + Vector3(0.0, 0.03, 0.014), Vector3(0.121, 0.12, 0.128) * volume, &"fur", color, &"head", 10, 6)


func _heads(b: Builder) -> void:
	# 0 Bua: young, short brown hair.
	b.part(&"head_0")
	var skin := Color(0.9, 0.7, 0.58)
	_face(b, skin)
	_hair(b, Color(0.35, 0.22, 0.12))
	_brows(b, Color(0.3, 0.2, 0.1))
	# 1 Bart: a full dark beard.
	b.part(&"head_1")
	skin = Color(0.84, 0.62, 0.5)
	_face(b, skin)
	_hair(b, Color(0.15, 0.1, 0.07))
	_brows(b, Color(0.12, 0.08, 0.05), 0.02)
	var beard := Color(0.18, 0.12, 0.08)
	b.ball(Vector3(0.0, 1.55, -0.085), Vector3(0.1, 0.085, 0.075), &"fur", beard, &"head", 8, 5)
	b.box(Vector3(0.0, 1.58, -0.15), Vector3(0.09, 0.02, 0.025), &"fur", beard, &"head")
	# 2 Opa: ruddy, bald on top, grey fringe, big grey moustache and brows.
	b.part(&"head_2")
	skin = Color(0.88, 0.6, 0.52)
	_face(b, skin)
	var grey := Color(0.78, 0.78, 0.76)
	b.ball(SKULL + Vector3(0.0, -0.01, 0.03), Vector3(0.122, 0.1, 0.12), &"fur", grey, &"head", 10, 5)
	_brows(b, grey, 0.024)
	b.box(Vector3(0.0, 1.583, -0.15), Vector3(0.11, 0.026, 0.03), &"fur", grey, &"head", Basis.IDENTITY, Vector2(0.8, 0.8))
	# 3 Zöpfe: blond braids down the back.
	b.part(&"head_3")
	skin = Color(0.92, 0.74, 0.64)
	_face(b, skin)
	var blond := Color(0.86, 0.7, 0.36)
	_hair(b, blond)
	_brows(b, blond.darkened(0.2), 0.012)
	for x: float in [-1.0, 1.0]:
		b.tube([Vector3(0.09 * x, 1.6, 0.07), Vector3(0.11 * x, 1.5, 0.08), Vector3(0.12 * x, 1.38, 0.06)],
				[Vector2(0.03, 0.03), Vector2(0.026, 0.026), Vector2(0.018, 0.018)], &"fur", blond, &"head", 6)
		b.box(Vector3(0.12 * x, 1.37, 0.06), Vector3(0.03, 0.02, 0.03), &"plain", Color(0.75, 0.15, 0.12), &"head")
	# 4 Locken: dark skin, black curls.
	b.part(&"head_4")
	skin = Color(0.45, 0.3, 0.22)
	_face(b, skin)
	var curls := Color(0.08, 0.06, 0.05)
	_hair(b, curls, 1.02)
	for i: int in 9:
		var a: float = TAU * float(i) / 9.0
		b.ball(SKULL + Vector3(cos(a) * 0.075, 0.105, 0.02 + sin(a) * 0.08), Vector3(0.045, 0.04, 0.045), &"fur", curls, &"head", 6, 4)
	_brows(b, curls)


func _hats(b: Builder) -> void:
	# 1 Tirolerhut: green felt, red cord, a feather.
	b.part(&"hat_1")
	var felt := Color(0.2, 0.32, 0.2)
	b.tube([Vector3(0.0, 1.735, 0.0), Vector3(0.0, 1.75, 0.0)], [Vector2(0.2, 0.21), Vector2(0.19, 0.2)], &"wool", felt, &"head", 10)
	b.tube([Vector3(0.0, 1.74, 0.0), Vector3(0.0, 1.8, 0.0), Vector3(0.0, 1.87, -0.005)], [Vector2(0.13, 0.14), Vector2(0.12, 0.13), Vector2(0.09, 0.1)], &"wool", felt, &"head", 9)
	b.tube([Vector3(0.0, 1.75, 0.0), Vector3(0.0, 1.78, 0.0)], [Vector2(0.132, 0.142), Vector2(0.129, 0.139)], &"plain", Color(0.7, 0.15, 0.12), &"head", 9, false)
	b.box(Vector3(0.125, 1.86, 0.05), Vector3(0.015, 0.17, 0.045), &"plain", Color(0.2, 0.2, 0.18), &"head", Basis(Vector3.RIGHT, -0.35), Vector2(0.4, 0.4))
	# 2 Bommelmütze: red knit, white band, pompom.
	b.part(&"hat_2")
	var knit := Color(0.75, 0.12, 0.12)
	b.tube([Vector3(0.0, 1.66, 0.005), Vector3(0.0, 1.74, 0.005), Vector3(0.0, 1.8, 0.0), Vector3(0.0, 1.83, -0.005)],
			[Vector2(0.135, 0.148), Vector2(0.13, 0.143), Vector2(0.1, 0.11), Vector2(0.05, 0.055)], &"wool", knit, &"head", 10)
	b.tube([Vector3(0.0, 1.66, 0.005), Vector3(0.0, 1.71, 0.005)], [Vector2(0.14, 0.153), Vector2(0.138, 0.151)], &"wool", Color(0.92, 0.9, 0.86), &"head", 10, false)
	b.ball(Vector3(0.0, 1.86, -0.005), Vector3(0.055, 0.05, 0.055), &"wool", Color(0.92, 0.9, 0.86), &"head", 7, 5)
	# 3 Stirnband: a wool headband over the ears.
	b.part(&"hat_3")
	b.tube([Vector3(0.0, 1.66, 0.01), Vector3(0.0, 1.715, 0.01)], [Vector2(0.13, 0.142), Vector2(0.126, 0.138)], &"wool", Color(0.15, 0.4, 0.65), &"head", 10, false)
	b.tube([Vector3(0.0, 1.685, 0.01), Vector3(0.0, 1.69, 0.01)], [Vector2(0.132, 0.144), Vector2(0.132, 0.144)], &"plain", Color(0.95, 0.95, 0.95), &"head", 10, false)
	# 4 Skihelm with the goggles pushed up.
	b.part(&"hat_4")
	var shell := Color(0.9, 0.9, 0.88)
	b.tube([Vector3(0.0, 1.675, 0.015), Vector3(0.0, 1.74, 0.012), Vector3(0.0, 1.79, 0.008), Vector3(0.0, 1.815, 0.005), Vector3(0.0, 1.822, 0.005)],
			[Vector2(0.14, 0.155), Vector2(0.138, 0.152), Vector2(0.11, 0.124), Vector2(0.06, 0.07), Vector2(0.003, 0.003)], &"plain", shell, &"head", 10)
	b.tube([Vector3(0.0, 1.705, 0.015), Vector3(0.0, 1.735, 0.015)], [Vector2(0.142, 0.157), Vector2(0.141, 0.156)], &"plain", Color(0.12, 0.12, 0.12), &"head", 10, false)
	b.box(Vector3(0.0, 1.72, -0.145), Vector3(0.17, 0.05, 0.03), &"plain", Color(0.95, 0.6, 0.15), &"head", Basis(Vector3.RIGHT, 0.25))
	# 5 Schildkappe: a cap with a peak.
	b.part(&"hat_5")
	var cap := Color(0.25, 0.28, 0.3)
	_cap(b, cap)
	_stuffed_hats(b)


func _cap(b: Builder, cap: Color) -> void:
	b.tube([Vector3(0.0, 1.69, 0.012), Vector3(0.0, 1.76, 0.01), Vector3(0.0, 1.8, 0.005), Vector3(0.0, 1.812, 0.005)],
			[Vector2(0.13, 0.142), Vector2(0.12, 0.132), Vector2(0.075, 0.085), Vector2(0.003, 0.003)], &"wool", cap, &"head", 10)
	b.box(Vector3(0.0, 1.695, -0.18), Vector3(0.2, 0.012, 0.11), &"wool", cap.darkened(0.15), &"head", Basis(Vector3.RIGHT, -0.12))


## The stuffed hats (M8, user request 2026-10-19): animals from stuffed.gd, and the earned ones
## (HikerStyle.LOCKED) after them.
func _stuffed_hats(b: Builder) -> void:
	# 6 Mankei-Haubn: a Murmeltier lying on the head, its tail down the back.
	b.part(&"hat_6")
	Stuffed.new(b, Stuffed.place(Vector3(0.0, 1.705, 0.0)), &"head").marmot_lying()
	# 7 Fuchspelz: a fox-fur hat with the fox's head at the front and its tail down to the shoulder.
	b.part(&"hat_7")
	var fox := Color(0.78, 0.36, 0.12)
	var white := Color(0.93, 0.9, 0.85)
	var black := Color(0.08, 0.06, 0.05)
	b.tube([Vector3(0.0, 1.665, 0.005), Vector3(0.0, 1.75, 0.005), Vector3(0.0, 1.835, 0.0)],
			[Vector2(0.138, 0.151), Vector2(0.143, 0.156), Vector2(0.135, 0.148)], &"fur", fox, &"head", 10)
	b.ball(Vector3(0.0, 1.765, -0.165), Vector3(0.055, 0.05, 0.05), &"fur", fox, &"head", 8, 6)
	b.spike([Vector3(0.0, 1.755, -0.2), Vector3(0.0, 1.745, -0.24), Vector3(0.0, 1.738, -0.27)], 0.028, &"fur", fox, &"head", 6)
	b.ball(Vector3(0.0, 1.739, -0.272), Vector3.ONE * 0.011, &"plain", black, &"head", 5, 3)
	for x: float in [-1.0, 1.0]:
		b.ball(Vector3(0.03 * x, 1.74, -0.2), Vector3(0.026, 0.02, 0.03), &"fur", white, &"head", 6, 4)
		b.ball(Vector3(0.027 * x, 1.778, -0.21), Vector3.ONE * 0.009, &"plain", Stuffed.GLASS, &"head", 5, 3)
		b.spike([Vector3(0.035 * x, 1.795, -0.165), Vector3(0.042 * x, 1.83, -0.168), Vector3(0.046 * x, 1.86, -0.17)], 0.022, &"fur", fox, &"head", 5)
		b.tube([Vector3(0.13 * x, 1.72, -0.07), Vector3(0.145 * x, 1.63, -0.07)], [Vector2(0.017, 0.017), Vector2(0.014, 0.014)], &"fur", black, &"head", 5)
	b.tube([Vector3(0.1, 1.74, 0.11), Vector3(0.14, 1.62, 0.13), Vector3(0.15, 1.5, 0.1), Vector3(0.14, 1.41, 0.06)],
			[Vector2(0.04, 0.04), Vector2(0.05, 0.05), Vector2(0.045, 0.045), Vector2(0.032, 0.032)], &"fur", fox, &"head", 7)
	b.spike([Vector3(0.14, 1.41, 0.06), Vector3(0.135, 1.37, 0.05), Vector3(0.13, 1.33, 0.04)], 0.032, &"fur", white, &"head", 6)
	# 8 Auerhahn-Huat: a low felt hat with a whole Auerhahn displaying on top.
	b.part(&"hat_8")
	var felt := Color(0.3, 0.22, 0.14)
	b.tube([Vector3(0.0, 1.735, 0.0), Vector3(0.0, 1.75, 0.0)], [Vector2(0.2, 0.21), Vector2(0.19, 0.2)], &"wool", felt, &"head", 10)
	b.tube([Vector3(0.0, 1.74, 0.0), Vector3(0.0, 1.8, 0.0), Vector3(0.0, 1.835, 0.0)], [Vector2(0.13, 0.14), Vector2(0.125, 0.135), Vector2(0.11, 0.12)], &"wool", felt, &"head", 9)
	b.tube([Vector3(0.0, 1.75, 0.0), Vector3(0.0, 1.775, 0.0)], [Vector2(0.132, 0.142), Vector2(0.13, 0.14)], &"plain", Color(0.15, 0.3, 0.18), &"head", 9, false)
	Stuffed.new(b, Stuffed.place(Vector3(0.0, 1.83, 0.01), 0.48), &"head").auerhahn()
	# 9 Marder-Haubn: an Edelmarder curled round the head like a stole, biting its own tail.
	b.part(&"hat_9")
	var ring := func(a: float) -> Vector3:
		return Vector3(sin(a) * 0.142, 1.715 + 0.018 * cos(a), -0.02 - cos(a) * 0.152)
	var spine: Array = []
	for i: int in 13:
		spine.append(ring.call(0.3 + float(i) * 0.43))
	var tail: Array = [ring.call(0.3 + 12.0 * 0.43), ring.call(TAU - 0.3) + Vector3(0.0, 0.02, 0.0),
			ring.call(TAU - 0.08) + Vector3(0.0, 0.05, -0.01), Vector3(0.05, 1.79, -0.16)]
	Stuffed.new(b, Transform3D.IDENTITY, &"head").marten(spine, tail, Vector3(-0.35, 0.0, -1.0), false)
	# 10 Raurakl-Kappl (earned): the Kappl with the Raurakl sitting on it.
	b.part(&"hat_10")
	_cap(b, Color(0.22, 0.26, 0.2))
	Stuffed.new(b, Stuffed.place(Vector3(0.0, 1.79, 0.02), 0.85), &"head").raurakl()
	# 11 Perchtn-Haubn (earned): a shaggy hood with the Perchte's horns and a little bell.
	b.part(&"hat_11")
	var shag := Color(0.36, 0.26, 0.17)
	var bone := Color(0.9, 0.86, 0.74)
	b.ball(Vector3(0.0, 1.69, 0.03), Vector3(0.137, 0.127, 0.142), &"fur", shag, &"head", 10, 7)
	for i: int in 9:
		var a: float = PI * (0.08 + 0.84 * float(i) / 8.0)
		var at := Vector3(cos(a) * 0.13, 1.66, 0.03 + sin(a) * 0.13)
		var out := Vector3(cos(a), 0.0, sin(a)) * 0.03
		b.spike([at, at + out + Vector3(0, -0.08, 0), at + out * 1.5 + Vector3(0, -0.15, 0)], 0.045, &"fur", shag.lightened(0.06 * float(i % 3)), &"head", 5)
	for x: float in [-1.0, 1.0]:
		b.spike([Vector3(0.08 * x, 1.79, 0.0), Vector3(0.13 * x, 1.87, 0.02), Vector3(0.14 * x, 1.94, 0.07), Vector3(0.11 * x, 1.99, 0.12)], 0.03, &"plain", bone, &"head", 6)
	b.tube([Vector3(0.0, 1.55, 0.16), Vector3(0.0, 1.49, 0.165)], [Vector2(0.022, 0.018), Vector2(0.035, 0.03)], &"metal", Color(0.75, 0.6, 0.3), &"head", 6)
	# 12 Krampus-Hörndl (earned): his horns on a black fur band.
	b.part(&"hat_12")
	var band := Color(0.09, 0.08, 0.08)
	b.tube([Vector3(0.0, 1.715, 0.012), Vector3(0.0, 1.76, 0.012)], [Vector2(0.123, 0.135), Vector2(0.112, 0.124)], &"fur", band, &"head", 10, false)
	for x: float in [-1.0, 1.0]:
		var root := Vector3(0.065 * x, 1.765, -0.03)
		b.ball(root, Vector3(0.04, 0.03, 0.04), &"fur", band, &"head", 6, 4)
		Stuffed.new(b, Stuffed.place(root, 0.6), &"head").krampus_horn(Vector3.ZERO, x, Color(0.25, 0.2, 0.16), 0.06)
