class_name RunDirector
extends RefCounted

## Headless roguelike run progression director for XXIV.
## Manages starter archetypes, persistent deck & HP, procedural 8-scene encounter scaling,
## card rewards, card upgrades (+), rest sites, wrap grades, high-score persistence,
## and instant Debug / Showcase level-skip mode with all 17 cards unlocked.

enum NodeKind {
	NORMAL = 0,
	ELITE = 1,
	BOSS = 2,
	REST = 3,
}

const SAVE_PATH: String = "user://xxiv_progress.cfg"
const SAVE_SECTION: String = "progress"
const DEBUG_HAND_DRAW_COUNT: int = 9

const ENEMY_HOUND: EnemyData = preload("res://data/enemies/Hound.tres")
const ENEMY_CLEAVER: EnemyData = preload("res://data/enemies/Cleaver.tres")
const ENEMY_SNIPER: EnemyData = preload("res://data/enemies/Sniper.tres")

const CARD_QUICK_STEP: CardData = preload("res://data/cards/motion/QuickStep.tres")
const CARD_DASH: CardData = preload("res://data/cards/motion/Dash.tres")
const CARD_SPRINT: CardData = preload("res://data/cards/motion/Sprint.tres")
const CARD_PIVOT: CardData = preload("res://data/cards/motion/Pivot.tres")

const CARD_JAB: CardData = preload("res://data/cards/action/Jab.tres")
const CARD_APERTURE_PALM: CardData = preload("res://data/cards/action/AperturePalm.tres")
const CARD_KICK: CardData = preload("res://data/cards/action/Kick.tres")
const CARD_GUARD: CardData = preload("res://data/cards/action/Guard.tres")
const CARD_TWIN_STRIKE: CardData = preload("res://data/cards/action/TwinStrike.tres")

const CARD_DEVELOP: CardData = preload("res://data/cards/edit/Develop.tres")
const CARD_DUTCH_ANGLE: CardData = preload("res://data/cards/edit/DutchAngle.tres")
const CARD_HOLD_FRAME: CardData = preload("res://data/cards/edit/HoldFrame.tres")
const CARD_NEGATIVE_EXPOSURE: CardData = preload("res://data/cards/edit/NegativeExposure.tres")
const CARD_REWIND: CardData = preload("res://data/cards/edit/Rewind.tres")
const CARD_SLIP: CardData = preload("res://data/cards/edit/Slip.tres")
const CARD_SWAP: CardData = preload("res://data/cards/edit/Swap.tres")
const CARD_TAG: CardData = preload("res://data/cards/edit/Tag.tres")


class ArchetypeInfo extends RefCounted:
	var id: String = ""
	var title: String = ""
	var tagline: String = ""
	var flavor: String = ""
	var perk_title: String = ""
	var perk_desc: String = ""
	var deck_summary: String = ""
	var starter_cards: Array[CardData] = []


class SceneWrapInfo extends RefCounted:
	var scene_number: int = 1
	var grade_title: String = "In the Can"
	var summary_line: String = ""
	var heal_gained: int = 0
	var max_hp_gained: int = 0
	var is_final_scene: bool = false


var _base_config: CombatConfig
var _run_config: CombatConfig
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reward_pool: Array[CardData] = []

var _total_scenes: int = 8
var _current_scene: int = 1
var _current_node_kind: NodeKind = NodeKind.NORMAL
var _last_node_was_rest: bool = false
var _archetype_id: String = "sprint"
var _is_debug_mode: bool = false

var _player_hp: int = 14
var _player_max_hp: int = 14
var _run_deck: Array[CardData] = []

var _scenes_cleared: int = 0
var _total_takes: int = 0
var _total_match_cuts: int = 0
var _total_pit_kills: int = 0
var _total_damage_taken: int = 0

var _best_scene: int = 0
var _best_score: int = 0
var _is_new_high_score: bool = false


