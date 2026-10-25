class_name ActorFigureRenderer
extends RefCounted

## Stateless vector renderer for Subject #24 and hostile combatant silhouettes.
## Shared by ActorView (live combatants) and ArenaView (cobalt motion afterimages & decoys).

const ELLIPSE_SEGMENTS: int = 28


static func draw_subject_24(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_dir: Types.Direction,
	p_scale: float,
	p_body_col: Color,
	p_rim_col: Color,
	p_accent_col: Color,
	p_draw_shadow: bool
) -> void:
	var s: float = p_scale * 1.04
	var d: Vector2 = Vector2(Types.to_vector(p_dir))

	p_canvas.draw_set_transform(p_center, 0.0, Vector2(s, s))

	if p_draw_shadow:
		_draw_filled_ellipse(p_canvas, Vector2(0.0, 30.0), 18.0, 6.0, Color(0.110, 0.114, 0.106, 0.28))

	# 1. Legs
	_draw_limb(p_canvas, Vector2(-5.0, 12.0), Vector2(-6.0, 27.0), 6.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(5.0, 12.0), Vector2(6.0, 27.0), 6.0, p_body_col, p_rim_col)

	# 2. Flared Mantis Trenchcoat & Center Lapel Seam
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([
			Vector2(-9.0, -12.0),
			Vector2(9.0, -12.0),
			Vector2(19.0, 26.0),
			Vector2(-19.0, 26.0),
		]),
		p_body_col,
		p_rim_col,
		2.6
	)
	var seam_col: Color = p_rim_col.lerp(Color(0.0, 0.0, 0.0, p_rim_col.a), 0.35)
	p_canvas.draw_line(Vector2(0.0, -10.0), Vector2(0.0, 24.0), seam_col, 1.6, true)

	# 3. Arms
	_draw_limb(p_canvas, Vector2(-9.0, -10.0), Vector2(-15.0, 8.0), 5.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(9.0, -10.0), Vector2(15.0, 8.0), 5.0, p_body_col, p_rim_col)

	# 4. Cobalt Collar Plate
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([
			Vector2(-8.0, -12.0),
			Vector2(8.0, -12.0),
			Vector2(4.0, -2.0),
			Vector2(-4.0, -2.0),
		]),
		p_accent_col,
		p_rim_col,
		1.6
	)

	# 5. Head, Hat Crown, Wide Hat Brim, Hatband & Directional Eye Dot
	_draw_outlined_circle(p_canvas, Vector2(0.0, -20.0), 8.0, p_body_col, p_rim_col, 2.6)
	_draw_outlined_poly(
		p_canvas,
		_make_round_rect(Rect2(Vector2(-8.0, -37.0), Vector2(16.0, 13.0)), 3.0),
		p_body_col,
		p_rim_col,
		2.6
	)
	_draw_outlined_ellipse(p_canvas, Vector2(0.0, -25.0), 17.0, 4.5, p_body_col, p_rim_col, 2.6)
	p_canvas.draw_line(Vector2(-8.0, -29.0), Vector2(8.0, -29.0), p_accent_col, 2.6, true)
	p_canvas.draw_circle(Vector2(d.x * 5.0, -19.0 + d.y * 3.0), 2.6, p_accent_col)

	p_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_enemy_figure(
	p_canvas: CanvasItem,
	p_symbol: String,
	p_center: Vector2,
	p_dir: Types.Direction,
	p_scale: float,
	p_body_col: Color,
	p_rim_col: Color,
	p_accent_col: Color,
	p_draw_shadow: bool
) -> void:
	var upper_sym: String = p_symbol.to_upper()
	if upper_sym == "H":
		_draw_hound(p_canvas, p_center, p_dir, p_scale * 0.92, p_body_col, p_rim_col, p_accent_col, p_draw_shadow)
	elif upper_sym == "S" or upper_sym == "W":
		_draw_sniper(p_canvas, p_center, p_dir, p_scale * 0.98, p_body_col, p_rim_col, p_accent_col, p_draw_shadow)
	else:
		_draw_cleaver(p_canvas, p_center, p_dir, p_scale * 1.02, p_body_col, p_rim_col, p_accent_col, p_draw_shadow)


# --- Archetype Silhouettes ---

