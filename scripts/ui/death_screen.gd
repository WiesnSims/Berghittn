class_name DeathScreen
extends Control
## Game-over overlay (solo: down = game over). Shows the run (kills, headshots, favourite weapon,
## Schnaps) and the personal best. The Restart click doubles as the gesture for pointer lock.
## Co-op (M9 "Nomoi!"): everyone's runs in the Hüttenwertung, Nomoi! to play again with the same
## people, and the room's invite link. Solo: Play with friends opens a room.

signal restart_requested
signal friends_requested

const QUIP_KEYS: Array[String] = ["UI_DEATH_QUIP_1", "UI_DEATH_QUIP_2", "UI_DEATH_QUIP_3", "UI_DEATH_QUIP_4"]
const HEADER_KEYS: Array[String] = [
	"UI_WERTUNG_NAME", "UI_WERTUNG_POINTS", "UI_DEATH_KILLS", "UI_DEATH_HEADSHOTS", "UI_DEATH_FAVOURITE",
	"UI_DEATH_SCHNAPS",
]
const HEADER_COLOR := Color(0.75, 0.7, 0.62)
const CELL_COLOR := Color(0.95, 0.92, 0.85)
const MINE_COLOR := Color(1.0, 0.86, 0.45)
const CELL_SIZE: int = 17

@onready var _quip: Label = %Quip
@onready var _stats: Label = %Stats
@onready var _new_best: Label = %NewBest
@onready var _run_grid: GridContainer = %Run
@onready var _kills: Label = %Kills
@onready var _headshots: Label = %Headshots
@onready var _favourite: Label = %Favourite
@onready var _schnaps: Label = %Schnaps
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


func _ready() -> void:
	_restart_button.pressed.connect(restart_requested.emit)
	_friends_button.pressed.connect(friends_requested.emit)
	_nomoi_button.pressed.connect(_on_nomoi_pressed)
	(%CopyLinkButton as Button).pressed.connect(_copy_link)
	_enable_timer.timeout.connect(_on_enable_timeout)
	Net.runs_changed.connect(_refresh_wertung)
	Net.nomoi_changed.connect(_refresh_nomoi)
	Net.roster_changed.connect(_refresh_nomoi)


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
	for button: Button in [_restart_button, _nomoi_button, _friends_button]:
		button.disabled = true
	_enable_timer.start()
	show()
	_refresh_nomoi()


func _on_enable_timeout() -> void:
	_restart_button.disabled = false
	_friends_button.disabled = false
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
			fav, str(row["schnaps"]),
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
