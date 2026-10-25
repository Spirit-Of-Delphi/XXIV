class_name CombatScreen
extends Node

## Self-contained combat scene coordinator.
## Connects CombatEncounter (headless brain) to ArenaView, PlaybackController, HUD, Hand, and Timeline,
## and supports multi-scene RunDirector progression + uncut end-of-fight Action Replay.

signal scene_finished(
	p_is_victory: bool,
	p_final_state: CombatState,
	p_takes_used: int,
	p_recorded_takes: Array[SimulationResult]
)
signal replay_take_started(p_take_index: int, p_total_takes: int)
signal replay_completed()

const REPLAY_FPS: float = 50.0
const REPLAY_HIT_STOP: float = 0.04

@export_group("View References")
@export var arena_view: ArenaView
@export var playback_controller: PlaybackController
@export var hud_view: CombatHudView
@export var hand_view: HandView
@export var timeline_view: TimelineEditorView
@export var frame_gate_label: Label

var _encounter_data: EncounterData = null
var _config: CombatConfig = null
var _encounter: CombatEncounter = null
var _playback_result: SimulationResult = null
var _signals_bound: bool = false

var _is_managed_run: bool = false
var _interactive_enabled: bool = true
var _recorded_takes: Array[SimulationResult] = []

var _is_replaying: bool = false
var _replay_queue: Array[SimulationResult] = []
var _replay_index: int = 0
var _saved_fps: float = 24.0
var _saved_hit_stop: float = 0.07


func start_encounter(p_encounter_data: EncounterData, p_config: CombatConfig) -> void:
	if p_encounter_data == null or p_config == null:
		return
	_is_managed_run = false
	_encounter_data = p_encounter_data
	var built: CombatEncounter = _encounter_data.create_encounter(p_config)
	_begin_with_encounter(built, p_config, 1, 24)


func start_managed_encounter(
	p_encounter: CombatEncounter,
	p_config: CombatConfig,
	p_scene_number: int,
	p_total_scenes: int
) -> void:
	if p_encounter == null or p_config == null:
		return
	_is_managed_run = true
	_encounter_data = null
	_begin_with_encounter(p_encounter, p_config, p_scene_number, p_total_scenes)


func set_combat_visible(p_visible: bool) -> void:
	if arena_view != null:
		arena_view.visible = p_visible
	var backdrop_layer: CanvasLayer = get_node_or_null("BackdropLayer") as CanvasLayer
	if backdrop_layer != null:
		backdrop_layer.visible = p_visible
	var ui_layer: CanvasLayer = get_node_or_null("UILayer") as CanvasLayer
	if ui_layer != null:
		ui_layer.visible = p_visible
	set_interactive_enabled(p_visible)


func set_interactive_enabled(p_enabled: bool) -> void:
	_interactive_enabled = p_enabled
	var planning_active: bool = (
		p_enabled
		and not _is_replaying
		and _encounter != null
		and _encounter.phase == CombatEncounter.Phase.PLANNING
	)
	if hand_view != null:
		hand_view.set_process_unhandled_key_input(planning_active)
	if arena_view != null:
		arena_view.set_process_unhandled_input(planning_active)


func play_action_replay(p_takes: Array[SimulationResult]) -> void:
	if p_takes.is_empty() or playback_controller == null:
		replay_completed.emit()
		return

	_is_replaying = true
	_replay_queue = p_takes.duplicate()
	_replay_index = 0
	_saved_fps = playback_controller.playback_fps
	_saved_hit_stop = playback_controller.hit_stop_seconds
	playback_controller.playback_fps = REPLAY_FPS
	playback_controller.hit_stop_seconds = REPLAY_HIT_STOP

	if hand_view != null:
		hand_view.clear_selection()
		hand_view.visible = false
	set_interactive_enabled(false)

	_start_current_replay_take()


func skip_action_replay() -> void:
	if not _is_replaying:
		return
	if playback_controller != null:
		playback_controller.stop()
	if not _replay_queue.is_empty() and arena_view != null:
		var last_res: SimulationResult = _replay_queue[_replay_queue.size() - 1]
		arena_view.render_frame_snapshot(last_res.final_state, last_res.total_frames - 1, last_res, false)
	_finish_action_replay()


