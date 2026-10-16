class_name Constants
extends RefCounted
## Single home for gameplay numbers that are not (yet) part of a data resource.

# Player movement, in metres, seconds and radians.
const PLAYER_WALK_SPEED: float = 4.0
const PLAYER_SPRINT_SPEED: float = 6.5
const PLAYER_CROUCH_SPEED: float = 2.0
const PLAYER_JUMP_VELOCITY: float = 4.5
const PLAYER_GROUND_ACCEL: float = 40.0
# Low air control keeps jumps committed but still lets players correct slightly.
const PLAYER_AIR_ACCEL: float = 8.0
const PLAYER_STAND_HEIGHT: float = 1.8
const PLAYER_CROUCH_HEIGHT: float = 1.1
const PLAYER_EYE_BELOW_TOP: float = 0.15
# Crouch blend per second (0 = standing, 1 = crouched).
const PLAYER_CROUCH_BLEND_SPEED: float = 8.0
const PLAYER_MAX_PITCH_DEG: float = 89.0
# Safety net if the player ever clips out of the map.
const PLAYER_FALL_RESPAWN_Y: float = -20.0

# Radians of view rotation per screen pixel of mouse movement.
const DEFAULT_MOUSE_SENSITIVITY: float = 0.0025
const DEFAULT_LOCALE: String = "en"

# Chrome refuses a new pointer lock for about a second after the user pressed Esc to exit one.
const POINTER_RELOCK_DELAY: float = 1.2
const DEBUG_OVERLAY_REFRESH: float = 0.25
