@tool
class_name CombatHudView
extends Control

## Cutting-Room Bench HUD:
## 1. Borderless top strip with vertical cream-stock HP pips (including striped predicted HP loss)
##    and 3 Speed Tier boxes (Tier 3 in grease-pencil yellow), underlined by a 1px steel rule.
## 2. Borderless top-right Briefing / Frame / Clip Inspector with natural-language prose.
## 3. Bottom-right control footer with 'Undo', 'Redo', 'Clear', and '● Execute'.

signal undo_requested()
signal redo_requested()
signal clear_requested()
signal commit_requested()
signal restart_requested()

const HP_PIP_SIZE: Vector2 = Vector2(8.0, 17.0)
const HP_PIP_GAP: float = 2.0
const TIER_PIP_SIZE: Vector2 = Vector2(15.0, 10.0)
const TIER_PIP_GAP: float = 3.0

@export_group("Scene Metadata")
@export var scene_number: int = 1
@export var total_scenes: int = 24

@export_group("Forecast Box References")
@export var objective_label: Label
@export var warning_label: Label
@export var frame_title_label: Label
@export var you_detail_label: Label
@export var hostiles_detail_label: Label

@export_group("Footer References")
@export var undo_button: Button
@export var redo_button: Button
@export var clear_button: Button
@export var piles_label: Label
@export var commit_button: Button

@export_group("End Slate References")
@export var end_banner_panel: Control
@export var end_title_label: Label
@export var restart_button: Button

@export_group("Cutting-Room Palette")
@export var rule_color: Color = Color(0.275, 0.318, 0.294, 1.0)          # #46514b
@export var stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)         # #e6e0d1
@export var soft_text_color: Color = Color(0.678, 0.714, 0.690, 1.0)     # #adb6b0
@export var mute_text_color: Color = Color(0.545, 0.584, 0.561, 1.0)     # #8b958f
@export var ochre_hostile_color: Color = Color(0.886, 0.710, 0.427, 1.0) # #e2b56d
@export var danger_color: Color = Color(0.933, 0.478, 0.404, 1.0)        # #ee7a67
@export var gold_color: Color = Color(0.941, 0.863, 0.333, 1.0)          # #f0dc55
@export var shield_blue_color: Color = Color(0.498, 0.624, 0.878, 1.0)   # #7f9fe0
@export var victory_color: Color = Color(0.498, 0.749, 0.690, 1.0)       # #7fbfb0

var _take_number: int = 1
var _current_hp: int = 14
var _predicted_hp: int = 14
var _max_hp: int = 14
var _shield: int = 0
var _tier: Types.SpeedTier = Types.SpeedTier.BASE
var _motion_scheduled: int = 0
var _motion_threshold: int = 12
var _promotes_this_take: bool = false
var _is_planning_mode: bool = true
var _can_undo: bool = false
var _can_redo: bool = false
var _has_blocks: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip_forecast_panel_box()

	if undo_button != null:
		undo_button.focus_mode = Control.FOCUS_NONE
		if not undo_button.pressed.is_connected(_on_undo_pressed):
			undo_button.pressed.connect(_on_undo_pressed)
	if redo_button != null:
		redo_button.focus_mode = Control.FOCUS_NONE
		if not redo_button.pressed.is_connected(_on_redo_pressed):
			redo_button.pressed.connect(_on_redo_pressed)
	if clear_button != null:
		clear_button.focus_mode = Control.FOCUS_NONE
		if not clear_button.pressed.is_connected(_on_clear_pressed):
			clear_button.pressed.connect(_on_clear_pressed)
	if commit_button != null:
		commit_button.focus_mode = Control.FOCUS_NONE
		if not commit_button.pressed.is_connected(_on_commit_pressed):
			commit_button.pressed.connect(_on_commit_pressed)
	if restart_button != null:
		restart_button.focus_mode = Control.FOCUS_NONE
		if not restart_button.pressed.is_connected(_on_restart_pressed):
			restart_button.pressed.connect(_on_restart_pressed)

	hide_end_banner()
	queue_redraw()


