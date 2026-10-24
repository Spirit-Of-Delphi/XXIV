class_name TileView
extends Node2D

## Visual Node2D cell for a single coordinate on the tactical grid.

enum TerrainMode {
	FLOOR = 0,
	WALL = 1,
	PIT = 2,
}

enum TelegraphMode {
	NONE = 0,
	UPCOMING = 1,
	ACTIVE_WINDOW = 2,
	IMPACT = 3,
}

@export_group("Node References")
@export var selection_border: CanvasItem
@export var floor_visual: CanvasItem
@export var obstacle_visual: CanvasItem
@export var telegraph_overlay: CanvasItem
@export var telegraph_label: Label

@export_group("Palette")
@export var floor_even_color: Color = Color(0.14, 0.16, 0.20, 1.0)
@export var floor_odd_color: Color = Color(0.17, 0.19, 0.24, 1.0)
@export var wall_color: Color = Color(0.42, 0.45, 0.52, 1.0)
@export var pit_color: Color = Color(0.04, 0.04, 0.06, 1.0)
@export var upcoming_telegraph_color: Color = Color(1.0, 0.65, 0.15, 0.22)
@export var active_window_telegraph_color: Color = Color(1.0, 0.72, 0.12, 0.48)
@export var impact_telegraph_color: Color = Color(1.0, 0.18, 0.22, 0.72)

var _grid_position: Vector2i = Vector2i.ZERO


var grid_position: Vector2i:
	get: return _grid_position


func setup_cell(p_grid_pos: Vector2i, p_world_pos: Vector2) -> void:
	_grid_position = p_grid_pos
	position = p_world_pos
	var is_even: bool = ((p_grid_pos.x + p_grid_pos.y) % 2) == 0
	if floor_visual != null:
		floor_visual.self_modulate = floor_even_color if is_even else floor_odd_color
	set_terrain(TerrainMode.FLOOR)
	set_telegraph(TelegraphMode.NONE, "")
	set_selected(false)


func set_terrain(p_mode: TerrainMode) -> void:
	if obstacle_visual == null:
		return
	match p_mode:
		TerrainMode.WALL:
			obstacle_visual.visible = true
			obstacle_visual.self_modulate = wall_color
		TerrainMode.PIT:
			obstacle_visual.visible = true
			obstacle_visual.self_modulate = pit_color
		_:
			obstacle_visual.visible = false


func set_telegraph(p_mode: TelegraphMode, p_frame_text: String = "") -> void:
	if telegraph_overlay != null:
		match p_mode:
			TelegraphMode.UPCOMING:
				telegraph_overlay.visible = true
				telegraph_overlay.self_modulate = upcoming_telegraph_color
			TelegraphMode.ACTIVE_WINDOW:
				telegraph_overlay.visible = true
				telegraph_overlay.self_modulate = active_window_telegraph_color
			TelegraphMode.IMPACT:
				telegraph_overlay.visible = true
				telegraph_overlay.self_modulate = impact_telegraph_color
			_:
				telegraph_overlay.visible = false

	if telegraph_label != null:
		var show_text: bool = p_mode != TelegraphMode.NONE and not p_frame_text.is_empty()
		telegraph_label.visible = show_text
		if show_text:
			telegraph_label.text = p_frame_text


func set_selected(p_selected: bool) -> void:
	if selection_border != null:
		selection_border.visible = p_selected
