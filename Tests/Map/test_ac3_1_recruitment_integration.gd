class_name Ac3_1RecruitmentIntegrationTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 8

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := await _instantiate_world()
	if is_instance_valid(world):
		_test_initial_roster(world)
		_test_initial_rewards_are_eligible(world)
		await _test_recruitment_applies_once(world)
		_test_duplicate_reward_is_filtered(world)
		_test_full_roster_keeps_valid_recruitment(world)
		_test_run_reset_restores_starters(world)
		await _test_battle_uses_roster(world)
		world.queue_free()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _instantiate_world() -> MapController:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	var world := packed.instantiate() as MapController if packed != null else null
	if is_instance_valid(world):
		root.add_child(world)
		await process_frame
		await process_frame
	return world


func _test_initial_roster(world: MapController) -> void:
	var roster := world.call("get_run_roster_snapshot") as Array
	_assert(
		_character_ids(roster) == [&"player_0", &"player_1", &"player_2"],
		"Initial roster",
		"run must begin with the three fixed starters"
	)


func _test_initial_rewards_are_eligible(world: MapController) -> void:
	var options := world.call("_get_eligible_reward_options", "combat") as Array
	_assert(
		_reward_ids(options) == [&"combat_recruit_scout", &"combat_money_100", &"combat_supply_cache"],
		"Initial eligible rewards",
		"eligible Scout must remain with money and item"
	)


func _test_recruitment_applies_once(world: MapController) -> void:
	await _place_recruit(world, 5)
	world.call("_on_recruitment_placement_requested", 5, &"scout")
	var roster := world.call("get_run_roster_snapshot") as Array
	var formation: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_assert(
		_character_ids(roster) == [&"player_0", &"player_1", &"player_2", &"scout"]
		and formation[5].character_id == &"scout",
		"Recruitment applies once",
		"placed Scout must be added exactly once in the chosen slot"
	)


func _test_duplicate_reward_is_filtered(world: MapController) -> void:
	var options := world.call("_get_eligible_reward_options", "combat") as Array
	_assert(
		_reward_ids(options) == [&"combat_money_100", &"combat_supply_cache"],
		"Duplicate reward filtering",
		"owned Scout must be absent while other rewards remain"
	)


func _test_full_roster_keeps_valid_recruitment(world: MapController) -> void:
	var full: Array[RunCharacter] = []
	for index: int in RunRoster.MAX_ROSTER_SIZE:
		full.append(RunCharacter.new(StringName("full_%d" % index), "Full %d" % index, 1, 10, []))
	var full_roster := RunRoster.new(full)
	var options := world.call(
		"_filter_eligible_reward_options",
		BattleRewardCatalog.get_options_for("boss"),
		full_roster
	) as Array
	_assert(
		_reward_ids(options) == [&"boss_recruit_champion", &"boss_money_250", &"boss_rare_relic"],
		"Full roster recruitment eligibility",
		"valid Champion recruitment must remain beside other rewards at capacity"
	)

	var returning_members: Array[RunCharacter] = [
		RunCharacterCatalog.create_for_reward(&"boss_recruit_champion"),
		_character(&"return_1", "Return 1"),
		_character(&"return_2", "Return 2"),
		_character(&"return_3", "Return 3"),
		_character(&"return_4", "Return 4"),
		_character(&"return_5", "Return 5"),
	]
	var returning_roster := RunRoster.new(returning_members)
	var scout := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	var replaced := returning_roster.try_replace_at(scout, 0, &"champion")
	var returning_options := world.call(
		"_filter_eligible_reward_options",
		BattleRewardCatalog.get_options_for("boss"),
		returning_roster
	) as Array
	_assert(
		replaced == RunRoster.ReplaceResult.REPLACED
		and _reward_ids(returning_options).has(&"boss_recruit_champion"),
		"Dismissed character eligibility",
		"dismissed Champion must become eligible when no copy remains"
	)


func _test_run_reset_restores_starters(world: MapController) -> void:
	world.set_run_id("another-run")
	var roster := world.call("get_run_roster_snapshot") as Array
	_assert(
		_character_ids(roster) == [&"player_0", &"player_1", &"player_2"],
		"Run reset",
		"new run ID must reconstruct the starter roster"
	)


func _test_battle_uses_roster(world: MapController) -> void:
	await _place_recruit(world, 4)
	world.call("_open_encounter", Vector2i(1, 0), "combat")
	var overlay := world.get_active_encounter()
	if is_instance_valid(overlay):
		world.call("_on_battle_requested", Vector2i(1, 0), "combat")
	await process_frame
	var battle := world.get_active_battle()
	var player_ids_by_slot: Dictionary[int, StringName] = {}
	if is_instance_valid(battle):
		for unit: BattleUnitState in battle.get_turn_queue():
			if unit.side == BattleUnitState.Side.PLAYER:
				player_ids_by_slot[unit.slot_index] = unit.unit_id
	var player_ids: Array[StringName] = []
	for slot_index: int in BattleArena.SIDE_SLOT_COUNT:
		if player_ids_by_slot.has(slot_index):
			player_ids.append(player_ids_by_slot[slot_index])
	_assert(
		player_ids == [&"player_0", &"player_1", &"player_2", &"scout"]
		and player_ids_by_slot.get(4, &"") == &"scout",
		"Next battle roster",
		"next battle must use Scout in chosen slot 4; got %s" % [player_ids_by_slot]
	)


func _place_recruit(world: MapController, destination_slot: int) -> void:
	world.call("_open_encounter", Vector2i(1, 0), "combat")
	if world.has_active_encounter():
		world.call("_on_battle_requested", Vector2i(1, 0), "combat")
	await process_frame
	var option := BattleRewardCatalog.get_options_for("combat")[0]
	world.call("_on_recruitment_reward_placement_requested", option)
	await process_frame
	world.call("_on_recruitment_placement_requested", destination_slot, &"scout")
	await process_frame
	if world.has_active_battle():
		world.exit_active_battle()
	await process_frame


func _character(id: StringName, display_name: String) -> RunCharacter:
	var skills: Array[CharacterSkill] = []
	return RunCharacter.new(id, display_name, 5, 20, skills)


func _character_ids(characters: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for character: RunCharacter in characters:
		ids.append(character.character_id)
	return ids


func _reward_ids(options: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for option: BattleRewardOption in options:
		ids.append(option.reward_id)
	return ids


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC3.1 recruitment integration tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