func _init(p_base_config: CombatConfig, p_total_scenes: int = 8) -> void:
	_base_config = p_base_config if p_base_config != null else CombatConfig.new()
	_run_config = _base_config.duplicate() as CombatConfig
	_total_scenes = maxi(4, p_total_scenes)
	_rng.randomize()
	_build_reward_pool()
	_load_progress()


# --- Read-Only Properties ---

var run_config: CombatConfig:
	get: return _run_config

var total_scenes: int:
	get: return _total_scenes

var current_scene: int:
	get: return _current_scene

var current_node_kind: NodeKind:
	get: return _current_node_kind

var is_debug_mode: bool:
	get: return _is_debug_mode

var player_hp: int:
	get: return _player_hp

var player_max_hp: int:
	get: return _player_max_hp

var deck: Array[CardData]:
	get: return _run_deck.duplicate()

var scenes_cleared: int:
	get: return _scenes_cleared

var total_takes: int:
	get: return _total_takes

var total_match_cuts: int:
	get: return _total_match_cuts

var total_pit_kills: int:
	get: return _total_pit_kills

var total_damage_taken: int:
	get: return _total_damage_taken

var best_scene: int:
	get: return _best_scene

var best_score: int:
	get: return _best_score

var is_new_high_score: bool:
	get: return _is_new_high_score


# --- Archetypes, Standard Run & Debug Showcase Initialization ---

func get_archetypes() -> Array[ArchetypeInfo]:
	var list: Array[ArchetypeInfo] = []

	var sprint_arch: ArchetypeInfo = ArchetypeInfo.new()
	sprint_arch.id = "sprint"
	sprint_arch.title = "Sprint"
	sprint_arch.tagline = "Stalk, then strike on the move."
	sprint_arch.flavor = "The mantis stalks. Then it is already there."
	sprint_arch.perk_title = "Relic: Spare Reel"
	sprint_arch.perk_desc = "Draw +1 extra card at the start of every take."
	sprint_arch.starter_cards = [
		CARD_QUICK_STEP, CARD_QUICK_STEP, CARD_DASH, CARD_DASH, CARD_SPRINT,
		CARD_PIVOT, CARD_JAB, CARD_JAB, CARD_APERTURE_PALM, CARD_SLIP
	]
	sprint_arch.deck_summary = _summarize_card_list(sprint_arch.starter_cards)
	list.append(sprint_arch)

	var still_arch: ArchetypeInfo = ArchetypeInfo.new()
	still_arch.id = "still"
	still_arch.title = "Still"
	still_arch.tagline = "Freeze, shatter, and edit time."
	still_arch.flavor = "The mantis waits, and the world forgets it is being watched."
	still_arch.perk_title = "Relic: Wide Shutter"
	still_arch.perk_desc = "Freeze lasts 36 frames (1.5s) and Match Cuts grant +4 motion."
	still_arch.starter_cards = [
		CARD_APERTURE_PALM, CARD_APERTURE_PALM, CARD_KICK, CARD_QUICK_STEP, CARD_DASH,
		CARD_PIVOT, CARD_SLIP, CARD_DUTCH_ANGLE, CARD_HOLD_FRAME, CARD_SWAP
	]
	still_arch.deck_summary = _summarize_card_list(still_arch.starter_cards)
	list.append(still_arch)

	var shatter_arch: ArchetypeInfo = ArchetypeInfo.new()
	shatter_arch.id = "shatter"
	shatter_arch.title = "Shatter"
	shatter_arch.tagline = "Heavy strikes, shields, and knockback."
	shatter_arch.flavor = "Chitin is armor. Whatever breaks, breaks against it."
	shatter_arch.perk_title = "Relic: Heavy Stock"
	shatter_arch.perk_desc = "+4 Max HP and +2 Wall Slam collision damage."
	shatter_arch.starter_cards = [
		CARD_JAB, CARD_JAB, CARD_KICK, CARD_KICK, CARD_TWIN_STRIKE,
		CARD_GUARD, CARD_GUARD, CARD_QUICK_STEP, CARD_DASH, CARD_TAG
	]
	shatter_arch.deck_summary = _summarize_card_list(shatter_arch.starter_cards)
	list.append(shatter_arch)

	return list