func refresh_planning_hud(
	p_take_number: int,
	p_base_state: CombatState,
	p_plan: TimelinePlan,
	p_deck: DeckState,
	p_preview: SimulationResult,
	p_config: CombatConfig,
	p_can_undo: bool = false,
	p_can_redo: bool = false,
	p_selected_block: TimelineBlock = null
) -> void:
	_is_planning_mode = true
	_take_number = p_take_number
	_current_hp = p_base_state.player.hp
	_predicted_hp = p_preview.final_state.player.hp if p_preview != null else _current_hp
	_max_hp = maxi(1, p_base_state.player.max_hp)
	_shield = p_base_state.player.shield
	_tier = p_base_state.player.tier
	_motion_scheduled = p_plan.total_motion_frames if p_plan != null else 0
	_motion_threshold = p_config.get_promotion_threshold(_tier) if p_config != null else 12
	_promotes_this_take = p_plan.qualifies_for_tier_promotion if p_plan != null else false
	_can_undo = p_can_undo
	_can_redo = p_can_redo
	_has_blocks = p_plan != null and not p_plan.blocks.is_empty()

	_apply_objective(p_base_state)
	_apply_forecast_prose(p_base_state, p_plan, p_preview)
	_apply_deck_counts(p_deck)
	_set_planning_buttons_enabled(true)

	if p_selected_block != null:
		refresh_selected_clip_hud(p_selected_block, p_base_state, p_preview)
		queue_redraw()
		return

	if frame_title_label != null:
		frame_title_label.text = "Briefing"
		frame_title_label.modulate = stock_color
	if you_detail_label != null:
		var end_pos: Vector2i = (
			p_preview.final_state.player.grid_position
			if p_preview != null
			else p_base_state.player.grid_position
		)
		var staged_cnt: int = p_plan.blocks.size() if p_plan != null else 0
		you_detail_label.text = "You: (%d,%d) → (%d,%d), %d clip%s staged." % [
			p_base_state.player.grid_position.x,
			p_base_state.player.grid_position.y,
			end_pos.x,
			end_pos.y,
			staged_cnt,
			"" if staged_cnt == 1 else "s"
		]
		you_detail_label.modulate = soft_text_color
	if hostiles_detail_label != null:
		hostiles_detail_label.text = _describe_overview_hostiles(p_base_state)
		hostiles_detail_label.modulate = ochre_hostile_color

	queue_redraw()


func refresh_selected_clip_hud(
	p_block: TimelineBlock,
	p_base_state: CombatState,
	p_preview: SimulationResult
) -> void:
	if p_block == null:
		return
	var card: CardData = p_block.card
	var title: String = card.display_name if not card.display_name.is_empty() else card.id
	if frame_title_label != null:
		frame_title_label.text = title
		frame_title_label.modulate = stock_color

	var track_str: String = "Motion" if p_block.track_index == TimelinePlan.TRACK_MOTION else "Action"
	var weight_str: String = "light" if p_block.duration <= 2 else ("medium" if p_block.duration <= 5 else "heavy")
	var meta_parts: PackedStringArray = PackedStringArray()
	meta_parts.append("%s track, frames %d–%d (%df, %s)" % [
		track_str, p_block.start_frame, p_block.end_frame, p_block.duration, weight_str
	])
	if card.requires_cardinal_direction():
		meta_parts.append("aimed %s" % _cardinal_short(p_block.direction))
	elif card.requires_timeline_direction():
		meta_parts.append("CCW / Earlier" if p_block.direction == Types.Direction.WEST else "CW / Later")
	elif card.requires_enemy_target() and p_base_state != null and p_block.target_enemy_id >= 0:
		var tgt: EnemyState = p_base_state.get_enemy_by_id(p_block.target_enemy_id)
		if tgt != null:
			meta_parts.append("target [%s]" % tgt.symbol)

	if you_detail_label != null:
		you_detail_label.text = card.description + "  —  " + ", ".join(meta_parts) + "."
		you_detail_label.modulate = ochre_hostile_color

	if hostiles_detail_label != null:
		var outcome_parts: PackedStringArray = PackedStringArray()
		var is_bad: bool = false
		if p_preview != null:
			for f: int in range(p_block.start_frame, p_block.end_frame + 1):
				if p_block.is_hit_frame(f):
					var is_cut: bool = p_preview.has_event_type(CombatEvent.Type.MATCH_CUT_TRIGGERED, f)
					var is_flow: bool = p_preview.has_event_type(CombatEvent.Type.FLOW_TRIGGERED, f)
					var tags: PackedStringArray = PackedStringArray()
					if is_flow:
						tags.append("flow")
					if is_cut:
						tags.append("match cut")
					var suffix: String = " (" + ", ".join(tags) + ")" if not tags.is_empty() else ""
					outcome_parts.append("Impact on frame %d%s" % [f, suffix])
			var viol_f: int = _find_block_violation(p_block, p_preview)
			if viol_f >= 0:
				is_bad = true
				outcome_parts.append("Violation on frame %d!" % viol_f)
		if outcome_parts.is_empty():
			outcome_parts.append("Drag clip or press ← / → to retime.")
		hostiles_detail_label.text = "  •  ".join(outcome_parts)
		hostiles_detail_label.modulate = danger_color if is_bad else soft_text_color


