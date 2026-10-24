class_name EnemySpawnData
extends Resource

## Pairs an EnemyData resource with its initial placement on the Arena grid.

@export var enemy_data: EnemyData
@export var grid_position: Vector2i = Vector2i(2, 1)
@export var direction: Types.Direction = Types.Direction.SOUTH
