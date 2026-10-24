class_name HeadlessTestRunner
extends RefCounted

## Orchestrates all headless simulation and encounter test suites.


static func run_all(p_config: CombatConfig) -> void:
	var start_usec: int = Time.get_ticks_usec()

	TestCoreSimulation.run_all(p_config)
	TestEditCards.run_all(p_config)
	TestEncounterLoop.run_all(p_config)

	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	print("[XXIV] ALL 8 HEADLESS SIMULATION SUITES PASSED in %d us (%.2f ms)!" % [
		elapsed_usec,
		float(elapsed_usec) / 1000.0
	])
