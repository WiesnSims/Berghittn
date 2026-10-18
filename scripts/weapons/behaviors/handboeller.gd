extends WeaponBehavior
## Handböller (section 6a): a Schützen hand mortar. One loud shot lobs an iron shell that bursts like a
## Böller where it lands, then the long reload of powder, ball and ramrod. Right click, the
## Doppelladung: a second measure of powder poured in (the loaded round plus one from the reserve),
## so the shell flies faster and flatter, bursts bigger, and the kick shoves the shooter back.

const SHELL := preload("res://scripts/weapons/behaviors/handboeller_shell.gd")
const BLAST := preload("res://scripts/perks/boeller_blast.gd")
const POOL: int = 4

var _shells: Array[Node3D] = []
var _next: int = 0
# Which charge the shell in the air was fired with: the burst's push follows it.
var _push: float = 0.0


func fire(_rounds: int) -> void:
	_push = data.knockback
	_launch(data.projectile_speed, data.damage, data.area_radius)
	holder.shake_view(data.shake)


func fire_secondary() -> void:
	_push = data.secondary_knockback
	_launch(data.projectile_speed * Constants.HANDBOELLER_DOUBLE_SPEED, data.secondary_damage, data.secondary_range)
	holder.shake_view(data.secondary_shake)
	var player := holder.shooter() as Player
	if player:
		var back: Vector3 = holder.global_basis.z
		player.push(Vector3(back.x, 0.0, back.z).normalized() * Constants.HANDBOELLER_DOUBLE_SHOVE)


func _launch(speed: float, damage: int, radius: float) -> void:
	var shell: Node3D = _free_shell()
	var direction: Vector3 = -holder.global_basis.z
	var start: Vector3 = holder.global_position + direction * 0.7 + holder.global_basis.y * -0.15
	shell.call("launch", self, start, direction * speed, damage, radius, 1.0)


## Called by a shell where it bursts.
func burst(at: Vector3, damage: int, radius: float, _size: float) -> void:
	holder.area_hit(at + Vector3.UP * 0.5, Vector3.FORWARD, 180.0, radius, damage, _push)
	Sound.play_at(data.hit_sound, at)
	var blast := Node3D.new()
	blast.set_script(BLAST)
	blast.set("radius", radius)
	holder.world_root().add_child(blast)
	blast.global_position = at


func _free_shell() -> Node3D:
	for shell: Node3D in _shells:
		if not shell.call("is_busy"):
			return shell
	if _shells.size() < POOL:
		var shell := Node3D.new()
		shell.set_script(SHELL)
		holder.world_root().add_child(shell)
		_shells.append(shell)
		return shell
	_next = (_next + 1) % POOL
	return _shells[_next]
