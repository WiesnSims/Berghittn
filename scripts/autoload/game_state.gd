extends Node
## Session state that has to survive a scene reload (restart after death).

## True once the player clicked past the title screen; restarts skip it.
var has_started: bool = false
## Shown on the title screen after a reload, e.g. why a co-op match ended.
var notice: String = ""
## The ?room= invite link only opens the lobby on the first load, not after every reload.
var invite_used: bool = false
## Co-op: after a match, the reloaded scene opens the room's lobby, or (the host already started the
## next one) goes straight into the new match.
var open_lobby: bool = false
var pending_match: bool = false
## Play with friends (solo end screen): the reloaded scene opens a new room's lobby.
var create_room: bool = false
