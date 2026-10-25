class_name RunOverlayView
extends CanvasLayer

## Self-building Cutting-Room Bench UI shell for XXIV.
## Renders the Main Menu (with animated 16mm film leader + Debug/Showcase Level Picker),
## Loadout Picker, Silent-Film Intertitles, Action Replay Banner, Card Reward Draft,
## Path Fork, Rest/Upgrade Booth, Deck & Rules Modals, and Victory / Game Over screens.

signal descend_requested()
signal archetype_picked(p_archetype_id: String)
signal debug_scene_selected(p_scene_number: int, p_node_kind: RunDirector.NodeKind)
signal return_to_title_requested()
signal scene_intro_dismissed()
signal replay_skip_requested()
signal scene_wrap_continued()
signal reward_card_chosen(p_card: CardData)
signal reward_skipped()
signal path_chosen(p_node_kind: RunDirector.NodeKind)
signal rest_heal_chosen()
signal rest_upgrade_chosen(p_deck_index: int)
signal play_again_requested()
signal overlay_blocking_changed(p_is_blocking: bool)

const BENCH_THEME: Theme = preload("res://scenes/ui/XXIVTheme.tres")
const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/ui/CardView.tscn")

const COL_BENCH: Color = Color(0.173, 0.200, 0.188, 1.0)     # #2c3330
const COL_WELL: Color = Color(0.137, 0.161, 0.153, 1.0)      # #232927
const COL_RULE: Color = Color(0.275, 0.318, 0.294, 1.0)      # #46514b
const COL_RULE2: Color = Color(0.365, 0.412, 0.388, 1.0)     # #5d6963
const COL_STOCK: Color = Color(0.902, 0.878, 0.820, 1.0)     # #e6e0d1
const COL_STOCK_HOV: Color = Color(0.945, 0.922, 0.867, 1.0)
const COL_EDGE: Color = Color(0.718, 0.686, 0.604, 1.0)      # #b7af9a
const COL_INK: Color = Color(0.110, 0.114, 0.106, 1.0)       # #1c1d1b
const COL_BODY_INK: Color = Color(0.200, 0.196, 0.173, 1.0)  # #33322c
const COL_SOFT: Color = Color(0.678, 0.714, 0.690, 1.0)      # #adb6b0
const COL_MUTE: Color = Color(0.545, 0.584, 0.561, 1.0)      # #8b958f
const COL_VERMILION: Color = Color(0.761, 0.231, 0.169, 1.0) # #c23b2b
const COL_DANGER: Color = Color(0.933, 0.478, 0.404, 1.0)    # #ee7a67
const COL_GOLD: Color = Color(0.941, 0.863, 0.333, 1.0)      # #f0dc55
const COL_ACETATE: Color = Color(0.498, 0.749, 0.690, 1.0)   # #7fbfb0
const COL_SLATE_BG: Color = Color(0.051, 0.051, 0.047, 1.0)  # #0d0d0c


