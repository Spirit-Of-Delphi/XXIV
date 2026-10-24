class_name TimelineEditorView
extends PanelContainer

## Interactive 24-frame film-strip editor with Ruler, Enemy Intents, Track 0 (Motion), and Track 1 (Action).
## Pure UI view: previews card placement via TimelinePlan.can_place() and emits user intent signals.

signal frame_scrubbed(p_frame: int)
signal scrub_cleared()
signal track_frame_clicked(p_track: int, p_frame: int)
signal block_remove_requested(p_block: TimelineBlock)

const NO_FRAME: int = -1
const NO_LANE: int = -99
const LANE_RULER: int = -2
const LANE_INTENT: int = -1

const PIP_STEP: String = "●"
const PIP_HIT: String = "✦"
const PIP_EDIT: String = "◆"

@export_group("Packed Scenes")
@export var cell_view_scene: PackedScene

@export_group("Row Containers")
@export var ruler_cells_row: HBoxContainer
@export var intent_cells_row: HBoxContainer
@export var motion_cells_row: HBoxContainer
@export var action_cells_row: HBoxContainer

@export_group("Palette")
@export var ruler_even_color: Color = Color(0.11, 0.12, 0.15, 1.0)
@export var ruler_odd_color: Color = Color(0.14, 0.15, 0.19, 1.0)
@export var empty_slot_color: Color = Color(0.09, 0.10, 0.13, 1.0)
@export var intent_windup_color: Color = Color(0.75, 0.48, 0.10, 0.65)
@export var intent_impact_color: Color = Color(0.92, 0.20, 0.24, 0.92)
@export var motion_clip_color: Color = Color(0.14, 0.58, 0.48, 0.92)
@export var action_clip_color: Color = Color(0.76, 0.24, 0.28, 0.92)
@export var edit_clip_color: Color = Color(0.54, 0.32, 0.82, 0.92)
@export var clip_edge_color: Color = Color(1.0, 0.96, 0.82, 1.0)
@export var ghost_valid_color: Color = Color(0.25, 0.88, 0.45, 0.55)
@export var ghost_invalid_color: Color = Color(0.95, 0.22, 0.25, 0.55)
@export var text_default_color: Color = Color(0.92, 0.94, 0.98, 1.0)
@export var text_muted_color: Color = Color(0.58, 0.62, 0.70, 1.0)

var _total_frames: int = 0
var _ruler_cells: Array[TimelineCellView] = []
var _intent_cells: Array[TimelineCellView] = []
var _motion_cells: Array[TimelineCellView] = []
var _action_cells: Array[TimelineCellView] = []

var _state: CombatState = null
var _plan: TimelinePlan = null
var _ghost_card: CardData = null
var _ghost_direction: Types.Direction = Types.Direction.NORTH
var _ghost_target_enemy_id: int = -1

var _hovered_lane: int = NO_LANE
var _hovered_frame: int = NO_FRAME
var _playhead_frame: int = NO_FRAME


## Binds the latest authoritative CombatState (for enemy intents) and TimelinePlan (for placed blocks).
func refresh_timeline(p_state: CombatState, p_plan: TimelinePlan, p_total_frames: int) -> void:
	_state = p_state
	_plan = p_plan
	_ensure_cells_built(p_total_frames)
	_refresh_all_cells()


## Configures the currently selected hand card so hovering a track previews valid/invalid block span.
func set_ghost_card(
	p_card: CardData,
	p_direction: Types.Direction = Types.Direction.NORTH,
	p_target_enemy_id: int = -1
) -> void:
	_ghost_card = p_card
	_ghost_direction = p_direction
	_ghost_target_enemy_id = p_target_enemy_id
	_refresh_all_cells()


func clear_ghost_card() -> void:
	_ghost_card = null
	_refresh_all_cells()


## Moves the vertical white playhead highlight across all 4 lanes (pass NO_FRAME to hide).
func set_playhead_frame(p_frame: int) -> void:
	_playhead_frame = p_frame
	_refresh_all_cells()


