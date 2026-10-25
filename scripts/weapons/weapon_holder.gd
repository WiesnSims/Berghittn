class_name WeaponHolder
extends Node3D
## Holds the guns (two slots, section 6: firing, hitscan, ammo, reload, switching) and the melee weapon
## for quick melee on V. Sits under the camera so shots follow the view.

signal ammo_changed(mag: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
## A shot went off; `rounds` > 1 when several went at once (both barrels).
signal fired(rounds: int)
## The gun in hand changed (switch, buy, replace).
signal weapon_changed(data: WeaponData)
## The melee weapon on V changed (a melee wall-buy or the Hüttentruhe). It is never in hand, so the HUD
## has to say so (play-test #65: a Goaßl from the chest seemed to vanish).
signal melee_changed(data: WeaponData)
## The Kraxn was strapped on: one gun slot more (#95).
signal slots_changed(count: int)
## Emitted when a shot hit an enemy, for the hit marker.
signal hit_confirmed(is_headshot: bool, killed: bool)
## A doppelt dengelt weapon in hand made a kill: `left` kills of its edge remain, of STUMPF_KILLS
## (`melee` for the melee weapon). Stumpf, 1.1.2.
signal edge_changed(left: int, melee: bool)
## A doppelt dengelt weapon went dull: `was` is dengelt again now, `now`.
signal went_dull(was: WeaponData, now: WeaponData)
## Co-op (M7): something the others should see (a shot, a swing, a held mode), for CoopPlayers to
## pass on; their copy of these guns replays it (ghost).
signal acted(action: Act, rounds: int)

## What `acted` reports: a left-click shot, a right-click special, a melee swing starting, its blow
## landing, and V held past the blow (guard or held mode) and let go.
enum Act { SHOT, SECONDARY, SWING, MELEE, HOLD, RELEASE }

# The Querschläger's streak from hop to hop.
const RICOCHET_TRAIL: Script = preload("res://scripts/effects/ricochet_trail.gd")

## One carried gun and the ammo it had when it was put away.
class GunSlot:
	var data: WeaponData
	var mag: int
	var reserve: int
	var viewmodel: Viewmodel
	## What a shot does for a special weapon (section 6a); null for plain hitscan.
	var behavior: WeaponBehavior
	## Kills left before a doppelt dengelt gun goes dull (Stumpf); 0 for the others.
	var edge: int = 0

@export var starting_weapon: WeaponData
## Always carried (section 6: the shovel until the melee slot gets replaced).
@export var melee_weapon: WeaponData
## Co-op (M7): another player's guns as this browser shows them, on their hiker: their actions are
## replayed (replay()) for the look and the sound only. Nothing is hit here; their own game does that.
@export var ghost: bool = false
## Co-op (M7): downed, only the pistol is in hand; no switching, no melee (set_downed).
var downed: bool = false
## Gun slots: GUN_SLOTS, one more with die Kraxn on the back (#95). Kept for the whole match, going
## down or bleeding out included.
var slots: int = Constants.GUN_SLOTS
var _starting_melee: WeaponData
var _before_down: int = -1
var _borrowed: bool = false
var _was_captured: bool = false
# Seconds after taking the mouse in which clicks do not fire: a quick click can press and release
# within one frame, so "locked while held" alone lets it through.
var _capture_grace: float = 0.0

@onready var _impact_marks: ImpactMarks = $ImpactMarks
@onready var _impact_puffs: EffectPool = $ImpactPuffs
@onready var _hit_puffs: EffectPool = $HitPuffs
# Every viewmodel hangs under this, so walking, sprinting and looking move them all.
@onready var _motion: Node3D = $Motion

## The gun in hand and its ammo; written back to its slot when it is put away.
var weapon: WeaponData
## Extra spread (degrees) from shots fired in quick succession; see WeaponData bloom_*.
var bloom: float = 0.0
## 0 = hip fire, 1 = fully aimed (down the sights or through the scope).
var aim_amount: float = 0.0
## Holds right click without a mouse, for tests and capture tools.
var force_aim: bool = false
var mag: int = 0
var reserve: int = 0
var _slots: Array[GunSlot] = []
var _current: int = -1
var _cooldown: float = 0.0
# How long the current cooldown and reload are in all, for the ready ring at the crosshair.
var _cooldown_total: float = 0.0
# The ready ring shows the current cycle (set by the shot that started it).
var _ring_cycle: bool = false
var _reload_total: float = 0.0
# A click that came in while the gun was still cycling; it fires as soon as it can, so fast clicking
# is never swallowed.
var _fire_buffer_left: float = 0.0
# After a reload, a trigger still held from before does not fire until it is let go: only a new
# pull once the gun is ready shoots (play-test 2026-10-18).
var _fire_locked: bool = false
var _reload_left: float = 0.0
# What the running reload fills the gun to.
var _reload_target: int = 0
# Loading round by round (reload_round_time): rounds to load, rounds in so far, seconds until the
# gun is up to load and per round (after perks).
var _reload_rounds: int = 0
var _reload_loaded: int = 0
var _reload_lift: float = 0.0
var _reload_per_round: float = 0.0
var _switch_left: float = 0.0
# Seconds until the gun is back up after a sprint and may fire.
var _sprint_left: float = 0.0
var _aiming: bool = false
# Playing the held secondary (PLAY) this frame, and seconds left of the round it is on.
var _playing: bool = false
var _play_left: float = 0.0
var _viewmodel: Viewmodel
var _behavior: WeaponBehavior
var _melee_viewmodel: MeleeViewmodel
# The melee weapon's own blow and held mode (section 6a's Goaßl, Mistgabel, Krampus-Rute), or null.
var _melee_behavior: WeaponBehavior
# Seconds left of the current swing, and until its blow lands (negative once it has).
var _melee_left: float = 0.0
# Holding the melee weapon up as a guard (BLOCK secondary), and a hold of V without a keyboard for tests.
var _blocking: bool = false
var force_melee_hold: bool = false
var _melee_hit_in: float = -1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# The shooter's own body, so rays never hit it, and who gets the points.
var _exclude: Array[RID] = []
var _shooter: Node3D
# The looping sound of held fire (the flame) or of a held tune, and seconds the flame's loop runs on
# waiting for the next shot.
var _loop_sound: AudioStreamPlayer
var _fire_loop_left: float = 0.0
# A ghost's behaviors by weapon id (each keeps its own pools of shells and puddles), its held-fire
# sound and flame, and its muzzle flash.
var _ghost_behaviors: Dictionary = {}
var _ghost_loop: AudioStreamPlayer3D
var _ghost_flame: CPUParticles3D
var _ghost_flash: OmniLight3D
# Seconds the hands hold only the melee weapon after a gun went to the Dengelstock (M9 part 4).
var _hands_free_left: float = 0.0
# Aiming by toggle (Settings.toggle_aim): a right click puts the sights up, the next one down.
var _aim_toggled: bool = false
# Stumpf: kills left of the doppelt dengelt melee weapon's edge, and the families that went dull and
# have not been sharpened again since (cheaper at the Dengelstock).
var _melee_edge: int = 0
var _dulled: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	if ghost:
		return
	Events.enemy_killed.connect(_on_enemy_killed)
	_starting_melee = melee_weapon
	if starting_weapon:
		give_weapon(starting_weapon)
		# Already in hand at the start, not drawn.
		_switch_left = 0.0
	if melee_weapon and melee_weapon.viewmodel:
		_melee_viewmodel = melee_weapon.viewmodel.instantiate() as MeleeViewmodel
		_motion.add_child(_melee_viewmodel)
	if melee_weapon:
		_melee_behavior = WeaponBehavior.create(melee_weapon, self)
	_loop_sound = AudioStreamPlayer.new()
	_loop_sound.bus = &"Effects"
	add_child(_loop_sound)
	hit_confirmed.connect(_on_hit_confirmed)


func set_owner_body(body: CollisionObject3D) -> void:
	_exclude = [body.get_rid()]
	_shooter = body


## A ghost's owner: the hiker its shots come from.
func set_ghost_owner(body: Node3D) -> void:
	_exclude = []
	_shooter = body


## A kill of ours (KillFeedback): the gun in hand jolts a little.
func bump() -> void:
	(_motion as WeaponMotion).bump(Constants.KILL_BUMP)


## Puts a gun in hand: into a free slot if there is one, otherwise in place of the gun in hand.
## Handed over ready to fire, chambered and with full reserve.
func give_weapon(data: WeaponData) -> void:
	if data.is_melee:
		set_melee(data)
		return
	var owned: int = _slot_of(data)
	_hands_free_left = 0.0
	if owned >= 0 and _slots[owned].data.level < data.level:
		# A dengelt one for the plain one carried: it takes its slot.
		_select(owned)
		_replace_current(_new_slot(data))
		return
	if owned >= 0:
		_select(owned)
		return
	var slot: GunSlot = _new_slot(data)
	if _slots.size() < slots or _current < 0:
		_slots.append(slot)
		_select(_slots.size() - 1)
		return
	_replace_current(slot)


func _replace_current(slot: GunSlot) -> void:
	var old: GunSlot = _slots[_current]
	if old.viewmodel:
		old.viewmodel.queue_free()
	_slots[_current] = slot
	_current = -1
	_select(_slots.find(slot))


func _new_slot(data: WeaponData) -> GunSlot:
	var slot := GunSlot.new()
	slot.data = data
	slot.mag = data.loaded_capacity(true)
	slot.reserve = data.reserve_ammo
	slot.edge = Constants.STUMPF_KILLS if data.level >= 2 else 0
	if data.level >= 2:
		_dulled.erase(data.family_id())
	if data.viewmodel:
		# Built once per gun and kept: instancing on every switch would hitch in the middle of a fight.
		slot.viewmodel = data.viewmodel.instantiate() as Viewmodel
		ForgedLook.dress(slot.viewmodel, data)
		slot.viewmodel.visible = false
		_motion.add_child(slot.viewmodel)
	slot.behavior = WeaponBehavior.create(data, self)
	return slot


## Co-op (M7, section 10): downed, only `pistol` is in hand, one lent for the time if none is
## carried; no switching, no melee. Up again, the gun from before comes back (the lent one is gone).
func set_downed(on: bool, pistol: WeaponData) -> void:
	if on == downed:
		return
	downed = on
	_end_block()
	_melee_left = 0.0
	_melee_hit_in = -1.0
	_stop_playing_if_needed()
	if on:
		_before_down = _current
		_hands_free_left = 0.0
		var index: int = _slot_of(pistol)
		# The Golden Gun is not the pistol to crawl with: its few rounds are kept for later.
		if index < 0 or not _slots[index].data.refillable:
			_slots.append(_new_slot(pistol))
			_borrowed = true
			index = _slots.size() - 1
		_select(index)
		return
	if _borrowed:
		var lent: GunSlot = _slots.pop_back()
		if lent.viewmodel:
			lent.viewmodel.queue_free()
		_borrowed = false
		if _current >= _slots.size():
			_current = -1
	if _before_down < 0 or _before_down >= _slots.size():
		# Their gun was at the Dengelstock when they went down.
		_put_away()
		return
	_select(_before_down)


## Co-op (M7): back from bleeding out with what a new game starts with (Brettljause and herbs stay).
func reset_loadout() -> void:
	set_downed(false, null)
	_cancel_reload()
	for slot: GunSlot in _slots:
		if slot.viewmodel:
			slot.viewmodel.queue_free()
	_slots.clear()
	_current = -1
	weapon = null
	_hands_free_left = 0.0
	if starting_weapon:
		give_weapon(starting_weapon)
	restore_melee()


## The melee weapon a match starts with back in the slot, if another one (or none) is there.
func restore_melee() -> void:
	if _starting_melee and melee_weapon != _starting_melee:
		set_melee(_starting_melee)


## The Dengelstock (M9 part 4): the gun `data` (or its dengelt version) leaves its slot to be forged.
## For DENGEL_TIME the hands hold only the melee weapon; then the other gun comes up, if there is one.
## False if it is not carried.
func hand_over(data: WeaponData) -> bool:
	var index: int = _slot_of(data)
	if index < 0:
		return false
	var resume: GunSlot = _slots[_current] if _current >= 0 and _current != index else null
	_put_away()
	var slot: GunSlot = _slots[index]
	if slot.viewmodel:
		slot.viewmodel.queue_free()
	_slots.remove_at(index)
	if resume:
		# It comes up first once the hands are free again.
		_slots.erase(resume)
		_slots.push_front(resume)
	_hands_free_left = Constants.DENGEL_TIME
	return true


## The Dengelstock: the melee weapon leaves its slot to be forged; until it comes back, V does nothing.
func hand_over_melee() -> void:
	set_melee(null)


## Seconds left with only the melee weapon in hand (a gun at the Dengelstock), 0 when the hands are free.
func hands_free_time() -> float:
	return _hands_free_left


## Puts the gun in hand away (its ammo kept in its slot): nothing in hand, only the melee weapon.
func _put_away() -> void:
	_cancel_reload()
	_stop_playing_if_needed()
	_stop_loop()
	if _current >= 0 and _current < _slots.size():
		var old: GunSlot = _slots[_current]
		old.mag = mag
		old.reserve = reserve
		if old.viewmodel:
			old.viewmodel.visible = false
	_current = -1
	weapon = null
	_viewmodel = null
	_behavior = null
	mag = 0
	reserve = 0
	aim_amount = 0.0
	_aiming = false
	weapon_changed.emit(null)
	ammo_changed.emit(mag, reserve)


## The trigger counts as held until it is let go (a menu click that took the mouse).
func lock_trigger() -> void:
	_fire_locked = true
	_fire_buffer_left = 0.0
	_capture_grace = Constants.CAPTURE_FIRE_GRACE


func _stop_playing_if_needed() -> void:
	if _playing:
		_playing = false
		_stop_playing()


## What refilling the carried `data` (or its forged version) costs on top: DENGEL_AMMO_EXTRA by level.
func ammo_extra(data: WeaponData) -> int:
	var index: int = _slot_of(data)
	if index < 0:
		return 0
	return Constants.DENGEL_AMMO_EXTRA[clampi(_slots[index].data.level, 0, Constants.DENGEL_AMMO_EXTRA.size() - 1)]


## The Munitionskiste's extra: ammo_extra of every carried gun it would refill.
func crate_extra() -> int:
	var extra: int = 0
	for slot: GunSlot in _slots:
		if needs_ammo(slot.data):
			extra += ammo_extra(slot.data)
	return extra


## Carried, as it is or dengelt.
func has_weapon(data: WeaponData) -> bool:
	if data.is_melee:
		return melee_weapon != null and melee_weapon.family_id() == data.family_id()
	return _slot_of(data) >= 0


## Puts a melee weapon in the melee slot (section 6), in place of the one carried (the shovel); null
## empties it (it is at the Dengelstock).
func set_melee(data: WeaponData) -> void:
	_end_block()
	_melee_left = 0.0
	_melee_hit_in = -1.0
	if _melee_viewmodel:
		_melee_viewmodel.queue_free()
		_melee_viewmodel = null
	melee_weapon = data
	_melee_behavior = WeaponBehavior.create(data, self) if data else null
	if data and data.viewmodel:
		_melee_viewmodel = data.viewmodel.instantiate() as MeleeViewmodel
		ForgedLook.dress(_melee_viewmodel, data)
		_motion.add_child(_melee_viewmodel)
	_melee_edge = Constants.STUMPF_KILLS if data and data.level >= 2 else 0
	if data and data.level >= 2:
		_dulled.erase(data.family_id())
	melee_changed.emit(data)


## Stumpf: kills left of the edge of the gun in hand (or the melee weapon); -1 if it is not doppelt
## dengelt.
func edge_left(melee: bool = false) -> int:
	if melee:
		return _melee_edge if melee_weapon and melee_weapon.level >= 2 else -1
	if _current < 0 or weapon == null or weapon.level < 2:
		return -1
	return _slots[_current].edge


## This weapon's kind went dull and was not sharpened again since (the Dengelstock asks).
func is_dulled(data: WeaponData) -> bool:
	return data != null and _dulled.has(data.family_id())


# A kill of ours wears down the edge of what it was made with: the melee weapon, or the gun in hand
# (like the death screen's count, a burn or a thrown thing goes to what is in hand).
func _on_enemy_killed(_enemy: Node3D, _is_headshot: bool, is_melee: bool, source: Node3D) -> void:
	if source == null or source != _shooter:
		return
	if is_melee:
		if melee_weapon == null or melee_weapon.level < 2 or _melee_edge <= 0:
			return
		_melee_edge -= 1
		edge_changed.emit(_melee_edge, true)
		if _melee_edge == 0:
			_go_dull(true)
		return
	if _current < 0 or weapon == null or weapon.level < 2 or _slots[_current].edge <= 0:
		return
	_slots[_current].edge -= 1
	edge_changed.emit(_slots[_current].edge, false)
	if _slots[_current].edge == 0:
		_go_dull(false)


# Doppelt dengelt -> dengelt: the same kind one level down, keeping what ammo still fits.
func _go_dull(melee: bool) -> void:
	var was: WeaponData = melee_weapon if melee else weapon
	var dull := load("res://data/weapons/%s_dengelt.tres" % was.family_id()) as WeaponData
	if dull == null:
		return
	_dulled[was.family_id()] = true
	if melee:
		set_melee(dull)
	else:
		var slot: GunSlot = _new_slot(dull)
		slot.mag = mini(mag, dull.mag_size)
		slot.reserve = mini(reserve, dull.reserve_ammo)
		_replace_current(slot)
	Sound.play(&"anvil_clang", -4.0, 0.6)
	went_dull.emit(was, dull)


## Holding the melee weapon up as a guard right now. Walking slows down; guns cannot fire.
func is_blocking() -> bool:
	return _blocking


## A hit is coming in from `attacker`: true when the guard is up and faces it, so the hit is caught
## (block_share of it still gets through) and the attacker is bonked back.
func block(attacker: Node3D) -> bool:
	if not _blocking or attacker == null or melee_weapon.secondary != WeaponData.Secondary.BLOCK:
		return false
	var to: Vector3 = attacker.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var forward := Vector3(-global_basis.z.x, 0.0, -global_basis.z.z).normalized()
	if flat.length() > 0.05 and flat.normalized().dot(forward) < cos(deg_to_rad(melee_weapon.block_angle)):
		return false
	var enemy := attacker as Enemy
	if enemy and enemy.is_alive():
		enemy.apply_knockback(flat.normalized() * melee_weapon.secondary_knockback * sqrt(enemy.data.flinch_multiplier))
		# The Kaiserschmarrn-Pfanne's twist: the bonked attacker stands dazed.
		if melee_weapon.twist > 0.0:
			enemy.stun(melee_weapon.twist)
	_hit_puffs.play(global_position + forward * 0.5 + Vector3.DOWN * 0.3, -forward)
	Sound.play(&"block_hit")
	if _melee_viewmodel:
		_melee_viewmodel.play_bonk()
	var player := _shooter as Player
	if player:
		player.kick_view(3.0, 1.5)
	return true


## True when the gun is carried and its reserve is not full, so buying ammo would do something.
## (A dengelt gun counts for its base: its own, larger reserve is what gets filled.)
func needs_ammo(data: WeaponData) -> bool:
	var index: int = _slot_of(data)
	if index < 0 or not _slots[index].data.refillable:
		return false
	var spare: int = reserve if index == _current else _slots[index].reserve
	return spare < _slots[index].data.reserve_ammo


func refill_ammo(data: WeaponData) -> void:
	var index: int = _slot_of(data)
	if index < 0 or not _slots[index].data.refillable:
		return
	var full: int = _slots[index].data.reserve_ammo
	_slots[index].reserve = full
	if index == _current:
		reserve = full
		ammo_changed.emit(mag, reserve)


## The gun in hand topped up completely, magazine and reserve (the Murmeltier's reward).
func refill_current() -> void:
	if weapon == null or not weapon.refillable:
		return
	_cancel_reload()
	mag = maxi(mag, weapon.mag_size)
	refill_ammo(weapon)
	ammo_changed.emit(mag, reserve)


## True when any carried gun is short of reserve ammo (the Lager's ammo crate).
func needs_any_ammo() -> bool:
	return _slots.any(func(slot: GunSlot) -> bool: return needs_ammo(slot.data))


func refill_all() -> void:
	for slot: GunSlot in _slots:
		refill_ammo(slot.data)


func gun_count() -> int:
	return _slots.size()


## A free slot for one more gun (a new one would not replace the one in hand).
func has_free_slot() -> bool:
	return _slots.size() < slots


## Die Kraxn (#95): a third gun slot.
func has_kraxn() -> bool:
	return slots > Constants.GUN_SLOTS


func add_kraxn() -> void:
	if has_kraxn():
		return
	slots = Constants.GUN_SLOTS + 1
	slots_changed.emit(slots)


## The guns carried but not in hand, for the Kraxn on a hiker's back.
func stowed() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for i: int in _slots.size():
		if i != _current:
			out.append(_slots[i].data)
	return out


func is_reloading() -> bool:
	return _reload_left > 0.0


## Share of the running reload done (0..1), or -1 when not reloading.
func reload_progress() -> float:
	return 1.0 - _reload_left / _reload_total if is_reloading() and _reload_total > 0.0 else -1.0


## The ready ring shows the cycle after this shot: guns with long gaps (WeaponData.cycle_ring), and
## the long wait after the Querschläger.
func shows_cycle_ring() -> bool:
	return weapon != null and (weapon.cycle_ring or _ring_cycle)


## Share of the gun's cycle after a shot done (0..1), or -1 when it is ready to fire again.
func cycle_progress() -> float:
	return 1.0 - _cooldown / _cooldown_total if _cooldown > 0.0 and _cooldown_total > 0.0 else -1.0


## Aiming right now (right click held on a gun that aims). Movement slows down and sprint is off.
func is_aiming() -> bool:
	return _aiming


## Looking through the scope: the overlay is up and the gun model is out of the way.
func is_scoped() -> bool:
	return weapon != null and weapon.secondary == WeaponData.Secondary.SCOPE and aim_amount >= Constants.SCOPE_SHOW_AT


## Right click held on a PLAY weapon (a held tune): walking slows, no sprinting.
func is_playing() -> bool:
	return _playing


## Cone half-angle in degrees the next shot can stray: base spread plus bloom, tightened by aiming.
func current_spread() -> float:
	if weapon == null:
		return 0.0
	return (weapon.spread + bloom) * lerpf(1.0, weapon.aim_spread_multiplier, aim_amount)


## Bloom as it would widen the next shot (aiming tightens it like the base spread), for the crosshair.
func current_bloom() -> float:
	if weapon == null:
		return 0.0
	return bloom * lerpf(1.0, weapon.aim_spread_multiplier, aim_amount)


## Aim blend eased, for the camera zoom and the gun pose.
func aim_eased() -> float:
	return smoothstep(0.0, 1.0, aim_amount)


func _unhandled_input(event: InputEvent) -> void:
	# Here and not in _physics_process: wheel "presses" are released in the same frame and would be missed.
	if ghost or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _melee_left > 0.0 or _slots.size() < 2 or downed or weapon == null:
		return
	if event.is_action_pressed("weapon_next"):
		_select((_current + 1) % _slots.size())
	elif event.is_action_pressed("weapon_previous"):
		_select((_current + _slots.size() - 1) % _slots.size())
	elif event.is_action_pressed("weapon_slot_1"):
		_select(0)
	elif event.is_action_pressed("weapon_slot_2"):
		_select(1)
	elif event.is_action_pressed("weapon_slot_3"):
		_select(2)


func _physics_process(delta: float) -> void:
	if ghost:
		_ghost_step(delta)
		return
	if weapon == null:
		_without_gun(delta)
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	bloom = move_toward(bloom, 0.0, weapon.bloom_recover * delta)
	if _fire_loop_left > 0.0:
		_fire_loop_left -= delta
		if _fire_loop_left <= 0.0:
			_stop_loop()
	var was_playing: bool = _playing
	_playing = false
	# Reloading on the run is fine, shooting is not: the gun is lowered until the sprint ends.
	var player := _shooter as Player
	if player and player.is_sprinting():
		_sprint_left = Constants.SPRINT_TO_FIRE_TIME
	else:
		_sprint_left = maxf(_sprint_left - delta, 0.0)
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# The click that took the mouse (a menu, co-op's "click to join") must not also fire.
	if captured and not _was_captured:
		lock_trigger()
	_was_captured = captured
	_capture_grace = maxf(_capture_grace - delta, 0.0)
	_update_aim(delta, force_aim or (captured and _aim_held(Input.is_action_pressed("secondary"), Input.is_action_just_pressed("secondary"))))
	if _melee_step(delta):
		return
	if _switch_left > 0.0:
		_switch_left -= delta
		return
	if is_reloading():
		# An instant secondary (Hoch damit!) still goes off: the last ball may be rolling yet.
		if (captured or force_aim) and weapon.secondary == WeaponData.Secondary.BEHAVIOR and _behavior 				and _behavior.secondary_instant() and Input.is_action_just_pressed("secondary") and _behavior.secondary_ready():
			fire_secondary()
		_reload_left -= delta
		_load_rounds()
		if _reload_left <= 0.0:
			_finish_reload()
		return
	_fire_locked = _fire_locked and Input.is_action_pressed("fire")
	# An empty gun reloads by itself once its last shot has cycled (play-test 2026-10-17: a click on
	# the empty gun during the cycle could run out before it counted, so R was needed).
	# (Not while the last round of a held tune still plays: that one ends first.)
	if mag == 0 and reserve > 0 and _cooldown <= 0.0 and not was_playing:
		start_reload()
		return
	# force_aim stands in for a held right click without a mouse (tests, capture tools).
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not force_aim:
		return
	if Input.is_action_just_pressed("reload"):
		start_reload()
		return
	if _sprint_left > 0.0:
		return
	if weapon.secondary == WeaponData.Secondary.PLAY and (force_aim or Input.is_action_pressed("secondary")) and (was_playing or _cooldown <= 0.0):
		_play(delta, was_playing)
		return
	if was_playing:
		_stop_playing()
	if weapon.secondary == WeaponData.Secondary.RICOCHET and Input.is_action_just_pressed("secondary") and _cooldown <= 0.0:
		if mag >= weapon.secondary_rounds:
			fire_ricochet()
		else:
			start_reload()
		return
	if weapon.secondary == WeaponData.Secondary.ALL_BARRELS and Input.is_action_just_pressed("secondary") and _cooldown <= 0.0:
		if mag > 0:
			fire_all()
		else:
			start_reload()
		return
	if weapon.secondary == WeaponData.Secondary.BEHAVIOR and Input.is_action_just_pressed("secondary") 			and (_cooldown <= 0.0 or (_behavior and _behavior.secondary_instant())):
		if _behavior and not _behavior.secondary_ready():
			return
		if _can_fire_secondary():
			fire_secondary()
		else:
			start_reload()
		return
	if _capture_grace > 0.0:
		_fire_buffer_left = 0.0
		return
	if Input.is_action_just_pressed("fire"):
		_fire_buffer_left = Constants.FIRE_BUFFER_TIME
	else:
		_fire_buffer_left = maxf(_fire_buffer_left - delta, 0.0)
	# Semi-auto fires once per click, as fast as the clicks come (up to fire_rate).
	var wants_fire: bool = (Input.is_action_pressed("fire") if weapon.is_auto else _fire_buffer_left > 0.0) and not _fire_locked
	if wants_fire and _cooldown <= 0.0:
		_fire_buffer_left = 0.0
		if mag > 0:
			_fire()
		else:
			# Pulling the trigger on an empty mag is the most common way players "ask" for a reload.
			start_reload()
			if reserve <= 0 and Input.is_action_just_pressed("fire"):
				Sound.play(&"dry_click")


## The melee weapon's part of a frame: a guard or held mode, a swing, or V pressed. True if it took
## the frame (the gun waits).
func _melee_step(delta: float) -> bool:
	if _blocking:
		if not _melee_held() or (_melee_behavior and melee_weapon.secondary == WeaponData.Secondary.BEHAVIOR and not _melee_behavior.hold(delta)):
			_end_block()
		return true
	if _melee_left > 0.0:
		_update_melee(delta)
		return true
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("melee") and melee_weapon and not downed:
		_start_melee()
		return true
	return false


## No gun in hand (it went to the Dengelstock): the melee weapon still works, and once the hands are
## free again the other gun comes up, if there is one.
func _without_gun(delta: float) -> void:
	_hands_free_left = maxf(_hands_free_left - delta, 0.0)
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _melee_step(delta):
		return
	if _hands_free_left <= 0.0 and not _slots.is_empty():
		_select(0)


func _play(delta: float, was_playing: bool) -> void:
	if not was_playing:
		_play_left = 0.0
		_start_loop(weapon.play_sound)
	_play_left -= delta
	if _play_left <= 0.0:
		# The next round of the tune; out of rounds, the music stops and the gun reloads.
		if mag <= 0:
			if was_playing:
				_stop_playing()
			start_reload()
			return
		mag -= 1
		_play_left += weapon.secondary_round_time
		# No fired signal: playing on has no recoil.
		ammo_changed.emit(mag, reserve)
	_playing = true
	if _behavior:
		_behavior.play_secondary(delta)
	if _viewmodel:
		_viewmodel.set_playing(true)


func _stop_playing() -> void:
	_play_left = 0.0
	_stop_loop()
	# The bellows are closed up before the next polka.
	_set_cooldown(weapon.secondary_round_time)
	if _viewmodel:
		_viewmodel.set_playing(false)


func start_reload() -> void:
	# With rounds left, one stays in the chamber on top of the new mag.
	var target: int = weapon.loaded_capacity(mag > 0)
	if is_reloading() or mag >= target or reserve <= 0:
		return
	_reload_target = target
	if mag == 0 and _perks():
		_perks().on_empty_reload()
	# Empty mag means the slide is locked back: chamber a round after the new mag is in.
	var speed: float = _perks().reload_time_multiplier() if _perks() else 1.0
	var chamber: float = weapon.chamber_time * speed if mag == 0 else 0.0
	var loading: float = weapon.reload_time * speed
	# Loaded round by round: as long as the rounds that are missing.
	_reload_rounds = mini(target - mag, reserve) if weapon.reload_round_time > 0.0 else 0
	_reload_loaded = 0
	_reload_per_round = weapon.reload_round_time * speed
	_reload_lift = loading * Constants.RELOAD_LIFT_SHARE
	loading += _reload_per_round * _reload_rounds
	_reload_left = loading + chamber
	_reload_total = _reload_left
	# A click from before the reload (still buffered from the last shot's cycle) must not fire after it.
	_fire_buffer_left = 0.0
	_fire_locked = true
	reload_started.emit(_reload_left)
	_stop_loop()
	Sound.play(weapon.reload_sound)
	if _viewmodel:
		_viewmodel.reload_rounds = _reload_rounds
		_viewmodel.reload_round_time = _reload_per_round
		_viewmodel.play_reload(loading, chamber)


## Loading round by round: every round that is in by now counts at once (a reload cut short keeps them).
func _load_rounds() -> void:
	var done: float = _reload_total - _reload_left
	var moved: bool = false
	while _reload_loaded < _reload_rounds and reserve > 0 and done >= _reload_lift + _reload_per_round * (_reload_loaded + Constants.RELOAD_ROUND_IN_AT):
		_reload_loaded += 1
		mag += 1
		reserve -= 1
		moved = true
	if moved:
		ammo_changed.emit(mag, reserve)


func _finish_reload() -> void:
	_reload_left = 0.0
	var moved: int = mini(_reload_target - mag, reserve)
	mag += moved
	reserve -= moved
	reload_finished.emit()
	Sound.play(weapon.reload_end_sound)
	ammo_changed.emit(mag, reserve)


func _cancel_reload() -> void:
	if is_reloading():
		_reload_left = 0.0
		reload_finished.emit()


func _perks() -> PlayerPerks:
	var player := _shooter as Player
	return player.perks if player else null


## Damage after perks and the Brettljause.
func _damage(base: int) -> int:
	return roundi(base * _perks().damage_multiplier()) if _perks() else base


## The slot of `data` or of a dengelt version of it.
func _slot_of(data: WeaponData) -> int:
	for i: int in _slots.size():
		if _slots[i].data.family_id() == data.family_id():
			return i
	return -1


## The Golden Gun: enough to kill whatever it hits, whatever its health (at least `amount`).
func _whole_health(receiver: Node, amount: int) -> int:
	var enemy := receiver as Enemy
	return maxi(amount, maxi(enemy.health, enemy.max_health)) if enemy else amount


## A special weapon's own hits (area, strike), by the weapon in hand or the melee weapon.
func _special_boss_share(receiver: Node, is_melee: bool) -> float:
	var data: WeaponData = melee_weapon if is_melee else weapon
	return _boss_share(receiver, data) if data else 1.0


## A dengelt weapon hits bosses for less of its extra damage (WeaponData.boss_multiplier).
func _boss_share(receiver: Node, data: WeaponData) -> float:
	var enemy := receiver as Enemy
	return data.boss_multiplier if enemy and enemy.data and enemy.data.is_boss else 1.0


func _select(index: int) -> void:
	if index == _current or index < 0 or index >= _slots.size():
		return
	# A switch drops a running reload, like in every shooter: the mag swap starts over next time.
	_cancel_reload()
	_stop_loop()
	if _current >= 0 and _current < _slots.size():
		# Not for the gun in hand at the start: that one is not drawn.
		Sound.play(&"weapon_raise")
		var old: GunSlot = _slots[_current]
		old.mag = mag
		old.reserve = reserve
		if old.viewmodel:
			old.viewmodel.visible = false
	_current = index
	_aim_toggled = false
	var slot: GunSlot = _slots[index]
	weapon = slot.data
	bloom = 0.0
	mag = slot.mag
	reserve = slot.reserve
	_viewmodel = slot.viewmodel
	_behavior = slot.behavior
	_cooldown = 0.0
	_switch_left = Constants.WEAPON_SWITCH_TIME
	if _viewmodel:
		_viewmodel.visible = true
		_viewmodel.play_raise(Constants.WEAPON_SWITCH_TIME)
	weapon_changed.emit(weapon)
	ammo_changed.emit(mag, reserve)


## Both barrels (ALL_BARRELS secondary): every loaded round in one blast.
func fire_all() -> void:
	_fire(mag)


## The Querschläger (RICOCHET secondary): one shot for secondary_rounds, then a long lever cycle.
## Returns how many bodies it hit.
func fire_ricochet() -> int:
	if mag < weapon.secondary_rounds:
		return 0
	mag -= weapon.secondary_rounds
	_set_cooldown(weapon.ricochet_cycle)
	_ring_cycle = true
	var hit: int = _ricochet()
	Sound.play(weapon.fire_sound, 0.0, weapon.sound_pitch)
	fired.emit(1)
	acted.emit(Act.SECONDARY, weapon.secondary_rounds)
	ammo_changed.emit(mag, reserve)
	if _viewmodel:
		_viewmodel.cycle_time = _cooldown_total
		_viewmodel.play_secondary(weapon.secondary_rounds)
	return hit


## The bullet's path: along the aim to the first body or wall, then glancing off on to the nearest
## enemy it can see within secondary_range that it has not hit yet, and on, through ricochet_damage
## bodies or ricochet_reach metres flown from hop to hop. A head hit first counts double; the hops
## strike bodies.
func _ricochet() -> int:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + _spread_direction() * weapon.range, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, _exclude)
	query.collide_with_areas = true
	var first: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if first.is_empty():
		return 0
	var path := PackedVector3Array([global_transform * Constants.MUZZLE_OFFSET, first.position])
	var struck: Dictionary = {}
	var at: Vector3 = first.position
	var hurtbox := first.collider as Hurtbox
	if hurtbox:
		struck[hurtbox.receiver] = true
		_ricochet_hit(hurtbox, first.position, first.normal, 0)
	else:
		_impact_marks.place(first.position, first.normal)
		_impact_puffs.play(first.position, first.normal)
		# Off the wall, from just in front of it.
		at += first.normal * 0.1
	var left: float = weapon.ricochet_reach
	while struck.size() < weapon.ricochet_damage.size() and left > 0.0:
		var next: Dictionary = {}
		for body: Dictionary in _bodies_in(at, Vector3.FORWARD, 180.0, minf(weapon.secondary_range, left)):
			var receiver: Node = (body.hurtbox as Hurtbox).receiver
			var enemy := receiver as Enemy
			if struck.has(receiver) or (enemy and not enemy.is_alive()):
				continue
			if next.is_empty() or body.distance < next.distance:
				next = body
		if next.is_empty():
			break
		left -= next.distance
		at = next.target
		struck[(next.hurtbox as Hurtbox).receiver] = true
		path.append(at)
		_ricochet_hit(next.hurtbox, at, -(next.to_target as Vector3).normalized(), struck.size() - 1)
	if path.size() > 2 or hurtbox == null:
		Sound.play(&"ricochet", 0.0, _rng.randf_range(0.9, 1.1))
	var trail := Node3D.new()
	trail.set_script(RICOCHET_TRAIL)
	trail.set("points", path)
	_shooter.get_parent().add_child(trail)
	return struck.size()


