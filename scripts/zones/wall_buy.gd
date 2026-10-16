class_name WallBuy
extends Node3D
## Chalk outline of a gun on the wall (section 6): buy the gun, or once carried, refill its ammo for
## ammo_cost (half the gun's price). Sits on the wall surface, centred on the outline, with -Z
## pointing into the room.

@export var weapon: WeaponData

## Bought with one press, not held.
var interact_repeat: float = 0.0


func _ready() -> void:
	add_to_group("interactables")


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(Constants.WALL_BUY_SPOT)


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	var gun_name: String = tr(weapon.display_name)
	if not buyer.weapons.has_weapon(weapon):
		var key: String = "UI_BUY_WEAPON" if buyer.points.can_afford(weapon.cost) else "UI_BUY_NEED"
		return tr(key) % [gun_name, weapon.cost]
	if not buyer.weapons.needs_ammo(weapon):
		return ""
	var ammo_key: String = "UI_BUY_AMMO" if buyer.points.can_afford(weapon.ammo_cost) else "UI_BUY_AMMO_NEED"
	return tr(ammo_key) % [gun_name, weapon.ammo_cost]


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if not buyer.weapons.has_weapon(weapon):
		if buyer.points.spend(weapon.cost):
			buyer.weapons.give_weapon(weapon)
	elif buyer.weapons.needs_ammo(weapon) and buyer.points.spend(weapon.ammo_cost):
		buyer.weapons.refill_ammo(weapon)
