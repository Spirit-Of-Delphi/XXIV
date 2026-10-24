class_name HandView
extends PanelContainer

## Displays Subject #24's current hand and context-sensitive aiming/targeting controls.

signal selection_changed(
	p_selected_card: CardData,
	p_direction: Types.Direction,
	p_target_enemy_id: int
)

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
@export var cards_row: HBoxContainer

var _cards: Array[CardData] = []
var _card_views: Array[CardView] = []
var _selected_index: int = NO_SELECTION
var _aim_direction: Types.Direction = Types.Direction.NORTH
var _target_enemy_id: int = NO_TARGET_ENEMY
var _state: CombatState = null
var _planning_tier: Types.SpeedTier = Types.SpeedTier.BASE
var _config: CombatConfig = null


var selected_card: CardData:
	get:
		if _selected_index >= 0 and _selected_index < _cards.size():
			return _cards[_selected_index]
		return null

var aim_direction: Types.Direction:
	get: return _aim_direction

var target_enemy_id: int:
	get: return _target_enemy_id


func _ready() -> void:
	if north_button != null:
		north_button.pressed.connect(_set_aim_direction.bind(Types.Direction.NORTH))
	if west_button != null:
		west_button.pressed.connect(_set_aim_direction.bind(Types.Direction.WEST))
	if south_button != null:
		south_button.pressed.connect(_set_aim_direction.bind(Types.Direction.SOUTH))
	if east_button != null:
		east_button.pressed.connect(_set_aim_direction.bind(Types.Direction.EAST))


func refresh_hand(
	p_deck: DeckState,
	p_state: CombatState,
	p_planning_tier: Types.SpeedTier,
	p_config: CombatConfig
) -> void:
	_cards = p_deck.hand
	_state = p_state
	_planning_tier = p_planning_tier
	_config = p_config

	if _selected_index >= _cards.size():
		_selected_index = NO_SELECTION

	if _target_enemy_id != NO_TARGET_ENEMY and _state != null:
		var target_enemy: EnemyState = _state.get_enemy_by_id(_target_enemy_id)
		if target_enemy == null or not target_enemy.is_alive:
			_target_enemy_id = NO_TARGET_ENEMY

	_normalize_direction_for_selected_card()
	_rebuild_card_widgets()
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


## True only when a card is selected AND all required enemy/frozen targets are valid.
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
	if selected_card == null or not visible:
		return
	if p_event is InputEventKey:
		var key_ev: InputEventKey = p_event as InputEventKey
		if not key_ev.pressed or key_ev.echo:
			return
		match key_ev.keycode:
			KEY_W, KEY_UP:
				if selected_card.requires_cardinal_direction():
					_set_aim_direction(Types.Direction.NORTH)
					get_viewport().set_input_as_handled()
			KEY_A, KEY_LEFT:
				if selected_card.requires_cardinal_direction() or selected_card.requires_timeline_direction():
					_set_aim_direction(Types.Direction.WEST)
					get_viewport().set_input_as_handled()
			KEY_S, KEY_DOWN:
				if selected_card.requires_cardinal_direction():
					_set_aim_direction(Types.Direction.SOUTH)
					get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				if selected_card.requires_cardinal_direction() or selected_card.requires_timeline_direction():
					_set_aim_direction(Types.Direction.EAST)
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				clear_selection()
				get_viewport().set_input_as_handled()


# --- Private Helpers ---

func _set_aim_direction(p_dir: Types.Direction) -> void:
	_aim_direction = p_dir
	_normalize_direction_for_selected_card()
	_refresh_toolbar()
	_emit_selection()


func _normalize_direction_for_selected_card() -> void:
	var card: CardData = selected_card
	if card != null and card.requires_timeline_direction():
		if _aim_direction != Types.Direction.WEST and _aim_direction != Types.Direction.EAST:
			_aim_direction = Types.Direction.EAST


func _rebuild_card_widgets() -> void:
	if card_view_scene == null or cards_row == null:
		return

	while _card_views.size() < _cards.size():
		var view: CardView = card_view_scene.instantiate() as CardView
		cards_row.add_child(view)
		view.card_clicked.connect(_on_card_clicked)
		_card_views.append(view)

	for i: int in range(_card_views.size()):
		var view: CardView = _card_views[i]
		if i < _cards.size():
			view.visible = true
			var card: CardData = _cards[i]
			var cost: int = card.frame_cost
			if _config != null:
				cost = CardCostResolver.resolve(card, _planning_tier, _config)
			view.bind_card(i, card, cost, i == _selected_index)
		else:
			view.visible = false


func _refresh_toolbar() -> void:
	var card: CardData = selected_card
	var use_cardinal: bool = card != null and card.requires_cardinal_direction()
	var use_binary: bool = card != null and card.requires_timeline_direction()

	if north_button != null:
		north_button.disabled = not use_cardinal
		north_button.text = "↑ W"
	if south_button != null:
		south_button.disabled = not use_cardinal
		south_button.text = "↓ S"
	if west_button != null:
		west_button.disabled = not (use_cardinal or use_binary)
		west_button.text = "← CCW / Earlier (A)" if use_binary else "← A"
	if east_button != null:
		east_button.disabled = not (use_cardinal or use_binary)
		east_button.text = "CW / Later (D) →" if use_binary else "→ D"

	if aim_status_label != null:
		aim_status_label.text = _build_status_text(card)


func _build_status_text(p_card: CardData) -> String:
	if p_card == null:
		return "Select a card in hand  |  Right-click a timeline clip to remove  |  Space = Commit Take"

	var parts: PackedStringArray = PackedStringArray()
	parts.append("[%s]" % (p_card.display_name if not p_card.display_name.is_empty() else p_card.id))

	if p_card.requires_enemy_target():
		var valid_enemy: EnemyState = _state.get_enemy_by_id(_target_enemy_id) if _state != null else null
		if valid_enemy == null or not valid_enemy.is_alive:
			parts.append("Click an ENEMY on the board to target!")
		elif p_card.requires_frozen_enemy_target() and not valid_enemy.is_frozen:
			parts.append("Target [%s] is NOT FROZEN — click a Frozen enemy!" % valid_enemy.symbol)
		else:
			parts.append("Target: %s (#%d)" % [valid_enemy.symbol, valid_enemy.id])

	if p_card.requires_cardinal_direction():
		parts.append("Aim: %s (WASD)" % _dir_name(_aim_direction))
	elif p_card.requires_timeline_direction():
		var mode_str: String = "CCW / Earlier" if _aim_direction == Types.Direction.WEST else "CW / Later"
		parts.append("Shift: %s (A/D)" % mode_str)

	if can_commit_selected_placement():
		parts.append("Click timeline track to place")

	return "  •  ".join(parts)


func _dir_name(p_dir: Types.Direction) -> String:
	match p_dir:
		Types.Direction.NORTH:
			return "NORTH ↑"
		Types.Direction.EAST:
			return "EAST →"
		Types.Direction.SOUTH:
			return "SOUTH ↓"
		Types.Direction.WEST:
			return "WEST ←"
		_:
			return ""


func _on_card_clicked(p_hand_index: int, _p_card: CardData) -> void:
	if _selected_index == p_hand_index:
		_selected_index = NO_SELECTION
	else:
		_selected_index = p_hand_index
	_normalize_direction_for_selected_card()
	_rebuild_card_widgets()
	_refresh_toolbar()
	_emit_selection()


func _emit_selection() -> void:
	selection_changed.emit(selected_card, _aim_direction, _target_enemy_id)