## The `index`-th body the Querschläger hits: less with every hop (ricochet_damage).
func _ricochet_hit(hurtbox: Hurtbox, at: Vector3, normal: Vector3, index: int) -> void:
	var amount: int = roundi(hurtbox.damage_for(_damage(weapon.ricochet_damage[index]), weapon.headshot_multiplier) * _boss_share(hurtbox.receiver, weapon))
	var result: Hurtbox.Result = hurtbox.receiver.receive_hit(amount, hurtbox.is_head, false, _shooter)
	if result != Hurtbox.Result.IGNORED:
		_hit_puffs.play(at, normal)
		hit_confirmed.emit(hurtbox.is_head, result == Hurtbox.Result.KILLED)


## A special weapon's own second shot (BEHAVIOR secondary), using secondary_rounds at once.
func fire_secondary() -> void:
	var rounds: int = weapon.secondary_rounds
	if _behavior == null or not _can_fire_secondary():
		return
	# What the magazine lacks comes from the reserve, where the weapon allows it.
	var from_reserve: int = maxi(rounds - mag, 0)
	mag -= rounds - from_reserve
	reserve -= from_reserve
	if not _behavior.secondary_instant():
		_set_cooldown(1.0 / weapon.fire_rate)
	_behavior.fire_secondary()
	Sound.play(weapon.secondary_sound if weapon.secondary_sound != &"" else weapon.fire_sound, 0.0, weapon.sound_pitch)
	fired.emit(rounds)
	acted.emit(Act.SECONDARY, rounds)
	ammo_changed.emit(mag, reserve)
	# Not over a reload's own animation.
	if _viewmodel and not is_reloading():
		_viewmodel.play_secondary(rounds)


