class_name TimelineBlock
extends RefCounted

## Represents a single card instance committed to the 24-frame timeline.

var _card: CardData
var _track_index: int = 0 # 0 = Motion Track, 1 = Action Track
var _start_frame: int = 0 # 0 to 23
var _direction: Types.Direction = Types.Direction.NORTH
var _target_enemy_id: int = -1 # Used by targeted Edit cards like Razor/Slip


func _init(
	p_card: CardData,
	p_track_index: int,
	p_start_frame: int,
	p_direction: Types.Direction = Types.Direction.NORTH,
	p_target_enemy_id: int = -1
) -> void:
	_card = p_card
	_track_index = p_track_index
	_start_frame = p_start_frame
	_direction = p_direction
	_target_enemy_id = p_target_enemy_id


# --- Read-Only Properties ---

var card: CardData:
	get: return _card

var track_index: int:
	get: return _track_index

var start_frame: int:
	get: return _start_frame

var end_frame: int:
	get: return _start_frame + _card.frame_cost - 1

var duration: int:
	get: return _card.frame_cost

var direction: Types.Direction:
	get: return _direction

var target_enemy_id: int:
	get: return _target_enemy_id


## Checks if this block occupies a specific frame on the timeline
func occupies_frame(p_frame: int) -> bool:
	return p_frame >= _start_frame and p_frame <= end_frame


## Checks if this block overlaps with another block on the same track
func overlaps_with(p_other: TimelineBlock) -> bool:
	if _track_index != p_other.track_index:
		return false
	return not (end_frame < p_other.start_frame or _start_frame > p_other.end_frame)


func clone() -> TimelineBlock:
	return TimelineBlock.new(_card, _track_index, _start_frame, _direction, _target_enemy_id)
