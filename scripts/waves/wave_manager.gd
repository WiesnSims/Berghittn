class_name WaveManager
extends Node3D
## Runs the waves: countdown, spawning at the active spawn points, and the break once every enemy is dead.
## Enemies are pooled because instancing during combat causes hitches in web builds.
## Now and then the Venedigermandl (M9 part 5a) turns up as well, outside the wave count: the wave
## ends without him.
## Sitzfleisch (1.1.2): a player who stays put too long in a wave gets a Wilderer and a few
## Bergdohlen sent after them (on top of the wave), a banner and a taunt.
## Die Bsundan (1.2): from VARIANT_FIRST_WAVE a normal spawn is now and then a rare variant instead,
## at most one alive; the Bergführer brings his Seilschaft from the wave along. "Bsundane Woch!"
## (1.2 extras, an EventDirector event) raises the chance for the rest of a wave.

enum Phase { BREAK, SPAWNING, CLEARING }

@export var enemy_scene: PackedScene
@export var wave_table: WaveTable
@export var zones: ZoneMap

## Current wave number; 0 before wave 1 starts.
var wave: int = 0
var _phase: Phase = Phase.BREAK
var _break_left: float = Constants.FIRST_WAVE_DELAY
var _to_spawn: int = 0
var _alive: int = 0
var _spawn_left: float = 0.0
# Pooled per enemy type: re-dressing a body as another type rebuilds its model, which hitches.
var _pools: Dictionary = {}
# Boss wave: the exact enemies still to come, boss first; empty in normal waves.
var _queue: Array[EnemyData] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Seconds until the Venedigermandl comes this wave (below 0: not this wave), and the one about.
var _mandl_left: float = -1.0
var _mandl: Enemy
# Sitzfleisch: per player, where they settled and seconds they have stayed within SITZ_RADIUS of it.
var _sitz: Dictionary = {}
const WILDERER: EnemyData = preload("res://data/enemies/wilderer.tres")
const DOHLE: EnemyData = preload("res://data/enemies/bergdohle.tres")
# The variant about now (if it still lives), and the last one sent (not twice in a row).
var _variant: Enemy
var _last_variant: EnemyData
## This wave's chance of a variant per spawn (Bsundane Woch raises it until the wave ends).
var variant_chance: float = Constants.VARIANT_CHANCE


func _ready() -> void:
	add_to_group("wave_manager")
	_rng.randomize()
	# Deferred so the HUD, which is set up after the world, hears the first countdown.
	Events.wave_break_started.emit.call_deferred(1, _break_left)


## Co-op (M7): the countdown to the next wave starts over at `delay` (the first wave waits for
## everyone to click into the match).
func begin_break(delay: float) -> void:
	_phase = Phase.BREAK
	_break_left = delay
	Events.wave_break_started.emit(wave + 1, delay)


func _physics_process(delta: float) -> void:
	_watch_sitzfleisch(delta)
	if _mandl_left > 0.0:
		_mandl_left -= delta
		if _mandl_left <= 0.0:
			send_mandl()
	match _phase:
		Phase.BREAK:
			_break_left -= delta
			if _break_left <= 0.0:
				_start_wave(wave + 1)
		Phase.SPAWNING:
			_spawn_left -= delta
			if _spawn_left <= 0.0 and _alive < Constants.MAX_ALIVE_ENEMIES:
				_spawn_left = wave_table.spawn_interval(wave)
				_spawn()


func _start_wave(number: int) -> void:
	wave = number
	variant_chance = Constants.VARIANT_CHANCE
	_queue.clear()
	if wave_table.is_boss_wave(wave):
		_queue.append(wave_table.boss)
		for i: int in wave_table.boss_escort_count:
			_queue.append(wave_table.boss_escort)
		_to_spawn = _queue.size()
	else:
		_to_spawn = wave_table.enemy_count(wave, get_tree().get_nodes_in_group("player").size())
	_mandl_left = -1.0
	if wave >= Constants.MANDL_FIRST_WAVE and not wave_table.is_boss_wave(wave) and wave_table.treasure \
			and _rng.randf() < Constants.MANDL_CHANCE:
		_mandl_left = _rng.randf_range(Constants.MANDL_DELAY_MIN, Constants.MANDL_DELAY_MAX)
	# First enemy right away: the countdown already was the wait.
	_spawn_left = 0.0
	_phase = Phase.SPAWNING
	Events.wave_started.emit(wave, wave_table.is_boss_wave(wave))


