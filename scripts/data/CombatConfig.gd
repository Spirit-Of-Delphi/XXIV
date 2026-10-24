class_name CombatConfig
extends Resource

## Central balance and rules configuration for XXIV.
## Edit res://data/DefaultCombatConfig.tres in the Inspector to tune gameplay.

@export_group("Timeline & Arena")
@export_range(1, 60) var total_frames: int = 24
@export_range(3, 12) var default_grid_size: int = 6
@export_range(1, 100) var player_max_hp: int = 14

@export_group("Deck & Hand")
@export_range(1, 12) var cards_drawn_per_take: int = 6
@export_range(1, 15) var max_hand_size: int = 10

@export_group("Speed Tier Thresholds")
@export_range(1, 24) var tier_1_motion_threshold: int = 12
@export_range(1, 24) var tier_2_motion_threshold: int = 18
@export_range(1, 24) var tier_3_motion_threshold: int = 24
## Consecutive non-motion frames before bleeding down 1 tier
@export_range(1, 24) var momentum_bleed_idle_frames: int = 12

@export_group("Speed Tier Benefits")
## Max frames after a motion frame where a strike still triggers Flow (Tier 1 & Tier 2)
@export_range(0, 24) var tier_1_flow_window_frames: int = 3
@export_range(0, 24) var tier_2_flow_window_frames: int = 5
@export_range(0, 10) var flow_bonus_damage: int = 3
@export_range(0, 6) var tier_3_motion_cost_reduction: int = 3
@export_range(1, 4) var minimum_card_cost: int = 1

@export_group("Collision & Violation Damage (Indexed by Tier 0..3)")
## Self-damage when dashing into an unfrozen enemy at [T0, T1, T2, T3]
@export var dash_unfrozen_self_damage: Array[int] = [0, 2, 4, 6]
## Enemy damage when dashing into a frozen enemy at [T0, T1, T2, T3]
@export var dash_frozen_enemy_damage: Array[int] = [2, 4, 8, 12]
## Self-damage when dashing into a wall or pit at [T0, T1, T2, T3]
@export var dash_wall_self_damage: Array[int] = [2, 4, 6, 10]
## Self-damage when making an illegal 180-degree turn at [T0, T1, T2, T3]
@export var turn_180_self_damage: Array[int] = [0, 0, 2, 4]
## Bonus damage when an actor is knocked into a solid wall or blocked tile
@export_range(0, 20) var wall_slam_damage: int = 3
## If true, crashing into an interior wall tile at Tier 3 destroys the wall
@export var tier_3_dash_breaks_walls: bool = true

@export_group("Freeze, Thaw & Match Cut")
@export_range(0.1, 5.0, 0.1) var freeze_duration_seconds: float = 1.0
@export_range(0, 24) var thaw_daze_max_frames: int = 6
@export_range(1, 24) var thaw_scramble_duration_frames: int = 4
@export_range(1, 10) var thaw_scramble_damage: int = 1
@export_range(1.0, 3.0, 0.1) var match_cut_damage_multiplier: float = 1.5
@export_range(0, 12) var match_cut_bonus_motion_frames: int = 2
@export_range(0, 20) var frozen_strike_bonus_damage: int = 4


# --- Computed Properties & Safe Lookup Helpers ---

var freeze_frames: int:
	get: return roundi(freeze_duration_seconds * total_frames)


## Returns the motion frames needed in a single take to promote from p_current_tier.
## Returns -1 if already at max tier (TIER_3).
func get_promotion_threshold(p_current_tier: Types.SpeedTier) -> int:
	match p_current_tier:
		Types.SpeedTier.BASE:
			return tier_1_motion_threshold
		Types.SpeedTier.TIER_1:
			return tier_2_motion_threshold
		Types.SpeedTier.TIER_2:
			return tier_3_motion_threshold
		_:
			return -1


func get_flow_window_frames(p_tier: Types.SpeedTier) -> int:
	match p_tier:
		Types.SpeedTier.TIER_1:
			return tier_1_flow_window_frames
		Types.SpeedTier.TIER_2:
			return tier_2_flow_window_frames
		_:
			return 0


func get_dash_unfrozen_self_damage(p_tier: Types.SpeedTier) -> int:
	return _get_tier_value(dash_unfrozen_self_damage, p_tier)


func get_dash_frozen_enemy_damage(p_tier: Types.SpeedTier) -> int:
	return _get_tier_value(dash_frozen_enemy_damage, p_tier)


func get_dash_wall_self_damage(p_tier: Types.SpeedTier) -> int:
	return _get_tier_value(dash_wall_self_damage, p_tier)


func get_turn_180_self_damage(p_tier: Types.SpeedTier) -> int:
	return _get_tier_value(turn_180_self_damage, p_tier)


func _get_tier_value(p_table: Array[int], p_tier: Types.SpeedTier) -> int:
	if p_table.is_empty():
		return 0
	var idx: int = clampi(int(p_tier), 0, p_table.size() - 1)
	return p_table[idx]
