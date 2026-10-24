extends SceneTree
## Builds the enemy models (M6 part 4; the Venedigermandl, M9 part 5a) into assets/models/enemies, each at its EnemyData
## model_scale, with the stance and swing its EnemyRig plays, and the living Deitscha Tourist
## (assets/models/guest.tscn, part 4c):
##
##     godot --headless --script res://tools/models/build_enemies.gd
##
## Every figure stands on the standard skeleton (CharacterBuilder.skeleton); the skull sits at about
## 1.63 m (scale 1), where the head hurtbox is. Colours are the greybox ones, so they read the same.

const Builder := preload("res://tools/models/character_builder.gd")
const RIG := preload("res://scripts/enemies/enemy_rig.gd")
const OUT: String = "res://assets/models/enemies"

const PELVIS := Vector3(0.0, 0.95, 0.0)
const WAIST := Vector3(0.0, 1.12, 0.0)
const NECK := Vector3(0.0, 1.5, 0.0)
const SHOULDER := Vector3(-0.22, 1.43, 0.0)
const ELBOW := Vector3(-0.25, 1.15, 0.0)
const WRIST := Vector3(-0.26, 0.9, 0.0)
const HIP := Vector3(-0.1, 0.92, 0.0)
const KNEE := Vector3(-0.11, 0.5, 0.0)
const ANKLE := Vector3(-0.11, 0.09, 0.0)

const ZOMBIE_SKIN := Color(0.55, 0.62, 0.5)
const EYE := Color(1.0, 0.85, 0.35)
const MOUTH := Color(0.12, 0.04, 0.04)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_wanderer()
	_tourist()
	_knappe()
	_perchte()
	_krampus()
	_mandl()
	_guest()
	print("enemy models built")
	quit()


func _scale(id: String) -> float:
	return (load("res://data/enemies/%s.tres" % id) as EnemyData).model_scale


func _standard(b: Builder) -> void:
	b.skeleton(PELVIS, WAIST, NECK, SHOULDER, ELBOW, WRIST, HIP, KNEE, ANKLE)


## `f` is called for the left side (mirror (1,1,1), suffix "_l") and then the right.
func _both(f: Callable) -> void:
	f.call(Vector3.ONE, "_l")
	f.call(Vector3(-1.0, 1.0, 1.0), "_r")


## A torso tube: rings of [height, half width, half depth, z offset] from the hips up; those below
## the waist ride on the hips, the waist ring on both, the rest on the chest.
func _torso(b: Builder, rings: Array, material: StringName, color: Color, sides: int = 8) -> void:
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
	b.tube(path, radii, material, color, rig, sides)


## A limb from `from` to `to` (left side; both are built), its first ring shared with `parent`.
func _limb(b: Builder, from: Vector3, to: Vector3, r_from: Vector2, r_to: Vector2, material: StringName,
		color: Color, bone: String, parent: String, sides: int = 7) -> void:
	_both(func(m: Vector3, s: String) -> void:
		var p := StringName(parent if parent in ["hips", "chest"] else parent + s)
		var own := StringName(bone + s)
		b.tube([from * m, from.lerp(to, 0.5) * m, to * m], [r_from, r_from.lerp(r_to, 0.5), r_to],
				material, color, [[p, own, 0.5], own, own], sides))


func _arms(b: Builder, upper: Vector2, lower: Vector2, material: StringName, color: Color) -> void:
	_limb(b, SHOULDER + Vector3(0.0, 0.03, 0.0), ELBOW, upper, upper * 0.88, material, color, "arm", "chest")
	_limb(b, ELBOW, WRIST, upper * 0.85, lower, material, color, "forearm", "arm")


func _legs(b: Builder, upper: Vector2, lower: Vector2, thigh_material: StringName, thigh_color: Color,
		shin_material: StringName, shin_color: Color) -> void:
	_limb(b, HIP + Vector3(0.0, 0.05, 0.0), KNEE, upper, upper * 0.82, thigh_material, thigh_color, "thigh", "hips")
	_limb(b, KNEE + Vector3(0.0, 0.03, 0.0), ANKLE, upper * 0.78, lower, shin_material, shin_color, "shin", "thigh")


func _hands(b: Builder, color: Color, material: StringName = &"skin", size: Vector3 = Vector3(0.045, 0.065, 0.035)) -> void:
	_both(func(m: Vector3, s: String) -> void:
		b.ball((WRIST + Vector3(0.0, -0.07, 0.0)) * m, size, material, color, StringName("hand" + s), 6, 4))


func _boots(b: Builder, color: Color, size: Vector3 = Vector3(0.12, 0.11, 0.27), material: StringName = &"leather") -> void:
	_both(func(m: Vector3, s: String) -> void:
		b.box(Vector3(ANKLE.x * m.x, size.y * 0.5, -0.05), size, material, color, StringName("foot" + s), Basis.IDENTITY, Vector2(0.85, 0.8)))


## A human head: skull, nose, brow, ears, mouth, glowing eyes and a neck. `face_z` is the front.
func _face(b: Builder, skin: Color, eye: Color = EYE, centre: Vector3 = Vector3(0.0, 1.63, -0.02),
		radii: Vector3 = Vector3(0.115, 0.14, 0.125), alive: bool = false) -> void:
	var front: float = centre.z - radii.z
	b.tube([Vector3(0.0, 1.46, 0.0), Vector3(0.0, 1.56, -0.01)], [Vector2(0.055, 0.055), Vector2(0.05, 0.05)], &"skin", skin, [[&"chest", &"head", 0.5], &"head"], 6, false)
	b.head(true)
	b.ball(centre, radii, &"skin", skin, &"head", 10, 7)
	b.box(Vector3(0.0, centre.y - 0.01, front - 0.015), Vector3(0.035, 0.06, 0.05), &"skin", skin.darkened(0.08), &"head", Basis.IDENTITY, Vector2(0.4, 0.3))
	b.box(Vector3(0.0, centre.y + 0.045, front + 0.012), Vector3(0.19, 0.03, 0.04), &"skin", skin.darkened(0.25), &"head")
	for x: float in [-1.0, 1.0]:
		if alive:
			# The living: white eyes with dark pupils, no glow.
			b.box(Vector3(0.048 * x, centre.y + 0.022, front + 0.008), Vector3(0.04, 0.022, 0.012), &"plain", Color(0.92, 0.9, 0.86), &"head")
			b.box(Vector3(0.048 * x, centre.y + 0.022, front + 0.002), Vector3(0.016, 0.016, 0.006), &"plain", Color(0.12, 0.2, 0.3), &"head")
		else:
			b.box(Vector3(0.048 * x, centre.y + 0.022, front + 0.012), Vector3(0.05, 0.03, 0.02), &"plain", Color(0.06, 0.05, 0.05), &"head")
			b.box(Vector3(0.048 * x, centre.y + 0.022, front + 0.004), Vector3(0.03, 0.016, 0.01), &"glow", eye, &"head")
		b.ball(Vector3(radii.x * x, centre.y, centre.z + 0.01), Vector3(0.02, 0.04, 0.03), &"skin", skin.darkened(0.1), &"head", 5, 3)
	b.box(Vector3(0.0, centre.y - 0.07, front + 0.018), Vector3(0.075, 0.018, 0.02), &"plain", MOUTH, &"head")
	b.head(false)


