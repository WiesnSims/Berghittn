class_name PerkData
extends Resource
## One Schnaps from the shrine (section 9). Bought once per life; lost when downed. Each one has a
## signature effect you notice in a fight (play-test, 2026-10-17); its numbers are in constants.gd
## (PERK_*), the code is in PlayerPerks. Plain stat gains come from the Brettljause (JauseData).

@export var id: StringName
## Translation keys: the Schnaps (stays dialect), the perk it gives, and what that does.
@export var display_name: String
@export var title: String
@export var description: String
@export var cost: int = 1000
## Bottle and HUD icon colour, and the short text on the HUD tile.
@export var color: Color = Color.WHITE
@export var badge: String = ""