# --- Private Cell Construction & Rendering ---

func _ensure_cells_built(p_total_frames: int) -> void:
	if _total_frames == p_total_frames or p_total_frames <= 0 or cell_view_scene == null:
		return

	_clear_row(ruler_cells_row, _ruler_cells)
	_clear_row(intent_cells_row, _intent_cells)
	_clear_row(motion_cells_row, _motion_cells)
	_clear_row(action_cells_row, _action_cells)

	for f: int in range(p_total_frames):
		_ruler_cells.append(_spawn_cell(ruler_cells_row, LANE_RULER, f))
		_intent_cells.append(_spawn_cell(intent_cells_row, LANE_INTENT, f))
		_motion_cells.append(_spawn_cell(motion_cells_row, TimelinePlan.TRACK_MOTION, f))
		_action_cells.append(_spawn_cell(action_cells_row, TimelinePlan.TRACK_ACTION, f))

	_total_frames = p_total_frames


func _spawn_cell(p_parent: HBoxContainer, p_lane: int, p_frame: int) -> TimelineCellView:
	var cell: TimelineCellView = cell_view_scene.instantiate() as TimelineCellView
	if p_parent != null:
		p_parent.add_child(cell)
	cell.setup_coordinates(p_lane, p_frame)
	cell.cell_hovered.connect(_on_cell_hovered)
	cell.cell_unhovered.connect(_on_cell_unhovered)
	cell.cell_left_clicked.connect(_on_cell_left_clicked)
	cell.cell_right_clicked.connect(_on_cell_right_clicked)
	return cell


func _clear_row(p_container: HBoxContainer, p_list: Array[TimelineCellView]) -> void:
	for old_cell: TimelineCellView in p_list:
		old_cell.queue_free()
	p_list.clear()
	if p_container != null:
		for child: Node in p_container.get_children():
			child.queue_free()


func _refresh_all_cells() -> void:
	if _total_frames <= 0:
		return

	var active_playhead: int = _playhead_frame if _playhead_frame != NO_FRAME else _hovered_frame
	var ghost_block: TimelineBlock = null
	var ghost_is_valid: bool = false
	if (
		_ghost_card != null
		and _plan != null
		and (_hovered_lane == TimelinePlan.TRACK_MOTION or _hovered_lane == TimelinePlan.TRACK_ACTION)
		and _hovered_frame >= 0
	):
		ghost_block = _plan.create_block(
			_ghost_card, _hovered_lane, _hovered_frame, _ghost_direction, _ghost_target_enemy_id
		)
		ghost_is_valid = _plan.can_place(ghost_block)

	for f: int in range(_total_frames):
		var is_ph: bool = (f == active_playhead)
		_refresh_ruler_cell(f, is_ph)
		_refresh_intent_cell(f, is_ph)
		_refresh_track_cell(_motion_cells[f], TimelinePlan.TRACK_MOTION, f, is_ph, ghost_block, ghost_is_valid)
		_refresh_track_cell(_action_cells[f], TimelinePlan.TRACK_ACTION, f, is_ph, ghost_block, ghost_is_valid)


func _refresh_ruler_cell(p_frame: int, p_is_playhead: bool) -> void:
	var bg: Color = ruler_even_color if (p_frame % 2) == 0 else ruler_odd_color
	var label_str: String = "%02d" % p_frame
	_ruler_cells[p_frame].apply_visual_state(bg, label_str, text_muted_color, false, clip_edge_color, p_is_playhead)