class _FilmLeaderEmblem extends Control:
	var _anim_t: float = 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(236.0, 236.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func restart_pencil_anim() -> void:
		_anim_t = 0.0
		queue_redraw()

	func _process(p_delta: float) -> void:
		if _anim_t < 1.35:
			_anim_t = minf(1.35, _anim_t + p_delta)
			queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var outer_r: float = 104.0
		var inner_r: float = 76.0

		draw_arc(center, outer_r, 0.0, TAU, 64, COL_RULE2, 1.5, true)

		var dash_steps: int = 48
		for i: int in range(dash_steps):
			if (i % 2) == 0:
				var a0: float = TAU * float(i) / float(dash_steps)
				var a1: float = TAU * float(i + 1) / float(dash_steps)
				draw_arc(center, inner_r, a0, a1, 4, COL_RULE2, 1.2, true)

		for k: int in range(24):
			var ang: float = TAU * float(k) / 24.0 - PI * 0.5
			var r1: float = 88.0 if (k % 6) == 0 else 96.0
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			draw_line(center + dir * r1, center + dir * outer_r, COL_RULE2, 1.5, true)

		draw_line(center + Vector2(0.0, -116.0), center + Vector2(0.0, -90.0), COL_RULE2, 1.5, true)
		draw_line(center + Vector2(0.0, 90.0), center + Vector2(0.0, 116.0), COL_RULE2, 1.5, true)
		draw_line(center + Vector2(-116.0, 0.0), center + Vector2(-90.0, 0.0), COL_RULE2, 1.5, true)
		draw_line(center + Vector2(90.0, 0.0), center + Vector2(116.0, 0.0), COL_RULE2, 1.5, true)

		# Animated vermilion grease-pencil oval loop
		var progress: float = clampf((_anim_t - 0.15) / 1.05, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var seg_total: int = 56
		var seg_drawn: int = roundi(float(seg_total) * eased)
		if seg_drawn >= 2:
			var pts: PackedVector2Array = PackedVector2Array()
			for s: int in range(seg_drawn + 1):
				var t: float = float(s) / float(seg_total)
				var a: float = -PI * 0.88 + t * (TAU * 1.06)
				var rx: float = 95.0 + sin(t * 9.0) * 2.5
				var ry: float = 46.0 + cos(t * 7.0) * 2.0
				pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
			draw_polyline(pts, COL_VERMILION, 4.2, true)

		var font: Font = get_theme_default_font()
		if font == null:
			font = ThemeDB.fallback_font
		if font != null:
			var font_sz: int = 54
			var ascent: float = font.get_ascent(font_sz)
			var descent: float = font.get_descent(font_sz)
			var base_y: float = center.y + (ascent - descent) * 0.5
			draw_string(
				font,
				Vector2(0.0, base_y),
				"XXIV",
				HORIZONTAL_ALIGNMENT_CENTER,
				size.x,
				font_sz,
				COL_STOCK
			)


class _PaperSlabCard extends Button:
	var _heading_text: String = ""
	var _subtitle_text: String = ""
	var _highlight_text: String = ""
	var _footer_text: String = ""
	var _accent_strip_color: Color = COL_VERMILION

	func _init(
		p_heading: String,
		p_subtitle: String,
		p_highlight: String,
		p_footer: String,
		p_accent: Color = COL_VERMILION
	) -> void:
		_heading_text = p_heading
		_subtitle_text = p_subtitle
		_highlight_text = p_highlight
		_footer_text = p_footer
		_accent_strip_color = p_accent
		flat = true
		text = ""
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(320.0, 250.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		add_theme_stylebox_override("normal", empty)
		add_theme_stylebox_override("hover", empty)
		add_theme_stylebox_override("pressed", empty)
		add_theme_stylebox_override("focus", empty)

		var margin: MarginContainer = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 18)
		add_child(margin)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		var h_lbl: Label = Label.new()
		h_lbl.text = _heading_text
		h_lbl.add_theme_font_size_override("font_size", 24)
		h_lbl.modulate = COL_INK
		vbox.add_child(h_lbl)

		var sub_lbl: Label = Label.new()
		sub_lbl.text = _subtitle_text
		sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub_lbl.add_theme_font_size_override("font_size", 14)
		sub_lbl.modulate = COL_BODY_INK
		vbox.add_child(sub_lbl)

		if not _highlight_text.is_empty():
			var hi_lbl: Label = Label.new()
			hi_lbl.text = _highlight_text
			hi_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hi_lbl.add_theme_font_size_override("font_size", 14)
			hi_lbl.modulate = COL_INK
			vbox.add_child(hi_lbl)

		if not _footer_text.is_empty():
			var spacer: Control = Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(spacer)

			var divider: ColorRect = ColorRect.new()
			divider.custom_minimum_size = Vector2(0.0, 1.0)
			divider.color = COL_EDGE
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(divider)

			var ft_lbl: Label = Label.new()
			ft_lbl.text = _footer_text
			ft_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ft_lbl.add_theme_font_size_override("font_size", 12)
			ft_lbl.modulate = Color(0.28, 0.26, 0.22, 1.0)
			vbox.add_child(ft_lbl)

	func _notification(p_what: int) -> void:
		if p_what == NOTIFICATION_MOUSE_ENTER or p_what == NOTIFICATION_MOUSE_EXIT or p_what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var hov: bool = is_hovered()
		var lift: Vector2 = Vector2(-1.5, -1.5) if hov else Vector2.ZERO
		var body_sz: Vector2 = Vector2(maxf(40.0, size.x - 4.0), maxf(40.0, size.y - 4.0))
		var rect: Rect2 = Rect2(lift, body_sz)
		var sh_off: Vector2 = Vector2(4.0, 4.0) if hov else Vector2(3.0, 3.0)

		draw_rect(Rect2(rect.position + sh_off, rect.size), Color(0.0, 0.0, 0.0, 0.45), true)
		draw_rect(rect, COL_STOCK_HOV if hov else COL_STOCK, true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), _accent_strip_color, true)
		draw_rect(rect, COL_EDGE, false, 1.0)


class _SilentSlateControl extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), COL_SLATE_BG, true)
		if size.x > 80.0 and size.y > 80.0:
			draw_rect(
				Rect2(Vector2(20.0, 20.0), size - Vector2(40.0, 40.0)),
				Color(COL_STOCK.r, COL_STOCK.g, COL_STOCK.b, 0.50),
				false,
				1.0
			)
			draw_rect(
				Rect2(Vector2(27.0, 27.0), size - Vector2(54.0, 54.0)),
				Color(COL_STOCK.r, COL_STOCK.g, COL_STOCK.b, 0.24),
				false,
				1.0
			)


var _root: Control
var _top_toolbar: HBoxContainer
var _jump_btn: Button
var _deck_btn: Button
var _rules_btn: Button
var _menu_btn: Button

var _replay_bar: PanelContainer
var _replay_label: Label

var _page_backdrop: ColorRect
var _page_body: VBoxContainer

var _slate_root: _SilentSlateControl
var _slate_top_label: Label
var _slate_title_label: Label
var _slate_sub_label: Label
var _slate_continue_btn: ExecuteButton
var _slate_is_intro: bool = false
var _intro_timer: float = 0.0

var _modal_backdrop: ColorRect
var _modal_title_label: Label
var _modal_body: VBoxContainer

var _cached_deck: Array[CardData] = []
var _active_reward_cards: Array[CardData] = []
var _cached_total_scenes: int = 8
var _cached_scene_notes: Array[String] = []
var _cached_boss_flags: Array[bool] = []


func _ready() -> void:
	layer = 10
	_build_shell_hierarchy()
	hide_all_overlays()


func _process(p_delta: float) -> void:
	if _slate_root != null and _slate_root.visible and _slate_is_intro:
		_intro_timer -= p_delta
		if _intro_timer <= 0.0:
			_dismiss_intro_slate()


func _input(p_event: InputEvent) -> void:
	if p_event is InputEventKey:
		var key_ev: InputEventKey = p_event as InputEventKey
		if not key_ev.pressed or key_ev.echo:
			return

		if key_ev.keycode == KEY_F2:
			if _modal_backdrop != null and _modal_backdrop.visible:
				_close_modal()
			else:
				show_debug_modal()
			get_viewport().set_input_as_handled()
			return

		if _modal_backdrop != null and _modal_backdrop.visible:
			if key_ev.keycode == KEY_ESCAPE:
				_close_modal()
				get_viewport().set_input_as_handled()
			return

		if _slate_root != null and _slate_root.visible:
			if key_ev.keycode == KEY_SPACE or key_ev.keycode == KEY_ENTER or key_ev.keycode == KEY_ESCAPE:
				if _slate_is_intro:
					_dismiss_intro_slate()
				else:
					_on_wrap_continue_pressed()
				get_viewport().set_input_as_handled()
			return

		if _replay_bar != null and _replay_bar.visible:
			if key_ev.keycode == KEY_SPACE or key_ev.keycode == KEY_ESCAPE or key_ev.keycode == KEY_ENTER:
				replay_skip_requested.emit()
				get_viewport().set_input_as_handled()
			return

		if _page_backdrop != null and _page_backdrop.visible and not _active_reward_cards.is_empty():
			if key_ev.keycode >= KEY_1 and key_ev.keycode <= KEY_3:
				var r_idx: int = int(key_ev.keycode) - int(KEY_1)
				if r_idx < _active_reward_cards.size():
					var picked: CardData = _active_reward_cards[r_idx]
					_active_reward_cards.clear()
					reward_card_chosen.emit(picked)
					get_viewport().set_input_as_handled()


