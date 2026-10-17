class_name EquipmentData
extends Resource
## A thing for the equipment slot (section 6a): stackable, thrown or placed with the throw key (G or the
## middle mouse button). The slot holds one kind at a time.

@export var id: StringName
## Translation key; the name stays dialect.
@export var display_name: String
@export var max_carry: int = 2
## What leaves the hand: a scene whose root has launch(from, direction, thrower).
@export var projectile: PackedScene
## Seconds before the next one can go.
@export var cooldown: float = 0.6
