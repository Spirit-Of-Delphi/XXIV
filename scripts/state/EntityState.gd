class_name EntityState
extends RefCounted

## Fully encapsulated base actor model with frame-accurate freeze timer.

var _id: int = 0
var _grid_position: Vector2i = Vector2i.ZERO
var _direction: Types.Direction = Types.Direction.NORTH
var _hp: int = 1
var _max_hp: int = 1
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
	assert(p_max_hp > 0, "EntityState max_hp must be positive.")
	_id = p_id
	_max_hp = p_max_hp
	if p_initial_hp >= 0:
		_hp = clampi(p_initial_hp, 0, _max_hp)
	else:
		_hp = _max_hp


func set_grid_position(p_pos: Vector2i) -> void:
	_grid_position = p_pos


func set_direction(p_dir: Types.Direction) -> void:
	_direction = p_dir


func set_position_and_direction(p_pos: Vector2i, p_dir: Types.Direction) -> void:
	_grid_position = p_pos
	_direction = p_dir


func add_shield(p_amount: int) -> void:
	if p_amount > 0:
		_shield += p_amount


func clear_shield() -> void:
	_shield = 0


## Restores HP up to _max_hp. Returns the actual HP restored.
func heal(p_amount: int) -> int:
	if p_amount <= 0 or not is_alive:
		return 0
	var hp_before: int = _hp
	_hp = mini(_max_hp, _hp + p_amount)
	return _hp - hp_before


## Deals damage, absorbed by shield first. Returns the actual HP lost.
func take_damage(p_amount: int) -> int:
	if p_amount <= 0 or not is_alive:
		return 0
	var remaining: int = p_amount
	if _shield > 0:
		var absorbed: int = mini(_shield, remaining)
		_shield -= absorbed
		remaining -= absorbed
	var hp_before: int = _hp
	_hp = maxi(0, _hp - remaining)
	return hp_before - _hp


## Instant elimination (e.g. falling into a pit hazard), bypassing shield.
func kill() -> void:
	_shield = 0
	_hp = 0
	_frozen_frames_remaining = 0


func freeze_for_frames(p_frames: int) -> void:
	if p_frames > 0 and is_alive:
		_frozen_frames_remaining = maxi(_frozen_frames_remaining, p_frames)


## Decrements the freeze timer by 1 frame.
## Returns true on the exact frame the entity thaws (transitions from 1 -> 0).
func tick_freeze_frame() -> bool:
	if _frozen_frames_remaining > 0:
		_frozen_frames_remaining -= 1
		return _frozen_frames_remaining == 0
	return false


func copy_base_to(p_target: EntityState) -> void:
	p_target._id = _id
	p_target._grid_position = _grid_position
	p_target._direction = _direction
	p_target._hp = _hp
	p_target._max_hp = _max_hp
	p_target._shield = _shield
	p_target._frozen_frames_remaining = _frozen_frames_remaining
