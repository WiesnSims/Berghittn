class_name Hiker
extends Node3D
## A player's body as the others see it (M7): the hiker model dressed by a HikerStyle profile, with
## the name above the head. The lobby stage and the remote players in the match both use it.

const GHOST_WEAPONS := preload("res://scenes/net/ghost_weapons.tscn")
const JACKET_MATERIAL: String = "res://assets/materials/characters/jacket.tres"
const TROUSERS_MATERIAL: String = "res://assets/materials/characters/trousers.tres"
## The neutral cloth texture averages 0.8, so this brings a tint back to its own colour (as in
## CharacterBuilder's shared materials).
const TINT_GAIN: float = 1.25

## Lying on the floor when downed: the model tips forward (rad) and lifts a little off it (m).
const DOWNED_TILT: float = -1.35
const DOWNED_LIFT: float = 0.18

@onready var rig: EnemyRig = $Model
@onready var _tag: Label3D = $NameTag

## Co-op (M7): whose hiker this is, and how they are (Player.Life).
var peer: int = 0
var life: Player.Life = Player.Life.ALIVE
## Co-op host: enemies go for this hiker like for a player (group "player"); a hit is handed on with
## (peer, amount, attacker) to that player's own game.
var on_hurt: Callable
## Co-op match (arm()): their guns as we see them, replaying what they do (a ghost WeaponHolder).
var weapons: WeaponHolder
var _jacket: StandardMaterial3D
var _trousers: StandardMaterial3D
# The gun in their hands (pitched with their aim), and the copies made so far by weapon id.
var _hands: Node3D
var _gun: Node3D
var _guns: Dictionary = {}


func _ready() -> void:
	var body := rig.get_node("Skeleton/Body") as MeshInstance3D
	for i: int in body.mesh.get_surface_count():
		var material := body.mesh.surface_get_material(i)
		if material == null:
			continue
		if material.resource_path == JACKET_MATERIAL:
			_jacket = material.duplicate() as StandardMaterial3D
			body.set_surface_override_material(i, _jacket)
		elif material.resource_path == TROUSERS_MATERIAL:
			_trousers = material.duplicate() as StandardMaterial3D
			body.set_surface_override_material(i, _trousers)


func apply(profile: Dictionary, peer: int) -> void:
	var p: Dictionary = HikerStyle.sanitize(profile)
	for i: int in HikerStyle.HEADS.size():
		(rig.get_node("Skeleton/Head%d" % i) as Node3D).visible = i == p["head"]
	for i: int in range(1, HikerStyle.HATS.size()):
		(rig.get_node("Skeleton/Hat%d" % i) as Node3D).visible = i == p["hat"]
	_jacket.albedo_color = HikerStyle.JACKETS[p["jacket"]] * TINT_GAIN
	_trousers.albedo_color = HikerStyle.TROUSERS[p["trousers"]] * TINT_GAIN
	_jacket.albedo_color.a = 1.0
	_trousers.albedo_color.a = 1.0
	_tag.text = HikerStyle.display_name(p, peer)


## For a co-op match: the ghost of their guns, and hands to hold a copy of the one they carry.
func arm() -> void:
	weapons = GHOST_WEAPONS.instantiate() as WeaponHolder
	add_child(weapons)
	weapons.set_ghost_owner(self)
	_hands = Node3D.new()
	_hands.position = Constants.HIKER_GUN_AT
	rig.add_child(_hands)
	var stance: Dictionary = rig.stance.duplicate()
	stance.merge(Constants.HIKER_HOLD_STANCE, true)
	rig.stance = stance


## The gun now in their hands.
func hold(data: WeaponData) -> void:
	if _hands == null:
		return
	if _gun:
		_gun.visible = false
	_gun = _guns.get(data.id)
	if _gun == null and data.viewmodel:
		_gun = WeaponPickup.model_of(data)
		_gun.scale = Vector3.ONE * Constants.HIKER_GUN_SCALE
		_hands.add_child(_gun)
		_guns[data.id] = _gun
	if _gun:
		_gun.visible = true


## Their look up or down (rad), for the gun in their hands.
func aim(pitch: float) -> void:
	if _hands:
		_hands.rotation.x = pitch


## A melee blow: the swing, both arms over the head and down.
func swing(length: float) -> void:
	rig.play(EnemyRig.Action.STRIKE, length)


func show_name(on: bool) -> void:
	_tag.visible = on


func is_targetable() -> bool:
	return life == Player.Life.ALIVE and visible


func take_damage(amount: int, attacker: Node3D = null) -> void:
	if on_hurt.is_valid():
		on_hurt.call(peer, amount, attacker)


## Downed: lying on the floor; out (bled out): gone until the next wave.
func set_life(new_life: Player.Life) -> void:
	life = new_life
	visible = life != Player.Life.OUT
	var down: bool = life == Player.Life.DOWNED
	rig.rotation.x = DOWNED_TILT if down else 0.0
	rig.position.y = DOWNED_LIFT if down else 0.0
