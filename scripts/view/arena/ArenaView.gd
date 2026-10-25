class_name ArenaView
extends Node2D

## Cutting-Room 2D Tactical Arena.
## Coordinates the 6x6 vellum grid, hover-isolated telegraphs, cobalt motion afterimages,
## numbered step-frame badges, strike crosshairs, and clickable on-board WASD / Pick aiming.

signal tile_clicked(p_grid_pos: Vector2i)
signal enemy_clicked(p_enemy_id: int)
signal direction_aimed(p_direction: Types.Direction)

const OVERVIEW_FRAME: int = -1
const HALF_TILE_OFFSET: float = 0.5
const MAX_AFTERIMAGES: int = 6
const COMPASS_KEYS: Array[String] = ["W", "D", "S", "A"]

@export_group("Packed Scenes")
@export var tile_view_scene: PackedScene
@export var actor_view_scene: PackedScene

@export_group("Node References")
@export var tiles_container: Node2D
@export var actors_container: Node2D

@export_group("Grid Layout")
@export_range(64.0, 256.0) var tile_pitch: float = 152.0

@export_group("Cutting-Room Palette")
@export var paper_stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)    # #e6e0d1
@export var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)            # #1c1d1b
@export var cobalt_color: Color = Color(0.290, 0.447, 0.784, 1.0)         # #4a72c8
@export var vermilion_color: Color = Color(0.761, 0.231, 0.169, 1.0)      # #c23b2b
@export var gold_cut_color: Color = Color(0.941, 0.863, 0.333, 1.0)       # #f0dc55
@export var plum_pick_color: Color = Color(0.541, 0.408, 0.722, 1.0)      # #8a68b8

var _built_grid_size: int = 0
var _tile_views: Dictionary[Vector2i, TileView] = {}
var _player_view: ActorView = null
var _enemy_views: Dictionary[int, ActorView] = {}

var _under_overlay: Node2D = null
var _over_overlay: Node2D = null

var _displayed_state: CombatState = null
var _displayed_frame: int = OVERVIEW_FRAME
var _active_preview: SimulationResult = null
var _is_planning_view: bool = true

var _selected_enemy_id: int = -1
var _board_hovered_enemy_id: int = -1
var _external_hovered_enemy_id: int = -1
var _aim_card: CardData = null
var _aim_direction: Types.Direction = Types.Direction.NORTH
var _aim_origin_override: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	if tiles_container != null:
		tiles_container.z_index = 0
	if actors_container != null:
		actors_container.z_index = 3

	_under_overlay = Node2D.new()
	_under_overlay.name = "UnderActorOverlay"
	_under_overlay.z_index = 1
	add_child(_under_overlay)
	_under_overlay.draw.connect(_on_draw_under_overlay)

	_over_overlay = Node2D.new()
	_over_overlay.name = "OverActorOverlay"
	_over_overlay.z_index = 10
	add_child(_over_overlay)
	_over_overlay.draw.connect(_on_draw_over_overlay)


func _process(_p_delta: float) -> void:
	if _aim_card != null and _over_overlay != null:
		_over_overlay.queue_redraw()


func render_planning_overview(p_base_state: CombatState, p_preview: SimulationResult) -> void:
	if p_base_state == null:
		return
	var display_state: CombatState = p_preview.final_state if p_preview != null else p_base_state
	_displayed_state = display_state
	_displayed_frame = OVERVIEW_FRAME
	_active_preview = p_preview
	_is_planning_view = true

	_ensure_grid_built(p_base_state.board.grid_size)
	_sync_terrain_and_selection(p_base_state)
	_sync_telegraphs(p_base_state, OVERVIEW_FRAME)
	_sync_actors_with_overview(p_base_state, display_state.player)
	_redraw_overlays()


func render_frame_snapshot(
	p_snapshot: CombatState,
	p_frame: int,
	p_preview: SimulationResult = null,
	p_is_planning: bool = true
) -> void:
	if p_snapshot == null:
		return
	_displayed_state = p_snapshot
	_displayed_frame = p_frame
	_active_preview = p_preview
	_is_planning_view = p_is_planning

	_ensure_grid_built(p_snapshot.board.grid_size)
	_sync_terrain_and_selection(p_snapshot)
	_sync_telegraphs(p_snapshot, p_frame)
	_sync_actors(p_snapshot)
	_redraw_overlays()


