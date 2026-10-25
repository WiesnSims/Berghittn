class_name Kegelbahn
extends Node3D
## Da Kegelbahn (1.2, GAME_DESIGN section 12): the skittle alley in the Skiraum's boot corridor.
## Nine pins in a diamond at the far end, a ball return with three balls at the line. E at the ball
## return bowls a ball from where the player stands, straight along their look. Each player has three
## balls to clear all nine (the knocked pins are cleared after each ball); cleared, they get da
## Bolingboi. Their balls come back KEGEL_BALLS_BACK waves after the last one.
##
## How the pins fall is worked out, not simulated (roll): the ball rolls straight, a pin it touches
## falls along its way, off to the side it was struck on, and the ball is turned a little off it; a
## falling pin knocks over the standing pins it falls onto (within KEGEL_KNOCK_ANGLE of its fall, at
## most KEGEL_KNOCK_REACH off), and they fall on in turn. The same throw gives the same pins on every
## screen, so co-op sends only the throw (CoopWorld). The host's game (or solo) deals the ball's
## blows to enemies on the lane.
## Built in code. Local -Z runs down the lane; the origin is the middle of the line, on the floor.

## A ball went down the lane (for tests): who, and the pins it knocked over (indices).
signal bowled(peer: int, down: Array[int])
## `peer` cleared all nine (`first`: with the first ball, Alle Neune).
signal cleared(peer: int, first: bool)

const BOLINGBOI: WeaponData = preload("res://data/weapons/bolingboi.tres")
const WOOD: Material = preload("res://assets/materials/wood_dark.tres")
const LANE_WOOD: Material = preload("res://assets/materials/wood_floor.tres")
## Half the lane's width; beyond it is the gutter (a Pudel).
const LANE_HALF: float = 0.62
const GUTTER: float = 0.3
## Where the ball starts (the line) and where the lane ends in the pit.
const LINE_Z: float = -0.3
const PIT_Z: float = -10.9
## The diamond: the front pin, and the spacing of the pins along its sides.
const FRONT_Z: float = -8.9
const SPACING: float = 0.5
const BALL_RADIUS: float = 0.11
const PIN_RADIUS: float = 0.07
const PIN_HEIGHT: float = 0.52
## The ball return (where E is pressed), beside the line.
const RETURN_AT := Vector3(-1.25, 0.0, 0.35)
## Seconds the knocked pins lie before they are cleared, and before a finished set stands up again.
const CLEAR_WAIT: float = 1.2
const RESET_WAIT: float = 1.6
## The middle pin, the König.
const KING: int = 4

## Bowled with one press, not held.
var interact_repeat: float = 0.0
## Which pins stand.
var standing: Array[bool] = []
## The player whose set is running (0: none).
var bowler: int = 0
var _balls: Dictionary = {}
var _back: Dictionary = {}
var _wave: int = 0
var _pins: Array[Node3D] = []
var _pin_spots: Array[Vector3] = []
var _rack_balls: Array[Node3D] = []
var _ball: Node3D
var _board: Label3D
# The ball under way: its path (points, local) and how far along it is; who bowled it, how many
# balls were left before it, the enemies it struck, and pins still to fall: [time, index, direction].
var _path: PackedVector3Array = PackedVector3Array()
var _rolled: float = 0.0
var _rolling: bool = false
var _roll_peer: int = 0
var _first_ball: bool = false
var _struck: Dictionary = {}
var _falls: Array = []
var _roll_time: float = 0.0
# Seconds until the knocked pins are cleared, and until the pins stand up again after a set.
var _clear_left: float = -1.0
var _reset_left: float = -1.0


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("kegelbahnen")
	_build()
	_stand_all()
	_refresh()
	Events.wave_started.connect(_on_wave_started)


# --- Rules -----------------------------------------------------------------------------------------

## Balls `peer` has left now (0 while theirs are away).
func balls_of(peer: int) -> int:
	return 0 if _back.has(peer) else int(_balls.get(peer, Constants.KEGEL_BALLS))


## The wave `peer`'s balls come back in (0 if they have them).
func back_in(peer: int) -> int:
	return int(_back.get(peer, 0))


## Nothing rolls and nothing is being cleared or set up.
func is_free() -> bool:
	return not _rolling and _clear_left < 0.0 and _reset_left < 0.0


func can_bowl(peer: int) -> bool:
	return is_free() and balls_of(peer) > 0


func standing_count() -> int:
	return standing.count(true)


