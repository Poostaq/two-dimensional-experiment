class_name RunRoster
extends RefCounted

enum AddResult {
	ADDED,
	INVALID,
	DUPLICATE,
	FULL,
	INVALID_SLOT,
	OCCUPIED,
}

enum MoveResult {
	MOVED,
	SWAPPED,
	INVALID_SLOT,
	EMPTY_SOURCE,
	STALE_SOURCE,
	SAME_SLOT,
}

const MAX_ROSTER_SIZE := 6

var _slots: Array[RunCharacter] = []


func _init(starters: Array[RunCharacter] = []) -> void:
	_slots.resize(MAX_ROSTER_SIZE)
	var initial := RunCharacterCatalog.create_starters() if starters.is_empty() else starters.duplicate()
	for slot_index: int in min(initial.size(), MAX_ROSTER_SIZE):
		_slots[slot_index] = initial[slot_index]


func size() -> int:
	var occupied_count := 0
	for character: RunCharacter in _slots:
		if is_instance_valid(character):
			occupied_count += 1
	return occupied_count


func is_full() -> bool:
	return size() >= MAX_ROSTER_SIZE


func has_character(character_id: StringName) -> bool:
	for character: RunCharacter in _slots:
		if is_instance_valid(character) and character.character_id == character_id:
			return true
	return false


func can_add(character_id: StringName) -> bool:
	return not character_id.is_empty() and not is_full() and not has_character(character_id)


func can_add_at(character_id: StringName, slot_index: int) -> bool:
	return (
		_is_valid_slot(slot_index)
		and not is_instance_valid(_slots[slot_index])
		and can_add(character_id)
	)


func try_add_at(character: RunCharacter, slot_index: int) -> AddResult:
	if not is_instance_valid(character) or character.character_id.is_empty():
		return AddResult.INVALID
	if not _is_valid_slot(slot_index):
		return AddResult.INVALID_SLOT
	if has_character(character.character_id):
		return AddResult.DUPLICATE
	if is_full():
		return AddResult.FULL
	if is_instance_valid(_slots[slot_index]):
		return AddResult.OCCUPIED
	_slots[slot_index] = character
	return AddResult.ADDED


func try_add(character: RunCharacter) -> AddResult:
	if not is_instance_valid(character) or character.character_id.is_empty():
		return AddResult.INVALID
	if has_character(character.character_id):
		return AddResult.DUPLICATE
	if is_full():
		return AddResult.FULL
	for slot_index: int in MAX_ROSTER_SIZE:
		if not is_instance_valid(_slots[slot_index]):
			return try_add_at(character, slot_index)
	return AddResult.FULL


func try_move(
	source_slot: int,
	destination_slot: int,
	expected_character_id: StringName
) -> MoveResult:
	if not _is_valid_slot(source_slot) or not _is_valid_slot(destination_slot):
		return MoveResult.INVALID_SLOT
	if source_slot == destination_slot:
		return MoveResult.SAME_SLOT
	var source: RunCharacter = _slots[source_slot]
	if not is_instance_valid(source):
		return MoveResult.EMPTY_SOURCE
	if source.character_id != expected_character_id:
		return MoveResult.STALE_SOURCE
	var destination: RunCharacter = _slots[destination_slot]
	_slots[destination_slot] = source
	_slots[source_slot] = destination
	return MoveResult.SWAPPED if is_instance_valid(destination) else MoveResult.MOVED


func get_character_at(slot_index: int) -> RunCharacter:
	if not _is_valid_slot(slot_index):
		return null
	return _slots[slot_index]


func get_slot_snapshot() -> Array[RunCharacter]:
	return _slots.duplicate()


func get_characters() -> Array[RunCharacter]:
	var characters: Array[RunCharacter] = []
	for character: RunCharacter in _slots:
		if is_instance_valid(character):
			characters.append(character)
	return characters


func create_battle_units() -> Array[BattleUnitState]:
	var units: Array[BattleUnitState] = []
	for slot_index: int in MAX_ROSTER_SIZE:
		var character := _slots[slot_index]
		if not is_instance_valid(character):
			continue
		units.append(BattleUnitState.new(
			character.character_id,
			character.display_name,
			BattleUnitState.Side.PLAYER,
			slot_index,
			character.base_speed,
			character.max_hp,
			character.get_skills()
		))
	return units


func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < MAX_ROSTER_SIZE
