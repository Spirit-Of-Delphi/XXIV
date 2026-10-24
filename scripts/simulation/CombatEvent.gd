class_name CombatEvent
extends RefCounted

## Immutable record of a single discrete gameplay event on a specific frame.
## Consumed by the UI preview, 24-FPS playback controller, audio engine, and unit tests.

enum Type {
	PLAYER_TURNED,
	PLAYER_STEPPED,
	SHIELD_GAINED,
	SHIELD_ABSORBED,
	TIER_PROMOTED,
	TIER_DROPPED,
	VIOLATION_180_TURN,
	VIOLATION_WALL_CRASH,
	WALL_BROKEN,
	VIOLATION_ENEMY_CRASH,
	FROZEN_ENEMY_IMPACT,
	SHOCKWAVE_PUSH,
	STRIKE_SWUNG,
	FLOW_TRIGGERED,
	MATCH_CUT_TRIGGERED,
	DAMAGE_DEALT,
	ENTITY_FROZEN,
	ENTITY_THAWED,
	ENEMY_DAZED,
	ENEMY_SCRAMBLE_SCHEDULED,
	ENEMY_ATTACK_HIT,
	KNOCKBACK_MOVED,
	WALL_SLAM,
	PIT_ELIMINATION,
	ENEMY_ROTATED,
	INTENT_SLIPPED,
	PHASE_DODGED,
	DECOY_PLACED,
	PLAYER_REWOUND,
	PLAYER_HEALED,
	POSITIONS_SWAPPED,
	ENEMY_TAGGED,
}

var _type: Type
var _frame: int
var _actor_id: int
var _grid_position: Vector2i
var _value: int
var _detail: String


func _init(
	p_type: Type,
	p_frame: int,
	p_actor_id: int = -1,
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_value: int = 0,
	p_detail: String = ""
) -> void:
	_type = p_type
	_frame = p_frame
	_actor_id = p_actor_id
	_grid_position = p_grid_position
	_value = p_value
	_detail = p_detail


# --- Read-Only Properties ---

var type: Type:
	get: return _type

var frame: int:
	get: return _frame

var actor_id: int:
	get: return _actor_id

var grid_position: Vector2i:
	get: return _grid_position

var value: int:
	get: return _value

var detail: String:
	get: return _detail


# --- Shared Simulation Helper ---

## Applies p_amount damage to p_target and records SHIELD_ABSORBED and/or DAMAGE_DEALT events.
static func record_damage(
	p_target: EntityState,
	p_amount: int,
	p_frame: int,
	p_grid_position: Vector2i,
	p_detail: String,
	p_events: Array[CombatEvent]
) -> void:
	if p_amount <= 0 or not p_target.is_alive:
		return
	var shield_before: int = p_target.shield
	var hp_lost: int = p_target.take_damage(p_amount)
	var absorbed: int = shield_before - p_target.shield
	if absorbed > 0:
		p_events.append(CombatEvent.new(
			Type.SHIELD_ABSORBED, p_frame, p_target.id, p_grid_position, absorbed, p_detail
		))
	if hp_lost > 0:
		p_events.append(CombatEvent.new(
			Type.DAMAGE_DEALT, p_frame, p_target.id, p_grid_position, hp_lost, p_detail
		))
