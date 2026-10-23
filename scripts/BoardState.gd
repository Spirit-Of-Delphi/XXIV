class_name BoardState
extends RefCounted

## Fully encapsulated arena geometry model.

const DEFAULT_GRID_SIZE: int = 6

var _grid_size: int = DEFAULT_GRID_SIZE
var _walls: Array[Vector2i] = []
var _pits: Array[Vector2i] = []


func _init(p_grid_size: int = DEFAULT_GRID_SIZE) -> void:
	_grid_size = p_grid_size


# --- Public Read-Only Accessors ---

var grid_size: int:
	get: return _grid_size

var walls: Array[Vector2i]:
	get: return _walls.duplicate()

var pits: Array[Vector2i]:
	get: return _pits.duplicate()


# --- Board Mutation API ---

func add_wall(pos: Vector2i) -> void:
	if is_in_bounds(pos) and not _walls.has(pos) and not _pits.has(pos):
		_walls.append(pos)


func add_pit(pos: Vector2i) -> void:
	if is_in_bounds(pos) and not _pits.has(pos) and not _walls.has(pos):
		_pits.append(pos)


# --- Query API ---

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < _grid_size and pos.y < _grid_size


func is_solid(pos: Vector2i) -> bool:
	return not is_in_bounds(pos) or _walls.has(pos)


func is_pit(pos: Vector2i) -> bool:
	return _pits.has(pos)


func is_blocked(pos: Vector2i) -> bool:
	return is_solid(pos) or is_pit(pos)


func clone() -> BoardState:
	var copy: BoardState = BoardState.new(_grid_size)
	for w: Vector2i in _walls:
		copy.add_wall(w)
	for p: Vector2i in _pits:
		copy.add_pit(p)
	return copy