func start_new_run(p_archetype_id: String) -> void:
	_rng.randomize()
	_is_debug_mode = false
	_archetype_id = p_archetype_id
	_run_config = _base_config.duplicate() as CombatConfig

	var chosen: ArchetypeInfo = null
	for arch: ArchetypeInfo in get_archetypes():
		if arch.id == p_archetype_id:
			chosen = arch
			break
	if chosen == null:
		chosen = get_archetypes()[0]

	if chosen.id == "sprint":
		_run_config.cards_drawn_per_take = mini(_run_config.max_hand_size, _run_config.cards_drawn_per_take + 1)
	elif chosen.id == "still":
		_run_config.freeze_duration_seconds = 1.5
		_run_config.match_cut_bonus_motion_frames += 2
	elif chosen.id == "shatter":
		_run_config.player_max_hp += 4
		_run_config.wall_slam_damage += 2

	_player_max_hp = _run_config.player_max_hp
	_player_hp = _player_max_hp
	_run_deck.clear()
	for card: CardData in chosen.starter_cards:
		_run_deck.append(card)

	_current_scene = 1
	_current_node_kind = NodeKind.NORMAL
	_last_node_was_rest = false
	_scenes_cleared = 0
	_total_takes = 0
	_total_match_cuts = 0
	_total_pit_kills = 0
	_total_damage_taken = 0
	_is_new_high_score = false


func start_debug_showcase_at_scene(p_scene_number: int, p_node_kind: NodeKind) -> void:
	_rng.randomize()
	_is_debug_mode = true
	_archetype_id = "debug"
	_run_config = _base_config.duplicate() as CombatConfig
	_run_config.cards_drawn_per_take = mini(_run_config.max_hand_size, DEBUG_HAND_DRAW_COUNT)

	_player_max_hp = _run_config.player_max_hp
	_player_hp = _player_max_hp

	_run_deck.clear()
	for card: CardData in _reward_pool:
		_run_deck.append(card)

	_current_scene = clampi(p_scene_number, 1, _total_scenes)
	_current_node_kind = NodeKind.NORMAL if p_node_kind == NodeKind.REST else p_node_kind
	_last_node_was_rest = false
	_scenes_cleared = 0
	_total_takes = 0
	_total_match_cuts = 0
	_total_pit_kills = 0
	_total_damage_taken = 0
	_is_new_high_score = false


func is_boss_scene_by_default(p_scene: int) -> bool:
	var act_one_boss_scene: int = maxi(2, floori(float(_total_scenes) * 0.5))
	return p_scene == act_one_boss_scene or p_scene >= _total_scenes


func get_debug_scene_preview_note(p_scene: int) -> String:
	var act_one_boss_scene: int = maxi(2, floori(float(_total_scenes) * 0.5))
	if p_scene >= _total_scenes:
		return "Final Boss — The Prime Projectionist + Hound + Sniper"
	if p_scene == act_one_boss_scene:
		return "Act I Boss — The Chief Editor + Hound"
	if p_scene == 1:
		return "Act I — Opening Patrol (Hound + Cleaver, Walls)"
	if p_scene == 2:
		return "Act I — Crossfire & Pits (Hound + Sniper, Pits introduced)"
	if p_scene < act_one_boss_scene:
		return "Act I — Projection Wing (3 Scaled Hostiles)"
	if p_scene < 6:
		return "Act II — The Furnace (3 Scaled Hostiles, 2 Pits)"
	return "Act II — Deep Furnace (4 Scaled Hostiles, 2 Pits)"


# --- Scene Titles & Procedural Encounter Builder ---

