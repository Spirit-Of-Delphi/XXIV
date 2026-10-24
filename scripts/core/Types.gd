class_name Types
extends RefCounted

## Core enums and pure spatial/direction math utilities shared across all XXIV layers.

enum Direction {
	NORTH = 0,
	EAST = 1,
	SOUTH = 2,
	WEST = 3,
}

enum SpeedTier {
	BASE = 0,
	TIER_1 = 1,
	TIER_2 = 2,
	TIER_3 = 3,
}

enum CardFamily {
	MOTION = 0,
	ACTION = 1,
	EDIT = 2,
}

const ALL_DIRECTIONS: Array[Direction] = [
	Direction.NORTH,
	Direction.EAST,
	Direction.SOUTH,
	Direction.WEST,
]


static func to_vector(p_dir: Direction) -> Vector2i:
	match p_dir:
		Direction.NORTH:
			return Vector2i(0, -1)
		Direction.EAST:
			return Vector2i(1, 0)
		Direction.SOUTH:
			return Vector2i(0, 1)
		Direction.WEST:
			return Vector2i(-1, 0)
		_:
			return Vector2i.ZERO


static func opposite_direction(p_dir: Direction) -> Direction:
	return ((int(p_dir) + 2) % 4) as Direction


static func is_opposite_direction(p_dir_a: Direction, p_dir_b: Direction) -> bool:
	return opposite_direction(p_dir_a) == p_dir_b


static func rotate_direction(p_dir: Direction, p_clockwise: bool = true) -> Direction:
	var step: int = 1 if p_clockwise else 3
	return ((int(p_dir) + step) % 4) as Direction


## Rotates a 2D grid vector 90 degrees clockwise or counter-clockwise around the origin.
static func rotate_vector_90(p_vec: Vector2i, p_clockwise: bool = true) -> Vector2i:
	return Vector2i(-p_vec.y, p_vec.x) if p_clockwise else Vector2i(p_vec.y, -p_vec.x)


## Rotates a North-relative local offset (where (0, -1) is 1 tile ahead) to match p_facing.
static func rotate_north_offset(p_offset: Vector2i, p_facing: Direction) -> Vector2i:
	match p_facing:
		Direction.EAST:
			return Vector2i(-p_offset.y, p_offset.x)
		Direction.SOUTH:
			return Vector2i(-p_offset.x, -p_offset.y)
		Direction.WEST:
			return Vector2i(p_offset.y, -p_offset.x)
		_:
			return p_offset


## Returns the primary cardinal direction from p_from toward p_to (ties favor East/West).
static func direction_toward(
	p_from: Vector2i,
	p_to: Vector2i,
	p_fallback: Direction = Direction.NORTH
) -> Direction:
	var delta: Vector2i = p_to - p_from
	if delta == Vector2i.ZERO:
		return p_fallback
	if absi(delta.x) >= absi(delta.y):
		return Direction.EAST if delta.x > 0 else Direction.WEST
	return Direction.SOUTH if delta.y > 0 else Direction.NORTH
