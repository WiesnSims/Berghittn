class_name WeaponBehavior
extends RefCounted
## A special weapon's own shot (section 6a), in place of the hitscan ray. WeaponData.behavior names
## the script in scripts/weapons/behaviors/; each weapon has its own, so a broken one never touches
## the others. The WeaponHolder still owns ammo, cooldown, reloads and recoil; a behavior only decides
## what a shot does.

const DIRECTORY: String = "res://scripts/weapons/behaviors/%s.gd"

var holder: WeaponHolder
var data: WeaponData


## The behavior for a weapon, or null for a plain hitscan gun.
static func create(weapon: WeaponData, owner: WeaponHolder) -> WeaponBehavior:
	if weapon.behavior == &"":
		return null
	var script := load(DIRECTORY % weapon.behavior) as GDScript
	if script == null:
		push_error("No behavior script for %s" % weapon.behavior)
		return null
	var behavior := script.new() as WeaponBehavior
	behavior.holder = owner
	behavior.data = weapon
	return behavior


## Left click: `rounds` went off (already taken from the magazine).
func fire(_rounds: int) -> void:
	pass


## Right click on a BEHAVIOR secondary: data.secondary_rounds went off.
func fire_secondary() -> void:
	pass


## Whether a BEHAVIOR secondary has something to do now; false and the click does nothing (no round,
## no animation, no reload). The Bolingboi's Hoch damit! needs a ball rolling.
func secondary_ready() -> bool:
	return true


## A BEHAVIOR secondary that goes off between shots: it does not wait for the shot's cooldown, and
## leaves none after it (Hoch damit! right after the ball is let go).
func secondary_instant() -> bool:
	return false


## Every frame right click is held on a PLAY secondary (its rounds are paid by the WeaponHolder).
func play_secondary(_delta: float) -> void:
	pass


## Melee weapons (quick melee on V) with a behavior: the blow lands now. True when the behavior dealt
## it itself; false leaves it to the WeaponHolder's plain arc.
func melee_hit() -> bool:
	return false


## V still held after the blow, on a melee weapon whose secondary is BEHAVIOR: true starts the held
## mode (walking slowed, guns down), false lets the weapon drop as usual.
func hold_start() -> bool:
	return false


## Every frame of the held mode; false ends it.
func hold(_delta: float) -> bool:
	return false


## The held mode ends: V let go, or hold() said so.
func hold_end() -> void:
	pass
