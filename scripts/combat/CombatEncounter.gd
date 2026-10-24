class_name CombatEncounter
extends RefCounted

## Headless turn-lifecycle state machine orchestrating a full multi-take battle.
## Bridges CombatState, DeckState, TimelinePlan, EnemyIntentGenerator, and CombatSimulator.

signal take_planning_started(p_take_number: int)
signal preview_updated(p_preview: SimulationResult)
signal take_committed(p_take_number: int, p_result: SimulationResult)
signal encounter_ended(p_phase: Phase)

enum Phase {
	NOT_STARTED,
	PLANNING,
	EXECUTING,
	VICTORY,
	DEFEAT,
}

var _config: CombatConfig
var _state: CombatState
var _deck: DeckState
var _plan: TimelinePlan
var _preview_result: SimulationResult
var _take_number: int = 0
var _phase: Phase = Phase.NOT_STARTED


func _init(p_initial_state: CombatState, p_deck: DeckState, p_config: CombatConfig) -> void:
	assert(p_initial_state != null, "CombatEncounter requires an initial CombatState.")
	assert(p_deck != null, "CombatEncounter requires a DeckState.")
	assert(p_config != null, "CombatEncounter requires a CombatConfig.")
	_config = p_config
	_state = p_initial_state.clone()
	_deck = p_deck.clone()


# --- Read-Only Properties ---

var config: CombatConfig:
	get: return _config

## Returns an isolated clone so UI views can never accidentally mutate authoritative state.
var state: CombatState:
	get: return _state.clone()

## Returns an isolated clone so UI views can only stage/unstage cards through CombatEncounter.
var deck: DeckState:
	get: return _deck.clone()

## Returns an isolated clone so UI views can only modify blocks through CombatEncounter.
var plan: TimelinePlan:
	get: return _plan.clone() if _plan != null else null

var preview_result: SimulationResult:
	get: return _preview_result

var take_number: int:
	get: return _take_number

var phase: Phase:
	get: return _phase

var is_over: bool:
	get: return _phase == Phase.VICTORY or _phase == Phase.DEFEAT


# --- Turn Lifecycle API ---

## Begins the next take (Take 1 when NOT_STARTED, or Take N+1 after EXECUTING finishes).
## Returns true if a new PLANNING phase began, or false if the encounter is over.
func start_next_take() -> bool:
	if _phase != Phase.NOT_STARTED and _phase != Phase.EXECUTING:
		return false

	if _check_and_update_end_condition():
		return false

	_take_number += 1
	_state.player.clear_shield()
	EnemyIntentGenerator.prepare_enemies_for_take(_state, _config)

	_plan = TimelinePlan.new(_config, _state.player.tier)
	_deck.draw_cards(_config.cards_drawn_per_take, _config.max_hand_size)

	_phase = Phase.PLANNING
	_refresh_preview()
	take_planning_started.emit(_take_number)
	return true


## Places a card from _deck.hand onto the timeline during PLANNING and refreshes the preview.
## Returns the created TimelineBlock, or null if placement is illegal or card is not in hand.
func place_card(
	p_card: CardData,
	p_track: int,
	p_start_frame: int,
	p_direction: Types.Direction = Types.Direction.NORTH,
	p_target_enemy_id: int = -1
) -> TimelineBlock:
	if _phase != Phase.PLANNING or p_card == null:
		return null

	var block: TimelineBlock = _plan.create_block(p_card, p_track, p_start_frame, p_direction, p_target_enemy_id)
	if not _plan.can_place(block):
		return null
	if not _deck.stage_card(p_card):
		return null

	_plan.add_block(block)
	_refresh_preview()
	return block


## Moves or re-aims an already-placed TimelineBlock without unstaging its card.
## Restores p_old_block automatically if the new position/track is invalid.
func move_or_reaim_block(
	p_old_block: TimelineBlock,
	p_new_track: int,
	p_new_start_frame: int,
	p_new_direction: Types.Direction,
	p_new_target_enemy_id: int = -1
) -> TimelineBlock:
	if _phase != Phase.PLANNING or p_old_block == null or not _plan.blocks.has(p_old_block):
		return null

	_plan.remove_block(p_old_block)
	var new_block: TimelineBlock = _plan.create_block(
		p_old_block.card, p_new_track, p_new_start_frame, p_new_direction, p_new_target_enemy_id
	)
	if _plan.add_block(new_block):
		_refresh_preview()
		return new_block

	# Revert cleanly if new placement overlapped or went out of bounds
	_plan.add_block(p_old_block)
	return null


## Removes a placed TimelineBlock from the timeline and returns its card to _deck.hand.
func remove_block(p_block: TimelineBlock) -> bool:
	if _phase != Phase.PLANNING or p_block == null or not _plan.blocks.has(p_block):
		return false

	_plan.remove_block(p_block)
	_deck.unstage_card(p_block.card)
	_refresh_preview()
	return true


## Clears all placed blocks on the timeline and returns every staged card to _deck.hand.
func clear_timeline() -> void:
	if _phase != Phase.PLANNING:
		return
	_plan.clear()
	_deck.unstage_all()
	_refresh_preview()


## Locks and executes the current 24-frame take, advancing authoritative state and deck piles.
## Transitions to VICTORY/DEFEAT if combat ended, or EXECUTING while awaiting start_next_take().
func commit_take() -> SimulationResult:
	if _phase != Phase.PLANNING:
		return null

	var result: SimulationResult = CombatSimulator.simulate(_state, _plan, _config)
	_deck.commit_take()
	_state = result.final_state
	_preview_result = result

	if not _check_and_update_end_condition():
		_phase = Phase.EXECUTING

	take_committed.emit(_take_number, result)
	return result


# --- Private Helpers ---

func _refresh_preview() -> void:
	_preview_result = CombatSimulator.simulate(_state, _plan, _config)
	preview_updated.emit(_preview_result)


func _check_and_update_end_condition() -> bool:
	if not _state.player.is_alive:
		_phase = Phase.DEFEAT
		encounter_ended.emit(_phase)
		return true
	if _state.get_living_enemies().is_empty():
		_phase = Phase.VICTORY
		encounter_ended.emit(_phase)
		return true
	return false