func _wanderer() -> void:
	var b := Builder.new(_scale("wanderer"))
	_standard(b)
	var jacket := Color(0.72, 0.14, 0.1)
	var breeches := Color(0.36, 0.24, 0.13)
	var socks := Color(0.85, 0.8, 0.7)
	var felt := Color(0.17, 0.3, 0.17)
	_torso(b, [[0.86, 0.17, 0.12], [1.0, 0.16, 0.11], [WAIST.y, 0.165, 0.115], [1.25, 0.2, 0.13], [1.4, 0.23, 0.13], [1.47, 0.17, 0.1], [1.5, 0.07, 0.06]], &"wool", jacket)
	# Knickerbockers over knee socks, mountain boots.
	_torso(b, [[0.8, 0.175, 0.125], [0.9, 0.18, 0.13]], &"leather", breeches)
	_legs(b, Vector2(0.085, 0.09), Vector2(0.05, 0.055), &"leather", breeches, &"wool", socks)
	_boots(b, Color(0.22, 0.15, 0.1))
	_arms(b, Vector2(0.065, 0.065), Vector2(0.048, 0.048), &"wool", jacket)
	_hands(b, ZOMBIE_SKIN)
	# Rucksack with a bedroll strapped on top.
	b.box(Vector3(0.0, 1.17, 0.2), Vector3(0.34, 0.42, 0.17), &"wool", Color(0.3, 0.33, 0.2), &"chest", Basis.IDENTITY, Vector2(0.9, 0.85))
	b.box(Vector3(0.0, 1.06, 0.29), Vector3(0.26, 0.14, 0.05), &"wool", Color(0.26, 0.28, 0.17), &"chest")
	b.tube([Vector3(-0.2, 1.43, 0.2), Vector3(0.2, 1.43, 0.2)], [Vector2(0.06, 0.06), Vector2(0.06, 0.06)], &"linen", Color(0.75, 0.7, 0.62), &"chest", 7, true, Vector3.UP)
	_both(func(m: Vector3, _s: String) -> void:
		b.box(Vector3(-0.12, 1.25, -0.125) * m, Vector3(0.05, 0.42, 0.02), &"leather", Color(0.2, 0.14, 0.09), &"chest"))
	_face(b, ZOMBIE_SKIN)
	# Tyrolean felt hat with a band and a feather.
	b.head(true)
	b.tube([Vector3(0.0, 1.735, -0.02), Vector3(0.0, 1.75, -0.02)], [Vector2(0.21, 0.21), Vector2(0.2, 0.2)], &"wool", felt, &"head", 10)
	b.tube([Vector3(0.0, 1.74, -0.02), Vector3(0.0, 1.8, -0.02), Vector3(0.0, 1.88, -0.025)], [Vector2(0.125, 0.13), Vector2(0.115, 0.12), Vector2(0.085, 0.095)], &"wool", felt, &"head", 9)
	b.tube([Vector3(0.0, 1.75, -0.02), Vector3(0.0, 1.78, -0.02)], [Vector2(0.127, 0.132), Vector2(0.124, 0.13)], &"leather", Color(0.15, 0.1, 0.06), &"head", 9, false)
	b.box(Vector3(0.12, 1.86, 0.03), Vector3(0.015, 0.17, 0.045), &"plain", Color(0.88, 0.86, 0.8), &"head", Basis(Vector3.RIGHT, -0.35), Vector2(0.4, 0.4))
	b.head(false)
	b.ragdoll({&"arm_l": 0.065, &"forearm_l": 0.05, &"arm_r": 0.065, &"forearm_r": 0.05,
			&"thigh_l": 0.085, &"shin_l": 0.06, &"thigh_r": 0.085, &"shin_r": 0.06},
			Vector3(0.32, 0.22, 0.24), Vector3(0.4, 0.38, 0.26), 0.13)
	b.save(OUT + "/wanderer.tscn", "WandererModel", RIG, {
		"build_scale": b.scale,
		"stance": {&"arm_l": Vector3(80, 0, -4), &"arm_r": Vector3(70, 0, 6), &"forearm_l": Vector3(12, 0, 0),
				&"forearm_r": Vector3(18, 0, 0), &"chest": Vector3(-8, 0, 0), &"head": Vector3(8, 0, 6)},
		"stride": 26.0, "arm_swing": 6.0, "cadence": 1.5})