func refresh_scrub_hud(
	p_take_number: int,
	p_frame: int,
	p_snapshot: CombatState,
	p_plan: TimelinePlan,
	p_frame_events: Array[CombatEvent]
) -> void:
	_take_number = p_take_number
	_tier = p_snapshot.player.tier
	_shield = p_snapshot.player.shield

	if frame_title_label != null:
		frame_title_label.text = "Frame %d" % p_frame
		frame_title_label.modulate = stock_color
	if you_detail_label != null:
		var is_viol: bool = _frame_has_violation_or_freeze(p_snapshot, p_frame_events)
		you_detail_label.text = _describe_player_on_frame(p_frame, p_snapshot, p_plan, p_frame_events)
		you_detail_label.modulate = danger_color if is_viol else soft_text_color
	if hostiles_detail_label != null:
		hostiles_detail_label.text = _describe_hostiles_on_frame(p_frame, p_snapshot, p_frame_events)
		hostiles_detail_label.modulate = ochre_hostile_color

	queue_redraw()


func refresh_playback_hud(
	p_take_number: int,
	p_frame: int,
	p_snapshot: CombatState,
	p_plan: TimelinePlan,
	p_frame_events: Array[CombatEvent]
) -> void:
	_is_planning_mode = false
	_current_hp = p_snapshot.player.hp
	_predicted_hp = _current_hp
	_max_hp = maxi(1, p_snapshot.player.max_hp)
	refresh_scrub_hud(p_take_number, p_frame, p_snapshot, p_plan, p_frame_events)
	if warning_label != null:
		warning_label.text = "Rolling at 24 fps."
		warning_label.modulate = stock_color
	_set_planning_buttons_enabled(false)


func show_end_banner(p_is_victory: bool, p_take_number: int) -> void:
	_set_planning_buttons_enabled(false)
	if end_banner_panel != null:
		end_banner_panel.visible = true
	if end_title_label != null:
		if p_is_victory:
			end_title_label.text = "Scene complete in %d %s" % [
				p_take_number,
				"take" if p_take_number == 1 else "takes"
			]
			end_title_label.modulate = victory_color
		else:
			end_title_label.text = "Frame dropped — Subject #24 terminated"
			end_title_label.modulate = danger_color


func hide_end_banner() -> void:
	if end_banner_panel != null:
		end_banner_panel.visible = false


# --- Cutting-Room Header & Rule Lines (_draw) ---