func get_act_title(p_scene: int) -> String:
	var half: int = maxi(2, floori(float(_total_scenes) * 0.5))
	if p_scene <= half:
		return "Act I — Projection Rooms"
	return "Act II — The Furnace"


func get_scene_headline(p_scene: int, p_kind: NodeKind) -> String:
	if p_kind == NodeKind.BOSS:
		return "The Prime Projectionist" if p_scene >= _total_scenes else "The Chief Editor"
	if p_kind == NodeKind.ELITE:
		return "Elite Scene %02d" % p_scene
	return "Scene %02d" % p_scene


func get_scene_subline(p_scene: int, p_kind: NodeKind) -> String:
	if p_kind == NodeKind.BOSS:
		if p_scene >= _total_scenes:
			return "The final reel. Every frame decides whether you walk into daylight."
		return "Guardian of the first archive. Watch the cross-cutting beam."
	if p_kind == NodeKind.ELITE:
		return "Reinforced hostiles. Grants +2 Max HP and an Upgraded (+) clip."
	var half: int = maxi(2, floori(float(_total_scenes) * 0.5))
	if p_scene <= half:
		return "Light leaks under every door. Plan all twenty-four frames."
	return "Where bad takes are burned. Use the pits and pillars."


func build_current_encounter() -> CombatEncounter:
	var grid_sz: int = _run_config.default_grid_size
	var board: BoardState = BoardState.new(grid_sz)

	var start_x: int = 2 + _rng.randi_range(0, 1)
	var player_pos: Vector2i = Vector2i(clampi(start_x, 0, grid_sz - 1), grid_sz - 1)

	var player: PlayerState = PlayerState.new()
	player.set_identity(EncounterData.PLAYER_ENTITY_ID, _player_max_hp, maxi(1, _player_hp))
	player.set_position_and_direction(player_pos, Types.Direction.NORTH)

	var state: CombatState = CombatState.new(board, player)
	var reserved_tiles: Array[Vector2i] = [
		player_pos,
		player_pos + Vector2i(0, -1),
		Vector2i(clampi(player_pos.x - 1, 0, grid_sz - 1), player_pos.y),
		Vector2i(clampi(player_pos.x + 1, 0, grid_sz - 1), player_pos.y),
	]

	var enemy_defs: Array[EnemyData] = _build_enemy_roster_for_scene(_current_scene, _current_node_kind)
	var next_eid: int = EncounterData.FIRST_ENEMY_ENTITY_ID
	for idx: int in range(enemy_defs.size()):
		var edata: EnemyData = enemy_defs[idx]
		var spawn_pos: Vector2i = _pick_open_tile(grid_sz, 0, 2, reserved_tiles)
		reserved_tiles.append(spawn_pos)

		var enemy: EnemyState = EnemyState.new()
		enemy.set_identity(next_eid, edata.max_hp)
		enemy.set_enemy_data(edata)
		enemy.set_position_and_direction(spawn_pos, Types.Direction.SOUTH)
		state.add_enemy(enemy)
		next_eid += 1

	var wall_count: int = 1 if _current_scene == 1 else mini(3, 1 + floori(float(_current_scene) / 3.0))
	for _w: int in range(wall_count):
		var w_pos: Vector2i = _pick_open_tile(grid_sz, 1, grid_sz - 2, reserved_tiles)
		reserved_tiles.append(w_pos)
		board.add_wall(w_pos)

	if _current_scene >= 2:
		var pit_count: int = 1 if _current_scene < 5 else 2
		for _p: int in range(pit_count):
			var pit_pos: Vector2i = _pick_open_tile(grid_sz, 1, grid_sz - 2, reserved_tiles)
			reserved_tiles.append(pit_pos)
			board.add_pit(pit_pos)

	var deck_seed: int = int(_rng.randi())
	var deck_state: DeckState = DeckState.new(_run_deck, deck_seed)
	return CombatEncounter.new(state, deck_state, _run_config)


