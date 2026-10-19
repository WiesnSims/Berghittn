extends RefCounted
## The stuffed animals (M8 cosmetics, user request 2026-10-19): a Mankei, an Auerhahn, an Edelmarder
## and the Raurakl, plus the trophy heads (Gams, Hirsch, Krampus, Perchte) and their plaques. Each is
## drawn once in its own frame (metres, facing -Z; animals stand on y = 0, heads come out of a plaque
## whose front is at z = 0) and `at` places it, so the same Mankei lies on a hiker's head
## (build_hiker.gd) and sits on the Stube's bar (build_trophies.gd).

const Builder := preload("res://tools/models/character_builder.gd")

const GLASS := Color(0.04, 0.03, 0.03)
const NOSE := Color(0.1, 0.07, 0.06)
const TEETH := Color(0.95, 0.86, 0.55)
const IVORY := Color(0.92, 0.88, 0.76)
const WOOD := Color(0.36, 0.22, 0.12)
const BRASS := Color(0.78, 0.62, 0.28)

var _b: Builder
var _at: Transform3D
var _turn: Basis
var _k: float
var _rig: Variant


func _init(builder: Builder, at: Transform3D, rig: Variant) -> void:
	_b = builder
	_at = at
	_k = at.basis.get_scale().x
	_turn = at.basis.orthonormalized()
	_rig = rig


## Placed at `origin`, `size` times life size, turned by `turn`.
static func place(origin: Vector3, size: float = 1.0, turn: Basis = Basis.IDENTITY) -> Transform3D:
	return Transform3D(turn.scaled(Vector3.ONE * size), origin)


# --- shapes in the animal's own frame -------------------------------------------------------------

func ball(centre: Vector3, radii: Vector3, material: StringName, color: Color, segments: int = 8, rings: int = 6,
		basis: Basis = Basis.IDENTITY) -> void:
	_b.ball(_at * centre, radii * _k, material, color, _rig, segments, rings, _turn * basis)


func box(centre: Vector3, size: Vector3, material: StringName, color: Color, basis: Basis = Basis.IDENTITY,
		taper: Vector2 = Vector2.ONE) -> void:
	_b.box(_at * centre, size * _k, material, color, _rig, _turn * basis, taper)


func tube(path: Array, radii: Array, material: StringName, color: Color, sides: int = 8, caps: bool = true) -> void:
	var placed: Array = []
	for p: Vector3 in path:
		placed.append(_at * p)
	var scaled: Array = []
	for r: Vector2 in radii:
		scaled.append(r * _k)
	_b.tube(placed, scaled, material, color, _rig, sides, caps, _turn * Vector3.RIGHT)


func spike(path: Array, base: float, material: StringName, color: Color, sides: int = 6) -> void:
	var placed: Array = []
	for p: Vector3 in path:
		placed.append(_at * p)
	_b.spike(placed, base * _k, material, color, _rig, sides)


## Where a ray from `centre` towards `direction` leaves the ellipsoid: eyes and ears sit on the skin.
static func surface(centre: Vector3, radii: Vector3, direction: Vector3) -> Vector3:
	var d: Vector3 = direction.normalized()
	return centre + d / sqrt(pow(d.x / radii.x, 2) + pow(d.y / radii.y, 2) + pow(d.z / radii.z, 2))


# --- the animals ----------------------------------------------------------------------------------

## Das Mankei (the Murmeltier) sitting up, paws to its chest, the way it whistles from its rock.
func marmot_sitting() -> void:
	var fur := Color(0.5, 0.38, 0.25)
	var belly := Color(0.7, 0.58, 0.42)
	var dark := Color(0.26, 0.18, 0.12)
	ball(Vector3(0.0, 0.16, 0.01), Vector3(0.12, 0.16, 0.11), &"fur", fur, 9, 7)
	ball(Vector3(0.0, 0.15, -0.045), Vector3(0.09, 0.12, 0.07), &"fur", belly)
	_marmot_head(Vector3(0.0, 0.35, -0.01), fur, belly, dark)
	for x: float in [-1.0, 1.0]:
		ball(Vector3(0.05 * x, 0.24, -0.09), Vector3(0.026, 0.045, 0.026), &"fur", fur)
		ball(Vector3(0.06 * x, 0.02, -0.06), Vector3(0.035, 0.02, 0.05), &"fur", dark)
	tube([Vector3(0.0, 0.05, 0.1), Vector3(0.0, 0.03, 0.17), Vector3(0.0, 0.025, 0.23)],
			[Vector2(0.03, 0.03), Vector2(0.032, 0.032), Vector2(0.022, 0.022)], &"fur", dark, 6)


