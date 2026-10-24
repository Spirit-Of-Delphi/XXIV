class_name TestEditCards
extends RefCounted

## Suite 5: Verifies all 8 composable EDIT cards (Dutch Angle, Slip, Hold Frame,
## Negative Exposure, Rewind, Develop, Swap, and Tag).


static func run_all(p_config: CombatConfig) -> void:
	var board: BoardState = BoardState.new(p_config.default_grid_size)
	var player: PlayerState = PlayerState.new()
	player.set_identity(1, p_config.player_max_hp, p_config.player_max_hp - 6)
	player.set_position_and_direction(Vector2i(2, 3), Types.Direction.NORTH)

	var sniper: EnemyState = EnemyState.new()
	sniper.set_identity(301, 20)
	sniper.set_position_and_direction(Vector2i(2, 1), Types.Direction.SOUTH)
	var beam_tiles: Array[Vector2i] = [Vector2i(2, 2), Vector2i(2, 3)]
	sniper.add_attack_intent(AttackIntent.new(20, 22, beam_tiles, 6, true))

	var hound: EnemyState = EnemyState.new()
	hound.set_identity(302, 20)
	hound.set_position_and_direction(Vector2i(2, 2), Types.Direction.SOUTH)
	var melee_tiles: Array[Vector2i] = [Vector2i(2, 3)]
	hound.add_attack_intent(AttackIntent.new(6, 10, melee_tiles, 5, false))

	var cleaver: EnemyState = EnemyState.new()
	cleaver.set_identity(303, 20)
	cleaver.set_position_and_direction(Vector2i(3, 3), Types.Direction.WEST)
	cleaver.add_attack_intent(AttackIntent.new(2, 4, melee_tiles, 4, false))

	var state: CombatState = CombatState.new(board, player)
	state.add_enemy(sniper)
	state.add_enemy(hound)
	state.add_enemy(cleaver)

	var plan: TimelinePlan = TimelinePlan.new(p_config, Types.SpeedTier.BASE)

	var dutch: CardData = CardData.new()
	dutch.family = Types.CardFamily.EDIT
	dutch.frame_cost = 2
	dutch.edit_frames = [0]
	dutch.rotates_target_90 = true
	plan.add_block(plan.create_block(dutch, TimelinePlan.TRACK_MOTION, 0, Types.Direction.EAST, 303))

	var slip: CardData = CardData.new()
	slip.family = Types.CardFamily.EDIT
	slip.frame_cost = 2
	slip.edit_frames = [0]
	slip.slip_intent_frames = 3
	plan.add_block(plan.create_block(slip, TimelinePlan.TRACK_MOTION, 2, Types.Direction.EAST, 301))

	var tag: CardData = CardData.new()
	tag.family = Types.CardFamily.EDIT
	tag.frame_cost = 2
	tag.edit_frames = [0]
	tag.tags_for_friendly_fire = true
	plan.add_block(plan.create_block(tag, TimelinePlan.TRACK_ACTION, 4, Types.Direction.NORTH))

	var hold: CardData = CardData.new()
	hold.family = Types.CardFamily.EDIT
	hold.frame_cost = 5
	hold.edit_frames = [2]
	hold.holds_frame_and_dodges = true
	plan.add_block(plan.create_block(hold, TimelinePlan.TRACK_ACTION, 8))

	var develop: CardData = CardData.new()
	develop.family = Types.CardFamily.EDIT
	develop.frame_cost = 8
	develop.edit_frames = [7]
	develop.heals_hp = 4
	plan.add_block(plan.create_block(develop, TimelinePlan.TRACK_ACTION, 13))

	var step: CardData = CardData.new()
	step.family = Types.CardFamily.MOTION
	step.frame_cost = 2
	step.step_frames = [0]
	plan.add_block(plan.create_block(step, TimelinePlan.TRACK_MOTION, 21, Types.Direction.WEST))

	var res: SimulationResult = CombatSimulator.simulate(state, plan, p_config)
	var end_1: CombatState = res.final_state

	assert(res.has_event_type(CombatEvent.Type.ENEMY_ROTATED, 0), "Dutch Angle should rotate Cleaver on f0!")
	assert(res.has_event_type(CombatEvent.Type.PHASE_DODGED, 10), "Hold Frame should phase-dodge Hound on f10!")
	assert(res.has_event_type(CombatEvent.Type.PLAYER_HEALED, 20), "Develop should heal +4 HP on f20!")
	assert(end_1.player.hp == p_config.player_max_hp - 2, "Player should end at 12/14 HP!")
	assert(end_1.get_enemy_by_id(302).hp == 14, "Tagged Hound at (2, 2) should take 6 friendly-fire dmg on f23!")

	# Part B: Negative Exposure, Swap & Rewind
	var state_b: CombatState = CombatState.new(BoardState.new(p_config.default_grid_size), PlayerState.new())
	state_b.player.set_identity(1, p_config.player_max_hp)
	state_b.player.set_position_and_direction(Vector2i(1, 4), Types.Direction.NORTH)

	var statue: EnemyState = EnemyState.new()
	statue.set_identity(304, 20)
	statue.set_position_and_direction(Vector2i(4, 1), Types.Direction.SOUTH)
	statue.freeze_for_frames(p_config.freeze_frames)
	state_b.add_enemy(statue)

	var plan_b: TimelinePlan = TimelinePlan.new(p_config, Types.SpeedTier.BASE)

	var swap: CardData = CardData.new()
	swap.family = Types.CardFamily.EDIT
	swap.frame_cost = 2
	swap.edit_frames = [0]
	swap.swaps_with_frozen = true
	plan_b.add_block(plan.create_block(swap, TimelinePlan.TRACK_ACTION, 0, Types.Direction.NORTH, 304))

	var decoy: CardData = CardData.new()
	decoy.family = Types.CardFamily.EDIT
	decoy.frame_cost = 2
	decoy.edit_frames = [0]
	decoy.places_decoy = true
	plan_b.add_block(plan.create_block(decoy, TimelinePlan.TRACK_ACTION, 2))

	var rewind: CardData = CardData.new()
	rewind.family = Types.CardFamily.EDIT
	rewind.frame_cost = 2
	rewind.edit_frames = [0]
	rewind.rewinds_to_start = true
	plan_b.add_block(plan.create_block(rewind, TimelinePlan.TRACK_ACTION, 4))

	var res_b1: SimulationResult = CombatSimulator.simulate(state_b, plan_b, p_config)
	assert(res_b1.final_state.player.grid_position == Vector2i(4, 1), "Rewind must NOT snap back onto an occupied start tile!")
	assert(res_b1.final_state.player.has_decoy and res_b1.final_state.player.decoy_position == Vector2i(4, 1), "Decoy should be active at (4, 1)!")

	var state_b2: CombatState = res_b1.final_state
	var plan_b2: TimelinePlan = TimelinePlan.new(p_config, Types.SpeedTier.BASE)
	plan_b2.add_block(plan_b2.create_block(step, TimelinePlan.TRACK_MOTION, 0, Types.Direction.WEST))
	plan_b2.add_block(plan_b2.create_block(rewind, TimelinePlan.TRACK_ACTION, 4))

	var res_b2: SimulationResult = CombatSimulator.simulate(state_b2, plan_b2, p_config)
	assert(res_b2.has_event_type(CombatEvent.Type.PLAYER_REWOUND, 4), "Rewind should snap back when start tile is unoccupied!")
	assert(res_b2.final_state.player.grid_position == Vector2i(4, 1), "Player should end back at (4, 1)!")
	assert(res_b2.final_state.player.enemy_target_position == Vector2i(4, 1), "Take 2 enemy_target_position should use Take 1's Decoy!")
	print("[XXIV] Suite 5 PASSED: All 8 EDIT cards (Dutch Angle, Slip, Hold Frame, Negative Exposure, Rewind, Develop, Swap, Tag).")