func _tourist() -> void:
	var b := Builder.new(_scale("tourist"))
	_standard(b)
	var jacket := Color(0.1, 0.72, 0.78)
	_torso(b, [[0.86, 0.17, 0.13], [1.0, 0.185, 0.17, -0.03], [WAIST.y, 0.19, 0.17, -0.04], [1.25, 0.2, 0.15, -0.02], [1.4, 0.22, 0.13], [1.47, 0.16, 0.1], [1.5, 0.07, 0.06]], &"plain", jacket)
	# Khaki shorts, bare knees, white socks in sandals.
	_torso(b, [[0.74, 0.18, 0.13], [0.9, 0.18, 0.135]], &"linen", Color(0.95, 0.88, 0.7))
	_both(func(m: Vector3, s: String) -> void:
		var own := StringName("thigh" + s)
		b.tube([(HIP + Vector3(0, 0.05, 0)) * m, Vector3(-0.115, 0.66, 0.0) * m], [Vector2(0.095, 0.1), Vector2(0.09, 0.095)], &"linen", Color(0.95, 0.88, 0.7), [[&"hips", own, 0.5], own], 7)
		b.tube([Vector3(-0.112, 0.68, 0.0) * m, KNEE * m], [Vector2(0.06, 0.065), Vector2(0.055, 0.058)], &"skin", ZOMBIE_SKIN, own, 6, false)
		var shin := StringName("shin" + s)
		b.tube([(KNEE + Vector3(0, 0.02, 0)) * m, Vector3(-0.11, 0.3, 0.0) * m], [Vector2(0.055, 0.058), Vector2(0.05, 0.052)], &"skin", ZOMBIE_SKIN, [[own, shin, 0.5], shin], 6, false)
		b.tube([Vector3(-0.11, 0.32, 0.0) * m, (ANKLE + Vector3(0, -0.02, 0)) * m], [Vector2(0.056, 0.058), Vector2(0.05, 0.052)], &"wool", Color(0.95, 0.95, 0.92), shin, 6)
		var foot := StringName("foot" + s)
		b.box(Vector3(-0.11, 0.06, -0.06) * m, Vector3(0.1, 0.07, 0.22), &"wool", Color(0.95, 0.95, 0.92), foot, Basis.IDENTITY, Vector2(0.8, 0.8))
		b.box(Vector3(-0.11, 0.015, -0.06) * m, Vector3(0.12, 0.03, 0.27), &"leather", Color(0.3, 0.2, 0.12), foot)
		b.box(Vector3(-0.11, 0.07, -0.1) * m, Vector3(0.125, 0.02, 0.04), &"leather", Color(0.3, 0.2, 0.12), foot))
	_arms(b, Vector2(0.07, 0.07), Vector2(0.05, 0.05), &"plain", jacket)
	_hands(b, ZOMBIE_SKIN)
	# Bum bag and the camera on its strap.
	b.box(Vector3(0.0, 0.97, -0.2), Vector3(0.2, 0.09, 0.07), &"plain", Color(0.45, 0.08, 0.12), &"hips", Basis.IDENTITY, Vector2(0.9, 0.7))
	b.box(Vector3(0.0, 1.02, -0.06), Vector3(0.4, 0.03, 0.3), &"plain", Color(0.1, 0.1, 0.1), &"hips")
	b.box(Vector3(0.0, 1.27, -0.175), Vector3(0.13, 0.08, 0.06), &"plain", Color(0.15, 0.15, 0.16), &"chest")
	b.tube([Vector3(0.03, 1.26, -0.2), Vector3(0.03, 1.26, -0.25)], [Vector2(0.028, 0.028), Vector2(0.025, 0.025)], &"plain", Color(0.06, 0.06, 0.07), &"chest", 8)
	b.box(Vector3(0.03, 1.26, -0.252), Vector3(0.035, 0.035, 0.005), &"glow", Color(0.35, 0.45, 0.6), &"chest")
	b.tube([Vector3(-0.07, 1.3, -0.18), Vector3(-0.12, 1.45, -0.08), Vector3(0.0, 1.5, 0.06), Vector3(0.12, 1.45, -0.08), Vector3(0.07, 1.3, -0.18)],
			[Vector2(0.008, 0.01), Vector2(0.008, 0.01), Vector2(0.008, 0.01), Vector2(0.008, 0.01), Vector2(0.008, 0.01)], &"plain", Color(0.08, 0.08, 0.08), &"chest", 4, false)
	_face(b, ZOMBIE_SKIN)
	b.head(true)
	# Sunglasses over the glowing eyes, and a bucket hat.
	b.box(Vector3(0.0, 1.652, -0.152), Vector3(0.2, 0.045, 0.012), &"plain", Color(0.03, 0.03, 0.04), &"head")
	b.tube([Vector3(0.0, 1.72, -0.02), Vector3(0.0, 1.74, -0.02)], [Vector2(0.18, 0.18), Vector2(0.15, 0.15)], &"linen", Color(0.95, 0.9, 0.75), &"head", 10)
	b.tube([Vector3(0.0, 1.73, -0.02), Vector3(0.0, 1.81, -0.02)], [Vector2(0.13, 0.135), Vector2(0.11, 0.115)], &"linen", Color(0.95, 0.9, 0.75), &"head", 10)
	b.head(false)
	b.ragdoll({&"arm_l": 0.07, &"forearm_l": 0.05, &"arm_r": 0.07, &"forearm_r": 0.05,
			&"thigh_l": 0.09, &"shin_l": 0.055, &"thigh_r": 0.09, &"shin_r": 0.055},
			Vector3(0.34, 0.22, 0.28), Vector3(0.4, 0.38, 0.32), 0.13)
	b.save(OUT + "/tourist.tscn", "TouristModel", RIG, {
		"build_scale": b.scale,
		"stance": {&"arm_l": Vector3(75, 0, -6), &"arm_r": Vector3(35, 0, 10), &"forearm_r": Vector3(70, 0, 0),
				&"forearm_l": Vector3(10, 0, 0), &"chest": Vector3(4, 0, 0), &"head": Vector3(-4, 0, -6)},
		"stride": 24.0, "arm_swing": 8.0, "cadence": 1.8})


