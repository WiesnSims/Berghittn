class_name DeathScreen
extends Control
## Game-over overlay (solo: down = game over). Shows the run (kills, headshots, favourite weapon,
## Schnaps, Bsundan killed) and the personal best. The Restart click doubles as the gesture for pointer lock.
## Co-op (M9 "Nomoi!"): everyone's runs in the Hüttenwertung, Nomoi! to play again with the same
## people, and the room's invite link. Solo: Play with friends opens a room.
## Das Gipfelbuch: the run's place on the global leaderboard (solo sent from here; in co-op the host
## sends the group's and everyone hears its place). Solo without a name it asks for one once.
## Under the buttons (1.1.2): the Gipfelbuch itself, and the way back to the title screen.

signal restart_requested
signal friends_requested
## Back to the title screen (co-op: out of the room).
signal menu_requested

const QUIP_KEYS: Array[String] = ["UI_DEATH_QUIP_1", "UI_DEATH_QUIP_2", "UI_DEATH_QUIP_3", "UI_DEATH_QUIP_4"]
const HEADER_KEYS: Array[String] = [
	"UI_WERTUNG_NAME", "UI_WERTUNG_POINTS", "UI_DEATH_KILLS", "UI_DEATH_HEADSHOTS", "UI_DEATH_FAVOURITE",
	"UI_DEATH_SCHNAPS", "UI_DEATH_BSUNDAN",
]
const HEADER_COLOR := Color(0.75, 0.7, 0.62)
const CELL_COLOR := Color(0.95, 0.92, 0.85)
const MINE_COLOR := Color(1.0, 0.86, 0.45)
const CELL_SIZE: int = 17
const BOARD_COLOR := Color(1.0, 0.86, 0.45)
const BOARD_SIZE: int = 22

@onready var _quip: Label = %Quip
@onready var _stats: Label = %Stats
@onready var _new_best: Label = %NewBest
@onready var _run_grid: GridContainer = %Run
@onready var _kills: Label = %Kills
@onready var _headshots: Label = %Headshots
@onready var _favourite: Label = %Favourite
@onready var _schnaps: Label = %Schnaps
@onready var _bsundan: Label = %Bsundan
@onready var _wertung: GridContainer = %Wertung
@onready var _best: Label = %Best
@onready var _restart_button: Button = %RestartButton
@onready var _nomoi_button: Button = %NomoiButton
@onready var _friends_button: Button = %FriendsButton
@onready var _nomoi_count: Label = %NomoiCount
@onready var _invite: Control = %Invite
@onready var _invite_hint: Label = %InviteHint
@onready var _enable_timer: Timer = $EnableTimer

var _coop: bool = false
var _wants_nomoi: bool = false
# Das Gipfelbuch: the line with the run's place, the name question, and the solo run to send.
var _board_line: Label
var _ask: HBoxContainer
var _name_edit: LineEdit
var _board_entry: Dictionary = {}
var _board_panel: BoardPanel
var _board_button: Button
var _menu_button: Button


func _ready() -> void:
	_restart_button.pressed.connect(restart_requested.emit)
	_friends_button.pressed.connect(friends_requested.emit)
	_nomoi_button.pressed.connect(_on_nomoi_pressed)
	(%CopyLinkButton as Button).pressed.connect(_copy_link)
	_enable_timer.timeout.connect(_on_enable_timeout)
	Net.runs_changed.connect(_refresh_wertung)
	Net.nomoi_changed.connect(_refresh_nomoi)
	Net.roster_changed.connect(_refresh_nomoi)
	_build_board()
	_build_more()
	Board.ranked.connect(_on_ranked)
	Board.not_ranked.connect(func() -> void: _board_line.hide())


