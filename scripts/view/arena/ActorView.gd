@tool
class_name ActorView
extends Node2D

## Cutting-Room combatant view.
## Renders illustrated Subject #24 (cream coat & wide-brimmed hat) and charcoal hostiles,
## real-time idle breathing bob, tilted seafoam-acetate freeze slabs with fracture cracks,
## and cream/ink/vermilion enemy health bars.

const FIGURE_BASE_SCALE: float = 1.72

@export_group("Node References")
@export var custom_sprite: Sprite2D
@export var symbol_label: Label
@export var frozen_frames_label: Label
@export var hp_label: Label
@export var status_label: Label

@export_group("Cutting-Room Palette")
@export var paper_stock_color: Color = Color(0.902, 0.878, 0.820, 1.0)     # #e6e0d1
@export var ink_color: Color = Color(0.110, 0.114, 0.106, 1.0)             # #1c1d1b
@export var charcoal_body_color: Color = Color(0.165, 0.173, 0.165, 1.0)   # #2a2c2a
@export var cobalt_accent_color: Color = Color(0.290, 0.447, 0.784, 1.0)   # #4a72c8
@export var vermilion_color: Color = Color(0.761, 0.231, 0.169, 1.0)       # #c23b2b
@export var gold_tier_color: Color = Color(0.941, 0.863, 0.333, 1.0)       # #f0dc55
@export var acetate_freeze_fill: Color = Color(0.498, 0.749, 0.690, 0.52)  # #7fbfb0 @ 52%
@export var plum_status_color: Color = Color(0.541, 0.408, 0.722, 1.0)     # #8a68b8

var _actor_id: int = 0
var _is_player: bool = true
var _symbol: String = "24"
var _direction: Types.Direction = Types.Direction.SOUTH
var _hp: int = 14
var _max_hp: int = 14
var _shield: int = 0
var _is_frozen: bool = false
var _speed_tier: Types.SpeedTier = Types.SpeedTier.BASE


var actor_id: int:
	get: return _actor_id


func _process(_p_delta: float) -> void:
	if Engine.is_editor_hint() or not visible or _is_frozen:
		return
	queue_redraw()


func bind_player(p_player: PlayerState, p_world_position: Vector2) -> void:
	_actor_id = p_player.id
	visible = p_player.is_alive
	if not visible:
		return

	position = p_world_position
	z_index = p_player.grid_position.y
	_is_player = true
	_symbol = "24"
	_direction = p_player.direction
	_hp = p_player.hp
	_max_hp = maxi(1, p_player.max_hp)
	_shield = p_player.shield
	_is_frozen = p_player.is_frozen
	_speed_tier = p_player.tier

	_sync_labels(p_player.frozen_frames_remaining)
	if status_label != null:
		status_label.visible = _is_frozen
		if _is_frozen:
			status_label.text = "locked"
			status_label.modulate = vermilion_color
	queue_redraw()


func bind_enemy(p_enemy: EnemyState, p_world_position: Vector2) -> void:
	_actor_id = p_enemy.id
	visible = p_enemy.is_alive
	if not visible:
		return

	position = p_world_position
	z_index = p_enemy.grid_position.y
	_is_player = false
	_symbol = p_enemy.symbol
	_direction = p_enemy.direction
	_hp = p_enemy.hp
	_max_hp = maxi(1, p_enemy.max_hp)
	_shield = p_enemy.shield
	_is_frozen = p_enemy.is_frozen
	_speed_tier = Types.SpeedTier.BASE

	_sync_labels(p_enemy.frozen_frames_remaining)
	_apply_enemy_status_badge(p_enemy)
	queue_redraw()


func _draw() -> void:
	var bob_y: float = 0.0
	if not Engine.is_editor_hint() and not _is_frozen:
		var freq: float = 420.0 if _is_player else 380.0
		var phase: float = float(Time.get_ticks_msec()) / freq + float(_actor_id) * 1.7
		bob_y = sin(phase) * 2.4

	var fig_center: Vector2 = Vector2(0.0, 6.0 + bob_y)

	# 1. Subtle Speed Tier Ground Ring (Subject #24 at Tier 1+)
	if _is_player and _speed_tier > Types.SpeedTier.BASE:
		_draw_tier_aura(fig_center)

	# 2. Illustrated Silhouette (or CustomSprite if assigned)
	var has_custom_art: bool = custom_sprite != null and custom_sprite.texture != null
	if not has_custom_art:
		if _is_player:
			var alpha_mul: float = 0.55 if _is_frozen else 1.0
			ActorFigureRenderer.draw_subject_24(
				self,
				fig_center,
				_direction,
				FIGURE_BASE_SCALE,
				Color(paper_stock_color.r, paper_stock_color.g, paper_stock_color.b, alpha_mul),
				Color(ink_color.r, ink_color.g, ink_color.b, alpha_mul),
				Color(cobalt_accent_color.r, cobalt_accent_color.g, cobalt_accent_color.b, alpha_mul),
				true
			)
		else:
			ActorFigureRenderer.draw_enemy_figure(
				self,
				_symbol,
				fig_center,
				_direction,
				FIGURE_BASE_SCALE,
				charcoal_body_color,
				paper_stock_color,
				vermilion_color,
				true
			)

	# 3. Cobalt Shield Ring (if shielded)
	if _shield > 0:
		draw_arc(
			Vector2(0.0, 2.0 + bob_y),
			60.0,
			0.0,
			TAU,
			36,
			Color(cobalt_accent_color.r, cobalt_accent_color.g, cobalt_accent_color.b, 0.85),
			3.0,
			true
		)

	# 4. Tilted Seafoam-Acetate 24-Frame Freeze Slab with Fracture Lines
	if _is_frozen:
		_draw_acetate_freeze_block(fig_center)

	# 5. Enemy Top Health Bar (Cream Back + Ink Frame + Vermilion Fill)
	if not _is_player:
		_draw_enemy_health_bar()