## `peer` bowls from `start` along `direction` (both local, on the lane's level). Every screen calls
## it with the same throw (CoopWorld). False if the lane is not free or they have no ball.
func bowl(peer: int, start: Vector3, direction: Vector3) -> bool:
	if not can_bowl(peer):
		return false
	# Someone else's set stands up fresh: one player at a time.
	if bowler != peer:
		_stand_all()
		bowler = peer
	var left: int = balls_of(peer)
	_first_ball = left == Constants.KEGEL_BALLS
	_balls[peer] = left - 1
	var plan: Dictionary = roll(start, direction, standing)
	_path = plan["path"]
	_falls = plan["falls"]
	_rolled = 0.0
	_roll_time = 0.0
	_rolling = true
	_roll_peer = peer
	_struck.clear()
	_ball.position = _path[0] + Vector3.UP * BALL_RADIUS
	_ball.visible = true
	_refresh()
	Sound.play_at(&"kegel_roll", to_global(start))
	var down: Array[int] = []
	for fall: Array in _falls:
		down.append(fall[1])
	bowled.emit(peer, down)
	return true


## Works out a throw without playing it: where the ball goes (`path`, local points), and the pins that
## fall, each as [distance the ball has rolled when it falls, index, direction (flat)], in order.
## `up`: the pins standing. A pure function of its arguments, so every screen gets the same.
func roll(start: Vector3, direction: Vector3, up: Array[bool]) -> Dictionary:
	var flat := Vector3(direction.x, 0.0, direction.z)
	var dir: Vector3 = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	if dir.z > -0.05:
		dir = Vector3.FORWARD
	var at := Vector3(clampf(start.x, -LANE_HALF + BALL_RADIUS, LANE_HALF - BALL_RADIUS), 0.0, LINE_Z)
	var path := PackedVector3Array([at])
	var falls: Array = []
	var left: Array[bool] = up.duplicate()
	var travelled: float = 0.0
	var gutter: bool = false
	while true:
		# The next pin the ball touches ahead of it, and where the lane or the pit ends its way.
		var best: int = -1
		var best_along: float = INF
		for i: int in _pin_spots.size():
			# In the gutter it passes beside the pins.
			if not left[i] or gutter:
				continue
			var offset: Vector3 = _pin_spots[i] - at
			var along: float = offset.dot(dir)
			if along <= 0.0:
				continue
			var side: float = (offset - dir * along).length()
			if side < BALL_RADIUS + PIN_RADIUS and along < best_along:
				best = i
				best_along = along
		var to_pit: float = (PIT_Z - at.z) / dir.z
		var to_edge: float = INF
		if not gutter and absf(dir.x) > 0.0001:
			var edge: float = (signf(dir.x) * LANE_HALF - at.x) / dir.x
			to_edge = edge if edge > 0.0 else INF
		if best >= 0 and best_along < to_pit and best_along < to_edge:
			# Contact a little short of the pin's middle.
			var reach: float = best_along - sqrt(maxf(pow(BALL_RADIUS + PIN_RADIUS, 2.0) - pow((_pin_spots[best] - at - dir * best_along).length(), 2.0), 0.0))
			at += dir * reach
			travelled += reach
			path.append(at)
			var offset: Vector3 = _pin_spots[best] - at
			var lateral: float = offset.dot(dir.cross(Vector3.UP))
			var share: float = clampf(lateral / (BALL_RADIUS + PIN_RADIUS), -1.0, 1.0)
			# Struck off-centre, it falls off to that side; the ball turns away from it.
			var fall: Vector3 = dir.rotated(Vector3.UP, -share * deg_to_rad(Constants.KEGEL_PIN_TURN))
			left[best] = false
			falls.append([travelled, best, fall])
			_chain(best, fall, travelled, left, falls)
			dir = dir.rotated(Vector3.UP, share * deg_to_rad(Constants.KEGEL_BALL_TURN) * (1.0 - absf(share)) + share * deg_to_rad(2.0))
			continue
		if to_edge < to_pit:
			# Into the gutter: it rolls on beside the lane and hits nothing more.
			at += dir * to_edge
			travelled += to_edge
			path.append(at)
			at.x = signf(at.x) * (LANE_HALF + GUTTER * 0.5)
			at.y = -0.04
			path.append(at)
			dir = Vector3.FORWARD
			gutter = true
			continue
		at += dir * to_pit
		path.append(at)
		break
	falls.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return {"path": path, "falls": falls, "gutter": gutter}


