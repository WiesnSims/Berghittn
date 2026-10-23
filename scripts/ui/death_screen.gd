class_name DeathScreen
extends Control
## Game-over overlay (solo: down = game over). Shows the run (kills, headshots, favourite weapon,
## Schnaps) and the personal best. The Restart click doubles as the gesture for pointer lock.

signal restart_requested

const QUIP_KEYS: Array[String] = ["UI_DEATH_QUIP_1", "UI_DEATH_QUIP_2", "UI_DEATH_QUIP_3", "UI_DEATH_QUIP_4"]

@onready var _quip: Label = %Quip
@onready var _stats: Label = %Stats
@onready var _new_best: Label = %NewBest
@onready var _kills: Label = %Kills
@onready var _headshots: Label = %Headshots
@onready var _favourite: Label = %Favourite
@onready var _schnaps: Label = %Schnaps
@onready var _best: Label = %Best
@onready var _restart_button: Button = %RestartButton
@onready var _enable_timer: Timer = $EnableTimer


func _ready() -> void:
	_restart_button.pressed.connect(restart_requested.emit)
	_enable_timer.timeout.connect(_on_enable_timeout)


## `run`: our player's stats; `new_best`: this run just became the personal best (Settings.record_run).
## `coop`: the button leads back to the room's lobby instead of a new game.
func present(wave: int, points: int, run: PlayerStats, new_best: bool, coop: bool = false) -> void:
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
	# Players are usually still clicking when they die; do not let that click restart instantly.
	_restart_button.disabled = true
	_enable_timer.start()
	show()


func _on_enable_timeout() -> void:
	_restart_button.disabled = false
	_restart_button.grab_focus()
