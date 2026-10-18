class_name ReviveSpot
extends Node3D
## Where a downed teammate lies (M7, section 10): hold E within reach for COOP_REVIVE_TIME to get them
## up. Lets go for longer than a tick or two and it starts over. Under that teammate's hiker.

## The Interactor calls interact() this often while E is held.
var interact_repeat: float = Constants.COOP_REVIVE_TICK
var _hiker: Hiker
var _progress: float = 0.0
var _since_tick: float = INF


func _init(hiker: Hiker) -> void:
	_hiker = hiker


func _ready() -> void:
	add_to_group("interactables")


func _process(delta: float) -> void:
	_since_tick += delta
	if _since_tick > Constants.COOP_REVIVE_HEARD_TIME:
		_progress = 0.0


# Interactable interface (see Interactor).

func get_interact_position() -> Vector3:
	return global_position


func get_interact_prompt(_player: Node3D) -> String:
	if _hiker.life != Player.Life.DOWNED:
		return ""
	var name: String = HikerStyle.display_name(Net.roster.get(_hiker.peer, {}), _hiker.peer)
	if _progress <= 0.0:
		return tr("UI_COOP_REVIVE") % name
	return tr("UI_COOP_REVIVING") % [name, roundi(_progress / Constants.COOP_REVIVE_TIME * 100.0)]


func interact(_player: Node3D) -> void:
	if _hiker.life != Player.Life.DOWNED or Coop.players == null:
		return
	if _since_tick > Constants.COOP_REVIVE_HEARD_TIME:
		_progress = 0.0
	_since_tick = 0.0
	_progress += Constants.COOP_REVIVE_TICK
	if _progress >= Constants.COOP_REVIVE_TIME:
		_progress = 0.0
		Coop.players.revive(_hiker.peer)
	else:
		Coop.players.revive_tick(_hiker.peer, _progress / Constants.COOP_REVIVE_TIME)
