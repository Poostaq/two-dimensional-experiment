class_name EnemySkillRulesTests
extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var effects: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd")
	var history: Script = load("res://Scripts/Battle/battle_history_query.gd")
	_expect(effects.has_method("conditional_damage"), "conditional damage supports moved/status/armor bonuses")
	_expect(effects.has_method("armor_stripping_damage"), "pre-hit Armor strip is authored")
	_expect(history.has_method("armor_lost_this_round"), "actual Armor loss is queryable by round")
	_expect(history.has_method("moved_this_round"), "target movement is queryable by round")
	if effects.has_method("conditional_damage") and history.has_method("armor_lost_this_round"):
		_test_rules(effects, history)
	if _failures.is_empty():
		print("Enemy skill rules: %d assertions passed." % _assertions)
	else:
		for failure: String in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _test_rules(effects: Script, history: Script) -> void:
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.ENEMY, 0, 5, 30, [], 10, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.PLAYER, 1, 5, 50, [], 4, 0)
	var source := BattleKeywordSource.create(&"setter", &"mark", 4)
	var records: Array[BattleActionRecord] = [
		BattleActionRecord.new(BattleActionRecord.Kind.SKILL, &"setter", [&"target"], {}, {&"target": 0}, {&"target": 1}, 1, 1, 1, BattleUnitState.Side.ENEMY, &"break", true, {}, [{&"kind": BattleKeywordOperation.Kind.ADD_ARMOR, &"target_id": &"target", &"value": -3}])
	]
	_expect(history.call("armor_lost_this_round", records, &"target", 1) == 3, "Armor loss sums actual before/after difference")
	_expect(history.call("armor_lost_this_round", records, &"target", 2) == 0, "Armor history expires at round boundary")
	_expect(history.call("moved_this_round", records, &"target", 1), "movement detects target slot change")
	_expect(not history.call("moved_this_round", records, &"target", 2), "movement is round scoped")
	target.add_armor(5)
	for bonus: int in range(1, 6):
		var effect: RefCounted = effects.call("conditional_damage", 1, 100, 200, bonus, bonus == 2, bonus == 4)
		var skill: CharacterSkill = _skill([effect])
		var plan: SkillEffectPlan = BattleSkillAuthoringResolver.build_plan(actor, skill, [target], [actor, target], 1, 0, [], [], records)
		var upgraded: bool = bonus in [1, 3, 5]
		_expect(plan.damage_operations[0][&"total_requested_damage"] == (20 if upgraded else 10), "conditional bonus %d respects current state" % bonus)
		_expect(target.get_armor() == 5 and target.current_hp == 50, "preview never mutates health or Armor")
	target.apply_advantage(source, 1)
	var both: RefCounted = effects.call("conditional_damage", 1, 170, 210, 2, true)
	var both_skill: CharacterSkill = _skill([both])
	var plan: SkillEffectPlan = BattleSkillAuthoringResolver.build_plan(actor, both_skill, [target], [actor, target], 1, 0, [])
	_expect(not plan.consume_advantage and plan.damage_operations[0][&"total_requested_damage"] == 17, "Advantage alone does not trigger both-keyword bonus")
	target.apply_snared(source, 1)
	plan = BattleSkillAuthoringResolver.build_plan(actor, both_skill, [target], [actor, target], 1, 0, [])
	_expect(plan.consume_advantage and plan.damage_operations[0][&"total_requested_damage"] == 21, "both keywords lock Advantage consumption and bonus")
	_expect(target.has_advantage(1), "preview does not consume Advantage")
	for kind: int in [BattleSkillCondition.Kind.PRIMARY_ADVANTAGE, BattleSkillCondition.Kind.PRIMARY_SNARED_OR_ADVANTAGE, BattleSkillCondition.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND]:
		var gated: CharacterSkill = _skill([effects.call("damage", 1, 100)], [BattleSkillCondition.create(kind)])
		_expect(is_instance_valid(BattleSkillAuthoringResolver.build_plan(actor, gated, [target], [actor, target], 1, 0, [], [], records)), "setup condition accepts current-round evidence")
		_expect(not is_instance_valid(BattleSkillAuthoringResolver.build_plan(actor, gated, [target], [actor, target], 2, 0, [], [], records)), "setup condition rejects expired evidence")
	var strip: RefCounted = effects.call("armor_stripping_damage", 1, 110, 2)
	plan = BattleSkillAuthoringResolver.build_plan(actor, _skill([strip]), [target], [actor, target], 1, 0, [])
	_expect(plan.damage_operations[0].get(&"armor_strip", 0) == 2, "plan retains pre-hit Armor stripping")
	var damage_script: Script = load("res://Scripts/Battle/battle_damage_resolver.gd")
	var result: BattleDamageResult = damage_script.call("apply_direct_damage", actor, target, 10, true)
	_expect(result.applied_damage == 10 and target.get_armor() == 5 and result.was_direct_hit, "ignore Armor retains direct hit semantics without spending Armor")

	var unarmored: RefCounted = effects.call("conditional_damage", 1, 210, 240, 4, false, true)
	target.spend_armor(5)
	plan = BattleSkillAuthoringResolver.build_plan(actor, _skill([unarmored]), [target], [actor, target], 1, 0, [])
	_expect(plan.damage_operations[0][&"total_requested_damage"] == 24 and plan.damage_operations[0][&"ignore_armor"], "unarmored target activates bypass finisher upgrade")
	var volley: CharacterSkill = _skill([effects.call("damage", 1, 120, 180), effects.call("damage", 4, 120)])
	plan = BattleSkillAuthoringResolver.build_plan(actor, volley, [target], [actor, target], 1, 0, [])
	_expect(is_instance_valid(plan) and plan.damage_operations.size() == 1, "optional secondary damage permits a single volley target")

func _skill(effects: Array[RefCounted], conditions: Array[RefCounted] = []) -> CharacterSkill:
	return CharacterSkill.create(&"test", "Test", CharacterSkill.Kind.ACTIVE, "Damage", "Enemy", "None", "None", CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, [], null, null, BattleSkillTargetProfile.create(1, 1, BattleUnitState.Side.ENEMY), conditions, effects)

func _expect(passed: bool, message: String) -> void:
	_assertions += 1
	if not passed:
		_failures.append(message)
