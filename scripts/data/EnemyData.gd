class_name EnemyData
extends Resource

## Inspector-driven blueprint for an enemy or boss archetype.

@export_group("Identity & Stats")
@export var id: String = ""
@export var title: String = ""
@export var symbol: String = "E"
@export_range(1, 200) var max_hp: int = 20

@export_group("AI Choreography")
## Cycles through these turn patterns across active takes (1 pattern for simple foes, multiple for bosses)
@export var turn_patterns: Array[EnemyTurnPattern] = []


func get_pattern_for_turn(p_turn_index: int) -> EnemyTurnPattern:
	if turn_patterns.is_empty():
		return null
	var idx: int = posmod(p_turn_index, turn_patterns.size())
	return turn_patterns[idx]
