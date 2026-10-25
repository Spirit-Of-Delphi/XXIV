@tool
class_name CardView
extends Control

## Tactile cream-paper index slip card for the Cutting-Room Bench UI.
## Supports both click-to-arm and direct drag-and-drop onto TimelineEditorView.

signal card_clicked(p_slot_index: int, p_card: CardData)
signal card_drag_started(p_slot_index: int, p_card: CardData)

const SHADOW_REST: Vector2 = Vector2(2.0, 2.0)
const SHADOW_HOVER: Vector2 = Vector2(3.5, 3.5)
const HOVER_LIFT: Vector2 = Vector2(-1.5, -1.5)
const CARD_MARGIN_RIGHT_BOTTOM: Vector2 = Vector2(4.0, 4.0)
const MAX_DRAWN_PIPS: int = 9
const PIP_SIZE: Vector2 = Vector2(6.0, 12.0)
const PIP_GAP: float = 2.0


class _PaperDragSlip extends Control:
	var title_text: String = ""
	var cost_text: String = ""
	var pip_color: Color = Color(0.498, 0.624, 0.878, 1.0)
	var stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)
	var edge_color: Color = Color(0.718, 0.686, 0.604, 1.0)
	var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)

	func _init(
		p_title: String,
		p_cost: int,
		p_pip_col: Color,
		p_stock_col: Color,
		p_edge_col: Color,
		p_ink_col: Color
	) -> void:
		title_text = p_title
		cost_text = "%df" % p_cost
		pip_color = p_pip_col
		stock_color = p_stock_col
		edge_color = p_edge_col
		ink_color = p_ink_col
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		var font: Font = ThemeDB.fallback_font
		var text_w: float = 120.0
		if font != null:
			text_w = font.get_string_size(title_text + "  " + cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var box_w: float = maxf(124.0, text_w + 34.0)
		var box_h: float = 30.0
		size = Vector2(box_w, box_h)
		position = Vector2(-box_w * 0.5, -box_h - 10.0)

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2(3.0, 3.0), size), Color(0.0, 0.0, 0.0, 0.45), true)
		draw_rect(rect, stock_color, true)
		draw_rect(rect, edge_color, false, 1.0)

		var pip_rect: Rect2 = Rect2(Vector2(9.0, 8.0), Vector2(6.0, 14.0))
		draw_rect(pip_rect, pip_color, true)
		draw_rect(pip_rect, ink_color, false, 1.0)

		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		if font == null:
			return
		var ascent: float = font.get_ascent(15)
		var descent: float = font.get_descent(15)
		var base_y: float = (size.y + ascent - descent) * 0.5
		draw_string(font, Vector2(22.0, base_y), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink_color)
		draw_string(
			font,
			Vector2(0.0, base_y),
			cost_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 9.0,
			13,
			Color(ink_color.r, ink_color.g, ink_color.b, 0.72)
		)


@export_group("Node References")
@export var name_label: Label
@export var description_label: Label

@export_group("Cutting-Room Palette")
@export var paper_stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)     # #e6e0d1
@export var paper_hover_color: Color = Color(0.933, 0.910, 0.855, 1.0)     # #eee8da
@export var paper_edge_color: Color = Color(0.718, 0.686, 0.604, 1.0)      # #b7af9a
@export var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)             # #1c1d1b
@export var body_ink_color: Color = Color(0.200, 0.196, 0.173, 1.0)        # #33322c
@export var sub_ink_color: Color = Color(0.420, 0.396, 0.337, 1.0)         # #6b6556
@export var discount_teal_color: Color = Color(0.153, 0.412, 0.353, 1.0)   # #27695a
@export var armed_yellow_color: Color = Color(0.941, 0.863, 0.333, 1.0)    # #f0dc55
@export var staged_dash_color: Color = Color(0.365, 0.412, 0.388, 1.0)     # #5d6963
@export var staged_text_color: Color = Color(0.545, 0.584, 0.561, 0.65)    # #8b958f
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.45)

@export_group("Track Pip Colors")
@export var motion_pip_color: Color = Color(0.498, 0.624, 0.878, 1.0)      # #7f9fe0
@export var strike_pip_color: Color = Color(0.839, 0.627, 0.290, 1.0)      # #d6a04a
@export var tech_pip_color: Color = Color(0.769, 0.698, 0.494, 1.0)        # #c4b27e
@export var edit_pip_color: Color = Color(0.671, 0.561, 0.839, 1.0)        # #ab8fd6

