extends Node
## Pictures of the menus as a player sees them (1.2 extras): the title screen, the Steckbriefe and
## the Wandernadln, the settings. Windowed:
##     godot --audio-driver Dummy res://tests/ui_view.tscn -- <out dir>

var _out: String


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://ui_view"
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var title := main.get_node("UI/StartScreen") as StartScreen
	while not title.is_revealed():
		await get_tree().process_frame
	for i: int in 30:
		await get_tree().process_frame
	await _save("title")
	var panel: SteckbriefPanel = title._steckbriefe
	panel.open(0)
	await _save("steckbriefe")
	# Everyone met (not saved), to see the posters filled in; the Bsundan scrolled to.
	var met: Array[String] = Settings.met.duplicate()
	Settings.met.assign(SteckbriefPanel.ENEMIES)
	panel.open(0)
	(panel._pages[0] as ScrollContainer).scroll_vertical = 420
	await _save("steckbriefe_met")
	Settings.met = met
	panel.show_page(1)
	await _save("wandernadln")
	panel.close()
	(main.get_node("UI/SettingsMenu") as SettingsMenu).open()
	await _save("settings")
	get_tree().quit()


func _save(name: String) -> void:
	for i: int in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(_out.path_join(name + ".jpg"), 0.88)
	print("saved ", name)
