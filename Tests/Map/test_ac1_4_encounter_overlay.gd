class_name Ac1_4EncounterOverlayTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 6
const START_COORD := Vector2i(0, 0)
const FIXTURE_RUN_ID_PREFIX := "ac1.4-fixture-"
const FIXTURE_SCAN_COUNT := 128
const START_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
]
const BOSS_PATH: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(0, 2),
	Vector2i(0, 3),
	Vector2i(0, 4),
	Vector2i(1, 4),
	Vector2i(2, 4),
	Vector2i(3, 4),
	Vector2i(4, 4),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := await _instantiate_world()
	if controller != null:
		if _assert_controller_overlay_contract(controller):
			_test_initial_state_has_no_overlay(controller)
			_test_each_encounter_type_opens_matching_overlay(controller)
			_test_rejected_move_opens_no_overlay(controller)
			_test_active_overlay_blocks_map_state_changes(controller)
			_test_debug_close_preserves_state_and_restores_navigation(controller)
			_test_reentry_opens_once_per_accepted_move(controller)
		controller.queue_free()
	_report()
	var exit_code := 1 if not _failures.is_empty() else 0
	quit(exit_code)


func _instantiate_world() -> MapController:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	if packed == null:
		_failures.append("instantiate_world - failed to load %s" % GAME_WORLD_PATH)
		return null
	var controller := packed.instantiate() as MapController
	if controller == null:
		_failures.append("instantiate_world - game world should instantiate as MapController")
		return null
	root.add_child(controller)
	await process_frame
	await process_frame
	return controller


func _test_initial_state_has_no_overlay(controller: MapController) -> void:
	var test_name := "test_initial_state_has_no_overlay"
	_assert_ui_layer(controller, test_name)
	_assert(not _has_active_encounter(controller, test_name), test_name, "initial setup should not open an encounter overlay")
	_assert(_active_overlay_count(controller) == 0, test_name, "UI should have no EncounterOverlay children at startup")


func _test_each_encounter_type_opens_matching_overlay(controller: MapController) -> void:
	var test_name := "test_each_encounter_type_opens_matching_overlay"
	var safe_fixture := _find_adjacent_fixture(controller, HexMapModel.ENCOUNTER_SAFE, test_name)
	if not safe_fixture.is_empty():
		_move_and_assert_overlay(controller, safe_fixture["destination"], HexMapModel.ENCOUNTER_SAFE, test_name)
		_close_expected_encounter(controller, test_name)

	var combat_fixture := _find_adjacent_fixture(controller, HexMapModel.ENCOUNTER_COMBAT, test_name)
	if not combat_fixture.is_empty():
		_move_and_assert_overlay(controller, combat_fixture["destination"], HexMapModel.ENCOUNTER_COMBAT, test_name)
		_close_expected_encounter(controller, test_name)

	_reset_to_start(controller)
	controller.set_run_id("boss-fixture")
	for destination: Vector2i in BOSS_PATH:
		var expected_type := controller.get_encounter_type_at(destination)
		_move_and_assert_overlay(controller, destination, expected_type, test_name)
		_close_expected_encounter(controller, test_name)


func _test_rejected_move_opens_no_overlay(controller: MapController) -> void:
	var test_name := "test_rejected_move_opens_no_overlay"
	_reset_to_start(controller)
	var moved := controller.request_move(Vector2i(4, 4))
	_assert(not moved, test_name, "non-adjacent move should be rejected")
	_assert(not _has_active_encounter(controller, test_name), test_name, "rejected move should not open an overlay")
	_assert(_active_overlay_count(controller) == 0, test_name, "rejected move should leave UI without EncounterOverlay children")


func _test_active_overlay_blocks_map_state_changes(controller: MapController) -> void:
	var test_name := "test_active_overlay_blocks_map_state_changes"
	_reset_to_start(controller)
	var first_destination := START_NEIGHBORS[0]
	_move_and_assert_overlay(controller, first_destination, controller.get_encounter_type_at(first_destination), test_name)
	var active_overlay := _get_active_encounter(controller, test_name)
	var before_coord := controller.player_coord
	var before_count := controller.move_count
	var blocked := controller.request_move(Vector2i(2, 0))
	_assert(not blocked, test_name, "movement should be rejected while an encounter overlay is active")
	_assert(controller.player_coord == before_coord, test_name, "active overlay should preserve player_coord during blocked move")
	_assert(controller.move_count == before_count, test_name, "active overlay should preserve move_count during blocked move")
	_assert(_get_active_encounter(controller, test_name) == active_overlay, test_name, "blocked move should keep the original active overlay")
	_close_expected_encounter(controller, test_name)


func _test_debug_close_preserves_state_and_restores_navigation(controller: MapController) -> void:
	var test_name := "test_debug_close_preserves_state_and_restores_navigation"
	_reset_to_start(controller)
	var first_destination := START_NEIGHBORS[0]
	_move_and_assert_overlay(controller, first_destination, controller.get_encounter_type_at(first_destination), test_name)
	var before_coord := controller.player_coord
	var before_count := controller.move_count
	var before_run_id := controller.run_id
	var before_layout := controller.get_encounter_layout()
	_close_expected_encounter(controller, test_name)
	_assert(controller.player_coord == before_coord, test_name, "Close should preserve player_coord")
	_assert(controller.move_count == before_count, test_name, "Close should preserve move_count")
	_assert(controller.run_id == before_run_id, test_name, "Close should preserve run_id")
	_assert(controller.get_encounter_layout() == before_layout, test_name, "Close should preserve encounter layout")
	var second_destination := Vector2i(2, 0)
	var moved := controller.request_move(second_destination)
	_assert(moved, test_name, "navigation should resume after Close")
	_assert(controller.player_coord == second_destination, test_name, "resumed navigation should move to the requested destination")
	_close_expected_encounter(controller, test_name)


