class_name HandView
extends VBoxContainer

## 3-column Cutting-Room paper card grid + directional aiming bar.
## Keeps hand slots [1..9] in fixed positions during a take, supports drag-and-drop
## slot reconciliation, and shares its directional toolbar with selected timeline clips.

signal selection_changed(
	p_selected_card: CardData,
	p_direction: Types.Direction,
	p_target_enemy_id: int
)
signal card_drag_begun(p_slot_index: int, p_card: CardData)
signal placed_clip_reaim_requested(p_direction: Types.Direction)

const NO_SELECTION: int = -1
const NO_TARGET_ENEMY: int = -1

@export_group("Packed Scenes")
@export var card_view_scene: PackedScene

@export_group("Node References")
@export var aim_status_label: Label
@export var north_button: Button
@export var west_button: Button
@export var south_button: Button
@export var east_button: Button
@export var cards_grid: GridContainer

@export_group("Palette")
@export var idle_hint_color: Color = Color(0.678, 0.714, 0.690, 1.0)    # #adb6b0
@export var armed_hint_color: Color = Color(0.941, 0.863, 0.333, 1.0)   # #f0dc55
@export var clip_hint_color: Color = Color(0.902, 0.878, 0.820, 1.0)    # #e6e0d1

var _bound_take_number: int = -1
var _slot_cards: Array[CardData] = []
var _slot_staged: Array[bool] = []
var _last_acted_slot: int = NO_SELECTION

var _card_views: Array[CardView] = []
var _selected_index: int = NO_SELECTION
var _aim_direction: Types.Direction = Types.Direction.NORTH
var _target_enemy_id: int = NO_TARGET_ENEMY
var _context_block: TimelineBlock = null
var _state: CombatState = null
var _planning_tier: Types.SpeedTier = Types.SpeedTier.BASE
var _config: CombatConfig = null


var selected_card: CardData:
	get:
		if _selected_index >= 0 and _selected_index < _slot_cards.size():
			if not _slot_staged[_selected_index]:
				return _slot_cards[_selected_index]
		return null

var aim_direction: Types.Direction:
	get: return _aim_direction

var target_enemy_id: int:
	get: return _target_enemy_id


func _ready() -> void:
	if north_button != null:
		north_button.focus_mode = Control.FOCUS_NONE
		north_button.pressed.connect(_on_direction_button_pressed.bind(Types.Direction.NORTH))
	if west_button != null:
		west_button.focus_mode = Control.FOCUS_NONE
		west_button.pressed.connect(_on_direction_button_pressed.bind(Types.Direction.WEST))
	if south_button != null:
		south_button.focus_mode = Control.FOCUS_NONE
		south_button.pressed.connect(_on_direction_button_pressed.bind(Types.Direction.SOUTH))
	if east_button != null:
		east_button.focus_mode = Control.FOCUS_NONE
		east_button.pressed.connect(_on_direction_button_pressed.bind(Types.Direction.EAST))


func reset_take_slots() -> void:
	_bound_take_number = -1
	_slot_cards.clear()
	_slot_staged.clear()
	_last_acted_slot = NO_SELECTION
	_selected_index = NO_SELECTION
	_context_block = null


func notify_slot_acted(p_slot_index: int) -> void:
	_last_acted_slot = p_slot_index
	if _selected_index == p_slot_index:
		_selected_index = NO_SELECTION


func set_placed_clip_context(p_block: TimelineBlock) -> void:
	_context_block = p_block
	_refresh_toolbar()


func refresh_hand(
	p_take_number: int,
	p_deck: DeckState,
	p_state: CombatState,
	p_planning_tier: Types.SpeedTier,
	p_config: CombatConfig
) -> void:
	_state = p_state
	_planning_tier = p_planning_tier
	_config = p_config

	_reconcile_slots(p_take_number, p_deck)

	if _selected_index >= _slot_cards.size() or (_selected_index >= 0 and _slot_staged[_selected_index]):
		_selected_index = NO_SELECTION

	if _target_enemy_id != NO_TARGET_ENEMY and _state != null:
		var target_enemy: EnemyState = _state.get_enemy_by_id(_target_enemy_id)
		if target_enemy == null or not target_enemy.is_alive:
			_target_enemy_id = NO_TARGET_ENEMY

	_normalize_direction_for_selected_card()
	_rebuild_card_widgets()
	_refresh_toolbar()
	_emit_selection()


