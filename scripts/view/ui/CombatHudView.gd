class_name CombatHudView
extends Control

## Top tactical status bar + centered Victory/Defeat slate overlay.
## Displays live Speed Tier, promotion progress, deck counts, and preview warnings.

signal clear_requested()
signal commit_requested()
signal restart_requested()

@export_group("Top Bar References")
@export var take_label: Label
@export var vitals_label: Label
@export var speed_tier_label: Label
@export var momentum_label: Label
@export var warning_label: Label
@export var piles_label: Label
@export var clear_button: Button
@export var commit_button: Button

@export_group("End Slate References")
@export var end_banner_panel: Control
@export var end_title_label: Label
@export var restart_button: Button

@export_group("Palette")
@export var tier_0_color: Color = Color(0.75, 0.80, 0.88, 1.0)
@export var tier_1_color: Color = Color(0.35, 0.85, 1.0, 1.0)
@export var tier_2_color: Color = Color(1.0, 0.78, 0.22, 1.0)
@export var tier_3_color: Color = Color(1.0, 0.28, 0.45, 1.0)
@export var warning_danger_color: Color = Color(1.0, 0.28, 0.32, 1.0)
@export var warning_caution_color: Color = Color(1.0, 0.76, 0.20, 1.0)
@export var warning_good_color: Color = Color(0.35, 0.96, 0.68, 1.0)
@export var victory_color: Color = Color(0.35, 0.96, 0.68, 1.0)
@export var defeat_color: Color = Color(1.0, 0.30, 0.34, 1.0)


func _ready() -> void:
	if clear_button != null:
		clear_button.focus_mode = Control.FOCUS_NONE
		clear_button.pressed.connect(_on_clear_pressed)
	if commit_button != null:
		commit_button.focus_mode = Control.FOCUS_NONE
		commit_button.pressed.connect(_on_commit_pressed)
	if restart_button != null:
		restart_button.focus_mode = Control.FOCUS_NONE
		restart_button.pressed.connect(_on_restart_pressed)
	hide_end_banner()


## Updates the HUD for the start-of-take Planning Overview.
func refresh_planning_hud(
	p_take_number: int,
	p_base_state: CombatState,
	p_plan: TimelinePlan,
	p_deck: DeckState,
	p_preview: SimulationResult,
	p_config: CombatConfig
) -> void:
	if take_label != null:
		take_label.text = "TAKE %02d  •  PLANNING" % p_take_number

	_apply_player_vitals_and_tier(p_base_state.player)
	_apply_momentum_progress(p_plan, p_config)
	_apply_preview_warnings(p_base_state.player, p_plan, p_preview)
	_apply_deck_counts(p_deck)
	_set_planning_buttons_enabled(true)


## Updates the HUD while hovering a specific frame on the timeline during PLANNING.
func refresh_scrub_hud(
	p_take_number: int,
	p_frame: int,
	p_snapshot: CombatState
) -> void:
	if take_label != null:
		take_label.text = "TAKE %02d  •  SCRUB f%02d" % [p_take_number, p_frame]
	_apply_player_vitals_and_tier(p_snapshot.player)


## Updates the HUD during 24-FPS execution playback.
func refresh_playback_hud(
	p_take_number: int,
	p_frame: int,
	p_snapshot: CombatState
) -> void:
	if take_label != null:
		take_label.text = "TAKE %02d  •  24 FPS [f%02d]" % [p_take_number, p_frame]
	_apply_player_vitals_and_tier(p_snapshot.player)
	if warning_label != null:
		warning_label.text = ""
	_set_planning_buttons_enabled(false)


func show_end_banner(p_is_victory: bool, p_take_number: int) -> void:
	_set_planning_buttons_enabled(false)
	if end_banner_panel != null:
		end_banner_panel.visible = true
	if end_title_label != null:
		if p_is_victory:
			end_title_label.text = "CUT! SCENE COMPLETE IN %d TAKES" % p_take_number
			end_title_label.modulate = victory_color
		else:
			end_title_label.text = "CUT! SUBJECT #24 TERMINATED"
			end_title_label.modulate = defeat_color


func hide_end_banner() -> void:
	if end_banner_panel != null:
		end_banner_panel.visible = false


# --- Private Helpers ---

func _apply_player_vitals_and_tier(p_player: PlayerState) -> void:
	if vitals_label != null:
		vitals_label.text = "HP %d/%d  |  SHIELD %d" % [p_player.hp, p_player.max_hp, p_player.shield]

	if speed_tier_label != null:
		match p_player.tier:
			Types.SpeedTier.TIER_1:
				speed_tier_label.text = "SPEED TIER 1"
				speed_tier_label.modulate = tier_1_color
			Types.SpeedTier.TIER_2:
				speed_tier_label.text = "SPEED TIER 2"
				speed_tier_label.modulate = tier_2_color
			Types.SpeedTier.TIER_3:
				speed_tier_label.text = "SPEED TIER 3 (MAX)"
				speed_tier_label.modulate = tier_3_color
			_:
				speed_tier_label.text = "SPEED TIER 0 (BASE)"
				speed_tier_label.modulate = tier_0_color


func _apply_momentum_progress(p_plan: TimelinePlan, p_config: CombatConfig) -> void:
	if momentum_label == null or p_plan == null or p_config == null:
		return
	var threshold: int = p_config.get_promotion_threshold(p_plan.planning_tier)
	var scheduled: int = p_plan.total_motion_frames
	if threshold <= 0:
		momentum_label.text = "MOTION: %df (MAX TIER)" % scheduled
	elif p_plan.qualifies_for_tier_promotion:
		momentum_label.text = "MOTION: %d/%df ★ PROMOTES!" % [scheduled, threshold]
	else:
		momentum_label.text = "MOTION: %d/%df" % [scheduled, threshold]


func _apply_preview_warnings(
	p_player: PlayerState,
	p_plan: TimelinePlan,
	p_preview: SimulationResult
) -> void:
	if warning_label == null:
		return

	if p_preview != null and (
		p_preview.has_event_type(CombatEvent.Type.VIOLATION_180_TURN)
		or p_preview.has_event_type(CombatEvent.Type.VIOLATION_WALL_CRASH)
		or p_preview.has_event_type(CombatEvent.Type.VIOLATION_ENEMY_CRASH)
	):
		warning_label.text = "⚠ VIOLATION: 24f GLASS FREEZE!"
		warning_label.modulate = warning_danger_color
	elif p_plan != null and p_player.tier > Types.SpeedTier.BASE and p_plan.has_momentum_bleed_gap():
		warning_label.text = "⚠ IDLE GAP: TIER WILL BLEED!"
		warning_label.modulate = warning_caution_color
	elif p_preview != null and p_preview.has_event_type(CombatEvent.Type.MATCH_CUT_TRIGGERED):
		warning_label.text = "✦ MATCH CUT LINED UP!"
		warning_label.modulate = warning_good_color
	else:
		warning_label.text = ""


func _apply_deck_counts(p_deck: DeckState) -> void:
	if piles_label != null and p_deck != null:
		piles_label.text = "DRAW %d  |  DISC %d  |  EXH %d" % [
			p_deck.draw_count,
			p_deck.discard_count,
			p_deck.exhaust_count
		]


func _set_planning_buttons_enabled(p_enabled: bool) -> void:
	if clear_button != null:
		clear_button.disabled = not p_enabled
	if commit_button != null:
		commit_button.disabled = not p_enabled


func _on_clear_pressed() -> void:
	clear_requested.emit()


func _on_commit_pressed() -> void:
	commit_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()