func _draw() -> void:
	var font: Font = get_theme_default_font()
	var right_edge: float = maxf(400.0, size.x - 24.0)

	# 1. Top Header Bottom Steel Rule (Y = 54) + Briefing Bottom Steel Rule (X = 972..1896, Y = 186)
	draw_line(Vector2(24.0, 54.0), Vector2(right_edge, 54.0), rule_color, 1.0)
	if size.x >= 1000.0:
		draw_line(Vector2(972.0, 186.0), Vector2(right_edge, 186.0), rule_color, 1.0)

	if font == null:
		return

	var base_y: float = 36.0

	# 2. XXIV Wordmark, Scene & Take
	draw_string(font, Vector2(28.0, base_y + 2.0), "XXIV", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, stock_color)
	draw_string(font, Vector2(118.0, base_y), "Scene %d" % scene_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, stock_color)
	draw_string(font, Vector2(180.0, base_y), "of %d" % total_scenes, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, mute_text_color)
	draw_string(font, Vector2(238.0, base_y), "Take %d" % _take_number, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, stock_color)

	# 3. Vertical Cream-Stock HP Pips (8x17) with Red-Striped Predicted Loss
	var hp_label_x: float = 322.0
	draw_string(font, Vector2(hp_label_x, base_y), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, soft_text_color)
	var pips_x: float = hp_label_x + 28.0
	var pip_top_y: float = 21.0
	var total_pips: int = maxi(1, _max_hp)
	for i: int in range(total_pips):
		var px: float = pips_x + float(i) * (HP_PIP_SIZE.x + HP_PIP_GAP)
		var pip_rect: Rect2 = Rect2(Vector2(px, pip_top_y), HP_PIP_SIZE)
		if _is_planning_mode and i >= _predicted_hp and i < _current_hp:
			draw_rect(pip_rect, stock_color, true)
			draw_line(
				Vector2(pip_rect.position.x + 1.0, pip_rect.position.y + 7.0),
				Vector2(pip_rect.end.x - 1.0, pip_rect.position.y + 1.0),
				danger_color, 2.0
			)
			draw_line(
				Vector2(pip_rect.position.x + 1.0, pip_rect.end.y - 1.0),
				Vector2(pip_rect.end.x - 1.0, pip_rect.position.y + 9.0),
				danger_color, 2.0
			)
			draw_rect(pip_rect, danger_color, false, 1.0)
		elif i < _current_hp:
			draw_rect(pip_rect, stock_color, true)
		else:
			draw_rect(pip_rect, Color(stock_color.r, stock_color.g, stock_color.b, 0.30), false, 1.0)

	var cursor_x: float = pips_x + float(total_pips) * (HP_PIP_SIZE.x + HP_PIP_GAP) + 12.0
	if _shield > 0:
		draw_string(font, Vector2(cursor_x, base_y), "+%d Shield" % _shield, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, shield_blue_color)
		cursor_x += 78.0
	else:
		cursor_x += 18.0

	# 4. Speed Tier Boxes (Pips 1..2 Cream, Pip 3 Gold)
	draw_string(font, Vector2(cursor_x, base_y), "Tier", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, soft_text_color)
	var tier_pips_x: float = cursor_x + 34.0
	var tier_top_y: float = 25.0
	for t: int in range(1, 4):
		var tx: float = tier_pips_x + float(t - 1) * (TIER_PIP_SIZE.x + TIER_PIP_GAP)
		var tr_rect: Rect2 = Rect2(Vector2(tx, tier_top_y), TIER_PIP_SIZE)
		var box_col: Color = gold_color if t == 3 else stock_color
		if int(_tier) >= t:
			draw_rect(tr_rect, box_col, true)
		else:
			draw_rect(tr_rect, box_col, false, 1.0)

	# 5. Compact Motion Progress Note Beside Tier
	var motion_x: float = tier_pips_x + 3.0 * (TIER_PIP_SIZE.x + TIER_PIP_GAP) + 16.0
	var motion_str: String = (
		"Motion %df (max tier)" % _motion_scheduled
		if _motion_threshold <= 0
		else "Motion %d of %df%s" % [
			_motion_scheduled,
			_motion_threshold,
			" ★" if _promotes_this_take else ""
		]
	)
	var motion_col: Color = gold_color if _promotes_this_take else mute_text_color
	draw_string(font, Vector2(motion_x, base_y), motion_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, motion_col)


# --- Private Readout & Prose Helpers ---

func _strip_forecast_panel_box() -> void:
	if objective_label == null:
		return
	var node: Node = objective_label.get_parent()
	while node != null and node != self:
		if node is PanelContainer:
			(node as PanelContainer).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			break
		node = node.get_parent()


func _apply_objective(p_state: CombatState) -> void:
	if objective_label != null:
		var count: int = p_state.get_living_enemies().size()
		objective_label.text = "Eliminate all hostiles (%d left)" % count
		objective_label.modulate = soft_text_color