func _begin_with_encounter(
	p_encounter: CombatEncounter,
	p_config: CombatConfig,
	p_scene_number: int,
	p_total_scenes: int
) -> void:
	_config = p_config
	_playback_result = null
	_is_replaying = false
	_recorded_takes.clear()
	_bind_view_signals_once()

	if playback_controller != null:
		playback_controller.stop()
	if hud_view != null:
		hud_view.scene_number = p_scene_number
		hud_view.total_scenes = p_total_scenes
		hud_view.hide_end_banner()
		hud_view.queue_redraw()
	if hand_view != null:
		hand_view.reset_take_slots()
	if timeline_view != null:
		timeline_view.set_selected_block(null)

	_encounter = p_encounter
	_encounter.preview_updated.connect(_on_preview_updated)
	_encounter.take_committed.connect(_on_take_committed)
	_encounter.start_next_take()
	set_interactive_enabled(_interactive_enabled)


func _unhandled_input(p_event: InputEvent) -> void:
	if not _interactive_enabled or _is_replaying:
		return
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return

	if p_event is InputEventKey:
		var key_ev: InputEventKey = p_event as InputEventKey
		if key_ev.pressed and not key_ev.echo:
			if key_ev.ctrl_pressed or key_ev.meta_pressed:
				if key_ev.keycode == KEY_Z:
					if key_ev.shift_pressed:
						_encounter.redo()
					else:
						_encounter.undo()
					get_viewport().set_input_as_handled()
					return
				if key_ev.keycode == KEY_Y:
					_encounter.redo()
					get_viewport().set_input_as_handled()
					return

			var hand_armed: bool = hand_view != null and hand_view.selected_card != null
			var sel_blk: TimelineBlock = timeline_view.selected_block if timeline_view != null else null

			if key_ev.keycode == KEY_C and not key_ev.ctrl_pressed and not key_ev.meta_pressed:
				_encounter.clear_timeline()
				get_viewport().set_input_as_handled()
				return

			if key_ev.keycode == KEY_BACKSPACE or key_ev.keycode == KEY_DELETE:
				if sel_blk != null:
					_encounter.remove_block(sel_blk)
					get_viewport().set_input_as_handled()
					return
				var current_blocks: Array[TimelineBlock] = _encounter.plan.blocks
				if not current_blocks.is_empty():
					_encounter.remove_block(current_blocks[current_blocks.size() - 1])
					get_viewport().set_input_as_handled()
					return

			if not hand_armed and sel_blk != null:
				match key_ev.keycode:
					KEY_LEFT:
						_nudge_selected_block(-1)
						get_viewport().set_input_as_handled()
						return
					KEY_RIGHT:
						_nudge_selected_block(1)
						get_viewport().set_input_as_handled()
						return
					KEY_W:
						if sel_blk.card.requires_cardinal_direction():
							_reaim_selected_block_direction(Types.Direction.NORTH)
							get_viewport().set_input_as_handled()
							return
					KEY_A:
						if sel_blk.card.requires_cardinal_direction() or sel_blk.card.requires_timeline_direction():
							_reaim_selected_block_direction(Types.Direction.WEST)
							get_viewport().set_input_as_handled()
							return
					KEY_S:
						if sel_blk.card.requires_cardinal_direction():
							_reaim_selected_block_direction(Types.Direction.SOUTH)
							get_viewport().set_input_as_handled()
							return
					KEY_D:
						if sel_blk.card.requires_cardinal_direction() or sel_blk.card.requires_timeline_direction():
							_reaim_selected_block_direction(Types.Direction.EAST)
							get_viewport().set_input_as_handled()
							return
					KEY_ESCAPE:
						_select_timeline_block(null)
						get_viewport().set_input_as_handled()
						return

	if p_event.is_action_pressed("ui_accept"):
		_encounter.commit_take()
		get_viewport().set_input_as_handled()


# --- Private View Wiring ---

