class_name PlayerState
extends EntityState

## Subject #24. Stores encapsulated momentum, flow window, take-start position, and optical decoy state.

const NO_RECENT_MOTION: int = -1

var _tier: Types.SpeedTier = Types.SpeedTier.BASE
var _take_start_position: Vector2i = Vector2i.ZERO
var _enemy_target_position: Vector2i = Vector2i.ZERO
var _has_decoy: bool = false
var _decoy_position: Vector2i = Vector2i.ZERO
var _motion_frames_this_take: int = 0
var _idle_frames_streak: int = 0
var _frames_since_last_motion: int = NO_RECENT_MOTION
var _promoted_this_take: bool = false


# --- Read-Only Properties ---

var tier: Types.SpeedTier:
	get: return _tier

## True starting tile of the current take (used by Rewind).
var take_start_position: Vector2i:
	get: return _take_start_position

## Tile that enemies believe is the player's take-start position during a take (used by mid-take Scrambles).
var enemy_target_position: Vector2i:
	get: return _enemy_target_position

## Tile enemies believe the player is starting the next take from (used by EnemyIntentGenerator).
var perceived_start_position: Vector2i:
	get: return _decoy_position if _has_decoy else _grid_position

var has_decoy: bool:
	get: return _has_decoy

var decoy_position: Vector2i:
	get: return _decoy_position

var motion_frames_this_take: int:
	get: return _motion_frames_this_take

var idle_frames_streak: int:
	get: return _idle_frames_streak

var frames_since_last_motion: int:
	get: return _frames_since_last_motion

var promoted_this_take: bool:
	get: return _promoted_this_take


# --- Queries ---

## Returns true if the player's current strike qualifies for the Flow bonus.
## At TIER_3, all strikes have Flow unconditionally.
func has_flow(p_config: CombatConfig) -> bool:
	if _tier >= Types.SpeedTier.TIER_3:
		return true
	if _tier <= Types.SpeedTier.BASE or _frames_since_last_motion == NO_RECENT_MOTION:
		return false
	return _frames_since_last_motion <= p_config.get_flow_window_frames(_tier)


# --- Encapsulated API ---

func set_position_and_direction(p_pos: Vector2i, p_dir: Types.Direction) -> void:
	super.set_position_and_direction(p_pos, p_dir)
	_take_start_position = p_pos
	if not _has_decoy:
		_enemy_target_position = p_pos


## Called at Frame 0 of a new take.
## Locks in _take_start_position (for Rewind) and _enemy_target_position (consuming any prior-take Decoy).
func begin_take() -> void:
	_take_start_position = _grid_position
	_enemy_target_position = perceived_start_position
	_has_decoy = false
	_reset_momentum_counters()
	_promoted_this_take = false


## Stamps a Negative Exposure optical decoy that redirects enemy scrambles and next-take intents.
func place_decoy(p_pos: Vector2i) -> void:
	_has_decoy = true
	_decoy_position = p_pos
	_enemy_target_position = p_pos


func set_tier(p_tier: Types.SpeedTier) -> void:
	_tier = p_tier


func promote_tier() -> void:
	if _tier < Types.SpeedTier.TIER_3:
		_tier = (int(_tier) + 1) as Types.SpeedTier
		_promoted_this_take = true


## Drops speed tier and resets all per-take motion, idle, and flow counters.
func drop_tier(p_levels: int = 1) -> void:
	_tier = maxi(int(_tier) - p_levels, int(Types.SpeedTier.BASE)) as Types.SpeedTier
	_reset_momentum_counters()


func record_motion_frame() -> void:
	_motion_frames_this_take += 1
	_idle_frames_streak = 0
	_frames_since_last_motion = 0


func add_bonus_motion_frames(p_frames: int) -> void:
	if p_frames > 0:
		_motion_frames_this_take += p_frames


## Called when an EDIT card occupies Track 0: pauses _idle_frames_streak (neither increments
## nor resets), while _frames_since_last_motion for Flow still ticks up.
func record_edit_pause_frame() -> void:
	if _frames_since_last_motion != NO_RECENT_MOTION:
		_frames_since_last_motion += 1


func record_idle_frame() -> void:
	_idle_frames_streak += 1
	if _frames_since_last_motion != NO_RECENT_MOTION:
		_frames_since_last_motion += 1


func reset_idle_streak() -> void:
	_idle_frames_streak = 0


## Applies a physics violation: drops to Tier 0, resets all counters, and freezes for p_freeze_frames.
func apply_violation(p_freeze_frames: int) -> void:
	drop_tier(int(Types.SpeedTier.TIER_3))
	freeze_for_frames(p_freeze_frames)


func clone() -> PlayerState:
	var copy: PlayerState = PlayerState.new()
	copy_base_to(copy)
	copy._tier = _tier
	copy._take_start_position = _take_start_position
	copy._enemy_target_position = _enemy_target_position
	copy._has_decoy = _has_decoy
	copy._decoy_position = _decoy_position
	copy._motion_frames_this_take = _motion_frames_this_take
	copy._idle_frames_streak = _idle_frames_streak
	copy._frames_since_last_motion = _frames_since_last_motion
	copy._promoted_this_take = _promoted_this_take
	return copy


# --- Private Helpers ---

func _reset_momentum_counters() -> void:
	_motion_frames_this_take = 0
	_idle_frames_streak = 0
	_frames_since_last_motion = NO_RECENT_MOTION
