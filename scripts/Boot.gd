class_name Boot
extends Node

@export var build_version: String = "0.2.0"
@export var config: CombatConfig
@export var run_headless_tests_on_boot: bool = true
@export_range(4, 24) var campaign_total_scenes: int = 8

@export_group("Startup Encounter")
@export var initial_encounter_data: EncounterData
@export var combat_screen: CombatScreen

var _is_initialized: bool = false
var _director: RunDirector = null
var _overlay: RunOverlayView = null
var _pending_wrap: RunDirector.SceneWrapInfo = null


func _ready() -> void:
	_initialize_game()


func _initialize_game() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	print("[XXIV] Engine online. Version: %s" % build_version)

	if config == null:
		config = CombatConfig.new()

	if run_headless_tests_on_boot:
		HeadlessTestRunner.run_all(config)

	_director = RunDirector.new(config, campaign_total_scenes)
	_overlay = RunOverlayView.new()
	add_child(_overlay)

	_sync_overlay_debug_catalog()
	_bind_loop_signals()
	_open_main_menu()


func _sync_overlay_debug_catalog() -> void:
	var notes: Array[String] = []
	var boss_flags: Array[bool] = []
	for s_num: int in range(1, _director.total_scenes + 1):
		notes.append(_director.get_debug_scene_preview_note(s_num))
		boss_flags.append(_director.is_boss_scene_by_default(s_num))
	_overlay.configure_debug_catalog(_director.total_scenes, notes, boss_flags)


func _bind_loop_signals() -> void:
	_overlay.descend_requested.connect(_on_descend_requested)
	_overlay.archetype_picked.connect(_on_archetype_picked)
	_overlay.debug_scene_selected.connect(_on_debug_scene_selected)
	_overlay.return_to_title_requested.connect(_open_main_menu)
	_overlay.scene_intro_dismissed.connect(_on_scene_intro_dismissed)
	_overlay.replay_skip_requested.connect(_on_replay_skip_requested)
	_overlay.scene_wrap_continued.connect(_on_scene_wrap_continued)
	_overlay.reward_card_chosen.connect(_on_reward_card_chosen)
	_overlay.reward_skipped.connect(_on_reward_skipped)
	_overlay.path_chosen.connect(_on_path_chosen)
	_overlay.rest_heal_chosen.connect(_on_rest_heal_chosen)
	_overlay.rest_upgrade_chosen.connect(_on_rest_upgrade_chosen)
	_overlay.play_again_requested.connect(_on_play_again_requested)
	_overlay.overlay_blocking_changed.connect(_on_overlay_blocking_changed)

	if combat_screen != null:
		combat_screen.scene_finished.connect(_on_combat_scene_finished)
		combat_screen.replay_take_started.connect(_on_replay_take_started)
		combat_screen.replay_completed.connect(_on_replay_completed)


# --- Game Loop State Transitions ---

func _stop_active_combat_playback() -> void:
	if combat_screen == null:
		return
	combat_screen.skip_action_replay()
	if combat_screen.playback_controller != null:
		combat_screen.playback_controller.stop()


func _open_main_menu() -> void:
	_pending_wrap = null
	_stop_active_combat_playback()
	if combat_screen != null:
		combat_screen.set_combat_visible(false)
	_overlay.show_main_menu(_director.best_scene, _director.total_scenes, _director.best_score)


func _on_descend_requested() -> void:
	_pending_wrap = null
	_stop_active_combat_playback()
	if combat_screen != null:
		combat_screen.set_combat_visible(false)
	_overlay.show_loadout_select(_director.get_archetypes())


func _on_play_again_requested() -> void:
	if _director.is_debug_mode:
		_director.start_debug_showcase_at_scene(_director.current_scene, _director.current_node_kind)
		_launch_current_combat_scene()
	else:
		_on_descend_requested()


func _on_archetype_picked(p_archetype_id: String) -> void:
	_director.start_new_run(p_archetype_id)
	_launch_current_combat_scene()


func _on_debug_scene_selected(p_scene_number: int, p_node_kind: RunDirector.NodeKind) -> void:
	_pending_wrap = null
	_stop_active_combat_playback()
	_overlay.hide_all_overlays()
	_director.start_debug_showcase_at_scene(p_scene_number, p_node_kind)
	_launch_current_combat_scene()


