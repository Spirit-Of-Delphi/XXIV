class_name CardView
extends Control

## Single interactive card widget inside HandView.
## Displays resolved frame cost (highlighting Tier 3 discounts) and emits click events.

signal card_clicked(p_hand_index: int, p_card: CardData)

@export_group("Node References")
@export var selection_border: ColorRect
@export var card_background: ColorRect
@export var family_banner: ColorRect
@export var family_label: Label
@export var cost_label: Label
@export var name_label: Label
@export var description_label: Label

@export_group("Palette")
@export var selected_border_color: Color = Color(1.0, 0.88, 0.32, 1.0)
@export var normal_bg_color: Color = Color(0.12, 0.14, 0.18, 0.96)
@export var selected_bg_color: Color = Color(0.18, 0.21, 0.27, 1.0)
@export var motion_banner_color: Color = Color(0.14, 0.58, 0.48, 1.0)
@export var action_banner_color: Color = Color(0.76, 0.24, 0.28, 1.0)
@export var edit_banner_color: Color = Color(0.54, 0.32, 0.82, 1.0)
@export var normal_cost_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var discounted_cost_color: Color = Color(0.40, 1.0, 0.62, 1.0)

var _hand_index: int = -1
var _card: CardData = null


func bind_card(
	p_hand_index: int,
	p_card: CardData,
	p_resolved_cost: int,
	p_is_selected: bool
) -> void:
	_hand_index = p_hand_index
	_card = p_card

	if selection_border != null:
		selection_border.visible = p_is_selected
		selection_border.color = selected_border_color

	if card_background != null:
		card_background.color = selected_bg_color if p_is_selected else normal_bg_color

	if family_banner != null:
		family_banner.color = _get_banner_color(p_card.family)

	if family_label != null:
		family_label.text = _get_family_title(p_card.family)

	if cost_label != null:
		var is_discounted: bool = p_resolved_cost < p_card.frame_cost
		cost_label.text = "%df*" % p_resolved_cost if is_discounted else "%df" % p_resolved_cost
		cost_label.modulate = discounted_cost_color if is_discounted else normal_cost_color

	if name_label != null:
		name_label.text = p_card.display_name if not p_card.display_name.is_empty() else p_card.id

	if description_label != null:
		description_label.text = p_card.description


func _gui_input(p_event: InputEvent) -> void:
	if _card == null:
		return
	if p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(_hand_index, _card)
			accept_event()


func _get_banner_color(p_family: Types.CardFamily) -> Color:
	match p_family:
		Types.CardFamily.MOTION:
			return motion_banner_color
		Types.CardFamily.ACTION:
			return action_banner_color
		_:
			return edit_banner_color


func _get_family_title(p_family: Types.CardFamily) -> String:
	match p_family:
		Types.CardFamily.MOTION:
			return "MOTION"
		Types.CardFamily.ACTION:
			return "ACTION"
		_:
			return "EDIT"