func _can_fire_secondary() -> bool:
	var rounds: int = weapon.secondary_rounds
	if weapon.secondary_from_reserve:
		return mag > 0 and mag + reserve >= rounds
	return mag >= rounds


## Area hit from the muzzle along the aim (the Alphorn); see area_hit.
func blast(half_angle: float, reach: float, amount: int, push: float) -> int:
	return area_hit(global_position, -global_basis.z, half_angle, reach, amount, push)


## Area hit for behaviors (section 6a): every enemy (or other hit receiver) whose body is within
## `reach` metres of `center` and `half_angle` degrees of `forward`, with a clear line from the center,
## takes `amount` (before perks), and enemies that survive are thrown back; 180 degrees is all around
## (an explosion). Returns how many were hit.
func area_hit(center: Vector3, forward: Vector3, half_angle: float, reach: float, amount: int, push: float) -> int:
	var hit: int = 0
	for body: Dictionary in _bodies_in(center, forward, half_angle, reach):
		var hurtbox: Hurtbox = body.hurtbox
		var to_target: Vector3 = body.to_target
		var result: Hurtbox.Result = hurtbox.take_hit(roundi(_damage(amount) * _special_boss_share(hurtbox.receiver, false)), 1.0, false, _shooter)
		if result == Hurtbox.Result.IGNORED:
			continue
		hit += 1
		_hit_puffs.play(body.target, -to_target.normalized())
		hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)
		var enemy := hurtbox.receiver as Enemy
		if enemy and enemy.is_alive():
			var flat := Vector3(to_target.x, 0.0, to_target.z)
			var away: Vector3 = flat.normalized() if flat.length() > 0.05 else Vector3(forward.x, 0.0, forward.z).normalized()
			var falloff: float = lerpf(1.0, 0.5, clampf(body.distance / reach, 0.0, 1.0))
			# Heavy bodies are shoved less, but still visibly: by the root of how much they flinch.
			enemy.apply_knockback(away * push * falloff * sqrt(enemy.data.flinch_multiplier))
	return hit