func _knappe() -> void:
	var b := Builder.new(_scale("knappe"))
	_standard(b)
	var coat := Color(0.1, 0.1, 0.11)
	var leather := Color(0.3, 0.18, 0.09)
	var brass := Color(0.85, 0.65, 0.25)
	# The miner's Bergkittel, buttoned to the neck, over a round belly.
	_torso(b, [[0.74, 0.21, 0.16], [0.86, 0.2, 0.16, -0.01], [1.0, 0.205, 0.18, -0.03], [WAIST.y, 0.21, 0.18, -0.035], [1.26, 0.23, 0.16, -0.02], [1.4, 0.25, 0.14], [1.47, 0.18, 0.11], [1.5, 0.08, 0.07]], &"wool", coat, 9)
	for i: int in 5:
		b.box(Vector3(0.0, 1.38 - i * 0.12, -0.15 - (0.035 if i in [2, 3] else 0.015)), Vector3(0.03, 0.03, 0.02), &"metal", brass, &"chest" if 1.38 - i * 0.12 > WAIST.y else &"hips")
	# The Arschleder at the back and the belt.
	b.box(Vector3(0.0, 0.84, 0.17), Vector3(0.38, 0.32, 0.03), &"leather", leather, &"hips", Basis(Vector3.RIGHT, 0.15))
	b.tube([Vector3(0.0, 0.98, -0.01), Vector3(0.0, 1.03, -0.015)], [Vector2(0.215, 0.19), Vector2(0.215, 0.19)], &"leather", Color(0.12, 0.08, 0.05), &"hips", 9, false)
	b.box(Vector3(0.0, 1.0, -0.2), Vector3(0.07, 0.06, 0.02), &"metal", brass, &"hips")
	_legs(b, Vector2(0.1, 0.1), Vector2(0.065, 0.07), &"wool", Color(0.13, 0.13, 0.14), &"wool", Color(0.13, 0.13, 0.14))
	_boots(b, Color(0.07, 0.06, 0.06), Vector3(0.14, 0.2, 0.28))
	_arms(b, Vector2(0.085, 0.085), Vector2(0.06, 0.06), &"wool", coat)
	# Shoulder pads of the uniform.
	_both(func(m: Vector3, s: String) -> void:
		b.ball((SHOULDER + Vector3(0.0, 0.04, 0.0)) * m, Vector3(0.1, 0.05, 0.1), &"wool", coat, StringName("arm" + s), 7, 4))
	_hands(b, ZOMBIE_SKIN, &"skin", Vector3(0.055, 0.06, 0.05))
	# A pick in the right hand: shaft forward, head up.
	var hand_r := Vector3(-WRIST.x, WRIST.y - 0.07, 0.0)
	b.tube([hand_r + Vector3(0, 0, 0.18), hand_r + Vector3(0, 0, -0.55)], [Vector2(0.022, 0.022), Vector2(0.025, 0.025)], &"wood", Color(0.55, 0.38, 0.22), &"hand_r", 6)
	b.tube([hand_r + Vector3(0, 0.26, -0.53), hand_r + Vector3(0, 0.02, -0.56), hand_r + Vector3(0, -0.17, -0.5)], [Vector2(0.008, 0.008), Vector2(0.03, 0.04), Vector2(0.008, 0.008)], &"metal", Color(0.5, 0.52, 0.55), &"hand_r", 5)
	_face(b, ZOMBIE_SKIN, EYE, Vector3(0.0, 1.63, -0.02), Vector3(0.125, 0.14, 0.13))
	b.head(true)
	# Grey beard, the helmet and its lamp.
	b.ball(Vector3(0.0, 1.55, -0.1), Vector3(0.11, 0.1, 0.07), &"fur", Color(0.42, 0.4, 0.38), &"head", 8, 5)
	b.spike([Vector3(0.0, 1.55, -0.13), Vector3(0.0, 1.45, -0.14), Vector3(0.0, 1.39, -0.12)], 0.06, &"fur", Color(0.42, 0.4, 0.38), &"head", 6)
	b.ball(Vector3(0.0, 1.71, -0.02), Vector3(0.145, 0.11, 0.155), &"metal", Color(0.16, 0.16, 0.17), &"head", 10, 5)
	b.tube([Vector3(0.0, 1.69, -0.02), Vector3(0.0, 1.705, -0.02)], [Vector2(0.17, 0.18), Vector2(0.165, 0.175)], &"metal", Color(0.16, 0.16, 0.17), &"head", 10)
	b.tube([Vector3(0.0, 1.74, -0.15), Vector3(0.0, 1.74, -0.2)], [Vector2(0.035, 0.035), Vector2(0.04, 0.04)], &"metal", brass, &"head", 8)
	b.box(Vector3(0.0, 1.74, -0.202), Vector3(0.055, 0.055, 0.005), &"glow", Color(1.0, 0.95, 0.75), &"head")
	b.head(false)
	b.ragdoll({&"arm_l": 0.085, &"forearm_l": 0.065, &"arm_r": 0.085, &"forearm_r": 0.065,
			&"thigh_l": 0.1, &"shin_l": 0.07, &"thigh_r": 0.1, &"shin_r": 0.07},
			Vector3(0.4, 0.24, 0.34), Vector3(0.46, 0.4, 0.34), 0.14)
	b.save(OUT + "/knappe.tscn", "KnappeModel", RIG, {
		"build_scale": b.scale, "one_handed": true,
		"stance": {&"arm_r": Vector3(15, 0, 4), &"forearm_r": Vector3(25, 0, 0), &"arm_l": Vector3(40, 0, -8),
				&"forearm_l": Vector3(25, 0, 0), &"chest": Vector3(-12, 0, 0), &"head": Vector3(10, 0, 0)},
		"stride": 22.0, "arm_swing": 10.0, "cadence": 1.4})


## Shaggy fur: tufts hanging down around a ring of the body.
func _tufts(b: Builder, y: float, radius: Vector2, length: float, count: int, color: Color, bone: StringName, z: float = 0.0) -> void:
	for i: int in count:
		var a: float = TAU * float(i) / float(count) + 0.3
		var at := Vector3(cos(a) * radius.x, y, sin(a) * radius.y + z)
		var out := Vector3(cos(a), 0.0, sin(a)) * 0.04
		b.spike([at, at + out + Vector3(0, -length * 0.6, 0), at + out * 1.5 + Vector3(0, -length, 0)], 0.055, &"fur", color.lightened(0.06 * float(i % 3)), bone, 5)


