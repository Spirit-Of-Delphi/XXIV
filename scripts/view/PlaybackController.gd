class_name PlaybackController
extends Node

## Steps through a SimulationResult at 24 FPS (1 Take = 1.0s), triggering Hit-Stop
## and non-drifting Screen Shake on high-impact CombatEvents.

signal frame_stepped(p_frame: int, p_snapshot: CombatState, p_events: Array[CombatEvent])
signal playback_finished(p_result: SimulationResult)

@export_group("Timing & Juice")
@export_range(1.0, 60.0) var playback_fps: float = 24.0
@export_range(0.0, 0.3) var hit_stop_seconds: float = 0.07
@export_range(0.0, 20.0) var shake_amplitude: float = 5.0
@export_range(0.0, 0.4) var shake_seconds: float = 0.12

@export_group("Optional Targets")
@export var shake_target: Node2D

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _result: SimulationResult = null
var _is_playing: bool = false
var _current_frame: int = 0
var _frame_accumulator: float = 0.0
var _hit_stop_remaining: float = 0.0
var _shake_remaining: float = 0.0
var _shake_rest_position: Vector2 = Vector2.ZERO


var is_playing: bool:
	get: return _is_playing

var current_frame: int:
	get: return _current_frame


func _ready() -> void:
	_rng.randomize()


func play_result(p_result: SimulationResult) -> void:
	if p_result == null or p_result.total_frames <= 0:
		return

	if _is_playing:
		_restore_shake_target()
	elif shake_target != null:
		_shake_rest_position = shake_target.position

	_result = p_result
	_is_playing = true
	_current_frame = 0
	_frame_accumulator = 0.0
	_hit_stop_remaining = 0.0
	_shake_remaining = 0.0

	_present_frame(0)


func stop() -> void:
	if not _is_playing:
		return
	_is_playing = false
	_hit_stop_remaining = 0.0
	_shake_remaining = 0.0
	_restore_shake_target()


func _process(p_delta: float) -> void:
	if not _is_playing or _result == null:
		return

	_update_shake(p_delta)

	if _hit_stop_remaining > 0.0:
		_hit_stop_remaining = maxf(0.0, _hit_stop_remaining - p_delta)
		return

	_frame_accumulator += p_delta
	var seconds_per_frame: float = 1.0 / maxf(1.0, playback_fps)
	if _frame_accumulator < seconds_per_frame:
		return

	_frame_accumulator -= seconds_per_frame
	_current_frame += 1

	if _current_frame < _result.total_frames:
		_present_frame(_current_frame)
	else:
		var finished_result: SimulationResult = _result
		stop()
		playback_finished.emit(finished_result)


# --- Private Helpers ---

func _present_frame(p_frame: int) -> void:
	var snapshot: CombatState = _result.get_snapshot(p_frame)
	var frame_events: Array[CombatEvent] = _result.get_events_on_frame(p_frame)
	frame_stepped.emit(p_frame, snapshot, frame_events)

	if _has_high_impact_event(frame_events):
		_hit_stop_remaining = hit_stop_seconds
		_trigger_shake(shake_seconds)
	elif _has_damage_event(frame_events):
		_trigger_shake(shake_seconds * 0.5)


func _has_high_impact_event(p_events: Array[CombatEvent]) -> bool:
	for ev: CombatEvent in p_events:
		match ev.type:
			CombatEvent.Type.MATCH_CUT_TRIGGERED, \
			CombatEvent.Type.FROZEN_ENEMY_IMPACT, \
			CombatEvent.Type.WALL_BROKEN, \
			CombatEvent.Type.VIOLATION_180_TURN, \
			CombatEvent.Type.VIOLATION_WALL_CRASH, \
			CombatEvent.Type.VIOLATION_ENEMY_CRASH:
				return true
	return false


func _has_damage_event(p_events: Array[CombatEvent]) -> bool:
	for ev: CombatEvent in p_events:
		if ev.type == CombatEvent.Type.DAMAGE_DEALT or ev.type == CombatEvent.Type.SHIELD_ABSORBED:
			return true
	return false


func _trigger_shake(p_duration: float) -> void:
	if shake_target == null or p_duration <= 0.0 or shake_amplitude <= 0.0:
		return
	_shake_remaining = maxf(_shake_remaining, p_duration)


func _update_shake(p_delta: float) -> void:
	if shake_target == null or _shake_remaining <= 0.0:
		return
	_shake_remaining = maxf(0.0, _shake_remaining - p_delta)
	if _shake_remaining <= 0.0:
		_restore_shake_target()
	else:
		var offset: Vector2 = Vector2(
			_rng.randf_range(-shake_amplitude, shake_amplitude),
			_rng.randf_range(-shake_amplitude, shake_amplitude)
		)
		shake_target.position = _shake_rest_position + offset


func _restore_shake_target() -> void:
	if shake_target != null:
		shake_target.position = _shake_rest_position	