## `run`: our player's stats; `new_best`: this run just became the personal best (Settings.record_run).
## `coop`: Nomoi! and the Hüttenwertung, and the other button leads back to the room's lobby.
func present(wave: int, points: int, run: PlayerStats, new_best: bool, coop: bool = false) -> void:
	_coop = coop
	_wants_nomoi = false
	_restart_button.text = "UI_BACK_TO_LOBBY" if coop else "UI_RESTART"
	_quip.text = tr(QUIP_KEYS.pick_random())
	_stats.text = tr("UI_DEATH_STATS") % [wave, points]
	_kills.text = str(run.kills)
	_headshots.text = tr("UI_DEATH_SHARE") % [run.headshots, roundi(100.0 * run.headshots / maxi(run.kills, 1))]
	var favourite: WeaponData = run.favourite()
	_favourite.text = tr("UI_DEATH_WEAPON") % [tr(favourite.display_name), run.kills_with(favourite)] if favourite else tr("UI_DEATH_NONE")
	_schnaps.text = str(run.schnaps)
	_bsundan.text = str(run.bsundan)
	_new_best.visible = new_best
	_best.visible = not new_best
	_best.text = tr("UI_DEATH_BEST") % [Settings.best_wave, Settings.best_points]
	# Co-op: our own run is a row of the Hüttenwertung instead.
	_run_grid.visible = not coop
	_wertung.visible = coop
	_nomoi_button.visible = coop
	_friends_button.visible = not coop
	_invite.visible = coop
	_invite_hint.hide()
	if coop:
		(%Room as Label).text = tr("UI_LOBBY_ROOM") % Net.code
		_refresh_wertung()
	# Players are usually still clicking when they die; do not let that click restart instantly.
	for button: Button in [_restart_button, _nomoi_button, _friends_button, _board_button, _menu_button]:
		button.disabled = true
	_board_panel.hide()
	_enable_timer.start()
	show()
	_refresh_nomoi()


## Solo: sends the run to the Gipfelbuch (keys as Board.submit takes them, without the names), or
## first asks for a name if the player never typed one.
func offer_board(entry: Dictionary) -> void:
	if not Board.has_run("solo"):
		return
	_board_entry = entry
	var player_name: String = str(Settings.profile.get("name", "")).strip_edges()
	if player_name == "":
		_ask.show()
		return
	_send_board(player_name)


func _send_board(player_name: String) -> void:
	_ask.hide()
	_board_line.text = tr("UI_BOARD_SENDING")
	_board_line.show()
	var entry: Dictionary = _board_entry.duplicate()
	entry["names"] = [player_name]
	Board.submit(entry)


## The name typed for the Gipfelbuch is our name from now on (also in the lobby).
func _on_board_enter(_text: String = "") -> void:
	var player_name: String = _name_edit.text.strip_edges().left(HikerStyle.NAME_MAX_LENGTH)
	if player_name == "":
		return
	var profile: Dictionary = Settings.edit_profile(1)
	profile["name"] = player_name
	Settings.profile = profile
	Settings.save()
	_send_board(player_name)


## Not into the Gipfelbuch: the Settings switch goes off (and can be turned on again there).
func _on_board_skip() -> void:
	Settings.board = false
	Settings.save()
	_ask.hide()
	_board_line.text = tr("UI_BOARD_OFF_HINT")
	_board_line.show()


func _on_ranked(rank: int, week_rank: int, _id: int) -> void:
	_board_line.text = tr("UI_BOARD_RANK") % rank if week_rank == rank else tr("UI_BOARD_RANK_WEEK") % [rank, week_rank]
	_board_line.show()


# Under the personal best: the place line, and the name question (both hidden until needed).
func _build_board() -> void:
	var box: Control = _best.get_parent()
	_board_line = Label.new()
	_board_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_line.add_theme_font_size_override("font_size", BOARD_SIZE)
	_board_line.add_theme_color_override("font_color", BOARD_COLOR)
	_board_line.hide()
	box.add_child(_board_line)
	box.move_child(_board_line, _best.get_index() + 1)
	_ask = HBoxContainer.new()
	_ask.alignment = BoxContainer.ALIGNMENT_CENTER
	_ask.add_theme_constant_override("separation", 10)
	var question := Label.new()
	question.text = "UI_BOARD_ASK"
	_ask.add_child(question)
	_name_edit = LineEdit.new()
	_name_edit.max_length = HikerStyle.NAME_MAX_LENGTH
	_name_edit.custom_minimum_size = Vector2(220, 0)
	_name_edit.text_submitted.connect(_on_board_enter)
	_ask.add_child(_name_edit)
	var enter := Button.new()
	enter.text = "UI_BOARD_ENTER"
	enter.pressed.connect(_on_board_enter)
	_ask.add_child(enter)
	var skip := Button.new()
	skip.text = "UI_BOARD_SKIP"
	skip.pressed.connect(_on_board_skip)
	_ask.add_child(skip)
	_ask.hide()
	box.add_child(_ask)
	box.move_child(_ask, _board_line.get_index() + 1)


