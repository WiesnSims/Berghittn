class_name Hud
extends Control
## In-game overlay for the local player: health, ammo, crosshair and damage feedback.

@onready var _ammo_label: Label = %AmmoLabel
@onready var _status_label: Label = %StatusLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _damage_vignette: TextureRect = %DamageVignette
@onready var _crosshair: Crosshair = %Crosshair

var _weapons: WeaponHolder
var _vignette_tween: Tween
# Vignette strength that stays on screen while hurt, so low health is visible without looking at the bar.
var _hurt_level: float = 0.0


func bind_player(player: Player) -> void:
	_weapons = player.weapons
	_weapons.ammo_changed.connect(_on_ammo_changed)
	_weapons.reload_started.connect(_on_reload_changed.unbind(1))
	_weapons.reload_finished.connect(_on_reload_changed)
	_weapons.hit_confirmed.connect(_crosshair.show_hit)
	player.health.changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_damaged.unbind(1))
	player.died.connect(_on_player_died)
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


func _on_player_died() -> void:
	_crosshair.hide()
	_status_label.text = ""
