class_name Ac2_5RewardSelectionTests
extends SceneTree

const CATALOG_PATH := "res://Scripts/Battle/battle_reward_catalog.gd"
const EXPECTED_TEST_COUNT := 4

var _failures: Array[String] = []
var _catalog_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_catalog_script = load(CATALOG_PATH) as GDScript if ResourceLoader.exists(CATALOG_PATH) else null
	_test_combat_catalog_is_fixed()
	_test_boss_catalog_is_fixed_and_distinct()
	_test_unsupported_catalog_is_empty()
	_test_catalog_returns_fresh_instances()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _options_for(event_type: String) -> Array:
	if _catalog_script == null:
		return []
	return _catalog_script.call("get_options_for", event_type) as Array


func _test_combat_catalog_is_fixed() -> void:
	var options := _options_for("combat")
	_assert(
		_signature(options) == [
			[&"combat_recruit_scout", 0, "Recruit Scout", "Recruit a Scout after this battle."],
			[&"combat_money_100", 1, "100 Money", "Take 100 money for this run."],
			[&"combat_supply_cache", 2, "Supply Cache", "Take a cache of practical supplies."],
		],
		"Combat catalog is fixed",
		"expected the exact three Combat rewards"
	)


func _test_boss_catalog_is_fixed_and_distinct() -> void:
	var options := _options_for("boss")
	_assert(
		_signature(options) == [
			[&"boss_recruit_champion", 0, "Recruit Champion", "Recruit a Champion after this boss battle."],
			[&"boss_money_250", 1, "250 Money", "Take 250 money for this run."],
			[&"boss_rare_relic", 2, "Rare Relic", "Take a rare relic from the defeated boss."],
		] and _signature(options) != _signature(_options_for("combat")),
		"Boss catalog is fixed and distinct",
		"expected the exact three Boss rewards"
	)


func _test_unsupported_catalog_is_empty() -> void:
	_assert(_options_for("safe").is_empty(), "Unsupported catalog is empty", "Safe must not invent rewards")


func _test_catalog_returns_fresh_instances() -> void:
	var first := _options_for("combat")
	var second := _options_for("combat")
	_assert(
		first.size() == 3 and second.size() == 3 and first[0] != second[0],
		"Catalog returns fresh instances",
		"reward objects must not leak between battles"
	)


func _signature(options: Array) -> Array:
	var result: Array = []
	for option: Variant in options:
		result.append([option.reward_id, int(option.kind), option.title, option.description])
	return result


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.5 reward selection tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
