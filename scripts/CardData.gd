class_name CardData
extends Resource

@export_group("Identity")
@export var id: String = "palm"
@export var title: String = "Aperture Palm"
@export_multiline var description: String = "8 dmg adjacent. Shutter Freeze."
@export var family: Types.CardFamily = Types.CardFamily.ACTION
@export var is_upgraded: bool = false

@export_group("Timeline & Frame Data")
## Total duration on the timeline strip (1 to 24 frames)
@export_range(1, 24) var frame_cost: int = 4
## The specific frame offsets where strikes land (relative to card start frame)
@export var hit_frames: Array[int] = [2]

@export_group("Combat Attributes")
@export var base_damage: int = 8
@export var knockback_distance: int = 0
@export var moves_tiles: int = 0
@export var freezes_target: bool = true
@export var grants_shield: int = 0