static func _draw_hound(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_dir: Types.Direction,
	p_scale: float,
	p_body_col: Color,
	p_rim_col: Color,
	p_accent_col: Color,
	p_draw_shadow: bool
) -> void:
	if p_draw_shadow:
		p_canvas.draw_set_transform(p_center, 0.0, Vector2(p_scale, p_scale))
		_draw_filled_ellipse(p_canvas, Vector2(0.0, 30.0), 18.0, 6.0, Color(0.110, 0.114, 0.106, 0.28))

	var rot_rad: float = float(int(p_dir)) * (PI * 0.5)
	p_canvas.draw_set_transform(p_center, rot_rad, Vector2(p_scale, p_scale))

	# 4 splayed limbs + tail
	_draw_limb(p_canvas, Vector2(-9.0, -4.0), Vector2(-14.0, 8.0), 4.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(9.0, -4.0), Vector2(14.0, 8.0), 4.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(-8.0, 16.0), Vector2(-12.0, 28.0), 4.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(8.0, 16.0), Vector2(12.0, 28.0), 4.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(0.0, 22.0), Vector2(3.0, 36.0), 3.0, p_body_col, p_rim_col)

	# Sleek oval torso, pointed snout, ears & vermilion eyes
	_draw_outlined_ellipse(p_canvas, Vector2(0.0, 6.0), 12.0, 21.0, p_body_col, p_rim_col, 2.6)
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([Vector2(-9.0, -16.0), Vector2(0.0, -36.0), Vector2(9.0, -16.0)]),
		p_body_col,
		p_rim_col,
		2.6
	)
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([Vector2(-8.0, -17.0), Vector2(-12.0, -26.0), Vector2(-3.0, -21.0)]),
		p_body_col,
		p_rim_col,
		2.4
	)
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([Vector2(8.0, -17.0), Vector2(12.0, -26.0), Vector2(3.0, -21.0)]),
		p_body_col,
		p_rim_col,
		2.4
	)
	p_canvas.draw_circle(Vector2(-3.0, -24.0), 2.1, p_accent_col)
	p_canvas.draw_circle(Vector2(3.0, -24.0), 2.1, p_accent_col)

	p_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_cleaver(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_dir: Types.Direction,
	p_scale: float,
	p_body_col: Color,
	p_rim_col: Color,
	p_accent_col: Color,
	p_draw_shadow: bool
) -> void:
	var d: Vector2 = Vector2(Types.to_vector(p_dir))
	p_canvas.draw_set_transform(p_center, 0.0, Vector2(p_scale, p_scale))

	if p_draw_shadow:
		_draw_filled_ellipse(p_canvas, Vector2(0.0, 30.0), 19.0, 6.0, Color(0.110, 0.114, 0.106, 0.28))

	_draw_limb(p_canvas, Vector2(-6.0, 12.0), Vector2(-7.0, 27.0), 6.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(6.0, 12.0), Vector2(7.0, 27.0), 6.0, p_body_col, p_rim_col)

	# Broad armored torso & round pauldrons
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([
			Vector2(-16.0, -12.0),
			Vector2(16.0, -12.0),
			Vector2(13.0, 14.0),
			Vector2(-13.0, 14.0),
		]),
		p_body_col,
		p_rim_col,
		2.6
	)
	_draw_outlined_circle(p_canvas, Vector2(-17.0, -10.0), 6.0, p_body_col, p_rim_col, 2.6)
	_draw_outlined_circle(p_canvas, Vector2(17.0, -10.0), 6.0, p_body_col, p_rim_col, 2.6)
	_draw_limb(p_canvas, Vector2(-16.0, -8.0), Vector2(-19.0, 10.0), 6.0, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(16.0, -8.0), Vector2(19.0, 10.0), 6.0, p_body_col, p_rim_col)

	# Helmet & Visor Slit
	_draw_outlined_circle(p_canvas, Vector2(0.0, -21.0), 8.0, p_body_col, p_rim_col, 2.6)
	_draw_outlined_poly(p_canvas, _make_helmet_dome(10.0, -22.0), p_body_col, p_rim_col, 2.6)
	p_canvas.draw_rect(Rect2(Vector2(-7.0, -21.0), Vector2(14.0, 3.2)), p_accent_col, true)

	# Outstretched Directional Cleaver Arm
	_draw_limb(
		p_canvas,
		Vector2(d.x * 13.0, d.y * 13.0 + 2.0),
		Vector2(d.x * 35.0, d.y * 35.0 + 2.0),
		5.0,
		p_body_col,
		p_rim_col
	)
	p_canvas.draw_circle(Vector2(d.x * 36.0, d.y * 36.0 + 2.0), 3.5, p_accent_col)

	p_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_sniper(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_dir: Types.Direction,
	p_scale: float,
	p_body_col: Color,
	p_rim_col: Color,
	p_accent_col: Color,
	p_draw_shadow: bool
) -> void:
	var d: Vector2 = Vector2(Types.to_vector(p_dir))
	p_canvas.draw_set_transform(p_center, 0.0, Vector2(p_scale, p_scale))

	if p_draw_shadow:
		_draw_filled_ellipse(p_canvas, Vector2(0.0, 30.0), 17.0, 5.5, Color(0.110, 0.114, 0.106, 0.28))

	_draw_limb(p_canvas, Vector2(-4.0, 10.0), Vector2(-5.0, 27.0), 5.5, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(4.0, 10.0), Vector2(5.0, 27.0), 5.5, p_body_col, p_rim_col)

	# Long Warden Coat
	_draw_outlined_poly(
		p_canvas,
		PackedVector2Array([
			Vector2(-8.0, -14.0),
			Vector2(8.0, -14.0),
			Vector2(12.0, 26.0),
			Vector2(-12.0, 26.0),
		]),
		p_body_col,
		p_rim_col,
		2.6
	)
	_draw_limb(p_canvas, Vector2(-8.0, -12.0), Vector2(-12.0, 6.0), 4.5, p_body_col, p_rim_col)
	_draw_limb(p_canvas, Vector2(8.0, -12.0), Vector2(12.0, 6.0), 4.5, p_body_col, p_rim_col)

	# Narrow Head & Single Optic Lens
	_draw_outlined_circle(p_canvas, Vector2(0.0, -23.0), 6.5, p_body_col, p_rim_col, 2.6)
	p_canvas.draw_circle(Vector2(0.0, -23.0), 2.5, p_accent_col)

	# Directional Long Rifle Barrel
	_draw_limb(
		p_canvas,
		Vector2(d.x * 5.0, d.y * 5.0 - 2.0),
		Vector2(d.x * 40.0, d.y * 40.0 - 2.0),
		4.0,
		p_body_col,
		p_rim_col
	)
	p_canvas.draw_circle(Vector2(d.x * 40.5, d.y * 40.5 - 2.0), 3.4, p_accent_col)

	p_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Low-Level Vector Primitives ---