## The Mankei lying flat on its belly (on a hiker's head), head up at the front, tail hanging down
## behind.
func marmot_lying() -> void:
	var fur := Color(0.5, 0.38, 0.25)
	var belly := Color(0.7, 0.58, 0.42)
	var dark := Color(0.26, 0.18, 0.12)
	ball(Vector3(0.0, 0.07, 0.02), Vector3(0.125, 0.075, 0.16), &"fur", fur, 9, 7)
	_marmot_head(Vector3(0.0, 0.09, -0.15), fur, belly, dark)
	for x: float in [-1.0, 1.0]:
		ball(Vector3(0.075 * x, 0.01, -0.11), Vector3(0.026, 0.022, 0.045), &"fur", dark)
		ball(Vector3(0.1 * x, 0.01, 0.13), Vector3(0.03, 0.022, 0.05), &"fur", dark)
	tube([Vector3(0.0, 0.07, 0.16), Vector3(0.0, 0.03, 0.21), Vector3(0.0, -0.06, 0.235), Vector3(0.0, -0.14, 0.22)],
			[Vector2(0.03, 0.03), Vector2(0.032, 0.032), Vector2(0.03, 0.03), Vector2(0.02, 0.02)], &"fur", dark, 6)


func _marmot_head(c: Vector3, fur: Color, belly: Color, dark: Color) -> void:
	var r := Vector3(0.072, 0.066, 0.075)
	ball(c, r, &"fur", fur)
	var muzzle: Vector3 = c + Vector3(0.0, -0.02, -0.065)
	ball(muzzle, Vector3(0.042, 0.032, 0.036), &"fur", belly)
	box(muzzle + Vector3(0.0, 0.015, -0.034), Vector3(0.024, 0.014, 0.012), &"plain", NOSE)
	box(muzzle + Vector3(0.0, -0.026, -0.026), Vector3(0.02, 0.024, 0.008), &"plain", TEETH)
	for x: float in [-1.0, 1.0]:
		ball(surface(c, r, Vector3(0.55 * x, 0.35, -0.75)), Vector3.ONE * 0.012, &"plain", GLASS, 6, 4)
		ball(surface(c, r, Vector3(0.75 * x, 0.6, 0.1)), Vector3(0.022, 0.02, 0.012), &"fur", dark, 6, 4)


