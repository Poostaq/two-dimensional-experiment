class_name Ac3_5PostBattleRecoveryTests
extends SceneTree

const EXPECTED_TEST_COUNT := 18
const RUN_STATE_PATH := "res://Scripts/Run/world_run_state.gd"

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

	var state_script := load(RUN_STATE_PATH) as GDScript
	var state := state_script.new() as WorldRunState
	state.battle_preparation = BattlePreparationRecord.none()
	var health: Dictionary[StringName, int] = {
		&"starter_vanguard": 17,
		&"starter_mage": 9,
	}
	_expect(state.set_character_hp_snapshot(health), "valid typed health snapshot is accepted")
	health[&"starter_vanguard"] = 1
	var first_snapshot: Dictionary[StringName, int] = state.get_character_hp_snapshot()
	_expect(first_snapshot[&"starter_vanguard"] == 17, "setter defensively copies health")
	first_snapshot[&"starter_mage"] = 1
	var second_snapshot: Dictionary[StringName, int] = state.get_character_hp_snapshot()
	_expect(second_snapshot[&"starter_mage"] == 9, "getter defensively copies health")
	var serialized: Dictionary = state.to_dictionary()
	_expect(serialized.get("character_hp") == {"starter_vanguard": 17, "starter_mage": 9}, "health serializes with string keys")
	var reordered_state := state_script.new() as WorldRunState
	reordered_state.battle_preparation = BattlePreparationRecord.none()
	var reordered_health: Dictionary[StringName, int] = {
		&"starter_mage": 9,
		&"starter_vanguard": 17,
	}
	reordered_state.set_character_hp_snapshot(reordered_health)
	_expect(reordered_state.canonical_key() == state.canonical_key(), "canonical health ordering is deterministic")
	var before_key: String = state.canonical_key()
	var changed_health: Dictionary[StringName, int] = {
		&"starter_vanguard": 16,
		&"starter_mage": 9,
	}
	_expect(state.set_character_hp_snapshot(changed_health), "replacement health snapshot is accepted")
	_expect(state.canonical_key() != before_key, "health participates in canonical key")
	_expect(
		not bool(state_script.call("_decode_character_hp", {1: 10}).get("ok", true)),
		"non-string serialized health ID is rejected"
	)
	var invalid_empty: Dictionary[StringName, int] = {&"": 1}
	_expect(not state.set_character_hp_snapshot(invalid_empty), "empty stable ID is rejected")
	var invalid_hp: Dictionary[StringName, int] = {&"starter_vanguard": 0}
	_expect(not state.set_character_hp_snapshot(invalid_hp), "HP below one is rejected")

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
