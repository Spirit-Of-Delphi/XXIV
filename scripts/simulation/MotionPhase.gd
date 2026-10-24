class_name MotionPhase
extends RefCounted

## Phase 2 of every frame: resolves Track 0 tile steps, wall/enemy collisions,
## Tier 2/3 frozen push-throughs & shockwaves, and Speed Tier promotions/bleed.


static func execute(
	p_state: CombatState,
	p_plan: TimelinePlan,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var player: PlayerState = p_state.player
	if not player.is_alive or player.is_frozen:
		return

	# Hold Frame locks movement on both tracks and pauses idle bleed
	if p_plan.is_hold_frame_active(p_frame):
		player.record_edit_pause_frame()
		return

	var motion_block: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_MOTION, p_frame)
	var tier_before_step: Types.SpeedTier = player.tier

	# 1. Execute tile step if this frame is a step_frame
	if motion_block != null and motion_block.card.family == Types.CardFamily.MOTION and motion_block.is_step_frame(p_frame):
		if BlockStartPhase.try_apply_body_turn(player, motion_block.direction, motion_block.card.allows_180_turn, p_frame, p_config, p_events):
			_execute_player_step(p_state, motion_block.direction, p_frame, p_config, p_events)

	# If the step killed or froze the player via a violation, do not record motion/idle streaks
	if not player.is_alive or player.is_frozen:
		return

	# 2. Update Momentum & Idle Bleed
	if motion_block == null:
		player.record_idle_frame()
		if player.idle_frames_streak >= p_config.momentum_bleed_idle_frames:
			player.reset_idle_streak()
			if player.tier > Types.SpeedTier.BASE:
				player.drop_tier(1)
				p_events.append(CombatEvent.new(
					CombatEvent.Type.TIER_DROPPED,
					p_frame,
					player.id,
					player.grid_position,
					int(player.tier),
					"IDLE_BLEED"
				))
	elif motion_block.card.family == Types.CardFamily.MOTION:
		if player.tier == tier_before_step:
			player.record_motion_frame()
			check_tier_promotion(player, p_frame, p_config, p_events)
	else:
		# EDIT card on Track 0: pauses idle bleed counter, still ticks Flow counter
		player.record_edit_pause_frame()


