class_name Ac6_2KeywordReactionTests
extends SceneTree

const SOURCE_PATH: String = "res://Scripts/Battle/battle_keyword_source.gd"
const BLEED_PATH: String = "res://Scripts/Battle/battle_bleed_state.gd"
const UNIT_STATE_PATH: String = "res://Scripts/Battle/battle_unit_state.gd"
const OPERATION_PATH: String = "res://Scripts/Battle/battle_keyword_operation.gd"
const EXPECTED_TEST_COUNT: int = 75

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_keyword_value_objects()
	_test_battle_local_keyword_state()
	_test_armor_aware_damage_results()
	_test_keyword_operation_contract()
	_test_keyword_skill_and_plan_contract()
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC6.2 keyword reactions: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_keyword_value_objects() -> void:
	_expect(ResourceLoader.exists(SOURCE_PATH), "keyword source script exists")
	_expect(ResourceLoader.exists(BLEED_PATH), "Bleed state script exists")
	if not ResourceLoader.exists(SOURCE_PATH) or not ResourceLoader.exists(BLEED_PATH):
		return
	var source_script := load(SOURCE_PATH) as Script
	var bleed_script := load(BLEED_PATH) as Script
	var source: RefCounted = source_script.call("create", &"shivrunner", &"rusted_cut", 7)
	_expect(source != null and source.call("is_valid"), "keyword source is valid")
	_expect(source_script.call("create", &"", &"rusted_cut", 7) == null, "empty source unit is rejected")
	_expect(source_script.call("create", &"shivrunner", &"", 7) == null, "empty source skill is rejected")
	_expect(source_script.call("create", &"shivrunner", &"rusted_cut", 0) == null, "Power below one is rejected")
	var bleed: RefCounted = bleed_script.call("create", source, 1, 2)
	_expect(bleed != null and bleed.call("is_valid"), "Bleed state is valid")
	_expect(bleed_script.call("create", source, 0, 2) == null, "Bleed rejects zero stacks")
	_expect(bleed_script.call("create", source, 4, 2) == null, "Bleed rejects stacks above cap")
	_expect(bleed_script.call("create", source, 1, 0) == null, "Bleed rejects zero duration")
	_expect(bleed.call("add_application", source, 2), "same source can reapply")
	_expect(bleed.get("stacks") == 2 and bleed.get("remaining_actions") == 2, "Bleed adds and refreshes")
	_expect(bleed.call("tick_damage") == 4, "Bleed uses snapshot Power per stack")


