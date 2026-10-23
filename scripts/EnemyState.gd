class_name EnemyState
extends EntityState

## Fully encapsulated enemy actor model.

var _archetype: String = "H"
## Array of Dictionary envelopes: [{ "start": int, "end": int, "tiles": Array[Vector2i], "damage": int, "is_beam": bool }]
var _attack_intents: Array[Dictionary] = []


# --- Read-Only Properties ---

var archetype: String:
	get: return _archetype

var attack_intents: Array[Dictionary]:
	get: return _attack_intents.duplicate(true) # Return deep copy to prevent external mutation


# --- Encapsulated API ---

func set_archetype(archetype_code: String) -> void:
	_archetype = archetype_code


func add_attack_intent(start_frame: int, end_frame: int, target_tiles: Array[Vector2i], damage: int, is_beam: bool = false) -> void:
	_attack_intents.append({
		"start": start_frame,
		"end": end_frame,
		"tiles": target_tiles.duplicate(),
		"damage": damage,
		"is_beam": is_beam
	})


func clear_intents() -> void:
	_attack_intents.clear()


func clone() -> EnemyState:
	var copy: EnemyState = EnemyState.new()
	copy_base_to(copy)
	copy._archetype = _archetype
	copy._attack_intents = _attack_intents.duplicate(true)
	return copy
