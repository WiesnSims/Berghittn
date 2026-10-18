class_name Coop
extends RefCounted
## Where the co-op match's parts live (M7): set by CoopPlayers, CoopEnemies and CoopWorld while a
## match runs in this scene, null otherwise. Gameplay code asks is_guest() before doing something
## the host decides (a door, a board, the chest) and hands it to the host instead.

static var players: CoopPlayers
static var enemies: CoopEnemies
static var world: CoopWorld


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
