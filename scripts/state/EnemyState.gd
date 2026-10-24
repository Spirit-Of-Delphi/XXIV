class_name EnemyState
extends EntityState

## A hostile combatant. Holds state only; the rules that act on it live in the simulator.

var _enemy_data: EnemyData = null
var _pattern_turn_index: int = 0
var _attack_intents: Array[AttackIntent] = []
## Tracks which AttackIntents have already triggered a Match Cut this take (once per intent).
var _triggered_match_cut_intents: Array[AttackIntent] = []
## Post-thaw recovery frames left within the current take. Never carries over to the next take.
var _dazed_frames_remaining: int = 0
## If true (from the Tag edit card), other enemies' attacks hitting this enemy's tile deal friendly-fire damage.
var _is_tagged_for_friendly_fire: bool = false


# --- Read-Only Properties ---

var enemy_data: EnemyData:
	get: return _enemy_data

var symbol: String:
	get: return _enemy_data.symbol if _enemy_data != null else "E"

var pattern_turn_index: int:
	get: return _pattern_turn_index

## A shallow copy is enough: AttackIntents are immutable, so sharing them is safe.
var attack_intents: Array[AttackIntent]:
	get: return _attack_intents.duplicate()

var dazed_frames_remaining: int:
	get: return _dazed_frames_remaining

var is_dazed: bool:
	get: return _dazed_frames_remaining > 0

var is_tagged_for_friendly_fire: bool:
	get: return _is_tagged_for_friendly_fire


# --- Encapsulated API ---

func set_enemy_data(p_data: EnemyData) -> void:
	_enemy_data = p_data


## Resets per-take statuses (Daze & Friendly-Fire Tag never carry into a new take).
func begin_take() -> void:
	_dazed_frames_remaining = 0
	_is_tagged_for_friendly_fire = false


func set_tagged_for_friendly_fire(p_tagged: bool) -> void:
	_is_tagged_for_friendly_fire = p_tagged


func advance_turn_pattern() -> void:
	_pattern_turn_index += 1


func add_attack_intent(p_intent: AttackIntent) -> void:
	if p_intent != null:
		_attack_intents.append(p_intent)


func replace_attack_intents(p_intents: Array[AttackIntent]) -> void:
	_attack_intents = p_intents.duplicate()
	_triggered_match_cut_intents.clear()


## Shifts all active AttackIntent target tiles when this enemy is knocked back or swapped.
func shift_attack_intents(p_offset: Vector2i) -> void:
	if p_offset == Vector2i.ZERO:
		return
	for i: int in range(_attack_intents.size()):
		_replace_intent_at(i, _attack_intents[i].shifted(p_offset))


## Rotates this enemy and all of its AttackIntent target tiles 90 degrees CW or CCW (Dutch Angle).
func rotate_90(p_clockwise: bool) -> void:
	_direction = Types.rotate_direction(_direction, p_clockwise)
	for i: int in range(_attack_intents.size()):
		_replace_intent_at(i, _attack_intents[i].rotated_around(_grid_position, p_clockwise))


## Shifts all non-expired AttackIntent windows by p_frame_delta, clamped to the take bounds (Slip).
func slip_attack_intents(p_frame_delta: int, p_current_frame: int, p_max_frame: int) -> void:
	if p_frame_delta == 0:
		return
	for i: int in range(_attack_intents.size()):
		var intent: AttackIntent = _attack_intents[i]
		if intent.end_frame >= p_current_frame:
			_replace_intent_at(i, intent.slipped(p_frame_delta, p_current_frame, p_max_frame))


func clear_attack_intents() -> void:
	_attack_intents.clear()
	_triggered_match_cut_intents.clear()


func has_triggered_match_cut(p_intent: AttackIntent) -> bool:
	return _triggered_match_cut_intents.has(p_intent)


func mark_match_cut_triggered(p_intent: AttackIntent) -> void:
	if p_intent != null and not _triggered_match_cut_intents.has(p_intent):
		_triggered_match_cut_intents.append(p_intent)


## Freezing an enemy immediately destroys its planned attacks and clears prior daze.
func freeze_for_frames(p_frames: int) -> void:
	super.freeze_for_frames(p_frames)
	if is_frozen:
		clear_attack_intents()
		_dazed_frames_remaining = 0


func daze_for_frames(p_frames: int) -> void:
	if p_frames > 0 and is_alive:
		_dazed_frames_remaining = maxi(_dazed_frames_remaining, p_frames)


## Decrements the daze timer by 1 frame.
## Returns true on the exact frame daze recovery finishes (transitions from 1 -> 0).
func tick_daze_frame() -> bool:
	if _dazed_frames_remaining > 0:
		_dazed_frames_remaining -= 1
		return _dazed_frames_remaining == 0
	return false


func clone() -> EnemyState:
	var copy: EnemyState = EnemyState.new()
	copy_base_to(copy)
	copy._enemy_data = _enemy_data
	copy._pattern_turn_index = _pattern_turn_index
	copy._attack_intents = _attack_intents.duplicate()
	copy._triggered_match_cut_intents = _triggered_match_cut_intents.duplicate()
	copy._dazed_frames_remaining = _dazed_frames_remaining
	copy._is_tagged_for_friendly_fire = _is_tagged_for_friendly_fire
	return copy


# --- Private Helpers ---

func _replace_intent_at(p_index: int, p_new_intent: AttackIntent) -> void:
	var old_intent: AttackIntent = _attack_intents[p_index]
	_attack_intents[p_index] = p_new_intent
	var trig_idx: int = _triggered_match_cut_intents.find(old_intent)
	if trig_idx >= 0:
		_triggered_match_cut_intents[trig_idx] = p_new_intent
