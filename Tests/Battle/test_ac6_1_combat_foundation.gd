class_name Ac6_1CombatFoundationTests
extends SceneTree

const EXPECTED_TEST_COUNT: int = 3

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fresh_battle_stats()
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC6.1 combat foundation: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_fresh_battle_stats() -> void:
	var skills: Array[CharacterSkill] = []
	var character := RunCharacter.new(&"goblin", "Goblin", 9, 20, skills, 7, 2)
	var starters: Array[RunCharacter] = [character]
	var roster := RunRoster.new(starters)
	var first: BattleUnitState = roster.create_battle_units()[0]
	_expect(first.power == 7 and first.defense == 2, "base combat stats copy into battle")
	first.power = 1
	first.defense = 0
	var second: BattleUnitState = roster.create_battle_units()[0]
	_expect(second.power == 7 and second.defense == 2, "battle stat mutation does not leak")
	_expect(character.power == 7 and character.defense == 2, "run definition stays immutable")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
