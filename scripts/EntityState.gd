class_name EntityState
extends RefCounted

## Fully encapsulated base actor model with frame-accurate 24-frame freeze timer.

var _id: int = 0
var _grid_position: Vector2i = Vector2i.ZERO
var _direction: Types.Direction = Types.Direction.NORTH
var _hp: int = 14
var _max_hp: int = 14
var _shield: int = 0
var _frozen_frames_remaining: int = 0


# --- Read-Only Properties ---

var id: int:
	get: return _id

var grid_position: Vector2i:
	get: return _grid_position

var direction: Types.Direction:
	get: return _direction

var hp: int:
	get: return _hp

var max_hp: int:
	get: return _max_hp

var shield: int:
	get: return _shield

var frozen_frames_remaining: int:
	get: return _frozen_frames_remaining

var is_alive: bool:
	get: return _hp > 0

var is_frozen: bool:
	get: return _frozen_frames_remaining > 0


# --- Encapsulated Mutation API ---

func set_identity(p_id: int, p_max_hp: int, p_initial_hp: int = -1) -> void:
	_id = p_id
	_max_hp = p_max_hp
	_hp = p_initial_hp if p_initial_hp > 0 else p_max_hp


func set_position_and_direction(pos: Vector2i, dir: Types.Direction) -> void:
	_grid_position = pos
	_direction = dir


func add_shield(amount: int) -> void:
	_shield += maxi(0, amount)


func clear_shield() -> void:
	_shield = 0


func take_damage(amount: int) -> int:
	var remaining: int = amount
	if _shield > 0:
		var absorbed: int = mini(_shield, remaining)
		_shield -= absorbed
		remaining -= absorbed
		
	_hp = maxi(0, _hp - remaining)
	return remaining


func freeze_for_seconds(seconds: float = 1.0) -> void:
	# 1 second = exactly 24 frames
	_frozen_frames_remaining = maxi(_frozen_frames_remaining, int(seconds * 24.0))


func tick_frame() -> void:
	if _frozen_frames_remaining > 0:
		_frozen_frames_remaining -= 1


func copy_base_to(target: EntityState) -> void:
	target._id = _id
	target._grid_position = _grid_position
	target._direction = _direction
	target._hp = _hp
	target._max_hp = _max_hp
	target._shield = _shield
	target._frozen_frames_remaining = _frozen_frames_remaining