## Der Auerhahn displaying: fanned tail, beard up, the red brow over the eye.
func auerhahn() -> void:
	var black := Color(0.11, 0.11, 0.12)
	var neck := Color(0.17, 0.17, 0.19)
	var green := Color(0.08, 0.3, 0.2)
	var brown := Color(0.34, 0.24, 0.15)
	var white := Color(0.9, 0.9, 0.88)
	ball(Vector3(0.0, 0.3, 0.03), Vector3(0.14, 0.15, 0.24), &"fur", black, 9, 7, Basis(Vector3.RIGHT, 0.35))
	ball(Vector3(0.0, 0.34, -0.13), Vector3(0.11, 0.12, 0.09), &"fur", green)
	tube([Vector3(0.0, 0.38, -0.15), Vector3(0.0, 0.47, -0.19), Vector3(0.0, 0.55, -0.2)],
			[Vector2(0.065, 0.06), Vector2(0.05, 0.05), Vector2(0.045, 0.045)], &"fur", neck, 7, false)
	var head := Vector3(0.0, 0.58, -0.21)
	var head_r := Vector3(0.05, 0.05, 0.06)
	ball(head, head_r, &"fur", neck)
	spike([Vector3(0.0, 0.575, -0.26), Vector3(0.0, 0.56, -0.3), Vector3(0.0, 0.54, -0.315)], 0.022, &"plain", IVORY, 5)
	spike([Vector3(0.0, 0.545, -0.23), Vector3(0.0, 0.5, -0.245), Vector3(0.0, 0.46, -0.235)], 0.026, &"fur", black, 5)
	for x: float in [-1.0, 1.0]:
		var eye: Vector3 = surface(head, head_r, Vector3(0.8 * x, 0.25, -0.55))
		box(eye + Vector3(0.0, 0.012, 0.0), Vector3(0.012, 0.022, 0.034), &"plain", Color(0.85, 0.1, 0.08))
		ball(eye + Vector3(0.0, -0.006, -0.004), Vector3.ONE * 0.008, &"plain", GLASS, 5, 3)
		ball(Vector3(0.12 * x, 0.3, 0.05), Vector3(0.045, 0.1, 0.17), &"fur", brown, 7, 5, Basis(Vector3.RIGHT, 0.35))
		ball(Vector3(0.135 * x, 0.36, -0.06), Vector3.ONE * 0.02, &"fur", white, 5, 3)
		tube([Vector3(0.05 * x, 0.18, 0.0), Vector3(0.055 * x, 0.04, -0.01)], [Vector2(0.026, 0.026), Vector2(0.02, 0.02)], &"fur", Color(0.42, 0.4, 0.38), 6)
		for k: int in 3:
			var toe := Vector3((0.055 + (k - 1) * 0.02) * x, 0.012, -0.01)
			spike([toe, toe + Vector3((k - 1) * 0.02 * x, -0.005, -0.06)], 0.009, &"plain", Color(0.25, 0.22, 0.2), 4)
	# The fan: feathers spread round a point behind the back, leaning back a little.
	var pivot := Vector3(0.0, 0.28, 0.22)
	for i: int in 9:
		var a: float = lerpf(-1.25, 1.25, float(i) / 8.0)
		var turn := Basis(Vector3.RIGHT, 0.35) * Basis(Vector3.BACK, -a)
		var along: Vector3 = turn * Vector3.UP
		box(pivot + along * 0.17, Vector3(0.07, 0.3, 0.012), &"fur", black, turn, Vector2(1.3, 1.0))
		box(pivot + along * 0.31, Vector3(0.09, 0.03, 0.014), &"fur", white, turn)


## Der Edelmarder: a slim brown body along `spine` (neck first), the head looking along `look`, a
## yellow bib, a bushy tail along `tail`. Legs hang down at the shoulders and hips when `legs`.
func marten(spine: Array, tail: Array, look: Vector3, legs: bool = true) -> void:
	var fur := Color(0.36, 0.22, 0.11)
	var dark := Color(0.2, 0.12, 0.07)
	var bib := Color(0.94, 0.76, 0.36)
	var radii: Array = []
	for i: int in spine.size():
		var t: float = float(i) / float(spine.size() - 1)
		var r: float = lerpf(0.03, 0.04, minf(t * 3.0, 1.0)) - (0.006 if i == spine.size() - 1 else 0.0)
		radii.append(Vector2(r, r * 0.92))
	tube(spine, radii, &"fur", fur, 7)
	var forward: Vector3 = look.normalized()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	var up: Vector3 = side.cross(forward)
	var neck: Vector3 = spine[0]
	var head: Vector3 = neck + forward * 0.04 + up * 0.012
	var aim := Basis(side, up, -forward)
	ball(head, Vector3(0.036, 0.032, 0.046), &"fur", fur, 8, 6, aim)
	spike([head + forward * 0.03, head + forward * 0.075 - up * 0.008], 0.022, &"fur", fur, 6)
	ball(head + forward * 0.078 - up * 0.008, Vector3.ONE * 0.009, &"plain", NOSE, 5, 3)
	ball(neck - up * 0.018 + forward * 0.01, Vector3(0.03, 0.024, 0.042), &"fur", bib, 7, 5, aim)
	for s: float in [-1.0, 1.0]:
		ball(head + forward * 0.028 + up * 0.016 + side * s * 0.022, Vector3.ONE * 0.008, &"plain", GLASS, 5, 3)
		ball(head - forward * 0.008 + up * 0.03 + side * s * 0.026, Vector3(0.017, 0.017, 0.008), &"fur", bib.darkened(0.3), 6, 4, aim)
		if legs:
			for at: Vector3 in [spine[1], spine[spine.size() - 2]]:
				var hip: Vector3 = at + side * s * 0.024 - up * 0.015
				tube([hip, hip - up * 0.06 + side * s * 0.008], [Vector2(0.014, 0.014), Vector2(0.011, 0.011)], &"fur", dark, 5)
	var tail_radii: Array = []
	for i: int in tail.size():
		var t: float = float(i) / float(tail.size() - 1)
		var r: float = 0.028 + 0.016 * sin(t * PI * 0.8)
		tail_radii.append(Vector2(r, r))
	tube(tail, tail_radii, &"fur", dark, 7)


