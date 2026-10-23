class_name Gredn
extends Node3D
## Talking enemies (M9 part 3): now and then an enemy says a short dialect line as it spots a player,
## groans, starts on a barricade, takes a hard hit, lunges or dies, with its voice (tools/audio/
## voices.py) and the text over its head. One per enemy every GREDN_ENEMY_GAP seconds and one every
## ~3 s overall; only near a player. Main makes one as /root/Main/Gredn.
##
## Solo and the host pick the lines (talk); every screen then shows a line (say) if the chatter
## setting is on and the enemy is within GREDN_REACH of its camera, the nearest GREDN_SHOWN at most.
## In co-op the host sends the line's index (one byte) to the guests with the enemy (CoopEnemies).
## Lines stay in dialect in both languages.

enum Moment { SPOT, IDLE, BARRICADE, HIT, LUNGE, DEATH }

const LINE: Script = preload("res://scripts/effects/gredn_line.gd")

## Every line: the enemy (EnemyData.id), the moment, the text shown, the sound (gredn_*). The index
## is what co-op sends, so new lines go at the end.
const LINES: Array = [
	[&"wanderer", Moment.SPOT, "Griaß di… griaß di…", &"gredn_wanderer_griass_di"],
	[&"wanderer", Moment.IDLE, "Is no weit bis zur Hüttn?", &"gredn_wanderer_huettn"],
	[&"wanderer", Moment.IDLE, "I hob an Hunger…", &"gredn_wanderer_hunger"],
	[&"wanderer", Moment.HIT, "Mei Fuaß…", &"gredn_wanderer_fuass"],
	[&"wanderer", Moment.BARRICADE, "Mach auf, i bin's, da Hüttnwirt!", &"gredn_wanderer_huettnwirt"],
	[&"wanderer", Moment.DEATH, "Servas…", &"gredn_wanderer_servas"],
	[&"tourist", Moment.SPOT, "Nur no a Foto!", &"gredn_tourist_foto"],
	[&"tourist", Moment.IDLE, "Hashtag Gipfelglück!", &"gredn_tourist_gipfelglueck"],
	[&"tourist", Moment.IDLE, "Wo is des WLAN?", &"gredn_tourist_wlan"],
	[&"tourist", Moment.BARRICADE, "Hallo? Is des Zimmer no frei?", &"gredn_tourist_frei"],
	[&"tourist", Moment.HIT, "Aua! Des gibt a schlechte Bewertung!", &"gredn_tourist_bewertung"],
	[&"tourist", Moment.DEATH, "Null Sterne…", &"gredn_tourist_sterne"],
	[&"knappe", Moment.SPOT, "Glück auf!", &"gredn_knappe_glueck_auf"],
	[&"knappe", Moment.IDLE, "Do geht's eini!", &"gredn_knappe_eini"],
	[&"knappe", Moment.BARRICADE, "Des is a weicher Fels.", &"gredn_knappe_fels"],
	[&"knappe", Moment.HIT, "Des kitzlt nur.", &"gredn_knappe_kitzlt"],
	[&"knappe", Moment.DEATH, "Schicht is…", &"gredn_knappe_schicht"],
	[&"perchte", Moment.SPOT, "Hö-hö-hö!", &"gredn_perchte_hoe"],
	[&"perchte", Moment.IDLE, "Hö-hö-hö!", &"gredn_perchte_hoe"],
	[&"perchte", Moment.LUNGE, "Jetzt kimmst!", &"gredn_perchte_kimmst"],
	[&"krampus", Moment.SPOT, "Warst a brav?", &"gredn_krampus_brav"],
	[&"krampus", Moment.IDLE, "In mei Sackl mit dir!", &"gredn_krampus_sackl"],
	[&"krampus", Moment.HIT, "Des wirst ma büßn!", &"gredn_krampus_buessn"],
	[&"krampus", Moment.DEATH, "I kimm wieder… nächsts Joahr!", &"gredn_krampus_joahr"],
]
const CHANCE: Dictionary = {
	Moment.SPOT: Constants.GREDN_CHANCE_SPOT, Moment.IDLE: Constants.GREDN_CHANCE_IDLE,
	Moment.BARRICADE: Constants.GREDN_CHANCE_BARRICADE, Moment.HIT: Constants.GREDN_CHANCE_HIT,
	Moment.LUNGE: Constants.GREDN_CHANCE_LUNGE, Moment.DEATH: Constants.GREDN_CHANCE_DEATH,
}