func _test_battle_local_keyword_state() -> void:
	_expect(ResourceLoader.exists(UNIT_STATE_PATH), "battle unit state script exists")
	if not ResourceLoader.exists(UNIT_STATE_PATH):
		return
	var skill := CharacterSkill.create(
		&"knife_work",
		"Knife Work",
		CharacterSkill.Kind.ACTIVE,
		"Deal damage.",
		"One enemy.",
		"None.",
		"Two actions.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		3,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2
	)
	_expect(skill != null, "unit test skill is valid")
	var unit := BattleUnitState.new(
		&"scout",
		"Scout",
		BattleUnitState.Side.PLAYER,
		0,
		5,
		20,
		[skill],
		8,
		1
	)
	_expect(unit.is_active(), "unit state fixture is active")
	var required_methods: Array[StringName] = [
		&"add_armor",
		&"spend_armor",
		&"get_armor",
		&"apply_advantage",
		&"has_advantage",
		&"consume_advantage",
		&"apply_snared",
		&"is_snared",
		&"apply_bleed",
		&"resolve_bleed_after_committed_action",
		&"get_bleed_snapshot",
		&"reduce_skill_cooldown",
		&"clear_round_keywords",
		&"clear_battle_local_state",
	]
	var missing_api := false
	for method_name: StringName in required_methods:
		var has_api := unit.has_method(method_name)
		_expect(has_api, "BattleUnitState exposes %s" % method_name)
		missing_api = missing_api or not has_api
	if missing_api:
		return
	var source_script := load(SOURCE_PATH) as Script
	var source_a: RefCounted = source_script.call("create", &"raider", &"rusted_cut", 7)
	var source_b: RefCounted = source_script.call("create", &"trapper", &"barbed_hook", 9)
	_expect(unit.add_armor(7) == 7 and unit.get_armor() == 7, "Armor adds applied amount")
	_expect(unit.add_armor(8) == 3 and unit.get_armor() == 10, "Armor caps at ten")
	_expect(unit.spend_armor(4) == 4 and unit.get_armor() == 6, "Armor spends partial prevention")
	_expect(unit.spend_armor(20) == 6 and unit.get_armor() == 0, "Armor spends no more than stored")
	_expect(unit.apply_advantage(source_a, 2) and unit.has_advantage(1), "Advantage applies until expiry")
	var consumed_advantage: RefCounted = null
	unit.apply_advantage(source_b, 3)
	consumed_advantage = unit.consume_advantage(2)
	_expect(consumed_advantage != null and consumed_advantage.get("source_unit_id") == &"trapper" and not unit.has_advantage(2), "Advantage replaces and consumes")
	unit.apply_advantage(source_a, 1)
	unit.clear_round_keywords(1)
	_expect(not unit.has_advantage(2), "Advantage expires after completed round")
	_expect(unit.apply_snared(source_a, 2) and unit.is_snared(1), "Snared applies until expiry")
	unit.apply_snared(source_b, 3)
	_expect(unit.is_snared(3), "Snared refreshes to the later round")
	unit.clear_round_keywords(3)
	_expect(not unit.is_snared(4), "Snared expires after completed round")
	unit.apply_bleed(source_a, 2)
	unit.apply_bleed(source_b, 2)
	unit.apply_bleed(source_a, 2)
	var bleed_ticks: Array[RefCounted] = unit.resolve_bleed_after_committed_action()
	_expect(bleed_ticks.size() == 2, "Bleed keeps distinct source entries")
	_expect(_has_bleed_tick(bleed_ticks, &"raider", 2, 4) and _has_bleed_tick(bleed_ticks, &"trapper", 1, 2), "Bleed ticks use source stacks and Power")
	unit.resolve_bleed_after_committed_action()
	_expect(unit.resolve_bleed_after_committed_action().is_empty(), "Bleed entries expire after affected actions")
	unit.add_speed_modifier(&"mud", -50, BattleUnitState.ModifierExpiry.NEXT_ACTION, 1)
	_expect(unit.get_effective_speed() == 1, "temporary Speed cannot fall below one")
	unit.expire_speed_modifiers_after_action()
	_expect(unit.get_effective_speed() == unit.get_base_speed(), "temporary Speed expires after action")
	_expect(unit.set_skill_cooldown(&"knife_work", 3), "cooldown fixture starts")
	_expect(unit.reduce_skill_cooldown(&"knife_work", 2) == 1, "cooldown reduction subtracts actions")
	_expect(unit.reduce_skill_cooldown(&"knife_work", 10) == 0 and unit.get_skill_cooldown(&"knife_work") == 0, "cooldown reduction floors at zero")
	unit.add_armor(5)
	unit.apply_advantage(source_a, 4)
	unit.apply_snared(source_a, 4)
	unit.apply_bleed(source_a, 2)
	unit.add_speed_modifier(&"dash", 2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 1)
	unit.set_skill_cooldown(&"knife_work", 2)
	unit.clear_battle_local_state()
	_expect(unit.unit_id == &"scout" and unit.power == 8 and unit.get_base_speed() == 5 and unit.skills.size() == 1, "battle cleanup preserves identity, stats, and skills")
	_expect(unit.get_armor() == 0 and not unit.has_advantage(4) and not unit.is_snared(4) and unit.get_skill_cooldown(&"knife_work") == 0 and unit.get_effective_speed() == 5 and unit.get_bleed_snapshot().is_empty(), "battle cleanup removes local keyword state")


