extends Node
## Visual check of the co-op lobby (M7). Needs a real window (not --headless):
##   godot res://tests/lobby_view.tscn -- <out_dir>
## Saves the lobby before a room exists and with a full pretend room of four (no relay needed).

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://lobby_view"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await _shot(out_dir.path_join("title.png"))
	var lobby := main.get_node("UI/Lobby") as Lobby
	Settings.profile = {"name": "Sepp", "head": 1, "hat": 1, "jacket": 0, "trousers": 0}
	lobby.open()
	await _shot(out_dir.path_join("lobby_offline.png"))
	# A pretend room: offline, our id is 1, so we are its host.
	Net.code = "4711"
	Net.roster = {1: Settings.profile, 2: {"name": "Resi", "head": 3, "hat": 2, "jacket": 3, "trousers": 1},
			3: {"name": "", "head": 4, "hat": 4, "jacket": 5, "trousers": 3},
			4: {"name": "Hias", "head": 2, "hat": 0, "jacket": 2, "trousers": 4}}
	Net.state = Net.State.LOBBY
	Net.roster_changed.emit()
	await _shot(out_dir.path_join("lobby_room.png"))
	Net.state = Net.State.OFFLINE
	get_tree().quit()


func _shot(path: String) -> void:
	for i: int in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
