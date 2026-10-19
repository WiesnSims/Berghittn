class_name HatUnlocks
extends Node
## Earned hats (M8, user request 2026-10-19): the Raurakl-Kappl for finding the Raurakl in the Stube
## and shooting it, the Perchtn-Haubn once Constants.UNLOCK_PERCHTEN Perchten have fallen in our
## matches (all together), the Krampus-Hörndl for surviving wave Constants.UNLOCK_WAVE. Kept in
## Settings, in this browser only (accounts are out of scope). In co-op each player earns their own:
## every screen sees every kill and every cleared wave (CoopEnemies, CoopWorld).


func _ready() -> void:
	Events.enemy_killed.connect(_on_killed)
	Events.wave_cleared.connect(_on_cleared)


## Can this browser's player wear `hat`?
static func has_hat(hat: int) -> bool:
	return not HikerStyle.LOCKED.has(hat) or String(HikerStyle.LOCKED[hat]) in Settings.unlocks


## What is still to do for `hat`, "" when it can be worn.
static func hint(hat: int) -> String:
	if has_hat(hat):
		return ""
	match HikerStyle.LOCKED[hat]:
		&"raurakl":
			return TranslationServer.translate("UI_UNLOCK_RAURAKL")
		&"perchten":
			return TranslationServer.translate("UI_UNLOCK_PERCHTEN") % [mini(Settings.perchten, Constants.UNLOCK_PERCHTEN), Constants.UNLOCK_PERCHTEN]
		&"krampus":
			return TranslationServer.translate("UI_UNLOCK_KRAMPUS") % Constants.UNLOCK_WAVE
	return ""


static func earn(id: StringName) -> void:
	if String(id) in Settings.unlocks:
		return
	Settings.unlocks.append(String(id))
	Settings.save()
	var hat: int = HikerStyle.LOCKED.find_key(id)
	Events.event_announced.emit(TranslationServer.translate("UI_HAT_UNLOCKED") % TranslationServer.translate(HikerStyle.HATS[hat]))


func _on_killed(enemy: Node3D, _is_headshot: bool, _is_melee: bool, _source: Node3D) -> void:
	var killed := enemy as Enemy
	if killed == null or killed.data.id != &"perchte":
		return
	Settings.perchten += 1
	if Settings.perchten >= Constants.UNLOCK_PERCHTEN:
		earn(&"perchten")
	else:
		Settings.save()


func _on_cleared(wave: int) -> void:
	if wave >= Constants.UNLOCK_WAVE:
		earn(&"krampus")
