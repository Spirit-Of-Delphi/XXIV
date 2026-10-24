class_name EnemyIntentGenerator
extends RefCounted

## Start-of-take tactical AI service: resets per-take enemy statuses, moves unfrozen enemies
## according to their current EnemyTurnPattern, and schedules all telegraphed AttackIntents.


static func prepare_enemies_for_take(p_state: CombatState, p_config: CombatConfig) -> void:
	var player: PlayerState = p_state.player
	if not player.is_alive:
		return

	var perceived_target: Vector2i = player.perceived_start_position
	var max_frame: int = p_config.total_frames - 1

	for enemy: EnemyState in p_state.get_living_enemies():
		# Daze and Tag never carry across takes
		enemy.begin_take()

		if enemy.is_frozen:
			continue

		enemy.clear_attack_intents()

		var data: EnemyData = enemy.enemy_data
		if data == null:
			continue
		var pattern: EnemyTurnPattern = data.get_pattern_for_turn(enemy.pattern_turn_index)
		if pattern == null:
			continue

		# 1. Reposition up to pattern.move_steps tiles toward ideal range/alignment
		for step: int in range(pattern.move_steps):
			var next_pos: Vector2i = _choose_best_step(p_state, enemy, perceived_target, pattern.preferred_range)
			if next_pos == enemy.grid_position:
				break
			enemy.set_grid_position(next_pos)

		# 2. Face perceived target
		var facing: Types.Direction = Types.direction_toward(enemy.grid_position, perceived_target, enemy.direction)
		enemy.set_direction(facing)

		# 3. Schedule every distinct attack in this turn's pattern
		for atk: EnemyAttackData in pattern.attacks:
			if atk == null:
				continue
			var target_tiles: Array[Vector2i] = _build_target_tiles(p_state.board, enemy.grid_position, facing, atk)
			if target_tiles.is_empty():
				continue
			var start_f: int = clampi(atk.start_frame, 0, max_frame)
			var end_f: int = clampi(maxi(start_f, atk.end_frame), 0, max_frame)
			enemy.add_attack_intent(AttackIntent.new(start_f, end_f, target_tiles, atk.damage, atk.is_beam))

		enemy.advance_turn_pattern()


static func _choose_best_step(
	p_state: CombatState,
	p_enemy: EnemyState,
	p_target_pos: Vector2i,
	p_preferred_range: int
) -> Vector2i:
	var best_pos: Vector2i = p_enemy.grid_position
	var best_cost: int = _score_position(best_pos, p_target_pos, p_preferred_range)

	for dir: Types.Direction in Types.ALL_DIRECTIONS:
		var cand: Vector2i = p_enemy.grid_position + Types.to_vector(dir)
		if p_state.board.is_blocked(cand):
			continue
		if cand == p_state.player.grid_position or cand == p_target_pos:
			continue
		if p_state.get_enemy_at(cand) != null:
			continue

		var cand_cost: int = _score_position(cand, p_target_pos, p_preferred_range)
		if cand_cost < best_cost:
			best_cost = cand_cost
			best_pos = cand

	return best_pos


static func _score_position(p_pos: Vector2i, p_target_pos: Vector2i, p_preferred_range: int) -> int:
	var dx: int = absi(p_pos.x - p_target_pos.x)
	var dy: int = absi(p_pos.y - p_target_pos.y)
	var manhattan: int = dx + dy
	if p_preferred_range <= 1:
		return absi(manhattan - 1) * 10 + mini(dx, dy)
	return mini(dx, dy) * 20 + absi(manhattan - p_preferred_range) * 5


static func _build_target_tiles(
	p_board: BoardState,
	p_origin: Vector2i,
	p_facing: Types.Direction,
	p_atk: EnemyAttackData
) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if p_atk.is_beam:
		var step_vec: Vector2i = Types.to_vector(p_facing)
		for dist: int in range(1, p_atk.beam_max_range + 1):
			var beam_tile: Vector2i = p_origin + step_vec * dist
			if not p_board.is_in_bounds(beam_tile):
				break
			tiles.append(beam_tile)
		return tiles

	for north_offset: Vector2i in p_atk.local_offsets:
		var world_tile: Vector2i = p_origin + Types.rotate_north_offset(north_offset, p_facing)
		if p_board.is_in_bounds(world_tile):
			tiles.append(world_tile)
	return tiles