func _refresh_intent_cell(p_frame: int, p_is_playhead: bool) -> void:
	var bg: Color = empty_slot_color
	var symbols: PackedStringArray = PackedStringArray()
	var has_windup: bool = false
	var has_impact: bool = false

	if _state != null:
		for enemy: EnemyState in _state.get_living_enemies():
			if enemy.is_frozen or enemy.is_dazed:
				continue
			for intent: AttackIntent in enemy.attack_intents:
				if intent.end_frame == p_frame:
					has_impact = true
					if not symbols.has(enemy.symbol):
						symbols.append(enemy.symbol)
				elif intent.is_active_on(p_frame):
					has_windup = true

	var text: String = ""
	if has_impact:
		bg = intent_impact_color
		text = "%s!" % "".join(symbols)
	elif has_windup:
		bg = intent_windup_color

	_intent_cells[p_frame].apply_visual_state(bg, text, text_default_color, false, clip_edge_color, p_is_playhead)


func _refresh_track_cell(
	p_cell: TimelineCellView,
	p_track: int,
	p_frame: int,
	p_is_playhead: bool,
	p_ghost_block: TimelineBlock,
	p_ghost_is_valid: bool
) -> void:
	var bg: Color = empty_slot_color
	var text: String = ""
	var is_start: bool = false

	if _plan != null:
		var block: TimelineBlock = _plan.get_block_at(p_track, p_frame)
		if block != null:
			bg = _get_family_color(block.card.family)
			is_start = (block.start_frame == p_frame)
			text = _build_block_cell_text(block, p_frame)

	if p_ghost_block != null and p_ghost_block.track_index == p_track and p_ghost_block.occupies_frame(p_frame):
		bg = ghost_valid_color if p_ghost_is_valid else ghost_invalid_color
		if text.is_empty() and p_ghost_block.is_trigger_frame(p_frame):
			text = _get_pip_for_family(p_ghost_block.card.family)

	p_cell.apply_visual_state(bg, text, text_default_color, is_start, clip_edge_color, p_is_playhead)


func _build_block_cell_text(p_block: TimelineBlock, p_frame: int) -> String:
	var prefix: String = ""
	if p_block.start_frame == p_frame:
		if p_block.card.requires_cardinal_direction() or p_block.card.requires_timeline_direction():
			prefix = _direction_arrow(p_block.direction)

	var pip: String = ""
	if p_block.is_step_frame(p_frame):
		pip = PIP_STEP
	elif p_block.is_hit_frame(p_frame):
		pip = PIP_HIT
	elif p_block.is_edit_frame(p_frame):
		pip = PIP_EDIT

	return prefix + pip


func _get_family_color(p_family: Types.CardFamily) -> Color:
	match p_family:
		Types.CardFamily.MOTION:
			return motion_clip_color
		Types.CardFamily.ACTION:
			return action_clip_color
		_:
			return edit_clip_color


func _get_pip_for_family(p_family: Types.CardFamily) -> String:
	match p_family:
		Types.CardFamily.MOTION:
			return PIP_STEP
		Types.CardFamily.ACTION:
			return PIP_HIT
		_:
			return PIP_EDIT


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


# --- Signal Handlers ---

func _on_cell_hovered(p_lane: int, p_frame: int) -> void:
	_hovered_lane = p_lane
	_hovered_frame = p_frame
	_refresh_all_cells()
	frame_scrubbed.emit(p_frame)


func _on_cell_unhovered(p_lane: int, p_frame: int) -> void:
	if _hovered_lane == p_lane and _hovered_frame == p_frame:
		_hovered_lane = NO_LANE
		_hovered_frame = NO_FRAME
		_refresh_all_cells()
		if not get_global_rect().has_point(get_global_mouse_position()):
			scrub_cleared.emit()


func _on_cell_left_clicked(p_lane: int, p_frame: int) -> void:
	if p_lane == TimelinePlan.TRACK_MOTION or p_lane == TimelinePlan.TRACK_ACTION:
		track_frame_clicked.emit(p_lane, p_frame)


func _on_cell_right_clicked(p_lane: int, p_frame: int) -> void:
	if _plan == null:
		return
	if p_lane == TimelinePlan.TRACK_MOTION or p_lane == TimelinePlan.TRACK_ACTION:
		var existing: TimelineBlock = _plan.get_block_at(p_lane, p_frame)
		if existing != null:
			block_remove_requested.emit(existing)