func _apply_forecast_prose(
	p_base_state: CombatState,
	p_plan: TimelinePlan,
	p_preview: SimulationResult
) -> void:
	if warning_label == null:
		return

	if p_plan == null or p_plan.blocks.is_empty() or p_preview == null:
		warning_label.text = "Drag a card onto the timeline or press [1–9]."
		warning_label.modulate = stock_color
		return

	var final_state: CombatState = p_preview.final_state
	var hp_lost: int = maxi(0, p_base_state.player.hp - final_state.player.hp)
	var kills: int = maxi(0, p_base_state.get_living_enemies().size() - final_state.get_living_enemies().size())
	var freezes: int = _count_newly_frozen_enemies(p_base_state, final_state)
	var match_cuts: int = p_preview.count_events_of_type(CombatEvent.Type.MATCH_CUT_TRIGGERED)
	var flows: int = p_preview.count_events_of_type(CombatEvent.Type.FLOW_TRIGGERED)
	var promo_frame: int = _find_first_event_frame(p_preview, CombatEvent.Type.TIER_PROMOTED)
	var drop_frame: int = _find_first_event_frame(p_preview, CombatEvent.Type.TIER_DROPPED)
	var viol_frame: int = _find_first_violation_frame(p_preview)

	var parts: PackedStringArray = PackedStringArray()
	parts.append("You take %d." % hp_lost if hp_lost > 0 else "No damage.")
	if kills > 0:
		parts.append("Kills %d." % kills)
	if freezes > 0:
		parts.append("Freezes %d." % freezes)
	if match_cuts > 0:
		parts.append("%d match %s." % [match_cuts, "cut" if match_cuts == 1 else "cuts"])
	if flows > 0:
		parts.append("%d in flow." % flows)
	if promo_frame >= 0:
		parts.append("Tier up at frame %d." % promo_frame)
	if drop_frame >= 0:
		parts.append("Tier drops at frame %d." % drop_frame)
	elif p_base_state.player.tier > Types.SpeedTier.BASE and p_plan.has_momentum_bleed_gap():
		parts.append("Idle gap bleeds tier.")
	if viol_frame >= 0:
		parts.append("Violation at frame %d!" % viol_frame)
	if not final_state.player.is_alive:
		parts.append("This plan is lethal.")

	var is_bad: bool = hp_lost > 0 or viol_frame >= 0 or drop_frame >= 0 or not final_state.player.is_alive
	warning_label.text = "  ".join(parts)
	warning_label.modulate = danger_color if is_bad else stock_color


func _count_newly_frozen_enemies(p_before: CombatState, p_after: CombatState) -> int:
	var count: int = 0
	for after_e: EnemyState in p_after.get_living_enemies():
		if after_e.is_frozen:
			var before_e: EnemyState = p_before.get_enemy_by_id(after_e.id)
			if before_e == null or not before_e.is_frozen:
				count += 1
	return count


func _find_first_event_frame(p_preview: SimulationResult, p_type: CombatEvent.Type) -> int:
	for ev: CombatEvent in p_preview.events:
		if ev.type == p_type:
			return ev.frame
	return -1


func _find_first_violation_frame(p_preview: SimulationResult) -> int:
	for ev: CombatEvent in p_preview.events:
		if (
			ev.type == CombatEvent.Type.VIOLATION_180_TURN
			or ev.type == CombatEvent.Type.VIOLATION_WALL_CRASH
			or ev.type == CombatEvent.Type.VIOLATION_ENEMY_CRASH
		):
			return ev.frame
	return -1


func _find_block_violation(p_block: TimelineBlock, p_preview: SimulationResult) -> int:
	if p_block.card.family != Types.CardFamily.MOTION:
		return -1
	for ev: CombatEvent in p_preview.events:
		if ev.frame < p_block.start_frame or ev.frame > p_block.end_frame:
			continue
		if (
			ev.type == CombatEvent.Type.VIOLATION_180_TURN
			or ev.type == CombatEvent.Type.VIOLATION_WALL_CRASH
			or ev.type == CombatEvent.Type.VIOLATION_ENEMY_CRASH
		):
			return ev.frame
	return -1


func _cardinal_short(p_dir: Types.Direction) -> String:
	match p_dir:
		Types.Direction.NORTH:
			return "North ↑"
		Types.Direction.EAST:
			return "East →"
		Types.Direction.SOUTH:
			return "South ↓"
		Types.Direction.WEST:
			return "West ←"
		_:
			return ""


func _frame_has_violation_or_freeze(p_snapshot: CombatState, p_events: Array[CombatEvent]) -> bool:
	if p_snapshot.player.is_frozen:
		return true
	for ev: CombatEvent in p_events:
		if (
			ev.type == CombatEvent.Type.VIOLATION_180_TURN
			or ev.type == CombatEvent.Type.VIOLATION_WALL_CRASH
			or ev.type == CombatEvent.Type.VIOLATION_ENEMY_CRASH
		):
			return true
	return false


