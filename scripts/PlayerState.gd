class_name PlayerState
extends EntityState

## Encapsulated player model. Exposure completely removed!

var _momentum_tier: int = 0
var _tiles_moved_this_take: int = 0


var momentum_tier: int:
	get: return _momentum_tier

var tiles_moved_this_take: int:
	get: return _tiles_moved_this_take


func record_movement_step(new_pos: Vector2i, new_dir: Types.Direction) -> void:
	_grid_position = new_pos
	_direction = new_dir
	_tiles_moved_this_take += 1


func reset_take_movement() -> void:
	_tiles_moved_this_take = 0


func set_momentum_tier(tier: int) -> void:
	_momentum_tier = clampi(tier, 0, 2)


func clone() -> PlayerState:
	var copy: PlayerState = PlayerState.new()
	copy_base_to(copy)
	copy._momentum_tier = _momentum_tier
	copy._tiles_moved_this_take = _tiles_moved_this_take
	return copy
