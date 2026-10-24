class_name EncounterData
extends Resource

## Inspector-authored blueprint for a complete combat encounter.

const PLAYER_ENTITY_ID: int = 1
const FIRST_ENEMY_ENTITY_ID: int = 101

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""

@export_group("Arena Layout")
@export_range(3, 12) var grid_size: int = BoardState.DEFAULT_GRID_SIZE
@export var walls: Array[Vector2i] = []
@export var pits: Array[Vector2i] = []

@export_group("Player & Deck")
@export var player_start_position: Vector2i = Vector2i(2, 4)
@export var player_start_direction: Types.Direction = Types.Direction.NORTH
@export var starting_deck: Array[CardData] = []
@export var rng_seed: int = 1

@export_group("Enemies")
@export var enemy_spawns: Array[EnemySpawnData] = []


## Instantiates an isolated, ready-to-start CombatEncounter from this Resource.
func create_encounter(p_config: CombatConfig) -> CombatEncounter:
	var board: BoardState = BoardState.new(grid_size)
	for wall_pos: Vector2i in walls:
		board.add_wall(wall_pos)
	for pit_pos: Vector2i in pits:
		board.add_pit(pit_pos)

	var player: PlayerState = PlayerState.new()
	player.set_identity(PLAYER_ENTITY_ID, p_config.player_max_hp)
	player.set_position_and_direction(player_start_position, player_start_direction)

	var initial_state: CombatState = CombatState.new(board, player)
	var next_enemy_id: int = FIRST_ENEMY_ENTITY_ID
	for spawn: EnemySpawnData in enemy_spawns:
		if spawn == null or spawn.enemy_data == null:
			continue
		var enemy: EnemyState = EnemyState.new()
		enemy.set_identity(next_enemy_id, spawn.enemy_data.max_hp)
		enemy.set_enemy_data(spawn.enemy_data)
		enemy.set_position_and_direction(spawn.grid_position, spawn.direction)
		initial_state.add_enemy(enemy)
		next_enemy_id += 1

	var deck: DeckState = DeckState.new(starting_deck, rng_seed)
	return CombatEncounter.new(initial_state, deck, p_config)
