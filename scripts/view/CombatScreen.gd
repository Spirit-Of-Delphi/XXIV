class_name CombatScreen
extends Node

## Self-contained combat scene coordinator.
## Connects CombatEncounter (headless brain) to ArenaView, PlaybackController, HUD, Hand, and Timeline.

@export_group("View References")
@export var arena_view: ArenaView
@export var playback_controller: PlaybackController
@export var hud_view: CombatHudView
@export var hand_view: HandView
@export var timeline_view: TimelineEditorView

var _encounter_data: EncounterData = null
var _config: CombatConfig = null
var _encounter: CombatEncounter = null
var _signals_bound: bool = false


func start_encounter(p_encounter_data: EncounterData, p_config: CombatConfig) -> void:
	if p_encounter_data == null or p_config == null:
		return

	_encounter_data = p_encounter_data
	_config = p_config
	_bind_view_signals_once()

	if playback_controller != null:
		playback_controller.stop()
	if hud_view != null:
		hud_view.hide_end_banner()

	_encounter = _encounter_data.create_encounter(_config)
	_encounter.preview_updated.connect(_on_preview_updated)
	_encounter.take_committed.connect(_on_take_committed)
	_encounter.start_next_take()


func _unhandled_input(p_event: InputEvent) -> void:
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
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
		arena_view.enemy_clicked.connect(_on_arena_enemy_clicked)

	if timeline_view != null:
		timeline_view.frame_scrubbed.connect(_on_timeline_frame_scrubbed)
		timeline_view.scrub_cleared.connect(_on_timeline_scrub_cleared)
		timeline_view.track_frame_clicked.connect(_on_timeline_track_frame_clicked)
		timeline_view.block_remove_requested.connect(_on_timeline_block_remove_requested)

	if hand_view != null:
		hand_view.selection_changed.connect(_on_hand_selection_changed)

	if hud_view != null:
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

	if arena_view != null:
		arena_view.render_planning_overview(base_state, p_preview)
	if timeline_view != null:
		timeline_view.set_playhead_frame(TimelineEditorView.NO_FRAME)
		timeline_view.refresh_timeline(base_state, current_plan, _config.total_frames)
	if hand_view != null:
		hand_view.visible = true
		hand_view.refresh_hand(current_deck, base_state, current_plan.planning_tier, _config)
	if hud_view != null:
		hud_view.refresh_planning_hud(
			_encounter.take_number, base_state, current_plan, current_deck, p_preview, _config
		)


func _on_hand_selection_changed(
	p_selected_card: CardData,
	p_direction: Types.Direction,
	p_target_enemy_id: int
) -> void:
	if arena_view != null:
		var highlight_id: int = -1
		if p_selected_card != null and p_selected_card.requires_enemy_target():
			highlight_id = p_target_enemy_id
		arena_view.set_selected_enemy_id(highlight_id)

	if timeline_view != null:
		if p_selected_card != null and hand_view != null and hand_view.can_commit_selected_placement():
			timeline_view.set_ghost_card(p_selected_card, p_direction, p_target_enemy_id)
		else:
			timeline_view.clear_ghost_card()


func _on_arena_enemy_clicked(p_enemy_id: int) -> void:
	if hand_view != null and _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		hand_view.set_target_enemy_id(p_enemy_id)


func _on_timeline_track_frame_clicked(p_track: int, p_frame: int) -> void:
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING or hand_view == null:
		return
	if not hand_view.can_commit_selected_placement():
		return
	_encounter.place_card(
		hand_view.selected_card,
		p_track,
		p_frame,
		hand_view.aim_direction,
		hand_view.target_enemy_id
	)


func _on_timeline_block_remove_requested(p_block: TimelineBlock) -> void:
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	_encounter.remove_block(p_block)


func _on_timeline_frame_scrubbed(p_frame: int) -> void:
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	var preview: SimulationResult = _encounter.preview_result
	if preview == null:
		return
	var snap: CombatState = preview.get_snapshot(p_frame)
	if arena_view != null:
		arena_view.render_frame_snapshot(snap, p_frame, preview)
	if hud_view != null:
		hud_view.refresh_scrub_hud(_encounter.take_number, p_frame, snap)


func _on_timeline_scrub_cleared() -> void:
	if _encounter == null or _encounter.phase != CombatEncounter.Phase.PLANNING:
		return
	var preview: SimulationResult = _encounter.preview_result
	if preview == null:
		return
	var base_state: CombatState = _encounter.state
	if arena_view != null:
		arena_view.render_planning_overview(base_state, preview)
	if hud_view != null:
		hud_view.refresh_planning_hud(
			_encounter.take_number, base_state, _encounter.plan, _encounter.deck, preview, _config
		)


func _on_clear_requested() -> void:
	if _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		_encounter.clear_timeline()


func _on_commit_requested() -> void:
	if _encounter != null and _encounter.phase == CombatEncounter.Phase.PLANNING:
		_encounter.commit_take()


func _on_restart_requested() -> void:
	if _encounter_data != null and _config != null:
		start_encounter(_encounter_data, _config)


func _on_take_committed(_p_take_number: int, p_result: SimulationResult) -> void:
	if hand_view != null:
		hand_view.clear_selection()
		hand_view.visible = false
	if playback_controller != null:
		playback_controller.play_result(p_result)
	else:
		_finish_post_playback()


func _on_playback_frame_stepped(
	p_frame: int,
	p_snapshot: CombatState,
	_p_events: Array[CombatEvent]
) -> void:
	if arena_view != null:
		arena_view.render_frame_snapshot(p_snapshot, p_frame)
	if timeline_view != null:
		timeline_view.set_playhead_frame(p_frame)
	if hud_view != null and _encounter != null:
		hud_view.refresh_playback_hud(_encounter.take_number, p_frame, p_snapshot)


func _on_playback_finished(_p_result: SimulationResult) -> void:
	if timeline_view != null:
		timeline_view.set_playhead_frame(TimelineEditorView.NO_FRAME)
	_finish_post_playback()


func _finish_post_playback() -> void:
	if _encounter == null:
		return
	if _encounter.is_over:
		if hud_view != null:
			hud_view.show_end_banner(
				_encounter.phase == CombatEncounter.Phase.VICTORY,
				_encounter.take_number
			)
	else:
		_encounter.start_next_take()
