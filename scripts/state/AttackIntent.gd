class_name AttackIntent
extends RefCounted

## One telegraphed enemy attack window. Immutable after creation:
## Edit cards replace intents instead of modifying them.

var _start_frame: int
var _end_frame: int
var _target_tiles: Array[Vector2i]
var _damage: int
var _is_beam: bool


func _init(
	p_start_frame: int,
	p_end_frame: int,
	p_target_tiles: Array[Vector2i],
	p_damage: int,
	p_is_beam: bool = false
) -> void:
	assert(p_end_frame >= p_start_frame, "AttackIntent: end frame is before start frame.")
	_start_frame = p_start_frame
	_end_frame = p_end_frame
	_target_tiles = p_target_tiles.duplicate()
	_damage = p_damage
	_is_beam = p_is_beam


# --- Read-Only Properties ---

var start_frame: int:
	get: return _start_frame

var end_frame: int:
	get: return _end_frame

var target_tiles: Array[Vector2i]:
	get: return _target_tiles.duplicate()

var damage: int:
	get: return _damage

## Beams are blocked by walls and frozen bodies; melee attacks are not.
var is_beam: bool:
	get: return _is_beam


# --- Queries & Immutable Transformations ---

func is_active_on(p_frame: int) -> bool:
	return p_frame >= _start_frame and p_frame <= _end_frame


func targets_tile(p_tile: Vector2i) -> bool:
	return _target_tiles.has(p_tile)


## Returns a new immutable AttackIntent with all target tiles shifted by p_offset.
func shifted(p_offset: Vector2i) -> AttackIntent:
	var moved_tiles: Array[Vector2i] = []
	for tile: Vector2i in _target_tiles:
		moved_tiles.append(tile + p_offset)
	return AttackIntent.new(_start_frame, _end_frame, moved_tiles, _damage, _is_beam)


## Returns a new immutable AttackIntent rotated 90 degrees CW or CCW around p_pivot (Dutch Angle).
func rotated_around(p_pivot: Vector2i, p_clockwise: bool) -> AttackIntent:
	var rotated_tiles: Array[Vector2i] = []
	for tile: Vector2i in _target_tiles:
		rotated_tiles.append(p_pivot + Types.rotate_vector_90(tile - p_pivot, p_clockwise))
	return AttackIntent.new(_start_frame, _end_frame, rotated_tiles, _damage, _is_beam)


## Returns a new immutable AttackIntent shifted in time by p_frame_delta (Slip),
## clamped to the take bounds [0..p_max_frame] and >= p_min_frame so it never cancels.
func slipped(p_frame_delta: int, p_min_frame: int, p_max_frame: int) -> AttackIntent:
	var min_delta: int = maxi(-_start_frame, p_min_frame - _end_frame)
	var max_delta: int = p_max_frame - _end_frame
	var clamped_delta: int = clampi(p_frame_delta, min_delta, max_delta)
	var new_end: int = clampi(_end_frame + clamped_delta, p_min_frame, p_max_frame)
	var new_start: int = clampi(_start_frame + clamped_delta, 0, new_end)
	return AttackIntent.new(new_start, new_end, _target_tiles, _damage, _is_beam)