func set_aim_direction(p_dir: Types.Direction) -> void:
	_aim_direction = p_dir
	_normalize_direction_for_selected_card()
	_refresh_toolbar()
	_emit_selection()


func set_target_enemy_id(p_enemy_id: int) -> void:
	_target_enemy_id = p_enemy_id
	_refresh_toolbar()
	_emit_selection()


func clear_selection() -> void:
	_selected_index = NO_SELECTION
	_rebuild_card_widgets()
	_refresh_toolbar()
	_emit_selection()


func can_commit_selected_placement() -> bool:
	var card: CardData = selected_card
	if card == null:
		return false
	if card.requires_enemy_target():
		if _state == null or _target_enemy_id == NO_TARGET_ENEMY:
			return false
		var target_enemy: EnemyState = _state.get_enemy_by_id(_target_enemy_id)
		if target_enemy == null or not target_enemy.is_alive:
			return false
		if card.requires_frozen_enemy_target() and not target_enemy.is_frozen:
			return false
	return true


func _unhandled_key_input(p_event: InputEvent) -> void:
	if not visible:
		return
	if p_event is InputEventKey:
		var key_ev: InputEventKey = p_event as InputEventKey
		if not key_ev.pressed or key_ev.echo or key_ev.ctrl_pressed or key_ev.meta_pressed:
			return

		if key_ev.keycode >= KEY_1 and key_ev.keycode <= KEY_9:
			var idx: int = int(key_ev.keycode) - int(KEY_1)
			if idx < _slot_cards.size() and not _slot_staged[idx]:
				_on_card_clicked(idx, _slot_cards[idx])
				get_viewport().set_input_as_handled()
			return

		if selected_card == null:
			return

		match key_ev.keycode:
			KEY_W, KEY_UP:
				if selected_card.requires_cardinal_direction():
					set_aim_direction(Types.Direction.NORTH)
					get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				if selected_card.requires_cardinal_direction() or selected_card.requires_timeline_direction():
					set_aim_direction(Types.Direction.WEST)
					get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				if selected_card.requires_cardinal_direction():
					set_aim_direction(Types.Direction.SOUTH)
					get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				if selected_card.requires_cardinal_direction() or selected_card.requires_timeline_direction():
					set_aim_direction(Types.Direction.EAST)
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				clear_selection()
				get_viewport().set_input_as_handled()


# --- Private Helpers ---

func _on_direction_button_pressed(p_dir: Types.Direction) -> void:
	if selected_card != null:
		set_aim_direction(p_dir)
	elif _context_block != null:
		placed_clip_reaim_requested.emit(p_dir)


func _reconcile_slots(p_take_number: int, p_deck: DeckState) -> void:
	if p_deck == null:
		return

	if p_take_number != _bound_take_number or _slot_cards.is_empty():
		_bound_take_number = p_take_number
		_slot_cards = p_deck.hand.duplicate()
		_slot_staged.clear()
		for _i: int in range(_slot_cards.size()):
			_slot_staged.append(false)
		_last_acted_slot = NO_SELECTION
		return

	var available: Array[CardData] = p_deck.hand.duplicate()
	var next_staged: Array[bool] = []
	for _i: int in range(_slot_cards.size()):
		next_staged.append(true)

	for i: int in range(_slot_cards.size()):
		if not _slot_staged[i] and i != _last_acted_slot:
			var found_idx: int = available.find(_slot_cards[i])
			if found_idx >= 0:
				available.remove_at(found_idx)
				next_staged[i] = false

	for i: int in range(_slot_cards.size()):
		if next_staged[i]:
			var found_idx: int = available.find(_slot_cards[i])
			if found_idx >= 0:
				available.remove_at(found_idx)
				next_staged[i] = false

	for extra_card: CardData in available:
		_slot_cards.append(extra_card)
		next_staged.append(false)

	_slot_staged = next_staged


func _normalize_direction_for_selected_card() -> void:
	var card: CardData = selected_card
	if card != null and card.requires_timeline_direction():
		if _aim_direction != Types.Direction.WEST and _aim_direction != Types.Direction.EAST:
			_aim_direction = Types.Direction.EAST


