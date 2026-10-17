class_name Hud
extends Control
## In-game overlay for the local player: health, ammo, points, wave, interact prompt, crosshair and damage feedback.

const SPENT_COLOR: Color = Color(0.9, 0.3, 0.25, 1)

@onready var _ammo_label: Label = %AmmoLabel
@onready var _weapon_label: Label = %WeaponLabel
@onready var _status_label: Label = %StatusLabel
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _damage_vignette: TextureRect = %DamageVignette
@onready var _crosshair: Crosshair = %Crosshair
@onready var _scope: ScopeOverlay = %ScopeOverlay
@onready var _points_label: Label = %PointsLabel
@onready var _points_popups: Control = %PointsPopups
@onready var _wave_label: Label = %WaveLabel
@onready var _banner: Label = %Banner
@onready var _countdown_label: Label = %CountdownLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _boss_box: Control = %BossBox
@onready var _boss_name: Label = %BossName
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _perk_icons: HBoxContainer = %PerkIcons
@onready var _perk_glow: TextureRect = %PerkGlow
@onready var _equipment_label: Label = %EquipmentLabel

var _weapons: WeaponHolder
var _dead: bool = false
var _vignette_tween: Tween
# Vignette strength that stays on screen while hurt, so low health is visible without looking at the bar.
var _hurt_level: float = 0.0
var _banner_tween: Tween
# Seconds until the next wave; negative while a wave is running.
var _countdown_left: float = -1.0
var _boss: Enemy
var _perks: PlayerPerks
# Perk tiles: the PerkData, its panel and the status label under the initial.
var _perk_tiles: Array[Dictionary] = []


func _ready() -> void:
	Events.wave_break_started.connect(_on_wave_break_started)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(_on_wave_cleared)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.event_announced.connect(_show_banner)


func _process(delta: float) -> void:
	if _boss:
		_boss_bar.value = maxi(_boss.health, 0)
		if not _boss.is_alive():
			_boss = null
			_boss_box.hide()
	_update_perks()
	if _weapons and not _dead:
		# Down the sights the gun's own sights are the crosshair; through the scope the reticle is.
		_scope.visible = _weapons.is_scoped()
		_crosshair.visible = _weapons.aim_amount < 0.5
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var half_fov: float = deg_to_rad(camera.fov) * 0.5
			_crosshair.set_spread(tan(deg_to_rad(_weapons.current_bloom())) / tan(half_fov) * size.y * 0.5)
	# The UI keeps running under the pause menu; the countdown must not.
	if _countdown_left < 0.0 or get_tree().paused:
		return
	_countdown_left -= delta
	_countdown_label.text = tr("UI_NEXT_WAVE") % ceili(_countdown_left) if _countdown_left > 0.0 else ""


func bind_player(player: Player) -> void:
	_weapons = player.weapons
	_weapons.ammo_changed.connect(_on_ammo_changed)
	_weapons.weapon_changed.connect(_on_weapon_changed)
	_weapons.reload_started.connect(_on_reload_changed.unbind(1))
	_weapons.reload_finished.connect(_on_reload_changed)
	_weapons.hit_confirmed.connect(_crosshair.show_hit)
	player.health.changed.connect(_on_health_changed)
	player.health.damaged.connect(_on_damaged.unbind(1))
	player.died.connect(_on_player_died)
	player.points.changed.connect(_on_points_changed)
	player.interactor.prompt_changed.connect(_on_prompt_changed)
	_perks = player.perks
	player.equipment.changed.connect(_on_equipment_changed)
	_on_equipment_changed(player.equipment.item, player.equipment.count)
	player.perks.changed.connect(_on_perks_changed)
	player.perks.triggered.connect(func(_id: StringName, text: String) -> void: _show_banner(tr(text)))
	_points_label.text = str(player.points.total)
	_on_weapon_changed(_weapons.weapon)
	_on_ammo_changed(_weapons.mag, _weapons.reserve)
	_on_health_changed(player.health.current(), player.health.max_health)


func _on_ammo_changed(mag: int, reserve: int) -> void:
	_ammo_label.text = tr("UI_AMMO") % [mag, reserve]
	_update_status()


