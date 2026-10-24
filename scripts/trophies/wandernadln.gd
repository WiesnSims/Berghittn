class_name Wandernadln
extends Node
## Die Wandernadln (1.2, GAME_DESIGN section 12): six badges, each in Bronze, Silber and Gold, like
## the real hiking badges; and what the Steckbriefe show: the enemies met in our matches and our
## kills of each. Kept in Settings, this browser's player only (in co-op each screen counts what its
## own Player did: every screen sees every kill and hat with its source). Main makes one.

const BADGES: Array[StringName] = [&"gipfel", &"bsundan", &"huat", &"scharf", &"krampus", &"seilschaft"]
## Per badge, what Bronze, Silber and Gold take (compared with value()).
const GOALS: Dictionary = {
	&"gipfel": [10, 20, 30], &"bsundan": [1, 6, 50], &"huat": [25, 250, 1],
	&"scharf": [100, 1000, 5000], &"krampus": [1, 10, 50], &"seilschaft": [5, 10, 20],
}
const TIERS: Array[String] = ["", "UI_NADL_BRONZE", "UI_NADL_SILBER", "UI_NADL_GOLD"]
const TIER_COLORS: Array[Color] = [Color(0.3, 0.28, 0.26), Color(0.8, 0.5, 0.25), Color(0.82, 0.84, 0.88), Color(1.0, 0.8, 0.3)]
## The Bsundan (Die Bsundan, 1.2).
const VARIANTS: Array[String] = ["kassier", "bergfuehrer", "trailrunner", "influencer", "sprengmeister", "schoenperchte"]

## The wave this match reached (Gipfelstürmer: the personal best is only kept as a run ends).
static var match_wave: int = 0


func _ready() -> void:
	match_wave = 0
	Events.enemy_appeared.connect(_on_appeared)
	Events.enemy_killed.connect(_on_killed)
	Events.hat_shot.connect(_on_hat_shot)
	Events.wave_started.connect(_on_wave_started)
	Events.wave_cleared.connect(func(_wave_done: int) -> void: Settings.save())
	Events.player_died.connect(func(_player: Node3D) -> void: Settings.save())
	var rack := get_tree().get_first_node_in_group("hat_rack") as HatRack
	if rack:
		rack.filled.connect(func() -> void: earn(&"huat", 3))
	# Badges already deserved by what was saved before (no banner outside a match).
	check(false)


## The tier `badge` has here (0 none, 1 Bronze, 2 Silber, 3 Gold).
static func tier(badge: StringName) -> int:
	return clampi(int(Settings.badges.get(String(badge), 0)), 0, 3)


## How many of the 18 are earned.
static func earned() -> int:
	var count: int = 0
	for badge: StringName in BADGES:
		count += tier(badge)
	return count


static func goal(badge: StringName, which: int) -> int:
	return GOALS[badge][which - 1]


## How far this browser's player is towards `badge`'s tier `which` (compared with goal()).
static func value(badge: StringName, which: int) -> int:
	match badge:
		&"gipfel":
			return maxi(Settings.best_wave, match_wave)
		&"bsundan":
			return kinds_killed() if which == 2 else bsundan_killed()
		&"huat":
			# Gold is a full Huatständer in one match: earned there, never counted.
			return Settings.hats if which < 3 else (1 if tier(badge) >= 3 else 0)
		&"scharf":
			return Settings.headshots
		&"krampus":
			return kills_of("krampus")
		&"seilschaft":
			return Settings.coop_best
	return 0


static func kills_of(id: String) -> int:
	return int(Settings.kills.get(id, 0))


static func bsundan_killed() -> int:
	var count: int = 0
	for id: String in VARIANTS:
		count += kills_of(id)
	return count


static func kinds_killed() -> int:
	return VARIANTS.filter(func(id: String) -> bool: return kills_of(id) > 0).size()


## Gives every tier that is deserved now; `loud`: a banner and the chime for each.
func check(loud: bool = true) -> void:
	for badge: StringName in BADGES:
		var next: int = tier(badge) + 1
		while next <= 3 and not (badge == &"huat" and next == 3) and value(badge, next) >= goal(badge, next):
			earn(badge, next, loud)
			next += 1


## `badge` reaches tier `which` (a lower one never replaces a higher).
func earn(badge: StringName, which: int, loud: bool = true) -> void:
	if tier(badge) >= which:
		return
	Settings.badges[String(badge)] = which
	Settings.save()
	if loud:
		Events.event_announced.emit(tr("UI_NADL_EARNED") % [tr(TIERS[which]), tr("UI_NADL_" + String(badge).to_upper())])
		Sound.play(&"nadl")


func _on_appeared(enemy: Node3D) -> void:
	var id: String = String((enemy as Enemy).data.id) if enemy is Enemy else ""
	if id != "" and not id in Settings.met:
		Settings.met.append(id)
		Settings.save()


func _on_killed(enemy: Node3D, is_headshot: bool, _is_melee: bool, source: Node3D) -> void:
	# Only our own Player's kills (in co-op a hiker is someone else).
	if not source is Player or not enemy is Enemy:
		return
	var id: String = String((enemy as Enemy).data.id)
	Settings.kills[id] = kills_of(id) + 1
	if is_headshot:
		Settings.headshots += 1
	check()


func _on_hat_shot(_enemy: Node3D, source: Node3D) -> void:
	if source is Player:
		Settings.hats += 1
		check()


func _on_wave_started(wave: int, _boss: bool) -> void:
	match_wave = wave
	if Net.in_match():
		Settings.coop_best = maxi(Settings.coop_best, wave)
	check()
	Settings.save()