func _bind_view_signals_once() -> void:
	if _signals_bound:
		return
	_signals_bound = true

	if arena_view != null:
		arena_view.enemy_clicked.connect(_on_enemy_picked)
		arena_view.direction_aimed.connect(_on_arena_direction_aimed)

	if timeline_view != null:
		timeline_view.frame_scrubbed.connect(_on_timeline_frame_scrubbed)
		timeline_view.scrub_cleared.connect(_on_timeline_scrub_cleared)
		timeline_view.track_frame_clicked.connect(_on_timeline_track_frame_clicked)
		timeline_view.block_selected.connect(_on_timeline_block_selected)
		timeline_view.block_move_requested.connect(_on_timeline_block_move_requested)
		timeline_view.block_remove_requested.connect(_on_timeline_block_remove_requested)
		timeline_view.card_dropped_on_timeline.connect(_on_timeline_card_dropped)
		timeline_view.enemy_badge_clicked.connect(_on_enemy_picked)
		timeline_view.enemy_lane_hovered.connect(_on_timeline_enemy_lane_hovered)

	if hand_view != null:
		hand_view.selection_changed.connect(_on_hand_selection_changed)
		hand_view.placed_clip_reaim_requested.connect(_reaim_selected_block_direction)

	if hud_view != null:
		hud_view.undo_requested.connect(_on_undo_requested)
		hud_view.redo_requested.connect(_on_redo_requested)
		hud_view.clear_requested.connect(_on_clear_requested)
		hud_view.commit_requested.connect(_on_commit_requested)
		hud_view.restart_requested.connect(_on_restart_requested)

	if playback_controller != null:
		playback_controller.frame_stepped.connect(_on_playback_frame_stepped)
		playback_controller.playback_finished.connect(_on_playback_finished)


# --- Encounter & UI Signal Handlers ---

func _on_preview_updated(p_preview: SimulationResult) -> void:
	if _encounter == null:
		return
	var base_state: CombatState = _encounter.state
	var current_plan: TimelinePlan = _encounter.plan
	var current_deck: DeckState = _encounter.deck

	_set_gate_frame_text(0)

	if arena_view != null:
		arena_view.render_planning_overview(base_state, p_preview)
	if timeline_view != null:
		timeline_view.set_playhead_frame(TimelineEditorView.NO_FRAME)
		timeline_view.refresh_timeline(base_state, current_plan, _config.total_frames, p_preview)
	if hand_view != null:
		hand_view.visible = true
		hand_view.refresh_hand(
			_encounter.take_number,
			current_deck,
			base_state,
			current_plan.planning_tier,
			_config
		)
		if timeline_view != null:
			hand_view.set_placed_clip_context(timeline_view.selected_block)

	_sync_aiming_views()
	_refresh_planning_hud_state()
	set_interactive_enabled(_interactive_enabled)


func _on_hand_selection_changed(
	p_selected_card: CardData,
	_p_direction: Types.Direction,
	_p_target_enemy_id: int
) -> void:
	if p_selected_card != null and timeline_view != null and timeline_view.selected_block != null:
		timeline_view.set_selected_block(null)
	_sync_aiming_views()
	_refresh_planning_hud_state()


func _on_timeline_block_selected(p_block: TimelineBlock) -> void:
	if p_block != null and hand_view != null and hand_view.selected_card != null:
		hand_view.clear_selection()
	_select_timeline_block(p_block)


func _select_timeline_block(p_block: TimelineBlock) -> void:
	if timeline_view != null:
		timeline_view.set_selected_block(p_block)
	if hand_view != null:
		hand_view.set_placed_clip_context(p_block)
	_sync_aiming_views()
	_refresh_planning_hud_state()


func _sync_aiming_views() -> void:
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		if arena_view != null:
			arena_view.set_aiming_context(null, Types.Direction.NORTH, -1)
		if timeline_view != null:
			timeline_view.clear_ghost_card()
			timeline_view.set_target_pick_context(null)
		return

	var armed_card: CardData = hand_view.selected_card if hand_view != null else null
	var sel_blk: TimelineBlock = timeline_view.selected_block if timeline_view != null else null

	if armed_card != null and hand_view != null:
		var origin_tile: Vector2i = _encounter.preview_result.final_state.player.grid_position
		if arena_view != null:
			arena_view.set_aiming_context(
				armed_card, hand_view.aim_direction, hand_view.target_enemy_id, origin_tile
			)
		if timeline_view != null:
			timeline_view.set_target_pick_context(armed_card)
			if hand_view.can_commit_selected_placement():
				timeline_view.set_ghost_card(armed_card, hand_view.aim_direction, hand_view.target_enemy_id)
			else:
				timeline_view.clear_ghost_card()
	elif sel_blk != null:
		var blk_origin: Vector2i = _get_player_origin_before_frame(sel_blk.start_frame)
		if arena_view != null:
			arena_view.set_aiming_context(
				sel_blk.card, sel_blk.direction, sel_blk.target_enemy_id, blk_origin
			)
		if timeline_view != null:
			timeline_view.clear_ghost_card()
			timeline_view.set_target_pick_context(sel_blk.card)
	else:
		if arena_view != null:
			arena_view.set_aiming_context(null, Types.Direction.NORTH, -1)
		if timeline_view != null:
			timeline_view.clear_ghost_card()
			timeline_view.set_target_pick_context(null)


