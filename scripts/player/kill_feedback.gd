class_name KillFeedback
extends Node
## Hit and kill feedback for this player's own kills (M9 part 2): the kill sound, a little punch
## (the view kicks on a headshot kill, the gun bumps on any kill), damage numbers when the setting
## is on, and the dialect kill streaks with their bonus points:
##   a chain of kills, each within KILL_STREAK_GAP of the last: 3 "Dreierpack!", 5 "Gmetzl!",
##   8 "Bluatbad am Berg!";
##   two or more kills within KILL_MULTI_WINDOW (one shot or blast): "Zwoa auf oan Streich!" and a
##   bonus for each enemy after the first;
##   every third headshot kill in a row: "Schädlweh!".
## Like PlayerPoints it only listens to what its own player did, so in co-op each screen has its own.

## Kill marker for the crosshair.
signal killed(is_headshot: bool)
## A streak was reached: `text` is its translation key, `bonus` the points it paid.
signal streak(text: String, bonus: int)

const DAMAGE_NUMBER: Script = preload("res://scripts/effects/damage_number.gd")
## Chain length -> [banner key, bonus].
const CHAIN_TIERS: Dictionary = {
	3: ["STREAK_DREIERPACK", Constants.STREAK_BONUS_3],
	5: ["STREAK_GMETZL", Constants.STREAK_BONUS_5],
	8: ["STREAK_BLUATBAD", Constants.STREAK_BONUS_8],
}

## Kills in the current chain, and headshot kills in a row.
var chain: int = 0
var headshots_in_row: int = 0
@onready var _player: Player = get_parent() as Player
# Seconds of game time (physics frames), so a test at a fixed frame rate counts like play.
var _clock: float = 0.0
var _last_kill: float = -INF
var _group_start: float = -INF
var _group: int = 0


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.enemy_damaged.connect(_on_enemy_damaged)


func _physics_process(delta: float) -> void:
	_clock += delta


func _on_enemy_damaged(enemy: Node3D, amount: int, is_headshot: bool, source: Node3D) -> void:
	if source == _player:
		_number(enemy, amount, is_headshot, false)


func _on_enemy_killed(enemy: Node3D, is_headshot: bool, _is_melee: bool, source: Node3D) -> void:
	if source != _player:
		return
	var enemy_body := enemy as Enemy
	_number(enemy, enemy_body.last_damage if enemy_body else 0, is_headshot, true)
	var text: String = ""
	var best: int = 0
	var bonus: int = 0
	# The chain.
	if _clock - _last_kill > Constants.KILL_STREAK_GAP:
		chain = 0
	chain += 1
	_last_kill = _clock
	if CHAIN_TIERS.has(chain):
		var tier: Array = CHAIN_TIERS[chain]
		bonus += tier[1]
		if tier[1] > best:
			best = tier[1]
			text = tier[0]
	# More than one with one shot or blast.
	if _clock - _group_start <= Constants.KILL_MULTI_WINDOW:
		_group += 1
		bonus += Constants.STREAK_BONUS_MULTI
		if _group == 2 and Constants.STREAK_BONUS_MULTI > best:
			best = Constants.STREAK_BONUS_MULTI
			text = "STREAK_ZWOA"
	else:
		_group_start = _clock
		_group = 1
	# Headshots in a row.
	headshots_in_row = headshots_in_row + 1 if is_headshot else 0
	if is_headshot and headshots_in_row % Constants.STREAK_HEADSHOTS == 0:
		bonus += Constants.STREAK_BONUS_HEADSHOTS
		if Constants.STREAK_BONUS_HEADSHOTS > best:
			text = "STREAK_SCHAEDLWEH"
	if bonus > 0:
		_player.points.add(bonus)
		if text != "":
			streak.emit(text, bonus)
	_punch(is_headshot)
	killed.emit(is_headshot)


func _punch(is_headshot: bool) -> void:
	if is_headshot:
		# The "Bumm" climbs with the chain.
		var pitch: float = 1.0 + Constants.KILL_PITCH_STEP * mini(chain - 1, Constants.KILL_PITCH_STEPS)
		Sound.play(&"kill_bumm", 0.0, pitch)
		_player.kick_view(Constants.KILL_KICK_PITCH, randf_range(-1.0, 1.0) * Constants.KILL_KICK_YAW)
	else:
		Sound.play(&"kill_thock")
	_player.weapons.bump()


## A number over the enemy that floats up and fades, when the setting is on.
func _number(enemy: Node3D, amount: int, is_headshot: bool, kill: bool) -> void:
	if not Settings.damage_numbers or enemy == null or amount <= 0 or not enemy.is_inside_tree():
		return
	var number := Node3D.new()
	number.set_script(DAMAGE_NUMBER)
	number.set("amount", amount)
	number.set("headshot", is_headshot)
	number.set("kill", kill)
	# Placed before it enters the tree: it starts floating up from there in its _ready.
	var jitter := Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25))
	number.position = enemy.position + Vector3.UP * Constants.DAMAGE_NUMBER_HEIGHT + jitter
	enemy.get_parent().add_child(number)