func _perchte() -> void:
	var b := Builder.new(_scale("perchte"))
	_standard(b)
	var fur := Color(0.36, 0.26, 0.17)
	var mask := Color(0.55, 0.32, 0.16)
	var bone := Color(0.9, 0.86, 0.74)
	_torso(b, [[0.7, 0.22, 0.17], [0.86, 0.22, 0.17], [WAIST.y, 0.22, 0.17], [1.28, 0.25, 0.17], [1.42, 0.27, 0.16], [1.48, 0.2, 0.13], [1.52, 0.1, 0.09]], &"fur", fur, 9)
	_tufts(b, 0.78, Vector2(0.21, 0.16), 0.22, 9, fur.darkened(0.1), &"hips")
	_tufts(b, 1.2, Vector2(0.24, 0.17), 0.2, 9, fur, &"chest")
	_tufts(b, 1.46, Vector2(0.26, 0.16), 0.18, 8, fur.lightened(0.05), &"chest")
	# A belt of cowbells.
	b.tube([Vector3(0.0, 0.94, 0.0), Vector3(0.0, 0.99, 0.0)], [Vector2(0.235, 0.185), Vector2(0.235, 0.185)], &"leather", Color(0.15, 0.09, 0.05), &"hips", 9, false)
	for x: float in [-0.14, 0.0, 0.14]:
		b.tube([Vector3(x, 0.93, -0.2), Vector3(x, 0.83, -0.2)], [Vector2(0.03, 0.025), Vector2(0.05, 0.04)], &"metal", Color(0.75, 0.6, 0.3), &"hips", 6)
	_legs(b, Vector2(0.11, 0.11), Vector2(0.075, 0.075), &"fur", fur, &"fur", fur.darkened(0.15))
	_boots(b, Color(0.08, 0.06, 0.05), Vector3(0.12, 0.12, 0.18), &"plain")
	_arms(b, Vector2(0.09, 0.09), Vector2(0.07, 0.07), &"fur", fur)
	_both(func(m: Vector3, s: String) -> void:
		var hand := StringName("hand" + s)
		var w := (WRIST + Vector3(0.0, -0.05, 0.0)) * m
		b.ball(w, Vector3(0.05, 0.05, 0.045), &"skin", Color(0.25, 0.2, 0.16), hand, 6, 4)
		for k: int in 3:
			var x: float = (k - 1) * 0.025 * m.x
			b.spike([w + Vector3(x, -0.03, -0.02), w + Vector3(x, -0.1, -0.05), w + Vector3(x * 1.2, -0.14, -0.1)], 0.014, &"plain", bone, hand, 4))
	b.tube([Vector3(0.0, 1.46, 0.0), Vector3(0.0, 1.56, -0.02)], [Vector2(0.07, 0.07), Vector2(0.06, 0.06)], &"fur", fur, [[&"chest", &"head", 0.5], &"head"], 7, false)
	b.head(true)
	# The carved wooden mask: a long face, a snout full of teeth, a tongue, horns and a mane.
	b.box(Vector3(0.0, 1.64, -0.04), Vector3(0.24, 0.3, 0.24), &"wood", mask, &"head", Basis.IDENTITY, Vector2(0.85, 0.9))
	b.box(Vector3(0.0, 1.56, -0.2), Vector3(0.17, 0.12, 0.14), &"wood", mask.darkened(0.08), &"head", Basis.IDENTITY, Vector2(0.85, 0.8))
	b.box(Vector3(0.0, 1.73, -0.165), Vector3(0.23, 0.05, 0.05), &"wood", mask.darkened(0.25), &"head")
	b.box(Vector3(0.0, 1.5, -0.24), Vector3(0.13, 0.03, 0.05), &"plain", Color(0.2, 0.03, 0.03), &"head")
	for k: int in 6:
		var x: float = -0.055 + k * 0.022
		b.spike([Vector3(x, 1.515, -0.268), Vector3(x, 1.485, -0.27)], 0.009, &"plain", bone, &"head", 3)
	b.box(Vector3(0.02, 1.46, -0.25), Vector3(0.05, 0.08, 0.015), &"plain", Color(0.8, 0.15, 0.2), &"head", Basis(Vector3.FORWARD, 0.2))
	for x: float in [-1.0, 1.0]:
		b.box(Vector3(0.06 * x, 1.66, -0.162), Vector3(0.06, 0.04, 0.02), &"plain", Color(0.04, 0.02, 0.02), &"head")
		b.box(Vector3(0.06 * x, 1.66, -0.172), Vector3(0.035, 0.022, 0.01), &"glow", Color(1.0, 0.3, 0.12), &"head")
		b.spike([Vector3(0.09 * x, 1.77, -0.02), Vector3(0.15 * x, 1.88, 0.0), Vector3(0.16 * x, 1.98, 0.06), Vector3(0.12 * x, 2.04, 0.12)], 0.04, &"plain", bone, &"head", 6)
		b.spike([Vector3(0.12 * x, 1.7, 0.05), Vector3(0.2 * x, 1.6, 0.1), Vector3(0.22 * x, 1.42, 0.12)], 0.06, &"fur", fur.lightened(0.1), &"head", 5)
	_tufts(b, 1.78, Vector2(0.1, 0.1), 0.14, 6, fur.lightened(0.08), &"head", 0.05)
	b.head(false)
	b.ragdoll({&"arm_l": 0.09, &"forearm_l": 0.07, &"arm_r": 0.09, &"forearm_r": 0.07,
			&"thigh_l": 0.11, &"shin_l": 0.075, &"thigh_r": 0.11, &"shin_r": 0.075},
			Vector3(0.42, 0.24, 0.34), Vector3(0.5, 0.4, 0.34), 0.15)
	b.save(OUT + "/perchte.tscn", "PerchteModel", RIG, {
		"build_scale": b.scale,
		"stance": {&"arm_l": Vector3(55, 0, -22), &"arm_r": Vector3(55, 0, 22), &"forearm_l": Vector3(30, 0, 0),
				&"forearm_r": Vector3(30, 0, 0), &"chest": Vector3(-22, 0, 0), &"head": Vector3(18, 0, 0),
				&"thigh_l": Vector3(18, 0, -4), &"thigh_r": Vector3(18, 0, 4), &"shin_l": Vector3(-30, 0, 0), &"shin_r": Vector3(-30, 0, 0)},
		"stride": 34.0, "arm_swing": 14.0, "cadence": 1.2})


