class_name Boot
extends Node

@export var build_version: String = "0.1.0-alpha"
@export var config: CombatConfig
@export var run_headless_tests_on_boot: bool = true

var _is_initialized: bool = false


func _ready() -> void:
	_initialize_game()


func _initialize_game() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	print("[XXIV] Engine online. Version: %s" % build_version)

	if config == null:
		config = CombatConfig.new()
		print("[XXIV] No CombatConfig assigned in Inspector; using default CombatConfig.")

	print("[XXIV] Config Loaded -> Frames: %d | Tier Thresholds: %d/%d/%df | Bleed Gap: %df" % [
		config.total_frames,
		config.tier_1_motion_threshold,
		config.tier_2_motion_threshold,
		config.tier_3_motion_threshold,
		config.momentum_bleed_idle_frames
	])

	if run_headless_tests_on_boot:
		HeadlessTestRunner.run_all(config)
