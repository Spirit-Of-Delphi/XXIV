class_name EnemyTurnPattern
extends Resource

## Defines one full take of movement and any number of distinct attacks for an enemy or boss.

@export var pattern_name: String = ""
@export_range(0, 6) var move_steps: int = 1
## 1 = Melee (closes in adjacent); >1 = Ranged/Sniper (strafes to align row/col at this distance)
@export_range(1, 6) var preferred_range: int = 1
## All attacks this enemy schedules during this take (each can have completely different shapes/timings)
@export var attacks: Array[EnemyAttackData] = []
