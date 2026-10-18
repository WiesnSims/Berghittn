class_name Lobby
extends Control
## The co-op lobby (M7): dress your hiker (name, head, hat, jacket and trousers), create a room or join
## one by its 4-digit code or invite link, see everyone's hikers on a little stage, and (host) start.
## Built in code: most of it is rows of the same few controls.

signal closed

const HIKER := preload("res://scenes/net/hiker.tscn")
# Sized to fit a laptop browser (about 620 px of canvas height).
const FONT_SIZE: int = 18
const TITLE_SIZE: int = 34
const BUTTON_HEIGHT: float = 36.0
const LABEL_WIDTH: float = 96.0
const PANEL_WIDTH: float = 400.0
const SWATCH_SIZE: Vector2 = Vector2(30, 26)
const STAGE_SIZE: Vector2i = Vector2i(600, 340)
## The stage: hikers side by side, ours turning slowly so every side of the outfit shows.
const STAGE_SPACING: float = 0.9
const TURN_SPEED: float = 0.6
const TEXT_COLOR := Color(0.96, 0.92, 0.84)
const HINT_COLOR := Color(0.7, 0.76, 0.86)
const ERROR_COLOR := Color(1.0, 0.55, 0.4)
const REASON_KEYS: Dictionary = {
	"host_left": "UI_NET_HOST_LEFT", "kicked": "UI_NET_KICKED", "full": "UI_NET_FULL",
	"started": "UI_NET_STARTED", "version": "UI_NET_VERSION", "no_room": "UI_NET_NO_ROOM",
	"lost": "UI_NET_LOST",
}

var _profile: Dictionary
var _name_edit: LineEdit
var _head_label: Label
var _hat_label: Label
var _jacket_swatches: Array[Button] = []
var _trouser_swatches: Array[Button] = []
var _offline_box: VBoxContainer
var _room_box: VBoxContainer
var _code_edit: LineEdit
var _room_label: Label
var _link_edit: LineEdit
var _count_label: Label
var _start_button: Button
var _wait_label: Label
var _leave_button: Button
var _status: Label
var _players: VBoxContainer
var _stage_root: Node3D
var _stage_hikers: Dictionary = {}