func _refresh_planning_hud_state() -> void:
	if hud_view == null or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	var sel_blk: TimelineBlock = timeline_view.selected_block if timeline_view != null else null
	hud_view.refresh_planning_hud(
		_encounter.take_number,
		_encounter.state,
		_encounter.plan,
		_encounter.deck,
		_encounter.preview_result,
		_config,
		_encounter.can_undo,
		_encounter.can_redo,
		sel_blk
	)


func _on_enemy_picked(p_enemy_id: int) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	if hand_view != null and hand_view.selected_card != null:
		hand_view.set_target_enemy_id(p_enemy_id)
		return
	if timeline_view != null and timeline_view.selected_block != null:
		var blk: TimelineBlock = timeline_view.selected_block
		if blk.card.requires_enemy_target():
			var base_state: CombatState = _encounter.state
			var enemy: EnemyState = base_state.get_enemy_by_id(p_enemy_id)
			if enemy == null or not enemy.is_alive:
				return
			if blk.card.requires_frozen_enemy_target() and not enemy.is_frozen:
				return
			var updated: TimelineBlock = _encounter.move_or_reaim_block(
				blk, blk.track_index, blk.start_frame, blk.direction, p_enemy_id, true
			)
			if updated != null:
				_select_timeline_block(updated)


func _on_timeline_enemy_lane_hovered(p_enemy_id: int) -> void:
	if arena_view != null:
		arena_view.set_external_hovered_enemy_id(p_enemy_id)


func _on_arena_direction_aimed(p_direction: Types.Direction) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	if hand_view != null and hand_view.selected_card != null:
		hand_view.set_aim_direction(p_direction)
		return
	if timeline_view != null and timeline_view.selected_block != null:
		_reaim_selected_block_direction(p_direction)


func _on_timeline_track_frame_clicked(p_track: int, p_frame: int) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING or hand_view == null:
		return
	if not hand_view.can_commit_selected_placement():
		return
	var placed: TimelineBlock = _encounter.place_card(
		hand_view.selected_card,
		p_track,
		p_frame,
		hand_view.aim_direction,
		hand_view.target_enemy_id
	)
	if placed != null:
		_select_timeline_block(placed)


func _on_timeline_card_dropped(
	p_slot_index: int,
	p_card: CardData,
	p_track: int,
	p_start_frame: int
) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING or p_card == null:
		return

	var chosen_dir: Types.Direction = Types.Direction.NORTH
	var chosen_target_id: int = -1

	if hand_view != null and hand_view.selected_card == p_card:
		chosen_dir = hand_view.aim_direction
		chosen_target_id = hand_view.target_enemy_id
	else:
		if p_card.requires_cardinal_direction():
			chosen_dir = _compute_smart_direction(p_start_frame)
		elif p_card.requires_timeline_direction():
			chosen_dir = Types.Direction.EAST

	if p_card.requires_enemy_target():
		if not _is_valid_target_for_card(p_card, chosen_target_id):
			chosen_target_id = _compute_smart_target_enemy(p_card)
		if chosen_target_id < 0:
			return

	if hand_view != null:
		hand_view.notify_slot_acted(p_slot_index)

	var placed: TimelineBlock = _encounter.place_card(
		p_card, p_track, p_start_frame, chosen_dir, chosen_target_id
	)
	if placed != null:
		_select_timeline_block(placed)


