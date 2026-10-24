class_name DeckState
extends RefCounted

## Encapsulated, deterministic deck & hand manager supporting reversible timeline staging,
## mid-draw discard reshuffling, Exhaust, and Retain.
## Note: The BACK of _draw_pile is the top of the deck for O(1) pop_back() drawing.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _draw_pile: Array[CardData] = []
var _hand: Array[CardData] = []
## Cards currently placed on the TimelinePlan during the planning phase before committing.
var _staged: Array[CardData] = []
var _discard_pile: Array[CardData] = []
var _exhaust_pile: Array[CardData] = []


func _init(p_starting_deck: Array[CardData] = [], p_seed: int = 1) -> void:
	_rng.seed = p_seed
	_draw_pile = p_starting_deck.duplicate()
	_shuffle_pile(_draw_pile)


# --- Read-Only Properties ---

var draw_pile: Array[CardData]:
	get: return _draw_pile.duplicate()

var hand: Array[CardData]:
	get: return _hand.duplicate()

var staged: Array[CardData]:
	get: return _staged.duplicate()

var discard_pile: Array[CardData]:
	get: return _discard_pile.duplicate()

var exhaust_pile: Array[CardData]:
	get: return _exhaust_pile.duplicate()

var draw_count: int:
	get: return _draw_pile.size()

var hand_count: int:
	get: return _hand.size()

var staged_count: int:
	get: return _staged.size()

var discard_count: int:
	get: return _discard_pile.size()

var exhaust_count: int:
	get: return _exhaust_pile.size()


# --- Encapsulated Deck Lifecycle API ---

## Draws up to p_count cards into _hand (respecting p_max_hand_size).
## Automatically reshuffles _discard_pile into _draw_pile if _draw_pile empties mid-draw.
## Returns the array of newly drawn cards (for UI draw animations).
func draw_cards(p_count: int, p_max_hand_size: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	if p_count <= 0:
		return drawn

	for i: int in range(p_count):
		if _hand.size() >= p_max_hand_size:
			break
		if _draw_pile.is_empty():
			if _discard_pile.is_empty():
				break
			_reshuffle_discard_into_draw()

		var next_card: CardData = _draw_pile.pop_back()
		_hand.append(next_card)
		drawn.append(next_card)

	return drawn


## Moves one instance of p_card from _hand to _staged when placed onto the timeline.
func stage_card(p_card: CardData) -> bool:
	if p_card == null or not _remove_one(_hand, p_card):
		return false
	_staged.append(p_card)
	return true


## Returns one instance of p_card from _staged back to _hand when removed from the timeline.
func unstage_card(p_card: CardData) -> bool:
	if p_card == null or not _remove_one(_staged, p_card):
		return false
	_hand.append(p_card)
	return true


## Returns all staged timeline cards back to _hand (e.g. "Clear Timeline" button).
func unstage_all() -> void:
	for card: CardData in _staged:
		_hand.append(card)
	_staged.clear()


## Finalizes the take: sends staged cards to Exhaust or Discard, and discards non-retained hand cards.
func commit_take() -> void:
	for card: CardData in _staged:
		if card.exhausts_on_play:
			_exhaust_pile.append(card)
		else:
			_discard_pile.append(card)
	_staged.clear()

	var retained: Array[CardData] = []
	for card: CardData in _hand:
		if card.retains_in_hand:
			retained.append(card)
		else:
			_discard_pile.append(card)
	_hand = retained


## Adds a generated or newly acquired card directly into _hand (or _discard_pile if hand is full).
func add_card_to_hand(p_card: CardData, p_max_hand_size: int) -> void:
	if p_card == null:
		return
	if _hand.size() < p_max_hand_size:
		_hand.append(p_card)
	else:
		_discard_pile.append(p_card)


func clone() -> DeckState:
	var copy: DeckState = DeckState.new([], _rng.seed)
	copy._rng.state = _rng.state
	copy._draw_pile = _draw_pile.duplicate()
	copy._hand = _hand.duplicate()
	copy._staged = _staged.duplicate()
	copy._discard_pile = _discard_pile.duplicate()
	copy._exhaust_pile = _exhaust_pile.duplicate()
	return copy


# --- Private Helpers ---

func _reshuffle_discard_into_draw() -> void:
	_draw_pile.append_array(_discard_pile)
	_discard_pile.clear()
	_shuffle_pile(_draw_pile)


func _shuffle_pile(p_pile: Array[CardData]) -> void:
	var count: int = p_pile.size()
	if count <= 1:
		return
	for i: int in range(count - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp: CardData = p_pile[i]
		p_pile[i] = p_pile[j]
		p_pile[j] = temp


func _remove_one(p_pile: Array[CardData], p_card: CardData) -> bool:
	var idx: int = p_pile.find(p_card)
	if idx < 0:
		return false
	p_pile.remove_at(idx)
	return true
