class_name CombatConfig
extends Resource

## Central balance configuration for XXIV. 
## Tweakable in the Godot Inspector without touching a single line of code.

@export_group("Timeline & Cadence")
## Number of frames in a single take (default: 24 = 1 second)
@export_range(12, 48) var total_frames: int = 24

@export_group("Momentum & Tiers (Projection)")
## Motion frames required in a single take to activate Tier 1
@export_range(6, 24) var tier_1_motion_threshold: int = 12
## Consecutive idle frames on the motion track before momentum bleeds down 1 tier
@export_range(2, 16) var momentum_bleed_idle_frames: int = 8

@export_group("Freeze & Thaw Mechanics")
## Base duration of a freeze in seconds (1.0s = 24 frames)
@export_range(0.5, 3.0) var freeze_duration_seconds: float = 1.0
## Maximum frames an enemy remains dazed after thawing
@export_range(2, 12) var thaw_daze_max_frames: int = 6

@export_group("Arena & Grid Rules")
## Playable arena width and height (6x6)
@export_range(4, 12) var default_grid_size: int = 6