func _test_reentry_opens_once_per_accepted_move(controller: MapController) -> void:
	var test_name := "test_reentry_opens_once_per_accepted_move"
	_reset_to_start(controller)
	var destination := START_NEIGHBORS[0]
	_move_and_assert_overlay(controller, destination, controller.get_encounter_type_at(destination), test_name)
	var first_overlay := _get_active_encounter(controller, test_name)
	_close_expected_encounter(controller, test_name)
	_move_and_assert_overlay(controller, START_COORD, controller.get_encounter_type_at(START_COORD), test_name)
	_close_expected_encounter(controller, test_name)
	_move_and_assert_overlay(controller, destination, controller.get_encounter_type_at(destination), test_name)
	var second_overlay := _get_active_encounter(controller, test_name)
	_assert(first_overlay != second_overlay, test_name, "re-entry should create a new overlay instance")
	_assert(_active_overlay_count(controller) == 1, test_name, "accepted re-entry should have exactly one active overlay")
	_close_expected_encounter(controller, test_name)


func _assert_controller_overlay_contract(controller: MapController) -> bool:
	var has_contract := true
	for method_name: String in ["has_active_encounter", "get_active_encounter", "close_active_encounter"]:
		if not controller.has_method(method_name):
			_failures.append("controller contract - MapController is missing %s()" % method_name)
			has_contract = false
	return has_contract


func _find_adjacent_fixture(controller: MapController, encounter_type: String, test_name: String) -> Dictionary:
	for index: int in range(FIXTURE_SCAN_COUNT):
		var fixture_run_id := "%s%d" % [FIXTURE_RUN_ID_PREFIX, index]
		_reset_to_start(controller)
		controller.set_run_id(fixture_run_id)
		for destination: Vector2i in START_NEIGHBORS:
			if controller.get_encounter_type_at(destination) == encounter_type:
				return {
					"run_id": fixture_run_id,
					"destination": destination,
				}
	_failures.append("%s - could not find adjacent %s fixture in %d run IDs" % [test_name, encounter_type, FIXTURE_SCAN_COUNT])
	return {}


func _move_and_assert_overlay(controller: MapController, destination: Vector2i, expected_type: String, test_name: String) -> void:
	var moved := controller.request_move(destination)
	_assert(moved, test_name, "accepted move to %s should return true" % destination)
	var overlay := _get_active_encounter(controller, test_name)
	if overlay == null:
		return
	_assert(_active_overlay_count(controller) == 1, test_name, "accepted move should create exactly one active overlay")
	_assert(overlay.get("encounter_coordinate") == destination, test_name, "overlay should store entered coordinate %s" % destination)
	_assert(overlay.get("encounter_type") == expected_type, test_name, "overlay should store encounter type %s" % expected_type)
	if controller.has_node("UI"):
		_assert(overlay.get_parent() == controller.get_node("UI"), test_name, "overlay should be attached under UI CanvasLayer")


func _close_expected_encounter(controller: MapController, test_name: String) -> void:
	if not _has_active_encounter(controller, test_name):
		_failures.append("%s - expected an active encounter before Close" % test_name)
		return
	controller.call("close_active_encounter")
	_assert(not _has_active_encounter(controller, test_name), test_name, "Close should clear active encounter")
	_assert(_active_overlay_count(controller) == 0, test_name, "Close should remove EncounterOverlay children from UI")


func _reset_to_start(controller: MapController) -> void:
	if controller.has_method("close_active_encounter"):
		controller.call("close_active_encounter")
	controller.player_coord = START_COORD
	controller.move_count = 0


func _has_active_encounter(controller: MapController, test_name: String) -> bool:
	if not controller.has_method("has_active_encounter"):
		_failures.append("%s - MapController is missing has_active_encounter()" % test_name)
		return false
	return controller.call("has_active_encounter") as bool


func _get_active_encounter(controller: MapController, test_name: String) -> Node:
	if not controller.has_method("get_active_encounter"):
		_failures.append("%s - MapController is missing get_active_encounter()" % test_name)
		return null
	return controller.call("get_active_encounter") as Node


func _active_overlay_count(controller: MapController) -> int:
	if not controller.has_node("UI"):
		return 0
	var count := 0
	for child: Node in controller.get_node("UI").get_children():
		if child.get_script() != null and child.get_class() == "CanvasLayer":
			count += 1
		elif child.get("encounter_type") != null:
			count += 1
	return count


func _assert_ui_layer(controller: MapController, test_name: String) -> void:
	_assert(controller.has_node("UI"), test_name, "game_world should expose a UI CanvasLayer")
	if controller.has_node("UI"):
		_assert(controller.get_node("UI") is CanvasLayer, test_name, "UI should be a CanvasLayer")


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC1.4 encounter overlay tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