# Pin `index` falls along `fall` (the ball at `travelled`): the standing pins it falls onto go too.
func _chain(index: int, fall: Vector3, travelled: float, left: Array[bool], falls: Array) -> void:
	for i: int in _pin_spots.size():
		if not left[i]:
			continue
		var offset: Vector3 = _pin_spots[i] - _pin_spots[index]
		var distance: float = offset.length()
		if distance > Constants.KEGEL_KNOCK_REACH or rad_to_deg(fall.angle_to(offset)) > Constants.KEGEL_KNOCK_ANGLE:
			continue
		left[i] = false
		var next: Vector3 = (offset.normalized() * 0.7 + fall * 0.3).normalized()
		# A moment later, the further it is.
		var later: float = travelled + distance * 0.6
		falls.append([later, i, next])
		_chain(i, next, later, left, falls)


func _physics_process(delta: float) -> void:
	if _rolling:
		_roll_step(delta)
	if _clear_left >= 0.0:
		_clear_left -= delta
		if _clear_left < 0.0:
			_cleared_away()
	if _reset_left >= 0.0:
		_reset_left -= delta
		if _reset_left < 0.0:
			_stand_all()
			bowler = 0
			_refresh()


func _roll_step(delta: float) -> void:
	_roll_time += delta
	_rolled += Constants.KEGEL_SPEED * delta
	var point: Vector3 = _point_at(_rolled)
	var moved: Vector3 = point - (_ball.position - Vector3.UP * BALL_RADIUS)
	_ball.position = point + Vector3.UP * BALL_RADIUS
	if moved.length() > 0.001:
		_ball.rotate(moved.cross(Vector3.DOWN).normalized(), moved.length() / BALL_RADIUS)
	while not _falls.is_empty() and float(_falls[0][0]) <= _rolled:
		var fall: Array = _falls.pop_front()
		_topple(fall[1], fall[2])
	_strike_enemies()
	if _rolled >= _length():
		_rolling = false
		_ball.visible = false
		for fall: Array in _falls:
			_topple(fall[1], fall[2])
		_falls.clear()
		_clear_left = CLEAR_WAIT


# Where the ball is `distance` along its path.
func _point_at(distance: float) -> Vector3:
	var gone: float = 0.0
	for i: int in range(1, _path.size()):
		var leg: float = _path[i - 1].distance_to(_path[i])
		if gone + leg >= distance:
			return _path[i - 1].lerp(_path[i], (distance - gone) / maxf(leg, 0.0001))
		gone += leg
	return _path[_path.size() - 1]


func _length() -> float:
	var total: float = 0.0
	for i: int in range(1, _path.size()):
		total += _path[i - 1].distance_to(_path[i])
	return total


# Enemies on the lane are bowled over (solo and the host; puppets hear it from the host).
func _strike_enemies() -> void:
	if Coop.is_guest():
		return
	var where: Vector3 = _ball.global_position
	var source: Node3D = Coop.node_of(_roll_peer) if Net.in_match() else get_tree().get_first_node_in_group("player") as Node3D
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive() or _struck.has(enemy) or enemy.data.flies:
			continue
		var offset: Vector3 = enemy.global_position - where
		if Vector2(offset.x, offset.z).length() > Constants.KEGEL_ENEMY_REACH or absf(offset.y) > 1.0:
			continue
		_struck[enemy] = true
		var way: Vector3 = -global_basis.z
		var side: Vector3 = way.cross(Vector3.UP) * (1.0 if offset.dot(way.cross(Vector3.UP)) >= 0.0 else -1.0)
		enemy.receive_hit(Constants.KEGEL_ENEMY_DAMAGE, false, false, source)
		if enemy.is_alive():
			enemy.apply_knockback((way + side).normalized() * Constants.KEGEL_ENEMY_PUSH)