func _krampus() -> void:
	var b := Builder.new(_scale("krampus"))
	_standard(b)
	var fur := Color(0.09, 0.08, 0.08)
	var face := Color(0.6, 0.08, 0.06)
	var horn := Color(0.25, 0.2, 0.16)
	var iron := Color(0.35, 0.36, 0.38)
	_torso(b, [[0.66, 0.21, 0.16], [0.86, 0.22, 0.17], [WAIST.y, 0.23, 0.18], [1.28, 0.27, 0.19], [1.42, 0.29, 0.17], [1.48, 0.21, 0.13], [1.52, 0.1, 0.09]], &"fur", fur, 9)
	_tufts(b, 0.72, Vector2(0.21, 0.16), 0.24, 10, fur, &"hips")
	_tufts(b, 1.18, Vector2(0.25, 0.19), 0.2, 10, fur.lightened(0.04), &"chest")
	_tufts(b, 1.46, Vector2(0.28, 0.17), 0.2, 9, fur, &"chest")
	# Chains across the chest and a big Schelle on the back.
	for i: int in 7:
		var t: float = float(i) / 6.0
		var at: Vector3 = Vector3(-0.22, 1.4, -0.16).lerp(Vector3(0.2, 0.98, -0.2), t) + Vector3(0, 0, -0.03 * sin(t * PI))
		b.tube([at + Vector3(-0.025, 0.02, 0), at + Vector3(0.025, -0.02, 0)], [Vector2(0.018, 0.012), Vector2(0.018, 0.012)], &"metal", iron, &"chest" if at.y > WAIST.y else &"hips", 5)
	b.tube([Vector3(0.0, 1.3, 0.22), Vector3(0.0, 1.12, 0.26)], [Vector2(0.06, 0.05), Vector2(0.11, 0.09)], &"metal", Color(0.6, 0.48, 0.25), &"chest", 8)
	_legs(b, Vector2(0.12, 0.12), Vector2(0.075, 0.075), &"fur", fur, &"fur", fur)
	_both(func(m: Vector3, s: String) -> void:
		b.box(Vector3(ANKLE.x * m.x, 0.05, -0.04), Vector3(0.12, 0.1, 0.16), &"plain", Color(0.05, 0.04, 0.04), StringName("foot" + s), Basis.IDENTITY, Vector2(0.8, 0.7))
		b.box(Vector3(ANKLE.x * m.x, 0.05, -0.12), Vector3(0.02, 0.1, 0.03), &"plain", Color(0.02, 0.02, 0.02), StringName("foot" + s)))
	_arms(b, Vector2(0.1, 0.1), Vector2(0.075, 0.075), &"fur", fur)
	_both(func(m: Vector3, s: String) -> void:
		var hand := StringName("hand" + s)
		var w := (WRIST + Vector3(0.0, -0.05, 0.0)) * m
		b.ball(w, Vector3(0.055, 0.06, 0.05), &"skin", face.darkened(0.3), hand, 6, 4)
		for k: int in 4:
			var x: float = (k - 1.5) * 0.024 * m.x
			b.spike([w + Vector3(x, -0.04, -0.02), w + Vector3(x, -0.11, -0.05), w + Vector3(x * 1.2, -0.16, -0.1)], 0.014, &"plain", Color(0.85, 0.8, 0.7), hand, 4))
	# The Rute: a bundle of birch twigs in the right hand.
	var hand_r := Vector3(-WRIST.x, WRIST.y - 0.06, 0.0)
	b.tube([hand_r + Vector3(0, 0, 0.1), hand_r + Vector3(0, 0, -0.25)], [Vector2(0.03, 0.03), Vector2(0.032, 0.032)], &"leather", Color(0.3, 0.2, 0.12), &"hand_r", 6)
	for k: int in 7:
		var a: float = TAU * float(k) / 7.0
		var spread := Vector3(cos(a), sin(a), 0.0)
		b.spike([hand_r + Vector3(0, 0, -0.2) + spread * 0.015, hand_r + Vector3(0, 0, -0.5) + spread * 0.05, hand_r + Vector3(0, 0.02, -0.82) + spread * 0.1], 0.012, &"wood", Color(0.45, 0.35, 0.25), &"hand_r", 3)
	b.tube([Vector3(0.0, 1.46, 0.0), Vector3(0.0, 1.56, -0.02)], [Vector2(0.08, 0.08), Vector2(0.07, 0.07)], &"fur", fur, [[&"chest", &"head", 0.5], &"head"], 7, false)
	b.head(true)
	# The red devil's face: snout, open jaw with fangs, the long tongue, a goat beard, ears and horns.
	b.ball(Vector3(0.0, 1.64, -0.03), Vector3(0.13, 0.14, 0.13), &"skin", face, &"head", 10, 7)
	b.box(Vector3(0.0, 1.6, -0.17), Vector3(0.12, 0.08, 0.1), &"skin", face.darkened(0.1), &"head", Basis.IDENTITY, Vector2(0.8, 0.8))
	b.box(Vector3(0.0, 1.69, -0.14), Vector3(0.22, 0.04, 0.05), &"skin", face.darkened(0.35), &"head")
	b.box(Vector3(0.0, 1.53, -0.13), Vector3(0.13, 0.04, 0.1), &"skin", face.darkened(0.2), &"head", Basis(Vector3.RIGHT, 0.25))
	b.box(Vector3(0.0, 1.555, -0.17), Vector3(0.1, 0.03, 0.03), &"plain", Color(0.15, 0.02, 0.02), &"head")
	b.box(Vector3(0.015, 1.47, -0.2), Vector3(0.055, 0.17, 0.015), &"plain", Color(0.85, 0.2, 0.3), &"head", Basis(Vector3.RIGHT, 0.35))
	for x: float in [-1.0, 1.0]:
		b.spike([Vector3(0.04 * x, 1.575, -0.2), Vector3(0.043 * x, 1.535, -0.2)], 0.012, &"plain", Color(0.92, 0.88, 0.78), &"head", 3)
		b.box(Vector3(0.055 * x, 1.665, -0.15), Vector3(0.05, 0.03, 0.02), &"plain", Color(0.03, 0.01, 0.01), &"head")
		b.box(Vector3(0.055 * x, 1.665, -0.16), Vector3(0.035, 0.02, 0.01), &"glow", Color(1.0, 0.85, 0.2), &"head")
		b.spike([Vector3(0.12 * x, 1.66, 0.0), Vector3(0.21 * x, 1.7, 0.02), Vector3(0.26 * x, 1.74, 0.05)], 0.035, &"skin", face.darkened(0.2), &"head", 4)
		# Long curved horns, swept back and up.
		b.spike([Vector3(0.07 * x, 1.75, -0.04), Vector3(0.15 * x, 1.86, -0.01), Vector3(0.22 * x, 1.98, 0.06), Vector3(0.24 * x, 2.1, 0.16), Vector3(0.2 * x, 2.2, 0.28)], 0.05, &"plain", horn, &"head", 7)
		b.spike([Vector3(0.05 * x, 1.52, -0.12), Vector3(0.04 * x, 1.42, -0.12), Vector3(0.0, 1.32, -0.1)], 0.045, &"fur", Color(0.22, 0.2, 0.19), &"head", 5)
	_tufts(b, 1.76, Vector2(0.11, 0.11), 0.16, 7, fur, &"head", 0.04)
	b.head(false)
	b.ragdoll({&"arm_l": 0.1, &"forearm_l": 0.075, &"arm_r": 0.1, &"forearm_r": 0.075,
			&"thigh_l": 0.12, &"shin_l": 0.075, &"thigh_r": 0.12, &"shin_r": 0.075},
			Vector3(0.42, 0.26, 0.34), Vector3(0.54, 0.4, 0.36), 0.15)
	b.save(OUT + "/krampus.tscn", "KrampusModel", RIG, {
		"build_scale": b.scale, "one_handed": true,
		"stance": {&"arm_l": Vector3(40, 0, -28), &"arm_r": Vector3(20, 0, 20), &"forearm_l": Vector3(30, 0, 0),
				&"forearm_r": Vector3(25, 0, 0), &"chest": Vector3(-14, 0, 0), &"head": Vector3(10, 0, 0),
				&"thigh_l": Vector3(8, 0, -6), &"thigh_r": Vector3(8, 0, 6), &"shin_l": Vector3(-14, 0, 0), &"shin_r": Vector3(-14, 0, 0)},
		"stride": 22.0, "arm_swing": 12.0, "cadence": 1.1})


