class_name ChestPool
extends Resource
## What the Hüttentruhe costs, how its roll plays out, and what can come out of it (section 6).

@export var cost: int = 950
## Seconds the weapons cycle with the lid open before one is picked, and how long the pick then
## floats for the buyer to take it.
@export var roll_time: float = 2.5
@export var offer_time: float = 4.0
@export var entries: Array[ChestEntry] = []


## Weighted random pick, skipping guns the buyer already carries; null if nothing is left.
func pick(skip: Callable, rng: RandomNumberGenerator) -> WeaponData:
	var allowed: Array[ChestEntry] = entries.filter(func(e: ChestEntry) -> bool: return e.weight > 0.0 and not skip.call(e.weapon))
	var total: float = 0.0
	for entry: ChestEntry in allowed:
		total += entry.weight
	var roll: float = rng.randf() * total
	for entry: ChestEntry in allowed:
		roll -= entry.weight
		if roll <= 0.0:
			return entry.weapon
	return null
