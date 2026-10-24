class_name TimelinePlan
extends RefCounted

## Every clip the player has scheduled for one take.
## Clip durations are resolved once, at planning time, through CardCostResolver.

const TRACK_MOTION: int = 0
const TRACK_ACTION: int = 1

var _config: CombatConfig
## The player's tier when this take was planned. Locks card costs for the whole take.
var _planning_tier: Types.SpeedTier
var _blocks: Array[TimelineBlock] = []


func _init(p_config: CombatConfig, p_planning_tier: Types.SpeedTier = Types.SpeedTier.BASE) -> void:
	assert(p_config != null, "TimelinePlan requires a CombatConfig.")
	_config = p_config
	_planning_tier = p_planning_tier


# --- Read-Only Properties ---

var config: CombatConfig:
	get: return _config

var planning_tier: Types.SpeedTier:
	get: return _planning_tier

## A shallow copy is enough: TimelineBlocks are immutable.
var blocks: Array[TimelineBlock]:
	get: return _blocks.duplicate()

## Counts frames where Track 0 has a MOTION block and is not locked by Hold Frame.
var total_motion_frames: int:
	get:
		var count: int = 0
		for f: int in range(_config.total_frames):
			if is_hold_frame_active(f):
				continue
			var m_block: TimelineBlock = get_block_at(TRACK_MOTION, f)
			if m_block != null and m_block.card.family == Types.CardFamily.MOTION:
				count += 1
		return count

## Planning-time estimate of whether this plan has enough motion frames to promote to the next tier.
var qualifies_for_tier_promotion: bool:
	get:
		var threshold: int = _config.get_promotion_threshold(_planning_tier)
		return threshold > 0 and total_motion_frames >= threshold


# --- Block Creation & Validation ---

func create_block(
	p_card: CardData,
	p_track: int,
	p_start_frame: int,
	p_direction: Types.Direction = Types.Direction.NORTH,
	p_target_enemy_id: int = -1
) -> TimelineBlock:
	var duration: int = CardCostResolver.resolve(p_card, _planning_tier, _config)
	var steps: Array[int] = CardCostResolver.resolve_step_frames(p_card, _planning_tier)
	return TimelineBlock.new(p_card, p_track, p_start_frame, duration, p_direction, p_target_enemy_id, steps)


func can_place(p_block: TimelineBlock) -> bool:
	if p_block.start_frame < 0 or p_block.end_frame >= _config.total_frames:
		return false
	if not _is_track_legal(p_block.card.family, p_block.track_index):
		return false
	for existing: TimelineBlock in _blocks:
		if existing != p_block and existing.overlaps_with(p_block):
			return false
	return true


func add_block(p_block: TimelineBlock) -> bool:
	if not can_place(p_block):
		return false
	_blocks.append(p_block)
	return true


func remove_block(p_block: TimelineBlock) -> void:
	_blocks.erase(p_block)


func clear() -> void:
	_blocks.clear()


func get_block_at(p_track: int, p_frame: int) -> TimelineBlock:
	for b: TimelineBlock in _blocks:
		if b.track_index == p_track and b.occupies_frame(p_frame):
			return b
	return null


## True during the entire duration of a Hold Frame block on either track (locks steps & strikes).
func is_hold_frame_active(p_frame: int) -> bool:
	var m_block: TimelineBlock = get_block_at(TRACK_MOTION, p_frame)
	if m_block != null and m_block.card.holds_frame_and_dodges:
		return true
	var a_block: TimelineBlock = get_block_at(TRACK_ACTION, p_frame)
	return a_block != null and a_block.card.holds_frame_and_dodges


## True on the active dodge frame(s) (edit_frames) of a Hold Frame block on either track.
func is_phase_dodge_active(p_frame: int) -> bool:
	var m_block: TimelineBlock = get_block_at(TRACK_MOTION, p_frame)
	if m_block != null and m_block.card.holds_frame_and_dodges and m_block.is_edit_frame(p_frame):
		return true
	var a_block: TimelineBlock = get_block_at(TRACK_ACTION, p_frame)
	return a_block != null and a_block.card.holds_frame_and_dodges and a_block.is_edit_frame(p_frame)


## Preview check: MOTION resets the idle counter, EDIT / Hold Frame pauses it, empty frames increment it.
func has_momentum_bleed_gap() -> bool:
	var idle_frames: int = 0
	for f: int in range(_config.total_frames):
		if is_hold_frame_active(f):
			continue
		var block: TimelineBlock = get_block_at(TRACK_MOTION, f)
		if block == null:
			idle_frames += 1
			if idle_frames >= _config.momentum_bleed_idle_frames:
				return true
		elif block.card.family == Types.CardFamily.MOTION:
			idle_frames = 0
	return false


func clone() -> TimelinePlan:
	var copy: TimelinePlan = TimelinePlan.new(_config, _planning_tier)
	copy._blocks = _blocks.duplicate()
	return copy


# --- Private Helpers ---

## Motion cards go on the motion track, action cards on the action track, edit cards on either.
func _is_track_legal(p_family: Types.CardFamily, p_track: int) -> bool:
	match p_family:
		Types.CardFamily.MOTION:
			return p_track == TRACK_MOTION
		Types.CardFamily.ACTION:
			return p_track == TRACK_ACTION
		_:
			return true