func set_selected_enemy_id(p_enemy_id: int) -> void:
	_selected_enemy_id = p_enemy_id
	if _displayed_state != null:
		_sync_terrain_and_selection(_displayed_state)
	_redraw_overlays()


func set_external_hovered_enemy_id(p_enemy_id: int) -> void:
	if _external_hovered_enemy_id == p_enemy_id:
		return
	_external_hovered_enemy_id = p_enemy_id
	_refresh_hover_telegraphs()


func set_aiming_context(
	p_card: CardData,
	p_direction: Types.Direction,
	p_target_enemy_id: int,
	p_origin_tile: Vector2i = Vector2i(-1, -1)
) -> void:
	_aim_card = p_card
	_aim_direction = p_direction
	_aim_origin_override = p_origin_tile
	set_selected_enemy_id(p_target_enemy_id if (p_card != null and p_card.requires_enemy_target()) else -1)
	_redraw_overlays()


func grid_to_local(p_grid_pos: Vector2i) -> Vector2:
	return Vector2(
		(float(p_grid_pos.x) + HALF_TILE_OFFSET) * tile_pitch,
		(float(p_grid_pos.y) + HALF_TILE_OFFSET) * tile_pitch
	)


func local_to_grid(p_local_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(p_local_pos.x / tile_pitch),
		floori(p_local_pos.y / tile_pitch)
	)


func _unhandled_input(p_event: InputEvent) -> void:
	if _displayed_state == null:
		return

	if p_event is InputEventMouseMotion:
		var hover_grid: Vector2i = local_to_grid(get_local_mouse_position())
		var next_hover_id: int = -1
		var lookup_state: CombatState = (
			_active_preview.initial_state
			if (_displayed_frame == OVERVIEW_FRAME and _active_preview != null)
			else _displayed_state
		)
		if lookup_state.board.is_in_bounds(hover_grid):
			var hov_enemy: EnemyState = lookup_state.get_enemy_at(hover_grid)
			if hov_enemy != null and hov_enemy.is_alive:
				next_hover_id = hov_enemy.id
		if next_hover_id != _board_hovered_enemy_id:
			_board_hovered_enemy_id = next_hover_id
			_refresh_hover_telegraphs()

	elif p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var click_grid: Vector2i = local_to_grid(get_local_mouse_position())
			if not _displayed_state.board.is_in_bounds(click_grid):
				return

			tile_clicked.emit(click_grid)
			var click_state: CombatState = (
				_active_preview.initial_state
				if (_displayed_frame == OVERVIEW_FRAME and _active_preview != null)
				else _displayed_state
			)
			var clicked_enemy: EnemyState = click_state.get_enemy_at(click_grid)
			if clicked_enemy != null and clicked_enemy.is_alive:
				enemy_clicked.emit(clicked_enemy.id)

			if _is_planning_view and _aim_card != null and _aim_card.requires_cardinal_direction():
				var origin: Vector2i = _get_aim_origin_tile()
				if click_grid != origin:
					var aimed_dir: Types.Direction = Types.direction_toward(origin, click_grid, _aim_direction)
					direction_aimed.emit(aimed_dir)


# --- Overlay Renderers ---

func _redraw_overlays() -> void:
	if _under_overlay != null:
		_under_overlay.queue_redraw()
	if _over_overlay != null:
		_over_overlay.queue_redraw()


func _refresh_hover_telegraphs() -> void:
	if _displayed_state == null:
		return
	var tele_state: CombatState = (
		_active_preview.initial_state
		if (_displayed_frame == OVERVIEW_FRAME and _active_preview != null)
		else _displayed_state
	)
	_sync_telegraphs(tele_state, _displayed_frame)


func _get_effective_hovered_enemy_id() -> int:
	if _board_hovered_enemy_id != -1:
		return _board_hovered_enemy_id
	return _external_hovered_enemy_id