func _topple(index: int, direction: Vector3) -> void:
	standing[index] = false
	var pin: Node3D = _pins[index]
	var axis: Vector3 = Vector3.UP.cross(direction).normalized()
	if axis.length() < 0.5:
		axis = Vector3.RIGHT
	var tween: Tween = pin.create_tween().set_parallel()
	tween.tween_property(pin, "basis", Basis(axis, deg_to_rad(84.0)), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(pin, "position", _pin_spots[index] + direction * 0.12, 0.3)
	Sound.play_at(&"kegel_pins", pin.global_position)


# The knocked pins are cleared; the set goes on, is won, or is over.
func _cleared_away() -> void:
	for i: int in _pins.size():
		if not standing[i]:
			_pins[i].visible = false
	var peer: int = _roll_peer
	if standing_count() == 0:
		_balls[peer] = 0
		_send_back(peer)
		cleared.emit(peer, _first_ball)
		_reward(peer, _first_ball)
		_reset_left = RESET_WAIT
	elif balls_of(peer) <= 0:
		_send_back(peer)
		Events.event_announced.emit(tr("EVENT_KEGEL_OVER") % standing_count())
		_reset_left = RESET_WAIT
	_refresh()


func _send_back(peer: int) -> void:
	_back[peer] = maxi(_wave, 0) + Constants.KEGEL_BALLS_BACK


# The prize, in the bowler's own game; everyone sees the banner.
func _reward(peer: int, first: bool) -> void:
	Events.event_announced.emit(tr("EVENT_KEGEL_NEUNE" if first else "EVENT_KEGEL_CLEARED"))
	Sound.play(&"nadl")
	if peer != _my_peer():
		return
	var player: Player
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			player = node
	if player == null:
		return
	if player.weapons.has_weapon(BOLINGBOI):
		player.weapons.refill_ammo(BOLINGBOI)
	else:
		player.weapons.give_weapon(BOLINGBOI)
	Events.event_announced.emit(tr("EVENT_KEGEL_PRIZE"))


func _on_wave_started(wave: int, _boss: bool) -> void:
	_wave = wave
	for peer: int in _back.keys():
		if wave >= int(_back[peer]):
			_back.erase(peer)
			_balls[peer] = Constants.KEGEL_BALLS
	_refresh()


func _stand_all() -> void:
	standing.clear()
	for i: int in _pins.size():
		standing.append(true)
		var pin: Node3D = _pins[i]
		pin.basis = Basis.IDENTITY
		pin.position = _pin_spots[i]
		pin.visible = true


static func _my_peer() -> int:
	return Net.my_id() if Net.in_match() else 1


# --- Interactable ----------------------------------------------------------------------------------

func get_interact_position() -> Vector3:
	return to_global(RETURN_AT + Vector3.UP * 0.5)


func get_interact_prompt(_player: Node3D) -> String:
	var me: int = _my_peer()
	if not is_free():
		return tr("UI_KEGEL_BUSY")
	if balls_of(me) <= 0:
		return tr("UI_KEGEL_BACK") % back_in(me)
	return tr("UI_KEGEL_BOWL") % [Constants.KEGEL_BALLS - balls_of(me) + 1, Constants.KEGEL_BALLS]


func interact(player: Node3D) -> void:
	var me: int = _my_peer()
	if not can_bowl(me):
		return
	var throw: Array = throw_of(player)
	if Coop.is_guest():
		Coop.world.request_kegel(self, throw[0], throw[1])
		return
	if bowl(me, throw[0], throw[1]) and Coop.is_host() and Coop.world:
		Coop.world.kegel_bowled(self, me, throw[0], throw[1])


## The throw `player` makes from where they stand, along their look: [start, direction], local.
func throw_of(player: Node3D) -> Array:
	var stand: Vector3 = to_local(player.global_position)
	var look: Vector3 = -(player as Player).weapons.global_basis.z if player is Player else -player.global_basis.z
	var local: Vector3 = global_basis.inverse() * look
	return [Vector3(stand.x, 0.0, LINE_Z), Vector3(local.x, 0.0, local.z)]


# --- Look ------------------------------------------------------------------------------------------

func _refresh() -> void:
	var me: int = _my_peer()
	var left: int = balls_of(me)
	for i: int in _rack_balls.size():
		_rack_balls[i].visible = i < left
	if left <= 0:
		_board.text = tr("UI_KEGEL_BOARD_BACK") % back_in(me)
	else:
		_board.text = tr("UI_KEGEL_BOARD") % [left, standing_count()]


func _build() -> void:
	var white := _plain(Color(0.94, 0.92, 0.86))
	var red := _plain(Color(0.72, 0.1, 0.08))
	var dark := _plain(Color(0.09, 0.07, 0.06))
	var ball_wood := _plain(Color(0.36, 0.2, 0.1))
	# The lane, the gutters, the pit.
	_box(Vector3(LANE_HALF * 2.0, 0.02, -PIT_Z), Vector3(0.0, 0.01, PIT_Z * 0.5), LANE_WOOD)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(GUTTER, 0.012, -PIT_Z), Vector3(side * (LANE_HALF + GUTTER * 0.5), 0.006, PIT_Z * 0.5), dark)
		_box(Vector3(0.05, 0.08, -PIT_Z), Vector3(side * (LANE_HALF + GUTTER + 0.025), 0.04, PIT_Z * 0.5), WOOD)
	_box(Vector3(LANE_HALF * 2.0 + GUTTER * 2.0, 0.014, 0.6), Vector3(0.0, 0.007, PIT_Z - 0.3), dark)
	_box(Vector3(LANE_HALF * 2.0 + GUTTER * 2.0 + 0.1, 0.5, 0.06), Vector3(0.0, 0.25, PIT_Z - 0.62), WOOD)
	# The line.
	_box(Vector3(LANE_HALF * 2.0, 0.022, 0.04), Vector3(0.0, 0.011, LINE_Z + 0.1), red)
	# The diamond: front pin first, the König in the middle.
	var corner := Vector3(0.0, 0.0, FRONT_Z)
	var right: Vector3 = Vector3(1.0, 0.0, -1.0).normalized() * SPACING
	var left_: Vector3 = Vector3(-1.0, 0.0, -1.0).normalized() * SPACING
	for row: int in 3:
		for column: int in 3:
			_pin_spots.append(corner + right * column + left_ * row)
	for i: int in _pin_spots.size():
		var pin := _pin(white, red, i == KING)
		pin.position = _pin_spots[i]
		add_child(pin)
		_pins.append(pin)
	# The ball return with the balls waiting.
	_box(Vector3(0.36, 0.5, 1.0), RETURN_AT + Vector3(0.0, 0.25, 0.0), WOOD)
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 14
	sphere.rings = 8
	sphere.material = ball_wood
	for i: int in Constants.KEGEL_BALLS:
		var waiting := MeshInstance3D.new()
		waiting.mesh = sphere
		waiting.position = RETURN_AT + Vector3(0.0, 0.5 + BALL_RADIUS, 0.3 - i * 0.28)
		add_child(waiting)
		_rack_balls.append(waiting)
	_ball = Node3D.new()
	var rolling := MeshInstance3D.new()
	rolling.mesh = sphere
	_ball.add_child(rolling)
	# A stripe, so its roll shows.
	var stripe := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = BALL_RADIUS * 1.02
	band.bottom_radius = BALL_RADIUS * 1.02
	band.height = 0.03
	band.material = _plain(Color(0.85, 0.7, 0.3))
	stripe.mesh = band
	stripe.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_ball.add_child(stripe)
	_ball.visible = false
	add_child(_ball)
	# The sign and the board over the pins, facing the line.
	var sign := _label("Kegelbahn", 0.006, Color(0.95, 0.86, 0.66))
	sign.position = Vector3(0.0, 2.45, FRONT_Z - 1.2)
	add_child(sign)
	_board = _label("", 0.004, Color(1.0, 0.86, 0.45))
	_board.position = Vector3(0.0, 2.05, FRONT_Z - 1.2)
	_board.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_board)
	# A lamp over the pins.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.4
	lamp.omni_range = 4.5
	lamp.position = Vector3(0.0, 2.4, FRONT_Z - 0.7)
	add_child(lamp)


