class_name TimelineBlock
extends RefCounted

## One card placed on the timeline. Immutable: moving or re-aiming a clip means
## replacing it with a new block, so plans can share blocks safely.
## Create blocks through TimelinePlan.create_block() so duration and step frames are resolved.

var _card: CardData
var _track_index: int
var _start_frame: int
## Resolved frame cost; may be shorter than card.frame_cost because of tier discounts.
var _duration: int
var _step_frames: Array[int]
var _direction: Types.Direction
var _target_enemy_id: int


func _init(
	p_card: CardData,
	p_track_index: int,
	p_start_frame: int,
	p_duration: int,
	p_direction: Types.Direction = Types.Direction.NORTH,
	p_target_enemy_id: int = -1,
	p_step_frames: Array[int] = []
) -> void:
	assert(p_card != null, "TimelineBlock needs a card.")
	assert(p_duration >= 1, "TimelineBlock duration must be at least 1 frame.")
	_card = p_card
	_track_index = p_track_index
	_start_frame = p_start_frame
	_duration = p_duration
	_direction = p_direction
	_target_enemy_id = p_target_enemy_id
	_step_frames = p_step_frames.duplicate() if not p_step_frames.is_empty() else p_card.step_frames.duplicate()


# --- Read-Only Properties ---

var card: CardData:
	get: return _card

var track_index: int:
	get: return _track_index

var start_frame: int:
	get: return _start_frame

var duration: int:
	get: return _duration

var end_frame: int:
	get: return _start_frame + _duration - 1

var step_frames: Array[int]:
	get: return _step_frames.duplicate()

var direction: Types.Direction:
	get: return _direction

var target_enemy_id: int:
	get: return _target_enemy_id


# --- Queries ---

func occupies_frame(p_frame: int) -> bool:
	return p_frame >= _start_frame and p_frame <= end_frame


## Returns true if p_global_frame is one of this card's strike hit frames.
func is_hit_frame(p_global_frame: int) -> bool:
	if not occupies_frame(p_global_frame):
		return false
	var local_frame: int = p_global_frame - _start_frame
	return _card.hit_frames.has(local_frame)


## Returns true if p_global_frame is one of this card's movement step frames.
func is_step_frame(p_global_frame: int) -> bool:
	if not occupies_frame(p_global_frame):
		return false
	var local_frame: int = p_global_frame - _start_frame
	return _step_frames.has(local_frame)


## Returns true if p_global_frame is one of this card's splice/edit trigger frames.
func is_edit_frame(p_global_frame: int) -> bool:
	if not occupies_frame(p_global_frame):
		return false
	var local_frame: int = p_global_frame - _start_frame
	return _card.edit_frames.has(local_frame)


## Returns true if p_global_frame triggers any step, hit, or edit effect on this block (for UI frame pips).
func is_trigger_frame(p_global_frame: int) -> bool:
	return is_step_frame(p_global_frame) or is_hit_frame(p_global_frame) or is_edit_frame(p_global_frame)


func overlaps_with(p_other: TimelineBlock) -> bool:
	if _track_index != p_other.track_index:
		return false
	return not (end_frame < p_other.start_frame or _start_frame > p_other.end_frame)
