class_name TimelinePlan
extends RefCounted

## Master container of all blocks scheduled across the timeline.
## Reads constraints strictly from an injected CombatConfig (Zero Magic Numbers).

const TRACK_MOTION: int = 0
const TRACK_ACTION: int = 1

var _config: CombatConfig
var _blocks: Array[TimelineBlock] = []


func _init(p_config: CombatConfig) -> void:
	assert(p_config != null, "TimelinePlan requires a valid CombatConfig!")
	_config = p_config


# --- Read-Only Properties ---

var config: CombatConfig:
	get: return _config

var blocks: Array[TimelineBlock]:
	get: return _blocks.duplicate()

var total_motion_frames: int:
	get:
		var count: int = 0
		for b: TimelineBlock in _blocks:
			if b.card.family == Types.CardFamily.MOTION:
				count += b.duration
		return count

## Checks if the planned motion meets the configured threshold for Tier 1
var qualifies_for_tier_1: bool:
	get: return total_motion_frames >= _config.tier_1_motion_threshold


# --- Query & Validation API ---

func can_place_block(p_card: CardData, p_track: int, p_start_frame: int) -> bool:
	# 1. Timeline boundary check (Using config.total_frames, NOT a hardcoded 24!)
	if p_start_frame < 0 or (p_start_frame + p_card.frame_cost) > _config.total_frames:
		return false
		
	# 2. Track legality rule (Edits go anywhere, Motion on 0, Action on 1)
	if p_card.family == Types.CardFamily.MOTION and p_track != TRACK_MOTION:
		return false
	if p_card.family == Types.CardFamily.ACTION and p_track != TRACK_ACTION:
		return false
		
	# 3. Collision check against existing blocks on the same track
	var temp_block: TimelineBlock = TimelineBlock.new(p_card, p_track, p_start_frame)
	for existing: TimelineBlock in _blocks:
		if existing.overlaps_with(temp_block):
			return false
			
	return true


func add_block(p_block: TimelineBlock) -> bool:
	if not can_place_block(p_block.card, p_block.track_index, p_block.start_frame):
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


## Checks for an idle gap using the threshold from CombatConfig!
func has_momentum_bleed_gap() -> bool:
	var consecutive_idle_frames: int = 0
	for f: int in range(_config.total_frames):
		var block: TimelineBlock = get_block_at(TRACK_MOTION, f)
		if block == null or block.card.family != Types.CardFamily.MOTION:
			consecutive_idle_frames += 1
			if consecutive_idle_frames >= _config.momentum_bleed_idle_frames:
				return true
		else:
			consecutive_idle_frames = 0
	return false


func clone() -> TimelinePlan:
	var copy: TimelinePlan = TimelinePlan.new(_config)
	for b: TimelineBlock in _blocks:
		copy.add_block(b.clone())
	return copy
