class_name TestCoreSimulation
extends RefCounted

## Suites 1–4: Timeline cost/step resolution, Match Cuts, cross-take Freeze/Thaw/Daze/Scramble,
## and Tier 3 frozen push-through, radial shockwave & wall breaking.


static func run_all(p_config: CombatConfig) -> void:
	_test_timeline_plan(p_config)
	_test_match_cut_and_tier_promotion(p_config)
	_test_cross_take_freeze_thaw_daze_scramble(p_config)
	_test_tier_3_frozen_shockwave_and_wall_break(p_config)


static func _test_timeline_plan(p_config: CombatConfig) -> void:
	var plan: TimelinePlan = TimelinePlan.new(p_config, Types.SpeedTier.TIER_3)

	var dash: CardData = CardData.new()
	dash.family = Types.CardFamily.MOTION
	dash.frame_cost = 6
	dash.step_frames = [0, 3]
	dash.tier_3_step_frames = [0, 1]

	var block: TimelineBlock = plan.create_block(dash, TimelinePlan.TRACK_MOTION, 0)
	assert(block.duration == 3, "Tier 3 discount not applied!")
	assert(block.is_step_frame(0) and block.is_step_frame(1) and not block.is_step_frame(2), "Step frames incorrect!")
	assert(plan.add_block(block), "Valid block was rejected!")

	var edit_card: CardData = CardData.new()
	edit_card.family = Types.CardFamily.EDIT
	edit_card.frame_cost = 4
	assert(plan.add_block(plan.create_block(edit_card, TimelinePlan.TRACK_MOTION, 5)), "Edit block rejected!")

	var state: CombatState = CombatState.new(BoardState.new(p_config.default_grid_size), PlayerState.new())
	state.player.set_identity(1, p_config.player_max_hp)
	state.player.set_position_and_direction(Vector2i(2, 4), Types.Direction.NORTH)
	var sim: SimulationResult = CombatSimulator.simulate(state, plan, p_config)
	var snap_after_edit: CombatState = sim.get_snapshot(8)
	assert(snap_after_edit.player.idle_frames_streak == 2, "EDIT card should pause idle streak at 2!")
	assert(snap_after_edit.player.frames_since_last_motion == 6, "EDIT card should still increment Flow timer!")
	print("[XXIV] Suite 1 PASSED: Cost resolution, explicit step frames & EDIT idle pause.")


static func _test_match_cut_and_tier_promotion(p_config: CombatConfig) -> void:
	var board: BoardState = BoardState.new(p_config.default_grid_size)
	var player: PlayerState = PlayerState.new()
	player.set_identity(1, p_config.player_max_hp)
	player.set_position_and_direction(Vector2i(2, 4), Types.Direction.NORTH)

	var hound: EnemyState = EnemyState.new()
	hound.set_identity(101, 30)
	hound.set_position_and_direction(Vector2i(2, 2), Types.Direction.SOUTH)
	var intent_tiles: Array[Vector2i] = [Vector2i(2, 3)]
	hound.add_attack_intent(AttackIntent.new(2, 8, intent_tiles, 4, false))

	var state: CombatState = CombatState.new(board, player)
	state.add_enemy(hound)

	var plan: TimelinePlan = TimelinePlan.new(p_config, player.tier)

	var long_step: CardData = CardData.new()
	long_step.id = "long_step"
	long_step.family = Types.CardFamily.MOTION
	long_step.frame_cost = 10
	long_step.step_frames = [0]
	plan.add_block(plan.create_block(long_step, TimelinePlan.TRACK_MOTION, 0, Types.Direction.NORTH))

	var twin_jab: CardData = CardData.new()
	twin_jab.id = "twin_jab"
	twin_jab.family = Types.CardFamily.ACTION
	twin_jab.frame_cost = 6
	twin_jab.hit_frames = [1, 3]
	twin_jab.base_damage = 6
	twin_jab.freezes_target = false
	plan.add_block(plan.create_block(twin_jab, TimelinePlan.TRACK_ACTION, 2, Types.Direction.NORTH))

	var result: SimulationResult = CombatSimulator.simulate(state, plan, p_config)
	var end_state: CombatState = result.final_state
	var end_hound: EnemyState = end_state.get_enemy_by_id(101)

	assert(result.count_events_of_type(CombatEvent.Type.MATCH_CUT_TRIGGERED) == 1, "Match Cut should trigger once per intent!")
	assert(end_hound.hp == 15, "Expected Hound HP 15 (9 Match Cut + 6 normal), got %d" % end_hound.hp)
	assert(not end_hound.is_frozen, "Normal Match Cut must not auto-freeze!")
	assert(end_state.player.hp == p_config.player_max_hp - 4, "Hound's un-frozen intent should hit player on frame 8!")
	assert(result.has_event_type(CombatEvent.Type.TIER_PROMOTED), "10f motion + 2f Match Cut bonus should promote to Tier 1!")
	print("[XXIV] Suite 2 PASSED: Once-per-intent Match Cut (1.5x dmg + +2f motion promotion).")