func _on_draw_under_overlay() -> void:
	if _displayed_state == null or _under_overlay == null:
		return

	# 1. Optical Decoy Silhouette
	var player_ref: PlayerState = _displayed_state.player
	if player_ref.has_decoy:
		ActorFigureRenderer.draw_subject_24(
			_under_overlay,
			grid_to_local(player_ref.decoy_position) + Vector2(0.0, 6.0),
			player_ref.direction,
			ActorView.FIGURE_BASE_SCALE,
			Color(plum_pick_color.r, plum_pick_color.g, plum_pick_color.b, 0.32),
			Color(plum_pick_color.r, plum_pick_color.g, plum_pick_color.b, 0.78),
			plum_pick_color,
			false
		)

	if _active_preview == null:
		return

	# 2. Dashed Cobalt Trajectory Line (Planning & Scrubbing)
	if _is_planning_view:
		var waypoints: Array[Dictionary] = _collect_step_waypoints(_active_preview)
		if waypoints.size() > 1:
			for i: int in range(waypoints.size() - 1):
				var p0: Vector2 = grid_to_local(waypoints[i]["pos"] as Vector2i) + Vector2(0.0, 6.0)
				var p1: Vector2 = grid_to_local(waypoints[i + 1]["pos"] as Vector2i) + Vector2(0.0, 6.0)
				_draw_dashed_line(_under_overlay, p0, p1, Color(cobalt_color.r, cobalt_color.g, cobalt_color.b, 0.82), 4.0, 10.0, 10.0)

	# 3. Translucent Cobalt-Blue Subject #24 Motion Afterimages
	_draw_cobalt_afterimages()


func _on_draw_over_overlay() -> void:
	if _displayed_state == null or _over_overlay == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	# 1. Step Waypoint Frame Badges (0, 2, 4) & Strike Crosshairs / Match Cut Tags
	if _is_planning_view and _active_preview != null:
		var waypoints: Array[Dictionary] = _collect_step_waypoints(_active_preview)
		if waypoints.size() > 1:
			for wp: Dictionary in waypoints:
				var wp_pos: Vector2i = wp["pos"] as Vector2i
				var wp_frame: int = wp["frame"] as int
				var badge_center: Vector2 = grid_to_local(wp_pos) + Vector2(38.0, 38.0)
				_over_overlay.draw_circle(badge_center, 15.0, paper_stock_color)
				_over_overlay.draw_arc(badge_center, 15.0, 0.0, TAU, 24, cobalt_color, 3.0, true)
				_draw_centered_string(_over_overlay, font, badge_center, "%d" % wp_frame, 13, ink_color)

		_draw_planned_strike_markers(font)

	# 2. Interactive On-Board Aiming Compass (W/D/S/A) or Enemy 'pick' Badges
	if _is_planning_view and _aim_card != null:
		if _aim_card.requires_enemy_target():
			_draw_enemy_pick_badges(font)
		elif _aim_card.requires_cardinal_direction():
			_draw_cardinal_aim_compass(font)