func _rebuild_card_widgets() -> void:
	if card_view_scene == null or cards_grid == null:
		return

	while _card_views.size() < _slot_cards.size():
		var view: CardView = card_view_scene.instantiate() as CardView
		cards_grid.add_child(view)
		view.card_clicked.connect(_on_card_clicked)
		view.card_drag_started.connect(_on_card_drag_started)
		_card_views.append(view)

	for i: int in range(_card_views.size()):
		var view: CardView = _card_views[i]
		if i < _slot_cards.size():
			view.visible = true
			var card: CardData = _slot_cards[i]
			var cost: int = card.frame_cost
			if _config != null:
				cost = CardCostResolver.resolve(card, _planning_tier, _config)
			var is_staged: bool = _slot_staged[i]
			view.bind_card(i, card, cost, i == _selected_index and not is_staged, is_staged)
		else:
			view.visible = false


func _refresh_toolbar() -> void:
	var active_card: CardData = selected_card
	if active_card == null and _context_block != null:
		active_card = _context_block.card

	var use_cardinal: bool = active_card != null and active_card.requires_cardinal_direction()
	var use_binary: bool = active_card != null and active_card.requires_timeline_direction()

	if north_button != null:
		north_button.disabled = not use_cardinal
		north_button.text = "↑ W"
	if south_button != null:
		south_button.disabled = not use_cardinal
		south_button.text = "↓ S"
	if west_button != null:
		west_button.disabled = not (use_cardinal or use_binary)
		west_button.text = "← Earlier / CCW (A)" if use_binary else "← A"
	if east_button != null:
		east_button.disabled = not (use_cardinal or use_binary)
		east_button.text = "Later / CW (D) →" if use_binary else "→ D"

	if aim_status_label != null:
		if selected_card != null:
			aim_status_label.text = _build_armed_status_text(selected_card)
			aim_status_label.modulate = armed_hint_color
		elif _context_block != null:
			aim_status_label.text = _build_clip_status_text(_context_block)
			aim_status_label.modulate = clip_hint_color
		else:
			aim_status_label.text = "Drag cards onto timeline or press [1–9]  •  Drag clips or ←/→ to retime"
			aim_status_label.modulate = idle_hint_color


func _build_armed_status_text(p_card: CardData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(p_card.display_name if not p_card.display_name.is_empty() else p_card.id)

	if p_card.requires_enemy_target():
		var valid_enemy: EnemyState = _state.get_enemy_by_id(_target_enemy_id) if _state != null else null
		if valid_enemy == null or not valid_enemy.is_alive:
			parts.append("Click hostile in arena or letter on timeline")
		elif p_card.requires_frozen_enemy_target() and not valid_enemy.is_frozen:
			parts.append("[%s] is not frozen — pick a frozen hostile" % valid_enemy.symbol)
		else:
			parts.append("Target [%s]" % valid_enemy.symbol)

	if p_card.requires_cardinal_direction():
		parts.append("Aim %s (click arena or WASD)" % _dir_name(_aim_direction))
	elif p_card.requires_timeline_direction():
		var mode_str: String = "CCW / Earlier" if _aim_direction == Types.Direction.WEST else "CW / Later"
		parts.append(mode_str)

	return "  •  ".join(parts)


func _build_clip_status_text(p_block: TimelineBlock) -> String:
	var card: CardData = p_block.card
	var title: String = card.display_name if not card.display_name.is_empty() else card.id
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%s (f%d–%d)" % [title, p_block.start_frame, p_block.end_frame])
	parts.append("Drag or ←/→ to retime")
	if card.requires_cardinal_direction() or card.requires_timeline_direction():
		parts.append("WASD or arena to re-aim")
	elif card.requires_enemy_target():
		parts.append("Click hostile to retarget")
	parts.append("Del to remove")
	return "  •  ".join(parts)


func _dir_name(p_dir: Types.Direction) -> String:
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


func _on_card_clicked(p_slot_index: int, _p_card: CardData) -> void:
	if p_slot_index < 0 or p_slot_index >= _slot_staged.size() or _slot_staged[p_slot_index]:
		return
	_last_acted_slot = p_slot_index
	if _selected_index == p_slot_index:
		_selected_index = NO_SELECTION
	else:
		_selected_index = p_slot_index
		_context_block = null
	_normalize_direction_for_selected_card()
	_rebuild_card_widgets()
	_refresh_toolbar()
	_emit_selection()


func _on_card_drag_started(p_slot_index: int, p_card: CardData) -> void:
	_last_acted_slot = p_slot_index
	_context_block = null
	card_drag_begun.emit(p_slot_index, p_card)


func _emit_selection() -> void:
	selection_changed.emit(selected_card, _aim_direction, _target_enemy_id)