## Every body within `reach` of the shooter, walls shielding (the Harmonika's polka): it dances for
## `duration` and takes `dps` (before perks) a second. Returns how many it reached.
func dance_around(reach: float, duration: float, dps: int) -> int:
	return dance_at(global_position, reach, duration, dps)


## The same around any spot (the Harmonika's Tanzboden), walls shielding from there.
func dance_at(center: Vector3, reach: float, duration: float, dps: int) -> int:
	var reached: int = 0
	for body: Dictionary in _bodies_in(center, -global_basis.z, 180.0, reach):
		var enemy := (body.hurtbox as Hurtbox).receiver as Enemy
		if enemy and enemy.is_alive():
			enemy.dance(duration, _damage(dps), _shooter)
			reached += 1
	return reached


## The Brennkessel's flame: every body within `reach` and `half_angle` degrees of the aim, walls
## shielding, takes `amount` (before perks) and catches fire, burning for `burn_dps` (before perks)
## a second for `burn_time`. Hit points are paid once a second per body, not per tick (Enemy.scorch).
## With `spread` (the Feuerwasser-Kessel's twist), the fire jumps from every body it catches to the
## bodies within that many metres of it.
func scorch(half_angle: float, reach: float, amount: int, burn_dps: int, burn_time: float, spread: float = 0.0) -> int:
	var hit: int = 0
	for body: Dictionary in _bodies_in(global_position, -global_basis.z, half_angle, reach):
		var enemy := (body.hurtbox as Hurtbox).receiver as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var result: Hurtbox.Result = enemy.scorch(_damage(amount), _shooter)
		if result == Hurtbox.Result.IGNORED:
			continue
		hit += 1
		hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)
		if enemy.is_alive():
			enemy.ignite(burn_time, _damage(burn_dps), _shooter)
		if spread > 0.0:
			ignite_around(enemy.global_position + Vector3.UP * 0.5, spread, burn_dps, burn_time)
	return hit


