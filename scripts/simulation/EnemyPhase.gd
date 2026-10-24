class_name EnemyPhase
extends RefCounted

## Resolves enemy AttackIntent impacts (including Phase Dodge & Tag friendly fire),
## end-of-frame freeze/daze ticks, and post-thaw scramble attack scheduling.


static func execute_attacks(
	p_state: CombatState,
	p_plan: TimelinePlan,
	p_frame: int,
	p_events: Array[CombatEvent]
) -> void:
	var player: PlayerState = p_state.player
	if not player.is_alive:
		return

	var phase_dodging: bool = p_plan.is_phase_dodge_active(p_frame)

	for enemy: EnemyState in p_state.get_living_enemies():
		if not enemy.is_alive or enemy.is_frozen or enemy.is_dazed:
			continue
		for intent: AttackIntent in enemy.attack_intents:
			if p_frame != intent.end_frame:
				continue

			# Evaluate line-of-sight BEFORE dealing damage so a frozen enemy killed by friendly fire
			# still blocks this beam shot from piercing to the player behind it on the same frame.
			var hits_player: bool = player.is_alive and _hits_position(p_state, intent, player.grid_position)
			var friendly_fire_victims: Array[EnemyState] = []
			for other: EnemyState in p_state.get_living_enemies():
				if other != enemy and other.is_tagged_for_friendly_fire and _hits_position(p_state, intent, other.grid_position):
					friendly_fire_victims.append(other)

			# 1. Resolve Tagged Friendly Fire
			for victim: EnemyState in friendly_fire_victims:
				p_events.append(CombatEvent.new(
					CombatEvent.Type.ENEMY_ATTACK_HIT, p_frame, enemy.id,
					victim.grid_position, intent.damage
				))
				CombatEvent.record_damage(
					victim, intent.damage, p_frame, victim.grid_position, "FRIENDLY_FIRE", p_events
				)

			# 2. Resolve Player Hit (or Hold Frame Phase Dodge)
			if hits_player:
				if phase_dodging:
					p_events.append(CombatEvent.new(
						CombatEvent.Type.PHASE_DODGED, p_frame, player.id,
						player.grid_position, intent.damage
					))
				else:
					p_events.append(CombatEvent.new(
						CombatEvent.Type.ENEMY_ATTACK_HIT, p_frame, enemy.id,
						player.grid_position, intent.damage
					))
					CombatEvent.record_damage(
						player, intent.damage, p_frame, player.grid_position, "ENEMY_ATTACK", p_events
					)
					if not player.is_alive:
						return


static func tick_statuses(
	p_state: CombatState,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var frames_remaining: int = (p_config.total_frames - 1) - p_frame
	var player: PlayerState = p_state.player

	if player.is_alive and player.tick_freeze_frame():
		p_events.append(CombatEvent.new(CombatEvent.Type.ENTITY_THAWED, p_frame, player.id, player.grid_position))

	for enemy: EnemyState in p_state.get_living_enemies():
		if enemy.is_frozen:
			if enemy.tick_freeze_frame():
				p_events.append(CombatEvent.new(CombatEvent.Type.ENTITY_THAWED, p_frame, enemy.id, enemy.grid_position))
				var daze_frames: int = mini(p_config.thaw_daze_max_frames, frames_remaining)
				if daze_frames > 0:
					enemy.daze_for_frames(daze_frames)
					p_events.append(CombatEvent.new(CombatEvent.Type.ENEMY_DAZED, p_frame, enemy.id, enemy.grid_position, daze_frames))
				elif frames_remaining >= p_config.thaw_scramble_duration_frames:
					_schedule_scramble(enemy, player.enemy_target_position, p_frame, p_config, p_events)
		elif enemy.is_dazed:
			if enemy.tick_daze_frame() and frames_remaining >= p_config.thaw_scramble_duration_frames:
				_schedule_scramble(enemy, player.enemy_target_position, p_frame, p_config, p_events)


static func _hits_position(p_state: CombatState, p_intent: AttackIntent, p_target_pos: Vector2i) -> bool:
	if not p_intent.is_beam:
		return p_intent.targets_tile(p_target_pos)

	for tile: Vector2i in p_intent.target_tiles:
		if p_state.board.is_solid(tile):
			return false
		if tile == p_target_pos:
			return true
		var blocker: EnemyState = p_state.get_enemy_at(tile)
		if blocker != null and blocker.is_frozen:
			return false
	return false


static func _schedule_scramble(
	p_enemy: EnemyState,
	p_target_pos: Vector2i,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var dir: Types.Direction = Types.direction_toward(p_enemy.grid_position, p_target_pos, p_enemy.direction)
	p_enemy.set_direction(dir)
	var target_tile: Vector2i = p_enemy.grid_position + Types.to_vector(dir)
	var targets: Array[Vector2i] = [target_tile]
	var intent: AttackIntent = AttackIntent.new(
		p_frame + 1,
		p_frame + p_config.thaw_scramble_duration_frames,
		targets,
		p_config.thaw_scramble_damage,
		false
	)
	p_enemy.add_attack_intent(intent)
	p_events.append(CombatEvent.new(
		CombatEvent.Type.ENEMY_SCRAMBLE_SCHEDULED, p_frame, p_enemy.id,
		target_tile, p_config.thaw_scramble_damage
	))