func _on_timeline_block_move_requested(
	p_block: TimelineBlock,
	p_new_track: int,
	p_new_start_frame: int,
	p_record_undo: bool
) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	var moved: TimelineBlock = _encounter.move_or_reaim_block(
		p_block, p_new_track, p_new_start_frame, p_block.direction, p_block.target_enemy_id, p_record_undo
	)
	if moved != null:
		_select_timeline_block(moved)


func _on_timeline_block_remove_requested(p_block: TimelineBlock) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	_encounter.remove_block(p_block)


func _nudge_selected_block(p_delta_frames: int) -> void:
	if _encounter == null or timeline_view == null or timeline_view.selected_block == null:
		return
	var blk: TimelineBlock = timeline_view.selected_block
	var moved: TimelineBlock = _encounter.move_or_reaim_block(
		blk, blk.track_index, blk.start_frame + p_delta_frames, blk.direction, blk.target_enemy_id, true
	)
	if moved != null:
		_select_timeline_block(moved)


func _reaim_selected_block_direction(p_direction: Types.Direction) -> void:
	if _encounter == null or timeline_view == null or timeline_view.selected_block == null:
		return
	var blk: TimelineBlock = timeline_view.selected_block
	var norm_dir: Types.Direction = p_direction
	if blk.card.requires_timeline_direction():
		if norm_dir != Types.Direction.WEST and norm_dir != Types.Direction.EAST:
			return
	elif not blk.card.requires_cardinal_direction():
		return
	if norm_dir == blk.direction:
		return
	var updated: TimelineBlock = _encounter.move_or_reaim_block(
		blk, blk.track_index, blk.start_frame, norm_dir, blk.target_enemy_id, true
	)
	if updated != null:
		_select_timeline_block(updated)


func _on_timeline_frame_scrubbed(p_frame: int) -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	var preview: SimulationResult = _encounter.preview_result
	if preview == null:
		return
	_set_gate_frame_text(p_frame)
	var snap: CombatState = preview.get_snapshot(p_frame)
	var frame_events: Array[CombatEvent] = preview.get_events_on_frame(p_frame)
	if arena_view != null:
		arena_view.render_frame_snapshot(snap, p_frame, preview, true)
	if hud_view != null:
		hud_view.refresh_scrub_hud(_encounter.take_number, p_frame, snap, _encounter.plan, frame_events)


func _on_timeline_scrub_cleared() -> void:
	if not _interactive_enabled or _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	var preview: SimulationResult = _encounter.preview_result
	if preview == null:
		return
	_set_gate_frame_text(0)
	var base_state: CombatState = _encounter.state
	if arena_view != null:
		arena_view.render_planning_overview(base_state, preview)
	_refresh_planning_hud_state()


func _on_undo_requested() -> void:
	if _interactive_enabled and _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		_encounter.undo()


func _on_redo_requested() -> void:
	if _interactive_enabled and _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		_encounter.redo()


func _on_clear_requested() -> void:
	if _interactive_enabled and _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		_encounter.clear_timeline()


func _on_commit_requested() -> void:
	if _interactive_enabled and _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		_encounter.commit_take()


func _on_restart_requested() -> void:
	if not _is_managed_run and _encounter_data != null and _config != null:
		start_encounter(_encounter_data, _config)


func _on_take_committed(_p_take_number: int, p_result: SimulationResult) -> void:
	_playback_result = p_result
	_recorded_takes.append(p_result)
	if timeline_view != null:
		timeline_view.set_selected_block(null)
		timeline_view.set_target_pick_context(null)
	if hand_view != null:
		hand_view.clear_selection()
		hand_view.set_placed_clip_context(null)
		hand_view.visible = false
	if arena_view != null:
		arena_view.set_aiming_context(null, Types.Direction.NORTH, -1)
	set_interactive_enabled(_interactive_enabled)

	if playback_controller != null:
		playback_controller.play_result(p_result)
	else:
		_finish_post_playback()


func _on_playback_frame_stepped(
	p_frame: int,
	p_snapshot: CombatState,
	p_events: Array[CombatEvent]
) -> void:
	_set_gate_frame_text(p_frame)
	if arena_view != null:
		arena_view.render_frame_snapshot(p_snapshot, p_frame, _playback_result, false)
	if timeline_view != null:
		timeline_view.set_playhead_frame(p_frame)
	if hud_view != null and _encounter != null:
		var shown_take: int = (_replay_index + 1) if _is_replaying else _encounter.take_number
		hud_view.refresh_playback_hud(shown_take, p_frame, p_snapshot, _encounter.plan, p_events)