func _test_keyword_skill_and_plan_contract() -> void:
	if not ResourceLoader.exists(OPERATION_PATH):
		return
	var operation_script := load(OPERATION_PATH) as Script
	var source_script := load(SOURCE_PATH) as Script
	var skill_script := load("res://Scripts/Battle/character_skill.gd") as Script
	var plan_script := load("res://Scripts/Battle/skill_effect_plan.gd") as Script
	var skill_accepts_keywords := _script_method_min_arg_count(skill_script, &"create") >= 21
	var plan_accepts_keywords := _script_method_min_arg_count(plan_script, &"create") >= 11
	_expect(skill_accepts_keywords, "skills expose keyword-operation create arguments")
	_expect(plan_accepts_keywords, "plans expose keyword-operation create arguments")
	if not skill_accepts_keywords or not plan_accepts_keywords:
		return
	var source: RefCounted = source_script.call("create", &"actor", &"knife_work", 6)
	var armor: RefCounted = operation_script.call("create", 0, &"target", 3, 1, null, &"")
	var bleed: RefCounted = operation_script.call("create", 3, &"target", 0, 2, source, &"")
	var skill: CharacterSkill = skill_script.call(
		"create",
		&"knife_work",
		"Knife Work",
		CharacterSkill.Kind.ACTIVE,
		"Deal damage and keywords.",
		"One enemy.",
		"None.",
		"Two actions.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		3,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2,
		0,
		null,
		[armor, bleed],
		null
	)
	_expect(skill != null, "skills accept authored keyword operations")
	if skill == null:
		return
	var keyword_operations: Array = skill.get("keyword_operations")
	keyword_operations.clear()
	_expect(skill.get("keyword_operations").size() == 2, "skill keyword operations are defensive copies")
	var duplicate: CharacterSkill = skill.duplicate_skill()
	_expect(duplicate.get("keyword_operations").size() == 2, "skill duplication preserves keyword operations")
	var invalid_skill: CharacterSkill = skill_script.call(
		"create",
		&"bad_keywords",
		"Bad Keywords",
		CharacterSkill.Kind.ACTIVE,
		"Bad.",
		"One enemy.",
		"None.",
		"None.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		1,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		null,
		[null],
		null
	)
	_expect(invalid_skill == null, "skills reject invalid keyword operations")
	var plan: SkillEffectPlan = plan_script.call(
		"create",
		&"actor",
		&"knife_work",
		[&"target"],
		[],
		[],
		2,
		true,
		7,
		[armor, bleed],
		null,
		null
	)
	_expect(plan != null, "plans accept ordered keyword operations")
	if plan == null:
		return
	var plan_operations: Array = plan.get("keyword_operations")
	plan_operations.clear()
	_expect(plan.get("keyword_operations").size() == 2, "plan keyword operations are defensive copies")
	_expect(plan_script.call("create", &"actor", &"knife_work", [&"target"], [], [], 2, true, 7, [armor, armor], null, null) == null, "plans reject duplicate keyword operations")
	var off_target: RefCounted = operation_script.call("create", 0, &"other", 3, 1, null, &"")
	_expect(plan_script.call("create", &"actor", &"knife_work", [&"target"], [], [], 2, true, 7, [off_target], null, null) == null, "plans reject keyword operations outside targets")
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 8, 20, [skill], 6, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	var validation := BattleSkillRules.validate_confirmation(actor, skill, [actor, target], actor.unit_id, false, 1, [&"target"], 3, 3, [])
	_expect(validation.effect_plan != null and validation.effect_plan.get("keyword_operations").size() == 2, "skill confirmation carries keyword operations into the plan")


