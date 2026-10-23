class_name Boot
extends Node

@export var build_version: String = "0.1.0-alpha"
@export var config: CombatConfig
@export var test_card: CardData

var _is_initialized: bool = false


func _ready() -> void:
	_initialize_game()


func _initialize_game() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	print("[XXIV] Engine online. Version: %s" % build_version)
	
	if config == null:
		push_error("[XXIV] No CombatConfig assigned to Boot node!")
		return
		
	print("[XXIV] Config Loaded -> Frames: %d | Tier 1 Threshold: %df | Bleed Gap: %df" % [
		config.total_frames,
		config.tier_1_motion_threshold,
		config.momentum_bleed_idle_frames
	])
	
	_test_timeline_plan()


func _test_timeline_plan() -> void:
	# Inject the config resource directly!
	var plan: TimelinePlan = TimelinePlan.new(config)
	
	var dash: CardData = CardData.new()
	dash.id = "dash"
	dash.family = Types.CardFamily.MOTION
	dash.frame_cost = 6
	
	# Place two 6-frame dashes (12 frames total)
	plan.add_block(TimelineBlock.new(dash, TimelinePlan.TRACK_MOTION, 0))
	plan.add_block(TimelineBlock.new(dash, TimelinePlan.TRACK_MOTION, 6))
	
	print("[XXIV] Scheduled Motion: %d frames (Qualifies for Tier 1: %s)" % [
		plan.total_motion_frames,
		plan.qualifies_for_tier_1
	])
	print("[XXIV] Contains Bleed Gap: %s" % plan.has_momentum_bleed_gap())
	
	assert(plan.qualifies_for_tier_1, "Should qualify for Tier 1 based on config threshold!")
	assert(plan.has_momentum_bleed_gap(), "Should detect momentum bleed based on config idle gap!")
	print("[XXIV] Config-driven TimelinePlan test PASSED!")