## Das Venedigermandl (M9 part 5a): a small hunched man from Venice in a long dark coat and a pointed
## hat, with a white beard, a pick in his right hand and a fat sack of gold on his back that glows
## through its seams. Alive (white eyes); built small (model_scale), so he is hard to hit.
func _mandl() -> void:
	var b := Builder.new(_scale("venedigermandl"))
	_standard(b)
	var coat := Color(0.16, 0.12, 0.1)
	var skin := Color(0.78, 0.58, 0.46)
	var hat := Color(0.52, 0.1, 0.08)
	var gold := Color(1.0, 0.78, 0.25)
	var sack := Color(0.5, 0.38, 0.22)
	# The long coat, down past the knees, and a rope belt.
	_torso(b, [[0.42, 0.22, 0.17], [0.6, 0.2, 0.15], [0.86, 0.18, 0.13], [1.0, 0.17, 0.125], [WAIST.y, 0.17, 0.12], [1.26, 0.2, 0.13], [1.4, 0.22, 0.13], [1.47, 0.16, 0.1], [1.5, 0.07, 0.06]], &"wool", coat, 9)
	b.tube([Vector3(0.0, 0.98, 0.0), Vector3(0.0, 1.01, 0.0)], [Vector2(0.178, 0.133), Vector2(0.178, 0.133)], &"linen", Color(0.62, 0.5, 0.32), &"hips", 9, false)
	_legs(b, Vector2(0.075, 0.08), Vector2(0.05, 0.055), &"wool", coat.darkened(0.2), &"wool", Color(0.3, 0.22, 0.14))
	_boots(b, Color(0.2, 0.12, 0.07), Vector3(0.11, 0.1, 0.25))
	_arms(b, Vector2(0.07, 0.07), Vector2(0.055, 0.055), &"wool", coat)
	_hands(b, skin)
	# The pick in the right hand: shaft forward, head up.
	var hand_r := Vector3(-WRIST.x, WRIST.y - 0.07, 0.0)
	b.tube([hand_r + Vector3(0, 0, 0.14), hand_r + Vector3(0, 0, -0.45)], [Vector2(0.02, 0.02), Vector2(0.022, 0.022)], &"wood", Color(0.5, 0.34, 0.2), &"hand_r", 6)
	b.tube([hand_r + Vector3(0, 0.22, -0.43), hand_r + Vector3(0, 0.02, -0.46), hand_r + Vector3(0, -0.15, -0.4)], [Vector2(0.007, 0.007), Vector2(0.026, 0.034), Vector2(0.007, 0.007)], &"metal", Color(0.5, 0.52, 0.55), &"hand_r", 5)
	# The sack of gold on his back: tied at the top, coins showing, the gold shining through the seams.
	b.ball(Vector3(0.0, 1.2, 0.27), Vector3(0.24, 0.28, 0.2), &"linen", sack, &"chest", 10, 7)
	b.tube([Vector3(0.0, 1.44, 0.27), Vector3(0.0, 1.52, 0.29)], [Vector2(0.07, 0.06), Vector2(0.1, 0.08)], &"linen", sack.darkened(0.1), &"chest", 8)
	b.tube([Vector3(0.0, 1.43, 0.27), Vector3(0.0, 1.46, 0.27)], [Vector2(0.075, 0.065), Vector2(0.075, 0.065)], &"leather", Color(0.25, 0.15, 0.08), &"chest", 8, false)
	b.ball(Vector3(0.0, 1.53, 0.29), Vector3(0.08, 0.035, 0.065), &"glow", gold, &"chest", 7, 3)
	for k: int in 3:
		var a: float = -0.6 + k * 0.6
		b.box(Vector3(sin(a) * 0.245, 1.2 + k * 0.05 - 0.05, 0.27 + cos(a) * 0.205), Vector3(0.012, 0.3, 0.012), &"glow", gold, &"chest", Basis(Vector3.FORWARD, a * 0.3))
	b.box(Vector3(-0.06, 1.0, 0.43), Vector3(0.05, 0.05, 0.012), &"glow", gold, &"chest", Basis(Vector3.RIGHT, 0.4))
	# The strap over the left shoulder.
	b.box(Vector3(0.11, 1.3, -0.12), Vector3(0.04, 0.38, 0.02), &"leather", Color(0.25, 0.15, 0.08), &"chest", Basis(Vector3.FORWARD, -0.35))
	_face(b, skin, EYE, Vector3(0.0, 1.63, -0.02), Vector3(0.11, 0.135, 0.12), true)
	b.head(true)
	# A big nose, bushy brows, the long white beard and the pointed hat with a gold band.
	b.ball(Vector3(0.0, 1.6, -0.16), Vector3(0.035, 0.04, 0.045), &"skin", skin.darkened(0.12), &"head", 6, 4)
	b.box(Vector3(0.0, 1.675, -0.135), Vector3(0.17, 0.025, 0.035), &"fur", Color(0.88, 0.86, 0.82), &"head")
	b.ball(Vector3(0.0, 1.53, -0.1), Vector3(0.1, 0.09, 0.07), &"fur", Color(0.9, 0.88, 0.84), &"head", 8, 5)
	b.spike([Vector3(0.0, 1.53, -0.13), Vector3(0.0, 1.4, -0.15), Vector3(0.0, 1.28, -0.13)], 0.075, &"fur", Color(0.9, 0.88, 0.84), &"head", 6)
	b.tube([Vector3(0.0, 1.71, -0.02), Vector3(0.0, 1.73, -0.02)], [Vector2(0.17, 0.17), Vector2(0.16, 0.16)], &"wool", hat, &"head", 10)
	b.spike([Vector3(0.0, 1.72, -0.02), Vector3(0.0, 1.9, 0.0), Vector3(0.0, 2.06, 0.06), Vector3(0.0, 2.16, 0.16)], 0.125, &"wool", hat, &"head", 9)
	b.tube([Vector3(0.0, 1.73, -0.02), Vector3(0.0, 1.76, -0.02)], [Vector2(0.126, 0.126), Vector2(0.122, 0.122)], &"glow", gold, &"head", 9, false)
	b.head(false)
	b.ragdoll({&"arm_l": 0.07, &"forearm_l": 0.055, &"arm_r": 0.07, &"forearm_r": 0.055,
			&"thigh_l": 0.08, &"shin_l": 0.055, &"thigh_r": 0.08, &"shin_r": 0.055},
			Vector3(0.36, 0.24, 0.28), Vector3(0.4, 0.38, 0.3), 0.13)
	b.save(OUT + "/venedigermandl.tscn", "VenedigermandlModel", RIG, {
		"build_scale": b.scale, "one_handed": true,
		"stance": {&"arm_r": Vector3(35, 0, 6), &"forearm_r": Vector3(40, 0, 0), &"arm_l": Vector3(-15, 0, -10),
				&"forearm_l": Vector3(60, 0, 0), &"chest": Vector3(-26, 0, 0), &"head": Vector3(24, 0, 0),
				&"thigh_l": Vector3(10, 0, -4), &"thigh_r": Vector3(10, 0, 4), &"shin_l": Vector3(-16, 0, 0), &"shin_r": Vector3(-16, 0, 0)},
		"stride": 32.0, "arm_swing": 8.0, "cadence": 1.6})