## Sets every body within `reach` of `center` on fire (a burning puddle): `burn_dps` (before perks) a
## second for `burn_time`, walls shielding. Returns how many.
func ignite_around(center: Vector3, reach: float, burn_dps: int, burn_time: float) -> int:
	var lit: int = 0
	for body: Dictionary in _bodies_in(center, Vector3.FORWARD, 180.0, reach):
		var enemy := (body.hurtbox as Hurtbox).receiver as Enemy
		if enemy and enemy.is_alive():
			enemy.ignite(burn_time, _damage(burn_dps), _shooter)
			lit += 1
	return lit


## The bodies (not heads) an area reaches: within `reach` of `center` and `half_angle` degrees of
## `forward` (180 = all around), one per receiver, with no wall between (window openings let it
## through). Each as {hurtbox, target (its middle), to_target, distance}. With `flat`, the angle is
## measured on the ground, as melee does: a body right below the eye still counts as straight ahead.
func _bodies_in(center: Vector3, forward: Vector3, half_angle: float, reach: float, flat: bool = false) -> Array[Dictionary]:
	if ghost:
		return []
	var sphere := SphereShape3D.new()
	sphere.radius = reach + Constants.AREA_BODY_MARGIN
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = Constants.LAYER_HITBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var min_dot: float = cos(deg_to_rad(half_angle))
	var seen: Dictionary = {}
	var bodies: Array[Dictionary] = []
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Constants.AREA_MAX_TARGETS):
		var hurtbox := found.collider as Hurtbox
		if hurtbox == null or hurtbox.is_head or seen.has(hurtbox.receiver):
			continue
		var target: Vector3 = hurtbox.global_position + Vector3.UP * Constants.AREA_AIM_HEIGHT * hurtbox.scale.y
		var to_target: Vector3 = target - center
		var distance: float = to_target.length()
		if distance > reach + Constants.AREA_BODY_MARGIN:
			continue
		# A body right next to the muzzle counts even if its middle is just outside the cone.
		var along: Vector3 = Vector3(to_target.x, 0.0, to_target.z) if flat else to_target
		var aim: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized() if flat else forward
		var off_axis: float = (along - aim * along.dot(aim)).length()
		if half_angle < 180.0 and along.normalized().dot(aim) < min_dot and not (along.dot(aim) > 0.0 and off_axis < Constants.AREA_BODY_MARGIN):
			continue
		var line := PhysicsRayQueryParameters3D.create(center, target, Constants.LAYER_WORLD, _exclude)
		if not get_world_3d().direct_space_state.intersect_ray(line).is_empty():
			continue
		seen[hurtbox.receiver] = true
		bodies.append({"hurtbox": hurtbox, "target": target, "to_target": to_target, "distance": distance})
	return bodies


