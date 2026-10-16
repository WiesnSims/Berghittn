class_name Hud
extends Control
## In-game overlay for the local player: health, ammo, points, wave, interact prompt, crosshair and damage feedback.

@onready var _ammo_label: Label = %AmmoLabel
@onready var _status_label: Label = %StatusLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _damage_vignette: TextureRect = %DamageVignette
@onready var _crosshair: Crosshair = %Crosshair
@onready var _points_label: Label = %PointsLabel
@onready var _points_popups: Control = %PointsPopups
@onready var _wave_label: Label = %WaveLabel
@onready var _banner: Label = %Banner
@onready var _countdown_label: Label = %CountdownLabel
@onready var _prompt_label: Label = %PromptLabel

var _weapons: WeaponHolder
var _vignette_tween: Tween
# Vignette strength that stays on screen while hurt, so low health is visible without looking at the bar.
var _hurt_level: float = 0.0
var _banner_tween: Tween
# Seconds until the next wave; negative while a wave is running.
var _countdown_left: float = -1.0


func _ready() -> void:
	Events.wave_break_started.connect(_on_wave_break_started)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)


func _process(delta: float) -> void:
	# The UI keeps running under the pause menu; the countdown must not.
	if _countdown_left < 0.0 or get_tree().paused:
		return
	_countdown_left -= delta
	_countdown_label.text = tr("UI_NEXT_WAVE") % ceili(_countdown_left) if _countdown_left > 0.0 else ""


func bind_player(player: Player) -> void:
	_weapons = player.weapons
	_weapons.ammo_changed.connect(_on_ammo_changed)
	_weapons.reload_started.connect(_on_reload_changed.unbind(1))
	_weapons.reload_finished.connect(_on_reload_changed)
	_weapons.hit_confirmed.connect(_crosshair.show_hit)
	player.health.changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_damaged.unbind(1))
	player.died.connect(_on_player_died)
	player.points.changed.connect(_on_points_changed)
	player.interactor.prompt_changed.connect(_on_prompt_changed)
	_points_label.text = str(player.points.total)
	_on_ammo_changed(_weapons.mag, _weapons.reserve)
	_on_health_changed(player.health.current(), player.health.max_health)


func _on_ammo_changed(mag: int, reserve: int) -> void:
	_ammo_label.text = tr("UI_AMMO") % [mag, reserve]
	_update_status()


func _on_reload_changed() -> void:
	_update_status()


func _update_status() -> void:
	if _weapons.is_reloading():
		_status_label.text = tr("UI_RELOADING")
	elif _weapons.mag == 0:
		_status_label.text = tr("UI_RELOAD_HINT") if _weapons.reserve > 0 else tr("UI_NO_AMMO")
	elif _weapons.mag * 4 <= _weapons.weapon.mag_size:
		_status_label.text = tr("UI_RELOAD_HINT")
	else:
		_status_label.text = ""


func _on_health_changed(current: int, maximum: int) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_hurt_level = (1.0 - float(current) / maximum) * 0.6
	if _vignette_tween == null or not _vignette_tween.is_running():
		_damage_vignette.modulate.a = _hurt_level


func _on_damaged() -> void:
	if _vignette_tween:
		_vignette_tween.kill()
	_damage_vignette.modulate.a = 1.0
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_damage_vignette, "modulate:a", _hurt_level, Constants.DAMAGE_FLASH_TIME)


func _on_points_changed(total: int, gained: int) -> void:
	_points_label.text = str(total)
	# Each gain floats up next to the total, so hits, kills and repairs are told apart at a glance.
	var popup := Label.new()
	popup.text = tr("UI_POINTS_GAIN") % gained
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", _points_label.get_theme_color("font_color"))
	popup.add_theme_color_override("font_outline_color", Color.BLACK)
	popup.add_theme_constant_override("outline_size", 4)
	popup.position = Vector2(_points_label.get_minimum_size().x + 12.0, 8.0 + randf() * 8.0)
	_points_popups.add_child(popup)
	var tween: Tween = popup.create_tween().set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y - 28.0, Constants.POINTS_POPUP_TIME)
	tween.tween_property(popup, "modulate:a", 0.0, Constants.POINTS_POPUP_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)


func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_wave_break_started(_next_wave: int, duration: float) -> void:
	_countdown_left = duration


func _on_wave_started(wave: int) -> void:
	_countdown_left = -1.0
	_countdown_label.text = ""
	_wave_label.text = tr("UI_WAVE") % wave
	_show_banner(tr("UI_WAVE") % wave)


func _on_wave_cleared(wave: int) -> void:
	_show_banner(tr("UI_WAVE_CLEARED") % wave)


func _show_banner(text: String) -> void:
	_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(Constants.WAVE_BANNER_TIME)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_player_died() -> void:
	_crosshair.hide()
	_status_label.text = ""
	_prompt_label.text = ""
	_countdown_left = -1.0
	_countdown_label.text = ""
