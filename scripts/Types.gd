class_name Types
extends RefCounted

enum Direction {
	NORTH = 0,
	EAST = 1,
	SOUTH = 2,
	WEST = 3
}

enum CardFamily {
	MOTION,
	ACTION,
	EDIT
}

const DIRECTION_VECTORS: Dictionary = {
	Direction.NORTH: Vector2i(0, -1),
	Direction.EAST: Vector2i(1, 0),
	Direction.SOUTH: Vector2i(0, 1),
	Direction.WEST: Vector2i(-1, 0),
}

const DIRECTION_ARROWS: Dictionary = {
	Direction.NORTH: "↑",
	Direction.EAST: "→",
	Direction.SOUTH: "↓",
	Direction.WEST: "←",
}


static func to_vector(dir: Direction) -> Vector2i:
	return DIRECTION_VECTORS[dir]


static func to_arrow(dir: Direction) -> String:
	return DIRECTION_ARROWS[dir]

## Detects a 180-degree reversal (triggers an Angle Violation when at speed)
static func is_opposite_direction(dir_a: Direction, dir_b: Direction) -> bool:
	return (int(dir_a) - int(dir_b) + 4) % 4 == 2