## One body hit for behaviors that find their own targets (the Rodelkanone's sled): `amount` (before
## perks), and a survivor thrown along `push` (scaled like area_hit's, by how much it flinches).
func strike(hurtbox: Hurtbox, amount: int, push: Vector3, is_melee: bool = false) -> Hurtbox.Result:
	if ghost:
		return Hurtbox.Result.IGNORED
	var result: Hurtbox.Result = hurtbox.take_hit(roundi(_damage(amount) * _special_boss_share(hurtbox.receiver, is_melee)), 1.0, is_melee, _shooter)
	if result == Hurtbox.Result.IGNORED:
		return result
	var target: Vector3 = hurtbox.global_position + Vector3.UP * Constants.AREA_AIM_HEIGHT * hurtbox.scale.y
	_hit_puffs.play(target, -push.normalized() if push.length() > 0.01 else Vector3.UP)
	hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)
	var enemy := hurtbox.receiver as Enemy
	if enemy and enemy.is_alive():
		enemy.apply_knockback(push * sqrt(enemy.data.flinch_multiplier))
	return result


## The bodies all around `center` within `reach` (walls shielding), nearest first; each as
## {hurtbox, target, to_target, distance}.
func bodies_near(center: Vector3, reach: float) -> Array[Dictionary]:
	var bodies: Array[Dictionary] = _bodies_in(center, Vector3.FORWARD, 180.0, reach)
	bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	return bodies


## The bodies in front of the shooter for a melee behavior: within `reach` and `half_angle` degrees of
## the aim, walls shielding, nearest first. Each as {hurtbox, target, to_target, distance}.
func bodies_ahead(reach: float, half_angle: float) -> Array[Dictionary]:
	var bodies: Array[Dictionary] = _bodies_in(global_position, -global_basis.z, half_angle, reach, true)
	bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	return bodies


## The first body straight along the aim within `reach` (a narrow line, walls stopping it), or null.
func body_in_line(reach: float) -> Hurtbox:
	var bodies: Array[Dictionary] = bodies_ahead(reach, Constants.LINE_HALF_ANGLE)
	return bodies[0].hurtbox if not bodies.is_empty() else null


## A melee blow from a behavior on one body: `amount` (before perks) counted as melee for points,
## the survivor thrown along `push`, and the weapon's hit sound where it lands.
func melee_strike(hurtbox: Hurtbox, amount: int, push: Vector3) -> Hurtbox.Result:
	var result: Hurtbox.Result = strike(hurtbox, amount, push, true)
	if result != Hurtbox.Result.IGNORED:
		Sound.play_at(melee_weapon.hit_sound, hurtbox.global_position + Vector3.UP * Constants.MELEE_AIM_HEIGHT * hurtbox.scale.y)
	return result


## The melee weapon's first-person model, for behaviors that animate it during their held mode.
func melee_viewmodel() -> MeleeViewmodel:
	return _melee_viewmodel


