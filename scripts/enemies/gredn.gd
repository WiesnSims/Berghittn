class_name Gredn
extends Node3D
## Talking enemies (M9 part 3): now and then an enemy says a short dialect line as it spots a player,
## groans, starts on a barricade, takes a hard hit, lunges or dies, with its voice (tools/audio/
## voices.py) and the text over its head. One per enemy every GREDN_ENEMY_GAP seconds and one every
## GREDN_GAP_MIN..MAX overall; only near a player. Main makes one as /root/Main/Gredn.
##
## Solo and the host pick the lines (talk); every screen then shows a line (say) if the chatter
## setting is on and the enemy is within GREDN_REACH of its camera, the nearest GREDN_SHOWN at most.
## In co-op the host sends the line's index (one byte) to the guests with the enemy (CoopEnemies).
## Lines stay in dialect in both languages.
##
## The Venedigermandl (M9 part 5a, EnemyData.treasure) has only seconds: he always talks when his
## moment comes (no dice, no gap between enemies), every MANDL_TALK_GAP at most (his last words and
## his goodbye even sooner), and is heard from MANDL_VOICE_REACH.

## APPEAR, RUN and VANISH are the Venedigermandl's: as he turns up, as he runs, as he vanishes.
## AIM and SHOT are the Wilderer's: as he starts to aim, and when his shot hits.
## SITZ is Sitzfleisch (1.1.2): the nearest enemy mocks a player who stays put too long (taunt).
## HAT is Huat obschiaßn: its hat was shot off (always said, and heard from GREDN_HAT_REACH).
enum Moment { SPOT, IDLE, BARRICADE, HIT, LUNGE, DEATH, APPEAR, RUN, VANISH, AIM, SHOT, SITZ, HAT }

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
	[&"tourist", Moment.DEATH, "Tschüss!", &"gredn_tourist_tschuess"],
	[&"knappe", Moment.SPOT, "Glück auf!", &"gredn_knappe_glueck_auf"],
	[&"knappe", Moment.IDLE, "Do geht's eini!", &"gredn_knappe_eini"],
	[&"knappe", Moment.BARRICADE, "Des is a weicher Fels.", &"gredn_knappe_fels"],
	[&"knappe", Moment.HIT, "Geh bitte…", &"gredn_knappe_geh_bitte"],
	[&"knappe", Moment.DEATH, "Schicht is…", &"gredn_knappe_schicht"],
	[&"perchte", Moment.SPOT, "Hö-hö-hö!", &"gredn_perchte_hoe"],
	[&"perchte", Moment.IDLE, "Hö-hö-hö!", &"gredn_perchte_hoe"],
	[&"perchte", Moment.LUNGE, "Jetzt kimmst!", &"gredn_perchte_kimmst"],
	[&"krampus", Moment.SPOT, "Warst a brav?", &"gredn_krampus_brav"],
	[&"krampus", Moment.IDLE, "In mei Sackl mit dir!", &"gredn_krampus_sackl"],
	[&"krampus", Moment.HIT, "Des wirst ma büßn!", &"gredn_krampus_buessn"],
	[&"krampus", Moment.DEATH, "I kimm wieder… nächsts Joahr!", &"gredn_krampus_joahr"],
	[&"venedigermandl", Moment.APPEAR, "Do glanzt wos!", &"gredn_venedigermandl_glanzt"],
	[&"venedigermandl", Moment.RUN, "Des Gold g'hert mir!", &"gredn_venedigermandl_gold"],
	[&"venedigermandl", Moment.RUN, "Mamma mia!", &"gredn_venedigermandl_mamma"],
	[&"venedigermandl", Moment.RUN, "Ciao, Bergsteiger!", &"gredn_venedigermandl_ciao"],
	[&"venedigermandl", Moment.HIT, "Au, mei Gold!", &"gredn_venedigermandl_au"],
	[&"venedigermandl", Moment.VANISH, "Arrivederci!", &"gredn_venedigermandl_arrivederci"],
	[&"venedigermandl", Moment.DEATH, "Porca miseria…", &"gredn_venedigermandl_porca"],
	[&"wilderer", Moment.SPOT, "Des is mei Revier!", &"gredn_wilderer_revier"],
	[&"wilderer", Moment.IDLE, "Des is mei Revier!", &"gredn_wilderer_revier"],
	[&"wilderer", Moment.AIM, "Hob di!", &"gredn_wilderer_hob_di"],
	[&"wilderer", Moment.SHOT, "Waidmannsheil!", &"gredn_wilderer_waidmannsheil"],
	[&"wilderer", Moment.DEATH, "Waidmannsdank…", &"gredn_wilderer_waidmannsdank"],
	[&"wanderer", Moment.SITZ, "Wurzln schlagst do, oder wos?", &"gredn_wanderer_sitz"],
	[&"tourist", Moment.SITZ, "Bist do festgwachsn?", &"gredn_tourist_sitz"],
	[&"knappe", Moment.SITZ, "Do hockt oana wia a Schwammerl.", &"gredn_knappe_sitz"],
	[&"perchte", Moment.SITZ, "Hockn bleibn? Hö-hö-hö!", &"gredn_perchte_sitz"],
	[&"krampus", Moment.SITZ, "Wer hockt, den hol i!", &"gredn_krampus_sitz"],
	[&"wilderer", Moment.SITZ, "Do hockt mei Wild.", &"gredn_wilderer_sitz"],
	[&"wanderer", Moment.HAT, "Mei Huat!", &"gredn_wanderer_huat"],
	[&"wanderer", Moment.HAT, "Der Huat woa vom Opa!", &"gredn_wanderer_opa"],
	[&"tourist", Moment.HAT, "Mei Sonnenhuat!", &"gredn_tourist_sonnenhuat"],
	[&"knappe", Moment.HAT, "Mei Helm! Wo is mei Helm?", &"gredn_knappe_helm"],
	[&"wilderer", Moment.HAT, "Mei Gamsbart!", &"gredn_wilderer_gamsbart"],
	[&"venedigermandl", Moment.HAT, "Il mio cappello!", &"gredn_venedigermandl_cappello"],
]
const CHANCE: Dictionary = {
	Moment.SPOT: Constants.GREDN_CHANCE_SPOT, Moment.IDLE: Constants.GREDN_CHANCE_IDLE,
	Moment.BARRICADE: Constants.GREDN_CHANCE_BARRICADE, Moment.HIT: Constants.GREDN_CHANCE_HIT,
	Moment.LUNGE: Constants.GREDN_CHANCE_LUNGE, Moment.DEATH: Constants.GREDN_CHANCE_DEATH,
	Moment.APPEAR: 1.0, Moment.RUN: 1.0, Moment.VANISH: 1.0,
	Moment.AIM: Constants.GREDN_CHANCE_AIM, Moment.SHOT: Constants.GREDN_CHANCE_SHOT, Moment.SITZ: 1.0,
	Moment.HAT: 1.0,
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
	var treasure: bool = enemy.data.treasure
	if treasure:
		if enemy.talk_left > 0.0 and which != Moment.DEATH and which != Moment.VANISH:
			return -1
	elif _gap_left > 0.0 or enemy.talk_left > 0.0 or (not always and randf() >= CHANCE[which]):
		return -1
	var choices: Array[int] = []
	for i: int in LINES.size():
		if LINES[i][0] == enemy.data.id and LINES[i][1] == which:
			choices.append(i)
	if choices.is_empty() or not _player_near(enemy):
		return -1
	var line: int = choices.pick_random()
	if treasure:
		enemy.talk_left = Constants.MANDL_TALK_GAP
	else:
		_gap_left = randf_range(Constants.GREDN_GAP_MIN, Constants.GREDN_GAP_MAX)
		enemy.talk_left = Constants.GREDN_ENEMY_GAP
	enemy.said.emit(enemy, line)
	say(enemy, line)
	return line


## Huat obschiaßn: `enemy` (solo, or the host's) lost its hat and says so. Returns the line's index,
## or -1.
static func hat(enemy: Enemy) -> int:
	if current == null or enemy.puppet:
		return -1
	return current.blurt(enemy, Moment.HAT)


## Sitzfleisch: `enemy` mocks a player who stays put (solo, or the host). Returns the line's index,
## or -1 if it has no such line.
func taunt(enemy: Enemy) -> int:
	return blurt(enemy, Moment.SITZ)


## A line for `enemy` at `which`, whatever the dice and the gaps say (solo, or the host). Returns
## its index, or -1 if it has no such line.
func blurt(enemy: Enemy, which: Moment) -> int:
	if enemy.puppet:
		return -1
	var choices: Array[int] = []
	for i: int in LINES.size():
		if LINES[i][0] == enemy.data.id and LINES[i][1] == which:
			choices.append(i)
	if choices.is_empty():
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
	if distance > _reach(enemy, line):
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


# Untyped: the enemy may have been freed meanwhile (a typed argument would fail on it).
static func _distance(camera: Camera3D, node: Variant) -> float:
	return camera.global_position.distance_to((node as Node3D).global_position) if is_instance_valid(node) else INF


static func _reach(enemy: Enemy, line: int = -1) -> float:
	if line >= 0 and LINES[line][1] == Moment.HAT:
		return Constants.GREDN_HAT_REACH
	return Constants.MANDL_VOICE_REACH if enemy.data.treasure else Constants.GREDN_REACH


func _player_near(enemy: Enemy) -> bool:
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player and player.global_position.distance_to(enemy.global_position) <= _reach(enemy):
			return true
	return false
