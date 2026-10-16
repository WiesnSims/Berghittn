class_name DeathScreen
extends Control
## Game-over overlay (solo: down = game over). The Restart click doubles as the gesture for pointer lock.

signal restart_requested

const QUIP_KEYS: Array[String] = ["UI_DEATH_QUIP_1", "UI_DEATH_QUIP_2", "UI_DEATH_QUIP_3", "UI_DEATH_QUIP_4"]

@onready var _quip: Label = %Quip
@onready var _stats: Label = %Stats
@onready var _restart_button: Button = %RestartButton
@onready var _enable_timer: Timer = $EnableTimer


func _ready() -> void:
	_restart_button.pressed.connect(restart_requested.emit)
	_enable_timer.timeout.connect(_on_enable_timeout)


func present(wave: int, points: int) -> void:
	_quip.text = tr(QUIP_KEYS.pick_random())
	_stats.text = tr("UI_DEATH_STATS") % [wave, points]
	# Players are usually still clicking when they die; do not let that click restart instantly.
	_restart_button.disabled = true
	_enable_timer.start()
	show()


func _on_enable_timeout() -> void:
	_restart_button.disabled = false
	_restart_button.grab_focus()
