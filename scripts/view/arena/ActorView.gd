class_name ActorView
extends Node2D

## Visual Node2D representation of Subject #24 or an EnemyState on the Arena grid.
## Purely driven by state snapshots; never mutates simulation state.

const DEGREES_PER_CARDINAL_STEP: float = 90.0
const PLAYER_SYMBOL: String = "24"

@export_group("Node References")
@export var tier_aura: CanvasItem
@export var body_visual: CanvasItem
@export var facing_pivot: Node2D
@export var symbol_label: Label
@export var frozen_overlay: CanvasItem
@export var frozen_frames_label: Label
@export var hp_label: Label
@export var status_label: Label

@export_group("Palette")
@export var player_base_color: Color = Color(0.20, 0.78, 0.62, 1.0)
@export var tier_1_aura_color: Color = Color(0.35, 0.85, 1.0, 0.55)
@export var tier_2_aura_color: Color = Color(1.0, 0.78, 0.22, 0.65)
@export var tier_3_aura_color: Color = Color(1.0, 0.28, 0.45, 0.80)
@export var enemy_default_color: Color = Color(0.86, 0.30, 0.32, 1.0)
@export var dazed_status_color: Color = Color(1.0, 0.82, 0.25, 1.0)
@export var tagged_status_color: Color = Color(1.0, 0.38, 0.15, 1.0)

var _actor_id: int = -1


var actor_id: int:
	get: return _actor_id


## Updates this view to match Subject #24's snapshot state.
func bind_player(p_player: PlayerState, p_world_position: Vector2) -> void:
	_actor_id = p_player.id
	visible = p_player.is_alive
	if not visible:
		return

	position = p_world_position
	_apply_facing(p_player.direction)
	_apply_body_tint(player_base_color)
	_apply_symbol(PLAYER_SYMBOL)
	_apply_hp_and_shield(p_player.hp, p_player.max_hp, p_player.shield)
	_apply_frozen_state(p_player.is_frozen, p_player.frozen_frames_remaining)
	_apply_player_tier_aura(p_player.tier)

	if status_label != null:
		status_label.visible = false


## Updates this view to match an EnemyState snapshot.
func bind_enemy(p_enemy: EnemyState, p_world_position: Vector2) -> void:
	_actor_id = p_enemy.id
	visible = p_enemy.is_alive
	if not visible:
		return

	position = p_world_position
	_apply_facing(p_enemy.direction)
	_apply_body_tint(enemy_default_color)
	_apply_symbol(p_enemy.symbol)
	_apply_hp_and_shield(p_enemy.hp, p_enemy.max_hp, p_enemy.shield)
	_apply_frozen_state(p_enemy.is_frozen, p_enemy.frozen_frames_remaining)

	if tier_aura != null:
		tier_aura.visible = false

	_apply_enemy_status_badge(p_enemy)


# --- Private Visual Helpers ---

func _apply_facing(p_direction: Types.Direction) -> void:
	if facing_pivot != null:
		facing_pivot.rotation_degrees = float(int(p_direction)) * DEGREES_PER_CARDINAL_STEP


func _apply_body_tint(p_color: Color) -> void:
	if body_visual != null:
		body_visual.self_modulate = p_color


func _apply_symbol(p_text: String) -> void:
	if symbol_label != null:
		symbol_label.text = p_text


func _apply_hp_and_shield(p_hp: int, p_max_hp: int, p_shield: int) -> void:
	if hp_label == null:
		return
	if p_shield > 0:
		hp_label.text = "%d/%d +%d" % [p_hp, p_max_hp, p_shield]
	else:
		hp_label.text = "%d/%d" % [p_hp, p_max_hp]


func _apply_frozen_state(p_is_frozen: bool, p_frames_remaining: int) -> void:
	if frozen_overlay != null:
		frozen_overlay.visible = p_is_frozen
	if frozen_frames_label != null:
		frozen_frames_label.visible = p_is_frozen
		if p_is_frozen:
			frozen_frames_label.text = "%df" % p_frames_remaining


func _apply_player_tier_aura(p_tier: Types.SpeedTier) -> void:
	if tier_aura == null:
		return
	match p_tier:
		Types.SpeedTier.TIER_1:
			tier_aura.visible = true
			tier_aura.self_modulate = tier_1_aura_color
		Types.SpeedTier.TIER_2:
			tier_aura.visible = true
			tier_aura.self_modulate = tier_2_aura_color
		Types.SpeedTier.TIER_3:
			tier_aura.visible = true
			tier_aura.self_modulate = tier_3_aura_color
		_:
			tier_aura.visible = false


func _apply_enemy_status_badge(p_enemy: EnemyState) -> void:
	if status_label == null:
		return
	if p_enemy.is_dazed:
		status_label.visible = true
		status_label.modulate = dazed_status_color
		status_label.text = "DAZE %df" % p_enemy.dazed_frames_remaining
	elif p_enemy.is_tagged_for_friendly_fire:
		status_label.visible = true
		status_label.modulate = tagged_status_color
		status_label.text = "TAGGED"
	else:
		status_label.visible = false
