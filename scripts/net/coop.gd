class_name Coop
extends RefCounted
## Where the co-op match's parts live (M7): set by CoopPlayers, CoopEnemies and CoopWorld while a
## match runs in this scene, null otherwise. Gameplay code asks is_guest() before doing something
## the host decides (a door, a board, the chest) and hands it to the host instead.

static var players: CoopPlayers
static var enemies: CoopEnemies
static var world: CoopWorld
static var events: CoopEvents


## A banner (a translation key, with `args` for its %s) on this screen and, from the host, on every
## guest's too; `except_peer` does not get it (they had a banner of their own). Solo: just here.
static func announce(key: String, args: Array = [], except_peer: int = 0) -> void:
	if except_peer == 0 or not Net.in_match() or except_peer != Net.my_id():
		var text: String = TranslationServer.translate(key)
		Events.event_announced.emit(text % args if not args.is_empty() else text)
	if is_host() and events:
		events.say(key, args, except_peer)


## A player's name as the lobby shows it.
static func name_of(peer: int) -> String:
	return HikerStyle.display_name(Net.roster.get(peer, {}), peer)


## A co-op match runs and the host decides the world.
static func is_host() -> bool:
	return world != null and Net.in_match() and Net.is_host()


## A co-op match runs and this browser is a guest: the world is the host's.
static func is_guest() -> bool:
	return world != null and Net.in_match() and not Net.is_host()


## The peer a node stands for: 1.. for our own Player or another player's hiker, 0 for anything else
## (an event, a barrel).
static func peer_of(node: Node) -> int:
	return players.peer_of(node) if players else 0


## Our own Player for our peer, that peer's hiker otherwise, null for 0 or a stranger.
static func node_of(peer: int) -> Node3D:
	return players.node_of(peer) if players else null
