extends SceneTree
## Builds the Stube's stuffed animals and trophies (M8) into assets/models/trophies/trophy_<name>.res,
## plain meshes from the animals in stuffed.gd:
##
##     godot --headless --script res://tools/models/build_trophies.gd
##
## Wall pieces have their origin on the front of their plaque (the wall is 4 cm behind, +Z) and face
## -Z; the Mankei and the Marder stand on y = 0.

const Builder := preload("res://tools/models/character_builder.gd")
const Stuffed := preload("res://tools/models/stuffed.gd")
const OUT: String = "res://assets/models/trophies/trophy"
const BARK := Color(0.3, 0.21, 0.13)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var b := Builder.new(1.0)
	var at := func(origin: Vector3, size: float = 1.0, turn: float = 0.0) -> Stuffed:
		return Stuffed.new(b, Stuffed.place(origin, size, Basis(Vector3.UP, turn)), &"root")
	var here: Stuffed = at.call(Vector3.ZERO)

	b.part(&"gams")
	here.plaque(Vector2(0.36, 0.46))
	at.call(Vector3(0.0, 0.0, 0.0), 1.15).gams_head()

	b.part(&"hirsch")
	at.call(Vector3(0.0, -0.08, 0.0)).plaque(Vector2(0.3, 0.38))
	at.call(Vector3(0.0, 0.0, 0.0), 1.1).hirsch_skull()

	# On a shelf out of a plaque, turned a little so the fan shows.
	b.part(&"auerhahn")
	here.plaque(Vector2(0.44, 0.52))
	here.box(Vector3(0.0, -0.215, -0.25), Vector3(0.46, 0.03, 0.5), &"wood", Stuffed.WOOD.lightened(0.08))
	at.call(Vector3(0.0, -0.2, -0.33), 1.0, -0.55).auerhahn()

	# Apart from its shelf, so it can spin when it is shot (scenes/props/raurakl.tscn): the shelf's top
	# is 0.1375 m below and 0.13 m in front of the plaque's middle.
	b.part(&"raurakl_shelf")
	here.plaque(Vector2(0.3, 0.36))
	here.box(Vector3(0.0, -0.15, -0.12), Vector3(0.28, 0.025, 0.24), &"wood", Stuffed.WOOD.lightened(0.08))
	b.part(&"raurakl")
	at.call(Vector3.ZERO, 1.25).raurakl()

	# Sitting up on a slice of log on the bar.
	b.part(&"mankei")
	here.tube([Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.045, 0.0)], [Vector2(0.15, 0.14), Vector2(0.15, 0.14)], &"wood", BARK)
	here.ball(Vector3(0.0, 0.045, 0.0), Vector3(0.13, 0.004, 0.12), &"wood", Color(0.72, 0.58, 0.4), 10, 2)
	at.call(Vector3(0.0, 0.045, 0.0), 1.0, 0.25).marmot_sitting()

	# Stalking along a branch on the mantel.
	b.part(&"marder")
	here.tube([Vector3(0.0, 0.03, -0.26), Vector3(0.0, 0.034, 0.0), Vector3(0.0, 0.03, 0.3)],
			[Vector2(0.03, 0.03), Vector2(0.032, 0.032), Vector2(0.026, 0.026)], &"wood", BARK, 7)
	here.spike([Vector3(0.0, 0.04, 0.12), Vector3(0.05, 0.1, 0.16), Vector3(0.07, 0.15, 0.17)], 0.014, &"wood", BARK, 5)
	here.marten([Vector3(0.0, 0.165, -0.15), Vector3(0.0, 0.142, -0.07), Vector3(0.0, 0.135, 0.01), Vector3(0.0, 0.142, 0.09),
			Vector3(0.0, 0.13, 0.17)], [Vector3(0.0, 0.13, 0.17), Vector3(0.0, 0.115, 0.26), Vector3(0.0, 0.07, 0.33),
			Vector3(0.0, 0.01, 0.36)], Vector3(0.0, 0.3, -1.0))

	# The trophy wall's plaques, and what the bosses leave on them.
	b.part(&"plaque")
	here.plaque(Vector2(0.52, 0.62))
	b.part(&"krampus")
	at.call(Vector3(0.0, 0.0, 0.0), 1.15).krampus_head()
	b.part(&"perchte")
	at.call(Vector3(0.0, 0.0, 0.0), 1.1).perchte_mask()

	b.save_static(OUT)
	print("trophies built")
	quit()