## Der Raurakl: the Austrian Wolpertinger, a hare with a roebuck's antlers, little wings and fangs.
func raurakl() -> void:
	var fur := Color(0.56, 0.46, 0.34)
	var white := Color(0.92, 0.9, 0.86)
	var antler := Color(0.8, 0.7, 0.52)
	var wing := Color(0.45, 0.32, 0.2)
	ball(Vector3(0.0, 0.12, 0.03), Vector3(0.09, 0.12, 0.13), &"fur", fur, 9, 7)
	ball(Vector3(0.0, 0.11, -0.055), Vector3(0.065, 0.085, 0.055), &"fur", white)
	var head := Vector3(0.0, 0.25, -0.08)
	var head_r := Vector3(0.055, 0.055, 0.07)
	ball(head, head_r, &"fur", fur)
	ball(Vector3(0.0, 0.232, -0.135), Vector3(0.033, 0.028, 0.03), &"fur", white)
	box(Vector3(0.0, 0.248, -0.164), Vector3(0.016, 0.012, 0.008), &"plain", Color(0.75, 0.42, 0.42))
	ball(Vector3(0.0, 0.08, 0.16), Vector3.ONE * 0.032, &"fur", white, 6, 4)
	for x: float in [-1.0, 1.0]:
		spike([Vector3(0.012 * x, 0.214, -0.152), Vector3(0.013 * x, 0.188, -0.15)], 0.006, &"plain", white, 3)
		ball(surface(head, head_r, Vector3(0.62 * x, 0.32, -0.7)), Vector3.ONE * 0.011, &"glow", Color(1.0, 0.55, 0.1), 5, 3)
		spike([Vector3(0.022 * x, 0.29, -0.06), Vector3(0.042 * x, 0.37, -0.02), Vector3(0.05 * x, 0.43, 0.04)], 0.024, &"fur", fur, 5)
		var root := Vector3(0.03 * x, 0.295, -0.1)
		var fork: Vector3 = root + Vector3(0.022 * x, 0.075, -0.012)
		spike([root, fork, fork + Vector3(0.02 * x, 0.07, 0.01)], 0.012, &"plain", antler, 4)
		spike([fork, fork + Vector3(0.03 * x, 0.03, -0.035)], 0.008, &"plain", antler, 4)
		var wing_turn := Basis(Vector3.RIGHT, 0.45) * Basis(Vector3.BACK, -0.6 * x)
		box(Vector3(0.1 * x, 0.22, 0.07), Vector3(0.015, 0.13, 0.15), &"fur", wing, wing_turn, Vector2(1.0, 0.6))
		box(Vector3(0.1 * x, 0.22, 0.07) + wing_turn * Vector3(0.0, 0.07, 0.0), Vector3(0.016, 0.025, 0.1), &"fur", white, wing_turn)
		ball(Vector3(0.035 * x, 0.02, -0.1), Vector3(0.022, 0.02, 0.04), &"fur", white, 6, 4)
		ball(Vector3(0.06 * x, 0.015, 0.0), Vector3(0.03, 0.015, 0.07), &"fur", fur, 6, 4)


