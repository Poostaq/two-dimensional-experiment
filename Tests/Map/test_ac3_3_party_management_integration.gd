class_name Ac3_3PartyManagementIntegrationTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 12

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
	world.call("set_run_id", "reset-check")
	var reset: Array[RunCharacter] = world.call("get_run_formation_snapshot")
	_expect(reset[0].character_id == &"player_0" and reset[3] == null, "run reset restores starter formation")
	_expect(not world.call("has_active_party_management"), "run reset leaves party management closed")

	world.queue_free()
	await process_frame
	_finish()


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
