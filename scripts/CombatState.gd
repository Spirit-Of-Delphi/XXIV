class_name CombatState
extends RefCounted

## Master snapshot container for a combat encounter. Fully encapsulated.

var _board: BoardState
var _player: PlayerState
var _enemies: Array[EnemyState] = []


func _init(p_board: BoardState = null, p_player: PlayerState = null) -> void:
	_board = p_board if p_board != null else BoardState.new()
	_player = p_player if p_player != null else PlayerState.new()


# --- Read-Only Properties ---

var board: BoardState:
	get: return _board

var player: PlayerState:
	get: return _player

var enemies: Array[EnemyState]:
	get: return _enemies.duplicate()


# --- Encapsulated API ---

func add_enemy(enemy: EnemyState) -> void:
	if enemy != null and not _enemies.has(enemy):
		_enemies.append(enemy)


func get_enemy_at(pos: Vector2i) -> EnemyState:
	for enemy: EnemyState in _enemies:
		if enemy.is_alive and enemy.grid_position == pos:
			return enemy
	return null


func get_living_enemies() -> Array[EnemyState]:
	var living: Array[EnemyState] = []
	for enemy: EnemyState in _enemies:
		if enemy.is_alive:
			living.append(enemy)
	return living


## Advances the 1-second (24-frame) freeze counters on all entities by 1 frame
func tick_all_freeze_timers() -> void:
	_player.tick_frame()
	for enemy: EnemyState in _enemies:
		enemy.tick_frame()


## Creates an isolated deep copy in microseconds
func clone() -> CombatState:
	var copy: CombatState = CombatState.new(_board.clone(), _player.clone())
	for enemy: EnemyState in _enemies:
		copy.add_enemy(enemy.clone())
	return copy
