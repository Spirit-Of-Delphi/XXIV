class_name TimelineCellView
extends Control

## Single frame cell inside one lane of the TimelineEditorView.
## Emits hover and left/right click signals with its assigned (lane, frame) coordinates.

signal cell_hovered(p_lane: int, p_frame: int)
signal cell_unhovered(p_lane: int, p_frame: int)
signal cell_left_clicked(p_lane: int, p_frame: int)
signal cell_right_clicked(p_lane: int, p_frame: int)

@export_group("Node References")
@export var background_rect: ColorRect
@export var start_edge_bar: ColorRect
@export var playhead_overlay: ColorRect
@export var cell_label: Label

var _lane: int = 0
var _frame: int = 0


var lane: int:
	get: return _lane

var frame: int:
	get: return _frame


func setup_coordinates(p_lane: int, p_frame: int) -> void:
	_lane = p_lane
	_frame = p_frame
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func apply_visual_state(
	p_bg_color: Color,
	p_text: String,
	p_text_color: Color,
	p_show_start_edge: bool,
	p_edge_color: Color,
	p_is_playhead: bool
) -> void:
	if background_rect != null:
		background_rect.color = p_bg_color
	if start_edge_bar != null:
		start_edge_bar.visible = p_show_start_edge
		if p_show_start_edge:
			start_edge_bar.color = p_edge_color
	if playhead_overlay != null:
		playhead_overlay.visible = p_is_playhead
	if cell_label != null:
		cell_label.text = p_text
		cell_label.modulate = p_text_color


func _gui_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				cell_left_clicked.emit(_lane, _frame)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				cell_right_clicked.emit(_lane, _frame)
				accept_event()


func _on_mouse_entered() -> void:
	cell_hovered.emit(_lane, _frame)


func _on_mouse_exited() -> void:
	cell_unhovered.emit(_lane, _frame)