# --- Outcome Recording, Rewards, Rest & Upgrades ---

func record_scene_victory(
	p_final_state: CombatState,
	p_takes_used: int,
	p_takes_reel: Array[SimulationResult]
) -> SceneWrapInfo:
	var hp_after_fight: int = maxi(1, p_final_state.player.hp)
	var dmg_taken: int = maxi(0, _player_hp - hp_after_fight)
	_player_hp = hp_after_fight

	var scene_cuts: int = 0
	var scene_pits: int = 0
	for res: SimulationResult in p_takes_reel:
		scene_cuts += res.count_events_of_type(CombatEvent.Type.MATCH_CUT_TRIGGERED)
		scene_pits += res.count_events_of_type(CombatEvent.Type.PIT_ELIMINATION)

	_scenes_cleared += 1
	_total_takes += maxi(1, p_takes_used)
	_total_match_cuts += scene_cuts
	_total_pit_kills += scene_pits
	_total_damage_taken += dmg_taken

	var max_hp_bonus: int = 2 if _current_node_kind == NodeKind.ELITE else 0
	if max_hp_bonus > 0:
		_player_max_hp += max_hp_bonus
		_player_hp += max_hp_bonus

	var base_heal: int = 5 if _current_node_kind == NodeKind.BOSS else 2
	var before_heal: int = _player_hp
	_player_hp = mini(_player_max_hp, _player_hp + base_heal)
	var actual_heal: int = _player_hp - before_heal

	var info: SceneWrapInfo = SceneWrapInfo.new()
	info.scene_number = _current_scene
	info.heal_gained = actual_heal
	info.max_hp_gained = max_hp_bonus
	info.is_final_scene = _current_scene >= _total_scenes

	if dmg_taken == 0 and p_takes_used <= 2:
		info.grade_title = "A Perfect Take"
	elif dmg_taken == 0:
		info.grade_title = "Clean Print"
	elif scene_cuts >= 2:
		info.grade_title = "Stylish Cut"
	elif scene_pits >= 1:
		info.grade_title = "Cold Cut"
	else:
		info.grade_title = "In the Can"

	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d %s" % [p_takes_used, "take" if p_takes_used == 1 else "takes"])
	if scene_cuts > 0:
		parts.append("%d match %s" % [scene_cuts, "cut" if scene_cuts == 1 else "cuts"])
	if scene_pits > 0:
		parts.append("%d pit %s" % [scene_pits, "kill" if scene_pits == 1 else "kills"])
	parts.append("%d damage taken" % dmg_taken if dmg_taken > 0 else "no damage taken")
	if max_hp_bonus > 0:
		parts.append("+%d Max HP" % max_hp_bonus)
	if actual_heal > 0:
		parts.append("+%d HP mended" % actual_heal)
	info.summary_line = ", ".join(parts) + "."

	_update_and_save_records(info.is_final_scene)
	return info


func record_scene_defeat(p_takes_used: int, p_takes_reel: Array[SimulationResult]) -> void:
	_total_takes += maxi(1, p_takes_used)
	for res: SimulationResult in p_takes_reel:
		_total_match_cuts += res.count_events_of_type(CombatEvent.Type.MATCH_CUT_TRIGGERED)
		_total_pit_kills += res.count_events_of_type(CombatEvent.Type.PIT_ELIMINATION)
	_total_damage_taken += _player_hp
	_player_hp = 0
	_update_and_save_records(false)


func roll_reward_cards(p_count: int = 3) -> Array[CardData]:
	var pool_copy: Array[CardData] = _reward_pool.duplicate()
	var offered: Array[CardData] = []
	var make_upgraded: bool = (
		_current_node_kind == NodeKind.ELITE or _current_node_kind == NodeKind.BOSS
	)

	while offered.size() < p_count and not pool_copy.is_empty():
		var pick_idx: int = _rng.randi_range(0, pool_copy.size() - 1)
		var base_card: CardData = pool_copy[pick_idx]
		pool_copy.remove_at(pick_idx)
		offered.append(create_upgraded_card(base_card) if make_upgraded else base_card)

	return offered


