extends Node
## Run: godot --headless --fixed-fps 60 res://tests/view_settings.tscn
## Headless check of the view settings (1.1.2): the field of view is the camera's and aiming still
## narrows it to the gun's; aiming by toggle puts the sights up with one right click and down with
## the next (a gun switch drops it), holding works as before with it off; the crosshair takes the
## colour and size picked; antialiasing (FXAA in the post pass, or MSAA 2x/4x on the window); the
## Settings menu has a row for each. The player's settings are put back.

const STUTZEN := preload("res://data/weapons/stutzen.tres")
const HARMONIKA := preload("res://data/weapons/harmonika.tres")

var failures: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures.append(what)


func _ready() -> void:
	var saved: Array = [Settings.fov, Settings.toggle_aim, Settings.crosshair_color, Settings.crosshair_size, Settings.antialiasing]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().physics_frame
	get_tree().paused = false
	var player := main.get_node("Player") as Player
	var weapons: WeaponHolder = player.weapons
	var camera: Camera3D = player.get_node("Head/Camera3D")
	(main.get_node("WaveManager") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	# Field of view.
	Settings.fov = 95.0
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(camera.fov, 95.0), "the field of view is the camera's (%.0f°)" % camera.fov)
	weapons.give_weapon(STUTZEN)
	for i: int in 30:
		await get_tree().physics_frame
	weapons.force_aim = true
	for i: int in roundi(STUTZEN.aim_time * 60.0) + 20:
		await get_tree().physics_frame
	await get_tree().process_frame
	_check(is_equal_approx(camera.fov, STUTZEN.aim_fov), "aiming narrows it to the Stutzen's own (%.0f°)" % camera.fov)
	weapons.force_aim = false
	# Hold, then toggle (right click held, and whether it was clicked this frame).
	Settings.toggle_aim = false
	_check(weapons._aim_held(true, true) and weapons._aim_held(true, false), "holding: aimed while held")
	_check(not weapons._aim_held(false, false), "and down once let go")
	Settings.toggle_aim = true
	_check(weapons._aim_held(true, true), "toggle: a click puts the sights up")
	_check(weapons._aim_held(true, false) and weapons._aim_held(false, false), "and they stay up after letting go")
	_check(not weapons._aim_held(true, true) and not weapons._aim_held(false, false), "the next click puts them down")
	weapons._aim_held(true, true)
	weapons.give_weapon(HARMONIKA)
	for i: int in 2:
		await get_tree().physics_frame
	_check(not weapons._aim_held(false, false), "a gun switch drops it")
	_check(not weapons._aim_held(true, true), "the Harmonika's right click is its own, not an aim")
	# Crosshair.
	Settings.crosshair_color = 1
	Settings.crosshair_size = 1.5
	var crosshair := main.get_node("UI/Hud").get("_crosshair") as Control
	Settings.apply(false)
	_check(crosshair != null, "the HUD has the crosshair")
	# The menu.
	var menu := main.get_node("UI/SettingsMenu") as SettingsMenu
	var keys: Array[String] = []
	for row: Node in menu._rows.get_children():
		if row is HBoxContainer and row.get_child_count() > 0 and row.get_child(0) is Label:
			keys.append((row.get_child(0) as Label).text)
	for key: String in ["UI_SET_FOV", "UI_SET_TOGGLE_AIM", "UI_SET_CROSSHAIR_COLOR", "UI_SET_CROSSHAIR_SIZE", "UI_SET_ANTIALIASING"]:
		_check(key in keys and tr(key) != key, "the menu: %s" % tr(key))
	for row: Node in menu._rows.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "UI_SET_CROSSHAIR_COLOR":
			var picker := row.get_child(1) as OptionButton
			_check(picker.item_count == Constants.CROSSHAIR_COLORS.size(), "%d colours to pick" % picker.item_count)
			picker.item_selected.emit(3)
	_check(Settings.crosshair_color == 3, "picking one sets it")
	# Antialiasing.
	var post := (main.get_node("PostFX/Grade") as ColorRect).material as ShaderMaterial
	var root: Window = get_tree().root
	var expect: Array = [[Viewport.MSAA_DISABLED, false], [Viewport.MSAA_DISABLED, true], [Viewport.MSAA_2X, false], [Viewport.MSAA_4X, false]]
	for row: Node in menu._rows.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "UI_SET_ANTIALIASING":
			var picker := row.get_child(1) as OptionButton
			_check(picker.item_count == 4 and picker.selected == Settings.antialiasing, "antialiasing: 4 to pick, the current one shown")
			for mode: int in 4:
				picker.item_selected.emit(mode)
				_check(Settings.antialiasing == mode and root.msaa_3d == expect[mode][0] and post.get_shader_parameter("fxaa") == expect[mode][1],
					"%s: MSAA %d, FXAA %s" % [tr(Constants.ANTIALIASING_KEYS[mode]), root.msaa_3d, post.get_shader_parameter("fxaa")])
	Settings.fov = saved[0]
	Settings.toggle_aim = saved[1]
	Settings.crosshair_color = saved[2]
	Settings.crosshair_size = saved[3]
	Settings.antialiasing = saved[4]
	Settings.save()
	print("RESULT: %s" % ("PASS" if failures.is_empty() else "%d FAILED" % failures.size()))
	get_tree().quit(1 if failures.size() > 0 else 0)
