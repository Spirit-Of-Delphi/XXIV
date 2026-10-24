class_name ArenaView
extends Node2D

## Scene-backed 2D Tactical Arena view.
## Renders either the Planning Overview or any discrete frame snapshot (0..23) identically.

signal tile_clicked(p_grid_pos: Vector2i)
signal enemy_clicked(p_enemy_id: int)

const OVERVIEW_FRAME: int = -1
const HALF_TILE_OFFSET: float = 0.5

@export_group("Packed Scenes")
@export var tile_view_scene: PackedScene
@export var actor_view_scene: PackedScene

@export_group("Node References")
@export var tiles_container: Node2D
@export var trajectory_line: Line2D
@export var decoy_marker: Node2D
@export var ghost_marker: Node2D
@export var actors_container: Node2D

@export_group("Grid Layout")
@export_range(32.0, 256.0) var tile_pitch: float = 72.0

var _built_grid_size: int = 0
var _tile_views: Dictionary[Vector2i, TileView] = {}
var _player_view: ActorView = null
var _enemy_views: Dictionary[int, ActorView] = {}
var _displayed_state: CombatState = null
var _selected_enemy_id: int = -1


## Renders the start-of-take board plus the 24-frame trajectory path and end-of-take player ghost.
func render_planning_overview(p_base_state: CombatState, p_preview: SimulationResult) -> void:
	if p_base_state == null:
		return
	_displayed_state = p_base_state
	_ensure_grid_built(p_base_state.board.grid_size)
	_sync_terrain_and_selection(p_base_state)
	_sync_telegraphs(p_base_state, OVERVIEW_FRAME)
	_sync_actors(p_base_state)
	_sync_decoy_marker(p_base_state.player, true)
	_sync_trajectory_and_ghost(p_base_state, p_preview, true)


## Renders a specific frame (0..23) during timeline scrubbing (p_preview != null) or 24-FPS playback (p_preview == null).
func render_frame_snapshot(
	p_snapshot: CombatState,
	p_frame: int,
	p_preview: SimulationResult = null
) -> void:
	if p_snapshot == null:
		return
	_displayed_state = p_snapshot
	_ensure_grid_built(p_snapshot.board.grid_size)
	_sync_terrain_and_selection(p_snapshot)
	_sync_telegraphs(p_snapshot, p_frame)
	_sync_actors(p_snapshot)
	_sync_decoy_marker(p_snapshot.player, false)
	_sync_trajectory_and_ghost(p_snapshot, p_preview, false)


func set_selected_enemy_id(p_enemy_id: int) -> void:
	_selected_enemy_id = p_enemy_id
	if _displayed_state != null:
		_sync_terrain_and_selection(_displayed_state)


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
	if p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var grid_pos: Vector2i = local_to_grid(get_local_mouse_position())
			if _displayed_state.board.is_in_bounds(grid_pos):
				tile_clicked.emit(grid_pos)
				var clicked_enemy: EnemyState = _displayed_state.get_enemy_at(grid_pos)
				if clicked_enemy != null:
					enemy_clicked.emit(clicked_enemy.id)


# --- Private Synchronization Helpers ---

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
	var best_mode: Dictionary[Vector2i, TileView.TelegraphMode] = {}
	var frame_tags: Dictionary[Vector2i, Array] = {}

	for enemy: EnemyState in p_state.get_living_enemies():
		if enemy.is_frozen or enemy.is_dazed:
			continue
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
				if not frame_tags.has(tile):
					frame_tags[tile] = []
				var tags_for_tile: Array = frame_tags[tile]
				if not tags_for_tile.has(impact_tag):
					tags_for_tile.append(impact_tag)

	for coord: Vector2i in _tile_views.keys():
		var cell: TileView = _tile_views[coord]
		var tile_mode: TileView.TelegraphMode = best_mode.get(coord, TileView.TelegraphMode.NONE) as TileView.TelegraphMode
		var label_str: String = ""
		if frame_tags.has(coord):
			label_str = ",".join(PackedStringArray(frame_tags[coord]))
		cell.set_telegraph(tile_mode, label_str)


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


func _sync_actors(p_state: CombatState) -> void:
	if actor_view_scene == null or actors_container == null:
		return

	if _player_view == null:
		_player_view = actor_view_scene.instantiate() as ActorView
		actors_container.add_child(_player_view)
	_player_view.bind_player(p_state.player, grid_to_local(p_state.player.grid_position))

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


func _sync_decoy_marker(p_player: PlayerState, p_is_overview: bool) -> void:
	if decoy_marker == null:
		return
	if p_player.has_decoy:
		decoy_marker.visible = true
		decoy_marker.position = grid_to_local(p_player.decoy_position)
	elif not p_is_overview and p_player.enemy_target_position != p_player.take_start_position:
		decoy_marker.visible = true
		decoy_marker.position = grid_to_local(p_player.enemy_target_position)
	else:
		decoy_marker.visible = false


func _sync_trajectory_and_ghost(
	p_state: CombatState,
	p_preview: SimulationResult,
	p_show_end_ghost: bool
) -> void:
	if trajectory_line != null:
		if p_preview == null:
			trajectory_line.clear_points()
			trajectory_line.visible = false
		else:
			var points: PackedVector2Array = PackedVector2Array()
			points.append(grid_to_local(p_preview.initial_state.player.grid_position))
			for step_tile: Vector2i in p_preview.get_player_trajectory():
				var world_pt: Vector2 = grid_to_local(step_tile)
				if points[points.size() - 1] != world_pt:
					points.append(world_pt)
			trajectory_line.points = points
			trajectory_line.visible = points.size() > 1

	if ghost_marker != null:
		if p_show_end_ghost and p_preview != null:
			var end_pos: Vector2i = p_preview.final_state.player.grid_position
			ghost_marker.visible = end_pos != p_state.player.grid_position
			ghost_marker.position = grid_to_local(end_pos)
		else:
			ghost_marker.visible = false
