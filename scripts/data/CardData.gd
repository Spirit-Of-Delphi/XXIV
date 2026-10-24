class_name CardData
extends Resource

## Data-driven definition for a single card in Subject #24's deck.
## Uses composable Inspector properties rather than hardcoded card-ID enums.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var family: Types.CardFamily = Types.CardFamily.MOTION

@export_group("Timeline & Deck Lifecycle")
@export_range(1, 24) var frame_cost: int = 4
@export var exhausts_on_play: bool = false
@export var retains_in_hand: bool = false

@export_group("Motion Mechanics (Track 0)")
## 0-indexed local frames within the block where the player steps 1 tile.
@export var step_frames: Array[int] = []
## Optional override for step_frames when played at SpeedTier.TIER_3.
@export var tier_3_step_frames: Array[int] = []
## If true (e.g. Pivot), suppresses the 180-degree instantaneous reversal violation.
@export var allows_180_turn: bool = false

@export_group("Action Mechanics (Track 1)")
## 0-indexed local frames within the block where a strike hits.
@export var hit_frames: Array[int] = []
@export_range(0, 99) var base_damage: int = 0
@export var freezes_target: bool = false
@export_range(0, 6) var knockback_distance: int = 0
## Granted on frame 0 of the block (BlockStartPhase).
@export_range(0, 99) var grants_shield: int = 0

@export_group("Edit & Splice Mechanics (Either Track)")
## 0-indexed local frames within the block where Edit/Splice effects trigger.
@export var edit_frames: Array[int] = []
## Dutch Angle: Rotates target enemy and its AttackIntents 90 degrees CW (EAST) or CCW (WEST).
@export var rotates_target_90: bool = false
## Slip: Shifts target enemy's AttackIntent windows by +/- N frames (WEST = earlier, EAST = later).
@export_range(0, 24) var slip_intent_frames: int = 0
## Hold Frame: Locks player movement/strikes for the full block and phase-dodges enemy hits on edit_frames.
@export var holds_frame_and_dodges: bool = false
## Negative Exposure: Stamps an optical decoy at the player's current tile on edit_frames.
@export var places_decoy: bool = false
## Rewind: Snaps player back to take_start_position on edit_frames if unoccupied and unblocked.
@export var rewinds_to_start: bool = false
## Develop: Restores HP to the player on edit_frames.
@export_range(0, 99) var heals_hp: int = 0
## Swap: Exchanges grid positions with a selected Frozen enemy on edit_frames.
@export var swaps_with_frozen: bool = false
## Tag: Marks an adjacent enemy in block.direction on edit_frames to take friendly-fire damage this take.
@export var tags_for_friendly_fire: bool = false


# --- UI & Targeting Queries ---

## True if placing this card requires choosing a 4-way cardinal arena direction (N/E/S/W).
func requires_cardinal_direction() -> bool:
	if family == Types.CardFamily.MOTION:
		return true
	if family == Types.CardFamily.ACTION and not hit_frames.is_empty():
		return true
	return tags_for_friendly_fire


## True if placing this card requires a binary West/East toggle (CCW/CW or Earlier/Later).
func requires_timeline_direction() -> bool:
	return rotates_target_90 or slip_intent_frames > 0


## True if placing this card requires selecting an enemy on the board (target_enemy_id).
func requires_enemy_target() -> bool:
	return rotates_target_90 or slip_intent_frames > 0 or swaps_with_frozen


## True if the selected enemy target must currently be Frozen (Swap).
func requires_frozen_enemy_target() -> bool:
	return swaps_with_frozen