## The Deitscha Tourist (section 8a), alive (M6 part 4c): sunburnt, a striped shirt over his belly, a
## rucksack, khaki shorts, socks in sandals, glasses, a souvenir Tyrolean hat, and the map he holds
## out in front of him. Same skeleton and rig as the enemies; he walks, he never fights.
func _guest() -> void:
	var b := Builder.new(1.0)
	_standard(b)
	var skin := Color(0.86, 0.62, 0.52)
	var shirt := Color(0.85, 0.85, 0.82)
	var stripe := Color(0.2, 0.35, 0.65)
	var khaki := Color(0.95, 0.88, 0.7)
	_torso(b, [[0.86, 0.17, 0.13], [1.0, 0.2, 0.19, -0.04], [WAIST.y, 0.205, 0.19, -0.05], [1.25, 0.21, 0.16, -0.02], [1.4, 0.22, 0.13], [1.47, 0.16, 0.1], [1.5, 0.07, 0.06]], &"linen", shirt)
	# Stripes round the shirt (rings just proud of it).
	for y: float in [1.02, 1.18, 1.34]:
		var r: Vector2 = Vector2(0.204, 0.195) if y < 1.1 else Vector2(0.214, 0.17) if y < 1.3 else Vector2(0.224, 0.138)
		var z: float = -0.045 if y < 1.1 else -0.03 if y < 1.3 else -0.005
		b.tube([Vector3(0.0, y - 0.025, z), Vector3(0.0, y + 0.025, z)], [r, r], &"linen", stripe, &"chest" if y > WAIST.y else &"hips", 8, false)
	_torso(b, [[0.74, 0.18, 0.13], [0.9, 0.185, 0.14]], &"linen", khaki)
	b.tube([Vector3(0.0, 0.88, -0.01), Vector3(0.0, 0.92, -0.015)], [Vector2(0.19, 0.15), Vector2(0.19, 0.15)], &"leather", Color(0.25, 0.15, 0.08), &"hips", 8, false)
	_both(func(m: Vector3, s: String) -> void:
		var thigh := StringName("thigh" + s)
		var shin := StringName("shin" + s)
		var foot := StringName("foot" + s)
		b.tube([(HIP + Vector3(0, 0.05, 0)) * m, Vector3(-0.115, 0.66, 0.0) * m], [Vector2(0.095, 0.1), Vector2(0.09, 0.095)], &"linen", khaki, [[&"hips", thigh, 0.5], thigh], 7)
		b.tube([Vector3(-0.112, 0.68, 0.0) * m, KNEE * m], [Vector2(0.062, 0.066), Vector2(0.056, 0.06)], &"skin", skin, thigh, 6, false)
		b.tube([(KNEE + Vector3(0, 0.02, 0)) * m, Vector3(-0.11, 0.3, 0.0) * m], [Vector2(0.056, 0.06), Vector2(0.05, 0.053)], &"skin", skin, [[thigh, shin, 0.5], shin], 6, false)
		b.tube([Vector3(-0.11, 0.32, 0.0) * m, (ANKLE + Vector3(0, -0.02, 0)) * m], [Vector2(0.057, 0.059), Vector2(0.05, 0.052)], &"wool", Color(0.95, 0.95, 0.92), shin, 6)
		b.box(Vector3(-0.11, 0.06, -0.06) * m, Vector3(0.1, 0.07, 0.22), &"wool", Color(0.95, 0.95, 0.92), foot, Basis.IDENTITY, Vector2(0.8, 0.8))
		b.box(Vector3(-0.11, 0.015, -0.06) * m, Vector3(0.12, 0.03, 0.27), &"leather", Color(0.35, 0.22, 0.12), foot)
		b.box(Vector3(-0.11, 0.07, -0.1) * m, Vector3(0.125, 0.02, 0.04), &"leather", Color(0.35, 0.22, 0.12), foot))
	_arms(b, Vector2(0.066, 0.066), Vector2(0.046, 0.046), &"linen", shirt)
	# Short sleeves: the forearms are bare.
	_both(func(m: Vector3, s: String) -> void:
		var own := StringName("forearm" + s)
		b.tube([(ELBOW + Vector3(0, -0.02, 0)) * m, WRIST * m], [Vector2(0.05, 0.05), Vector2(0.042, 0.042)], &"skin", skin, own, 6))
	_hands(b, skin)
	# Rucksack, and the map held open in front of him (on the right hand, the left holding its edge).
	b.box(Vector3(0.0, 1.2, 0.2), Vector3(0.32, 0.4, 0.16), &"wool", Color(0.75, 0.3, 0.1), &"chest", Basis.IDENTITY, Vector2(0.9, 0.85))
	_both(func(m: Vector3, _s: String) -> void:
		b.box(Vector3(-0.11, 1.26, -0.13) * m, Vector3(0.045, 0.4, 0.02), &"plain", Color(0.15, 0.15, 0.15), &"chest"))
	var hand_r := Vector3(-WRIST.x, WRIST.y - 0.08, -0.02)
	b.box(hand_r + Vector3(-0.2, 0.0, -0.04), Vector3(0.36, 0.005, 0.26), &"plain", Color(0.92, 0.88, 0.72), &"hand_r", Basis(Vector3.RIGHT, -0.4))
	b.box(hand_r + Vector3(-0.17, 0.004, -0.06), Vector3(0.2, 0.004, 0.008), &"plain", Color(0.8, 0.2, 0.15), &"hand_r", Basis(Vector3.RIGHT, -0.4) * Basis(Vector3.UP, 0.4))
	_face(b, skin, EYE, Vector3(0.0, 1.63, -0.02), Vector3(0.115, 0.14, 0.125), true)
	b.head(true)
	# Glasses, a moustache, the souvenir hat.
	b.box(Vector3(0.0, 1.652, -0.15), Vector3(0.17, 0.035, 0.008), &"plain", Color(0.3, 0.25, 0.2), &"head")
	b.box(Vector3(0.0, 1.585, -0.148), Vector3(0.08, 0.018, 0.02), &"fur", Color(0.4, 0.3, 0.2), &"head")
	var felt := Color(0.2, 0.32, 0.2)
	b.tube([Vector3(0.0, 1.735, -0.02), Vector3(0.0, 1.75, -0.02)], [Vector2(0.2, 0.2), Vector2(0.19, 0.19)], &"wool", felt, &"head", 10)
	b.tube([Vector3(0.0, 1.74, -0.02), Vector3(0.0, 1.8, -0.02), Vector3(0.0, 1.87, -0.025)], [Vector2(0.125, 0.13), Vector2(0.115, 0.12), Vector2(0.085, 0.095)], &"wool", felt, &"head", 9)
	b.tube([Vector3(0.0, 1.75, -0.02), Vector3(0.0, 1.78, -0.02)], [Vector2(0.127, 0.132), Vector2(0.124, 0.13)], &"plain", Color(0.7, 0.15, 0.12), &"head", 9, false)
	b.box(Vector3(0.12, 1.86, 0.03), Vector3(0.015, 0.17, 0.045), &"plain", Color(0.95, 0.85, 0.3), &"head", Basis(Vector3.RIGHT, -0.35), Vector2(0.4, 0.4))
	b.head(false)
	b.ragdoll({&"arm_l": 0.066, &"forearm_l": 0.046, &"arm_r": 0.066, &"forearm_r": 0.046,
			&"thigh_l": 0.09, &"shin_l": 0.055, &"thigh_r": 0.09, &"shin_r": 0.055},
			Vector3(0.34, 0.22, 0.28), Vector3(0.42, 0.38, 0.34), 0.13)
	b.save("res://assets/models/guest.tscn", "GuestModel", RIG, {
		"build_scale": b.scale,
		"stance": {&"arm_l": Vector3(55, 0, 8), &"arm_r": Vector3(50, 0, -6), &"forearm_l": Vector3(45, 0, 0),
				&"forearm_r": Vector3(50, 0, 0), &"head": Vector3(-14, 0, 0)},
		"stride": 26.0, "arm_swing": 0.0, "cadence": 1.6})