func _draw_cobalt_afterimages() -> void:
	if _active_preview == null or _under_overlay == null:
		return

	if _displayed_frame == OVERVIEW_FRAME:
		var waypoints: Array[Dictionary] = _collect_step_waypoints(_active_preview)
		if waypoints.size() <= 1:
			return
		var final_pos: Vector2i = _displayed_state.player.grid_position
		var count: int = mini(waypoints.size() - 1, MAX_AFTERIMAGES)
		var start_idx: int = waypoints.size() - 1 - count
		for idx: int in range(start_idx, waypoints.size() - 1):
			var wp_pos: Vector2i = waypoints[idx]["pos"] as Vector2i
			if wp_pos == final_pos:
				continue
			var wp_dir: Types.Direction = waypoints[idx]["dir"] as Types.Direction
			var alpha: float = 0.18 + 0.06 * float(idx - start_idx)
			var ghost_col: Color = Color(cobalt_color.r, cobalt_color.g, cobalt_color.b, alpha)
			ActorFigureRenderer.draw_subject_24(
				_under_overlay,
				grid_to_local(wp_pos) + Vector2(0.0, 6.0),
				wp_dir,
				ActorView.FIGURE_BASE_SCALE,
				ghost_col,
				ghost_col,
				ghost_col,
				false
			)
	elif _displayed_frame > 0:
		var cur_pos: Vector2i = _displayed_state.player.grid_position
		var first_f: int = maxi(0, _displayed_frame - MAX_AFTERIMAGES)
		var seen_tiles: Array[Vector2i] = []
		for f: int in range(first_f, _displayed_frame):
			var prev_snap: CombatState = _active_preview.get_snapshot(f)
			var p_pos: Vector2i = prev_snap.player.grid_position
			if p_pos == cur_pos or seen_tiles.has(p_pos):
				continue
			seen_tiles.append(p_pos)
			var step_k: int = f - first_f
			var alpha: float = 0.10 + 0.06 * float(step_k)
			var ghost_col: Color = Color(cobalt_color.r, cobalt_color.g, cobalt_color.b, alpha)
			ActorFigureRenderer.draw_subject_24(
				_under_overlay,
				grid_to_local(p_pos) + Vector2(0.0, 6.0),
				prev_snap.player.direction,
				ActorView.FIGURE_BASE_SCALE,
				ghost_col,
				ghost_col,
				ghost_col,
				false
			)


func _draw_planned_strike_markers(p_font: Font) -> void:
	for ev: CombatEvent in _active_preview.events:
		if ev.type == CombatEvent.Type.STRIKE_SWUNG:
			if not _displayed_state.board.is_in_bounds(ev.grid_position):
				continue
			var center: Vector2 = grid_to_local(ev.grid_position) + Vector2(0.0, 6.0)
			var is_flow: bool = _active_preview.has_event_type(CombatEvent.Type.FLOW_TRIGGERED, ev.frame)
			var mark_col: Color = cobalt_color if is_flow else ink_color
			_over_overlay.draw_line(center + Vector2(-13.0, -13.0), center + Vector2(13.0, 13.0), mark_col, 4.0, true)
			_over_overlay.draw_line(center + Vector2(13.0, -13.0), center + Vector2(-13.0, 13.0), mark_col, 4.0, true)
			_draw_centered_string(_over_overlay, p_font, center + Vector2(0.0, -24.0), "%d" % ev.frame, 13, mark_col)
		elif ev.type == CombatEvent.Type.MATCH_CUT_TRIGGERED:
			var tag_center: Vector2 = grid_to_local(ev.grid_position) + Vector2(0.0, -48.0)
			var pill_rect: Rect2 = Rect2(tag_center - Vector2(24.0, 11.0), Vector2(48.0, 22.0))
			_over_overlay.draw_rect(pill_rect, gold_cut_color, true)
			_over_overlay.draw_rect(pill_rect, ink_color, false, 1.5)
			_draw_centered_string(_over_overlay, p_font, tag_center, "cut", 13, ink_color)


func _draw_enemy_pick_badges(p_font: Font) -> void:
	var pulse: float = 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 160.0)
	var ring_col: Color = Color(plum_pick_color.r, plum_pick_color.g, plum_pick_color.b, pulse)
	var pick_state: CombatState = (
		_active_preview.initial_state
		if (_displayed_frame == OVERVIEW_FRAME and _active_preview != null)
		else _displayed_state
	)
	for enemy: EnemyState in pick_state.get_living_enemies():
		if _aim_card.requires_frozen_enemy_target() and not enemy.is_frozen:
			continue
		var t_center: Vector2 = grid_to_local(enemy.grid_position)
		var r: Rect2 = Rect2(t_center - Vector2(tile_pitch * 0.5 - 4.0, tile_pitch * 0.5 - 4.0), Vector2(tile_pitch - 8.0, tile_pitch - 8.0))
		_draw_dashed_rect(_over_overlay, r, ring_col, 3.5, 10.0, 7.0)
		var pill_center: Vector2 = t_center + Vector2(0.0, tile_pitch * 0.5 - 16.0)
		var pill: Rect2 = Rect2(pill_center - Vector2(34.0, 11.0), Vector2(68.0, 22.0))
		_over_overlay.draw_rect(pill, plum_pick_color, true)
		_draw_centered_string(_over_overlay, p_font, pill_center, "pick", 13, paper_stock_color)


