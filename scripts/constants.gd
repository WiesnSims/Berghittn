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
const DEFAULT_MOUSE_SENSITIVITY: float = 0.002
const DEFAULT_LOCALE: String = "en"

# Chrome refuses a new pointer lock for about a second after the user pressed Esc to exit one.
const POINTER_RELOCK_DELAY: float = 1.2
const DEBUG_OVERLAY_REFRESH: float = 0.25

# Physics layer bitmasks (see README "Physics layers").
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 4
const LAYER_PLAYER_BLOCKER: int = 8
const LAYER_HITBOX: int = 16

# Player health.
const PLAYER_MAX_HEALTH: int = 100
const PLAYER_REGEN_PER_SECOND: float = 10.0
const PLAYER_REGEN_DELAY: float = 5.0
# Time the camera takes to drop to the floor, and the pause before the death screen shows.
const PLAYER_DEATH_FALL_TIME: float = 0.8
const DEATH_SCREEN_DELAY: float = 1.6

# Enemy AI.
# Re-pathing every physics frame is wasted work with 24 enemies; the player does not move that far in 0.25 s.
const ENEMY_REPATH_INTERVAL: float = 0.25
const ENEMY_TURN_SPEED: float = 8.0
const ENEMY_CORPSE_TIME: float = 5.0
const ENEMY_DEATH_FALL_TIME: float = 0.6
# Window entry: height of the window centre above the inside floor (sill 0.9 m + half of the 1.2 m
# opening), how far from the wall centre the enemy stands to start its dive and lands inside,
# and the root height that puts a body lying face down on the floor.
const ENEMY_WINDOW_DIVE_HEIGHT: float = 1.5
const ENEMY_WINDOW_STAND_OFF: float = 0.75
const ENEMY_LYING_HEIGHT: float = 0.2
# Vertical distance beyond which a melee swing cannot reach (player on a table, enemy below).
const ENEMY_ATTACK_MAX_HEIGHT: float = 1.4

# Seconds to walk the last bit from the link start to the window.
const ENEMY_WINDOW_APPROACH_TIME: float = 0.3

# Waves (section 8; the per-wave formula numbers live in data/wave_table.tres).
# Hard performance cap from section 3, shared by all players in co-op.
const MAX_ALIVE_ENEMIES: int = 24
# Countdown before wave 1, so the player can look around first.
const FIRST_WAVE_DELAY: float = 5.0
# Enemies spawn scattered around their marker instead of stacked inside each other.
const SPAWN_SCATTER_RADIUS: float = 1.2
const WAVE_BANNER_TIME: float = 3.0

# Points (section 8).
const POINTS_HIT: int = 10
const POINTS_KILL_BODY: int = 60
const POINTS_KILL_HEADSHOT: int = 100
const POINTS_KILL_MELEE: int = 130
const POINTS_REPAIR_BOARD: int = 10
const POINTS_POPUP_TIME: float = 0.9

# Barricades (section 4).
const BARRICADE_MAX_BOARDS: int = 6
# Seconds per board while E is held.
const BARRICADE_REPAIR_INTERVAL: float = 0.6
# Distance from the repair spot inside the window within which E works.
const INTERACT_RANGE: float = 1.7

# Weapon feedback.
const MUZZLE_FLASH_TIME: float = 0.05
const IMPACT_MARK_COUNT: int = 32
const IMPACT_MARK_LIFETIME: float = 8.0
const HIT_MARKER_TIME: float = 0.15
const DAMAGE_FLASH_TIME: float = 0.4

# Quick melee: share of the swing time before the blow lands, and the fan of rays it checks
# (degrees: x = yaw, y = pitch, from the centre of the view).
const MELEE_HIT_FRACTION: float = 0.3
const MELEE_RAY_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(-12, 0), Vector2(12, 0), Vector2(0, -10), Vector2(0, 8)]