var _slot_index: int = 0
var _card: CardData = null
var _resolved_cost: int = 4
var _base_cost: int = 4
var _is_selected: bool = false
var _is_staged: bool = false
var _is_hovered: bool = false
var _press_armed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_apply_label_visuals()
	queue_redraw()


func bind_card(
	p_slot_index: int,
	p_card: CardData,
	p_resolved_cost: int,
	p_is_selected: bool,
	p_is_staged: bool = false
) -> void:
	_slot_index = p_slot_index
	_card = p_card
	_resolved_cost = maxi(1, p_resolved_cost)
	_base_cost = p_card.frame_cost if p_card != null else _resolved_cost
	_is_selected = p_is_selected and not p_is_staged
	_is_staged = p_is_staged
	_press_armed = false

	mouse_default_cursor_shape = Control.CURSOR_ARROW if _is_staged else Control.CURSOR_POINTING_HAND
	_apply_label_visuals()
	queue_redraw()


func _gui_input(p_event: InputEvent) -> void:
	if _card == null or _is_staged:
		return
	if p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_armed = true
		else:
			var was_armed: bool = _press_armed
			_press_armed = false
			if (
				was_armed
				and not get_viewport().gui_is_dragging()
				and Rect2(Vector2.ZERO, size).has_point(mb.position)
			):
				card_clicked.emit(_slot_index, _card)
				accept_event()


func _get_drag_data(_p_at_position: Vector2) -> Variant:
	if Engine.is_editor_hint() or _card == null or _is_staged:
		return null

	_press_armed = false
	var card_title: String = _card.display_name if not _card.display_name.is_empty() else _card.id
	var preview_anchor: Control = Control.new()
	preview_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slip: _PaperDragSlip = _PaperDragSlip.new(
		card_title,
		_resolved_cost,
		_resolve_pip_color(_card),
		paper_stock_color,
		paper_edge_color,
		ink_color
	)
	preview_anchor.add_child(slip)
	set_drag_preview(preview_anchor)

	card_drag_started.emit(_slot_index, _card)
	return {
		"kind": "hand_card",
		"slot_index": _slot_index,
		"card": _card,
	}


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var base_size: Vector2 = Vector2(
		maxf(40.0, size.x - CARD_MARGIN_RIGHT_BOTTOM.x),
		maxf(40.0, size.y - CARD_MARGIN_RIGHT_BOTTOM.y)
	)

	if _is_staged:
		_draw_staged_slot(font, Rect2(Vector2.ZERO, base_size))
		return

	var lift: Vector2 = HOVER_LIFT if _is_hovered else Vector2.ZERO
	var card_rect: Rect2 = Rect2(lift, base_size)
	var shadow_offset: Vector2 = SHADOW_HOVER if _is_hovered else SHADOW_REST

	# 1. Hard Offset Drop Shadow
	draw_rect(Rect2(card_rect.position + shadow_offset, card_rect.size), shadow_color, true)

	# 2. Warm Cream Paper Body & Tan Edge Border
	var fill: Color = paper_hover_color if _is_hovered else paper_stock_color
	draw_rect(card_rect, fill, true)
	draw_rect(card_rect, paper_edge_color, false, 1.0)

	# 3. Armed 3px Grease-Pencil Yellow Outline
	if _is_selected:
		draw_rect(card_rect.grow(2.0), armed_yellow_color, false, 3.0)

	if font == null:
		return

	# 4. Top-Right [1..9] Keycap Box
	var kbd_rect: Rect2 = Rect2(
		Vector2(card_rect.end.x - 29.0, card_rect.position.y + 7.0),
		Vector2(20.0, 18.0)
	)
	draw_rect(kbd_rect, paper_edge_color, false, 1.0)
	_draw_text_in_rect(font, kbd_rect, "%d" % (_slot_index + 1), 11, sub_ink_color, HORIZONTAL_ALIGNMENT_CENTER)

	# 5. Row 2 Left: Colored Frame-Cost Pips + Resolved Cost Number
	var pip_y: float = card_rect.position.y + 30.0
	var pip_x: float = card_rect.position.x + 10.0
	var pip_col: Color = _resolve_pip_color(_card)
	var pip_count: int = mini(_resolved_cost, MAX_DRAWN_PIPS)
	for i: int in range(pip_count):
		var pr: Rect2 = Rect2(Vector2(pip_x + float(i) * (PIP_SIZE.x + PIP_GAP), pip_y), PIP_SIZE)
		draw_rect(pr, pip_col, true)
		draw_rect(pr, ink_color, false, 1.0)

	var num_x: float = pip_x + float(pip_count) * (PIP_SIZE.x + PIP_GAP) + 5.0
	var is_discounted: bool = _resolved_cost < _base_cost
	var cost_col: Color = discount_teal_color if is_discounted else ink_color
	_draw_text_in_rect(
		font,
		Rect2(Vector2(num_x, pip_y - 2.0), Vector2(36.0, 16.0)),
		"%d" % _resolved_cost,
		13,
		cost_col,
		HORIZONTAL_ALIGNMENT_LEFT
	)

	# 6. Row 2 Right: Card Family & Lifecycle Tag
	var type_rect: Rect2 = Rect2(
		Vector2(card_rect.end.x - 128.0, pip_y - 2.0),
		Vector2(118.0, 16.0)
	)
	_draw_text_in_rect(font, type_rect, _build_type_tag(_card), 12, sub_ink_color, HORIZONTAL_ALIGNMENT_RIGHT)


