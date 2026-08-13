class_name Ac3_1RunRosterTests
extends SceneTree

const EXPECTED_TEST_COUNT := 2

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_run_character()
	_test_skills_are_defensive()
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