func _on_weapon_changed(data: WeaponData) -> void:
	_weapon_label.text = tr(data.display_name)


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
	# Each gain floats up next to the total, so hits, kills and repairs are told apart at a glance;
	# purchases show as a red loss.
	var popup := Label.new()
	popup.text = tr("UI_POINTS_GAIN") % gained if gained >= 0 else tr("UI_POINTS_SPENT") % -gained
	popup.add_theme_font_size_override("font_size", 24)
	popup.add_theme_color_override("font_color", _points_label.get_theme_color("font_color") if gained >= 0 else SPENT_COLOR)
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


func _on_wave_started(wave: int, is_boss_wave: bool) -> void:
	_countdown_left = -1.0
	_countdown_label.text = ""
	_wave_label.text = tr("UI_WAVE") % wave
	_show_banner(tr("UI_BOSS_WAVE") if is_boss_wave else tr("UI_WAVE") % wave)


func _on_boss_spawned(enemy: Node3D) -> void:
	_boss = enemy as Enemy
	_boss_name.text = tr(_boss.data.display_name)
	_boss_bar.max_value = _boss.max_health
	_boss_bar.value = _boss.health
	_boss_box.show()


func _update_perks() -> void:
	if _perks == null:
		return
	var glow: Color = _perks.glow_color() if not _dead else Color(1, 1, 1, 0)
	_perk_glow.self_modulate = Color(glow.r, glow.g, glow.b)
	_perk_glow.modulate.a = glow.a
	for entry: Dictionary in _perk_tiles:
		var state: Dictionary = _perks.status(entry.perk)
		entry.label.text = state.text
		entry.tile.modulate = Color(1, 1, 1, 0.4 if state.dim else 1.0)


func _on_perks_changed(perks: Array[PerkData]) -> void:
	# One tile per Schnaps in the bottle's colour, with its initial and what it is doing; newest on the right.
	# Rebuilt only when the set changes (a Jause helping also signals, and must not re-announce).
	if perks.size() == _perk_tiles.size():
		return
	for child: Node in _perk_icons.get_children():
		child.queue_free()
	_perk_tiles.clear()
	for perk: PerkData in perks:
		var tile := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = perk.color
		style.set_border_width_all(2)
		style.border_color = Color(1, 1, 1, 0.7)
		style.set_corner_radius_all(4)
		tile.add_theme_stylebox_override("panel", style)
		tile.custom_minimum_size = Vector2(40, 40)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var letter := Label.new()
		letter.text = perk.badge if perk.badge != "" else tr(perk.display_name).left(1)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 17)
		letter.add_theme_color_override("font_outline_color", Color.BLACK)
		letter.add_theme_constant_override("outline_size", 4)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -4)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(letter)
		var state := Label.new()
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.add_theme_font_size_override("font_size", 11)
		state.add_theme_color_override("font_outline_color", Color.BLACK)
		state.add_theme_constant_override("outline_size", 3)
		box.add_child(state)
		tile.add_child(box)
		_perk_icons.add_child(tile)
		_perk_tiles.append({"perk": perk, "tile": tile, "label": state})
	if not perks.is_empty():
		_show_banner(tr(perks[-1].title) + "!")


func _on_equipment_changed(item: EquipmentData, count: int) -> void:
	_equipment_label.text = tr("UI_EQUIPMENT") % [tr(item.display_name), count] if item and count > 0 else ""


func _on_wave_cleared(wave: int) -> void:
	_show_banner(tr("UI_WAVE_CLEARED") % wave)


func _show_banner(text: String) -> void:
	_banner.text = text
	# Long event lines shrink to fit the screen, and wrap if even that is not enough.
	var font: Font = _banner.get_theme_font("font")
	var room: float = maxf(_banner.size.x, 200.0)
	var font_size: int = Constants.BANNER_FONT_SIZE
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if width > room:
		font_size = maxi(Constants.BANNER_MIN_FONT_SIZE, floori(font_size * room / width))
	_banner.add_theme_font_size_override("font_size", font_size)
	var fits: bool = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room
	_banner.autowrap_mode = TextServer.AUTOWRAP_OFF if fits else TextServer.AUTOWRAP_WORD_SMART
	if _banner_tween:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(Constants.WAVE_BANNER_TIME)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _on_player_died() -> void:
	_dead = true
	_scope.hide()
	_crosshair.hide()
	_status_label.text = ""
	_prompt_label.text = ""
	_countdown_left = -1.0
	_countdown_label.text = ""