## Text for a relay reason, for the lobby and the title screen.
static func reason_text(reason: String) -> String:
	return TranslationServer.translate(REASON_KEYS.get(reason, "UI_NET_LOST"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_profile = HikerStyle.sanitize(Settings.profile)
	_build()
	Net.state_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh)
	Net.ended.connect(_on_ended)
	hide()


func open() -> void:
	_status.text = ""
	_load_profile()
	show()
	_refresh()


## Straight into a room from an invite link.
func join(code: String) -> void:
	open()
	_code_edit.text = code
	_join()


func _process(delta: float) -> void:
	if not visible:
		return
	var mine: Hiker = _stage_hikers.get(_my_key())
	if mine:
		mine.rotation.y += TURN_SPEED * delta
	for hiker: Hiker in _stage_hikers.values():
		hiker.rig.update(delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and Net.state == Net.State.OFFLINE:
		get_viewport().set_input_as_handled()
		_close()


# --- building -------------------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	center.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	left.add_child(_label("UI_LOBBY_TITLE", TITLE_SIZE, TEXT_COLOR))
	left.add_child(_build_stage())
	_players = VBoxContainer.new()
	left.add_child(_players)
	_status = _label("", FONT_SIZE, ERROR_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = STAGE_SIZE.x
	left.add_child(_status)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = PANEL_WIDTH
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	_name_edit = LineEdit.new()
	_name_edit.max_length = HikerStyle.NAME_MAX_LENGTH
	_name_edit.placeholder_text = "UI_LOBBY_NAME_HINT"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_edit.text_changed.connect(func(text: String) -> void: _set_field("name", text))
	_row(right, "UI_LOBBY_NAME").add_child(_name_edit)
	_head_label = _add_stepper(right, "UI_LOBBY_HEAD", "head", HikerStyle.HEADS.size())
	_hat_label = _add_stepper(right, "UI_LOBBY_HAT", "hat", HikerStyle.HATS.size())
	_row(right, "UI_LOBBY_JACKET").add_child(_swatches(HikerStyle.JACKETS, "jacket", _jacket_swatches))
	_row(right, "UI_LOBBY_TROUSERS").add_child(_swatches(HikerStyle.TROUSERS, "trousers", _trouser_swatches))
	right.add_child(HSeparator.new())

	_offline_box = VBoxContainer.new()
	_offline_box.add_theme_constant_override("separation", 6)
	right.add_child(_offline_box)
	_offline_box.add_child(_button("UI_LOBBY_CREATE", Net.create_room))
	var join_row := HBoxContainer.new()
	_offline_box.add_child(join_row)
	_code_edit = LineEdit.new()
	_code_edit.max_length = Constants.NET_CODE_LENGTH
	_code_edit.placeholder_text = "UI_LOBBY_CODE_HINT"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.add_theme_font_size_override("font_size", FONT_SIZE)
	_code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code_edit.text_changed.connect(_on_code_typed)
	_code_edit.text_submitted.connect(func(_t: String) -> void: _join())
	join_row.add_child(_code_edit)
	join_row.add_child(_button("UI_LOBBY_JOIN", _join))

	_room_box = VBoxContainer.new()
	_room_box.add_theme_constant_override("separation", 6)
	right.add_child(_room_box)
	var room_row := HBoxContainer.new()
	_room_box.add_child(room_row)
	_room_label = _label("", 28, TEXT_COLOR)
	_room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_row.add_child(_room_label)
	_count_label = _label("", FONT_SIZE, HINT_COLOR)
	room_row.add_child(_count_label)
	_link_edit = LineEdit.new()
	_link_edit.editable = false
	_link_edit.add_theme_font_size_override("font_size", 15)
	_room_box.add_child(_link_edit)
	_room_box.add_child(_button("UI_LOBBY_COPY_LINK", _copy_link))
	_start_button = _button("UI_LOBBY_START", Net.start_match)
	_room_box.add_child(_start_button)
	_wait_label = _label("", FONT_SIZE, HINT_COLOR)
	_wait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_box.add_child(_wait_label)

	right.add_child(HSeparator.new())
	var bottom := HBoxContainer.new()
	right.add_child(bottom)
	_leave_button = _button("UI_LOBBY_LEAVE", Net.leave)
	_leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_leave_button)
	var back := _button("UI_BACK", _close)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(back)


func _build_stage() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(STAGE_SIZE)
	container.stretch = true
	var viewport := SubViewport.new()
	viewport.size = STAGE_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)
	_stage_root = Node3D.new()
	viewport.add_child(_stage_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.15, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.47, 0.55)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.13, 0.15, 0.19)
	env.environment.fog_density = 0.06
	_stage_root.add_child(env)
	# Warm light from the hut's side, like in the Stube.
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-35, 25, 0)
	lamp.light_color = Color(1.0, 0.88, 0.72)
	_stage_root.add_child(lamp)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 8)
	var snow := StandardMaterial3D.new()
	snow.albedo_color = Color(0.75, 0.78, 0.84)
	plane.material = snow
	floor_mesh.mesh = plane
	_stage_root.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.fov = 40.0
	# Not in the tree yet, so no look_at().
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.45, 4.0)).looking_at(Vector3(0.0, 1.0, 0.0))
	_stage_root.add_child(camera)
	return container