static var current: Gredn

## Tests: every moment brings a line (the gaps still hold).
var always: bool = false
## The last line shown on this screen (tests), or -1.
var last_heard: int = -1
## Seconds until any enemy may talk again.
var _gap_left: float = 0.0
# The lines showing now: [enemy, label node].
var _shown: Array = []


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## The moment `moment` came for `enemy` (solo, or the host): maybe a line. Returns its index, or -1.
static func moment(enemy: Enemy, which: Moment) -> int:
	if current == null or enemy.puppet:
		return -1
	return current.talk(enemy, which)


## Picks a line for `enemy` at this moment, if it may talk and the dice say so: said here, and the
## enemy's `said` signal takes it to co-op guests. Returns its index, or -1.
func talk(enemy: Enemy, which: Moment) -> int:
	if _gap_left > 0.0 or enemy.talk_left > 0.0 or (not always and randf() >= CHANCE[which]):
		return -1
	var choices: Array[int] = []
	for i: int in LINES.size():
		if LINES[i][0] == enemy.data.id and LINES[i][1] == which:
			choices.append(i)
	if choices.is_empty() or not _player_near(enemy):
		return -1
	var line: int = choices.pick_random()
	_gap_left = randf_range(Constants.GREDN_GAP_MIN, Constants.GREDN_GAP_MAX)
	enemy.talk_left = Constants.GREDN_ENEMY_GAP
	enemy.said.emit(enemy, line)
	say(enemy, line)
	return line


## Line `line` from `enemy` on this screen: its voice and its text over the head, if the chatter is
## on, it is near enough, and not more lines nearer are showing.
func say(enemy: Enemy, line: int) -> void:
	if line < 0 or line >= LINES.size() or not Settings.chatter:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance: float = camera.global_position.distance_to(enemy.global_position)
	if distance > Constants.GREDN_REACH:
		return
	_shown = _shown.filter(func(s: Array) -> bool: return is_instance_valid(s[1]))
	if _shown.size() >= Constants.GREDN_SHOWN:
		# The farthest one showing makes room, if this one is nearer.
		var farthest: Array = _shown[0]
		for s: Array in _shown:
			if _distance(camera, s[0]) > _distance(camera, farthest[0]):
				farthest = s
		if _distance(camera, farthest[0]) <= distance:
			return
		(farthest[1] as Node).queue_free()
		_shown.erase(farthest)
	var sound: StringName = LINES[line][3]
	var stream: AudioStream = Sound.stream(sound)
	var length: float = stream.get_length() if stream else 0.0
	Sound.play_at(sound, enemy.mouth(), Constants.GREDN_VOLUME)
	enemy.speaking(length)
	var label := Node3D.new()
	label.set_script(LINE)
	label.set("text", LINES[line][2])
	label.set("time", maxf(Constants.GREDN_TIME_MIN, length))
	label.set("enemy", enemy)
	add_child(label)
	_shown.append([enemy, label])
	last_heard = line


## How many lines are showing now (tests).
func shown() -> int:
	_shown = _shown.filter(func(s: Array) -> bool: return is_instance_valid(s[1]))
	return _shown.size()


func _physics_process(delta: float) -> void:
	_gap_left -= delta


static func _distance(camera: Camera3D, node: Node3D) -> float:
	return camera.global_position.distance_to(node.global_position) if is_instance_valid(node) else INF


func _player_near(enemy: Enemy) -> bool:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player and player.global_position.distance_to(enemy.global_position) <= Constants.GREDN_REACH:
			return true
	return false