func claim_reward_card(p_card: CardData) -> void:
	if p_card != null:
		_run_deck.append(p_card)


func skip_reward_for_heal() -> int:
	var before: int = _player_hp
	_player_hp = mini(_player_max_hp, _player_hp + 3)
	return _player_hp - before


func prepare_next_scene_options() -> Array[NodeKind]:
	var next_scene: int = _current_scene + 1
	var act_one_boss_scene: int = maxi(2, floori(float(_total_scenes) * 0.5))
	if next_scene == act_one_boss_scene or next_scene >= _total_scenes:
		return [NodeKind.BOSS]

	var options: Array[NodeKind] = [NodeKind.NORMAL]
	if next_scene >= 3:
		options.append(NodeKind.ELITE)
	if not _last_node_was_rest:
		options.append(NodeKind.REST)
	return options


func choose_next_node(p_kind: NodeKind) -> void:
	_current_scene = mini(_total_scenes, _current_scene + 1)
	_current_node_kind = p_kind
	_last_node_was_rest = (p_kind == NodeKind.REST)


func get_rest_heal_amount() -> int:
	return maxi(3, ceili(float(_player_max_hp) * 0.35))


func perform_rest_heal() -> int:
	var before: int = _player_hp
	_player_hp = mini(_player_max_hp, _player_hp + get_rest_heal_amount())
	return _player_hp - before


func can_upgrade_card(p_card: CardData) -> bool:
	return p_card != null and not p_card.id.ends_with("_plus")


func get_upgradable_deck_indices() -> Array[int]:
	var indices: Array[int] = []
	for i: int in range(_run_deck.size()):
		if can_upgrade_card(_run_deck[i]):
			indices.append(i)
	return indices


func upgrade_card_at_deck_index(p_deck_idx: int) -> CardData:
	if p_deck_idx < 0 or p_deck_idx >= _run_deck.size():
		return null
	var original: CardData = _run_deck[p_deck_idx]
	if not can_upgrade_card(original):
		return original
	var upgraded: CardData = create_upgraded_card(original)
	_run_deck[p_deck_idx] = upgraded
	return upgraded


func create_upgraded_card(p_card: CardData) -> CardData:
	if p_card == null or not can_upgrade_card(p_card):
		return p_card

	var up: CardData = p_card.duplicate(true) as CardData
	up.id = p_card.id + "_plus"
	up.display_name = p_card.display_name + "+"

	var notes: PackedStringArray = PackedStringArray()
	if up.frame_cost >= 3:
		up.frame_cost -= 1
		up.step_frames = _clamp_local_frames(up.step_frames, up.frame_cost)
		up.tier_3_step_frames = _clamp_local_frames(up.tier_3_step_frames, up.frame_cost)
		up.hit_frames = _clamp_local_frames(up.hit_frames, up.frame_cost)
		up.edit_frames = _clamp_local_frames(up.edit_frames, up.frame_cost)
		notes.append("-1f cost")

	if up.base_damage > 0:
		up.base_damage += 3
		notes.append("+3 dmg")
	elif up.grants_shield > 0:
		up.grants_shield += 4
		notes.append("+4 shield")
	elif up.heals_hp > 0:
		up.heals_hp += 2
		notes.append("+2 heal")
	elif up.slip_intent_frames > 0:
		up.slip_intent_frames += 2
		notes.append("+2f slip")
	elif up.frame_cost == 2 and notes.is_empty():
		up.frame_cost = 1
		up.step_frames = _clamp_local_frames(up.step_frames, 1)
		up.edit_frames = _clamp_local_frames(up.edit_frames, 1)
		notes.append("1f cost")

	var upgrade_tag: String = " (" + ", ".join(notes) + ")" if not notes.is_empty() else " (Upgraded)"
	up.description = p_card.description + upgrade_tag
	return up


