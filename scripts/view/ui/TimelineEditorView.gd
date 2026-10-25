@tool
class_name TimelineEditorView
extends Control

## Cutting-Room Moviola 24-Frame Timeline Strip.
## Renders the Frame Ruler, Speed Tier Ribbon, Dynamic Enemy Threat Lanes (with dashed ghost
## cancelled intents & gold Match Cut windows), and Move/Action tape clips with full wind-up,
## impact diamond, recovery shading, drag-and-drop placement, and live clip retiming.

signal frame_scrubbed(p_frame: int)
signal scrub_cleared()
signal track_frame_clicked(p_track: int, p_frame: int)
signal block_selected(p_block: TimelineBlock)
signal block_move_requested(
	p_block: TimelineBlock,
	p_new_track: int,
	p_new_start_frame: int,
	p_record_undo: bool
)
signal block_remove_requested(p_block: TimelineBlock)
signal card_dropped_on_timeline(
	p_slot_index: int,
	p_card: CardData,
	p_track: int,
	p_start_frame: int
)
signal enemy_badge_clicked(p_enemy_id: int)
signal enemy_lane_hovered(p_enemy_id: int)

const NO_FRAME: int = -1
const NO_LANE: int = -99
const DEFAULT_PREVIEW_FRAMES: int = 24
const MAJOR_TICK_INTERVAL: int = 4
const MAX_SNAP_SEARCH_RADIUS: int = 6


class _DropCalc extends RefCounted:
	var valid: bool = false
	var track: int = TimelinePlan.TRACK_MOTION
	var start_frame: int = 0
	var fallback_frame: int = 0
	var duration: int = 1
	var card: CardData = null


@export_group("Layout Metrics")
@export_range(56.0, 120.0) var left_gutter_width: float = 76.0
@export_range(6.0, 24.0) var padding_x: float = 10.0
@export_range(6.0, 20.0) var padding_y: float = 8.0
@export_range(14.0, 28.0) var ruler_height: float = 16.0
@export_range(12.0, 24.0) var tier_row_height: float = 14.0
@export_range(16.0, 32.0) var enemy_lane_base_height: float = 22.0
@export_range(32.0, 56.0) var player_track_height: float = 38.0
@export_range(2.0, 12.0) var section_gap: float = 6.0

@export_group("Cutting-Room Palette")
@export var well_bg_color: Color = Color(0.137, 0.161, 0.153, 1.0)         # #232927
@export var cell_bg_color: Color = Color(0.165, 0.192, 0.180, 1.0)         # #2a312e
@export var rule_color: Color = Color(0.275, 0.318, 0.294, 1.0)            # #46514b
@export var rule2_color: Color = Color(0.365, 0.412, 0.388, 1.0)           # #5d6963
@export var stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)           # #e6e0d1
@export var soft_text_color: Color = Color(0.678, 0.714, 0.690, 1.0)       # #adb6b0
@export var mute_text_color: Color = Color(0.545, 0.584, 0.561, 1.0)       # #8b958f
@export var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)             # #1c1d1b
@export var vermilion_color: Color = Color(0.761, 0.231, 0.169, 1.0)       # #c23b2b
@export var danger_color: Color = Color(0.933, 0.478, 0.404, 1.0)          # #ee7a67
@export var gold_cut_color: Color = Color(0.941, 0.863, 0.333, 1.0)        # #f0dc55
@export var acetate_color: Color = Color(0.498, 0.749, 0.690, 1.0)         # #7fbfb0
@export var motion_clip_color: Color = Color(0.498, 0.624, 0.878, 1.0)     # #7f9fe0
@export var strike_clip_color: Color = Color(0.839, 0.627, 0.290, 1.0)     # #d6a04a
@export var tech_clip_color: Color = Color(0.769, 0.698, 0.494, 1.0)       # #c4b27e
@export var edit_clip_color: Color = Color(0.671, 0.561, 0.839, 1.0)       # #ab8fd6

var _total_frames: int = DEFAULT_PREVIEW_FRAMES
var _state: CombatState = null
var _plan: TimelinePlan = null
var _preview: SimulationResult = null

var _ghost_card: CardData = null
var _ghost_direction: Types.Direction = Types.Direction.NORTH
var _ghost_target_enemy_id: int = -1
var _target_pick_card: CardData = null

var _selected_block: TimelineBlock = null
var _dragging_block: TimelineBlock = null
var _drag_grab_frame_offset: int = 0
var _drag_has_moved: bool = false

var _active_drag_drop: _DropCalc = null

var _hovered_frame: int = NO_FRAME
var _hovered_lane: int = NO_LANE
var _hovered_block: TimelineBlock = null
var _hovered_enemy_id: int = -1
var _playhead_frame: int = NO_FRAME
var _enemy_badge_rects: Dictionary[int, Rect2] = {}
var _enemy_row_rects: Dictionary[int, Rect2] = {}


var selected_block: TimelineBlock:
	get: return _selected_block


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_recompute_minimum_height()
	queue_redraw()


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_DRAG_END:
		if _active_drag_drop != null:
			_active_drag_drop = null
			queue_redraw()
			if _hovered_frame == NO_FRAME:
				scrub_cleared.emit()


func refresh_timeline(
	p_state: CombatState,
	p_plan: TimelinePlan,
	p_total_frames: int,
	p_preview: SimulationResult = null
) -> void:
	_state = p_state
	_plan = p_plan
	_preview = p_preview
	_total_frames = maxi(1, p_total_frames)

	if _selected_block != null and (_plan == null or not _plan.blocks.has(_selected_block)):
		_selected_block = null
	if _dragging_block != null and (_plan == null or not _plan.blocks.has(_dragging_block)):
		_dragging_block = null

	_recompute_minimum_height()
	queue_redraw()


func set_selected_block(p_block: TimelineBlock) -> void:
	var resolved: TimelineBlock = p_block
	if resolved != null and (_plan == null or not _plan.blocks.has(resolved)):
		resolved = null
	_selected_block = resolved
	if _dragging_block != null and _selected_block != null:
		_dragging_block = _selected_block
	queue_redraw()


func set_ghost_card(
	p_card: CardData,
	p_direction: Types.Direction = Types.Direction.NORTH,
	p_target_enemy_id: int = -1
) -> void:
	_ghost_card = p_card
	_ghost_direction = p_direction
	_ghost_target_enemy_id = p_target_enemy_id
	queue_redraw()


func clear_ghost_card() -> void:
	_ghost_card = null
	queue_redraw()


func set_target_pick_context(p_card: CardData) -> void:
	_target_pick_card = p_card if (p_card != null and p_card.requires_enemy_target()) else null
	queue_redraw()


func set_playhead_frame(p_frame: int) -> void:
	if _playhead_frame == p_frame:
		return
	_playhead_frame = p_frame
	queue_redraw()


# --- Godot Native Drag-and-Drop Receivers (Hand -> Timeline) ---