# --- Private Helpers ---

func _draw_staged_slot(p_font: Font, p_rect: Rect2) -> void:
	_draw_dashed_rect(p_rect, staged_dash_color, 6.0, 4.0)
	if p_font == null:
		return

	var kbd_rect: Rect2 = Rect2(
		Vector2(p_rect.end.x - 29.0, p_rect.position.y + 7.0),
		Vector2(20.0, 18.0)
	)
	draw_rect(kbd_rect, staged_dash_color, false, 1.0)
	_draw_text_in_rect(p_font, kbd_rect, "%d" % (_slot_index + 1), 11, staged_text_color, HORIZONTAL_ALIGNMENT_CENTER)

	var pip_y: float = p_rect.position.y + 30.0
	var pip_x: float = p_rect.position.x + 10.0
	var pip_count: int = mini(_resolved_cost, MAX_DRAWN_PIPS)
	for i: int in range(pip_count):
		var pr: Rect2 = Rect2(Vector2(pip_x + float(i) * (PIP_SIZE.x + PIP_GAP), pip_y), PIP_SIZE)
		draw_rect(pr, staged_text_color, false, 1.0)

	var num_x: float = pip_x + float(pip_count) * (PIP_SIZE.x + PIP_GAP) + 5.0
	_draw_text_in_rect(
		p_font,
		Rect2(Vector2(num_x, pip_y - 2.0), Vector2(36.0, 16.0)),
		"%d" % _resolved_cost,
		13,
		staged_text_color,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	var type_rect: Rect2 = Rect2(
		Vector2(p_rect.end.x - 128.0, pip_y - 2.0),
		Vector2(118.0, 16.0)
	)
	_draw_text_in_rect(p_font, type_rect, _build_type_tag(_card), 12, staged_text_color, HORIZONTAL_ALIGNMENT_RIGHT)


func _apply_label_visuals() -> void:
	if name_label != null:
		if _card != null:
			name_label.text = _card.display_name if not _card.display_name.is_empty() else _card.id
		name_label.modulate = staged_text_color if _is_staged else ink_color

	if description_label != null:
		if _card != null:
			description_label.text = _card.description
		description_label.modulate = staged_text_color if _is_staged else body_ink_color


func _resolve_pip_color(p_card_data: CardData) -> Color:
	if p_card_data == null:
		return motion_pip_color
	match p_card_data.family:
		Types.CardFamily.MOTION:
			return motion_pip_color
		Types.CardFamily.ACTION:
			if p_card_data.base_damage > 0 or not p_card_data.hit_frames.is_empty():
				return strike_pip_color
			return tech_pip_color
		_:
			return edit_pip_color


func _build_type_tag(p_card_data: CardData) -> String:
	if p_card_data == null:
		return "Motion"
	var base: String = "Edit"
	match p_card_data.family:
		Types.CardFamily.MOTION:
			base = "Motion"
		Types.CardFamily.ACTION:
			base = "Action"
		_:
			base = "Edit"
	if p_card_data.exhausts_on_play:
		return "%s, exhaust" % base
	if p_card_data.retains_in_hand:
		return "%s, retain" % base
	return base


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


func _draw_text_in_rect(
	p_font: Font,
	p_rect: Rect2,
	p_text: String,
	p_font_size: int,
	p_color: Color,
	p_align: HorizontalAlignment
) -> void:
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


func _on_mouse_entered() -> void:
	_is_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_hovered = false
	queue_redraw()
