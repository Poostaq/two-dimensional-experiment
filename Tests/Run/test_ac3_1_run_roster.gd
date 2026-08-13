class_name Ac3_1RunRosterTests
extends SceneTree

const EXPECTED_TEST_COUNT := 13

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_run_character()
	_test_skills_are_defensive()
	_test_fixed_starters()
	_test_combat_recruit_mapping()
	_test_boss_recruit_mapping()
	_test_catalog_returns_fresh_characters()
	_test_roster_initialization()
	_test_valid_add()
	_test_duplicate_rejection()
	_test_full_rejection()
	_test_invalid_rejection()
	_test_roster_snapshot_is_defensive()
	_test_battle_conversion_is_fresh()
	if _failures.is_empty():
		print("AC3.1 run roster tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_valid_run_character() -> void:
	var character := RunCharacter.new(&"starter_guard", "Starter Guard", 8, 20, [])
	_expect(character.character_id == &"starter_guard", "character keeps stable ID")
	_expect(character.display_name == "Starter Guard", "character keeps display name")
	_expect(character.base_speed == 8 and character.max_hp == 20, "character keeps base combat data")


func _test_skills_are_defensive() -> void:
	var source: Array[CharacterSkill] = []
	var character := RunCharacter.new(&"starter_guard", "Starter Guard", 8, 20, source)
	source.append(null)
	_expect(character.get_skills().is_empty(), "constructor defensively copies skills")
	var snapshot := character.get_skills()
	snapshot.append(null)
	_expect(character.get_skills().is_empty(), "getter defensively copies skills")


func _test_fixed_starters() -> void:
	var starters := RunCharacterCatalog.create_starters()
	_expect(starters.size() == 3, "catalog returns exactly three starters")
	_expect(starters[0].character_id == &"player_0", "first existing player fixture is first")
	_expect(starters[1].character_id == &"player_1", "second existing player fixture is second")
	_expect(starters[2].character_id == &"player_2", "third existing player fixture is third")


func _test_combat_recruit_mapping() -> void:
	var recruit := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	_expect(is_instance_valid(recruit), "Combat recruit resolves")
	_expect(recruit.character_id == &"scout", "Combat recruit resolves to Scout")


func _test_boss_recruit_mapping() -> void:
	var recruit := RunCharacterCatalog.create_for_reward(&"boss_recruit_champion")
	_expect(is_instance_valid(recruit), "Boss recruit resolves")
	_expect(recruit.character_id == &"champion", "Boss recruit resolves to Champion")


func _test_catalog_returns_fresh_characters() -> void:
	var first := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	var second := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	_expect(first != second, "catalog calls return fresh characters")
	_expect(RunCharacterCatalog.create_for_reward(&"combat_money_100") == null, "non-recruit rewards do not map")
	_expect(RunCharacterCatalog.create_for_reward(&"unknown_recruit") == null, "unknown rewards do not map")


func _test_roster_initialization() -> void:
	var roster := RunRoster.new()
	var characters := roster.get_characters()
	_expect(roster.size() == 3, "roster starts with three characters")
	_expect(characters[0].character_id == &"player_0", "roster keeps starter order")
	_expect(not roster.is_full(), "starter roster is not full")
	_expect(roster.can_add(&"scout"), "Scout is eligible initially")


func _test_valid_add() -> void:
	var roster := RunRoster.new()
	var result := roster.try_add(RunCharacterCatalog.create_for_reward(&"combat_recruit_scout"))
	_expect(result == RunRoster.AddResult.ADDED, "eligible Scout is added")
	_expect(roster.size() == 4 and roster.has_character(&"scout"), "successful add mutates once")


func _test_duplicate_rejection() -> void:
	var roster := RunRoster.new()
	roster.try_add(RunCharacterCatalog.create_for_reward(&"combat_recruit_scout"))
	var result := roster.try_add(RunCharacterCatalog.create_for_reward(&"combat_recruit_scout"))
	_expect(result == RunRoster.AddResult.DUPLICATE, "duplicate is rejected")
	_expect(roster.size() == 4 and not roster.can_add(&"scout"), "duplicate does not mutate roster")


func _test_full_rejection() -> void:
	var starters: Array[RunCharacter] = [
		RunCharacter.new(&"a", "A", 1, 10, []),
		RunCharacter.new(&"b", "B", 1, 10, []),
		RunCharacter.new(&"c", "C", 1, 10, []),
		RunCharacter.new(&"d", "D", 1, 10, []),
		RunCharacter.new(&"e", "E", 1, 10, []),
		RunCharacter.new(&"f", "F", 1, 10, []),
	]
	var roster := RunRoster.new(starters)
	var result := roster.try_add(RunCharacter.new(&"g", "G", 1, 10, []))
	_expect(roster.is_full(), "six-character roster is full")
	_expect(result == RunRoster.AddResult.FULL and roster.size() == 6, "full roster rejects seventh")


func _test_invalid_rejection() -> void:
	var roster := RunRoster.new()
	_expect(roster.try_add(null) == RunRoster.AddResult.INVALID, "null character is invalid")
	_expect(roster.try_add(RunCharacter.new(&"", "Invalid", 1, 10, [])) == RunRoster.AddResult.INVALID, "empty ID is invalid")
	_expect(roster.size() == 3, "invalid characters do not mutate roster")


func _test_roster_snapshot_is_defensive() -> void:
	var roster := RunRoster.new()
	var snapshot := roster.get_characters()
	snapshot.clear()
	_expect(roster.size() == 3, "roster snapshot cannot clear ownership")


func _test_battle_conversion_is_fresh() -> void:
	var roster := RunRoster.new()
	var first := roster.create_battle_units()
	_expect(first.size() == roster.size(), "battle conversion includes every roster character")
	_expect(first[0].side == BattleUnitState.Side.PLAYER and first[0].slot_index == 0, "battle conversion assigns player slot")
	_expect(first[0].unit_id == roster.get_characters()[0].character_id, "battle conversion preserves identity")
	_expect(first[0].current_hp == first[0].max_hp, "battle conversion starts at full HP")
	first[0].current_hp = 1
	first[0].set_skill_cooldown(&"test", 3)
	var second := roster.create_battle_units()
	_expect(second[0] != first[0], "later battle receives a fresh state object")
	_expect(second[0].current_hp == second[0].max_hp, "battle HP does not leak")
	_expect(second[0].get_skill_cooldown(&"test") == 0, "battle cooldown does not leak")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