func _spawn() -> void:
	var point: Node3D = _pick_spawn_point()
	var queued: bool = not _queue.is_empty()
	var data: EnemyData = _queue.pop_front() if queued else wave_table.pick_enemy(wave, _rng)
	if point == null or data == null:
		push_warning("Wave %d: no spawn point or no enemy type; skipping a spawn." % wave)
		_count_spawned()
		return
	if not queued and not data.flies:
		var variant: EnemyData = _roll_variant()
		if variant:
			var angle: float = _rng.randf() * TAU
			var at: Transform3D = point.global_transform.translated(Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf() * Constants.SPAWN_SCATTER_RADIUS)
			var room: int = mini(_to_spawn, Constants.MAX_ALIVE_ENEMIES - _alive)
			for i: int in send_variant(variant, at, room - 1).size():
				_count_spawned()
			return
	# A flock of birds (the Bergdohlen) comes at once, high up, each one of the wave and of the alive.
	var count: int = 1
	if data.flies:
		count = clampi(_rng.randi_range(data.flock_min, data.flock_max), 1, mini(_to_spawn, Constants.MAX_ALIVE_ENEMIES - _alive))
	for i: int in count:
		var pool: Array = _pools.get(data.id, [])
		var enemy: Enemy = pool.pop_back() if not pool.is_empty() else _create_enemy()
		var angle: float = _rng.randf() * TAU
		var scatter := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf() * Constants.SPAWN_SCATTER_RADIUS
		if data.flies:
			scatter = Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf() * Constants.DOHLE_SPAWN_SCATTER + Vector3.UP * Constants.DOHLE_SPAWN_HEIGHT
		enemy.activate(data, wave, point.global_transform.translated(scatter))
		_alive += 1
		_count_spawned()


# A rare variant instead of this spawn, now and then (null: not this time).
func _roll_variant() -> EnemyData:
	if wave < Constants.VARIANT_FIRST_WAVE or wave_table.is_boss_wave(wave) or variant_about():
		return null
	if _rng.randf() >= variant_chance:
		return null
	var data: EnemyData = wave_table.pick_variant(wave, _last_variant, _rng)
	if data:
		_last_variant = data
	return data


## How many enemies of this wave are still to come.
func still_to_spawn() -> int:
	return _to_spawn if _phase == Phase.SPAWNING else 0


## A rare variant is alive now.
func variant_about() -> bool:
	return is_instance_valid(_variant) and _variant.is_alive() and _variant.data.variant != null


## Sends the variant `data` in at `at` (also used by tests), with up to `room` of its base enemy along
## if it brings any (the Bergführer's Seilschaft, lined up behind him). Returns everyone sent, the
## variant first; each counts as alive in the wave.
func send_variant(data: EnemyData, at: Transform3D, room: int = 0) -> Array[Enemy]:
	var sent: Array[Enemy] = [_take(data, at)]
	_variant = sent[0]
	var along: Array[Enemy] = []
	var behind: Vector3 = at.basis.z.normalized()
	for i: int in mini(_variant.variant.followers(), maxi(room, 0)):
		along.append(_take(data.variant_of, at.translated(behind * Constants.SEIL_GAP * (i + 1))))
	if not along.is_empty():
		_variant.variant.escort(along)
	sent.append_array(along)
	return sent


# One more enemy of the wave, out of the pool.
func _take(data: EnemyData, at: Transform3D) -> Enemy:
	var pool: Array = _pools.get(data.id, [])
	var enemy: Enemy = pool.pop_back() if not pool.is_empty() else _create_enemy()
	enemy.activate(data, wave, at)
	_alive += 1
	return enemy


## The Venedigermandl turns up now (also used by tests), at a spawn point of an open zone at least
## MANDL_SPAWN_DISTANCE from every player and walkable from one (no window or player blocker on the
## way), or else at such a spot anywhere players can walk. At most one at a time; null if there is
## one already or no place for him.
func send_mandl() -> Enemy:
	if wave_table.treasure == null or (is_instance_valid(_mandl) and _mandl.is_alive() and _mandl.data.treasure):
		return null
	var at: Vector3 = _mandl_spot()
	if at == Vector3.INF:
		return null
	var data: EnemyData = wave_table.treasure
	var pool: Array = _pools.get(data.id, [])
	_mandl = pool.pop_back() if not pool.is_empty() else _create_enemy()
	_mandl.activate(data, maxi(wave, 1), Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at))
	return _mandl


# Sitzfleisch: who has stayed put long enough in this wave gets company.
func _watch_sitzfleisch(delta: float) -> void:
	if wave < Constants.SITZ_FIRST_WAVE or _phase == Phase.BREAK:
		_sitz.clear()
		return
	for node: Variant in _sitz.keys():
		if not is_instance_valid(node):
			_sitz.erase(node)
	for node: Node in get_tree().get_nodes_in_group("player"):
		var player := node as Node3D
		if player == null or not player.is_targetable():
			_sitz.erase(node)
			continue
		var settled: Array = _sitz.get(player, [player.global_position, 0.0])
		if player.global_position.distance_to(settled[0]) > Constants.SITZ_RADIUS:
			settled = [player.global_position, 0.0]
		else:
			settled[1] += delta
		if settled[1] >= Constants.SITZ_TIME:
			settled = [player.global_position, 0.0]
			sitzfleisch(player)
		_sitz[player] = settled


