@tool
class_name ExecuteButton
extends Button

## Custom tactile Cutting-Room '● Execute' button.
## Renders warm cream stock, a vermilion recording dot, and a razor-sharp 3px offset shadow
## with physical press-down sink, eliminating manual Inspector StyleBox overrides.

@export var button_title: String = "Execute":
	set(p_val):
		button_title = p_val
		queue_redraw()

@export_group("Palette")
@export var stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)       # #e6e0d1
@export var stock_hover_color: Color = Color(1.0, 0.965, 0.867, 1.0)   # #fff6dd
@export var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)         # #1c1d1b
@export var record_dot_color: Color = Color(0.761, 0.231, 0.169, 1.0)  # #c23b2b
@export var hard_shadow_color: Color = Color(0.059, 0.067, 0.063, 1.0) # #0f1110
@export var disabled_border_color: Color = Color(0.275, 0.318, 0.294, 1.0)
@export var disabled_text_color: Color = Color(0.545, 0.584, 0.561, 0.55)


func _ready() -> void:
	text = ""
	flat = true
	var empty_box: StyleBoxEmpty = StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty_box)
	add_theme_stylebox_override("hover", empty_box)
	add_theme_stylebox_override("pressed", empty_box)
	add_theme_stylebox_override("disabled", empty_box)
	add_theme_stylebox_override("focus", empty_box)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _notification(p_what: int) -> void:
	if (
		p_what == NOTIFICATION_MOUSE_ENTER
		or p_what == NOTIFICATION_MOUSE_EXIT
		or p_what == NOTIFICATION_THEME_CHANGED
		or p_what == NOTIFICATION_RESIZED
	):
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var body_size: Vector2 = Vector2(maxf(20.0, size.x - 3.0), maxf(20.0, size.y - 3.0))

	if disabled:
		var dis_rect: Rect2 = Rect2(Vector2.ZERO, body_size)
		draw_rect(dis_rect, disabled_border_color, false, 1.0)
		if font != null:
			_draw_centered(font, dis_rect, button_title, 18, disabled_text_color, 0.0)
		return

	var is_down: bool = button_pressed
	var press_shift: Vector2 = Vector2(2.0, 2.0) if is_down else Vector2.ZERO
	var shadow_shift: Vector2 = Vector2(1.0, 1.0) if is_down else Vector2(3.0, 3.0)
	var body_rect: Rect2 = Rect2(press_shift, body_size)

	# 1. Hard Offset Shadow (#0f1110)
	draw_rect(Rect2(body_rect.position + shadow_shift, body_rect.size), hard_shadow_color, true)

	# 2. Cream Paper Slab (#e6e0d1 -> #fff6dd on hover)
	var fill: Color = stock_hover_color if is_hovered() else stock_color
	draw_rect(body_rect, fill, true)

	# 3. Vermilion Record Dot (●) + Ink Title
	var dot_center: Vector2 = Vector2(body_rect.position.x + 26.0, body_rect.position.y + body_rect.size.y * 0.5)
	draw_circle(dot_center, 5.5, record_dot_color)

	if font != null:
		_draw_centered(font, body_rect, button_title, 19, ink_color, 12.0)


func _draw_centered(
	p_font: Font,
	p_rect: Rect2,
	p_label: String,
	p_font_size: int,
	p_color: Color,
	p_x_offset: float
) -> void:
	var ascent: float = p_font.get_ascent(p_font_size)
	var descent: float = p_font.get_descent(p_font_size)
	var baseline_y: float = p_rect.position.y + (p_rect.size.y + ascent - descent) * 0.5
	draw_string(
		p_font,
		Vector2(p_rect.position.x + p_x_offset, baseline_y),
		p_label,
		HORIZONTAL_ALIGNMENT_CENTER,
		p_rect.size.x - p_x_offset,
		p_font_size,
		p_color
	)
