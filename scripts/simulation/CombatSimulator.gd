class_name CombatSimulator
extends RefCounted

## Top-level 24-frame simulation orchestrator.
## Runs the deterministic frame pipeline on each frame from 0 to total_frames - 1.


static func simulate(
	p_initial_state: CombatState,
	p_plan: TimelinePlan,
	p_config: CombatConfig
) -> SimulationResult:
	assert(p_initial_state != null, "CombatSimulator requires an initial CombatState.")
	assert(p_plan != null, "CombatSimulator requires a TimelinePlan.")
	assert(p_config != null, "CombatSimulator requires a CombatConfig.")

	var working_state: CombatState = p_initial_state.clone()
	var snapshots: Array[CombatState] = []
	var events: Array[CombatEvent] = []

	working_state.player.begin_take()
	for enemy: EnemyState in working_state.enemies:
		enemy.begin_take()

	for frame: int in range(p_config.total_frames):
		BlockStartPhase.execute(working_state, p_plan, frame, p_config, events)
		MotionPhase.execute(working_state, p_plan, frame, p_config, events)
		EditPhase.execute(working_state, p_plan, frame, p_config, events)
		ActionPhase.execute(working_state, p_plan, frame, p_config, events)
		EnemyPhase.execute_attacks(working_state, p_plan, frame, events)
		EnemyPhase.tick_statuses(working_state, frame, p_config, events)
		snapshots.append(working_state.clone())

	return SimulationResult.new(p_initial_state, snapshots, events)
