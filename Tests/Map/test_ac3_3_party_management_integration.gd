class_name Ac3_3PartyManagementIntegrationTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 24

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	var world := packed.instantiate() as MapController
	get_root().add_child(world)
	await process_frame

	_expect(is_instance_valid(world.get_node_or_null("%ManagePartyButton")), "persistent Manage Party button exists")
	_expect(not world.call("has_active_party_management"), "party management starts closed")
	world.call("open_party_management")
	await process_frame
	_expect(world.call("has_active_party_management"), "map opens party management")
	var party: Control = world.call("get_active_party_management")
	_expect(is_instance_valid(party), "active party scene is observable")
	var before: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	party.call("request_move", 0, 5, before[0].character_id)
	await process_frame
	var moved: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_expect(moved[0] == null and moved[5].character_id == &"player_0", "move into empty slot persists immediately")
	party.call("request_move", 1, 5, moved[1].character_id)
	await process_frame
	var swapped: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_expect(swapped[1].character_id == &"player_0" and swapped[5].character_id == &"player_1", "occupied drop swaps immediately")
	party.call("select_character", 1, &"player_0")
	party.call("request_close")
	await process_frame
	_expect(not world.call("has_active_party_management"), "Return closes party management")
	world.call("open_party_management")
	await process_frame
	var reopened: Control = world.call("get_active_party_management")
	_expect(not (reopened.get_node("%DetailsPanel") as Control).visible, "reopen clears selected details")
	world.call("close_party_management")
	world.call("_open_encounter", Vector2i(1, 0), "combat")
	world.call("_on_battle_requested", Vector2i(1, 0), "combat")
	await process_frame
	var recruit_option := BattleRewardCatalog.get_options_for("combat")[0]
	world.call("_on_recruitment_reward_placement_requested", recruit_option)
	await process_frame
	_expect(
		world.call("has_active_party_management")
		and (world.call("get_run_roster_snapshot") as Array).size() == 3,
		"recruitment placement starts without roster mutation"
	)
	var placement_party: Control = world.call("get_active_party_management")
	placement_party.call("request_placement_cancel")
	await process_frame
	_expect(
		not world.call("has_active_party_management")
		and (world.call("get_run_roster_snapshot") as Array).size() == 3,
		"placement cancellation clears UI without roster mutation"
	)
	world.exit_active_battle()

	var roster: RunRoster = world.get("_run_roster") as RunRoster
	_expect(roster.try_add_at(_character(&"fourth", "Fourth"), 0) == RunRoster.AddResult.ADDED, "fixture fills empty slot 0")
	_expect(roster.try_add_at(_character(&"fifth", "Fifth"), 3) == RunRoster.AddResult.ADDED, "fixture fills empty slot 3")
	_expect(roster.try_add_at(_character(&"sixth", "Sixth"), 4) == RunRoster.AddResult.ADDED and roster.is_full(), "fixture reaches capacity")

	world.call("_open_encounter", Vector2i(1, 0), "boss")
	world.call("_on_battle_requested", Vector2i(1, 0), "boss")
	await process_frame
	var active_battle := world.call("get_active_battle") as BattleArena
	active_battle.call("_complete_battle", BattleOutcome.Type.VICTORY)
	var champion_option := _find_reward(active_battle.get_reward_options(), &"boss_recruit_champion")
	_expect(is_instance_valid(champion_option), "full roster retains valid recruitment reward")
	active_battle.select_reward(champion_option.reward_id)
	active_battle.confirm_reward_selection()
	await process_frame
	var replacement_party: PartyManagement = world.call("get_active_party_management")
	_expect(is_instance_valid(replacement_party) and replacement_party.get("_mode") == PartyManagement.Mode.REPLACEMENT, "capacity opens replacement mode")
	var before_replace: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	replacement_party.call("request_placement_cancel")
	await process_frame
	_expect(not world.call("has_active_party_management") and _same_slots(before_replace, world.call("get_run_formation_snapshot")), "replacement cancel restores without mutation")

	active_battle.confirm_reward_selection()
	await process_frame
	var teardown_party: PartyManagement = world.call("get_active_party_management")
	teardown_party.queue_free()
	await process_frame
	_expect(
		not world.call("has_active_party_management") and not is_instance_valid(world.get("_pending_recruit")),
		"unexpected replacement teardown clears pending state without mutation"
	)

	active_battle.restore_pending_recruitment(champion_option)
	active_battle.confirm_reward_selection()
	await process_frame
	replacement_party = world.call("get_active_party_management")
	replacement_party.call("request_replacement", 1, before_replace[1].character_id, &"champion")
	await process_frame
	var after_replace: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_expect(after_replace[1].character_id == &"champion" and roster.size() == 6, "replacement commits at exact slot")
	_expect(not roster.has_character(before_replace[1].character_id), "dismissed character leaves membership")
	world.call("_on_recruitment_replacement_requested", 1, before_replace[1].character_id, &"champion")
	_expect(_same_slots(after_replace, world.call("get_run_formation_snapshot")), "repeated stale replacement cannot mutate")
	_expect(not world.call("has_active_party_management"), "successful replacement closes party management")
	world.call("_open_encounter", Vector2i(1, 0), "combat")
	world.call("_on_battle_requested", Vector2i(1, 0), "combat")
	await process_frame
	var next_battle := world.call("get_active_battle") as BattleArena
	var next_slot_id: StringName = &""
	for unit: BattleUnitState in next_battle.get_turn_queue():
		if unit.side == BattleUnitState.Side.PLAYER and unit.slot_index == 1:
			next_slot_id = unit.unit_id
	_expect(next_slot_id == &"champion", "next battle preserves the replaced semantic slot")
	world.exit_active_battle()

	world.call("set_run_id", "reset-check")
	var reset: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_expect(reset[0].character_id == &"player_0" and reset[3] == null, "run reset restores starter formation")
	_expect(not world.call("has_active_party_management"), "run reset leaves party management closed")

	world.queue_free()
	await process_frame
	_finish()


func _character(id: StringName, display_name: String) -> RunCharacter:
	var skills: Array[CharacterSkill] = []
	return RunCharacter.new(id, display_name, 5, 20, skills)


func _find_reward(options: Array[BattleRewardOption], reward_id: StringName) -> BattleRewardOption:
	for option: BattleRewardOption in options:
		if option.reward_id == reward_id:
			return option
	return null


func _same_slots(left: Array[RunCharacter], right: Array[RunCharacter]) -> bool:
	if left.size() != right.size():
		return false
	for slot_index: int in left.size():
		if left[slot_index] != right[slot_index]:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC3.3 party management integration tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