static func check_tier_promotion(
	p_player: PlayerState,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	if p_player.promoted_this_take:
		return
	var threshold: int = p_config.get_promotion_threshold(p_player.tier)
	if threshold > 0 and p_player.motion_frames_this_take >= threshold:
		p_player.promote_tier()
		p_events.append(CombatEvent.new(
			CombatEvent.Type.TIER_PROMOTED,
			p_frame,
			p_player.id,
			p_player.grid_position,
			int(p_player.tier)
		))


## Shared helper for 180-turn recoil, wall crashes, and unfrozen enemy crashes.
static func apply_player_violation(
	p_player: PlayerState,
	p_event_type: CombatEvent.Type,
	p_impact_pos: Vector2i,
	p_self_dmg: int,
	p_dmg_detail: String,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	CombatEvent.record_damage(p_player, p_self_dmg, p_frame, p_player.grid_position, p_dmg_detail, p_events)
	p_player.apply_violation(p_config.freeze_frames)
	p_events.append(CombatEvent.new(
		p_event_type, p_frame, p_player.id, p_impact_pos, p_self_dmg
	))
	p_events.append(CombatEvent.new(
		CombatEvent.Type.ENTITY_FROZEN, p_frame, p_player.id,
		p_player.grid_position, p_config.freeze_frames
	))


static func _execute_player_step(
	p_state: CombatState,
	p_dir: Types.Direction,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var player: PlayerState = p_state.player
	var board: BoardState = p_state.board
	var target_pos: Vector2i = player.grid_position + Types.to_vector(p_dir)

	# Case 1: Solid Wall, Arena Boundary, or Pit Hazard
	if board.is_blocked(target_pos):
		var impact_tier: Types.SpeedTier = player.tier
		if impact_tier == Types.SpeedTier.TIER_3 and p_config.tier_3_dash_breaks_walls and board.is_wall(target_pos):
			board.remove_wall(target_pos)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.WALL_BROKEN, p_frame, player.id, target_pos
			))
		var wall_dmg: int = p_config.get_dash_wall_self_damage(impact_tier)
		apply_player_violation(
			player, CombatEvent.Type.VIOLATION_WALL_CRASH,
			target_pos, wall_dmg, "WALL_CRASH", p_frame, p_config, p_events
		)
		return

	# Case 2: Living Enemy Occupying Target Tile
	var enemy: EnemyState = p_state.get_enemy_at(target_pos)
	if enemy != null:
		if not enemy.is_frozen:
			var self_dmg: int = p_config.get_dash_unfrozen_self_damage(player.tier)
			apply_player_violation(
				player, CombatEvent.Type.VIOLATION_ENEMY_CRASH,
				target_pos, self_dmg, "ENEMY_CRASH", p_frame, p_config, p_events
			)
		else:
			_resolve_frozen_enemy_impact(p_state, enemy, p_dir, target_pos, p_frame, p_config, p_events)
		return

	# Case 3: Open Tile
	player.set_grid_position(target_pos)
	p_events.append(CombatEvent.new(
		CombatEvent.Type.PLAYER_STEPPED, p_frame, player.id, target_pos
	))


static func _resolve_frozen_enemy_impact(
	p_state: CombatState,
	p_enemy: EnemyState,
	p_dash_dir: Types.Direction,
	p_impact_pos: Vector2i,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var player: PlayerState = p_state.player
	var impact_tier: Types.SpeedTier = player.tier
	var enemy_dmg: int = p_config.get_dash_frozen_enemy_damage(impact_tier)

	if enemy_dmg > 0:
		p_events.append(CombatEvent.new(
			CombatEvent.Type.FROZEN_ENEMY_IMPACT, p_frame, p_enemy.id, p_impact_pos, enemy_dmg
		))
		CombatEvent.record_damage(p_enemy, enemy_dmg, p_frame, p_impact_pos, "FROZEN_IMPACT", p_events)

	if impact_tier <= Types.SpeedTier.TIER_1:
		apply_player_violation(
			player, CombatEvent.Type.VIOLATION_ENEMY_CRASH,
			p_impact_pos, 0, "ENEMY_CRASH", p_frame, p_config, p_events
		)
		return

	# Tier 2 & Tier 3: No violation! Drop 1 tier, push enemy, optional Tier 3 radial shockwave, claim tile
	player.drop_tier(1)
	p_events.append(CombatEvent.new(
		CombatEvent.Type.TIER_DROPPED, p_frame, player.id,
		player.grid_position, int(player.tier), "FROZEN_PUSH_THROUGH"
	))

	var shockwave_targets: Array[EnemyState] = []
	var shockwave_dirs: Array[Types.Direction] = []
	if impact_tier == Types.SpeedTier.TIER_3:
		for dir: Types.Direction in Types.ALL_DIRECTIONS:
			var neighbor: EnemyState = p_state.get_enemy_at(p_impact_pos + Types.to_vector(dir))
			if neighbor != null and neighbor != p_enemy:
				shockwave_targets.append(neighbor)
				shockwave_dirs.append(dir)

	if p_enemy.is_alive:
		KnockbackResolver.apply(p_state, p_enemy, p_dash_dir, 1, p_frame, p_config, p_events)

	for i: int in range(shockwave_targets.size()):
		var sw_enemy: EnemyState = shockwave_targets[i]
		if sw_enemy.is_alive:
			p_events.append(CombatEvent.new(
				CombatEvent.Type.SHOCKWAVE_PUSH, p_frame, sw_enemy.id, sw_enemy.grid_position, 1
			))
			KnockbackResolver.apply(p_state, sw_enemy, shockwave_dirs[i], 1, p_frame, p_config, p_events)

	if p_state.get_enemy_at(p_impact_pos) == null and not p_state.board.is_blocked(p_impact_pos):
		player.set_grid_position(p_impact_pos)
		p_events.append(CombatEvent.new(
			CombatEvent.Type.PLAYER_STEPPED, p_frame, player.id, p_impact_pos
		))
