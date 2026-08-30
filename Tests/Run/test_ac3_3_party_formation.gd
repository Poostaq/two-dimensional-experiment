class_name Ac3_3PartyFormationTests
extends SceneTree

const EXPECTED_TEST_COUNT := 37

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var roster := RunRoster.new()
	var slots := roster.get_slot_snapshot()
	_expect(slots.size() == 6, "snapshot exposes six slots")
	_expect(_id_at(slots, 0) == &"player_0", "starter 0 keeps slot 0")
	_expect(_id_at(slots, 1) == &"player_1", "starter 1 keeps slot 1")
	_expect(_id_at(slots, 2) == &"player_2", "starter 2 keeps slot 2")
	_expect(slots[3] == null and slots[4] == null and slots[5] == null, "remaining slots are empty")
	_expect(roster.size() == 3 and not roster.is_full(), "size counts occupied slots")

	var scout := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	_expect(roster.can_add_at(scout.character_id, 5), "empty explicit slot is eligible")
	_expect(roster.try_add_at(scout, 5) == RunRoster.AddResult.ADDED, "explicit empty placement succeeds")
	_expect(roster.size() == 4 and _id_at(roster.get_slot_snapshot(), 5) == &"scout", "addition preserves chosen slot")
	_expect(roster.try_add_at(scout, 4) == RunRoster.AddResult.DUPLICATE, "duplicate is rejected")
	_expect(roster.try_add_at(_character(&"extra", "Extra"), 5) == RunRoster.AddResult.OCCUPIED, "occupied placement is rejected")
	_expect(roster.try_add_at(_character(&"bad_slot", "Bad"), -1) == RunRoster.AddResult.INVALID_SLOT, "invalid placement index is rejected")

	_expect(roster.try_move(0, 5, &"player_0") == RunRoster.MoveResult.SWAPPED, "occupied drop swaps")
	_expect(_id_at(roster.get_slot_snapshot(), 0) == &"scout" and _id_at(roster.get_slot_snapshot(), 5) == &"player_0", "swap updates both slots")
	_expect(roster.try_move(5, 4, &"player_0") == RunRoster.MoveResult.MOVED, "empty drop moves")
	_expect(roster.get_character_at(5) == null and roster.get_character_at(4).character_id == &"player_0", "move leaves source empty")
	_expect(roster.try_move(4, 4, &"player_0") == RunRoster.MoveResult.SAME_SLOT, "same-slot move is rejected")
	_expect(roster.try_move(5, 3, &"player_0") == RunRoster.MoveResult.EMPTY_SOURCE, "empty source is rejected")
	_expect(roster.try_move(4, 3, &"stale") == RunRoster.MoveResult.STALE_SOURCE, "stale source identity is rejected")
	_expect(roster.try_move(7, 3, &"player_0") == RunRoster.MoveResult.INVALID_SLOT, "invalid move index is rejected")

	var snapshot := roster.get_slot_snapshot()
	snapshot[0] = null
	_expect(roster.get_character_at(0).character_id == &"scout", "slot snapshot is defensive")
	var occupied := roster.get_characters()
	_expect(_ids(occupied) == [&"scout", &"player_1", &"player_2", &"player_0"], "occupied snapshot follows ascending slots")
	var units := roster.create_battle_units()
	_expect(_unit_slots(units) == [0, 1, 2, 4], "battle conversion preserves gaps")

	_expect(roster.try_add_at(_character(&"fifth", "Fifth"), 3) == RunRoster.AddResult.ADDED and roster.try_add_at(_character(&"sixth", "Sixth"), 5) == RunRoster.AddResult.ADDED and roster.is_full(), "explicit additions reach full capacity")

	var replacement := _character(&"replacement", "Replacement")
	_expect(
		roster.try_replace_at(replacement, 4, &"player_0") == RunRoster.ReplaceResult.REPLACED,
		"full roster replacement succeeds"
	)
	_expect(roster.size() == 6, "replacement preserves size six")
	_expect(roster.get_character_at(4) == replacement, "replacement preserves target slot")
	_expect(not roster.has_character(&"player_0") and roster.has_character(&"replacement"), "replacement updates membership")
	_expect(_unit_id_at(roster.create_battle_units(), 4) == &"replacement", "battle conversion uses replaced slot")
	var replacement_unit: BattleUnitState = _unit_at(roster.create_battle_units(), 4)
	_expect(
		is_instance_valid(replacement_unit)
		and replacement_unit.power == 7
		and replacement_unit.defense == 2,
		"battle conversion preserves Power and Defense"
	)

	var replaced_snapshot := roster.get_slot_snapshot()
	_expect(
		roster.try_replace_at(_character(&"invalid_slot", "Invalid"), -1, &"replacement") == RunRoster.ReplaceResult.INVALID_SLOT
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"invalid replacement slot is mutation-free"
	)
	_expect(
		roster.try_replace_at(null, 4, &"replacement") == RunRoster.ReplaceResult.INVALID_RECRUIT
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"invalid recruit is mutation-free"
	)
	_expect(
		roster.try_replace_at(_character(&"player_1", "Duplicate"), 4, &"replacement") == RunRoster.ReplaceResult.DUPLICATE
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"duplicate replacement is mutation-free"
	)
	_expect(
		roster.try_replace_at(_character(&"stale", "Stale"), 4, &"player_0") == RunRoster.ReplaceResult.STALE_TARGET
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"stale target is mutation-free"
	)
	_expect(
		roster.try_replace_at(replacement, 4, &"replacement") == RunRoster.ReplaceResult.DUPLICATE
		and _same_slots(replaced_snapshot, roster.get_slot_snapshot()),
		"repeated replacement is mutation-free"
	)

	var non_full := RunRoster.new()
	var non_full_before := non_full.get_slot_snapshot()
	_expect(
		non_full.try_replace_at(_character(&"early", "Early"), 0, &"player_0") == RunRoster.ReplaceResult.NOT_FULL
		and _same_slots(non_full_before, non_full.get_slot_snapshot()),
		"non-full roster replacement is rejected"
	)
	_expect(not roster.has_character(&"player_0"), "dismissed character is absent and may be eligible later")

	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC3.3 party formation tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _character(id: StringName, display_name: String) -> RunCharacter:
	var skills: Array[CharacterSkill] = []
	return RunCharacter.new(id, display_name, 5, 20, skills, 7, 2)


func _id_at(slots: Array[RunCharacter], slot_index: int) -> StringName:
	var character := slots[slot_index]
	return character.character_id if is_instance_valid(character) else &""


func _ids(characters: Array[RunCharacter]) -> Array[StringName]:
	var result: Array[StringName] = []
	for character: RunCharacter in characters:
		result.append(character.character_id)
	return result


func _unit_slots(units: Array[BattleUnitState]) -> Array[int]:
	var result: Array[int] = []
	for unit: BattleUnitState in units:
		result.append(unit.slot_index)
	return result


func _unit_id_at(units: Array[BattleUnitState], slot_index: int) -> StringName:
	var unit: BattleUnitState = _unit_at(units, slot_index)
	return unit.unit_id if is_instance_valid(unit) else &""


func _unit_at(units: Array[BattleUnitState], slot_index: int) -> BattleUnitState:
	for unit: BattleUnitState in units:
		if unit.slot_index == slot_index:
			return unit
	return null


func _same_slots(left: Array[RunCharacter], right: Array[RunCharacter]) -> bool:
	if left.size() != right.size():
		return false
	for slot_index: int in left.size():
		if left[slot_index] != right[slot_index]:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
