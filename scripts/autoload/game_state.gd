extends Node
## Session state that has to survive a scene reload (restart after death).

## True once the player clicked past the title screen; restarts skip it.
var has_started: bool = false
## Shown on the title screen after a reload, e.g. why a co-op match ended.
var notice: String = ""
## The ?room= invite link only opens the lobby on the first load, not after every reload.
var invite_used: bool = false
