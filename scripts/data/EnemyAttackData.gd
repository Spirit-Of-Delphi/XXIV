class_name EnemyAttackData
extends Resource

## Defines a single telegraphed enemy attack window within a 24-frame take.

@export_range(0, 23) var start_frame: int = 4
@export_range(0, 23) var end_frame: int = 10
@export_range(1, 50) var damage: int = 4
## Relative target tiles authored assuming the enemy faces NORTH (0, -1). Ignored if is_beam is true.
@export var local_offsets: Array[Vector2i] = [Vector2i(0, -1)]
@export var is_beam: bool = false
@export_range(1, 12) var beam_max_range: int = 6
