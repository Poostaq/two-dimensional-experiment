class_name AC85RecruitmentRulesTests
extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ids: Array[StringName] = [
		&"scrapshield_bruiser", &"wirefang_skirmisher", &"snarewright",
		&"scrapbroker", &"shivrunner", &"mobcaller",
	]
	var starters: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	for index: int in starters.size():
		_expect(starters[index].character_id == StringName("player_%d" % index), "starter instance identity preserved")
		_expect(starters[index].get("class_id") == ids[index], "starter canonical identity preserved")
	for id: StringName in ids:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(id)
		_expect(is_instance_valid(character) and character.get("class_id") == id, "regular factory identity: %s" % id)
	for reward: StringName in [RunCharacterCatalog.COMBAT_SCOUT_REWARD_ID, RunCharacterCatalog.BOSS_CHAMPION_REWARD_ID]:
		_expect(RunCharacterCatalog.create_for_reward(reward).get("class_id") == &"", "legacy rewards have no canonical class")
	var catalog: Script = load("res://Scripts/Run/run_character_catalog.gd")
	var economy: Script = load("res://Scripts/Run/run_economy_rules.gd")
	_expect(economy.get_script_constant_map().get("RECRUITMENT_COST") == 500, "recruitment costs exactly 500g")
	_expect(catalog.has_method("get_recruitable_class_ids"), "clan allowlist exists")
	if catalog.has_method("get_recruitable_class_ids"):
		var offers: Array[StringName] = catalog.get_recruitable_class_ids(&"goblin")
		_expect(offers == ids, "Goblin allowlist contains precisely six regular classes")
		offers.clear()
		_expect(catalog.get_recruitable_class_ids(&"goblin") == ids, "allowlist is a fresh copy")
		_expect(catalog.get_recruitable_class_ids(&"unknown").is_empty(), "unknown clan has no recruits")
	var rules_path: String = "res://Scripts/Run/town_recruitment_rules.gd"
	_expect(ResourceLoader.exists(rules_path), "pure recruitment rule module exists")
	if ResourceLoader.exists(rules_path):
		_test_rules(load(rules_path), ids)
	_finish()


func _test_rules(rules: Script, ids: Array[StringName]) -> void:
	var roster: RunRoster = RunRoster.new()
	var before: Array[RunCharacter] = roster.get_slot_snapshot()
	var expected: Array[StringName] = [&"scrapbroker", &"shivrunner", &"mobcaller"]
	_expect(rules.eligible_class_ids(&"goblin", roster) == expected, "all starter classes excluded regardless of instance ID")
	_expect(rules.eligible_class_ids(&"unknown", roster).is_empty(), "unknown clan offers empty")
	_expect(rules.eligible_class_ids(&"goblin", null).is_empty(), "invalid roster offers empty")
	_expect(rules.purchase_error(&"goblin", roster, &"scrapbroker", 499, true) == &"insufficient_gold", "499g rejected")
	_expect(rules.purchase_error(&"goblin", roster, &"scrapbroker", 500, true) == &"", "500g accepted")
	_expect(rules.purchase_error(&"goblin", roster, &"scrapbroker", 500, false) == &"town_unavailable", "unavailable town rejected")
	_expect(rules.purchase_error(&"goblin", null, &"scrapbroker", 500, true) == &"invalid_roster", "invalid roster rejected")
	_expect(rules.purchase_error(&"unknown", roster, &"scrapbroker", 500, true) == &"class_not_recruitable", "unknown clan rejected")
	for id: StringName in [&"", &"unknown", &"scout", &"champion", &"combat_recruit_scout", &"boss_recruit_champion", &"brakka_rustbanner"]:
		_expect(rules.purchase_error(&"goblin", roster, id, 500, true) == &"class_not_recruitable", "non-regular class rejected: %s" % id)
	for index: int in 3:
		_expect(rules.purchase_error(&"goblin", roster, ids[index], 500, true) == &"class_already_present", "starter class duplicate rejected")
	var offers: Array[StringName] = rules.eligible_class_ids(&"goblin", roster)
	offers.clear()
	_expect(rules.eligible_class_ids(&"goblin", roster) == expected, "offers are independent copies")
	_expect(roster.get_slot_snapshot() == before, "rule queries preserve roster slots")
	for index: int in 3:
		_expect(roster.get_character_at(index).character_id == StringName("player_%d" % index), "queries preserve character identities")
	var complete: Array[RunCharacter] = []
	for id: StringName in ids:
		complete.append(RunCharacterCatalog.create_by_class_id(id))
	var full_roster: RunRoster = RunRoster.new(complete)
	_expect(rules.eligible_class_ids(&"goblin", full_roster).is_empty(), "owning all six classes leaves no offers")
	for id: StringName in ids:
		_expect(rules.purchase_error(&"goblin", full_roster, id, 500, true) == &"class_already_present", "whole roster duplicate rejected")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PASS test_ac8_5_recruitment_rules")
	quit(0 if _failures == 0 else 1)
