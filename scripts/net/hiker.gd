class_name Hiker
extends Node3D
## A player's body as the others see it (M7): the hiker model dressed by a HikerStyle profile, with
## the name above the head. The lobby stage and the remote players in the match both use it.

const JACKET_MATERIAL: String = "res://assets/materials/characters/jacket.tres"
const TROUSERS_MATERIAL: String = "res://assets/materials/characters/trousers.tres"
## The neutral cloth texture averages 0.8, so this brings a tint back to its own colour (as in
## CharacterBuilder's shared materials).
const TINT_GAIN: float = 1.25

@onready var rig: EnemyRig = $Model
@onready var _tag: Label3D = $NameTag

var _jacket: StandardMaterial3D
var _trousers: StandardMaterial3D


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


func show_name(on: bool) -> void:
	_tag.visible = on
