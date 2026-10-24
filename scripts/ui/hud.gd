class_name Hud
extends Control
## In-game overlay for the local player: health, ammo, points, wave, interact prompt, crosshair and damage feedback.

const SPENT_COLOR: Color = Color(0.9, 0.3, 0.25, 1)
const DOWN_COLOR: Color = Color(1.0, 0.35, 0.3)
const TEAM_COLOR: Color = Color(0.96, 0.92, 0.84)
const STREAK_COLOR: Color = Color(1.0, 0.82, 0.3)

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
@onready var _melee_label: Label = %MeleeLabel

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
var _player: Player
# Co-op (M7): what happens to us when down or out (centre), and how the team is doing (top left).
var _coop_label: Label
var _team_label: Label
var _coop_over: bool = false
# Kill streaks (M9 part 2): a small banner under the crosshair.
var _streak_label: Label
var _streak_tween: Tween


func _ready() -> void:
	_coop_label = _make_label(DOWN_COLOR, 34, HORIZONTAL_ALIGNMENT_CENTER)
	_coop_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_coop_label.offset_top = -260.0
	_coop_label.offset_bottom = -180.0
	_coop_label.offset_left = -500.0
	_coop_label.offset_right = 500.0
	_streak_label = _make_label(STREAK_COLOR, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_streak_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_streak_label.offset_top = 48.0
	_streak_label.offset_bottom = 88.0
	_streak_label.offset_left = -300.0
	_streak_label.offset_right = 300.0
	_streak_label.modulate.a = 0.0
	_team_label = _make_label(TEAM_COLOR, 18, HORIZONTAL_ALIGNMENT_LEFT)
	# One line per teammate under the wave label; names are short (HikerStyle.NAME_MAX_LENGTH).
	_team_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_team_label.position = Vector2(24.0, 112.0)
	_team_label.size = Vector2(360.0, 100.0)
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
	_update_coop()
	if _weapons and not _dead and (_player == null or _player.life != Player.Life.OUT):
		# Down the sights the gun's own sights are the crosshair; through the scope the reticle is.
		_scope.visible = _weapons.is_scoped()
		_crosshair.visible = _weapons.aim_amount < 0.5
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera:
			var half_fov: float = deg_to_rad(camera.fov) * 0.5
			_crosshair.set_spread(tan(deg_to_rad(_weapons.current_bloom())) / tan(half_fov) * size.y * 0.5)
		_crosshair.set_progress(_weapons.reload_progress(), _weapons.cycle_progress(), _weapons.shows_cycle_ring())
	# The UI keeps running under the pause menu; the countdown must not.
	if _countdown_left < 0.0 or get_tree().paused:
		return
	_countdown_left -= delta
	_countdown_label.text = tr("UI_NEXT_WAVE") % ceili(_countdown_left) if _countdown_left > 0.0 else ""


func bind_player(player: Player) -> void:
	_player = player
	_weapons = player.weapons
	_weapons.ammo_changed.connect(_on_ammo_changed)
	_weapons.weapon_changed.connect(_on_weapon_changed)
	_weapons.edge_changed.connect(_on_edge_changed)
	_weapons.went_dull.connect(func(was: WeaponData, _now: WeaponData) -> void:
		_show_banner(tr("UI_STUMPF") % tr(was.display_name))
		_on_weapon_changed(_weapons.weapon))
	_weapons.reload_started.connect(_on_reload_changed.unbind(1))
	_weapons.reload_finished.connect(_on_reload_changed)
	_weapons.hit_confirmed.connect(_crosshair.show_hit)
	player.feedback.killed.connect(_crosshair.show_kill)
	player.feedback.streak.connect(_show_streak)
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
	if _weapons.melee_weapon:
		_melee_label.text = Keys.fill(tr("UI_MELEE")) % tr(_weapons.melee_weapon.display_name)
	# Connected after the start weapon is shown, so only a new one gets the banner.
	_weapons.melee_changed.connect(_on_melee_changed)
	_on_ammo_changed(_weapons.mag, _weapons.reserve)
	_on_health_changed(player.health.current(), player.health.max_health)


func _on_ammo_changed(mag: int, reserve: int) -> void:
	_ammo_label.text = tr("UI_AMMO") % [mag, reserve]
	_update_status()


func _on_weapon_changed(data: WeaponData) -> void:
	# Nothing in hand while the gun is at the Dengelstock.
	_weapon_label.text = tr(data.display_name) if data else ""
	var edge: int = _weapons.edge_left()
	if data and edge >= 0:
		_weapon_label.text += "  " + tr("UI_EDGE") % edge
	_update_status()


# Stumpf: the edge's kills left next to the name, and a warning once it is nearly dull.
func _on_edge_changed(left: int, melee: bool) -> void:
	if melee:
		_melee_label.text = Keys.fill(tr("UI_MELEE")) % tr(_weapons.melee_weapon.display_name) + "  " + tr("UI_EDGE") % left
	else:
		_on_weapon_changed(_weapons.weapon)
	if left == Constants.STUMPF_WARN:
		var data: WeaponData = _weapons.melee_weapon if melee else _weapons.weapon
		_show_banner(tr("UI_STUMPF_SOON") % tr(data.display_name))


func _on_melee_changed(data: WeaponData) -> void:
	if data == null:
		_melee_label.text = ""
		return
	_melee_label.text = Keys.fill(tr("UI_MELEE")) % tr(data.display_name)
	if _weapons.edge_left(true) >= 0:
		_melee_label.text += "  " + tr("UI_EDGE") % _weapons.edge_left(true)
	_show_banner(tr("UI_MELEE_TAKEN") % tr(data.display_name))


func _on_reload_changed() -> void:
	_update_status()


func _update_status() -> void:
	if _weapons.weapon == null:
		_status_label.text = ""
	elif _weapons.is_reloading():
		_status_label.text = tr("UI_RELOADING")
	elif _weapons.mag == 0:
		_status_label.text = Keys.fill(tr("UI_RELOAD_HINT")) if _weapons.reserve > 0 else tr("UI_NO_AMMO")
	elif _weapons.mag * 4 <= _weapons.weapon.mag_size:
		_status_label.text = Keys.fill(tr("UI_RELOAD_HINT"))
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
	# Prompts name the key ("Press {interact} ..."): whatever it is bound to now (Keys).
	_prompt_label.text = Keys.fill(text)


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
	_equipment_label.text = Keys.fill(tr("UI_EQUIPMENT")) % [tr(item.display_name), count] if item and count > 0 else ""


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


## "Dreierlei!  +50" under the crosshair; the bonus also shows in the points popup.
func _show_streak(text: String, bonus: int) -> void:
	_streak_label.text = tr("UI_STREAK") % [tr(text), bonus]
	if _streak_tween:
		_streak_tween.kill()
	_streak_label.modulate.a = 1.0
	_streak_label.scale = Vector2.ONE * 1.25
	_streak_label.pivot_offset = _streak_label.size * 0.5
	_streak_tween = create_tween()
	_streak_tween.tween_property(_streak_label, "scale", Vector2.ONE, 0.15)
	_streak_tween.tween_interval(Constants.STREAK_BANNER_TIME)
	_streak_tween.tween_property(_streak_label, "modulate:a", 0.0, 0.4)


func _make_label(color: Color, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


## Co-op game over: the death screen says it all now.
func end_coop() -> void:
	_coop_over = true


## Co-op: our own downed or out state in the middle, and every teammate's state and health.
func _update_coop() -> void:
	if _player == null or Coop.players == null or _coop_over:
		_coop_label.text = ""
		_team_label.text = ""
		return
	match _player.life:
		Player.Life.DOWNED:
			var text: String = Keys.fill(tr("UI_COOP_DOWNED")) % ceili(_player.bleed_left)
			if _player.revive_progress > 0.0:
				text += "\n" + tr("UI_COOP_BEING_REVIVED") % roundi(_player.revive_progress * 100.0)
			_coop_label.text = text
		Player.Life.OUT:
			_coop_label.text = tr("UI_COOP_OUT")
			_crosshair.hide()
			_scope.hide()
		_:
			_coop_label.text = ""
	var lines: PackedStringArray = []
	var lives: Dictionary = Coop.players.lives()
	var peers: Array = lives.keys()
	peers.sort()
	for peer: int in peers:
		if peer == Net.my_id():
			continue
		var name: String = HikerStyle.display_name(Net.roster.get(peer, {}), peer)
		match lives[peer]:
			Player.Life.DOWNED:
				lines.append(tr("UI_COOP_TEAM_DOWN") % name)
			Player.Life.OUT:
				lines.append(tr("UI_COOP_TEAM_OUT") % name)
			_:
				lines.append("%s  %d %%" % [name, roundi(Coop.players.health_share(peer) * 100.0)])
	_team_label.text = "\n".join(lines)


func _on_player_died() -> void:
	_dead = true
	_scope.hide()
	_crosshair.hide()
	_status_label.text = ""
	_prompt_label.text = ""
	_countdown_left = -1.0
	_countdown_label.text = ""