func _draw_cardinal_aim_compass(p_font: Font) -> void:
	var origin: Vector2i = _get_aim_origin_tile()
	var origin_px: Vector2 = grid_to_local(origin)
	var board_px: float = float(_displayed_state.board.grid_size) * tile_pitch
	var enemy_lookup: CombatState = (
		_active_preview.initial_state
		if (_displayed_frame == OVERVIEW_FRAME and _active_preview != null)
		else _displayed_state
	)

	for i: int in range(Types.ALL_DIRECTIONS.size()):
		var dir_enum: Types.Direction = Types.ALL_DIRECTIONS[i]
		var step_vec: Vector2i = Types.to_vector(dir_enum)
		var adj_tile: Vector2i = origin + step_vec
		var is_chosen: bool = (dir_enum == _aim_direction)
		var has_enemy: bool = (
			enemy_lookup.board.is_in_bounds(adj_tile)
			and enemy_lookup.get_enemy_at(adj_tile) != null
		)
		var accent: Color = gold_cut_color if is_chosen else (vermilion_color if has_enemy else cobalt_color)

		if enemy_lookup.board.is_in_bounds(adj_tile):
			var adj_center: Vector2 = grid_to_local(adj_tile)
			var adj_rect: Rect2 = Rect2(
				adj_center - Vector2(tile_pitch * 0.5 - 6.0, tile_pitch * 0.5 - 6.0),
				Vector2(tile_pitch - 12.0, tile_pitch - 12.0)
			)
			_over_overlay.draw_rect(adj_rect, Color(accent.r, accent.g, accent.b, 0.16 if is_chosen else 0.08), true)
			_draw_dashed_rect(_over_overlay, adj_rect, accent, 3.0 if is_chosen else 2.0, 9.0, 7.0)

		var badge_pos: Vector2 = origin_px + Vector2(step_vec) * (tile_pitch * 0.68)
		badge_pos.x = clampf(badge_pos.x, 24.0, board_px - 24.0)
		badge_pos.y = clampf(badge_pos.y, 24.0, board_px - 24.0)
		_over_overlay.draw_circle(badge_pos, 18.0, ink_color)
		_over_overlay.draw_arc(badge_pos, 18.0, 0.0, TAU, 24, accent, 3.0 if is_chosen else 2.0, true)
		_draw_centered_string(
			_over_overlay,
			p_font,
			badge_pos,
			COMPASS_KEYS[i],
			14,
			gold_cut_color if is_chosen else paper_stock_color
		)


# --- Synchronization & Math Helpers ---

func _get_aim_origin_tile() -> Vector2i:
	if _displayed_state != null and _displayed_state.board.is_in_bounds(_aim_origin_override):
		return _aim_origin_override
	if _active_preview != null:
		return _active_preview.final_state.player.grid_position
	return _displayed_state.player.grid_position


func _collect_step_waypoints(p_preview: SimulationResult) -> Array[Dictionary]:
	var pts: Array[Dictionary] = []
	var start_p: PlayerState = p_preview.initial_state.player
	var last_pos: Vector2i = start_p.grid_position
	pts.append({"pos": last_pos, "frame": 0, "dir": start_p.direction})

	for f: int in range(p_preview.total_frames):
		var snap_p: PlayerState = p_preview.get_snapshot(f).player
		if snap_p.grid_position != last_pos:
			last_pos = snap_p.grid_position
			pts.append({"pos": last_pos, "frame": f, "dir": snap_p.direction})
	return pts


func _ensure_grid_built(p_grid_size: int) -> void:
	if _built_grid_size == p_grid_size or tile_view_scene == null or tiles_container == null:
		return

	for old_tile: TileView in _tile_views.values():
		old_tile.queue_free()
	_tile_views.clear()

	for y: int in range(p_grid_size):
		for x: int in range(p_grid_size):
			var coord: Vector2i = Vector2i(x, y)
			var cell: TileView = tile_view_scene.instantiate() as TileView
			tiles_container.add_child(cell)
			cell.setup_cell(coord, grid_to_local(coord))
			_tile_views[coord] = cell

	_built_grid_size = p_grid_size


