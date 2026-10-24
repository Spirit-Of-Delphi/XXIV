class_name BlockStartPhase
extends RefCounted

## Phase 1 of every frame: resolves start-of-block Action shields (Track 1)
## and start-of-block Motion body turns / 180-degree violations (Track 0).


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

	var motion_block: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_MOTION, p_frame)
	var action_block: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_ACTION, p_frame)

	# 1. Action Track: Grant start-of-block shields FIRST so a shield starting on Frame F protects Frame F
	if action_block != null and action_block.start_frame == p_frame and action_block.card.family == Types.CardFamily.ACTION:
		_grant_block_shield(player, action_block, p_frame, p_events)

	# 2. Motion Track: Only MOTION cards rotate the player's body (suppressed during Hold Frame)
	if (
		not p_plan.is_hold_frame_active(p_frame)
		and motion_block != null
		and motion_block.start_frame == p_frame
		and motion_block.card.family == Types.CardFamily.MOTION
	):
		try_apply_body_turn(player, motion_block.direction, motion_block.card.allows_180_turn, p_frame, p_config, p_events)


static func try_apply_body_turn(
	p_player: PlayerState,
	p_new_dir: Types.Direction,
	p_safe_turn_active: bool,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> bool:
	if p_player.direction == p_new_dir:
		return true

	if Types.is_opposite_direction(p_player.direction, p_new_dir) and not p_safe_turn_active:
		var self_dmg: int = p_config.get_turn_180_self_damage(p_player.tier)
		MotionPhase.apply_player_violation(
			p_player,
			CombatEvent.Type.VIOLATION_180_TURN,
			p_player.grid_position,
			self_dmg,
			"180_TURN_RECOIL",
			p_frame,
			p_config,
			p_events
		)
		return false

	p_player.set_direction(p_new_dir)
	p_events.append(CombatEvent.new(
		CombatEvent.Type.PLAYER_TURNED,
		p_frame,
		p_player.id,
		p_player.grid_position,
		int(p_new_dir)
	))
	return true


static func _grant_block_shield(
	p_player: PlayerState,
	p_block: TimelineBlock,
	p_frame: int,
	p_events: Array[CombatEvent]
) -> void:
	if p_block.card.grants_shield > 0:
		p_player.add_shield(p_block.card.grants_shield)
		p_events.append(CombatEvent.new(
			CombatEvent.Type.SHIELD_GAINED,
			p_frame,
			p_player.id,
			p_player.grid_position,
			p_block.card.grants_shield
		))
