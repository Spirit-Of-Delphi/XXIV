class_name SimulationResult
extends RefCounted

## Immutable container holding the 24 frame snapshots and events produced by CombatSimulator.
## Shared by both the real-time planning preview and the 24-FPS execution playback.

var _initial_state: CombatState
var _snapshots: Array[CombatState] = []
var _events: Array[CombatEvent] = []


func _init(
	p_initial_state: CombatState,
	p_snapshots: Array[CombatState],
	p_events: Array[CombatEvent]
) -> void:
	assert(p_initial_state != null, "SimulationResult requires an initial CombatState.")
	_initial_state = p_initial_state.clone()
	_snapshots = p_snapshots.duplicate()
	_events = p_events.duplicate()


# --- Read-Only Properties ---

var initial_state: CombatState:
	get: return _initial_state.clone()

var final_state: CombatState:
	get:
		if _snapshots.is_empty():
			return _initial_state.clone()
		return _snapshots[_snapshots.size() - 1].clone()

var total_frames: int:
	get: return _snapshots.size()

## CombatEvents are immutable, so a shallow array copy is safe.
var events: Array[CombatEvent]:
	get: return _events.duplicate()


# --- Queries ---

## Returns an isolated clone of the board state at the end of p_frame.
func get_snapshot(p_frame: int) -> CombatState:
	if _snapshots.is_empty():
		return _initial_state.clone()
	var idx: int = clampi(p_frame, 0, _snapshots.size() - 1)
	return _snapshots[idx].clone()


func get_events_on_frame(p_frame: int) -> Array[CombatEvent]:
	var frame_events: Array[CombatEvent] = []
	for ev: CombatEvent in _events:
		if ev.frame == p_frame:
			frame_events.append(ev)
	return frame_events


## Checks if an event of p_type occurred. If p_frame >= 0, checks only that frame.
func has_event_type(p_type: CombatEvent.Type, p_frame: int = -1) -> bool:
	for ev: CombatEvent in _events:
		if ev.type == p_type and (p_frame < 0 or ev.frame == p_frame):
			return true
	return false


func count_events_of_type(p_type: CombatEvent.Type) -> int:
	var count: int = 0
	for ev: CombatEvent in _events:
		if ev.type == p_type:
			count += 1
	return count


## Returns the player's grid position across every simulated frame (for drawing trajectory lines).
func get_player_trajectory() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for snap: CombatState in _snapshots:
		path.append(snap.player.grid_position)
	return path