func _describe_overview_hostiles(p_state: CombatState) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for enemy: EnemyState in p_state.get_living_enemies():
		if enemy.is_frozen:
			parts.append("[%s] frozen (%df)" % [enemy.symbol, enemy.frozen_frames_remaining])
		else:
			for intent: AttackIntent in enemy.attack_intents:
				parts.append("[%s] %d dmg on f%02d" % [enemy.symbol, intent.damage, intent.end_frame])
	if parts.is_empty():
		return "Hostile: quiet."
	return "Hostile: " + ", ".join(parts) + "."


func _describe_player_on_frame(
	p_frame: int,
	p_snapshot: CombatState,
	p_plan: TimelinePlan,
	p_events: Array[CombatEvent]
) -> String:
	var notes: PackedStringArray = PackedStringArray()
	if p_snapshot.player.is_frozen:
		notes.append("frozen (%df)" % p_snapshot.player.frozen_frames_remaining)

	if p_plan != null:
		var m_blk: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_MOTION, p_frame)
		var a_blk: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_ACTION, p_frame)
		if m_blk != null:
			var m_name: String = m_blk.card.display_name if not m_blk.card.display_name.is_empty() else m_blk.card.id
			notes.append("%s: moves" % m_name if m_blk.is_step_frame(p_frame) else m_name)
		if a_blk != null:
			var a_name: String = a_blk.card.display_name if not a_blk.card.display_name.is_empty() else a_blk.card.id
			notes.append("%s: hits" % a_name if a_blk.is_hit_frame(p_frame) else a_name)

	for ev: CombatEvent in p_events:
		match ev.type:
			CombatEvent.Type.MATCH_CUT_TRIGGERED:
				notes.append("match cut")
			CombatEvent.Type.FLOW_TRIGGERED:
				notes.append("in flow (+%d)" % ev.value)
			CombatEvent.Type.PHASE_DODGED:
				notes.append("phase dodge")
			CombatEvent.Type.TIER_PROMOTED:
				notes.append("tier up")
			CombatEvent.Type.VIOLATION_180_TURN, CombatEvent.Type.VIOLATION_WALL_CRASH, CombatEvent.Type.VIOLATION_ENEMY_CRASH:
				notes.append("violation")

	if notes.is_empty():
		return "You: idle at (%d,%d)." % [p_snapshot.player.grid_position.x, p_snapshot.player.grid_position.y]
	return "You: " + ", ".join(notes) + "."


func _describe_hostiles_on_frame(
	p_frame: int,
	p_snapshot: CombatState,
	p_events: Array[CombatEvent]
) -> String:
	var notes: PackedStringArray = PackedStringArray()
	for ev: CombatEvent in p_events:
		if ev.type == CombatEvent.Type.ENEMY_ATTACK_HIT:
			notes.append("hits you for %d dmg" % ev.value)
	for enemy: EnemyState in p_snapshot.get_living_enemies():
		if enemy.is_frozen:
			continue
		for intent: AttackIntent in enemy.attack_intents:
			if intent.end_frame == p_frame:
				notes.append("[%s] strike impacts (%d dmg)" % [enemy.symbol, intent.damage])
			elif intent.is_active_on(p_frame):
				notes.append("[%s] strike (f%02d–%02d)" % [enemy.symbol, intent.start_frame, intent.end_frame])
	if notes.is_empty():
		return "Hostile: quiet."
	return "Hostile: " + ", ".join(notes) + "."


func _apply_deck_counts(p_deck: DeckState) -> void:
	if piles_label != null and p_deck != null:
		piles_label.text = "Draw %d   •   Disc %d   •   Exh %d" % [
			p_deck.draw_count,
			p_deck.discard_count,
			p_deck.exhaust_count
		]
		piles_label.modulate = mute_text_color


func _set_planning_buttons_enabled(p_enabled: bool) -> void:
	if undo_button != null:
		undo_button.disabled = (not p_enabled) or (not _can_undo)
	if redo_button != null:
		redo_button.disabled = (not p_enabled) or (not _can_redo)
	if clear_button != null:
		clear_button.disabled = (not p_enabled) or (not _has_blocks)
	if commit_button != null:
		commit_button.disabled = not p_enabled
		commit_button.queue_redraw()


func _on_undo_pressed() -> void:
	undo_requested.emit()


func _on_redo_pressed() -> void:
	redo_requested.emit()


func _on_clear_pressed() -> void:
	clear_requested.emit()


func _on_commit_pressed() -> void:
	commit_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()