## A Wilderer and SITZ_FLOCK Bergdohlen go after `player` from the spawn point nearest them (at least
## SITZ_SPAWN_MIN away), counted
## in the wave; everyone sees a banner and the enemy nearest them mocks them. Returns who was sent.
func sitzfleisch(player: Node3D) -> Array[Enemy]:
	var sent: Array[Enemy] = []
	var point: Node3D = _spawn_point_near(player.global_position)
	if point == null:
		return sent
	sent.append(_send(WILDERER, point.global_transform, player))
	for i: int in Constants.SITZ_FLOCK:
		var angle: float = _rng.randf() * TAU
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * _rng.randf() * Constants.DOHLE_SPAWN_SCATTER + Vector3.UP * Constants.DOHLE_SPAWN_HEIGHT
		sent.append(_send(DOHLE, point.global_transform.translated(offset), player))
	if Net.in_match():
		Coop.announce("EVENT_SITZ_COOP", [Coop.name_of(Coop.peer_of(player))])
	else:
		Events.event_announced.emit(tr("EVENT_SITZ"))
	var mocker: Enemy = null
	for child: Node in get_children():
		var enemy := child as Enemy
		if enemy == null or not enemy.is_alive() or enemy.data.treasure or enemy.data.flies or enemy in sent:
			continue
		if enemy.global_position.distance_to(player.global_position) > Constants.GREDN_REACH:
			continue
		if mocker == null or enemy.global_position.distance_to(player.global_position) < mocker.global_position.distance_to(player.global_position):
			mocker = enemy
	if mocker and Gredn.current:
		Gredn.current.taunt(mocker)
	return sent


# One more enemy of the wave, out of the pool, going for `target`.
func _send(data: EnemyData, at: Transform3D, target: Node3D) -> Enemy:
	var pool: Array = _pools.get(data.id, [])
	var enemy: Enemy = pool.pop_back() if not pool.is_empty() else _create_enemy()
	enemy.activate(data, wave, at)
	enemy.focus = target
	_alive += 1
	return enemy


# The nearest open spawn point at least SITZ_SPAWN_MIN from `at`, else the nearest at all.
func _spawn_point_near(at: Vector3) -> Node3D:
	var best: Node3D = null
	var closest: Node3D = null
	for node: Node in get_tree().get_nodes_in_group("spawn_points"):
		var point := node as SpawnPoint
		if point == null or not zones.is_spawn_active(point.zone):
			continue
		var distance: float = point.global_position.distance_to(at)
		if closest == null or distance < closest.global_position.distance_to(at):
			closest = point
		if distance >= Constants.SITZ_SPAWN_MIN and (best == null or distance < best.global_position.distance_to(at)):
			best = point
	return best if best else closest


func _mandl_spot() -> Vector3:
	var players: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node.has_method("is_targetable") and node.call("is_targetable"):
			players.append(node as Node3D)
	if players.is_empty():
		return Vector3.INF
	var world: World3D = get_world_3d()
	var far := func(spot: Vector3) -> bool:
		return players.all(func(p: Node3D) -> bool: return p.global_position.distance_to(spot) >= Constants.MANDL_SPAWN_DISTANCE)
	var points: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group("spawn_points"):
		var point := node as SpawnPoint
		if point and zones.is_unlocked(point.zone):
			points.append(point.global_position)
	points.shuffle()
	for spot: Vector3 in points:
		if far.call(spot) and players.any(func(p: Node3D) -> bool: return EventDirector.walkable(world, p.global_position, spot)):
			return spot
	for i: int in 8:
		var spot: Vector3 = EventDirector.reachable_spot(world, players.pick_random().global_position,
				Constants.MANDL_SPAWN_DISTANCE, Constants.MANDL_SPAWN_DISTANCE * 2.0)
		if spot != Vector3.INF and far.call(spot):
			return spot
	return Vector3.INF


func _count_spawned() -> void:
	_to_spawn -= 1
	if _to_spawn <= 0:
		_phase = Phase.CLEARING
		_check_cleared()


func _pick_spawn_point() -> Node3D:
	# Only points of open zones and their neighbours (section 4), so enemies come from near the players.
	var points: Array[SpawnPoint] = []
	for node: Node in get_tree().get_nodes_in_group("spawn_points"):
		var point := node as SpawnPoint
		if point and zones.is_spawn_active(point.zone):
			points.append(point)
	if points.is_empty():
		return null
	return points[_rng.randi() % points.size()]


func _check_cleared() -> void:
	if _phase != Phase.CLEARING or _alive > 0:
		return
	_phase = Phase.BREAK
	_break_left = wave_table.break_time
	Events.wave_cleared.emit(wave)
	Events.wave_break_started.emit(wave + 1, _break_left)


func _create_enemy() -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.despawned.connect(_on_enemy_despawned)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	# The Venedigermandl was never counted.
	if enemy.data.treasure:
		return
	_alive -= 1
	_check_cleared()


func _on_enemy_despawned(enemy: Enemy) -> void:
	if not _pools.has(enemy.data.id):
		_pools[enemy.data.id] = []
	_pools[enemy.data.id].append(enemy)
