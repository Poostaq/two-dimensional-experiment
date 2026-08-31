class_name Ac6_4GoblinWaveBTests
extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	var goblin := RunCharacter.new(
		&"scrapbroker",
		"Scrapbroker",
		8,
		18,
		[],
		3,
		1,
		&"goblin"
	)
	var roster := RunRoster.new([goblin])
	var battle_units := roster.create_battle_units()
	_expect(goblin.race_id == &"goblin", "run character stores stable race identity")
	_expect(battle_units[0].race_id == &"goblin", "battle conversion preserves race identity")
	_expect(battle_units[0].unit_id == goblin.character_id, "race propagation preserves identity")
	var legacy := RunCharacter.new(&"legacy", "Legacy", 1, 10, [])
	_expect(legacy.race_id == &"unknown", "legacy constructors default race identity")
	_test_wave_b_condition_contracts()
	_test_wave_b_history_queries()
	if _failures.is_empty():
		print("AC6.4 Goblin wave B: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_wave_b_condition_contracts() -> void:
	var kinds: Array[int] = [
		BattleSkillCondition.Kind.PRIMARY_BLEEDING,
		BattleSkillCondition.Kind.PRIMARY_BELOW_HALF_HP,
		BattleSkillCondition.Kind.PRIMARY_HIT_BY_ALLY_THIS_ROUND,
		BattleSkillCondition.Kind.PRIMARY_CONSUMED_ADVANTAGE_THIS_ROUND,
		BattleSkillCondition.Kind.ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND,
		BattleSkillCondition.Kind.PRIMARY_DIFFERENT_RACE_FROM_ACTOR,
	]
	for kind: int in kinds:
		var condition := BattleSkillCondition.create(kind)
		_expect(is_instance_valid(condition), "Wave B condition is constructible: %d" % kind)
		_expect(condition.duplicate_condition().kind == kind, "Wave B condition duplicates: %d" % kind)


func _test_wave_b_history_queries() -> void:
	var source := BattleKeywordSource.create(&"setter", &"spot_buyer", 3)
	var records: Array[BattleActionRecord] = [
		BattleActionRecord.new(
			BattleActionRecord.Kind.SKILL, &"ally_a", [&"enemy"], {&"enemy": 2},
			{}, {}, 1, 1, 1, BattleUnitState.Side.PLAYER, &"attack", true,
			{&"enemy": true}
		),
		BattleActionRecord.new(
			BattleActionRecord.Kind.SKILL, &"ally_b", [&"enemy"], {&"enemy": 3},
			{}, {}, 1, 2, 2, BattleUnitState.Side.PLAYER, &"finish", true,
			{&"enemy": true}, [], source
		),
	]
	_expect(
		BattleHistoryQuery.consumed_advantage_this_round(records, &"ally_b", 1),
		"history finds the selected ally's Advantage consumption"
	)
	_expect(
		BattleHistoryQuery.ally_acted_before_this_round(
			records, BattleUnitState.Side.PLAYER, &"shivrunner", 1
		),
		"history finds an earlier allied committed action"
	)
	_expect(
		BattleHistoryQuery.was_directly_hit_by_ally_this_round(
			records, BattleUnitState.Side.PLAYER, &"enemy", &"mobcaller", 1
		),
		"history finds an earlier allied direct hit"
	)
	_expect(
		BattleHistoryQuery.distinct_allied_attackers_this_round(
			records, BattleUnitState.Side.PLAYER, &"enemy", &"mobcaller", 1
		) == [&"ally_a", &"ally_b"],
		"history returns stable distinct prior allied attackers"
	)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