# A second, smaller row under the buttons: the Gipfelbuch (on this run's board, our entries
# highlighted) and Main menu.
func _build_more() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var buttons: Control = _restart_button.get_parent()
	buttons.get_parent().add_child(row)
	buttons.get_parent().move_child(row, buttons.get_index() + 1)
	_board_button = _small_button(row, "UI_BOARD")
	_board_button.pressed.connect(func() -> void: _board_panel.open("coop" if _coop else "solo"))
	_menu_button = _small_button(row, "UI_MAIN_MENU")
	_menu_button.pressed.connect(menu_requested.emit)
	_board_panel = BoardPanel.new()
	add_child(_board_panel)


func _small_button(row: Control, key: String) -> Button:
	var button := Button.new()
	button.text = key
	button.custom_minimum_size = Vector2(240, 44)
	button.add_theme_font_size_override("font_size", 22)
	row.add_child(button)
	return button


func _on_enable_timeout() -> void:
	_restart_button.disabled = false
	_friends_button.disabled = false
	_board_button.disabled = false
	_menu_button.disabled = false
	_refresh_nomoi()
	(_nomoi_button if _coop and not _nomoi_button.disabled else _restart_button).grab_focus()


func _on_nomoi_pressed() -> void:
	_wants_nomoi = true
	Net.want_nomoi()
	_refresh_nomoi()


func _copy_link() -> void:
	DisplayServer.clipboard_set(Net.invite_url())
	_invite_hint.show()


## Greyed out once pressed, while the buttons wait out the stray click, and with nobody else left.
func _refresh_nomoi() -> void:
	if not visible or not _coop:
		return
	var alone: bool = Net.roster.size() < Constants.NET_MIN_PLAYERS
	_nomoi_button.disabled = _wants_nomoi or alone or not _enable_timer.is_stopped()
	_nomoi_button.text = "UI_NOMOI_WAITING" if _wants_nomoi else "UI_NOMOI"
	_nomoi_count.visible = Net.nomoi_total > 0 and not alone
	_nomoi_count.text = tr("UI_NOMOI_COUNT") % [Net.nomoi_ready, Net.nomoi_total]
	_invite.visible = Net.state != Net.State.OFFLINE


## One row per player, best points first, ours highlighted.
func _refresh_wertung() -> void:
	if not _coop:
		return
	for child: Node in _wertung.get_children():
		_wertung.remove_child(child)
		child.queue_free()
	for key: String in HEADER_KEYS:
		_wertung.add_child(_cell(tr(key), HEADER_COLOR))
	var peers: Array = Net.runs.keys()
	peers.sort_custom(func(a: int, b: int) -> bool: return int(Net.runs[a]["points"]) > int(Net.runs[b]["points"]))
	for peer: int in peers:
		var row: Dictionary = Net.runs[peer]
		var color: Color = MINE_COLOR if peer == Net.my_id() else CELL_COLOR
		var kills: int = row["kills"]
		var fav: String = tr("UI_DEATH_WEAPON") % [tr(row["fav"]), row["fav_kills"]] if row["fav"] != "" else tr("UI_DEATH_NONE")
		for text: String in [
			row["name"], str(row["points"]), str(kills),
			tr("UI_DEATH_SHARE") % [row["headshots"], roundi(100.0 * int(row["headshots"]) / maxi(kills, 1))],
			fav, str(row["schnaps"]), str(row["bsundan"]),
		]:
			_wertung.add_child(_cell(text, color))


func _cell(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	# Names and weapon keys are shown as they are, not looked up again.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", CELL_SIZE)
	label.add_theme_color_override("font_color", color)
	return label
