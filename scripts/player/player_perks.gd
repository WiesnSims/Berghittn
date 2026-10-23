class_name PlayerPerks
extends Node
## The Schnaps this player has had (section 9) and their signature effects, plus the helpings from the
## Brettljause (the stat gains). Schnaps are gone when the player goes down; the Jause stays, and so does
## what the Jagamoasta's 56 herbs paid for.

signal changed(perks: Array[PerkData])
## A signature effect went off; `text` is a translation key for the HUD banner.
signal triggered(id: StringName, text: String)

const DURCHSCHLAG: StringName = &"zirbenschnaps"
const BOELLERSCHUSS: StringName = &"marillenbrand"
const STURSCHAEDL: StringName = &"enzian"
const GMIATLICHKEIT: StringName = &"jagertee"
const GRANTLER: StringName = &"obstler"
const KRAEUTER: StringName = &"jagamoasta"

const BOELLER_BLAST: Script = preload("res://scripts/perks/boeller_blast.gd")

var owned: Array[PerkData] = []
## Kills towards the 56 gsunde Kräuter (Jagamoasta), and whether they have paid out: +20 % max health
## and +20 % damage for good, kept when the player goes down.
var herbs: int = 0
var herbs_done: bool = false
@onready var _player: Player = get_parent() as Player
@onready var _health: PlayerHealth = get_parent().get_node("Health")
# Helpings eaten per Jause id, and the data behind them.
var _jause_levels: Dictionary = {}
var _jause: Dictionary = {}
var _wave: int = 1
var _boeller_left: float = 0.0
var _stur_used: bool = false
var _cosy_time: float = 0.0
var _grumps: int = 0
var _herb_glow_left: float = 0.0


func _ready() -> void:
	_health.died.connect(clear)
	_health.death_guard = _cheat_death
	Events.wave_started.connect(_on_wave_started)
	Events.enemy_killed.connect(_on_enemy_killed)


func _physics_process(delta: float) -> void:
	_boeller_left = maxf(_boeller_left - delta, 0.0)
	_herb_glow_left = maxf(_herb_glow_left - delta, 0.0)
	var cosy: bool = false
	if has_id(GMIATLICHKEIT):
		var moving: float = Vector2(_player.velocity.x, _player.velocity.z).length()
		_cosy_time = _cosy_time + delta if moving < Constants.PERK_COSY_STILL_SPEED or _player.is_crouching() else 0.0
		cosy = _cosy_time >= Constants.PERK_COSY_TIME and not _health.is_swarmed()
	_health.regen_multiplier = Constants.PERK_COSY_REGEN_MULTIPLIER if cosy else 1.0
	_health.regen_skips_delay = cosy
	_grumps = _count_close_enemies() if has_id(GRANTLER) else 0


func has(perk: PerkData) -> bool:
	return has_id(perk.id)


func has_id(id: StringName) -> bool:
	return owned.any(func(p: PerkData) -> bool: return p.id == id)


## Still worth buying: not had yet, and not a Jagamoasta whose herbs have already paid out.
func wants(perk: PerkData) -> bool:
	return not has(perk) and not (perk.id == KRAEUTER and herbs_done)


func add(perk: PerkData) -> void:
	if has(perk):
		return
	owned.append(perk)
	if perk.id == KRAEUTER:
		herbs = 0
	if perk.id == STURSCHAEDL:
		_stur_used = false
	changed.emit(owned)


func clear() -> void:
	if owned.is_empty():
		return
	owned.clear()
	changed.emit(owned)


# --- Brettljause ---

func jause_level(jause: JauseData) -> int:
	return _jause_levels.get(jause.id, 0)


func eat(jause: JauseData) -> void:
	_jause[jause.id] = jause
	_jause_levels[jause.id] = jause_level(jause) + 1
	if jause.max_health_bonus > 0:
		_health.raise_max(jause.max_health_bonus)
	changed.emit(owned)


# --- What the rest of the game asks ---

## Weapon damage factor: Pinzgauer Kasnockn, the Obstler's grumpiness and the Jagamoasta's herbs.
func damage_multiplier() -> float:
	var factor: float = 1.0 + _jause_sum(func(j: JauseData) -> float: return j.damage_bonus)
	factor *= 1.0 + grantler_bonus()
	if herbs_done:
		factor *= 1.0 + Constants.PERK_HERB_DAMAGE
	return factor


## Reload time factor (Germknedl): +25 % reload speed makes a reload take 1 / 1.25 of the time.
func reload_time_multiplier() -> float:
	return 1.0 / (1.0 + _jause_sum(func(j: JauseData) -> float: return j.reload_speed_bonus))


## Durchschlag: bodies every shot goes through on top of the gun's own penetration.
func extra_penetration() -> int:
	return Constants.PERK_PIERCE_BONUS if has_id(DURCHSCHLAG) else 0


## Grantler: the more of them crowd in, the harder you hit back.
func grantler_bonus() -> float:
	return minf(_grumps * Constants.PERK_GRANT_PER_ENEMY, Constants.PERK_GRANT_MAX)


func is_invincible() -> bool:
	return _health.invincible_left > 0.0


func is_cosy() -> bool:
	return _health.regen_skips_delay


