class_name Ac6_3GoblinWaveATests
extends SceneTree

const TARGET_PROFILE_PATH := "res://Scripts/Battle/battle_skill_target_profile.gd"
const EFFECT_DEFINITION_PATH := "res://Scripts/Battle/battle_skill_effect_definition.gd"
const CONDITION_PATH := "res://Scripts/Battle/battle_skill_condition.gd"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	_test_authoring_value_objects()
	if _failures.is_empty():
		print("AC6.3 Goblin wave A: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC6.3 Goblin wave A: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)


func _test_authoring_value_objects() -> void:
	var target_profile_script := load(TARGET_PROFILE_PATH) as Script
	var effect_definition_script := load(EFFECT_DEFINITION_PATH) as Script
	var condition_script := load(CONDITION_PATH) as Script
	_expect(is_instance_valid(target_profile_script), "target profile script exists")
	_expect(is_instance_valid(effect_definition_script), "effect definition script exists")
	_expect(is_instance_valid(condition_script), "condition script exists")
	if not is_instance_valid(target_profile_script) or not is_instance_valid(effect_definition_script) or not is_instance_valid(condition_script):
		return

	var one_enemy: RefCounted = target_profile_script.create(1, 1, BattleUnitState.Side.ENEMY, false, false)
	var one_or_two_enemies: RefCounted = target_profile_script.create(1, 2, BattleUnitState.Side.ENEMY, false, false)
	var adjacent_ally: RefCounted = target_profile_script.create(1, 1, BattleUnitState.Side.PLAYER, true, false)
	var optional_self_move: RefCounted = target_profile_script.create(0, 0, BattleUnitState.Side.PLAYER, false, true)
	var damage: RefCounted = effect_definition_script.damage(
		effect_definition_script.TargetRole.PRIMARY,
		85
	)
	var armor: RefCounted = effect_definition_script.keyword(
		effect_definition_script.TargetRole.HISTORY_ALLY,
		BattleKeywordOperation.Kind.ADD_ARMOR,
		2
	)
	var snared: RefCounted = condition_script.create(condition_script.Kind.PRIMARY_SNARED)

	_expect(is_instance_valid(one_enemy) and one_enemy.is_valid(), "single enemy profile is valid")
	_expect(one_or_two_enemies.maximum_targets == 2, "Ring Net can lock two enemies")
	_expect(adjacent_ally.require_adjacent_lane, "Pack Brace requires adjacency")
	_expect(optional_self_move.allows_optional_self_move, "Slipstep exposes optional Move 1")
	_expect(damage.power_percent == 85, "damage stores integer Power percentage")
	_expect(armor.target_role == effect_definition_script.TargetRole.HISTORY_ALLY, "history recipient is semantic")
	_expect(is_instance_valid(snared) and snared.is_valid(), "Snared condition is valid")

	_expect(target_profile_script.create(0, 0, BattleUnitState.Side.ENEMY, false, false) == null, "empty non-movement profile rejects")
	_expect(target_profile_script.create(2, 1, BattleUnitState.Side.ENEMY, false, false) == null, "minimum above maximum rejects")
	_expect(target_profile_script.create(1, 3, BattleUnitState.Side.ENEMY, false, false) == null, "more than two selected targets rejects")
	_expect(target_profile_script.create(1, 1, BattleUnitState.Side.PLAYER, false, true) == null, "movement combined with selection rejects")
	_expect(effect_definition_script.damage(effect_definition_script.TargetRole.PRIMARY, 0) == null, "non-positive Power percentage rejects")
	_expect(
		effect_definition_script.keyword(
			effect_definition_script.TargetRole.PRIMARY,
			BattleKeywordOperation.Kind.ADD_ARMOR,
			0
		) == null,
		"Armor without magnitude rejects"
	)
	_expect(
		effect_definition_script.keyword(
			effect_definition_script.TargetRole.PRIMARY,
			BattleKeywordOperation.Kind.APPLY_SNARED,
			0,
			0
		) == null,
		"Snared without duration rejects"
	)
	_expect(condition_script.create(999) == null, "unknown condition rejects")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