func _sync_terrain_and_selection(p_state: CombatState) -> void:
	var board: BoardState = p_state.board
	var selected_enemy: EnemyState = p_state.get_enemy_by_id(_selected_enemy_id)
	var has_selected_tile: bool = selected_enemy != null and selected_enemy.is_alive

	for coord: Vector2i in _tile_views.keys():
		var cell: TileView = _tile_views[coord]
		if board.is_wall(coord):
			cell.set_terrain(TileView.TerrainMode.WALL)
		elif board.is_pit(coord):
			cell.set_terrain(TileView.TerrainMode.PIT)
		else:
			cell.set_terrain(TileView.TerrainMode.FLOOR)
		cell.set_selected(has_selected_tile and selected_enemy.grid_position == coord)


func _sync_telegraphs(p_state: CombatState, p_frame: int) -> void:
	var hov_id: int = _get_effective_hovered_enemy_id()
	var best_mode: Dictionary[Vector2i, TileView.TelegraphMode] = {}
	var frame_tags: Dictionary[Vector2i, Array] = {}
	var has_hovered_source: Dictionary[Vector2i, bool] = {}
	var has_unhovered_only: Dictionary[Vector2i, bool] = {}

	for enemy: EnemyState in p_state.get_living_enemies():
		if enemy.is_frozen or enemy.is_dazed:
			continue
		var is_hov_enemy: bool = (hov_id != -1 and enemy.id == hov_id)
		var is_other_enemy: bool = (hov_id != -1 and enemy.id != hov_id)

		for intent: AttackIntent in enemy.attack_intents:
			if p_frame != OVERVIEW_FRAME and intent.end_frame < p_frame:
				continue

			var mode: TileView.TelegraphMode = TileView.TelegraphMode.UPCOMING
			if p_frame != OVERVIEW_FRAME:
				if intent.end_frame == p_frame:
					mode = TileView.TelegraphMode.IMPACT
				elif intent.is_active_on(p_frame):
					mode = TileView.TelegraphMode.ACTIVE_WINDOW

			var effective_tiles: Array[Vector2i] = _collect_effective_intent_tiles(p_state, intent)
			var impact_tag: String = "f%d" % intent.end_frame
			for tile: Vector2i in effective_tiles:
				var prev: TileView.TelegraphMode = best_mode.get(tile, TileView.TelegraphMode.NONE) as TileView.TelegraphMode
				if int(mode) > int(prev):
					best_mode[tile] = mode
				if is_hov_enemy:
					has_hovered_source[tile] = true
					has_unhovered_only[tile] = false
				elif is_other_enemy and not has_hovered_source.get(tile, false):
					has_unhovered_only[tile] = true

				if not frame_tags.has(tile):
					frame_tags[tile] = []
				var tags_for_tile: Array = frame_tags[tile]
				if not tags_for_tile.has(impact_tag):
					tags_for_tile.append(impact_tag)

	var player_pos: Vector2i = _displayed_state.player.grid_position if _displayed_state != null else Vector2i(-1, -1)
	for coord: Vector2i in _tile_views.keys():
		var cell: TileView = _tile_views[coord]
		var tile_mode: TileView.TelegraphMode = best_mode.get(coord, TileView.TelegraphMode.NONE) as TileView.TelegraphMode
		var label_str: String = ""
		if frame_tags.has(coord):
			label_str = ",".join(PackedStringArray(frame_tags[coord]))
		cell.set_telegraph(
			tile_mode,
			label_str,
			has_unhovered_only.get(coord, false),
			has_hovered_source.get(coord, false),
			coord == player_pos
		)


