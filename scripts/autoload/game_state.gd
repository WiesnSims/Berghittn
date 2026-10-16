extends Node
## Session state that has to survive a scene reload (restart after death).

## True once the player clicked past the title screen; restarts skip it.
var has_started: bool = false
