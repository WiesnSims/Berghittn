extends WeaponBehavior
## Steirische Harmonika (section 6a): a squeezebox polka. Every enemy within 8 m (walls shield) dances
## on the spot for 4 s: it cannot walk or attack, takes 20 a second, and every other hit on it lands
## twice as hard. Bosses do not dance but take the damage.
## Right click, the Landler (hold): a slow tune played on for as long as it is held, one round every
## 1.5 s; whoever is within reach keeps dancing while it plays (and a second after), but the player
## only walks, and has no hand free to shoot.

const NOTES := preload("res://scripts/weapons/behaviors/harmonika_notes.gd")
# Seconds between looks for dancers while the Landler plays, and between its puffs of notes.
const LANDLER_SCAN: float = 0.1
const LANDLER_NOTES: float = 0.7

var _scan_left: float = 0.0
var _notes_left: float = 0.0


func fire(_rounds: int) -> void:
	holder.dance_around(data.range, Constants.DANCE_TIME, data.damage)
	_show_notes(data.range, 1.0)
	holder.shake_view(data.shake)
	var ahead: Vector3 = -holder.global_basis.z
	holder.show_word(holder.global_position + Vector3(ahead.x, 0.0, ahead.z).normalized() * 2.5, data.hit_text)


func play_secondary(delta: float) -> void:
	_scan_left -= delta
	if _scan_left <= 0.0:
		_scan_left = LANDLER_SCAN
		holder.dance_around(data.secondary_range, Constants.DANCE_LINGER, data.secondary_damage)
	_notes_left -= delta
	if _notes_left <= 0.0:
		_notes_left = LANDLER_NOTES
		_show_notes(data.secondary_range, 0.4)


func _show_notes(reach: float, amount: float) -> void:
	var notes := Node3D.new()
	notes.set_script(NOTES)
	notes.set("reach", reach)
	notes.set("amount", amount)
	holder.add_effect(notes)