func _launch_current_combat_scene() -> void:
	if combat_screen == null:
		return
	var encounter: CombatEncounter = _director.build_current_encounter()
	combat_screen.set_combat_visible(true)
	combat_screen.start_managed_encounter(
		encounter,
		_director.run_config,
		_director.current_scene,
		_director.total_scenes
	)
	_overlay.set_top_toolbar_visible(true, _director.deck, _director.is_debug_mode)
	_overlay.show_scene_intro(
		"%s   •   Scene %d of %d%s" % [
			_director.get_act_title(_director.current_scene),
			_director.current_scene,
			_director.total_scenes,
			"   •   DEBUG SHOWCASE" if _director.is_debug_mode else ""
		],
		_director.get_scene_headline(_director.current_scene, _director.current_node_kind),
		_director.get_scene_subline(_director.current_scene, _director.current_node_kind)
	)


func _on_scene_intro_dismissed() -> void:
	if combat_screen != null:
		combat_screen.set_interactive_enabled(true)


func _on_overlay_blocking_changed(p_is_blocking: bool) -> void:
	if combat_screen != null:
		combat_screen.set_interactive_enabled(not p_is_blocking)


func _on_combat_scene_finished(
	p_is_victory: bool,
	p_final_state: CombatState,
	p_takes_used: int,
	p_recorded_takes: Array[SimulationResult]
) -> void:
	if not p_is_victory:
		_director.record_scene_defeat(p_takes_used, p_recorded_takes)
		combat_screen.set_combat_visible(false)
		_overlay.show_run_over(false, _director)
		return

	_pending_wrap = _director.record_scene_victory(p_final_state, p_takes_used, p_recorded_takes)
	_overlay.show_action_replay_banner(1, maxi(1, p_recorded_takes.size()))
	combat_screen.play_action_replay(p_recorded_takes)


func _on_replay_take_started(p_take_index: int, p_total_takes: int) -> void:
	_overlay.update_action_replay_take(p_take_index, p_total_takes)


func _on_replay_skip_requested() -> void:
	if combat_screen != null:
		combat_screen.skip_action_replay()


func _on_replay_completed() -> void:
	if _pending_wrap == null:
		return
	_overlay.show_scene_wrap(_pending_wrap)


func _on_scene_wrap_continued() -> void:
	if combat_screen != null:
		combat_screen.set_combat_visible(false)
	if _pending_wrap != null and _pending_wrap.is_final_scene:
		_overlay.show_run_over(true, _director)
		return

	if _director.is_debug_mode:
		_present_path_choice()
		return

	var offered: Array[CardData] = _director.roll_reward_cards(3)
	_overlay.show_card_reward(
		_director.current_scene,
		offered,
		_director.player_hp,
		_director.player_max_hp,
		_director.deck,
		_director.is_debug_mode
	)


func _on_reward_card_chosen(p_card: CardData) -> void:
	_director.claim_reward_card(p_card)
	_present_path_choice()


func _on_reward_skipped() -> void:
	_director.skip_reward_for_heal()
	_present_path_choice()


func _present_path_choice() -> void:
	var options: Array[RunDirector.NodeKind] = _director.prepare_next_scene_options()
	if options.size() == 1 and options[0] == RunDirector.NodeKind.BOSS:
		_director.choose_next_node(RunDirector.NodeKind.BOSS)
		_launch_current_combat_scene()
		return

	_overlay.show_path_select(
		_director.current_scene + 1,
		_director.total_scenes,
		options,
		_director.player_hp,
		_director.player_max_hp,
		_director.deck,
		_director.is_debug_mode
	)


func _on_path_chosen(p_node_kind: RunDirector.NodeKind) -> void:
	_director.choose_next_node(p_node_kind)
	if p_node_kind == RunDirector.NodeKind.REST:
		_overlay.show_rest_site(
			_director.get_rest_heal_amount(),
			_director.player_hp,
			_director.player_max_hp,
			_director.deck,
			_director.get_upgradable_deck_indices(),
			_director.is_debug_mode
		)
	else:
		_launch_current_combat_scene()


func _on_rest_heal_chosen() -> void:
	_director.perform_rest_heal()
	_present_path_choice()


func _on_rest_upgrade_chosen(p_deck_index: int) -> void:
	_director.upgrade_card_at_deck_index(p_deck_index)
	_present_path_choice()
