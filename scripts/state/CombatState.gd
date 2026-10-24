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

func add_enemy(p_enemy: EnemyState) -> void:
	if p_enemy != null and not _enemies.has(p_enemy):
		_enemies.append(p_enemy)


func get_enemy_at(p_pos: Vector2i) -> EnemyState:
	for enemy: EnemyState in _enemies:
		if enemy.is_alive and enemy.grid_position == p_pos:
			return enemy
	return null


func get_enemy_by_id(p_id: int) -> EnemyState:
	for enemy: EnemyState in _enemies:
		if enemy.id == p_id:
			return enemy
	return null


func get_living_enemies() -> Array[EnemyState]:
	var living: Array[EnemyState] = []
	for enemy: EnemyState in _enemies:
		if enemy.is_alive:
			living.append(enemy)
	return living


## Creates an isolated deep copy in microseconds.
func clone() -> CombatState:
	var copy: CombatState = CombatState.new(_board.clone(), _player.clone())
	for enemy: EnemyState in _enemies:
		copy.add_enemy(enemy.clone())
	return copy
