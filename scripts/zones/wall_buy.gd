class_name WallBuy
extends Node3D
## Chalk outline of a gun on the wall (section 6): buy the gun, or once carried, refill its ammo for
## ammo_cost (half the gun's price). Or of a piece of equipment (section 6a): buy the slot full of it.
## Sits on the wall surface, centred on the outline, with -Z pointing into the room.

@export var weapon: WeaponData
## Set instead of weapon for an equipment wall-buy.
@export var equipment: EquipmentData
## Hidden until this wave starts (the Alphorn in the Seilbahn, from a later wave), then announced
## with arrival_text (translation key). 0 = there from the start.
@export var from_wave: int = 0
@export var arrival_text: String = ""

## Bought with one press, not held.
var interact_repeat: float = 0.0


func _ready() -> void:
	if from_wave > 0:
		visible = false
		Events.wave_started.connect(_on_wave_started)
		return
	add_to_group("interactables")


func _on_wave_started(wave: int, _is_boss_wave: bool) -> void:
	if wave < from_wave or visible:
		return
	visible = true
	add_to_group("interactables")
	if arrival_text != "":
		Events.event_announced.emit(tr(arrival_text))


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return to_global(Constants.WALL_BUY_SPOT)


func get_interact_prompt(player: Node3D) -> String:
	var buyer := player as Player
	if equipment:
		return _equipment_prompt(buyer)
	var gun_name: String = tr(weapon.display_name)
	if not buyer.weapons.has_weapon(weapon):
		var key: String = "UI_BUY_WEAPON" if buyer.points.can_afford(weapon.cost) else "UI_BUY_NEED"
		return tr(key) % [gun_name, weapon.cost]
	if not buyer.weapons.needs_ammo(weapon):
		return ""
	var price: int = _ammo_price(buyer)
	var ammo_key: String = "UI_BUY_AMMO" if buyer.points.can_afford(price) else "UI_BUY_AMMO_NEED"
	return tr(ammo_key) % [gun_name, price]


## Half the gun's price, and more for a forged one (WeaponHolder.ammo_extra, balance 1.1.2).
func _ammo_price(buyer: Player) -> int:
	return weapon.ammo_cost + buyer.weapons.ammo_extra(weapon)


func interact(player: Node3D) -> void:
	var buyer := player as Player
	if equipment:
		if _equipment_short(buyer) > 0 and buyer.points.spend(equipment.cost):
			buyer.equipment.give(equipment, equipment.max_carry)
		return
	if not buyer.weapons.has_weapon(weapon):
		if buyer.points.spend(weapon.cost):
			buyer.weapons.give_weapon(weapon)
	elif buyer.weapons.needs_ammo(weapon) and buyer.points.spend(_ammo_price(buyer)):
		buyer.weapons.refill_ammo(weapon)


# How many the slot is short of full of this kind (all of them when it holds something else).
func _equipment_short(buyer: Player) -> int:
	if buyer.equipment.item != equipment:
		return equipment.max_carry
	return equipment.max_carry - buyer.equipment.count


func _equipment_prompt(buyer: Player) -> String:
	if _equipment_short(buyer) <= 0:
		return ""
	var item_name: String = tr(equipment.display_name)
	if not buyer.points.can_afford(equipment.cost):
		return tr("UI_BUY_NEED") % [item_name, equipment.cost]
	var held: EquipmentData = buyer.equipment.item
	# The slot holds one kind: say what would be given up (an Eisstock is not to be lost by accident).
	if held and held != equipment and buyer.equipment.count > 0:
		return tr("UI_BUY_EQUIP_SWAP") % [item_name, equipment.cost, tr(held.display_name)]
	return tr("UI_BUY_WEAPON") % [item_name, equipment.cost]