static func _test_cross_take_freeze_thaw_daze_scramble(p_config: CombatConfig) -> void:
	var board: BoardState = BoardState.new(p_config.default_grid_size)
	var player: PlayerState = PlayerState.new()
	player.set_identity(1, p_config.player_max_hp)
	player.set_position_and_direction(Vector2i(2, 3), Types.Direction.NORTH)

	var hound: EnemyState = EnemyState.new()
	hound.set_identity(102, 20)
	hound.set_position_and_direction(Vector2i(2, 2), Types.Direction.SOUTH)

	var state: CombatState = CombatState.new(board, player)
	state.add_enemy(hound)

	var palm: CardData = CardData.new()
	palm.id = "palm"
	palm.family = Types.CardFamily.ACTION
	palm.frame_cost = 4
	palm.hit_frames = [2]
	palm.base_damage = 8
	palm.freezes_target = true

	var plan_1: TimelinePlan = TimelinePlan.new(p_config, player.tier)
	plan_1.add_block(plan_1.create_block(palm, TimelinePlan.TRACK_ACTION, 6, Types.Direction.NORTH))

	var res_1: SimulationResult = CombatSimulator.simulate(state, plan_1, p_config)
	var state_after_take_1: CombatState = res_1.final_state
	var hound_t1: EnemyState = state_after_take_1.get_enemy_by_id(102)

	assert(hound_t1.is_frozen and hound_t1.frozen_frames_remaining == 8, "Should have 8 freeze frames left entering Take 2!")

	var plan_2: TimelinePlan = TimelinePlan.new(p_config, state_after_take_1.player.tier)
	var res_2: SimulationResult = CombatSimulator.simulate(state_after_take_1, plan_2, p_config)

	assert(res_2.has_event_type(CombatEvent.Type.ENTITY_THAWED, 7), "Hound should thaw at end of frame 7!")
	assert(res_2.has_event_type(CombatEvent.Type.ENEMY_DAZED, 7), "Hound should enter daze upon thawing!")
	assert(res_2.has_event_type(CombatEvent.Type.ENEMY_SCRAMBLE_SCHEDULED, 13), "Scramble should schedule when daze ends on frame 13!")
	assert(res_2.has_event_type(CombatEvent.Type.ENEMY_ATTACK_HIT, 17), "Scramble should hit player on frame 17!")
	print("[XXIV] Suite 3 PASSED: 24-frame cross-take freeze -> 6f daze -> 4f scramble attack.")


static func _test_tier_3_frozen_shockwave_and_wall_break(p_config: CombatConfig) -> void:
	var board: BoardState = BoardState.new(p_config.default_grid_size)
	board.add_wall(Vector2i(2, 0))

	var player: PlayerState = PlayerState.new()
	player.set_identity(1, p_config.player_max_hp)
	player.set_position_and_direction(Vector2i(2, 3), Types.Direction.NORTH)
	player.set_tier(Types.SpeedTier.TIER_3)

	var frozen_enemy: EnemyState = EnemyState.new()
	frozen_enemy.set_identity(201, 30)
	frozen_enemy.set_position_and_direction(Vector2i(2, 2), Types.Direction.SOUTH)
	frozen_enemy.freeze_for_frames(p_config.freeze_frames)

	var bystander: EnemyState = EnemyState.new()
	bystander.set_identity(202, 20)
	bystander.set_position_and_direction(Vector2i(3, 2), Types.Direction.WEST)

	var state: CombatState = CombatState.new(board, player)
	state.add_enemy(frozen_enemy)
	state.add_enemy(bystander)

	var plan: TimelinePlan = TimelinePlan.new(p_config, player.tier)
	var step_card: CardData = CardData.new()
	step_card.id = "step"
	step_card.family = Types.CardFamily.MOTION
	step_card.frame_cost = 4
	step_card.step_frames = [0]
	step_card.tier_3_step_frames = [0]

	plan.add_block(plan.create_block(step_card, TimelinePlan.TRACK_MOTION, 0, Types.Direction.NORTH))

	var res: SimulationResult = CombatSimulator.simulate(state, plan, p_config)
	var snap_0: CombatState = res.get_snapshot(0)

	assert(snap_0.player.grid_position == Vector2i(2, 2), "Player should claim vacated frozen enemy tile (2, 2)!")
	assert(snap_0.player.tier == Types.SpeedTier.TIER_2, "Player should drop from Tier 3 to Tier 2!")
	assert(snap_0.get_enemy_by_id(201).grid_position == Vector2i(2, 1), "Frozen enemy should be pushed North to (2, 1)!")
	assert(snap_0.get_enemy_by_id(202).grid_position == Vector2i(4, 2), "Shockwave should push bystander East to (4, 2)!")

	var wall_state: CombatState = snap_0.clone()
	wall_state.player.set_grid_position(Vector2i(2, 1))
	wall_state.player.set_tier(Types.SpeedTier.TIER_3)
	var wall_plan: TimelinePlan = TimelinePlan.new(p_config, Types.SpeedTier.TIER_3)
	wall_plan.add_block(wall_plan.create_block(step_card, TimelinePlan.TRACK_MOTION, 0, Types.Direction.NORTH))

	var wall_res: SimulationResult = CombatSimulator.simulate(wall_state, wall_plan, p_config)
	assert(wall_res.has_event_type(CombatEvent.Type.WALL_BROKEN, 0), "Tier 3 crash into interior wall must break the wall!")
	assert(not wall_res.final_state.board.is_wall(Vector2i(2, 0)), "Wall at (2, 0) should be removed from BoardState!")
	assert(wall_res.get_snapshot(0).player.is_frozen and wall_res.final_state.player.tier == Types.SpeedTier.BASE, "Player should freeze on impact and drop to Tier 0!")
	print("[XXIV] Suite 4 PASSED: Tier 3 frozen push-through, radial shockwave, and wall destruction.")
