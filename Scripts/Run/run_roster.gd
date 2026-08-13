class_name RunRoster
extends RefCounted

enum AddResult {
	ADDED,
	INVALID,
	DUPLICATE,
	FULL,
}

const MAX_ROSTER_SIZE := 6

var _characters: Array[RunCharacter] = []


func _init(starters: Array[RunCharacter] = []) -> void:
	_characters = RunCharacterCatalog.create_starters() if starters.is_empty() else starters.duplicate()


func size() -> int:
	return _characters.size()


func is_full() -> bool:
	return size() >= MAX_ROSTER_SIZE


func has_character(character_id: StringName) -> bool:
	for character: RunCharacter in _characters:
		if is_instance_valid(character) and character.character_id == character_id:
			return true
	return false


func can_add(character_id: StringName) -> bool:
	return not character_id.is_empty() and not is_full() and not has_character(character_id)


func try_add(character: RunCharacter) -> AddResult:
	if not is_instance_valid(character) or character.character_id.is_empty():
		return AddResult.INVALID
	if has_character(character.character_id):
		return AddResult.DUPLICATE
	if is_full():
		return AddResult.FULL
	_characters.append(character)
	return AddResult.ADDED


func get_characters() -> Array[RunCharacter]:
	return _characters.duplicate()


func create_battle_units() -> Array[BattleUnitState]:
	var units: Array[BattleUnitState] = []
	for slot_index: int in _characters.size():
		var character := _characters[slot_index]
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
