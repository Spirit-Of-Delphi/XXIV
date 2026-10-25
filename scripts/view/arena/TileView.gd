@tool
class_name TileView
extends Node2D

## Seamless 152x152 Cutting-Room drafting-vellum tile.
## Renders warm checkerboard paper stock, procedural grain speckles/scratches,
## gunmetal beveled walls, ink-hatched pits, and grease-pencil vermilion telegraphs.

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

const LCG_MULT: int = 9301
const LCG_INC: int = 49297
const LCG_MOD: int = 233280

@export_group("Node References")
@export var telegraph_label: Label

@export_group("Cell Geometry")
@export_range(64.0, 256.0) var cell_size: float = 152.0:
	set(p_value):
		cell_size = p_value
		queue_redraw()
@export_range(10.0, 36.0) var stripe_spacing: float = 19.0

@export_group("Cutting-Room Palette")
@export var vellum_light_color: Color = Color(0.749, 0.737, 0.694, 1.0)    # #bfbcb1
@export var vellum_dark_color: Color = Color(0.714, 0.702, 0.659, 1.0)     # #b6b3a8
@export var projector_tint_color: Color = Color(0.788, 0.635, 0.353, 0.07) # #c9a25a @ 7%
@export var grid_rule_color: Color = Color(0.110, 0.114, 0.106, 0.20)
@export var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)             # #1c1d1b
@export var wall_body_color: Color = Color(0.165, 0.173, 0.165, 1.0)       # #2a2c2a
@export var wall_cap_color: Color = Color(0.353, 0.365, 0.333, 1.0)        # #5a5d55
@export var paper_hatch_color: Color = Color(0.902, 0.878, 0.820, 0.17)
@export var vermilion_color: Color = Color(0.761, 0.231, 0.169, 1.0)       # #c23b2b
@export var crimson_color: Color = Color(0.541, 0.149, 0.110, 1.0)         # #8a261c
@export var selected_plum_color: Color = Color(0.541, 0.408, 0.722, 1.0)   # #8a68b8

var _grid_position: Vector2i = Vector2i.ZERO
var _is_odd_tile: bool = false
var _terrain_mode: TerrainMode = TerrainMode.FLOOR
var _telegraph_mode: TelegraphMode = TelegraphMode.NONE
var _telegraph_dimmed: bool = false
var _telegraph_highlighted: bool = false
var _player_in_danger: bool = false
var _is_selected: bool = false


var grid_position: Vector2i:
	get: return _grid_position