## Böllerschuss: the weapon holder calls this when a reload starts on an empty magazine.
func on_empty_reload() -> void:
	if not has_id(BOELLERSCHUSS) or _boeller_left > 0.0:
		return
	_boeller_left = Constants.PERK_BOELLER_COOLDOWN
	_boeller()


## What the HUD tile shows under the Schnaps' initial, and whether it is greyed out (spent, cooling).
func status(perk: PerkData) -> Dictionary:
	match perk.id:
		STURSCHAEDL:
			if is_invincible():
				return {"text": "%.0f" % ceilf(_health.invincible_left), "dim": false}
			return {"text": "", "dim": _stur_used}
		BOELLERSCHUSS:
			return {"text": str(ceili(_boeller_left)) if _boeller_left > 0.0 else "", "dim": _boeller_left > 0.0}
		GRANTLER:
			var bonus: float = grantler_bonus()
			return {"text": "+%d%%" % roundi(bonus * 100.0) if bonus > 0.0 else "", "dim": bonus <= 0.0}
		KRAEUTER:
			if herbs_done:
				return {"text": "+%d%%" % roundi(Constants.PERK_HERB_DAMAGE * 100.0), "dim": false}
			return {"text": "%d/%d" % [herbs, Constants.PERK_HERBS], "dim": false}
		GMIATLICHKEIT:
			return {"text": "", "dim": not is_cosy()}
	return {"text": "", "dim": false}


## Full-screen glow for effects that are running: gold while Sturschädl holds, green as the 56 herbs
## pay out, warm while cosily healing. Transparent when nothing runs.
func glow_color() -> Color:
	var t: float = Time.get_ticks_msec() / 1000.0
	if is_invincible():
		return Color(1.0, 0.78, 0.25, 0.55 + 0.25 * sin(t * TAU * 2.5))
	if _herb_glow_left > 0.0:
		return Color(0.35, 0.85, 0.3, 0.5 * _herb_glow_left / Constants.PERK_HERB_GLOW_TIME)
	if is_cosy() and _health.current() < _health.max_health:
		return Color(1.0, 0.6, 0.3, 0.22)
	return Color(1, 1, 1, 0)


# --- Effects ---

func _cheat_death() -> bool:
	# Sturschädl: once per wave a lethal hit leaves 1 HP and a few seconds where nothing gets through.
	if not has_id(STURSCHAEDL) or _stur_used:
		return false
	_stur_used = true
	_health.invincible_left = Constants.PERK_STUR_INVINCIBLE_TIME
	triggered.emit(STURSCHAEDL, "PERK_ENZIAN_SHOUT")
	return true


func _boeller() -> void:
	# A Schützen black-powder salute around the player: damage falls off to half at the edge, walls
	# stop it, and whoever survives is thrown back.
	var center: Vector3 = _player.global_position
	var damage: int = Constants.PERK_BOELLER_DAMAGE + Constants.PERK_BOELLER_DAMAGE_PER_WAVE * _wave
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var to: Vector3 = enemy.global_position - center
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > Constants.PERK_BOELLER_RADIUS or absf(to.y) > 2.0:
			continue
		var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP, enemy.global_position + Vector3.UP, Constants.LAYER_WORLD)
		if not space.intersect_ray(query).is_empty():
			continue
		var share: float = lerpf(1.0, 0.5, flat.length() / Constants.PERK_BOELLER_RADIUS)
		enemy.receive_hit(roundi(damage * share), false, false, _player)
		if enemy.is_alive():
			var away: Vector3 = flat.normalized() if flat.length() > 0.05 else -_player.global_basis.z
			enemy.apply_knockback(away * Constants.PERK_BOELLER_KNOCKBACK)
	var blast := Node3D.new()
	blast.set_script(BOELLER_BLAST)
	_player.get_parent().add_child(blast)
	blast.global_position = center
	_player.kick_view(4.0, 2.0)
	triggered.emit(BOELLERSCHUSS, "PERK_MARILLENBRAND_SHOUT")


func _on_enemy_killed(_enemy: Node3D, _is_headshot: bool, _is_melee: bool, source: Node3D) -> void:
	if source != _player or not has_id(KRAEUTER) or herbs_done:
		return
	herbs += 1
	if herbs < Constants.PERK_HERBS:
		return
	# 56 gsunde Kräuter: patched up completely, and stronger for good.
	herbs_done = true
	_health.raise_max(Constants.PERK_HERB_HEALTH)
	_health.heal_full()
	_herb_glow_left = Constants.PERK_HERB_GLOW_TIME
	triggered.emit(KRAEUTER, "PERK_JAGAMOASTA_SHOUT")


func _on_wave_started(wave: int, _is_boss_wave: bool) -> void:
	_wave = wave
	_stur_used = false


func _count_close_enemies() -> int:
	var count: int = 0
	var reach: float = Constants.PERK_GRANT_RADIUS * Constants.PERK_GRANT_RADIUS
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy.is_alive() and enemy.global_position.distance_squared_to(_player.global_position) <= reach:
			count += 1
	return count


func _jause_sum(field: Callable) -> float:
	var total: float = 0.0
	for id: StringName in _jause_levels:
		total += field.call(_jause[id]) * _jause_levels[id]
	return total