# --- trophy heads (out of a plaque whose front is at z = 0) ---------------------------------------

## A wooden shield to hang a trophy on, `size` wide and high; its back is on the wall (z = +depth).
func plaque(size: Vector2, depth: float = 0.04) -> void:
	box(Vector3(0.0, 0.0, depth * 0.5), Vector3(size.x, size.y, depth), &"wood", WOOD)
	box(Vector3(0.0, 0.0, -0.005), Vector3(size.x * 0.84, size.y * 0.86, 0.012), &"wood", WOOD.lightened(0.12))
	box(Vector3(0.0, -size.y * 0.36, -0.013), Vector3(size.x * 0.4, size.y * 0.07, 0.006), &"metal", BRASS)


## Der Gamskopf: a chamois head, the pale face with its dark stripes and the black hooked horns.
func gams_head() -> void:
	var coat := Color(0.3, 0.21, 0.13)
	var face := Color(0.86, 0.8, 0.66)
	var black := Color(0.06, 0.05, 0.05)
	tube([Vector3(0.0, -0.04, 0.0), Vector3(0.0, 0.01, -0.1), Vector3(0.0, 0.06, -0.17)],
			[Vector2(0.09, 0.1), Vector2(0.075, 0.082), Vector2(0.062, 0.068)], &"fur", coat, 8, false)
	var tilt := Basis(Vector3.RIGHT, 0.45)
	var head := Vector3(0.0, 0.1, -0.22)
	ball(head, Vector3(0.06, 0.065, 0.1), &"fur", face, 8, 6, tilt)
	ball(Vector3(0.0, 0.05, -0.295), Vector3(0.036, 0.034, 0.045), &"fur", face, 7, 5)
	box(Vector3(0.0, 0.056, -0.338), Vector3(0.03, 0.02, 0.012), &"plain", black)
	for x: float in [-1.0, 1.0]:
		box(Vector3(0.047 * x, 0.085, -0.25), Vector3(0.014, 0.03, 0.12), &"fur", black, tilt)
		ball(Vector3(0.053 * x, 0.125, -0.225), Vector3.ONE * 0.013, &"plain", GLASS, 5, 3)
		spike([Vector3(0.042 * x, 0.15, -0.17), Vector3(0.07 * x, 0.19, -0.15), Vector3(0.085 * x, 0.22, -0.13)], 0.02, &"fur", coat, 5)
		spike([Vector3(0.022 * x, 0.15, -0.21), Vector3(0.026 * x, 0.23, -0.215), Vector3(0.029 * x, 0.29, -0.2),
				Vector3(0.028 * x, 0.315, -0.16), Vector3(0.025 * x, 0.295, -0.125)], 0.017, &"plain", black, 5)


## A stag's skull, nose down, with a big set of antlers (a Zwölfender).
func hirsch_skull() -> void:
	var bone := Color(0.9, 0.87, 0.78)
	var antler := Color(0.48, 0.38, 0.26)
	var tip := Color(0.86, 0.8, 0.68)
	var hole := Color(0.12, 0.1, 0.08)
	ball(Vector3(0.0, 0.02, -0.06), Vector3(0.065, 0.07, 0.06), &"plain", bone)
	box(Vector3(0.0, -0.1, -0.07), Vector3(0.075, 0.2, 0.05), &"plain", bone, Basis.IDENTITY, Vector2(0.6, 1.0))
	for x: float in [-1.0, 1.0]:
		box(Vector3(0.038 * x, -0.005, -0.112), Vector3(0.032, 0.03, 0.01), &"plain", hole)
		box(Vector3(0.012 * x, -0.19, -0.096), Vector3(0.012, 0.025, 0.006), &"plain", hole)
		var beam: Array = [Vector3(0.04 * x, 0.06, -0.08), Vector3(0.12 * x, 0.14, -0.1), Vector3(0.21 * x, 0.25, -0.1),
				Vector3(0.27 * x, 0.38, -0.09), Vector3(0.29 * x, 0.5, -0.07), Vector3(0.27 * x, 0.6, -0.06)]
		spike(beam, 0.026, &"plain", antler, 6)
		for tine: Array in [[beam[1], Vector3(0.1 * x, 0.2, -0.21)], [beam[2], Vector3(0.2 * x, 0.34, -0.2)],
				[beam[3], Vector3(0.35 * x, 0.47, -0.14)], [beam[4], Vector3(0.21 * x, 0.6, -0.12)]]:
			var from: Vector3 = tine[0]
			var to: Vector3 = tine[1]
			spike([from, from.lerp(to, 0.6), to], 0.015, &"plain", antler, 5)
			ball(to, Vector3.ONE * 0.006, &"plain", tip, 4, 3)