static func _draw_limb(
	p_canvas: CanvasItem,
	p_from: Vector2,
	p_to: Vector2,
	p_width: float,
	p_body_col: Color,
	p_rim_col: Color
) -> void:
	var outer_w: float = p_width + 2.6
	p_canvas.draw_line(p_from, p_to, p_rim_col, outer_w, true)
	p_canvas.draw_circle(p_from, outer_w * 0.5, p_rim_col)
	p_canvas.draw_circle(p_to, outer_w * 0.5, p_rim_col)

	var inner_col: Color = p_body_col.lerp(Color(0.0, 0.0, 0.0, p_body_col.a), 0.25)
	p_canvas.draw_line(p_from, p_to, inner_col, p_width, true)
	p_canvas.draw_circle(p_from, p_width * 0.5, inner_col)
	p_canvas.draw_circle(p_to, p_width * 0.5, inner_col)


static func _draw_outlined_poly(
	p_canvas: CanvasItem,
	p_pts: PackedVector2Array,
	p_fill_col: Color,
	p_rim_col: Color,
	p_rim_width: float
) -> void:
	if p_pts.size() < 3:
		return
	p_canvas.draw_colored_polygon(p_pts, p_fill_col)
	var closed: PackedVector2Array = p_pts.duplicate()
	closed.append(p_pts[0])
	p_canvas.draw_polyline(closed, p_rim_col, p_rim_width, true)
	for pt: Vector2 in p_pts:
		p_canvas.draw_circle(pt, p_rim_width * 0.5, p_rim_col)


static func _draw_outlined_circle(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_radius: float,
	p_fill_col: Color,
	p_rim_col: Color,
	p_rim_width: float
) -> void:
	p_canvas.draw_circle(p_center, p_radius, p_fill_col)
	p_canvas.draw_arc(p_center, p_radius, 0.0, TAU, ELLIPSE_SEGMENTS, p_rim_col, p_rim_width, true)


static func _draw_filled_ellipse(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_rx: float,
	p_ry: float,
	p_fill_col: Color
) -> void:
	p_canvas.draw_colored_polygon(_make_ellipse_pts(p_center, p_rx, p_ry), p_fill_col)


static func _draw_outlined_ellipse(
	p_canvas: CanvasItem,
	p_center: Vector2,
	p_rx: float,
	p_ry: float,
	p_fill_col: Color,
	p_rim_col: Color,
	p_rim_width: float
) -> void:
	var pts: PackedVector2Array = _make_ellipse_pts(p_center, p_rx, p_ry)
	p_canvas.draw_colored_polygon(pts, p_fill_col)
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	p_canvas.draw_polyline(closed, p_rim_col, p_rim_width, true)


static func _make_ellipse_pts(p_center: Vector2, p_rx: float, p_ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(ELLIPSE_SEGMENTS):
		var angle: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
		pts.append(p_center + Vector2(cos(angle) * p_rx, sin(angle) * p_ry))
	return pts


static func _make_round_rect(p_rect: Rect2, p_radius: float) -> PackedVector2Array:
	var r: float = minf(p_radius, minf(p_rect.size.x, p_rect.size.y) * 0.5)
	var x0: float = p_rect.position.x
	var y0: float = p_rect.position.y
	var x1: float = p_rect.end.x
	var y1: float = p_rect.end.y
	return PackedVector2Array([
		Vector2(x0 + r, y0),
		Vector2(x1 - r, y0),
		Vector2(x1, y0 + r),
		Vector2(x1, y1 - r),
		Vector2(x1 - r, y1),
		Vector2(x0 + r, y1),
		Vector2(x0, y1 - r),
		Vector2(x0, y0 + r),
	])


static func _make_helmet_dome(p_radius: float, p_y: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var arc_steps: int = 12
	for i: int in range(arc_steps + 1):
		var angle: float = PI + PI * float(i) / float(arc_steps)
		pts.append(Vector2(cos(angle) * p_radius, p_y + sin(angle) * p_radius))
	pts.append(Vector2(p_radius, p_y + 4.0))
	pts.append(Vector2(-p_radius, p_y + 4.0))
	return pts