## A sound from the guns: in the ears for our own, from where they are for a ghost.
func play_sound(id: StringName, pitch: float = 1.0) -> void:
	if ghost:
		Sound.play_at(id, global_position, 0.0, pitch)
	else:
		Sound.play(id, 0.0, pitch)


## A jolt of the shooter's view that is not recoil (a blast going off).
func shake_view(degrees: float) -> void:
	var player := _shooter as Player
	if player and degrees > 0.0:
		player.shake_view(degrees)


## Where thrown things and effects live: the world the shooter stands in.
func world_root() -> Node:
	return _shooter.get_parent()


## Who holds the guns (the Player), for behaviors that move or affect them.
func shooter() -> Node3D:
	return _shooter


## The shooter's own body, so its projectiles never hit it.
func shooter_exclude() -> Array[RID]:
	return _exclude


## Puts a short-lived effect into the world where the camera is, looking along the aim.
func add_effect(effect: Node3D) -> void:
	effect.transform = global_transform
	_shooter.get_parent().add_child(effect)


# Right click held (`held`), or (Settings.toggle_aim) clicked on (`clicked` this frame) and not yet
# off again. Only for a gun that aims: its right click is not a special mode of its own.
func _aim_held(held: bool, clicked: bool) -> bool:
	if not Settings.toggle_aim:
		return held
	if weapon == null or not weapon.can_aim():
		_aim_toggled = false
	elif clicked:
		_aim_toggled = not _aim_toggled
	return _aim_toggled


func _update_aim(delta: float, held: bool) -> void:
	# Reloading, switching or swinging the shovel drops the aim; it comes back once the hands are free.
	_aiming = held and weapon != null and weapon.can_aim() and not is_reloading() and _switch_left <= 0.0 and _melee_left <= 0.0 and not _blocking
	var speed: float = 1.0 / weapon.aim_time if weapon and weapon.aim_time > 0.0 else 1.0 / Constants.WEAPON_SWITCH_TIME
	aim_amount = move_toward(aim_amount, 1.0 if _aiming else 0.0, speed * delta)
	if _viewmodel:
		_viewmodel.set_aim(aim_eased())
		# Out of the way behind the scope, and down while a melee guard is up.
		_viewmodel.visible = not is_scoped() and not _blocking


func _fire(rounds: int = 1) -> void:
	rounds = mini(rounds, mag)
	mag -= rounds
	bloom = minf(bloom + weapon.bloom_per_shot * rounds, weapon.bloom_max)
	_set_cooldown(1.0 / weapon.fire_rate)
	# Pellets that hit the same enemy land as one hit: one flinch, one hit marker and one set of
	# points per shot, not one per pellet.
	if _behavior:
		_behavior.fire(rounds)
		_after_shot(rounds)
		return
	var hits: Dictionary = {}
	for i: int in weapon.pellets * rounds:
		_fire_ray(hits)
	for receiver: Node in hits:
		var hit: Dictionary = hits[receiver]
		var result: Hurtbox.Result = receiver.receive_hit(hit.amount, hit.head, false, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(hit.position, hit.normal)
			hit_confirmed.emit(hit.head, result == Hurtbox.Result.KILLED)
	_after_shot(rounds)


func _after_shot(rounds: int) -> void:
	if weapon.fire_loop_sound != &"":
		# Held fire: the start once, then the loop for as long as the shots keep coming.
		if not _loop_sound.playing:
			Sound.play(weapon.fire_sound, 0.0, weapon.sound_pitch)
			_start_loop(weapon.fire_loop_sound)
		_fire_loop_left = 2.0 / weapon.fire_rate
	elif rounds > 1 and weapon.secondary_sound != &"":
		Sound.play(weapon.secondary_sound, 0.0, weapon.sound_pitch)
	else:
		Sound.play(weapon.fire_sound, 0.0, weapon.sound_pitch)
	fired.emit(rounds)
	acted.emit(Act.SHOT, rounds)
	ammo_changed.emit(mag, reserve)
	if _viewmodel:
		_viewmodel.cycle_time = _cooldown_total
		_viewmodel.play_fire(rounds)


func _set_cooldown(time: float) -> void:
	_cooldown = time
	_cooldown_total = time
	_ring_cycle = false


func _start_melee() -> void:
	# A swing cancels a running reload: in a panic the shovel must always come out.
	_cancel_reload()
	_melee_left = 1.0 / melee_weapon.fire_rate
	_melee_hit_in = _melee_left * Constants.MELEE_HIT_FRACTION
	Sound.play(melee_weapon.swing_sound)
	acted.emit(Act.SWING, 1)
	if _viewmodel:
		_viewmodel.play_lower(_melee_left)
	if _melee_viewmodel:
		_melee_viewmodel.play_swing(_melee_left, _melee_hit_in)


func _update_melee(delta: float) -> void:
	_melee_left -= delta
	if _melee_hit_in >= 0.0:
		_melee_hit_in -= delta
		if _melee_hit_in < 0.0:
			_melee_hit()
			# Still holding V after the blow: the weapon stays up as a guard, or goes into its own held
			# mode (BEHAVIOR on a melee weapon).
			if _melee_held():
				if melee_weapon.secondary == WeaponData.Secondary.BLOCK:
					_start_block()
				elif melee_weapon.secondary == WeaponData.Secondary.BEHAVIOR and _melee_behavior and _melee_behavior.hold_start():
					_start_block()


func _melee_held() -> bool:
	return force_melee_hold or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("melee"))


func _start_block() -> void:
	_blocking = true
	acted.emit(Act.HOLD, 1)
	_melee_left = 0.0
	# The gun stays down for as long as the guard is up.
	if _viewmodel:
		_viewmodel.visible = false
	if _melee_viewmodel:
		_melee_viewmodel.play_guard()


func _end_block() -> void:
	if not _blocking:
		return
	_blocking = false
	acted.emit(Act.RELEASE, 1)
	if _melee_behavior and melee_weapon.secondary == WeaponData.Secondary.BEHAVIOR:
		_melee_behavior.hold_end()
	if _melee_viewmodel:
		_melee_viewmodel.end_guard()
	_switch_left = Constants.BLOCK_LOWER_TIME
	if _viewmodel:
		_viewmodel.visible = true
		_viewmodel.play_raise(Constants.BLOCK_LOWER_TIME)


func _start_loop(id: StringName) -> void:
	if id == &"" or not Sound.has(id):
		return
	_loop_sound.stream = Sound.stream(id)
	_loop_sound.volume_db = Sound.level(id)
	_loop_sound.play()


func _stop_loop() -> void:
	_fire_loop_left = 0.0
	if _loop_sound:
		_loop_sound.stop()


func _on_hit_confirmed(is_headshot: bool, _killed: bool) -> void:
	Sound.play(&"headshot" if is_headshot else &"hitmarker")


func _melee_hit() -> void:
	acted.emit(Act.MELEE, 1)
	if _melee_behavior and _melee_behavior.melee_hit():
		return
	# The swing sweeps an arc in front of the player and hits every enemy in it, once each.
	var sphere := SphereShape3D.new()
	sphere.radius = melee_weapon.range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = Constants.LAYER_HITBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var forward: Vector3 = -global_basis.z
	var min_dot: float = cos(deg_to_rad(Constants.MELEE_ARC_DEGREES * 0.5))
	var struck: Dictionary = {}
	for found: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, Constants.MELEE_MAX_TARGETS):
		var hurtbox := found.collider as Hurtbox
		# Body boxes only: one blow per enemy, and a shovel does not do headshots.
		if hurtbox == null or hurtbox.is_head or struck.has(hurtbox.receiver):
			continue
		var target: Vector3 = hurtbox.global_position + Vector3.UP * Constants.MELEE_AIM_HEIGHT
		var to_target: Vector3 = target - global_position
		# Flattened, so an enemy right in front still counts when the player looks down at it.
		var flat := Vector3(to_target.x, 0.0, to_target.z)
		var flat_forward := Vector3(forward.x, 0.0, forward.z)
		if flat.length() > 0.2 and flat.normalized().dot(flat_forward.normalized()) < min_dot:
			continue
		# No hitting through walls; the window openings themselves are fine.
		var line: Dictionary = _cast(to_target, Constants.LAYER_WORLD)
		if line.collider != null:
			continue
		struck[hurtbox.receiver] = true
		var amount: int = roundi(_damage(melee_weapon.damage) * _boss_share(hurtbox.receiver, melee_weapon))
		var result: Hurtbox.Result = hurtbox.take_hit(amount, melee_weapon.headshot_multiplier, true, _shooter)
		if result != Hurtbox.Result.IGNORED:
			_hit_puffs.play(target, -to_target.normalized())
			hit_confirmed.emit(false, result == Hurtbox.Result.KILLED)
			Sound.play_at(melee_weapon.hit_sound, target)
			var enemy := hurtbox.receiver as Enemy
			if enemy and enemy.is_alive() and melee_weapon.knockback > 0.0:
				enemy.apply_knockback(flat.normalized() * melee_weapon.knockback * sqrt(enemy.data.flinch_multiplier))
			# The Schneefräsn-Schaufl's twist: the survivor stands dazed.
			if enemy and enemy.is_alive() and melee_weapon.stun_time > 0.0:
				enemy.stun(melee_weapon.stun_time)


