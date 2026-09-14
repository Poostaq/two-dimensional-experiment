class_name Ac3_5PostBattleRecoveryTests
extends SceneTree

const EXPECTED_TEST_COUNT := 8

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"survivor", 7, 20) == 20, "survivor fully heals")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"defeated_even", 0, 20) == 10, "defeated character recovers half of even max HP")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"defeated_odd", 0, 19) == 10, "defeated character recovers rounded-up half of odd max HP")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"", 0, 20) == -1, "empty character ID is invalid")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"negative_hp", -1, 20) == -1, "negative final HP is invalid")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"over_max", 21, 20) == -1, "final HP above max HP is invalid")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"zero_max", 0, 0) == -1, "zero max HP is invalid")
	_expect(PostBattleRecoveryRules.calculate_next_hp(&"negative_max", 0, -1) == -1, "negative max HP is invalid")

	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC3.5 post-battle recovery tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