func _process(_p_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _telegraph_mode == TelegraphMode.ACTIVE_WINDOW or _telegraph_mode == TelegraphMode.IMPACT:
		queue_redraw()


func setup_cell(p_grid_pos: Vector2i, p_world_pos: Vector2) -> void:
	_grid_position = p_grid_pos
	position = p_world_pos
	_is_odd_tile = ((p_grid_pos.x + p_grid_pos.y) % 2) != 0
	_terrain_mode = TerrainMode.FLOOR
	_telegraph_mode = TelegraphMode.NONE
	_telegraph_dimmed = false
	_telegraph_highlighted = false
	_player_in_danger = false
	_is_selected = false
	if telegraph_label != null:
		telegraph_label.visible = false
	queue_redraw()


func set_terrain(p_mode: TerrainMode) -> void:
	if _terrain_mode == p_mode:
		return
	_terrain_mode = p_mode
	queue_redraw()


func set_telegraph(
	p_mode: TelegraphMode,
	p_frame_text: String = "",
	p_dimmed: bool = false,
	p_highlighted: bool = false,
	p_player_in_danger: bool = false
) -> void:
	_telegraph_mode = p_mode
	_telegraph_dimmed = p_dimmed
	_telegraph_highlighted = p_highlighted
	_player_in_danger = p_player_in_danger

	if telegraph_label != null:
		var show_text: bool = (
			p_mode != TelegraphMode.NONE
			and _terrain_mode != TerrainMode.WALL
			and not p_frame_text.is_empty()
		)
		telegraph_label.visible = show_text
		if show_text:
			telegraph_label.text = p_frame_text
			var lbl_alpha: float = 0.35 if p_dimmed else 0.85
			telegraph_label.modulate = Color(crimson_color.r, crimson_color.g, crimson_color.b, lbl_alpha)
	queue_redraw()


func set_selected(p_selected: bool) -> void:
	if _is_selected == p_selected:
		return
	_is_selected = p_selected
	queue_redraw()


func _draw() -> void:
	var half: float = cell_size * 0.5
	var cell_rect: Rect2 = Rect2(Vector2(-half, -half), Vector2(cell_size, cell_size))

	# 1. Vellum Checkerboard + Paper Grain + Warm Act Tint + Ink Grid Rule
	var base_fill: Color = vellum_light_color if _is_odd_tile else vellum_dark_color
	draw_rect(cell_rect, base_fill, true)
	_draw_paper_grain(cell_rect)
	draw_rect(cell_rect, projector_tint_color, true)
	draw_rect(cell_rect, grid_rule_color, false, 1.0)

	# 2. Grease-Pencil Telegraph Stripes (drawn under walls/pits just like the HTML canvas)
	if _telegraph_mode != TelegraphMode.NONE and _terrain_mode != TerrainMode.WALL:
		_draw_grease_pencil_telegraph(cell_rect)

	# 3. Obstacles (Beveled Gunmetal Wall or Ink-Hatched Pit)
	if _terrain_mode == TerrainMode.WALL:
		_draw_wall_block(cell_rect)
	elif _terrain_mode == TerrainMode.PIT:
		_draw_pit_hazard(cell_rect)

	# 4. Selected Target Brackets
	if _is_selected:
		_draw_corner_brackets(cell_rect.grow(-4.0), selected_plum_color, 22.0, 3.5)


# --- Private Drawing Helpers ---

func _draw_paper_grain(p_rect: Rect2) -> void:
	var seed_val: int = _grid_position.x * 197 + _grid_position.y * 89 + 13
	var w: float = p_rect.size.x
	var h: float = p_rect.size.y

	# Fine ink speckles
	for _i: int in range(26):
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var rx: float = float(seed_val) / float(LCG_MOD)
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var ry: float = float(seed_val) / float(LCG_MOD)
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var ra: float = 0.04 + (float(seed_val) / float(LCG_MOD)) * 0.08
		draw_rect(
			Rect2(p_rect.position + Vector2(rx * (w - 3.0), ry * (h - 3.0)), Vector2(2.0, 1.5)),
			Color(ink_color.r, ink_color.g, ink_color.b, ra),
			true
		)

	# Subtle paper fibers / scratches
	for _i: int in range(3):
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var sx: float = 12.0 + (float(seed_val) / float(LCG_MOD)) * (w - 36.0)
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var sy: float = 12.0 + (float(seed_val) / float(LCG_MOD)) * (h - 24.0)
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var dx: float = ((float(seed_val) / float(LCG_MOD)) - 0.5) * 42.0
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var dy: float = ((float(seed_val) / float(LCG_MOD)) - 0.5) * 14.0
		var p0: Vector2 = p_rect.position + Vector2(sx, sy)
		draw_line(p0, p0 + Vector2(dx, dy), Color(ink_color.r, ink_color.g, ink_color.b, 0.07), 1.0, true)

	# Light cream paper flecks
	for _i: int in range(4):
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var fx: float = float(seed_val) / float(LCG_MOD)
		seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
		var fy: float = float(seed_val) / float(LCG_MOD)
		draw_rect(
			Rect2(p_rect.position + Vector2(fx * (w - 3.0), fy * (h - 3.0)), Vector2(2.0, 2.0)),
			Color(0.94, 0.92, 0.87, 0.14),
			true
		)


func _draw_wall_block(p_cell_rect: Rect2) -> void:
	var block_rect: Rect2 = Rect2(
		p_cell_rect.position + Vector2(15.0, 18.0),
		Vector2(p_cell_rect.size.x - 30.0, p_cell_rect.size.y - 30.0)
	)
	# Offset Ground Shadow
	draw_rect(
		Rect2(block_rect.position + Vector2(9.0, 9.0), block_rect.size),
		Color(ink_color.r, ink_color.g, ink_color.b, 0.30),
		true
	)

	# Main Gunmetal Body & Top Cap
	draw_rect(block_rect, wall_body_color, true)
	var cap_h: float = 34.0
	draw_rect(Rect2(block_rect.position, Vector2(block_rect.size.x, cap_h)), wall_cap_color, true)

	# Diagonal Cream Hatching on Lower Face
	var lower_rect: Rect2 = Rect2(
		Vector2(block_rect.position.x, block_rect.position.y + cap_h),
		Vector2(block_rect.size.x, block_rect.size.y - cap_h)
	)
	_draw_clipped_diagonal_stripes(lower_rect, paper_hatch_color, 22.0, 2.0, 0)

	# Bold Ink Outline
	draw_rect(block_rect, ink_color, false, 3.5)


func _draw_pit_hazard(p_cell_rect: Rect2) -> void:
	var pit_rect: Rect2 = p_cell_rect.grow(-8.0)
	draw_rect(pit_rect, ink_color, true)
	_draw_clipped_diagonal_stripes(pit_rect, paper_hatch_color, 17.0, 2.0, 0)
	draw_rect(pit_rect, ink_color, false, 3.5)


func _draw_grease_pencil_telegraph(p_cell_rect: Rect2) -> void:
	var inner_rect: Rect2 = p_cell_rect.grow(-4.0)
	var is_active: bool = (
		_telegraph_mode == TelegraphMode.ACTIVE_WINDOW
		or _telegraph_mode == TelegraphMode.IMPACT
	)
	var base_col: Color = crimson_color if _telegraph_mode == TelegraphMode.IMPACT else vermilion_color
	var dim_factor: float = 0.38 if _telegraph_dimmed else 1.0

	var pulse: float = 0.0
	if is_active and not Engine.is_editor_hint():
		pulse = 0.07 * sin(float(Time.get_ticks_msec()) / 130.0)

	var wash_alpha: float = clampf(
		((0.28 + pulse) if is_active else 0.08) * dim_factor + (0.08 if _telegraph_highlighted else 0.0),
		0.0,
		0.85
	)
	draw_rect(inner_rect, Color(base_col.r, base_col.g, base_col.b, wash_alpha), true)

	var stripe_alpha: float = clampf((0.92 if is_active else 0.62) * dim_factor, 0.0, 1.0)
	var stripe_col: Color = Color(base_col.r, base_col.g, base_col.b, stripe_alpha)
	var line_w: float = 4.2 if is_active else 3.0
	var jitter_seed: int = _grid_position.x * 131 + _grid_position.y * 71 + 7
	_draw_clipped_diagonal_stripes(inner_rect, stripe_col, stripe_spacing, line_w, jitter_seed)

	if _telegraph_highlighted:
		draw_rect(inner_rect.grow(-1.0), base_col, false, 3.0)
	if is_active and _player_in_danger:
		draw_rect(inner_rect.grow(-3.0), crimson_color, false, 5.0)


func _draw_clipped_diagonal_stripes(
	p_rect: Rect2,
	p_color: Color,
	p_spacing: float,
	p_width: float,
	p_jitter_seed: int
) -> void:
	var w: float = p_rect.size.x
	var h: float = p_rect.size.y
	var max_d: float = w + h
	var d: float = p_spacing * 0.45
	var seed_val: int = p_jitter_seed

	while d < max_d:
		var j1: float = 0.0
		var j2: float = 0.0
		if p_jitter_seed > 0:
			seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
			j1 = ((float(seed_val) / float(LCG_MOD)) - 0.5) * 6.0
			seed_val = (seed_val * LCG_MULT + LCG_INC) % LCG_MOD
			j2 = ((float(seed_val) / float(LCG_MOD)) - 0.5) * 6.0

		var u1: float = clampf(maxf(0.0, d - h) + j1, 0.0, w)
		var v1: float = clampf(d - maxf(0.0, d - h), 0.0, h)
		var u2: float = clampf(minf(w, d) + j2, 0.0, w)
		var v2: float = clampf(d - minf(w, d), 0.0, h)

		if Vector2(u1, v1).distance_to(Vector2(u2, v2)) > 4.0:
			draw_line(
				p_rect.position + Vector2(u1, v1),
				p_rect.position + Vector2(u2, v2),
				p_color,
				p_width,
				true
			)
		d += p_spacing


func _draw_corner_brackets(p_rect: Rect2, p_color: Color, p_len: float, p_width: float) -> void:
	var tl: Vector2 = p_rect.position
	@warning_ignore("shadowed_variable_base_class")
	var tr: Vector2 = Vector2(p_rect.end.x, p_rect.position.y)
	var br: Vector2 = p_rect.end
	var bl: Vector2 = Vector2(p_rect.position.x, p_rect.end.y)

	draw_line(tl, tl + Vector2(p_len, 0.0), p_color, p_width)
	draw_line(tl, tl + Vector2(0.0, p_len), p_color, p_width)
	draw_line(tr, tr + Vector2(-p_len, 0.0), p_color, p_width)
	draw_line(tr, tr + Vector2(0.0, p_len), p_color, p_width)
	draw_line(br, br + Vector2(-p_len, 0.0), p_color, p_width)
	draw_line(br, br + Vector2(0.0, -p_len), p_color, p_width)
	draw_line(bl, bl + Vector2(p_len, 0.0), p_color, p_width)
	draw_line(bl, bl + Vector2(0.0, -p_len), p_color, p_width)