func _label(key: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = key
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(action)
	return button


## A row with a title on the left; the caller adds the control.
func _row(parent: Control, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := _label(key, FONT_SIZE, HINT_COLOR)
	title.custom_minimum_size.x = LABEL_WIDTH
	row.add_child(title)
	return row


## "Head:  <  Bartl  >" — steps through `count` choices of profile[field].
func _add_stepper(parent: Control, key: String, field: String, count: int) -> Label:
	var row := _row(parent, key)
	row.add_child(_button("<", func() -> void: _set_field(field, posmod(int(_profile[field]) - 1, count))))
	var value := _label("", FONT_SIZE, TEXT_COLOR)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	row.add_child(_button(">", func() -> void: _set_field(field, posmod(int(_profile[field]) + 1, count))))
	return value


func _swatches(colors: Array[Color], field: String, into: Array[Button]) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 8
	for i: int in colors.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.toggle_mode = true
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = colors[i]
			box.set_corner_radius_all(4)
			# The chosen colour gets a light frame.
			var framed: bool = state in ["pressed", "hover_pressed"]
			box.set_border_width_all(3 if framed else 1)
			box.border_color = Color(1, 1, 1) if framed else Color(0, 0, 0, 0.6)
			if state == "focus":
				box.draw_center = false
			swatch.add_theme_stylebox_override(state, box)
		swatch.pressed.connect(func() -> void: _set_field(field, i))
		grid.add_child(swatch)
		into.append(swatch)
	return grid


# --- behaviour ------------------------------------------------------------------------------------

func _load_profile() -> void:
	_profile = HikerStyle.sanitize(Settings.profile)
	_name_edit.text = _profile["name"]


func _set_field(field: String, value: Variant) -> void:
	_profile[field] = value
	_profile = HikerStyle.sanitize(_profile)
	Settings.profile = _profile.duplicate()
	Settings.save()
	Net.update_profile(_profile)
	_refresh()


func _on_code_typed(text: String) -> void:
	var digits: String = ""
	for c: String in text:
		if c.is_valid_int():
			digits += c
	if digits != text:
		_code_edit.text = digits
		_code_edit.caret_column = digits.length()


func _join() -> void:
	var code: String = _code_edit.text.strip_edges()
	if code.length() != Constants.NET_CODE_LENGTH:
		_status.text = tr("UI_NET_NO_ROOM")
		return
	_status.text = ""
	Net.join_room(code)


func _copy_link() -> void:
	DisplayServer.clipboard_set(Net.invite_url())
	_wait_label.text = tr("UI_LOBBY_COPIED")


func _close() -> void:
	Net.leave()
	hide()
	closed.emit()


func _on_ended(reason: String) -> void:
	_status.text = "" if reason == "left" else reason_text(reason)
	_refresh()


func _my_key() -> int:
	return Net.my_id() if Net.state != Net.State.OFFLINE else 0


func _refresh() -> void:
	if not visible:
		return
	var online: bool = Net.state != Net.State.OFFLINE
	_offline_box.visible = not online
	_room_box.visible = Net.in_lobby()
	_leave_button.visible = online
	if Net.state == Net.State.CONNECTING:
		_status.text = tr("UI_LOBBY_CONNECTING")
	elif Net.in_lobby() and _status.text == tr("UI_LOBBY_CONNECTING"):
		_status.text = ""
	_head_label.text = tr(HikerStyle.HEADS[_profile["head"]])
	_hat_label.text = tr(HikerStyle.HATS[_profile["hat"]])
	for i: int in _jacket_swatches.size():
		_jacket_swatches[i].set_pressed_no_signal(i == _profile["jacket"])
	for i: int in _trouser_swatches.size():
		_trouser_swatches[i].set_pressed_no_signal(i == _profile["trousers"])
	if Net.in_lobby():
		_room_label.text = tr("UI_LOBBY_ROOM") % Net.code
		_link_edit.text = Net.invite_url()
		_count_label.text = tr("UI_LOBBY_PLAYERS") % [Net.roster.size(), Constants.NET_MAX_PLAYERS]
		_start_button.visible = Net.is_host()
		_start_button.disabled = not Net.can_start()
		if Net.is_host():
			_wait_label.text = "" if Net.can_start() else tr("UI_LOBBY_NEED_PLAYER")
		else:
			_wait_label.text = tr("UI_LOBBY_WAITING")
	_refresh_stage()
	_refresh_players()


## Everyone in the room on the stage (offline: just us), in peer order.
func _refresh_stage() -> void:
	var cast: Dictionary = {}
	if Net.in_lobby():
		cast = Net.roster.duplicate()
		cast[Net.my_id()] = _profile
	else:
		cast[0] = _profile
	for key: int in _stage_hikers.keys():
		if not cast.has(key):
			(_stage_hikers[key] as Node).queue_free()
			_stage_hikers.erase(key)
	var keys: Array = cast.keys()
	keys.sort()
	for i: int in keys.size():
		var key: int = keys[i]
		var hiker: Hiker = _stage_hikers.get(key)
		if hiker == null:
			hiker = HIKER.instantiate() as Hiker
			_stage_root.add_child(hiker)
			# The model faces -Z; the camera is at +Z.
			hiker.rotation.y = PI
			_stage_hikers[key] = hiker
		hiker.position = Vector3((float(i) - float(keys.size() - 1) * 0.5) * STAGE_SPACING, 0.0, 0.0)
		hiker.apply(cast[key], maxi(key, 1))


func _refresh_players() -> void:
	for child: Node in _players.get_children():
		child.queue_free()
	if not Net.in_lobby():
		return
	var keys: Array = Net.roster.keys()
	keys.sort()
	for peer: int in keys:
		var row := HBoxContainer.new()
		_players.add_child(row)
		var text: String = HikerStyle.display_name(Net.roster[peer], peer)
		if peer == 1:
			text += "  ·  " + tr("UI_LOBBY_HOST")
		if peer == Net.my_id():
			text += "  " + tr("UI_LOBBY_YOU")
		var label := _label(text, FONT_SIZE, TEXT_COLOR)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if Net.is_host() and peer != 1:
			var kick := _button("UI_LOBBY_KICK", func() -> void: multiplayer.multiplayer_peer.disconnect_peer(peer))
			kick.custom_minimum_size.y = 32
			row.add_child(kick)