func _on_playback_finished(_p_result: SimulationResult) -> void:
	if _is_replaying:
		_replay_index += 1
		if _replay_index < _replay_queue.size():
			_start_current_replay_take()
		else:
			_finish_action_replay()
		return

	_playback_result = null
	_set_gate_frame_text(0)
	if timeline_view != null:
		timeline_view.set_playhead_frame(TimelineEditorView.NO_FRAME)
	_finish_post_playback()


func _start_current_replay_take() -> void:
	if _replay_index < 0 or _replay_index >= _replay_queue.size():
		_finish_action_replay()
		return
	var take_res: SimulationResult = _replay_queue[_replay_index]
	_playback_result = take_res
	replay_take_started.emit(_replay_index + 1, _replay_queue.size())
	playback_controller.play_result(take_res)


func _finish_action_replay() -> void:
	_is_replaying = false
	_playback_result = null
	_replay_queue.clear()
	if playback_controller != null:
		playback_controller.playback_fps = _saved_fps
		playback_controller.hit_stop_seconds = _saved_hit_stop
	if timeline_view != null:
		timeline_view.set_playhead_frame(TimelineEditorView.NO_FRAME)
	replay_completed.emit()


func _finish_post_playback() -> void:
	if _encounter == null:
		return
	if _encounter.is_over:
		if _is_managed_run:
			scene_finished.emit(
				_encounter.phase == CombatEncounter.Phase.VICTORY,
				_encounter.state,
				_encounter.take_number,
				_recorded_takes.duplicate()
			)
		elif hud_view != null:
			hud_view.show_end_banner(
				_encounter.phase == CombatEncounter.Phase.VICTORY,
				_encounter.take_number
			)
	else:
		_encounter.start_next_take()


# --- Smart Drop Targeting Helpers ---

func _get_player_origin_before_frame(p_frame: int) -> Vector2i:
	if _encounter == null:
		return Vector2i.ZERO
	var base_state: CombatState = _encounter.state
	var preview: SimulationResult = _encounter.preview_result
	if p_frame <= 0 or preview == null or preview.total_frames <= 0:
		return base_state.player.grid_position
	return preview.get_snapshot(p_frame - 1).player.grid_position


func _compute_smart_direction(p_start_frame: int) -> Types.Direction:
	if _encounter == null:
		return Types.Direction.NORTH
	var base_state: CombatState = _encounter.state
	var origin: Vector2i = _get_player_origin_before_frame(p_start_frame)
	var fallback_dir: Types.Direction = base_state.player.direction

	var nearest: EnemyState = null
	var best_dist: int = 9999
	for enemy: EnemyState in base_state.get_living_enemies():
		var dist: int = absi(enemy.grid_position.x - origin.x) + absi(enemy.grid_position.y - origin.y)
		if dist < best_dist:
			best_dist = dist
			nearest = enemy

	if nearest == null:
		return fallback_dir
	return Types.direction_toward(origin, nearest.grid_position, fallback_dir)


func _is_valid_target_for_card(p_card: CardData, p_enemy_id: int) -> bool:
	if _encounter == null or p_enemy_id < 0:
		return false
	var enemy: EnemyState = _encounter.state.get_enemy_by_id(p_enemy_id)
	if enemy == null or not enemy.is_alive:
		return false
	if p_card.requires_frozen_enemy_target() and not enemy.is_frozen:
		return false
	return true


func _compute_smart_target_enemy(p_card: CardData) -> int:
	if _encounter == null:
		return -1
	var living: Array[EnemyState] = _encounter.state.get_living_enemies()
	if p_card.requires_frozen_enemy_target():
		for enemy: EnemyState in living:
			if enemy.is_frozen:
				return enemy.id
		return -1

	for enemy: EnemyState in living:
		if not enemy.is_frozen and not enemy.attack_intents.is_empty():
			return enemy.id
	if not living.is_empty():
		return living[0].id
	return -1


func _set_gate_frame_text(p_frame: int) -> void:
	if frame_gate_label != null:
		frame_gate_label.text = "frame %d" % maxi(0, p_frame)
