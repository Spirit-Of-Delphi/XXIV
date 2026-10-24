class_name EditPhase
extends RefCounted

## Phase 3 of every frame: resolves composable Edit & Splice mechanics on edit_frames
## across both timeline tracks (Dutch Angle, Slip, Negative Exposure, Rewind, Swap, Tag, Develop).


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
	if motion_block != null and motion_block.is_edit_frame(p_frame):
		_resolve_edit_effects(p_state, motion_block, p_frame, p_config, p_events)

	if not player.is_alive or player.is_frozen:
		return

	var action_block: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_ACTION, p_frame)
	if action_block != null and action_block.is_edit_frame(p_frame):
		_resolve_edit_effects(p_state, action_block, p_frame, p_config, p_events)


static func _resolve_edit_effects(
	p_state: CombatState,
	p_block: TimelineBlock,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var player: PlayerState = p_state.player
	var card: CardData = p_block.card

	# 1. Dutch Angle: Rotate selected enemy & its AttackIntents 90° CW (EAST) or CCW (WEST)
	if card.rotates_target_90:
		var rot_enemy: EnemyState = p_state.get_enemy_by_id(p_block.target_enemy_id)
		if rot_enemy != null and rot_enemy.is_alive:
			var is_clockwise: bool = p_block.direction != Types.Direction.WEST
			rot_enemy.rotate_90(is_clockwise)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.ENEMY_ROTATED, p_frame, rot_enemy.id,
				rot_enemy.grid_position, int(rot_enemy.direction)
			))

	# 2. Slip: Shift selected enemy's AttackIntent windows earlier (WEST) or later (EAST)
	if card.slip_intent_frames > 0:
		var slip_enemy: EnemyState = p_state.get_enemy_by_id(p_block.target_enemy_id)
		if slip_enemy != null and slip_enemy.is_alive:
			var sign_dir: int = -1 if p_block.direction == Types.Direction.WEST else 1
			var frame_delta: int = sign_dir * card.slip_intent_frames
			slip_enemy.slip_attack_intents(frame_delta, p_frame, p_config.total_frames - 1)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.INTENT_SLIPPED, p_frame, slip_enemy.id,
				slip_enemy.grid_position, frame_delta
			))

	# 3. Negative Exposure: Stamp optical decoy at player's current tile
	if card.places_decoy:
		player.place_decoy(player.grid_position)
		p_events.append(CombatEvent.new(
			CombatEvent.Type.DECOY_PLACED, p_frame, player.id, player.grid_position
		))

	# 4. Rewind: Snap back to take_start_position ONLY if unoccupied and unblocked
	if card.rewinds_to_start:
		var start_pos: Vector2i = player.take_start_position
		if (
			player.grid_position != start_pos
			and not p_state.board.is_blocked(start_pos)
			and p_state.get_enemy_at(start_pos) == null
		):
			player.set_grid_position(start_pos)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.PLAYER_REWOUND, p_frame, player.id, start_pos
			))

	# 5. Swap: Exchange grid positions with a selected Frozen enemy
	if card.swaps_with_frozen:
		var frozen_enemy: EnemyState = p_state.get_enemy_by_id(p_block.target_enemy_id)
		if frozen_enemy != null and frozen_enemy.is_alive and frozen_enemy.is_frozen:
			var old_player_pos: Vector2i = player.grid_position
			var old_enemy_pos: Vector2i = frozen_enemy.grid_position
			var offset: Vector2i = old_player_pos - old_enemy_pos
			player.set_grid_position(old_enemy_pos)
			frozen_enemy.set_grid_position(old_player_pos)
			frozen_enemy.shift_attack_intents(offset)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.POSITIONS_SWAPPED, p_frame, frozen_enemy.id, old_enemy_pos
			))

	# 6. Tag: Mark adjacent enemy in block.direction to take friendly fire this take
	if card.tags_for_friendly_fire:
		var tag_pos: Vector2i = player.grid_position + Types.to_vector(p_block.direction)
		var tag_enemy: EnemyState = p_state.get_enemy_at(tag_pos)
		if tag_enemy != null and tag_enemy.is_alive:
			tag_enemy.set_tagged_for_friendly_fire(true)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.ENEMY_TAGGED, p_frame, tag_enemy.id, tag_pos
			))

	# 7. Develop: Restore HP on trigger frame
	if card.heals_hp > 0:
		var healed: int = player.heal(card.heals_hp)
		if healed > 0:
			p_events.append(CombatEvent.new(
				CombatEvent.Type.PLAYER_HEALED, p_frame, player.id, player.grid_position, healed
			))
