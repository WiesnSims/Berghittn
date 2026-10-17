extends WeaponBehavior
## Alphorn (section 6): one long low note as a sound wave that fills a cone in front of the player,
## hitting and throwing back everything in it. Right click, the Echo: the bell goes up to the sky and
## the note comes down all around the player, a panic button when they are surrounded.

const WAVE := preload("res://scripts/weapons/behaviors/alphorn_wave.gd")


func fire(_rounds: int) -> void:
	holder.blast(data.area_angle, data.range, data.damage, data.knockback)
	_show_wave(false, data.range)
	holder.shake_view(data.shake)


func fire_secondary() -> void:
	holder.blast(180.0, data.secondary_range, data.secondary_damage, data.secondary_knockback)
	_show_wave(true, data.secondary_range)
	holder.shake_view(data.secondary_shake)


func _show_wave(all_around: bool, reach: float) -> void:
	var wave := Node3D.new()
	wave.set_script(WAVE)
	wave.set("all_around", all_around)
	wave.set("reach", reach)
	wave.set("angle", data.area_angle)
	holder.add_effect(wave)