func _pin(white: Material, red: Material, king: bool) -> Node3D:
	var pin := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = PIN_RADIUS * 0.55
	body.bottom_radius = PIN_RADIUS
	body.height = PIN_HEIGHT * 0.72
	body.radial_segments = 12
	body.rings = 1
	body.material = white
	var lower := MeshInstance3D.new()
	lower.mesh = body
	lower.position.y = PIN_HEIGHT * 0.36
	pin.add_child(lower)
	var head := SphereMesh.new()
	head.radius = PIN_RADIUS * 0.72
	head.height = PIN_RADIUS * 1.44
	head.radial_segments = 12
	head.rings = 6
	head.material = red if king else white
	var top := MeshInstance3D.new()
	top.mesh = head
	top.position.y = PIN_HEIGHT * 0.72 + head.radius * 0.55
	pin.add_child(top)
	var ring := CylinderMesh.new()
	ring.top_radius = PIN_RADIUS * 0.62
	ring.bottom_radius = PIN_RADIUS * 0.66
	ring.height = 0.03
	ring.radial_segments = 12
	ring.rings = 1
	ring.material = red
	var band := MeshInstance3D.new()
	band.mesh = ring
	band.position.y = PIN_HEIGHT * 0.62
	pin.add_child(band)
	return pin


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.position = at
	add_child(box)
	return box


func _label(text: String, pixel: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel
	label.font_size = 64
	label.outline_size = 12
	label.modulate = color
	label.outline_modulate = Color(0.12, 0.07, 0.03, 1.0)
	# Faces the line (+Z).
	return label


static func _plain(color: Color) -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return SharedLook.adopt(material)
