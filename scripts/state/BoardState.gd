class_name BoardState
extends RefCounted

## Fully encapsulated arena geometry model.

const DEFAULT_GRID_SIZE: int = 6

var _grid_size: int = DEFAULT_GRID_SIZE
var _walls: Array[Vector2i] = []
var _pits: Array[Vector2i] = []


func _init(p_grid_size: int = DEFAULT_GRID_SIZE) -> void:
	assert(p_grid_size > 0, "BoardState grid_size must be positive.")
	_grid_size = p_grid_size


# --- Public Read-Only Accessors ---

var grid_size: int:
	get: return _grid_size

var walls: Array[Vector2i]:
	get: return _walls.duplicate()

var pits: Array[Vector2i]:
	get: return _pits.duplicate()


# --- Board Mutation API ---

func add_wall(p_pos: Vector2i) -> void:
	if is_in_bounds(p_pos) and not _walls.has(p_pos) and not _pits.has(p_pos):
		_walls.append(p_pos)


func remove_wall(p_pos: Vector2i) -> void:
	_walls.erase(p_pos)


func add_pit(p_pos: Vector2i) -> void:
	if is_in_bounds(p_pos) and not _pits.has(p_pos) and not _walls.has(p_pos):
		_pits.append(p_pos)


# --- Query API ---

func is_in_bounds(p_pos: Vector2i) -> bool:
	return p_pos.x >= 0 and p_pos.y >= 0 and p_pos.x < _grid_size and p_pos.y < _grid_size


## True only for interior destructible wall tiles (can be broken by Tier 3 wall crash).
func is_wall(p_pos: Vector2i) -> bool:
	return _walls.has(p_pos)


## True for both interior walls and out-of-bounds arena edges.
func is_solid(p_pos: Vector2i) -> bool:
	return not is_in_bounds(p_pos) or _walls.has(p_pos)


func is_pit(p_pos: Vector2i) -> bool:
	return _pits.has(p_pos)


func is_blocked(p_pos: Vector2i) -> bool:
	return is_solid(p_pos) or is_pit(p_pos)


func clone() -> BoardState:
	var copy: BoardState = BoardState.new(_grid_size)
	copy._walls = _walls.duplicate()
	copy._pits = _pits.duplicate()
	return copy
