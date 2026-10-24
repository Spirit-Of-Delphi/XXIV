class_name ActionPhase
extends RefCounted

## Phase 4 of every frame: resolves Track 1 strike hit frames, Flow bonus,
## Frozen target bonus, once-per-intent Match Cuts, and card freeze/knockback.


static func execute(
	p_state: CombatState,
	p_plan: TimelinePlan,
	p_frame: int,
	p_config: CombatConfig,
	p_events: Array[CombatEvent]
) -> void:
	var player: PlayerState = p_state.player
	if not player.is_alive or player.is_frozen or p_plan.is_hold_frame_active(p_frame):
		return

	var action_block: TimelineBlock = p_plan.get_block_at(TimelinePlan.TRACK_ACTION, p_frame)
	if action_block == null or action_block.card.family != Types.CardFamily.ACTION or not action_block.is_hit_frame(p_frame):
		return

	var strike_pos: Vector2i = player.grid_position + Types.to_vector(action_block.direction)
	p_events.append(CombatEvent.new(
		CombatEvent.Type.STRIKE_SWUNG, p_frame, player.id, strike_pos, int(action_block.direction)
	))

	var target: EnemyState = p_state.get_enemy_at(strike_pos)
	if target == null or not target.is_alive:
		return

	var hit_count: int = maxi(1, action_block.card.hit_frames.size())
	var damage: int = action_block.card.base_damage

	# 1. Flow Bonus (requires Tier 1+ and moving within the tier's Flow window)
	if player.has_flow(p_config):
		var flow_bonus: int = _divide_flat_bonus(p_config.flow_bonus_damage, hit_count)
		damage += flow_bonus
		p_events.append(CombatEvent.new(
			CombatEvent.Type.FLOW_TRIGGERED, p_frame, player.id, strike_pos, flow_bonus
		))

	# 2. Frozen Target Bonus
	if target.is_frozen:
		damage += _divide_flat_bonus(p_config.frozen_strike_bonus_damage, hit_count)

	# 3. Match Cut Check (once per active AttackIntent on an unfrozen, undazed enemy)
	if not target.is_frozen and not target.is_dazed:
		var match_intent: AttackIntent = _find_untriggered_match_cut_intent(target, p_frame)
		if match_intent != null:
			target.mark_match_cut_triggered(match_intent)
			damage = roundi(float(damage) * p_config.match_cut_damage_multiplier)
			player.add_bonus_motion_frames(p_config.match_cut_bonus_motion_frames)
			p_events.append(CombatEvent.new(
				CombatEvent.Type.MATCH_CUT_TRIGGERED, p_frame, target.id,
				strike_pos, p_config.match_cut_bonus_motion_frames
			))
			MotionPhase.check_tier_promotion(player, p_frame, p_config, p_events)

	# 4. Apply Damage
	CombatEvent.record_damage(target, damage, p_frame, strike_pos, action_block.card.id, p_events)

	# 5. Apply Card Freeze
	if target.is_alive and action_block.card.freezes_target:
		target.freeze_for_frames(p_config.freeze_frames)
		p_events.append(CombatEvent.new(
			CombatEvent.Type.ENTITY_FROZEN, p_frame, target.id,
			target.grid_position, p_config.freeze_frames
		))

	# 6. Apply Card Knockback
	if target.is_alive and action_block.card.knockback_distance > 0:
		KnockbackResolver.apply(
			p_state, target, action_block.direction,
			action_block.card.knockback_distance, p_frame, p_config, p_events
		)


static func _find_untriggered_match_cut_intent(p_enemy: EnemyState, p_frame: int) -> AttackIntent:
	for intent: AttackIntent in p_enemy.attack_intents:
		if intent.is_active_on(p_frame) and not p_enemy.has_triggered_match_cut(intent):
			return intent
	return null


static func _divide_flat_bonus(p_bonus: int, p_hit_count: int) -> int:
	if p_bonus <= 0:
		return 0
	if p_hit_count <= 1:
		return p_bonus
	return maxi(1, floori(float(p_bonus) / float(p_hit_count)))