## Da Krampus: his head (as on the enemy, build_enemies.gd) with the neck in the plaque.
func krampus_head() -> void:
	var fur := Color(0.09, 0.08, 0.08)
	var face := Color(0.6, 0.08, 0.06)
	var horn := Color(0.25, 0.2, 0.16)
	# Far enough out of the plaque that the swept-back horns clear the wall.
	var o := Vector3(0.0, -1.52, -0.3)
	tube([Vector3(0.0, -0.12, 0.0), Vector3(0.0, -0.06, -0.12), Vector3(0.0, 0.02, -0.26)],
			[Vector2(0.12, 0.12), Vector2(0.105, 0.105), Vector2(0.09, 0.09)], &"fur", fur, 8, false)
	ball(o + Vector3(0.0, 1.64, -0.03), Vector3(0.13, 0.14, 0.13), &"skin", face, 10, 7)
	box(o + Vector3(0.0, 1.6, -0.17), Vector3(0.12, 0.08, 0.1), &"skin", face.darkened(0.1), Basis.IDENTITY, Vector2(0.8, 0.8))
	box(o + Vector3(0.0, 1.69, -0.14), Vector3(0.22, 0.04, 0.05), &"skin", face.darkened(0.35))
	box(o + Vector3(0.0, 1.53, -0.13), Vector3(0.13, 0.04, 0.1), &"skin", face.darkened(0.2), Basis(Vector3.RIGHT, 0.25))
	box(o + Vector3(0.0, 1.555, -0.17), Vector3(0.1, 0.03, 0.03), &"plain", Color(0.15, 0.02, 0.02))
	box(o + Vector3(0.015, 1.47, -0.2), Vector3(0.055, 0.17, 0.015), &"plain", Color(0.85, 0.2, 0.3), Basis(Vector3.RIGHT, 0.35))
	for x: float in [-1.0, 1.0]:
		spike([o + Vector3(0.04 * x, 1.575, -0.2), o + Vector3(0.043 * x, 1.535, -0.2)], 0.012, &"plain", IVORY, 3)
		box(o + Vector3(0.055 * x, 1.665, -0.15), Vector3(0.05, 0.03, 0.02), &"plain", Color(0.03, 0.01, 0.01))
		box(o + Vector3(0.055 * x, 1.665, -0.16), Vector3(0.035, 0.02, 0.01), &"glow", Color(1.0, 0.85, 0.2))
		spike([o + Vector3(0.12 * x, 1.66, 0.0), o + Vector3(0.21 * x, 1.7, 0.02), o + Vector3(0.26 * x, 1.74, 0.05)], 0.035, &"skin", face.darkened(0.2), 4)
		krampus_horn(o + Vector3(0.07 * x, 1.75, -0.04), x, horn)
		spike([o + Vector3(0.05 * x, 1.52, -0.12), o + Vector3(0.04 * x, 1.42, -0.12), o + Vector3(0.0, 1.32, -0.1)], 0.045, &"fur", Color(0.22, 0.2, 0.19), 5)
	_tufts(o + Vector3(0.0, 1.76, 0.04), Vector2(0.11, 0.11), 0.16, 7, fur)


