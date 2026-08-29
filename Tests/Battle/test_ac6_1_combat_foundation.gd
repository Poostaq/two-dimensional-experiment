class_name Ac6_1CombatFoundationTests
extends SceneTree

const EXPECTED_TEST_COUNT: int = 14

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fresh_battle_stats()
	_test_physical_damage_formula()
	_test_formation_contract()
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


func _test_physical_damage_formula() -> void:
	_expect(BattleDamageRules.physical_damage(4, 0.85, 2) == 2, "85% rounds before Defense")
	_expect(BattleDamageRules.physical_damage(6, 1.20, 2) == 6, "ordinary damage uses ceil")
	_expect(BattleDamageRules.physical_damage(1, 0.60, 99) == 1, "direct damage minimum is one")
	_expect(BattleDamageRules.physical_damage(0, 1.0, 0) == -1, "invalid Power is rejected")


func _test_formation_contract() -> void:
	_expect(BattleFormationRules.is_front_slot(0), "slot 0 is front")
	_expect(BattleFormationRules.is_front_slot(2), "slot 2 is front")
	_expect(not BattleFormationRules.is_front_slot(3), "slot 3 is back")
	_expect(BattleFormationRules.is_back_slot(5), "slot 5 is back")
	_expect(BattleFormationRules.lane_of(4) == 1, "slot 4 is lane 1")
	_expect(BattleFormationRules.lane_distance(0, 5) == 2, "distance compares lanes")
	_expect(BattleFormationRules.lane_of(-1) == -1, "invalid slots are rejected")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
