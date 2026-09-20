extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var roster: RunRoster = RunRoster.new()
	_check(roster.has_method("try_remove_at"), "explicit roster removal API exists")
	if not roster.has_method("try_remove_at"):
		_finish()
		return
	_test_eligibility()
	_test_removal()
	_finish()


func _test_eligibility() -> void:
	var roster: RunRoster = RunRoster.new()
	var expected: Array[StringName] = [&"scrapbroker", &"shivrunner", &"mobcaller"]
	var before: Array[RunCharacter] = roster.get_slot_snapshot()
	_check(TownRecruitmentRules.eligible_class_ids(&"goblin", roster) == expected,
		"canonical starters exclude first three classes in catalog order")
	_check(TownRecruitmentRules.eligible_class_ids(&"unknown", roster).is_empty(),
		"unknown clan has no eligible classes")
	var result: Array[StringName] = TownRecruitmentRules.eligible_class_ids(&"goblin", roster)
	result.clear()
	_check(roster.get_slot_snapshot() == before, "eligibility query does not mutate roster")
	_check(TownRecruitmentRules.eligible_class_ids(&"goblin", roster) == expected,
		"returned eligibility array is detached")
	_check(roster.try_move(0, 5, &"player_0") == RunRoster.MoveResult.MOVED,
		"sparse formation setup succeeds")
	_check(TownRecruitmentRules.eligible_class_ids(&"goblin", roster) == expected,
		"sparse formation still excludes occupied classes")
	var units: Array[BattleUnitState] = roster.create_battle_units()
	units[0].current_hp = 0
	_check(TownRecruitmentRules.eligible_class_ids(&"goblin", roster) == expected,
		"battle death does not release a class still in the run roster")

	var duplicate: RunRoster = RunRoster.new()
	_check(duplicate.try_add_at(RunCharacterCatalog.create_by_class_id(&"scrapshield_bruiser"), 4)
		== RunRoster.AddResult.ADDED, "distinct identities can represent the same class")
	_check(_remove(duplicate, 0, &"player_0") == 0, "remove first same-class representative")
	_check(not TownRecruitmentRules.eligible_class_ids(&"goblin", duplicate).has(&"scrapshield_bruiser"),
		"remaining representative keeps class excluded")
	_check(_remove(duplicate, 4, &"scrapshield_bruiser") == 0, "remove final class representative")
	_check(TownRecruitmentRules.eligible_class_ids(&"goblin", duplicate).has(&"scrapshield_bruiser"),
		"final representative removal restores eligibility while other members remain")

	var full: RunRoster = RunRoster.new()
	for index: int in expected.size():
		_check(full.try_add_at(RunCharacterCatalog.create_by_class_id(expected[index]), index + 3)
			== RunRoster.AddResult.ADDED, "fill remaining catalog class")
	_check(TownRecruitmentRules.eligible_class_ids(&"goblin", full).is_empty(),
		"all six classes represented produces empty eligibility")


func _test_removal() -> void:
	var roster: RunRoster = RunRoster.new()
	var before: Array[RunCharacter] = roster.get_slot_snapshot()
	_reject(roster, -1, &"player_0", 1, "negative slot")
	_reject(roster, 6, &"player_0", 1, "out-of-range slot")
	_reject(roster, 5, &"player_0", 2, "empty slot")
	_reject(roster, 1, &"wrong", 3, "stale identity")
	_check(_remove(roster, 1, &"player_1") == 0, "occupied matching target is removed")
	var expected: Array[RunCharacter] = before.duplicate()
	expected[1] = null
	_check(roster.get_slot_snapshot() == expected, "success clears only the explicit slot")
	_reject(roster, 1, &"player_1", 2, "repeated removal")
	_check(_remove(roster, 2, &"player_2") == 0, "removal down to one member succeeds")
	_reject(roster, 0, &"wrong", 3, "stale identity precedes final-member guard")
	_reject(roster, 5, &"player_0", 2, "empty slot precedes final-member guard")
	_reject(roster, -1, &"player_0", 1, "invalid slot precedes final-member guard")
	_reject(roster, 0, &"player_0", 4, "D1 minimum one member")

	var live: RunRoster = RunRoster.new()
	var live_before: Array[RunCharacter] = live.get_slot_snapshot()
	var candidate: RunRoster = RunRoster.new(live_before)
	_check(_remove(candidate, 1, &"player_1") == 0, "detached candidate removal succeeds")
	_check(live.get_slot_snapshot() == live_before, "candidate removal leaves live roster unchanged")


func _remove(roster: RunRoster, slot_index: int, expected_id: StringName) -> int:
	# Dynamic dispatch allows an explicit RED assertion before the API is added.
	return int(roster.call("try_remove_at", slot_index, expected_id))


func _reject(roster: RunRoster, slot_index: int, expected_id: StringName,
		expected_result: int, label: String) -> void:
	var before: Array[RunCharacter] = roster.get_slot_snapshot()
	_check(_remove(roster, slot_index, expected_id) == expected_result, label + " rejects correctly")
	_check(roster.get_slot_snapshot() == before, label + " preserves all slots")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL AC8.6 roster: " + label)


func _finish() -> void:
	if _failures == 0:
		print("PASS AC8.6 roster eligibility/removal (%d checks)" % _checks)
	else:
		printerr("FAIL AC8.6 roster: %d/%d checks failed" % [_failures, _checks])
	quit(0 if _failures == 0 else 1)
