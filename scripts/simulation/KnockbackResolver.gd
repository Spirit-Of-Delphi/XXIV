class_name KnockbackResolver
extends RefCounted

## Single-responsibility helper for pushing an actor across the grid.
## Resolves solid wall/actor slams and pit hazard eliminations.


static func apply(
	p_state: CombatState,
	p_target: EnemyState,
	p_dir: Types.Direction,
	p_distance: int,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var step_vec: Vector2i = Types.to_vector(p_dir)
	for step: int in range(p_distance):
		if not p_target.is_alive:
			return
		var next_pos: Vector2i = p_target.grid_position + step_vec

		var occupied_by_actor: bool = (
			p_state.get_enemy_at(next_pos) != null
			or (p_state.player.is_alive and p_state.player.grid_position == next_pos)
		)

		# 1. Blocked by wall, arena edge, or another actor -> Wall Slam!
		if p_state.board.is_solid(next_pos) or occupied_by_actor:
			if p_config.wall_slam_damage > 0:
				p_events.append(CombatEvent.new(
					CombatEvent.Type.WALL_SLAM, p_frame, p_target.id,
					p_target.grid_position, p_config.wall_slam_damage
				))
				CombatEvent.record_damage(
					p_target, p_config.wall_slam_damage, p_frame,
					p_target.grid_position, "WALL_SLAM", p_events
				)
			return

		# 2. Pit Hazard -> Instant elimination!
		if p_state.board.is_pit(next_pos):
			p_target.set_grid_position(next_pos)
			p_target.kill()
			p_events.append(CombatEvent.new(
				CombatEvent.Type.PIT_ELIMINATION, p_frame, p_target.id, next_pos
			))
			return

		# 3. Open Tile -> Move 1 tile
		p_target.set_grid_position(next_pos)
		p_target.shift_attack_intents(step_vec)
		p_events.append(CombatEvent.new(
			CombatEvent.Type.KNOCKBACK_MOVED, p_frame, p_target.id, next_pos
		))