func _test_keyword_operation_contract() -> void:
	_expect(ResourceLoader.exists(OPERATION_PATH), "keyword operation script exists")
	if not ResourceLoader.exists(OPERATION_PATH):
		return
	var operation_script := load(OPERATION_PATH) as Script
	var armor: RefCounted = operation_script.call("create", 0, &"target", 3, 1, null, &"")
	var cooldown: RefCounted = operation_script.call("create", 4, &"actor", 2, 0, null, &"knife_work")
	_expect(armor != null and armor.get("target_id") == &"target" and armor.get("magnitude") == 3, "keyword operation stores target and magnitude")
	_expect(cooldown != null and cooldown.get("affected_skill_id") == &"knife_work", "cooldown operation stores affected skill")
	_expect(operation_script.call("create", 0, &"", 3, 1, null, &"") == null, "keyword operation rejects empty target")
	_expect(operation_script.call("create", 4, &"actor", 2, 0, null, &"") == null, "cooldown operation rejects empty affected skill")


func _test_armor_aware_damage_results() -> void:
	var resolver_script := load("res://Scripts/Battle/battle_damage_resolver.gd") as Script
	var has_direct := _script_has_static_method(resolver_script, &"apply_direct_damage")
	var has_status := _script_has_static_method(resolver_script, &"apply_status_damage")
	_expect(has_direct, "damage resolver exposes direct damage")
	_expect(has_status, "damage resolver exposes status damage")
	if not has_direct or not has_status:
		return
	var attacker := BattleUnitState.new(&"attacker", "Attacker", BattleUnitState.Side.PLAYER, 0, 8, 20, [], 6, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	target.add_armor(3)
	var partial: RefCounted = resolver_script.call("apply_direct_damage", attacker, target, 5)
	_expect(partial.get("requested_damage") == 5, "direct result keeps post-Defense request")
	_expect(partial.get("armor_prevented") == 3, "Armor prevents direct damage first")
	_expect(partial.get("applied_damage") == 2 and target.current_hp == 18 and target.get_armor() == 0, "direct damage applies after Armor")
	_expect(partial.get("was_direct_hit") and not partial.get("is_status_damage"), "direct hit classification survives absorption")
	target = BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	target.add_armor(10)
	var absorbed: RefCounted = resolver_script.call("apply_direct_damage", attacker, target, 4)
	_expect(absorbed.get("applied_damage") == 0 and absorbed.get("armor_prevented") == 4 and target.current_hp == 20 and target.get_armor() == 6 and absorbed.get("was_direct_hit"), "fully absorbed direct damage still counts as a hit")
	target.current_hp = 3
	var overkill: RefCounted = resolver_script.call("apply_direct_damage", attacker, target, 10)
	_expect(overkill.get("armor_prevented") == 6 and overkill.get("applied_damage") == 3 and target.current_hp == 0 and overkill.get("caused_defeat"), "overkill reports actual HP loss after Armor")
	target = BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	target.current_hp = 10
	target.add_armor(5)
	var status: RefCounted = resolver_script.call("apply_status_damage", attacker, target, 4)
	_expect(status.get("applied_damage") == 4 and target.current_hp == 6 and target.get_armor() == 5 and status.get("is_status_damage") and not status.get("was_direct_hit"), "status damage bypasses Armor")


func _script_method_min_arg_count(script: Script, method_name: StringName) -> int:
	if not is_instance_valid(script):
		return -1
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", &"") == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func _script_has_static_method(script: Script, method_name: StringName) -> bool:
	if not is_instance_valid(script):
		return false
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", &"") == method_name:
			return true
	return false


func _has_bleed_tick(ticks: Array[RefCounted], source_unit_id: StringName, expected_stacks: int, expected_damage: int) -> bool:
	for tick: RefCounted in ticks:
		if not is_instance_valid(tick):
			continue
		var source: RefCounted = tick.get("source")
		if (
			is_instance_valid(source)
			and source.get("source_unit_id") == source_unit_id
			and tick.get("stacks") == expected_stacks
			and tick.call("tick_damage") == expected_damage
		):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
