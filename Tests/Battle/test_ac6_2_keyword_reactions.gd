class_name Ac6_2KeywordReactionTests
extends SceneTree

const SOURCE_PATH: String = "res://Scripts/Battle/battle_keyword_source.gd"
const BLEED_PATH: String = "res://Scripts/Battle/battle_bleed_state.gd"
const UNIT_STATE_PATH: String = "res://Scripts/Battle/battle_unit_state.gd"
const EXPECTED_TEST_COUNT: int = 50

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_keyword_value_objects()
	_test_battle_local_keyword_state()
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