func compute_run_score(p_won_run: bool) -> int:
	var raw_score: int = (
		_scenes_cleared * 120
		+ _total_match_cuts * 35
		+ _total_pit_kills * 60
		+ (250 if p_won_run else 0)
		- _total_damage_taken * 4
	)
	return maxi(0, raw_score)


# --- Private Helpers ---

func _build_reward_pool() -> void:
	_reward_pool = [
		CARD_QUICK_STEP, CARD_DASH, CARD_SPRINT, CARD_PIVOT,
		CARD_JAB, CARD_APERTURE_PALM, CARD_KICK, CARD_GUARD, CARD_TWIN_STRIKE,
		CARD_DEVELOP, CARD_DUTCH_ANGLE, CARD_HOLD_FRAME, CARD_NEGATIVE_EXPOSURE,
		CARD_REWIND, CARD_SLIP, CARD_SWAP, CARD_TAG,
	]


func _build_enemy_roster_for_scene(p_scene: int, p_kind: NodeKind) -> Array[EnemyData]:
	var roster: Array[EnemyData] = []
	var hp_mult: float = (1.0 + float(p_scene - 1) * 0.12) * (1.28 if p_kind == NodeKind.ELITE else 1.0)
	var dmg_bonus: int = floori(float(p_scene - 1) / 3.0) + (1 if p_kind == NodeKind.ELITE else 0)

	if p_kind == NodeKind.BOSS:
		var is_final: bool = p_scene >= _total_scenes
		roster.append(_create_boss_enemy_data(is_final))
		roster.append(_clone_scaled_enemy(ENEMY_HOUND, 1.0, dmg_bonus))
		if is_final:
			roster.append(_clone_scaled_enemy(ENEMY_SNIPER, 1.0, dmg_bonus))
		return roster

	if p_scene == 1 and p_kind == NodeKind.NORMAL:
		roster.append(_clone_scaled_enemy(ENEMY_HOUND, 0.72, 0))
		roster.append(_clone_scaled_enemy(ENEMY_CLEAVER, 0.80, 0))
		return roster

	if p_scene == 2 and p_kind == NodeKind.NORMAL:
		roster.append(_clone_scaled_enemy(ENEMY_HOUND, 0.85, 0))
		roster.append(_clone_scaled_enemy(ENEMY_SNIPER, 1.0, 0))
		return roster

	var templates: Array[EnemyData] = [ENEMY_HOUND, ENEMY_CLEAVER, ENEMY_SNIPER]
	var enemy_count: int = 3
	if p_scene >= 6:
		enemy_count = 4

	for i: int in range(enemy_count):
		var tmpl: EnemyData = templates[(p_scene + i) % templates.size()]
		roster.append(_clone_scaled_enemy(tmpl, hp_mult, dmg_bonus))

	return roster


func _clone_scaled_enemy(p_template: EnemyData, p_hp_mult: float, p_dmg_bonus: int) -> EnemyData:
	var copy: EnemyData = p_template.duplicate(true) as EnemyData
	copy.max_hp = maxi(6, roundi(float(copy.max_hp) * p_hp_mult))
	if p_dmg_bonus > 0:
		for pat: EnemyTurnPattern in copy.turn_patterns:
			for atk: EnemyAttackData in pat.attacks:
				atk.damage += p_dmg_bonus
	return copy