func _can_drop_data(p_at_position: Vector2, p_data: Variant) -> bool:
	if typeof(p_data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = p_data as Dictionary
	if payload.get("kind", "") != "hand_card":
		return false
	var card: CardData = payload.get("card", null) as CardData
	if card == null or _plan == null:
		return false

	_active_drag_drop = _compute_smart_drop(card, p_at_position, true)
	var preview_frame: int = (
		_active_drag_drop.start_frame
		if _active_drag_drop.valid
		else _active_drag_drop.fallback_frame
	)
	if preview_frame != _hovered_frame:
		_hovered_frame = preview_frame
		frame_scrubbed.emit(preview_frame)
	queue_redraw()
	return _active_drag_drop.valid


func _drop_data(p_at_position: Vector2, p_data: Variant) -> void:
	if typeof(p_data) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = p_data as Dictionary
	if payload.get("kind", "") != "hand_card":
		return
	var card: CardData = payload.get("card", null) as CardData
	var slot_index: int = int(payload.get("slot_index", 0))
	if card == null or _plan == null:
		return

	var drop: _DropCalc = _compute_smart_drop(card, p_at_position, true)
	_active_drag_drop = null
	queue_redraw()
	if drop.valid:
		card_dropped_on_timeline.emit(slot_index, card, drop.track, drop.start_frame)


# --- Mouse Input (Scrubbing, Selection, Clip Sliding, Removal, Enemy Badge Picking) ---

func _gui_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = p_event as InputEventMouseMotion
		if _dragging_block != null and _plan != null:
			_handle_placed_clip_drag_motion(mm.position)
			accept_event()
			return
		_handle_hover_motion(mm.position)

	elif p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _dragging_block != null:
				_dragging_block = null
				_drag_has_moved = false
				_update_cursor_for_position(mb.position)
				queue_redraw()
				accept_event()
			return

		if not mb.pressed:
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_press(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and _plan != null:
			var click_frame: int = _x_to_frame(mb.position.x)
			var click_track: int = _y_to_track(mb.position.y)
			if (
				click_frame != NO_FRAME
				and (click_track == TimelinePlan.TRACK_MOTION or click_track == TimelinePlan.TRACK_ACTION)
			):
				var existing: TimelineBlock = _plan.get_block_at(click_track, click_frame)
				if existing != null:
					block_remove_requested.emit(existing)
					accept_event()


func _handle_left_press(p_pos: Vector2) -> void:
	# 1. Clickable Enemy Gutter Badge (for Edit card targeting)
	for enemy_id: int in _enemy_badge_rects.keys():
		if _enemy_badge_rects[enemy_id].has_point(p_pos):
			enemy_badge_clicked.emit(enemy_id)
			accept_event()
			return

	# 2. Top-Right '×' Remove Button on Hovered or Selected Placed Clip
	if _plan != null:
		for candidate: TimelineBlock in _plan.blocks:
			if candidate == _hovered_block or candidate == _selected_block:
				if _get_clip_close_rect(candidate).has_point(p_pos):
					block_remove_requested.emit(candidate)
					accept_event()
					return

	# 3. Armed Hand Card Click-Placement (with smart track & nearest-slot snapping)
	if _ghost_card != null and _plan != null and _x_to_frame(p_pos.x) != NO_FRAME:
		var drop: _DropCalc = _compute_smart_drop(_ghost_card, p_pos, false)
		if drop.valid:
			track_frame_clicked.emit(drop.track, drop.start_frame)
			accept_event()
			return

	# 4. Select & Begin Dragging an Existing Placed Clip
	var click_frame: int = _x_to_frame(p_pos.x)
	var click_track: int = _y_to_track(p_pos.y)
	if (
		_plan != null
		and click_frame != NO_FRAME
		and (click_track == TimelinePlan.TRACK_MOTION or click_track == TimelinePlan.TRACK_ACTION)
	):
		var hit_block: TimelineBlock = _plan.get_block_at(click_track, click_frame)
		if hit_block != null:
			_selected_block = hit_block
			_dragging_block = hit_block
			_drag_grab_frame_offset = clampi(click_frame - hit_block.start_frame, 0, hit_block.duration - 1)
			_drag_has_moved = false
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			block_selected.emit(hit_block)
			queue_redraw()
			accept_event()
			return

	# 5. Clicked Empty Space -> Deselect Placed Clip
	if _selected_block != null:
		_selected_block = null
		block_selected.emit(null)
		queue_redraw()


func _handle_placed_clip_drag_motion(p_pos: Vector2) -> void:
	if _dragging_block == null or _plan == null:
		return

	var raw_frame: int = _x_to_frame_unclamped(p_pos.x)
	var max_start: int = maxi(0, _total_frames - _dragging_block.duration)
	var desired_start: int = clampi(raw_frame - _drag_grab_frame_offset, 0, max_start)

	var desired_track: int = _dragging_block.track_index
	if _dragging_block.card.family == Types.CardFamily.EDIT:
		desired_track = _nearest_player_track_for_y(p_pos.y)

	if desired_start == _dragging_block.start_frame and desired_track == _dragging_block.track_index:
		return

	if _can_relocate_block(_dragging_block, desired_track, desired_start):
		var record_undo: bool = not _drag_has_moved
		_drag_has_moved = true
		block_move_requested.emit(_dragging_block, desired_track, desired_start, record_undo)


func _handle_hover_motion(p_pos: Vector2) -> void:
	var new_frame: int = _x_to_frame(p_pos.x)
	var new_lane: int = _y_to_track(p_pos.y)
	var new_block: TimelineBlock = null
	if (
		_plan != null
		and new_frame != NO_FRAME
		and (new_lane == TimelinePlan.TRACK_MOTION or new_lane == TimelinePlan.TRACK_ACTION)
	):
		new_block = _plan.get_block_at(new_lane, new_frame)

	var new_enemy_id: int = -1
	for enemy_id: int in _enemy_row_rects.keys():
		if _enemy_row_rects[enemy_id].has_point(p_pos):
			new_enemy_id = enemy_id
			break

	var needs_redraw: bool = (
		new_frame != _hovered_frame
		or new_lane != _hovered_lane
		or new_block != _hovered_block
		or new_enemy_id != _hovered_enemy_id
	)

	var prev_frame: int = _hovered_frame
	var prev_enemy_id: int = _hovered_enemy_id
	_hovered_frame = new_frame
	_hovered_lane = new_lane
	_hovered_block = new_block
	_hovered_enemy_id = new_enemy_id

	_update_cursor_for_position(p_pos)

	if needs_redraw:
		queue_redraw()
	if _hovered_enemy_id != prev_enemy_id:
		enemy_lane_hovered.emit(_hovered_enemy_id)
	if _hovered_frame != NO_FRAME and _hovered_frame != prev_frame:
		frame_scrubbed.emit(_hovered_frame)
	elif _hovered_frame == NO_FRAME and prev_frame != NO_FRAME:
		scrub_cleared.emit()


func _update_cursor_for_position(p_pos: Vector2) -> void:
	if _target_pick_card != null:
		for enemy_id: int in _enemy_badge_rects.keys():
			if _enemy_badge_rects[enemy_id].has_point(p_pos) and _is_valid_pick_enemy(enemy_id):
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				return
	if _hovered_block != null or _ghost_card != null:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _on_mouse_exited() -> void:
	var had_scrub: bool = (_hovered_frame != NO_FRAME)
	var had_enemy_hover: bool = (_hovered_enemy_id != -1)
	_hovered_frame = NO_FRAME
	_hovered_lane = NO_LANE
	_hovered_block = null
	_hovered_enemy_id = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()
	if had_enemy_hover:
		enemy_lane_hovered.emit(-1)
	if had_scrub and _active_drag_drop == null:
		scrub_cleared.emit()


# --- Main Drawing Pipeline ---

func _draw() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font

	var full_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(full_rect, well_bg_color, true)
	draw_rect(full_rect, rule_color, false, 1.0)

	_enemy_badge_rects.clear()
	_enemy_row_rects.clear()

	var strip_x: float = padding_x + left_gutter_width
	var strip_w: float = maxf(48.0, size.x - strip_x - padding_x)
	var frame_w: float = strip_w / float(maxi(1, _total_frames))

	# 1. Frame Ruler Row
	var cursor_y: float = padding_y
	_draw_ruler(font, strip_x, cursor_y, frame_w)
	cursor_y += ruler_height + 2.0

	# 2. Speed Tier Progression Ribbon
	_draw_tier_ribbon(font, strip_x, cursor_y, strip_w, frame_w)
	cursor_y += tier_row_height + 4.0

	# 3. Dynamic Enemy Threat Lanes
	var living_enemies: Array[EnemyState] = _get_enemies_for_lanes()
	var lane_h: float = _resolve_enemy_lane_height(living_enemies.size())
	if living_enemies.is_empty():
		_draw_empty_enemy_lane(font, strip_x, cursor_y, strip_w, lane_h)
		cursor_y += lane_h
	else:
		for i: int in range(living_enemies.size()):
			var enemy: EnemyState = living_enemies[i]
			_draw_enemy_lane(font, enemy, strip_x, cursor_y, strip_w, frame_w, lane_h)
			cursor_y += lane_h
			if i + 1 < living_enemies.size():
				cursor_y += 2.0

	cursor_y += section_gap

	# 4. Player Tracks: Move (Track 0) & Action (Track 1)
	var move_y: float = cursor_y
	var act_y: float = move_y + player_track_height + 4.0
	_draw_player_track(font, "Move", TimelinePlan.TRACK_MOTION, strip_x, move_y, frame_w)
	_draw_player_track(font, "Action", TimelinePlan.TRACK_ACTION, strip_x, act_y, frame_w)

	# 5. Player Frozen / Locked Track Overlay (.lkz)
	_draw_player_frozen_zones(font, strip_x, move_y, act_y + player_track_height - move_y, frame_w)

	# 6. Drop Zone Preview (#dz) for Drag-and-Drop or Armed Click Placement
	var preview_drop: _DropCalc = _active_drag_drop
	if preview_drop == null and _ghost_card != null and _plan != null and _hovered_frame != NO_FRAME:
		var synth_y: float = _track_center_y(_hovered_lane, move_y, act_y)
		var synth_x: float = strip_x + (float(_hovered_frame) + 0.5) * frame_w
		preview_drop = _compute_smart_drop(_ghost_card, Vector2(synth_x, synth_y), false)
	if preview_drop != null:
		var dz_y: float = move_y if preview_drop.track == TimelinePlan.TRACK_MOTION else act_y
		_draw_drop_zone(font, preview_drop, strip_x, dz_y, frame_w)

	# 7. Full-Height Cream Playhead (#ph)
	var active_ph: int = _playhead_frame if _playhead_frame != NO_FRAME else _hovered_frame
	if active_ph >= 0 and active_ph < _total_frames:
		_draw_playhead(strip_x, padding_y, act_y + player_track_height, active_ph, frame_w)


# --- Row Renderers ---

func _draw_ruler(p_font: Font, p_strip_x: float, p_y: float, p_frame_w: float) -> void:
	for f: int in range(_total_frames):
		var fx: float = p_strip_x + float(f) * p_frame_w
		draw_line(
			Vector2(fx, p_y + 2.0),
			Vector2(fx, p_y + ruler_height),
			rule_color,
			1.0
		)
		if (f % MAJOR_TICK_INTERVAL) == 0 and p_font != null:
			var num_rect: Rect2 = Rect2(Vector2(fx + 3.0, p_y), Vector2(p_frame_w * 2.5, ruler_height))
			_draw_text_centered_y(p_font, num_rect, "%d" % f, 11, mute_text_color, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_tier_ribbon(
	p_font: Font,
	p_strip_x: float,
	p_y: float,
	p_strip_w: float,
	p_frame_w: float
) -> void:
	if p_font != null:
		_draw_text_centered_y(
			p_font,
			Rect2(Vector2(padding_x, p_y), Vector2(left_gutter_width - 6.0, tier_row_height)),
			"Tier",
			12,
			soft_text_color,
			HORIZONTAL_ALIGNMENT_LEFT
		)

	var mid_y: float = p_y + tier_row_height * 0.5
	draw_line(
		Vector2(p_strip_x, mid_y),
		Vector2(p_strip_x + p_strip_w, mid_y),
		Color(rule_color.r, rule_color.g, rule_color.b, 0.55),
		1.0
	)

	var t1_frames: Array[int] = []
	var t2_frames: Array[int] = []
	var t3_frames: Array[int] = []

	for f: int in range(_total_frames):
		var frame_tier: int = 0
		if _preview != null and _preview.total_frames > 0:
			frame_tier = int(_preview.get_snapshot(f).player.tier)
		elif _state != null:
			frame_tier = int(_state.player.tier)
		if frame_tier >= 1:
			t1_frames.append(f)
		if frame_tier >= 2:
			t2_frames.append(f)
		if frame_tier >= 3:
			t3_frames.append(f)

	var bar_y: float = mid_y - 2.5
	for run: Vector2i in _collect_runs(t1_frames):
		_draw_frame_span_bar(p_strip_x, p_frame_w, run.x, run.y, bar_y, 5.0, rule2_color)
	for run: Vector2i in _collect_runs(t2_frames):
		_draw_frame_span_bar(p_strip_x, p_frame_w, run.x, run.y, bar_y, 5.0, stock_color)
	for run: Vector2i in _collect_runs(t3_frames):
		_draw_frame_span_bar(p_strip_x, p_frame_w, run.x, run.y, bar_y, 5.0, gold_cut_color)


func _draw_empty_enemy_lane(
	p_font: Font,
	p_strip_x: float,
	p_y: float,
	p_strip_w: float,
	p_lane_h: float
) -> void:
	var badge_rect: Rect2 = Rect2(Vector2(padding_x, p_y + 2.0), Vector2(22.0, p_lane_h - 4.0))
	draw_rect(badge_rect, stock_color, true)
	if p_font != null:
		_draw_text_centered_y(p_font, badge_rect, "–", 11, ink_color, HORIZONTAL_ALIGNMENT_CENTER)

	var free_rect: Rect2 = Rect2(Vector2(p_strip_x + 1.0, p_y + 1.0), Vector2(p_strip_w - 2.0, p_lane_h - 2.0))
	_draw_dashed_rect(free_rect, rule_color, 6.0, 4.0)
	if p_font != null:
		_draw_text_centered_y(p_font, free_rect, "no pending attacks", 11, mute_text_color, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_enemy_lane(
	p_font: Font,
	p_enemy: EnemyState,
	p_strip_x: float,
	p_y: float,
	p_strip_w: float,
	p_frame_w: float,
	p_lane_h: float
) -> void:
	_enemy_row_rects[p_enemy.id] = Rect2(Vector2(padding_x, p_y), Vector2(left_gutter_width + p_strip_w, p_lane_h))

	# 1. Cream Gutter Badge (.lab.hl i) + Plum Pick Ring (.lab.pick i)
	var badge_fill: Color = acetate_color if p_enemy.is_frozen else stock_color
	var badge_rect: Rect2 = Rect2(Vector2(padding_x, p_y + 2.0), Vector2(24.0, p_lane_h - 4.0))
	_enemy_badge_rects[p_enemy.id] = badge_rect
	draw_rect(badge_rect, badge_fill, true)
	if _target_pick_card != null and _is_valid_pick_enemy(p_enemy.id):
		draw_rect(badge_rect.grow(2.0), edit_clip_color, false, 2.0)
	elif _hovered_enemy_id == p_enemy.id:
		draw_rect(badge_rect.grow(1.5), vermilion_color, false, 1.5)

	if p_font != null:
		_draw_text_centered_y(p_font, badge_rect, p_enemy.symbol, 11, ink_color, HORIZONTAL_ALIGNMENT_CENTER)

	# Subtle track baseline
	draw_line(
		Vector2(p_strip_x, p_y + p_lane_h - 1.0),
		Vector2(p_strip_x + p_strip_w, p_y + p_lane_h - 1.0),
		Color(rule_color.r, rule_color.g, rule_color.b, 0.45),
		1.0
	)

	# 2. Compute Live Played Frames, Dashed Ghost Frames, and Gold Match Cut Frames
	var base_frames: Array[int] = []
	var has_beam: bool = false
	if not p_enemy.is_frozen and not p_enemy.is_dazed:
		for intent: AttackIntent in p_enemy.attack_intents:
			if intent.is_beam:
				has_beam = true
			for f: int in range(maxi(0, intent.start_frame), mini(_total_frames - 1, intent.end_frame) + 1):
				if not base_frames.has(f):
					base_frames.append(f)

	var played_frames: Array[int] = []
	var cut_frames: Array[int] = []
	if _preview != null and _preview.total_frames > 0:
		for f: int in range(_total_frames):
			var pre_enemy: EnemyState = (
				p_enemy
				if f == 0
				else _preview.get_snapshot(f - 1).get_enemy_by_id(p_enemy.id)
			)
			var end_enemy: EnemyState = _preview.get_snapshot(f).get_enemy_by_id(p_enemy.id)

			if end_enemy != null and end_enemy.is_alive and not end_enemy.is_frozen and not end_enemy.is_dazed:
				for intent: AttackIntent in end_enemy.attack_intents:
					if intent.is_beam:
						has_beam = true
					if intent.is_active_on(f):
						if not played_frames.has(f):
							played_frames.append(f)

			var cut_source: EnemyState = (
				end_enemy
				if (end_enemy != null and end_enemy.is_alive and not end_enemy.is_frozen and not end_enemy.is_dazed)
				else pre_enemy
			)
			if cut_source != null and cut_source.is_alive and not cut_source.is_frozen and not cut_source.is_dazed:
				for intent: AttackIntent in cut_source.attack_intents:
					if intent.is_active_on(f) and not cut_source.has_triggered_match_cut(intent):
						if not cut_frames.has(f):
							cut_frames.append(f)
						break
	else:
		played_frames = base_frames.duplicate()
		cut_frames = base_frames.duplicate()

	var ghost_frames: Array[int] = []
	for bf: int in base_frames:
		if not played_frames.has(bf):
			ghost_frames.append(bf)

	# 3. Draw Dashed Ghost Intents (.hz.ghost)
	for g_run: Vector2i in _collect_runs(ghost_frames):
		var gx0: float = p_strip_x + float(g_run.x) * p_frame_w + 1.0
		var gx1: float = p_strip_x + float(g_run.y + 1) * p_frame_w - 1.0
		var g_rect: Rect2 = Rect2(Vector2(gx0, p_y + 1.0), Vector2(maxf(4.0, gx1 - gx0), p_lane_h - 2.0))
		_draw_dashed_rect(g_rect, rule2_color, 5.0, 4.0)

	# 4. Draw Active Vermilion Hazard Bars (.hz)
	var bar_label: String = "Beam" if has_beam else "Strike"
	var played_runs: Array[Vector2i] = _collect_runs(played_frames)
	for r_idx: int in range(played_runs.size()):
		var p_run: Vector2i = played_runs[r_idx]
		var px0: float = p_strip_x + float(p_run.x) * p_frame_w + 0.5
		var px1: float = p_strip_x + float(p_run.y + 1) * p_frame_w - 0.5
		var hz_rect: Rect2 = Rect2(Vector2(px0, p_y + 1.0), Vector2(maxf(4.0, px1 - px0), p_lane_h - 2.0))
		draw_rect(hz_rect, vermilion_color, true)

		var span_frames: int = p_run.y - p_run.x + 1
		if p_font != null and p_lane_h >= 18.0 and span_frames >= 3 and hz_rect.size.x >= 38.0:
			var txt_rect: Rect2 = Rect2(
				Vector2(hz_rect.position.x + 5.0, hz_rect.position.y),
				Vector2(hz_rect.size.x - 8.0, hz_rect.size.y - 3.0)
			)
			_draw_text_centered_y(p_font, txt_rect, bar_label, 11, stock_color, HORIZONTAL_ALIGNMENT_LEFT)

	# 5. Draw 4px Gold Match Cut Windows (.cut) Along Bottom of Lane
	for c_run: Vector2i in _collect_runs(cut_frames):
		var cx0: float = p_strip_x + float(c_run.x) * p_frame_w + 0.5
		var cx1: float = p_strip_x + float(c_run.y + 1) * p_frame_w - 0.5
		var cut_rect: Rect2 = Rect2(
			Vector2(cx0, p_y + p_lane_h - 4.5),
			Vector2(maxf(4.0, cx1 - cx0), 4.0)
		)
		draw_rect(cut_rect, gold_cut_color, true)


func _draw_player_track(
	p_font: Font,
	p_track_title: String,
	p_track_idx: int,
	p_strip_x: float,
	p_y: float,
	p_frame_w: float
) -> void:
	# 1. Left Gutter Label ("Move" / "0 of 24")
	var used_frames: int = _count_occupied_track_frames(p_track_idx)
	if p_font != null:
		_draw_text_centered_y(
			p_font,
			Rect2(Vector2(padding_x, p_y + 3.0), Vector2(left_gutter_width - 6.0, 16.0)),
			p_track_title,
			13,
			soft_text_color,
			HORIZONTAL_ALIGNMENT_LEFT
		)
		_draw_text_centered_y(
			p_font,
			Rect2(Vector2(padding_x, p_y + 19.0), Vector2(left_gutter_width - 6.0, 14.0)),
			"%d of %d" % [used_frames, _total_frames],
			11,
			mute_text_color,
			HORIZONTAL_ALIGNMENT_LEFT
		)

	# 2. 24-Frame Moviola Track Cells (.trkbg)
	var strip_w: float = p_frame_w * float(_total_frames)
	var outer_track_rect: Rect2 = Rect2(Vector2(p_strip_x, p_y), Vector2(strip_w, player_track_height))
	draw_rect(outer_track_rect, cell_bg_color, true)
	for f: int in range(1, _total_frames):
		var div_x: float = p_strip_x + float(f) * p_frame_w
		draw_line(
			Vector2(div_x, p_y),
			Vector2(div_x, p_y + player_track_height),
			well_bg_color,
			1.0
		)
	draw_rect(outer_track_rect, rule_color, false, 1.0)

	# 3. Placed Clips (.blk)
	if _plan != null:
		for block: TimelineBlock in _plan.blocks:
			if block.track_index == p_track_idx:
				_draw_clip_bar(p_font, block, p_strip_x, p_y, p_frame_w)


func _draw_clip_bar(
	p_font: Font,
	p_block: TimelineBlock,
	p_strip_x: float,
	p_y: float,
	p_frame_w: float
) -> void:
	var clamped_end: int = mini(p_block.end_frame, _total_frames - 1)
	if p_block.start_frame >= _total_frames or clamped_end < p_block.start_frame:
		return

	var clip_rect: Rect2 = _get_clip_rect(p_block, p_strip_x, p_y, p_frame_w)
	var card: CardData = p_block.card
	var is_locked_at_start: bool = _is_player_frozen_before_block(p_block)
	var viol_frame: int = _find_block_violation_frame(p_block)

	var base_fill: Color = _resolve_clip_color(card)
	if _hovered_block == p_block and _dragging_block == null:
		base_fill = base_fill.lightened(0.08)
	if is_locked_at_start:
		base_fill.a = 0.42

	# 1. Paper-Tape Colored Body & Crisp Ink Border
	draw_rect(clip_rect, base_fill, true)

	# 2. Strike Wind-Up Hatching (.wu) & Recovery Shade (.rc)
	if card.family == Types.CardFamily.ACTION and not card.hit_frames.is_empty():
		var min_hit_local: int = 999
		var max_hit_local: int = -1
		for hf: int in card.hit_frames:
			var clamped_hf: int = clampi(hf, 0, p_block.duration - 1)
			min_hit_local = mini(min_hit_local, clamped_hf)
			max_hit_local = maxi(max_hit_local, clamped_hf)

		if min_hit_local > 0:
			var wu_w: float = clip_rect.size.x * (float(min_hit_local) / float(p_block.duration))
			var wu_rect: Rect2 = Rect2(clip_rect.position, Vector2(wu_w, clip_rect.size.y))
			_draw_clipped_diagonal_hatch(wu_rect, Color(0.110, 0.114, 0.106, 0.25), 7.0, 1.5)

		if max_hit_local >= 0 and max_hit_local < p_block.duration - 1:
			var rc_frames: int = (p_block.duration - 1) - max_hit_local
			var rc_w: float = clip_rect.size.x * (float(rc_frames) / float(p_block.duration))
			var rc_rect: Rect2 = Rect2(
				Vector2(clip_rect.end.x - rc_w, clip_rect.position.y),
				Vector2(rc_w, clip_rect.size.y)
			)
			draw_rect(rc_rect, Color(0.110, 0.114, 0.106, 0.34), true)

	# 3. Violation Warning Stripes (.blk.bad)
	if viol_frame >= 0:
		_draw_clipped_diagonal_hatch(clip_rect, Color(vermilion_color.r, vermilion_color.g, vermilion_color.b, 0.52), 8.0, 2.0)

	draw_rect(clip_rect, Color(0.0, 0.0, 0.0, 0.65), false, 1.0)
	if viol_frame >= 0:
		draw_rect(clip_rect.grow(1.0), danger_color, false, 2.0)
	if _selected_block == p_block:
		draw_rect(clip_rect.grow(1.5), stock_color, false, 2.0)

	# 4. Trigger Markers: Rotated 45° Impact Diamonds (.mk) & Step/Edit Dots (.mk.st)
	var has_cut_hit: bool = false
	var has_flow_hit: bool = false
	for f: int in range(p_block.start_frame, clamped_end + 1):
		var cx: float = p_strip_x + (float(f) + 0.5) * p_frame_w
		if p_block.is_hit_frame(f):
			var is_cut: bool = _preview != null and _preview.has_event_type(CombatEvent.Type.MATCH_CUT_TRIGGERED, f)
			var is_flow: bool = _preview != null and _preview.has_event_type(CombatEvent.Type.FLOW_TRIGGERED, f)
			var swung: bool = _preview == null or _preview.has_event_type(CombatEvent.Type.STRIKE_SWUNG, f)
			if is_cut:
				has_cut_hit = true
				_draw_diamond_marker(Vector2(cx, clip_rect.end.y - 6.0), 4.5, gold_cut_color, ink_color)
			elif is_flow:
				has_flow_hit = true
				_draw_diamond_marker(Vector2(cx, clip_rect.end.y - 6.0), 4.5, stock_color, ink_color)
			elif not swung:
				_draw_diamond_marker(Vector2(cx, clip_rect.end.y - 6.0), 4.5, vermilion_color, stock_color)
			else:
				_draw_diamond_marker(Vector2(cx, clip_rect.end.y - 6.0), 4.5, ink_color, stock_color)
		elif f == viol_frame:
			_draw_diamond_marker(Vector2(cx, clip_rect.end.y - 6.0), 4.5, vermilion_color, stock_color)
		elif p_block.is_step_frame(f) or p_block.is_edit_frame(f):
			draw_circle(Vector2(cx, clip_rect.end.y - 5.0), 2.5, ink_color)

	if p_font == null:
		return

	# 5. Clip Name + Direction / Target Label
	var show_close: bool = (_hovered_block == p_block or _selected_block == p_block) and _active_drag_drop == null
	var right_pad: float = 20.0 if show_close else 6.0
	var title_str: String = _format_clip_title(p_block, clip_rect.size.x - right_pad)
	var text_rect: Rect2 = Rect2(
		Vector2(clip_rect.position.x + 5.0, clip_rect.position.y + 1.0),
		Vector2(maxf(0.0, clip_rect.size.x - 5.0 - right_pad), clip_rect.size.y - 8.0)
	)
	if text_rect.size.x >= 10.0 and not title_str.is_empty():
		_draw_text_centered_y(p_font, text_rect, title_str, 12, ink_color, HORIZONTAL_ALIGNMENT_LEFT)

	# 6. 'cut' or 'flow' Micro-Badge (.blk .fb)
	if (has_cut_hit or has_flow_hit) and clip_rect.size.x >= 54.0:
		var badge_txt: String = "cut" if has_cut_hit else "flow"
		var badge_w: float = 24.0 if has_cut_hit else 28.0
		var fb_rect: Rect2 = Rect2(
			Vector2(clip_rect.end.x - badge_w - (18.0 if show_close else 4.0), clip_rect.end.y - 14.0),
			Vector2(badge_w, 12.0)
		)
		draw_rect(fb_rect, gold_cut_color if has_cut_hit else ink_color, true)
		_draw_text_centered_y(
			p_font,
			fb_rect,
			badge_txt,
			10,
			ink_color if has_cut_hit else stock_color,
			HORIZONTAL_ALIGNMENT_CENTER
		)

	# 7. Top-Right Clickable '×' Button (.blk .x)
	if show_close and clip_rect.size.x >= 24.0:
		var close_rect: Rect2 = _get_clip_close_rect(p_block)
		draw_rect(close_rect, Color(stock_color.r, stock_color.g, stock_color.b, 0.82), true)
		_draw_text_centered_y(p_font, close_rect, "×", 13, ink_color, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_player_frozen_zones(
	p_font: Font,
	p_strip_x: float,
	p_top_y: float,
	p_span_h: float,
	p_frame_w: float
) -> void:
	if _preview == null or _preview.total_frames <= 0:
		return
	var frozen_frames: Array[int] = []
	for f: int in range(_total_frames):
		if _preview.get_snapshot(f).player.is_frozen:
			frozen_frames.append(f)

	for run: Vector2i in _collect_runs(frozen_frames):
		var x0: float = p_strip_x + float(run.x) * p_frame_w + 1.0
		var x1: float = p_strip_x + float(run.y + 1) * p_frame_w - 1.0
		var lk_rect: Rect2 = Rect2(Vector2(x0, p_top_y), Vector2(maxf(6.0, x1 - x0), p_span_h))
		draw_rect(lk_rect, Color(0.12, 0.04, 0.04, 0.58), true)
		_draw_clipped_diagonal_hatch(
			lk_rect,
			Color(vermilion_color.r, vermilion_color.g, vermilion_color.b, 0.65),
			9.0,
			2.0
		)
		draw_rect(lk_rect, vermilion_color, false, 1.0)
		if p_font != null and lk_rect.size.x >= 44.0:
			_draw_text_centered_y(p_font, lk_rect, "frozen", 12, stock_color, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_drop_zone(
	p_font: Font,
	p_drop: _DropCalc,
	p_strip_x: float,
	p_track_y: float,
	p_frame_w: float
) -> void:
	var start_f: int = p_drop.start_frame if p_drop.valid else p_drop.fallback_frame
	var end_f: int = mini(_total_frames - 1, start_f + p_drop.duration - 1)
	if start_f < 0 or start_f >= _total_frames or end_f < start_f:
		return

	var x0: float = p_strip_x + float(start_f) * p_frame_w + 1.0
	var x1: float = p_strip_x + float(end_f + 1) * p_frame_w - 1.0
	var dz_rect: Rect2 = Rect2(
		Vector2(x0, p_track_y + 1.0),
		Vector2(maxf(8.0, x1 - x0), player_track_height - 2.0)
	)

	var border_col: Color = stock_color if p_drop.valid else danger_color
	var fill_col: Color = (
		Color(stock_color.r, stock_color.g, stock_color.b, 0.18)
		if p_drop.valid
		else Color(danger_color.r, danger_color.g, danger_color.b, 0.22)
	)
	draw_rect(dz_rect, fill_col, true)
	draw_rect(dz_rect, border_col, false, 2.0)

	# Trigger preview pips along bottom of drop zone
	if p_drop.card != null and _plan != null:
		var preview_blk: TimelineBlock = _plan.create_block(
			p_drop.card, p_drop.track, start_f, _ghost_direction, _ghost_target_enemy_id
		)
		for f: int in range(start_f, end_f + 1):
			var cx: float = p_strip_x + (float(f) + 0.5) * p_frame_w
			if preview_blk.is_hit_frame(f):
				_draw_diamond_marker(Vector2(cx, dz_rect.end.y - 6.0), 4.0, border_col, ink_color)
			elif preview_blk.is_step_frame(f) or preview_blk.is_edit_frame(f):
				draw_circle(Vector2(cx, dz_rect.end.y - 5.0), 2.5, border_col)

	if p_font != null and p_drop.card != null and dz_rect.size.x >= 28.0:
		var card_name: String = p_drop.card.display_name if not p_drop.card.display_name.is_empty() else p_drop.card.id
		var txt_rect: Rect2 = Rect2(
			Vector2(dz_rect.position.x + 5.0, dz_rect.position.y),
			Vector2(dz_rect.size.x - 8.0, dz_rect.size.y - 6.0)
		)
		_draw_text_centered_y(p_font, txt_rect, card_name, 11, border_col, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_playhead(
	p_strip_x: float,
	p_top_y: float,
	p_bottom_y: float,
	p_frame: int,
	p_frame_w: float
) -> void:
	var col_x: float = p_strip_x + float(p_frame) * p_frame_w
	var col_wash: Color = Color(stock_color.r, stock_color.g, stock_color.b, 0.09)
	draw_rect(Rect2(Vector2(col_x, p_top_y), Vector2(p_frame_w, p_bottom_y - p_top_y)), col_wash, true)
	draw_line(Vector2(col_x + 1.0, p_top_y), Vector2(col_x + 1.0, p_bottom_y), stock_color, 2.0)


# --- Smart Drop & Geometry Helpers ---

func _compute_smart_drop(p_card: CardData, p_pos: Vector2, p_center_on_cursor: bool) -> _DropCalc:
	var calc: _DropCalc = _DropCalc.new()
	calc.card = p_card
	if p_card == null or _plan == null:
		return calc

	var target_track: int = TimelinePlan.TRACK_ACTION
	match p_card.family:
		Types.CardFamily.MOTION:
			target_track = TimelinePlan.TRACK_MOTION
		Types.CardFamily.ACTION:
			target_track = TimelinePlan.TRACK_ACTION
		_:
			target_track = _nearest_player_track_for_y(p_pos.y)
	calc.track = target_track

	var dummy: TimelineBlock = _plan.create_block(p_card, target_track, 0)
	var cs: int = maxi(1, dummy.duration)
	calc.duration = cs

	var cursor_f: int = clampi(_x_to_frame_unclamped(p_pos.x), 0, _total_frames - 1)
	var raw_base: int = (
		cursor_f - floori(float(cs) / 2.0)
		if p_center_on_cursor
		else cursor_f
	)
	var max_start: int = maxi(0, _total_frames - cs)
	var base_frame: int = clampi(raw_base, 0, max_start)
	calc.fallback_frame = base_frame

	if cs > _total_frames:
		return calc

	for d: int in range(MAX_SNAP_SEARCH_RADIUS + 1):
		var candidates: Array[int] = [base_frame - d]
		if d > 0:
			candidates.append(base_frame + d)
		for cand: int in candidates:
			if cand < 0 or cand + cs > _total_frames:
				continue
			var test_block: TimelineBlock = _plan.create_block(p_card, target_track, cand)
			if _plan.can_place(test_block):
				calc.valid = true
				calc.start_frame = cand
				return calc

	return calc


func _can_relocate_block(p_moving_block: TimelineBlock, p_new_track: int, p_new_start: int) -> bool:
	if _plan == null or p_moving_block == null:
		return false
	var candidate: TimelineBlock = _plan.create_block(
		p_moving_block.card,
		p_new_track,
		p_new_start,
		p_moving_block.direction,
		p_moving_block.target_enemy_id
	)
	if candidate.start_frame < 0 or candidate.end_frame >= _total_frames:
		return false
	for other: TimelineBlock in _plan.blocks:
		if other != p_moving_block and other.overlaps_with(candidate):
			return false
	return true


func _is_valid_pick_enemy(p_enemy_id: int) -> bool:
	if _target_pick_card == null or _state == null:
		return false
	var enemy: EnemyState = _state.get_enemy_by_id(p_enemy_id)
	if enemy == null or not enemy.is_alive:
		return false
	if _target_pick_card.requires_frozen_enemy_target() and not enemy.is_frozen:
		return false
	return true


func _recompute_minimum_height() -> void:
	var enemies: Array[EnemyState] = _get_enemies_for_lanes()
	var lane_count: int = maxi(1, enemies.size())
	var lane_h: float = _resolve_enemy_lane_height(enemies.size())
	var enemy_total_h: float = float(lane_count) * lane_h + float(maxi(0, lane_count - 1)) * 2.0
	var h: float = (
		padding_y * 2.0
		+ ruler_height + 2.0
		+ tier_row_height + 4.0
		+ enemy_total_h
		+ section_gap
		+ player_track_height * 2.0 + 4.0
	)
	custom_minimum_size = Vector2(0.0, h)


func _resolve_enemy_lane_height(p_enemy_count: int) -> float:
	if p_enemy_count <= 3:
		return enemy_lane_base_height
	if p_enemy_count == 4:
		return maxf(16.0, enemy_lane_base_height - 3.0)
	return maxf(15.0, enemy_lane_base_height - 6.0)


func _get_player_tracks_top_y() -> float:
	var enemies: Array[EnemyState] = _get_enemies_for_lanes()
	var lane_count: int = maxi(1, enemies.size())
	var lane_h: float = _resolve_enemy_lane_height(enemies.size())
	var enemy_total_h: float = float(lane_count) * lane_h + float(maxi(0, lane_count - 1)) * 2.0
	return (
		padding_y
		+ ruler_height + 2.0
		+ tier_row_height + 4.0
		+ enemy_total_h
		+ section_gap
	)


func _nearest_player_track_for_y(p_local_y: float) -> int:
	var move_y: float = _get_player_tracks_top_y()
	var mid_y: float = move_y + player_track_height + 2.0
	return TimelinePlan.TRACK_MOTION if p_local_y < mid_y else TimelinePlan.TRACK_ACTION


func _track_center_y(p_lane: int, p_move_y: float, p_act_y: float) -> float:
	if p_lane == TimelinePlan.TRACK_ACTION:
		return p_act_y + player_track_height * 0.5
	return p_move_y + player_track_height * 0.5


func _get_clip_rect(p_block: TimelineBlock, p_strip_x: float, p_track_y: float, p_frame_w: float) -> Rect2:
	var clamped_end: int = mini(p_block.end_frame, _total_frames - 1)
	var x0: float = p_strip_x + float(p_block.start_frame) * p_frame_w + 1.0
	var x1: float = p_strip_x + float(clamped_end + 1) * p_frame_w - 1.0
	return Rect2(Vector2(x0, p_track_y + 1.0), Vector2(maxf(6.0, x1 - x0), player_track_height - 2.0))


func _get_clip_close_rect(p_block: TimelineBlock) -> Rect2:
	var strip_x: float = padding_x + left_gutter_width
	var strip_w: float = maxf(48.0, size.x - strip_x - padding_x)
	var frame_w: float = strip_w / float(maxi(1, _total_frames))
	var move_y: float = _get_player_tracks_top_y()
	var track_y: float = move_y if p_block.track_index == TimelinePlan.TRACK_MOTION else (move_y + player_track_height + 4.0)
	var clip_rect: Rect2 = _get_clip_rect(p_block, strip_x, track_y, frame_w)
	return Rect2(Vector2(clip_rect.end.x - 16.0, clip_rect.position.y + 2.0), Vector2(14.0, 14.0))


func _get_enemies_for_lanes() -> Array[EnemyState]:
	if _state == null:
		return []
	return _state.get_living_enemies()


func _x_to_frame(p_local_x: float) -> int:
	var strip_x: float = padding_x + left_gutter_width
	var strip_w: float = maxf(48.0, size.x - strip_x - padding_x)
	if p_local_x < strip_x or p_local_x >= strip_x + strip_w:
		return NO_FRAME
	var frame_w: float = strip_w / float(maxi(1, _total_frames))
	return clampi(floori((p_local_x - strip_x) / frame_w), 0, _total_frames - 1)


func _x_to_frame_unclamped(p_local_x: float) -> int:
	var strip_x: float = padding_x + left_gutter_width
	var strip_w: float = maxf(48.0, size.x - strip_x - padding_x)
	var frame_w: float = strip_w / float(maxi(1, _total_frames))
	return floori((p_local_x - strip_x) / frame_w)


func _y_to_track(p_local_y: float) -> int:
	var move_y: float = _get_player_tracks_top_y()
	var act_y: float = move_y + player_track_height + 4.0
	if p_local_y >= move_y and p_local_y <= move_y + player_track_height:
		return TimelinePlan.TRACK_MOTION
	if p_local_y >= act_y and p_local_y <= act_y + player_track_height:
		return TimelinePlan.TRACK_ACTION
	return NO_LANE


func _count_occupied_track_frames(p_track: int) -> int:
	if _plan == null:
		return 0
	var count: int = 0
	for f: int in range(_total_frames):
		if _plan.get_block_at(p_track, f) != null:
			count += 1
	return count


func _is_player_frozen_before_block(p_block: TimelineBlock) -> bool:
	if _preview == null or _preview.total_frames <= 0:
		return _state != null and _state.player.is_frozen and p_block.start_frame == 0
	if p_block.start_frame <= 0:
		return _state != null and _state.player.is_frozen
	return _preview.get_snapshot(p_block.start_frame - 1).player.is_frozen


func _find_block_violation_frame(p_block: TimelineBlock) -> int:
	if _preview == null or p_block.card.family != Types.CardFamily.MOTION:
		return -1
	for ev: CombatEvent in _preview.events:
		if ev.frame < p_block.start_frame or ev.frame > p_block.end_frame:
			continue
		if (
			ev.type == CombatEvent.Type.VIOLATION_180_TURN
			or ev.type == CombatEvent.Type.VIOLATION_WALL_CRASH
			or ev.type == CombatEvent.Type.VIOLATION_ENEMY_CRASH
		):
			return ev.frame
	return -1


func _resolve_clip_color(p_card: CardData) -> Color:
	if p_card == null:
		return motion_clip_color
	match p_card.family:
		Types.CardFamily.MOTION:
			return motion_clip_color
		Types.CardFamily.ACTION:
			if p_card.base_damage > 0 or not p_card.hit_frames.is_empty():
				return strike_clip_color
			return tech_clip_color
		_:
			return edit_clip_color


func _format_clip_title(p_block: TimelineBlock, p_avail_width: float) -> String:
	var card: CardData = p_block.card
	var base_name: String = card.display_name if not card.display_name.is_empty() else card.id
	var suffix: String = ""
	if card.requires_cardinal_direction() or card.requires_timeline_direction():
		suffix = _direction_arrow(p_block.direction)
	elif card.requires_enemy_target() and _state != null and p_block.target_enemy_id >= 0:
		var tgt: EnemyState = _state.get_enemy_by_id(p_block.target_enemy_id)
		if tgt != null:
			suffix = "→%s" % tgt.symbol

	if p_avail_width < 38.0:
		return suffix if not suffix.is_empty() else base_name.substr(0, 2)
	if not suffix.is_empty():
		return "%s %s" % [base_name, suffix]
	return base_name


func _direction_arrow(p_dir: Types.Direction) -> String:
	match p_dir:
		Types.Direction.NORTH:
			return "↑"
		Types.Direction.EAST:
			return "→"
		Types.Direction.SOUTH:
			return "↓"
		Types.Direction.WEST:
			return "←"
		_:
			return ""


func _collect_runs(p_frames: Array[int]) -> Array[Vector2i]:
	var runs_out: Array[Vector2i] = []
	if p_frames.is_empty():
		return runs_out
	var sorted: Array[int] = p_frames.duplicate()
	sorted.sort()
	var run_start: int = sorted[0]
	var run_end: int = sorted[0]
	for i: int in range(1, sorted.size()):
		var f: int = sorted[i]
		if f == run_end:
			continue
		if f == run_end + 1:
			run_end = f
		else:
			runs_out.append(Vector2i(run_start, run_end))
			run_start = f
			run_end = f
	runs_out.append(Vector2i(run_start, run_end))
	return runs_out


func _draw_frame_span_bar(
	p_strip_x: float,
	p_frame_w: float,
	p_start_f: int,
	p_end_f: int,
	p_y: float,
	p_h: float,
	p_color: Color
) -> void:
	var x0: float = p_strip_x + float(p_start_f) * p_frame_w
	var x1: float = p_strip_x + float(p_end_f + 1) * p_frame_w
	draw_rect(Rect2(Vector2(x0, p_y), Vector2(maxf(2.0, x1 - x0), p_h)), p_color, true)


func _draw_diamond_marker(p_center: Vector2, p_radius: float, p_fill: Color, p_outline: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		p_center + Vector2(0.0, -p_radius),
		p_center + Vector2(p_radius, 0.0),
		p_center + Vector2(0.0, p_radius),
		p_center + Vector2(-p_radius, 0.0),
	])
	draw_colored_polygon(pts, p_fill)
	var border_pts: PackedVector2Array = PackedVector2Array([
		pts[0], pts[1], pts[2], pts[3], pts[0]
	])
	draw_polyline(border_pts, p_outline, 1.0, true)


func _draw_clipped_diagonal_hatch(
	p_rect: Rect2,
	p_color: Color,
	p_spacing: float,
	p_width: float
) -> void:
	var w: float = p_rect.size.x
	var h: float = p_rect.size.y
	if w <= 1.0 or h <= 1.0:
		return
	var step: float = maxf(3.0, p_spacing)
	var u: float = -h
	while u < w:
		var t_min: float = maxf(0.0, -u)
		var t_max: float = minf(h, w - u)
		if t_max > t_min:
			var p0: Vector2 = Vector2(p_rect.position.x + u + t_min, p_rect.position.y + h - t_min)
			var p1: Vector2 = Vector2(p_rect.position.x + u + t_max, p_rect.position.y + h - t_max)
			draw_line(p0, p1, p_color, p_width, true)
		u += step


func _draw_dashed_rect(p_rect: Rect2, p_color: Color, p_dash_len: float, p_gap_len: float) -> void:
	var tl: Vector2 = p_rect.position
	var tr: Vector2 = Vector2(p_rect.end.x, p_rect.position.y)
	var br: Vector2 = p_rect.end
	var bl: Vector2 = Vector2(p_rect.position.x, p_rect.end.y)
	_draw_dashed_segment(tl, tr, p_color, p_dash_len, p_gap_len)
	_draw_dashed_segment(tr, br, p_color, p_dash_len, p_gap_len)
	_draw_dashed_segment(br, bl, p_color, p_dash_len, p_gap_len)
	_draw_dashed_segment(bl, tl, p_color, p_dash_len, p_gap_len)


func _draw_dashed_segment(
	p_p0: Vector2,
	p_p1: Vector2,
	p_color: Color,
	p_dash_len: float,
	p_gap_len: float
) -> void:
	var total_len: float = p_p0.distance_to(p_p1)
	if total_len <= 0.5:
		return
	var dir: Vector2 = (p_p1 - p_p0) / total_len
	var dist: float = 0.0
	var step: float = maxf(2.0, p_dash_len + p_gap_len)
	while dist < total_len:
		var seg_end: float = minf(dist + p_dash_len, total_len)
		draw_line(p_p0 + dir * dist, p_p0 + dir * seg_end, p_color, 1.0)
		dist += step


func _draw_text_centered_y(
	p_font: Font,
	p_rect: Rect2,
	p_text: String,
	p_font_size: int,
	p_color: Color,
	p_align: HorizontalAlignment
) -> void:
	if p_font == null or p_rect.size.x <= 2.0:
		return
	var ascent: float = p_font.get_ascent(p_font_size)
	var descent: float = p_font.get_descent(p_font_size)
	var baseline_y: float = p_rect.position.y + (p_rect.size.y + ascent - descent) * 0.5
	draw_string(
		p_font,
		Vector2(p_rect.position.x, baseline_y),
		p_text,
		p_align,
		p_rect.size.x,
		p_font_size,
		p_color
	)