func _collect_effective_intent_tiles(p_state: CombatState, p_intent: AttackIntent) -> Array[Vector2i]:
	if not p_intent.is_beam:
		return p_intent.target_tiles
	var effective: Array[Vector2i] = []
	for tile: Vector2i in p_intent.target_tiles:
		if p_state.board.is_solid(tile):
			break
		effective.append(tile)
		var blocker: EnemyState = p_state.get_enemy_at(tile)
		if blocker != null and blocker.is_frozen:
			break
	return effective


func _sync_actors_with_overview(p_base_state: CombatState, p_end_player: PlayerState) -> void:
	if actor_view_scene == null or actors_container == null:
		return
	if _player_view == null:
		_player_view = actor_view_scene.instantiate() as ActorView
		actors_container.add_child(_player_view)
	_player_view.bind_player(p_end_player, grid_to_local(p_end_player.grid_position))
	_sync_enemy_actors(p_base_state)


func _sync_actors(p_state: CombatState) -> void:
	if actor_view_scene == null or actors_container == null:
		return
	if _player_view == null:
		_player_view = actor_view_scene.instantiate() as ActorView
		actors_container.add_child(_player_view)
	_player_view.bind_player(p_state.player, grid_to_local(p_state.player.grid_position))
	_sync_enemy_actors(p_state)


func _sync_enemy_actors(p_state: CombatState) -> void:
	var active_ids: Array[int] = []
	for enemy: EnemyState in p_state.enemies:
		active_ids.append(enemy.id)
		var e_view: ActorView = _enemy_views.get(enemy.id, null) as ActorView
		if e_view == null:
			e_view = actor_view_scene.instantiate() as ActorView
			actors_container.add_child(e_view)
			_enemy_views[enemy.id] = e_view
		e_view.bind_enemy(enemy, grid_to_local(enemy.grid_position))

	var stale_ids: Array[int] = []
	for existing_id: int in _enemy_views.keys():
		if not active_ids.has(existing_id):
			stale_ids.append(existing_id)
	for stale_id: int in stale_ids:
		var stale_view: ActorView = _enemy_views[stale_id]
		stale_view.queue_free()
		_enemy_views.erase(stale_id)


func _draw_dashed_rect(
	p_canvas: CanvasItem,
	p_rect: Rect2,
	p_color: Color,
	p_width: float,
	p_dash: float,
	p_gap: float
) -> void:
	var tl: Vector2 = p_rect.position
	var tr: Vector2 = Vector2(p_rect.end.x, p_rect.position.y)
	var br: Vector2 = p_rect.end
	var bl: Vector2 = Vector2(p_rect.position.x, p_rect.end.y)
	_draw_dashed_line(p_canvas, tl, tr, p_color, p_width, p_dash, p_gap)
	_draw_dashed_line(p_canvas, tr, br, p_color, p_width, p_dash, p_gap)
	_draw_dashed_line(p_canvas, br, bl, p_color, p_width, p_dash, p_gap)
	_draw_dashed_line(p_canvas, bl, tl, p_color, p_width, p_dash, p_gap)


func _draw_dashed_line(
	p_canvas: CanvasItem,
	p_from: Vector2,
	p_to: Vector2,
	p_color: Color,
	p_width: float,
	p_dash: float,
	p_gap: float
) -> void:
	var total: float = p_from.distance_to(p_to)
	if total <= 0.5:
		return
	var dir: Vector2 = (p_to - p_from) / total
	var dist: float = 0.0
	var step: float = maxf(2.0, p_dash + p_gap)
	while dist < total:
		var seg_end: float = minf(dist + p_dash, total)
		p_canvas.draw_line(p_from + dir * dist, p_from + dir * seg_end, p_color, p_width, true)
		dist += step


func _draw_centered_string(
	p_canvas: CanvasItem,
	p_font: Font,
	p_center: Vector2,
	p_text: String,
	p_font_size: int,
	p_color: Color
) -> void:
	var box_w: float = 64.0
	var ascent: float = p_font.get_ascent(p_font_size)
	var descent: float = p_font.get_descent(p_font_size)
	var baseline_y: float = p_center.y + (ascent - descent) * 0.5
	p_canvas.draw_string(
		p_font,
		Vector2(p_center.x - box_w * 0.5, baseline_y),
		p_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		box_w,
		p_font_size,
		p_color
	)