# --- Public Configuration & Screen Transitions ---

func configure_debug_catalog(
	p_total_scenes: int,
	p_scene_notes: Array[String],
	p_boss_flags: Array[bool]
) -> void:
	_cached_total_scenes = maxi(1, p_total_scenes)
	_cached_scene_notes = p_scene_notes.duplicate()
	_cached_boss_flags = p_boss_flags.duplicate()


func hide_all_overlays() -> void:
	_active_reward_cards.clear()
	if _page_backdrop != null:
		_page_backdrop.visible = false
	if _slate_root != null:
		_slate_root.visible = false
	if _modal_backdrop != null:
		_modal_backdrop.visible = false
	if _replay_bar != null:
		_replay_bar.visible = false
	_emit_blocking_state()


func set_top_toolbar_visible(
	p_visible: bool,
	p_deck: Array[CardData] = [],
	p_is_debug: bool = false
) -> void:
	_cached_deck = p_deck.duplicate()
	if _top_toolbar != null:
		_top_toolbar.visible = p_visible
	if _jump_btn != null:
		_jump_btn.visible = p_is_debug
	if _deck_btn != null:
		_deck_btn.text = "Deck (%d)" % _cached_deck.size()


func show_main_menu(p_best_scene: int, p_total_scenes: int, p_best_score: int) -> void:
	hide_all_overlays()
	set_top_toolbar_visible(false)
	_clear_page_body()
	_page_backdrop.visible = true

	var center_col: VBoxContainer = _make_centered_column(620.0, 18)
	_page_body.add_child(center_col)

	var emblem_holder: CenterContainer = CenterContainer.new()
	var emblem: _FilmLeaderEmblem = _FilmLeaderEmblem.new()
	emblem_holder.add_child(emblem)
	center_col.add_child(emblem_holder)
	emblem.restart_pencil_anim()

	var lore_a: Label = _make_wrapped_label(
		"In a world where souls take the outward shape of the animal they align with most, yours was a praying mantis. Twenty-three subjects did not survive the experiment that fused the two into one.",
		16,
		COL_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	center_col.add_child(lore_a)

	var lore_b: Label = _make_wrapped_label(
		"Now, you perceive the world at twenty-four frames a second. Plan every one.",
		17,
		COL_STOCK,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	center_col.add_child(lore_b)

	var cta_row: CenterContainer = CenterContainer.new()
	var descend_btn: ExecuteButton = _make_execute_button("Descend", Vector2(240.0, 52.0))
	descend_btn.pressed.connect(func() -> void: descend_requested.emit())
	cta_row.add_child(descend_btn)
	center_col.add_child(cta_row)

	var sub_btns: HBoxContainer = HBoxContainer.new()
	sub_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_btns.add_theme_constant_override("separation", 12)
	center_col.add_child(sub_btns)

	var how_btn: Button = _make_bench_button("How to Play", Vector2(140.0, 38.0))
	how_btn.pressed.connect(show_rules_modal)
	sub_btns.add_child(how_btn)

	var debug_btn: Button = _make_bench_button("Debug / Showcase", Vector2(168.0, 38.0))
	debug_btn.pressed.connect(show_debug_modal)
	sub_btns.add_child(debug_btn)

	if not OS.has_feature("web"):
		var quit_btn: Button = _make_bench_button("Quit", Vector2(110.0, 38.0))
		quit_btn.pressed.connect(func() -> void: get_tree().quit())
		sub_btns.add_child(quit_btn)

	if p_best_scene > 0 or p_best_score > 0:
		var best_lbl: Label = _make_wrapped_label(
			"Best Descent: Scene %d of %d   •   High Score: %d" % [p_best_scene, p_total_scenes, p_best_score],
			13,
			COL_MUTE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		center_col.add_child(best_lbl)

	_emit_blocking_state()


func show_loadout_select(p_archetypes: Array[RunDirector.ArchetypeInfo]) -> void:
	hide_all_overlays()
	set_top_toolbar_visible(false)
	_clear_page_body()
	_page_backdrop.visible = true

	var col: VBoxContainer = _make_centered_column(1080.0, 18)
	_page_body.add_child(col)

	col.add_child(_make_wrapped_label("Choose Your Cutting Style", 36, COL_STOCK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_make_wrapped_label(
		"Your starting reel and passive relic stay with you for the entire descent.",
		16,
		COL_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 18)
	col.add_child(cards_row)

	var accents: Array[Color] = [
		Color(0.498, 0.624, 0.878, 1.0), # Motion blue
		Color(0.671, 0.561, 0.839, 1.0), # Edit plum
		Color(0.839, 0.627, 0.290, 1.0), # Strike ochre
	]
	for i: int in range(p_archetypes.size()):
		var arch: RunDirector.ArchetypeInfo = p_archetypes[i]
		var slab: _PaperSlabCard = _PaperSlabCard.new(
			arch.title,
			arch.tagline + "\n\"" + arch.flavor + "\"",
			arch.perk_title + " — " + arch.perk_desc,
			"Starting Reel (10): " + arch.deck_summary,
			accents[i % accents.size()]
		)
		var arch_id: String = arch.id
		slab.pressed.connect(func() -> void: archetype_picked.emit(arch_id))
		cards_row.add_child(slab)

	var back_row: CenterContainer = CenterContainer.new()
	var back_btn: Button = _make_bench_button("← Back to Title", Vector2(160.0, 40.0))
	back_btn.pressed.connect(func() -> void: return_to_title_requested.emit())
	back_row.add_child(back_btn)
	col.add_child(back_row)

	_emit_blocking_state()


func show_scene_intro(p_act_line: String, p_headline: String, p_subline: String) -> void:
	_page_backdrop.visible = false
	_replay_bar.visible = false
	_slate_is_intro = true
	_intro_timer = 1.45
	_slate_top_label.text = p_act_line
	_slate_top_label.modulate = COL_SOFT
	_slate_title_label.text = p_headline
	_slate_sub_label.text = p_subline
	_slate_continue_btn.visible = false
	_slate_root.visible = true
	_emit_blocking_state()


func show_action_replay_banner(p_take_index: int, p_total_takes: int) -> void:
	_page_backdrop.visible = false
	_slate_root.visible = false
	_replay_bar.visible = true
	_replay_label.text = "Take %d of %d" % [p_take_index, p_total_takes]
	_emit_blocking_state()


func update_action_replay_take(p_take_index: int, p_total_takes: int) -> void:
	if _replay_label != null:
		_replay_label.text = "Take %d of %d" % [p_take_index, p_total_takes]


func show_scene_wrap(p_wrap: RunDirector.SceneWrapInfo) -> void:
	_replay_bar.visible = false
	_page_backdrop.visible = false
	_slate_is_intro = false
	_slate_top_label.text = "Scene %02d is a wrap" % p_wrap.scene_number
	_slate_top_label.modulate = COL_GOLD
	_slate_title_label.text = p_wrap.grade_title
	_slate_sub_label.text = p_wrap.summary_line
	_slate_continue_btn.button_title = "Finish Run" if p_wrap.is_final_scene else "Continue"
	_slate_continue_btn.visible = true
	_slate_root.visible = true
	_emit_blocking_state()


func show_card_reward(
	p_scene_cleared: int,
	p_offered_cards: Array[CardData],
	p_hp: int,
	p_max_hp: int,
	p_deck: Array[CardData],
	p_is_debug: bool = false
) -> void:
	hide_all_overlays()
	set_top_toolbar_visible(true, p_deck, p_is_debug)
	_clear_page_body()
	_active_reward_cards = p_offered_cards.duplicate()
	_page_backdrop.visible = true

	var col: VBoxContainer = _make_centered_column(960.0, 18)
	_page_body.add_child(col)

	col.add_child(_make_wrapped_label(
		"Scene %02d Clear — Print One Clip" % p_scene_cleared,
		34,
		COL_STOCK,
		HORIZONTAL_ALIGNMENT_CENTER
	))
	col.add_child(_make_wrapped_label(
		"Add one index slip to your reel (click or press [1–3]), or skip to mend +3 HP.   (Current HP: %d / %d)" % [p_hp, p_max_hp],
		15,
		COL_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var cards_row: HBoxContainer = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 16)
	col.add_child(cards_row)

	for i: int in range(p_offered_cards.size()):
		var card: CardData = p_offered_cards[i]
		var view: CardView = CARD_VIEW_SCENE.instantiate() as CardView
		view.custom_minimum_size = Vector2(296.0, 134.0)
		cards_row.add_child(view)
		view.bind_card(i, card, card.frame_cost, false, false)
		view.card_clicked.connect(_on_reward_card_clicked)

	var skip_row: CenterContainer = CenterContainer.new()
	var skip_btn: Button = _make_bench_button("Skip Reel (+3 HP)", Vector2(210.0, 42.0))
	skip_btn.pressed.connect(func() -> void:
		_active_reward_cards.clear()
		reward_skipped.emit()
	)
	skip_row.add_child(skip_btn)
	col.add_child(skip_row)

	_emit_blocking_state()


func show_path_select(
	p_next_scene: int,
	p_total_scenes: int,
	p_options: Array[RunDirector.NodeKind],
	p_hp: int,
	p_max_hp: int,
	p_deck: Array[CardData],
	p_is_debug: bool = false
) -> void:
	hide_all_overlays()
	set_top_toolbar_visible(true, p_deck, p_is_debug)
	_clear_page_body()
	_page_backdrop.visible = true

	var col: VBoxContainer = _make_centered_column(1040.0, 18)
	_page_body.add_child(col)

	col.add_child(_make_wrapped_label(
		"Scene %02d of %02d — Choose Your Path" % [p_next_scene, p_total_scenes],
		34,
		COL_STOCK,
		HORIZONTAL_ALIGNMENT_CENTER
	))
	col.add_child(_make_wrapped_label(
		"Subject #24 Status: %d / %d HP   •   %d Clips in Reel" % [p_hp, p_max_hp, p_deck.size()],
		15,
		COL_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)

	for kind: RunDirector.NodeKind in p_options:
		var title_str: String = "Standard Scene"
		var desc_str: String = "Engage a standard hostile patrol in the projection wing."
		var reward_str: String = "Reward: Draft 1 clip + mend 2 HP."
		var accent_col: Color = Color(0.498, 0.624, 0.878, 1.0)

		if kind == RunDirector.NodeKind.ELITE:
			title_str = "Elite Scene"
			desc_str = "Reinforced hostiles with heavier damage and tighter crossfire."
			reward_str = "Reward: +2 Max HP + Draft 1 Upgraded (+) clip."
			accent_col = COL_VERMILION
		elif kind == RunDirector.NodeKind.REST:
			title_str = "Projection Booth"
			desc_str = "The projector idles behind a locked steel door. Catch your breath."
			reward_str = "Choice: Restore 35% Max HP OR Upgrade (+) any clip in your reel."
			accent_col = COL_ACETATE
		elif kind == RunDirector.NodeKind.BOSS:
			title_str = "Boss Scene"
			desc_str = "The archive guardian awaits on the cutting-room floor."
			reward_str = "Reward: Mend 5 HP + Upgraded (+) clip (or Victory!)."
			accent_col = COL_GOLD

		var slab: _PaperSlabCard = _PaperSlabCard.new(title_str, desc_str, reward_str, "", accent_col)
		slab.custom_minimum_size = Vector2(310.0, 210.0)
		var captured_kind: RunDirector.NodeKind = kind
		slab.pressed.connect(func() -> void: path_chosen.emit(captured_kind))
		row.add_child(slab)

	_emit_blocking_state()


func show_rest_site(
	p_heal_amount: int,
	p_hp: int,
	p_max_hp: int,
	p_deck: Array[CardData],
	p_upgradable_indices: Array[int],
	p_is_debug: bool = false
) -> void:
	hide_all_overlays()
	set_top_toolbar_visible(true, p_deck, p_is_debug)
	_clear_page_body()
	_page_backdrop.visible = true

	var col: VBoxContainer = _make_centered_column(960.0, 14)
	_page_body.add_child(col)

	col.add_child(_make_wrapped_label("Projection Booth — Rest or Sharpen", 32, COL_STOCK, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_make_wrapped_label(
		"Current HP: %d / %d. Recover your strength, or permanently sharpen one clip in your reel." % [p_hp, p_max_hp],
		15,
		COL_SOFT,
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var heal_row: CenterContainer = CenterContainer.new()
	var heal_btn: ExecuteButton = _make_execute_button("Recover (+%d HP)" % p_heal_amount, Vector2(280.0, 48.0))
	heal_btn.pressed.connect(func() -> void: rest_heal_chosen.emit())
	heal_row.add_child(heal_btn)
	col.add_child(heal_row)

	if not p_upgradable_indices.is_empty():
		col.add_child(_make_wrapped_label(
			"Or click a paper slip below to Upgrade (+) it:",
			14,
			COL_GOLD,
			HORIZONTAL_ALIGNMENT_CENTER
		))

		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(940.0, 420.0)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(scroll)

		var grid: GridContainer = GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		scroll.add_child(grid)

		for order_i: int in range(p_upgradable_indices.size()):
			var deck_idx: int = p_upgradable_indices[order_i]
			var card: CardData = p_deck[deck_idx]
			var view: CardView = CARD_VIEW_SCENE.instantiate() as CardView
			view.custom_minimum_size = Vector2(292.0, 124.0)
			grid.add_child(view)
			view.bind_card(order_i, card, card.frame_cost, false, false)
			var captured_deck_idx: int = deck_idx
			view.card_clicked.connect(func(_p_slot: int, _p_c: CardData) -> void:
				rest_upgrade_chosen.emit(captured_deck_idx)
			)

	_emit_blocking_state()


func show_run_over(p_is_victory: bool, p_director: RunDirector) -> void:
	hide_all_overlays()
	set_top_toolbar_visible(false)
	_clear_page_body()
	_page_backdrop.visible = true

	var col: VBoxContainer = _make_centered_column(660.0, 18)
	_page_body.add_child(col)

	var title_txt: String = "Foundation — Twenty-Four Frames Free" if p_is_victory else "Frame Dropped"
	var title_col: Color = COL_ACETATE if p_is_victory else COL_DANGER
	col.add_child(_make_wrapped_label(title_txt, 38, title_col, HORIZONTAL_ALIGNMENT_CENTER))

	var story_txt: String = (
		"All %d scenes cleared. The final reel runs out and you walk out of the projection chamber into daylight." % p_director.total_scenes
		if p_is_victory
		else "Subject #24 fell on Scene %d of %d. The projector keeps rolling in the dark." % [
			p_director.current_scene, p_director.total_scenes
		]
	)
	col.add_child(_make_wrapped_label(story_txt, 16, COL_SOFT, HORIZONTAL_ALIGNMENT_CENTER))

	var final_score: int = p_director.compute_run_score(p_is_victory)
	var score_badge: String = (
		"  (Debug Showcase)"
		if p_director.is_debug_mode
		else ("  (NEW BEST!)" if p_director.is_new_high_score else "  (Best: %d)" % p_director.best_score)
	)
	var stats_panel: PanelContainer = PanelContainer.new()
	var well_box: StyleBoxFlat = StyleBoxFlat.new()
	well_box.bg_color = COL_WELL
	well_box.border_color = COL_RULE2
	well_box.set_border_width_all(1)
	well_box.content_margin_left = 22.0
	well_box.content_margin_right = 22.0
	well_box.content_margin_top = 16.0
	well_box.content_margin_bottom = 16.0
	stats_panel.add_theme_stylebox_override("panel", well_box)
	col.add_child(stats_panel)

	var stats_lbl: Label = _make_wrapped_label(
		"Scenes Cleared: %d / %d   •   Total Takes: %d\nMatch Cuts: %d   •   Pit Kills: %d   •   Damage Taken: %d\nFinal Score: %d%s" % [
			p_director.scenes_cleared,
			p_director.total_scenes,
			p_director.total_takes,
			p_director.total_match_cuts,
			p_director.total_pit_kills,
			p_director.total_damage_taken,
			final_score,
			score_badge,
		],
		15,
		COL_STOCK,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	stats_panel.add_child(stats_lbl)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	col.add_child(btn_row)

	var again_btn: ExecuteButton = _make_execute_button("Play Again" if p_is_victory else "Run It Again", Vector2(210.0, 50.0))
	again_btn.pressed.connect(func() -> void: play_again_requested.emit())
	btn_row.add_child(again_btn)

	if p_director.is_debug_mode:
		var jump_again_btn: Button = _make_bench_button("Jump Scene", Vector2(140.0, 50.0))
		jump_again_btn.pressed.connect(show_debug_modal)
		btn_row.add_child(jump_again_btn)

	var menu_btn: Button = _make_bench_button("Main Menu", Vector2(140.0, 50.0))
	menu_btn.pressed.connect(func() -> void: return_to_title_requested.emit())
	btn_row.add_child(menu_btn)

	_emit_blocking_state()


# --- Modals (Debug Scene Picker, Deck Viewer & Rules) ---

func show_debug_modal() -> void:
	_clear_modal_body()
	_modal_title_label.text = "Debug / Showcase — Jump to Any Scene"

	var note_lbl: Label = _make_wrapped_label(
		"All 17 cards loaded into your reel  •  9-card hand draw [1–9]  •  Full HP restored on jump  •  Press [F2] anytime",
		14,
		COL_GOLD,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_modal_body.add_child(note_lbl)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920.0, 470.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_body.add_child(scroll)

	var list_box: VBoxContainer = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)

	for s_idx: int in range(_cached_total_scenes):
		var scene_num: int = s_idx + 1
		var is_default_boss: bool = (
			_cached_boss_flags[s_idx]
			if s_idx < _cached_boss_flags.size()
			else (scene_num == _cached_total_scenes)
		)
		var preview_note: String = (
			_cached_scene_notes[s_idx]
			if s_idx < _cached_scene_notes.size()
			else ("Scene %02d" % scene_num)
		)

		var row_panel: PanelContainer = PanelContainer.new()
		var row_style: StyleBoxFlat = StyleBoxFlat.new()
		row_style.bg_color = COL_BENCH
		row_style.border_color = COL_GOLD if is_default_boss else COL_RULE
		row_style.set_border_width_all(1)
		row_style.content_margin_left = 14.0
		row_style.content_margin_right = 14.0
		row_style.content_margin_top = 10.0
		row_style.content_margin_bottom = 10.0
		row_panel.add_theme_stylebox_override("panel", row_style)
		list_box.add_child(row_panel)

		var row_hbox: HBoxContainer = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 12)
		row_panel.add_child(row_hbox)

		var info_col: VBoxContainer = VBoxContainer.new()
		info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_col.add_theme_constant_override("separation", 2)
		row_hbox.add_child(info_col)

		var title_tag: String = "Scene %02d  ★" % scene_num if is_default_boss else "Scene %02d" % scene_num
		var sc_lbl: Label = Label.new()
		sc_lbl.text = title_tag
		sc_lbl.add_theme_font_size_override("font_size", 17)
		sc_lbl.modulate = COL_GOLD if is_default_boss else COL_STOCK
		info_col.add_child(sc_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = preview_note
		desc_lbl.add_theme_font_size_override("font_size", 13)
		desc_lbl.modulate = COL_SOFT
		info_col.add_child(desc_lbl)

		var captured_scene: int = scene_num
		if is_default_boss:
			var boss_exec: ExecuteButton = _make_execute_button("Boss", Vector2(116.0, 36.0))
			boss_exec.pressed.connect(func() -> void:
				_trigger_debug_jump(captured_scene, RunDirector.NodeKind.BOSS)
			)
			row_hbox.add_child(boss_exec)

			var std_alt: Button = _make_bench_button("Standard", Vector2(96.0, 36.0))
			std_alt.pressed.connect(func() -> void:
				_trigger_debug_jump(captured_scene, RunDirector.NodeKind.NORMAL)
			)
			row_hbox.add_child(std_alt)

			var elite_alt: Button = _make_bench_button("Elite", Vector2(88.0, 36.0))
			elite_alt.pressed.connect(func() -> void:
				_trigger_debug_jump(captured_scene, RunDirector.NodeKind.ELITE)
			)
			row_hbox.add_child(elite_alt)
		else:
			var std_exec: ExecuteButton = _make_execute_button("Standard", Vector2(116.0, 36.0))
			std_exec.pressed.connect(func() -> void:
				_trigger_debug_jump(captured_scene, RunDirector.NodeKind.NORMAL)
			)
			row_hbox.add_child(std_exec)

			var elite_btn: Button = _make_bench_button("Elite", Vector2(96.0, 36.0))
			elite_btn.pressed.connect(func() -> void:
				_trigger_debug_jump(captured_scene, RunDirector.NodeKind.ELITE)
			)
			row_hbox.add_child(elite_btn)

			var boss_btn: Button = _make_bench_button("Boss", Vector2(88.0, 36.0))
			boss_btn.pressed.connect(func() -> void:
				_trigger_debug_jump(captured_scene, RunDirector.NodeKind.BOSS)
			)
			row_hbox.add_child(boss_btn)

	_modal_backdrop.visible = true
	_emit_blocking_state()


func show_deck_modal() -> void:
	_clear_modal_body()
	_modal_title_label.text = "Current Reel (%d Clips)" % _cached_deck.size()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(920.0, 500.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_body.add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	for i: int in range(_cached_deck.size()):
		var card: CardData = _cached_deck[i]
		var view: CardView = CARD_VIEW_SCENE.instantiate() as CardView
		view.custom_minimum_size = Vector2(290.0, 122.0)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(view)
		view.bind_card(i, card, card.frame_cost, false, false)

	_modal_backdrop.visible = true
	_emit_blocking_state()


func show_rules_modal() -> void:
	_clear_modal_body()
	_modal_title_label.text = "Cutting-Room Rules & Controls"

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860.0, 480.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal_body.add_child(scroll)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 12)
	scroll.add_child(text_box)

	var sections: Array[Dictionary] = [
		{
			"h": "1. One Second = 24 Frames",
			"b": "Every turn ('Take') is exactly 1 second split into 24 discrete frames (0–23). Enemy attacks are 100% deterministic and telegraphed on both the Arena grid and the Moviola Timeline. Motion cards go on the Move track, Action cards on the Action track, and plum Edit cards on either track."
		},
		{
			"h": "2. Wind-Up, Impact Diamonds & Match Cuts",
			"b": "Strikes show hatched wind-up frames, a rotated impact diamond on the exact hit frame, and dark recovery frames. Land a strike on an enemy during its gold Match Cut window (while its Strike bar is active) for 1.5× damage and bonus motion!"
		},
		{
			"h": "3. Shutter Freeze, Knockback & Pits",
			"b": "Freezing an enemy encases it in seafoam acetate, cancelling its planned attack (shown as a dashed ghost box on the timeline) and granting bonus damage on follow-up hits. Knocking any enemy into a black Pit kills it outright; knocking it into a wall deals bonus Wall Slam damage."
		},
		{
			"h": "4. Speed Tiers (1–3) & Violations",
			"b": "Schedule enough Motion frames in a take to promote your Speed Tier: Tier 1+ unlocks Flow (+3 strike damage right after moving), and Tier 3 discounts Motion cards by 3 frames! Leaving a long idle gap bleeds a tier. Avoid 180° turns without Pivot/Quick Step and avoid dashing into walls or live foes, or you suffer a Violation and freeze."
		},
		{
			"h": "5. Bench Controls",
			"b": "• Drag cards from Hand onto Timeline (or press [1–9] and click).\n• Drag placed clips left/right on the Timeline (or press ← / →) to retime them.\n• Press W / A / S / D or click the Arena compass to aim.\n• Right-click, click '×', or press Delete/Backspace to remove a clip.\n• Ctrl+Z / Ctrl+Y for Undo & Redo. Press Enter / Space or click '● Execute' to roll the take."
		},
	]

	for sec: Dictionary in sections:
		text_box.add_child(_make_wrapped_label(sec["h"] as String, 18, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		text_box.add_child(_make_wrapped_label(sec["b"] as String, 14, COL_STOCK, HORIZONTAL_ALIGNMENT_LEFT))

	_modal_backdrop.visible = true
	_emit_blocking_state()


# --- Internal Shell Builders ---

func _build_shell_hierarchy() -> void:
	_root = Control.new()
	_root.name = "RunOverlayRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = BENCH_THEME
	add_child(_root)

	# 1. Persistent Top-Right Combat Bench Buttons (Y = 10..44 inside Header Bar)
	_top_toolbar = HBoxContainer.new()
	_top_toolbar.anchor_left = 1.0
	_top_toolbar.anchor_right = 1.0
	_top_toolbar.offset_left = -520.0
	_top_toolbar.offset_top = 10.0
	_top_toolbar.offset_right = -26.0
	_top_toolbar.offset_bottom = 44.0
	_top_toolbar.alignment = BoxContainer.ALIGNMENT_END
	_top_toolbar.add_theme_constant_override("separation", 8)
	_top_toolbar.visible = false
	_root.add_child(_top_toolbar)

	_jump_btn = _make_bench_button("Jump Scene", Vector2(114.0, 32.0))
	_jump_btn.visible = false
	_jump_btn.pressed.connect(show_debug_modal)
	_top_toolbar.add_child(_jump_btn)

	_deck_btn = _make_bench_button("Deck (10)", Vector2(106.0, 32.0))
	_deck_btn.pressed.connect(show_deck_modal)
	_top_toolbar.add_child(_deck_btn)

	_rules_btn = _make_bench_button("Rules", Vector2(82.0, 32.0))
	_rules_btn.pressed.connect(show_rules_modal)
	_top_toolbar.add_child(_rules_btn)

	_menu_btn = _make_bench_button("Main Menu", Vector2(112.0, 32.0))
	_menu_btn.pressed.connect(func() -> void: return_to_title_requested.emit())
	_top_toolbar.add_child(_menu_btn)

	# 2. Action Replay Top-of-Arena Banner (32, 74, width 912)
	_replay_bar = PanelContainer.new()
	_replay_bar.position = Vector2(32.0, 74.0)
	_replay_bar.size = Vector2(912.0, 34.0)
	_replay_bar.visible = false
	var rp_style: StyleBoxFlat = StyleBoxFlat.new()
	rp_style.bg_color = Color(0.05, 0.05, 0.05, 0.88)
	rp_style.border_color = COL_RULE2
	rp_style.border_width_bottom = 1
	rp_style.content_margin_left = 12.0
	rp_style.content_margin_right = 8.0
	_replay_bar.add_theme_stylebox_override("panel", rp_style)
	_root.add_child(_replay_bar)

	var rp_hbox: HBoxContainer = HBoxContainer.new()
	rp_hbox.add_theme_constant_override("separation", 12)
	_replay_bar.add_child(rp_hbox)

	var rec_lbl: Label = Label.new()
	rec_lbl.text = "● Replay"
	rec_lbl.modulate = COL_DANGER
	rec_lbl.add_theme_font_size_override("font_size", 14)
	rp_hbox.add_child(rec_lbl)

	_replay_label = Label.new()
	_replay_label.text = "Take 1 of 1"
	_replay_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay_label.modulate = COL_STOCK
	_replay_label.add_theme_font_size_override("font_size", 14)
	rp_hbox.add_child(_replay_label)

	var skip_rp_btn: Button = _make_bench_button("Skip [Space]", Vector2(116.0, 26.0))
	skip_rp_btn.pressed.connect(func() -> void: replay_skip_requested.emit())
	rp_hbox.add_child(skip_rp_btn)

	# 3. Full-Screen Bench Page Container
	_page_backdrop = ColorRect.new()
	_page_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page_backdrop.color = COL_BENCH
	_page_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_page_backdrop.visible = false
	_root.add_child(_page_backdrop)

	var page_center: CenterContainer = CenterContainer.new()
	page_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_page_backdrop.add_child(page_center)

	_page_body = VBoxContainer.new()
	_page_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_body.mouse_filter = Control.MOUSE_FILTER_PASS
	page_center.add_child(_page_body)

	# 4. Silent-Film Intertitle Slate (#it)
	_slate_root = _SilentSlateControl.new()
	_slate_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slate_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_slate_root.visible = false
	_slate_root.gui_input.connect(_on_slate_gui_input)
	_root.add_child(_slate_root)

	var slate_center: CenterContainer = CenterContainer.new()
	slate_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slate_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_slate_root.add_child(slate_center)

	var slate_vbox: VBoxContainer = _make_centered_column(720.0, 14)
	slate_center.add_child(slate_vbox)

	_slate_top_label = _make_wrapped_label("Act I", 18, COL_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	slate_vbox.add_child(_slate_top_label)

	_slate_title_label = _make_wrapped_label("Scene 01", 62, COL_STOCK, HORIZONTAL_ALIGNMENT_CENTER)
	slate_vbox.add_child(_slate_title_label)

	_slate_sub_label = _make_wrapped_label("", 18, COL_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	slate_vbox.add_child(_slate_sub_label)

	var cont_holder: CenterContainer = CenterContainer.new()
	_slate_continue_btn = _make_execute_button("Continue", Vector2(230.0, 50.0))
	_slate_continue_btn.pressed.connect(_on_wrap_continue_pressed)
	cont_holder.add_child(_slate_continue_btn)
	slate_vbox.add_child(cont_holder)

	# 5. Modal Overlay (Debug Scene Picker, Deck Viewer & Rules)
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.color = Color(0.05, 0.06, 0.055, 0.85)
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.visible = false
	_root.add_child(_modal_backdrop)

	var modal_center: CenterContainer = CenterContainer.new()
	modal_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.add_child(modal_center)

	var modal_panel: PanelContainer = PanelContainer.new()
	var modal_style: StyleBoxFlat = StyleBoxFlat.new()
	modal_style.bg_color = COL_WELL
	modal_style.border_color = COL_RULE2
	modal_style.set_border_width_all(1)
	modal_style.content_margin_left = 26.0
	modal_style.content_margin_right = 26.0
	modal_style.content_margin_top = 22.0
	modal_style.content_margin_bottom = 22.0
	modal_panel.add_theme_stylebox_override("panel", modal_style)
	modal_center.add_child(modal_panel)

	var modal_outer_vbox: VBoxContainer = VBoxContainer.new()
	modal_outer_vbox.add_theme_constant_override("separation", 16)
	modal_panel.add_child(modal_outer_vbox)

	var modal_header: HBoxContainer = HBoxContainer.new()
	modal_outer_vbox.add_child(modal_header)

	_modal_title_label = Label.new()
	_modal_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_title_label.add_theme_font_size_override("font_size", 24)
	_modal_title_label.modulate = COL_STOCK
	modal_header.add_child(_modal_title_label)

	var close_btn: Button = _make_bench_button("Close [Esc]", Vector2(116.0, 36.0))
	close_btn.pressed.connect(_close_modal)
	modal_header.add_child(close_btn)

	_modal_body = VBoxContainer.new()
	_modal_body.add_theme_constant_override("separation", 12)
	modal_outer_vbox.add_child(_modal_body)


# --- Widget Helpers & Signal Callbacks ---

func _trigger_debug_jump(p_scene_number: int, p_node_kind: RunDirector.NodeKind) -> void:
	_close_modal()
	debug_scene_selected.emit(p_scene_number, p_node_kind)


func _make_centered_column(p_min_width: float, p_sep: int) -> VBoxContainer:
	var vb: VBoxContainer = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(p_min_width, 0.0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_theme_constant_override("separation", p_sep)
	return vb


func _make_wrapped_label(
	p_text: String,
	p_font_size: int,
	p_color: Color,
	p_align: HorizontalAlignment
) -> Label:
	var lbl: Label = Label.new()
	lbl.text = p_text
	lbl.horizontal_alignment = p_align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", p_font_size)
	lbl.modulate = p_color
	return lbl


func _make_bench_button(p_label: String, p_min_size: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = p_label
	btn.custom_minimum_size = p_min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _make_execute_button(p_title: String, p_min_size: Vector2) -> ExecuteButton:
	var btn: ExecuteButton = ExecuteButton.new()
	btn.button_title = p_title
	btn.custom_minimum_size = p_min_size
	btn.focus_mode = Control.FOCUS_NONE
	return btn


func _clear_page_body() -> void:
	if _page_body == null:
		return
	for child: Node in _page_body.get_children():
		child.queue_free()


func _clear_modal_body() -> void:
	if _modal_body == null:
		return
	for child: Node in _modal_body.get_children():
		child.queue_free()


func _close_modal() -> void:
	if _modal_backdrop != null:
		_modal_backdrop.visible = false
	_emit_blocking_state()


func _on_slate_gui_input(p_event: InputEvent) -> void:
	if not _slate_is_intro:
		return
	if p_event is InputEventMouseButton:
		var mb: InputEventMouseButton = p_event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_dismiss_intro_slate()


func _dismiss_intro_slate() -> void:
	if not _slate_root.visible or not _slate_is_intro:
		return
	_slate_root.visible = false
	_emit_blocking_state()
	scene_intro_dismissed.emit()


func _on_wrap_continue_pressed() -> void:
	if not _slate_root.visible or _slate_is_intro:
		return
	_slate_root.visible = false
	_emit_blocking_state()
	scene_wrap_continued.emit()


func _on_reward_card_clicked(_p_slot_index: int, p_card: CardData) -> void:
	if p_card == null or _active_reward_cards.is_empty():
		return
	_active_reward_cards.clear()
	reward_card_chosen.emit(p_card)


func _emit_blocking_state() -> void:
	var blocking: bool = (
		(_page_backdrop != null and _page_backdrop.visible)
		or (_slate_root != null and _slate_root.visible)
		or (_modal_backdrop != null and _modal_backdrop.visible)
		or (_replay_bar != null and _replay_bar.visible)
	)
	overlay_blocking_changed.emit(blocking)