# --- Private Helpers ---

func _sync_labels(p_frozen_frames: int) -> void:
	if symbol_label != null:
		symbol_label.visible = false

	if hp_label != null:
		hp_label.visible = false

	if frozen_frames_label != null:
		frozen_frames_label.visible = _is_frozen
		if _is_frozen:
			frozen_frames_label.text = "%df" % p_frozen_frames
			frozen_frames_label.modulate = ink_color


func _apply_enemy_status_badge(p_enemy: EnemyState) -> void:
	if status_label == null:
		return
	if p_enemy.is_dazed:
		status_label.visible = true
		status_label.modulate = ink_color
		status_label.text = "daze %df" % p_enemy.dazed_frames_remaining
	elif p_enemy.is_tagged_for_friendly_fire:
		status_label.visible = true
		status_label.modulate = plum_status_color
		status_label.text = "tagged"
	else:
		status_label.visible = false


func _draw_tier_aura(p_center: Vector2) -> void:
	var ring_col: Color = gold_tier_color if _speed_tier >= Types.SpeedTier.TIER_3 else cobalt_accent_color
	var count: int = int(_speed_tier)
	for i: int in range(count):
		var rx: float = 34.0 + float(i) * 7.0
		var ry: float = 12.0 + float(i) * 3.0
		var col: Color = Color(ring_col.r, ring_col.g, ring_col.b, 0.50 - float(i) * 0.12)
		var pts: PackedVector2Array = PackedVector2Array()
		for s_idx: int in range(25):
			var ang: float = TAU * float(s_idx) / 24.0
			pts.append(p_center + Vector2(0.0, 44.0) + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_polyline(pts, col, 2.0, true)


func _draw_acetate_freeze_block(p_center: Vector2) -> void:
	var s: float = FIGURE_BASE_SCALE
	draw_set_transform(p_center, -0.08, Vector2(s, s))

	var slab: Rect2 = Rect2(Vector2(-34.0, -42.0), Vector2(68.0, 78.0))
	draw_rect(slab, acetate_freeze_fill, true)
	# Offset vermilion chromatic grease-pencil registration mark
	draw_rect(
		Rect2(slab.position + Vector2(3.0, 3.0), slab.size),
		Color(vermilion_color.r, vermilion_color.g, vermilion_color.b, 0.65),
		false,
		2.0
	)
	draw_rect(slab, ink_color, false, 2.6)

	# White fracture cracks
	var crack_col: Color = Color(paper_stock_color.r, paper_stock_color.g, paper_stock_color.b, 0.90)
	draw_line(Vector2(-22.0, -38.0), Vector2(-4.0, -8.0), crack_col, 2.0, true)
	draw_line(Vector2(-10.0, -38.0), Vector2(4.0, -18.0), crack_col, 2.0, true)
	draw_line(Vector2(8.0, 30.0), Vector2(24.0, 2.0), crack_col, 2.0, true)
	draw_line(Vector2(4.0, 0.0), Vector2(-4.0, -8.0), crack_col, 2.0, true)
	draw_line(Vector2(-4.0, -8.0), Vector2(10.0, -6.0), crack_col, 2.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_enemy_health_bar() -> void:
	var bar_w: float = 104.0
	var bar_h: float = 12.0
	var outer_rect: Rect2 = Rect2(Vector2(-bar_w * 0.5, -69.0), Vector2(bar_w, bar_h))

	draw_rect(outer_rect, paper_stock_color, true)
	var ratio: float = clampf(float(_hp) / float(_max_hp), 0.0, 1.0)
	if ratio > 0.0:
		var inner_w: float = maxf(2.0, (bar_w - 4.0) * ratio)
		draw_rect(
			Rect2(outer_rect.position + Vector2(2.0, 2.0), Vector2(inner_w, bar_h - 4.0)),
			vermilion_color,
			true
		)
	draw_rect(outer_rect, ink_color, false, 2.2)
