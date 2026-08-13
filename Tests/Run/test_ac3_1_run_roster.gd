class_name Ac3_1RunRosterTests
extends SceneTree

const EXPECTED_TEST_COUNT := 6

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_run_character()
	_test_skills_are_defensive()
	_test_fixed_starters()
	_test_combat_recruit_mapping()
	_test_boss_recruit_mapping()
	_test_catalog_returns_fresh_characters()
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
