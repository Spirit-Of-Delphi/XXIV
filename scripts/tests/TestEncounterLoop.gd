class_name TestEncounterLoop
extends RefCounted

## Suites 6–8: DeckState lifecycle, EnemyIntentGenerator multi-attack patterns,
## and full multi-take CombatEncounter state machine.


static func run_all(p_config: CombatConfig) -> void:
	_test_deck_state_lifecycle(p_config)
	_test_enemy_intent_generator(p_config)
	_test_full_combat_encounter_loop(p_config)


static func _test_deck_state_lifecycle(p_config: CombatConfig) -> void:
	var step_card: CardData = CardData.new()
	step_card.id = "quick_step"

	var develop_card: CardData = CardData.new()
	develop_card.id = "develop"
	develop_card.exhausts_on_play = true

	var pivot_card: CardData = CardData.new()
	pivot_card.id = "pivot"
	pivot_card.retains_in_hand = true

	var starter: Array[CardData] = [step_card, step_card, step_card, step_card, develop_card, pivot_card]

	var deck_a: DeckState = DeckState.new(starter, 777)
	var deck_b: DeckState = DeckState.new(starter, 777)
	var drawn_a: Array[CardData] = deck_a.draw_cards(6, p_config.max_hand_size)
	var drawn_b: Array[CardData] = deck_b.draw_cards(6, p_config.max_hand_size)
	assert(drawn_a == drawn_b, "Identical seeds must produce identical draw orders!")
	assert(deck_a.hand_count == 6 and deck_a.draw_count == 0, "Should have all 6 cards in hand!")

	assert(deck_a.stage_card(step_card), "Should stage 1st Quick Step!")
	assert(deck_a.stage_card(step_card), "Should stage 2nd Quick Step!")
	assert(deck_a.stage_card(develop_card), "Should stage Develop!")
	assert(deck_a.hand_count == 3 and deck_a.staged_count == 3, "Should have 3 in hand and 3 staged!")

	assert(deck_a.unstage_card(step_card), "Should return 1 Quick Step to hand!")
	assert(deck_a.hand_count == 4 and deck_a.staged_count == 2, "Should have 4 in hand and 2 staged!")

	deck_a.commit_take()
	assert(deck_a.exhaust_count == 1, "Develop should exhaust on play!")
	assert(deck_a.hand_count == 1 and deck_a.hand[0] == pivot_card, "Pivot should retain in hand!")
	assert(deck_a.discard_count == 4, "4 Quick Steps should be in discard pile!")

	deck_a.draw_cards(4, p_config.max_hand_size)
	assert(deck_a.hand_count == 5 and deck_a.discard_count == 0 and deck_a.draw_count == 0, "Discard should auto-reshuffle into draw!")
	print("[XXIV] Suite 6 PASSED: Deterministic DeckState shuffle, staging, exhaust, retain & reshuffle.")


static func _test_enemy_intent_generator(p_config: CombatConfig) -> void:
	var board: BoardState = BoardState.new(p_config.default_grid_size)
	var player: PlayerState = PlayerState.new()
	player.set_identity(1, p_config.player_max_hp)
	player.set_position_and_direction(Vector2i(5, 5), Types.Direction.NORTH)
	player.place_decoy(Vector2i(2, 4))

	var jab_atk: EnemyAttackData = EnemyAttackData.new()
	jab_atk.start_frame = 2
	jab_atk.end_frame = 5
	jab_atk.damage = 3
	jab_atk.local_offsets = [Vector2i(0, -1)]

	var sweep_atk: EnemyAttackData = EnemyAttackData.new()
	sweep_atk.start_frame = 8
	sweep_atk.end_frame = 13
	sweep_atk.damage = 6
	sweep_atk.local_offsets = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

	var beam_atk: EnemyAttackData = EnemyAttackData.new()
	beam_atk.start_frame = 16
	beam_atk.end_frame = 22
	beam_atk.damage = 8
	beam_atk.is_beam = true
	beam_atk.beam_max_range = 6

	var boss_pattern: EnemyTurnPattern = EnemyTurnPattern.new()
	boss_pattern.move_steps = 1
	boss_pattern.preferred_range = 1
	boss_pattern.attacks = [jab_atk, sweep_atk, beam_atk]

	var boss_data: EnemyData = EnemyData.new()
	boss_data.id = "director_boss"
	boss_data.symbol = "B"
	boss_data.turn_patterns = [boss_pattern]

	var boss: EnemyState = EnemyState.new()
	boss.set_identity(401, 60)
	boss.set_enemy_data(boss_data)
	boss.set_position_and_direction(Vector2i(2, 2), Types.Direction.NORTH)
	boss.daze_for_frames(5)

	var sniper_pattern: EnemyTurnPattern = EnemyTurnPattern.new()
	sniper_pattern.move_steps = 1
	sniper_pattern.preferred_range = 3
	sniper_pattern.attacks = [beam_atk]

	var sniper_data: EnemyData = EnemyData.new()
	sniper_data.id = "sniper"
	sniper_data.symbol = "S"
	sniper_data.turn_patterns = [sniper_pattern]

	var sniper: EnemyState = EnemyState.new()
	sniper.set_identity(402, 16)
	sniper.set_enemy_data(sniper_data)
	sniper.set_position_and_direction(Vector2i(1, 1), Types.Direction.NORTH)

	var state: CombatState = CombatState.new(board, player)
	state.add_enemy(boss)
	state.add_enemy(sniper)

	EnemyIntentGenerator.prepare_enemies_for_take(state, p_config)

	assert(not boss.is_dazed, "Leftover Daze must never carry over into the next take!")
	assert(boss.grid_position == Vector2i(2, 3) and boss.direction == Types.Direction.SOUTH, "Boss should step adjacent to Decoy!")
	assert(boss.attack_intents.size() == 3, "Boss should schedule all 3 distinct attacks!")
	assert(boss.attack_intents[0].target_tiles.size() == 1 and not boss.attack_intents[0].is_beam, "Attack 1 should be 1-tile jab!")
	assert(boss.attack_intents[1].target_tiles.size() == 3, "Attack 2 should be 3-tile sweep around Decoy!")
	assert(boss.attack_intents[2].is_beam, "Attack 3 should be a beam!")

	assert(sniper.grid_position == Vector2i(2, 1) and sniper.direction == Types.Direction.SOUTH, "Sniper should strafe East to (2, 1) to line up beam with Decoy!")
	print("[XXIV] Suite 7 PASSED: Multi-attack Boss patterns, Sniper line-up, Decoy targeting & Daze reset.")


