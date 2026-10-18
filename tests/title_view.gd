extends Node
## Visual check of the title screen and the shader warmup behind it (#77, #78). Needs a window:
##   godot res://tests/title_view.tscn -- <out_dir>
## Saves the title early on, while preparing, and once ready; prints how long the warmup took.

var _out_dir: String
var _progress: Array = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0] if args.size() > 0 else "user://title_view"
	DirAccess.make_dir_recursive_absolute(_out_dir)
	get_window().size = Vector2i(1280, 720)
	var started: int = Time.get_ticks_msec()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var warmup := main.get_node("ShaderWarmup") as ShaderWarmup
	var done: Array = [false]
	warmup.finished.connect(func() -> void: done[0] = true)
	warmup.progress.connect(func(share: float) -> void: _progress.append(share))
	for i: int in 3:
		await RenderingServer.frame_post_draw
	_shot("title_early.png")
	var frames: int = 0
	while not done[0]:
		await get_tree().process_frame
		frames += 1
		if frames == 15:
			_shot("title_preparing.png")
	print("warmup: %d frames, %d ms, last progress %.2f" % [frames, Time.get_ticks_msec() - started, _progress[-1] if not _progress.is_empty() else -1.0])
	for i: int in 30:
		await get_tree().process_frame
	_shot("title_ready.png")
	# The world behind the title, as the game will show it.
	(main.get_node("UI/StartScreen") as Control).hide()
	for i: int in 3:
		await RenderingServer.frame_post_draw
	_shot("world_after.png")
	get_tree().quit()


func _shot(file: String) -> void:
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(file))