func _cast(offset: Vector3, mask: int = Constants.LAYER_WORLD | Constants.LAYER_HITBOX) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + offset, mask, _exclude)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() else {"collider": null}


func _fire_ray(hits: Dictionary) -> void:
	# One ray, re-cast past every enemy it goes through (penetration) until it stops in one or a wall.
	var offset: Vector3 = _spread_direction() * weapon.range
	var exclude: Array[RID] = _exclude.duplicate()
	var share: float = 1.0
	var pierced: int = 0
	var extra_pierce: int = _perks().extra_penetration() if _perks() else 0
	var last: Node = null
	for i: int in Constants.MAX_RAY_STEPS:
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + offset, Constants.LAYER_WORLD | Constants.LAYER_HITBOX | Constants.LAYER_HAT, exclude)
		query.collide_with_areas = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return
		# Huat obschiaßn: a shot through a hat knocks it off and flies on, maybe into the head.
		var hat := hit.collider as HatBox
		if hat:
			exclude.append(hat.get_rid())
			hat.receiver.knock_hat(offset.normalized(), _shooter)
			continue
		var hurtbox := hit.collider as Hurtbox
		if hurtbox == null:
			_impact_marks.place(hit.position, hit.normal)
			_impact_puffs.play(hit.position, hit.normal)
			return
		exclude.append(hurtbox.get_rid())
		# A hat sitting low in the head's box is met only after the head: through the head, on through it.
		if hurtbox.is_head:
			var wearer := hurtbox.receiver as Enemy
			var direction: Vector3 = offset.normalized()
			if wearer and wearer.hat_in_line(hit.position, hit.position + direction * Constants.HAT_THROUGH_HEAD):
				wearer.knock_hat(direction, _shooter)
		# The ray can cross both boxes (head and body) of one enemy: that is still one body.
		if hurtbox.receiver == last:
			continue
		last = hurtbox.receiver
		var amount: int = roundi(hurtbox.damage_for(_damage(weapon.damage), weapon.headshot_multiplier) * share * _boss_share(hurtbox.receiver, weapon))
		if weapon.one_hit:
			amount = _whole_health(hurtbox.receiver, amount)
		var total: Dictionary = hits.get(hurtbox.receiver, {"amount": 0, "head": false})
		total.amount += amount
		total.head = total.head or hurtbox.is_head
		total.position = hit.position
		total.normal = hit.normal
		hits[hurtbox.receiver] = total
		pierced += 1
		if pierced > weapon.penetration + extra_pierce:
			return
		if weapon.penetration_range > 0.0 and global_position.distance_to(hit.position) > weapon.penetration_range:
			return
		share *= weapon.penetration_falloff


func _spread_direction() -> Vector3:
	var basis: Basis = global_basis
	var forward: Vector3 = -basis.z
	var spread: float = current_spread()
	if spread <= 0.0:
		return forward
	# Uniform over the cone's disc, so shots do not cluster in the middle.
	var radius: float = tan(deg_to_rad(spread)) * sqrt(_rng.randf())
	var angle: float = _rng.randf() * TAU
	return (forward + basis.x * cos(angle) * radius + basis.y * sin(angle) * radius).normalized()


# --- Co-op (M7): a ghost, another player's guns -------------------------------------------------------

## Replays what another player's guns did, from `aim` (their eye, looking along -Z): the shot through
## the weapon's own behavior (shells, sleds, puddles, notes) or as impacts for a plain gun, with its
## sound from there.
func replay(action: Act, data: WeaponData, rounds: int, aim: Transform3D) -> void:
	global_transform = aim
	var behavior: WeaponBehavior = _ghost_behavior(data)
	match action:
		Act.SHOT:
			weapon = data
			if behavior:
				behavior.fire(rounds)
			else:
				for i: int in data.pellets * rounds:
					_ghost_ray()
				_flash()
			_ghost_shot_sound(data, rounds)
		Act.SECONDARY:
			weapon = data
			if behavior:
				behavior.fire_secondary()
			else:
				# The Querschläger.
				_flash()
			play_sound(data.secondary_sound if data.secondary_sound != &"" else data.fire_sound, data.sound_pitch)
		Act.SWING:
			play_sound(data.swing_sound)
		Act.MELEE:
			melee_weapon = data
			if behavior:
				behavior.melee_hit()
		Act.HOLD:
			melee_weapon = data
			if behavior:
				behavior.hold_start()
		Act.RELEASE:
			if behavior:
				behavior.hold_end()


func _ghost_behavior(data: WeaponData) -> WeaponBehavior:
	if not _ghost_behaviors.has(data.id):
		_ghost_behaviors[data.id] = WeaponBehavior.create(data, self)
	return _ghost_behaviors[data.id]


func _ghost_step(delta: float) -> void:
	if _fire_loop_left <= 0.0:
		return
	_fire_loop_left -= delta
	if _fire_loop_left <= 0.0:
		if is_instance_valid(_ghost_loop):
			_ghost_loop.queue_free()
		if _ghost_flame:
			_ghost_flame.emitting = false


func _ghost_shot_sound(data: WeaponData, rounds: int) -> void:
	if data.fire_loop_sound == &"":
		play_sound(data.secondary_sound if rounds > 1 and data.secondary_sound != &"" else data.fire_sound, data.sound_pitch)
		return
	# Held fire (the flame): the start once, the loop and the stream of flame while the shots come.
	if not is_instance_valid(_ghost_loop):
		play_sound(data.fire_sound)
		_ghost_loop = Sound.attach(data.fire_loop_sound, self)
	_fire_loop_left = 2.0 / data.fire_rate
	if _ghost_flame == null:
		_ghost_flame = Flames.particles(48, Constants.GHOST_FLAME_LIFETIME, Vector2(0.4, 0.5))
		_ghost_flame.direction = Vector3.FORWARD
		_ghost_flame.spread = 8.0
		_ghost_flame.gravity = Vector3(0.0, 1.5, 0.0)
		_ghost_flame.position = Vector3(0.15, -0.2, -0.7)
		add_child(_ghost_flame)
	var speed: float = data.range / Constants.GHOST_FLAME_LIFETIME
	_ghost_flame.initial_velocity_min = speed * 0.8
	_ghost_flame.initial_velocity_max = speed
	_ghost_flame.emitting = true


## One pellet for the look: a puff where it hits a body, a mark and dust on a wall.
func _ghost_ray() -> void:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + _spread_direction() * weapon.range, Constants.LAYER_WORLD | Constants.LAYER_HITBOX, _exclude)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	if hit.collider is Hurtbox:
		_hit_puffs.play(hit.position, hit.normal)
		return
	_impact_marks.place(hit.position, hit.normal)
	_impact_puffs.play(hit.position, hit.normal)


## The muzzle lighting up the room for a moment.
func _flash() -> void:
	if _ghost_flash == null:
		_ghost_flash = OmniLight3D.new()
		_ghost_flash.light_color = Color(1.0, 0.8, 0.5)
		_ghost_flash.omni_range = 4.0
		_ghost_flash.position = Vector3(0.15, -0.15, -0.9)
		add_child(_ghost_flash)
	_ghost_flash.light_energy = 3.0
	create_tween().tween_property(_ghost_flash, "light_energy", 0.0, 0.08)