static func _test_full_combat_encounter_loop(p_config: CombatConfig) -> void:
	var board: BoardState = BoardState.new(p_config.default_grid_size)
	var player: PlayerState = PlayerState.new()
	player.set_identity(1, p_config.player_max_hp)
	player.set_position_and_direction(Vector2i(2, 4), Types.Direction.NORTH)

	var bite_atk: EnemyAttackData = EnemyAttackData.new()
	bite_atk.start_frame = 4
	bite_atk.end_frame = 10
	bite_atk.damage = 4
	bite_atk.local_offsets = [Vector2i(0, -1)]

	var hound_pattern: EnemyTurnPattern = EnemyTurnPattern.new()
	hound_pattern.move_steps = 1
	hound_pattern.preferred_range = 1
	hound_pattern.attacks = [bite_atk]

	var hound_data: EnemyData = EnemyData.new()
	hound_data.id = "hound"
	hound_data.symbol = "H"
	hound_data.turn_patterns = [hound_pattern]

	var hound: EnemyState = EnemyState.new()
	hound.set_identity(501, 18)
	hound.set_enemy_data(hound_data)
	hound.set_position_and_direction(Vector2i(2, 1), Types.Direction.SOUTH)

	var initial_state: CombatState = CombatState.new(board, player)
	initial_state.add_enemy(hound)

	var step_card: CardData = CardData.new()
	step_card.id = "quick_step"
	step_card.family = Types.CardFamily.MOTION
	step_card.frame_cost = 4
	step_card.step_frames = [0]

	var palm_card: CardData = CardData.new()
	palm_card.id = "palm"
	palm_card.family = Types.CardFamily.ACTION
	palm_card.frame_cost = 4
	palm_card.hit_frames = [2]
	palm_card.base_damage = 8
	palm_card.freezes_target = true

	var jab_card: CardData = CardData.new()
	jab_card.id = "jab"
	jab_card.family = Types.CardFamily.ACTION
	jab_card.frame_cost = 4
	jab_card.hit_frames = [1]
	jab_card.base_damage = 6

	var deck: DeckState = DeckState.new([step_card, step_card, palm_card, jab_card, jab_card], 101)
	var encounter: CombatEncounter = CombatEncounter.new(initial_state, deck, p_config)

	assert(encounter.start_next_take(), "Take 1 should start in PLANNING!")
	assert(encounter.phase == CombatEncounter.Phase.PLANNING and encounter.take_number == 1, "Should be Take 1 PLANNING!")

	var step_blk: TimelineBlock = encounter.place_card(step_card, TimelinePlan.TRACK_MOTION, 0, Types.Direction.NORTH)
	var palm_blk: TimelineBlock = encounter.place_card(palm_card, TimelinePlan.TRACK_ACTION, 2, Types.Direction.NORTH)
	assert(step_blk != null and palm_blk != null, "Cards in hand should place cleanly!")

	palm_blk = encounter.move_or_reaim_block(palm_blk, TimelinePlan.TRACK_ACTION, 4, Types.Direction.NORTH)
	assert(palm_blk != null and palm_blk.start_frame == 4, "move_or_reaim_block should relocate block to f4!")
	assert(encounter.preview_result.has_event_type(CombatEvent.Type.MATCH_CUT_TRIGGERED, 6), "Live preview must show Match Cut on f6!")

	var res_1: SimulationResult = encounter.commit_take()
	assert(res_1 != null and encounter.phase == CombatEncounter.Phase.EXECUTING, "Should enter EXECUTING after Take 1!")
	assert(encounter.state.get_enemy_by_id(501).hp == 6, "Hound should have 6 HP left after 12-dmg Match Cut!")

	assert(encounter.start_next_take(), "Take 2 should start!")
	assert(encounter.take_number == 2 and encounter.deck.hand_count == 5, "Discard pile should reshuffle to deal 5 cards for Take 2!")
	assert(encounter.place_card(jab_card, TimelinePlan.TRACK_ACTION, 0, Types.Direction.NORTH) != null, "Should place Jab!")
	encounter.commit_take()

	assert(encounter.phase == CombatEncounter.Phase.VICTORY and encounter.is_over, "Killing last enemy must trigger VICTORY!")
	print("[XXIV] Suite 8 PASSED: Full multi-take CombatEncounter loop from NOT_STARTED -> VICTORY.")
