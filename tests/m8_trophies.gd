extends Node
## Run: godot --headless --fixed-fps 60 res://tests/m8_trophies.tscn
## Headless check of the stuffed animals (M8): every hat has its part on the hiker; an earned hat not
## earned yet stays in the lobby but is not worn; the trophy wall hangs every Krampus and the 1st and
## every 5th Perchte, and stops when it is full; the Perchtn-Haubn comes with the 5th Perchte, the
## Krampus-Hörndl with wave 10, the Raurakl-Kappl with our own hit on the Raurakl (and it spins);
## the Stube has its wall, its Raurakl and its five animals. The saved settings are put back after.

const HIKER := preload("res://scenes/net/hiker.tscn")
const WALL := preload("res://scenes/props/trophy_wall.tscn")
const RAURAKL := preload("res://scenes/props/raurakl.tscn")
const STUBE := preload("res://scenes/zones/stube.tscn")

var failures: Array[String] = []


func _ready() -> void:
	var saved: Array = [Settings.unlocks.duplicate(), Settings.perchten, Settings.profile.duplicate()]
	Settings.unlocks.clear()
	Settings.perchten = 0
	_hats()
	await _wall_and_unlocks()
	await _raurakl()
	_stube()
	Settings.unlocks.assign(saved[0])
	Settings.perchten = saved[1]
	Settings.profile = saved[2]
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _hats() -> void:
	var hiker := HIKER.instantiate() as Hiker
	add_child(hiker)
	var missing: Array[int] = []
	for hat: int in range(1, HikerStyle.HATS.size()):
		if not hiker.rig.has_node("Skeleton/Hat%d" % hat):
			missing.append(hat)
	_check(HikerStyle.HATS.size() == 10 and missing.is_empty() and not hiker.rig.has_node("Skeleton/Hat10"), "10 hats, each with its part on the hiker (missing %s)" % [missing])
	hiker.apply({"hat": 9}, 1)
	_check((hiker.rig.get_node("Skeleton/Hat9") as Node3D).visible, "the Krampus-Hörndl shows when worn")
	hiker.queue_free()
	for peer: int in range(1, 5):
		_check(HatUnlocks.has_hat(HikerStyle.default_profile(peer)["hat"]), "peer %d's default hat needs no earning" % peer)
	Settings.profile = HikerStyle.sanitize({"name": "Test", "hat": 9})
	_check(not HatUnlocks.has_hat(9) and HatUnlocks.hint(9) != "", "the Krampus-Hörndl is locked, with a hint")
	_check(Settings.edit_profile(1)["hat"] == 9, "the lobby keeps a locked hat for the preview")
	_check(Settings.profile_for(1)["hat"] == 0, "a locked hat is not worn (or sent to the others)")
	Settings.profile = HikerStyle.sanitize({"name": "Test", "hat": 4})
	_check(Settings.profile_for(1)["hat"] == 4, "a free stuffed hat is worn")


func _wall_and_unlocks() -> void:
	var wall := WALL.instantiate() as TrophyWall
	add_child(wall)
	var unlocks := HatUnlocks.new()
	add_child(unlocks)
	var banners: Array[String] = []
	Events.event_announced.connect(func(text: String) -> void: banners.append(text))
	_kill(&"perchte")
	_check(wall.hung() == 1, "the first Perchte goes on the wall")
	for i: int in 3:
		_kill(&"perchte")
	_check(wall.hung() == 1 and not HatUnlocks.has_hat(8), "the 2nd to 4th do not, and 4 Perchten earn nothing yet")
	_kill(&"perchte")
	_check(wall.hung() == 2, "the 5th Perchte goes on the wall")
	_check(HatUnlocks.has_hat(8) and Settings.perchten == 5, "5 Perchten earn the Perchtn-Haubn")
	_kill(&"knappe")
	_check(wall.hung() == 2, "a Knappe does not")
	for i: int in 5:
		_kill(&"krampus")
	_check(wall.hung() == 6, "every Krampus goes up until the wall is full (6)")
	_check(banners.has(tr("TROPHY_KRAMPUS")) and banners.has(tr("TROPHY_PERCHTE")), "each trophy has its banner")
	await get_tree().create_timer(Constants.TROPHY_POP_TIME + 0.1).timeout
	var last := wall.get_node("Plaque5").get_child(1) as MeshInstance3D
	_check(last != null and last.mesh == TrophyWall.KRAMPUS and last.scale.is_equal_approx(Vector3.ONE), "the last plaque has a Krampus, popped to full size")
	Events.wave_cleared.emit(9)
	_check(not HatUnlocks.has_hat(9), "wave 9 does not earn the Krampus-Hörndl")
	Events.wave_cleared.emit(10)
	_check(HatUnlocks.has_hat(9), "surviving wave 10 earns it")
	var before: int = banners.size()
	Events.wave_cleared.emit(11)
	_check(banners.size() == before, "earned once, announced once")
	wall.queue_free()
	unlocks.queue_free()


func _kill(id: StringName) -> void:
	var enemy := Enemy.new()
	enemy.data = load("res://data/enemies/%s.tres" % id)
	Events.enemy_killed.emit(enemy, false, false, null)
	enemy.free()


func _raurakl() -> void:
	var raurakl := RAURAKL.instantiate() as Raurakl
	add_child(raurakl)
	var model := raurakl.get_node("Model") as Node3D
	_check(raurakl.receive_hit(10, false, false, null) == Hurtbox.Result.HIT and not HatUnlocks.has_hat(7),
			"a hit that is not ours spins it but earns nothing")
	await get_tree().create_timer(Constants.RAURAKL_SPIN_TIME + 0.1).timeout
	_check(is_equal_approx(model.rotation.y, TAU * 2.0) and (raurakl.get_node("Bubble") as Label3D).visible, "it spun twice and grumbles")
	var player := Player.new()
	raurakl.receive_hit(10, false, false, player)
	player.free()
	_check(HatUnlocks.has_hat(7), "our own hit earns the Raurakl-Kappl")
	var hurtbox := raurakl.get_node("Hurtbox") as Hurtbox
	_check(hurtbox.collision_layer == Constants.LAYER_HITBOX and hurtbox.receiver == raurakl, "its hurtbox is on the hitbox layer")
	raurakl.queue_free()


func _stube() -> void:
	var stube := STUBE.instantiate()
	var stuffed := stube.get_node("Stuffed")
	_check(stuffed.get_node("TrophyWall") is TrophyWall and stuffed.get_node("Raurakl") is Raurakl, "the Stube has the trophy wall and the Raurakl")
	var animals: int = 0
	for name: String in ["Gams", "Hirsch", "Auerhahn", "Mankei", "Marder"]:
		var mesh := stuffed.get_node_or_null(name) as MeshInstance3D
		if mesh and mesh.mesh:
			animals += 1
	_check(animals == 5, "the Stube has its five stuffed animals (%d)" % animals)
	stube.free()