## One of the Krampus's long horns from `root`, swept back and up; x = -1 left, 1 right.
func krampus_horn(root: Vector3, x: float, color: Color, base: float = 0.05) -> void:
	spike([root, root + Vector3(0.08 * x, 0.11, 0.03), root + Vector3(0.15 * x, 0.23, 0.1), root + Vector3(0.17 * x, 0.35, 0.2),
			root + Vector3(0.13 * x, 0.45, 0.32)], base, &"plain", color, 7)


## Die Perchtnlarvn: the Perchte's carved wooden mask (as on the enemy) with horns and mane.
func perchte_mask() -> void:
	var fur := Color(0.36, 0.26, 0.17)
	var mask := Color(0.55, 0.32, 0.16)
	var bone := Color(0.9, 0.86, 0.74)
	var o := Vector3(0.0, -1.62, -0.16)
	# The mane behind the mask fills the gap to the plaque.
	ball(o + Vector3(0.0, 1.66, 0.07), Vector3(0.15, 0.17, 0.1), &"fur", fur, 8, 6)
	box(o + Vector3(0.0, 1.64, -0.04), Vector3(0.24, 0.3, 0.24), &"wood", mask, Basis.IDENTITY, Vector2(0.85, 0.9))
	box(o + Vector3(0.0, 1.56, -0.2), Vector3(0.17, 0.12, 0.14), &"wood", mask.darkened(0.08), Basis.IDENTITY, Vector2(0.85, 0.8))
	box(o + Vector3(0.0, 1.73, -0.165), Vector3(0.23, 0.05, 0.05), &"wood", mask.darkened(0.25))
	box(o + Vector3(0.0, 1.5, -0.24), Vector3(0.13, 0.03, 0.05), &"plain", Color(0.2, 0.03, 0.03))
	for k: int in 6:
		var x: float = -0.055 + k * 0.022
		spike([o + Vector3(x, 1.515, -0.268), o + Vector3(x, 1.485, -0.27)], 0.009, &"plain", bone, 3)
	box(o + Vector3(0.02, 1.46, -0.25), Vector3(0.05, 0.08, 0.015), &"plain", Color(0.8, 0.15, 0.2), Basis(Vector3.FORWARD, 0.2))
	for x: float in [-1.0, 1.0]:
		box(o + Vector3(0.06 * x, 1.66, -0.162), Vector3(0.06, 0.04, 0.02), &"plain", Color(0.04, 0.02, 0.02))
		box(o + Vector3(0.06 * x, 1.66, -0.172), Vector3(0.035, 0.022, 0.01), &"glow", Color(1.0, 0.3, 0.12))
		spike([o + Vector3(0.09 * x, 1.77, -0.02), o + Vector3(0.15 * x, 1.88, 0.0), o + Vector3(0.16 * x, 1.98, 0.06), o + Vector3(0.12 * x, 2.04, 0.12)], 0.04, &"plain", bone, 6)
		spike([o + Vector3(0.12 * x, 1.7, 0.05), o + Vector3(0.2 * x, 1.6, 0.08), o + Vector3(0.22 * x, 1.42, 0.08)], 0.06, &"fur", fur.lightened(0.1), 5)
	_tufts(o + Vector3(0.0, 1.78, 0.05), Vector2(0.1, 0.1), 0.14, 6, fur.lightened(0.08))


## Shaggy fur hanging down in a ring round `centre`.
func _tufts(centre: Vector3, radius: Vector2, length: float, count: int, color: Color) -> void:
	for i: int in count:
		var a: float = TAU * float(i) / float(count) + 0.3
		var at: Vector3 = centre + Vector3(cos(a) * radius.x, 0.0, sin(a) * radius.y)
		var out := Vector3(cos(a), 0.0, sin(a)) * 0.04
		spike([at, at + out + Vector3(0, -length * 0.6, 0), at + out * 1.5 + Vector3(0, -length, 0)], 0.055, &"fur", color.lightened(0.06 * float(i % 3)), 5)