func _create_boss_enemy_data(p_is_final_boss: bool) -> EnemyData:
	var boss: EnemyData = EnemyData.new()
	boss.id = "prime_projectionist" if p_is_final_boss else "chief_editor"
	boss.title = "The Prime" if p_is_final_boss else "Chief Editor"
	boss.symbol = "C"
	boss.max_hp = 46 if p_is_final_boss else 32

	var cleave_atk: EnemyAttackData = EnemyAttackData.new()
	cleave_atk.start_frame = 8
	cleave_atk.end_frame = 15
	cleave_atk.damage = 7 if p_is_final_boss else 6
	cleave_atk.local_offsets = [Vector2i(0, -1), Vector2i(-1, -1), Vector2i(1, -1)]

	var beam_atk: EnemyAttackData = EnemyAttackData.new()
	beam_atk.start_frame = 16 if p_is_final_boss else 13
	beam_atk.end_frame = 22
	beam_atk.damage = 8 if p_is_final_boss else 7
	beam_atk.is_beam = true
	beam_atk.beam_max_range = 6

	if p_is_final_boss:
		var pat_combo: EnemyTurnPattern = EnemyTurnPattern.new()
		pat_combo.pattern_name = "Double Reel"
		pat_combo.move_steps = 1
		pat_combo.preferred_range = 1
		pat_combo.attacks = [cleave_atk, beam_atk]
		boss.turn_patterns = [pat_combo]
	else:
		var pat_a: EnemyTurnPattern = EnemyTurnPattern.new()
		pat_a.pattern_name = "Heavy Splice"
		pat_a.move_steps = 1
		pat_a.preferred_range = 1
		pat_a.attacks = [cleave_atk]

		var pat_b: EnemyTurnPattern = EnemyTurnPattern.new()
		pat_b.pattern_name = "Projector Beam"
		pat_b.move_steps = 1
		pat_b.preferred_range = 3
		pat_b.attacks = [beam_atk]
		boss.turn_patterns = [pat_a, pat_b]

	return boss


func _pick_open_tile(
	p_grid_size: int,
	p_min_y: int,
	p_max_y: int,
	p_reserved: Array[Vector2i]
) -> Vector2i:
	for _attempt: int in range(60):
		var cand: Vector2i = Vector2i(
			_rng.randi_range(0, p_grid_size - 1),
			_rng.randi_range(p_min_y, p_max_y)
		)
		if not p_reserved.has(cand):
			return cand

	for y: int in range(p_min_y, p_max_y + 1):
		for x: int in range(p_grid_size):
			var fallback: Vector2i = Vector2i(x, y)
			if not p_reserved.has(fallback):
				return fallback
	return Vector2i.ZERO


func _clamp_local_frames(p_frames: Array[int], p_duration: int) -> Array[int]:
	var out: Array[int] = []
	var max_f: int = maxi(0, p_duration - 1)
	for f: int in p_frames:
		var clamped: int = clampi(f, 0, max_f)
		if not out.has(clamped):
			out.append(clamped)
	return out


func _summarize_card_list(p_cards: Array[CardData]) -> String:
	var counts: Dictionary[String, int] = {}
	var order: Array[String] = []
	for card: CardData in p_cards:
		var cname: String = card.display_name if not card.display_name.is_empty() else card.id
		if not counts.has(cname):
			counts[cname] = 0
			order.append(cname)
		counts[cname] += 1

	var parts: PackedStringArray = PackedStringArray()
	for cname: String in order:
		var cnt: int = counts[cname]
		parts.append("%s ×%d" % [cname, cnt] if cnt > 1 else cname)
	return ", ".join(parts)


func _load_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_best_scene = int(cfg.get_value(SAVE_SECTION, "best_scene", 0))
		_best_score = int(cfg.get_value(SAVE_SECTION, "best_score", 0))


func _update_and_save_records(p_won_run: bool) -> void:
	if _is_debug_mode:
		return
	var reached: int = _total_scenes if p_won_run else _current_scene
	if reached > _best_scene:
		_best_scene = reached
	var score: int = compute_run_score(p_won_run)
	if score > _best_score:
		_best_score = score
		_is_new_high_score = true

	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SAVE_SECTION, "best_scene", _best_scene)
	cfg.set_value(SAVE_SECTION, "best_score", _best_score)
	cfg.save(SAVE_PATH)	
