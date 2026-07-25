class_name Ac1_5SuddenDeathTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 13
const FIXTURE_RUN_ID := "ac1-5-fixture"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pursuit_step_is_adjacent_and_reduces_distance()
	_test_pursuit_tie_break_uses_neighbor_order()
	_test_pursuit_step_is_deterministic()
	_test_invalid_or_equal_endpoints_stay_put()
	await _test_moves_before_threshold_keep_boss_idle()
	await _test_move_fifteen_activates_without_pursuit()
	await _test_move_sixteen_starts_one_step_pursuit()
	await _test_each_later_accepted_move_advances_once()
	await _test_rejected_and_blocked_moves_do_not_advance_pursuit()
	await _test_player_entering_boss_coord_triggers_boss_encounter()
	await _test_boss_reaching_player_triggers_boss_encounter()
	await _test_runtime_boss_identity_moves_and_vacated_origin_is_safe()
	await _test_set_run_id_resets_sudden_death()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _new_model() -> HexMapModel:
	return HexMapModel.new()


func _new_controller() -> MapController:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	var controller := packed.instantiate() as MapController
	root.add_child(controller)
	return controller


func _test_pursuit_step_is_adjacent_and_reduces_distance() -> void:
	const TEST_NAME := "test_pursuit_step_is_adjacent_and_reduces_distance"
	var model := _new_model()
	if not _require_method(model, "get_hex_distance", TEST_NAME) or not _require_method(model, "get_pursuit_step", TEST_NAME):
		return
	var from_coord := Vector2i(4, 4)
	var target := Vector2i(0, 0)
	var step: Vector2i = model.call("get_pursuit_step", from_coord, target)
	var original_distance: int = model.call("get_hex_distance", from_coord, target)
	var step_distance: int = model.call("get_hex_distance", step, target)
	_assert(model.are_adjacent(from_coord, step), TEST_NAME, "step must be adjacent")
	_assert(step_distance == original_distance - 1, TEST_NAME, "step must reduce distance by one")


func _test_pursuit_tie_break_uses_neighbor_order() -> void:
	const TEST_NAME := "test_pursuit_tie_break_uses_neighbor_order"
	var model := _new_model()
	if not _require_method(model, "get_pursuit_step", TEST_NAME):
		return
	var step: Vector2i = model.call("get_pursuit_step", Vector2i(4, 4), Vector2i(0, 0))
	_assert(step == Vector2i(4, 3), TEST_NAME, "first equally short NEIGHBOR_OFFSETS candidate must win")


func _test_pursuit_step_is_deterministic() -> void:
	const TEST_NAME := "test_pursuit_step_is_deterministic"
	var model := _new_model()
	if not _require_method(model, "get_pursuit_step", TEST_NAME):
		return
	var first: Vector2i = model.call("get_pursuit_step", Vector2i(3, 3), Vector2i(0, 1))
	var second: Vector2i = model.call("get_pursuit_step", Vector2i(3, 3), Vector2i(0, 1))
	_assert(first == second, TEST_NAME, "identical inputs must return identical steps")


func _test_invalid_or_equal_endpoints_stay_put() -> void:
	const TEST_NAME := "test_invalid_or_equal_endpoints_stay_put"
	var model := _new_model()
	if not _require_method(model, "get_pursuit_step", TEST_NAME):
		return
	var source := Vector2i(2, 2)
	_assert(model.call("get_pursuit_step", source, source) == source, TEST_NAME, "equal endpoints must stay put")
	_assert(model.call("get_pursuit_step", source, Vector2i(9, 9)) == source, TEST_NAME, "invalid target must stay put")


func _test_moves_before_threshold_keep_boss_idle() -> void:
	const TEST_NAME := "test_moves_before_threshold_keep_boss_idle"
	var controller := _new_controller()
	await process_frame
	var origin := controller.boss_coord
	_move_back_and_forth(controller, 14)
	_assert(controller.move_count == 14, TEST_NAME, "fixture must reach move 14")
	_assert(controller.boss_coord == origin, TEST_NAME, "boss must remain idle through move 14")
	_assert(not _is_sudden_death_active(controller, TEST_NAME), TEST_NAME, "Sudden Death must remain inactive")
	controller.queue_free()


func _test_move_fifteen_activates_without_pursuit() -> void:
	const TEST_NAME := "test_move_fifteen_activates_without_pursuit"
	var controller := _new_controller()
	await process_frame
	var origin := controller.boss_coord
	_move_back_and_forth(controller, 15)
	_assert(controller.move_count == 15, TEST_NAME, "fixture must reach move 15")
	_assert(_is_sudden_death_active(controller, TEST_NAME), TEST_NAME, "move 15 must activate Sudden Death")
	_assert(controller.boss_coord == origin, TEST_NAME, "boss must not move on activation turn")
	controller.queue_free()


func _test_move_sixteen_starts_one_step_pursuit() -> void:
	const TEST_NAME := "test_move_sixteen_starts_one_step_pursuit"
	var controller := _new_controller()
	await process_frame
	_move_back_and_forth(controller, 15)
	var model := HexMapModel.new()
	if not _require_method(model, "get_pursuit_step", TEST_NAME):
		controller.queue_free()
		return
	var before := controller.boss_coord
	var expected: Vector2i = model.call("get_pursuit_step", before, Vector2i.ZERO)
	_move_and_close(controller, Vector2i.ZERO)
	_assert(controller.move_count == 16, TEST_NAME, "fixture must reach move 16")
	_assert(controller.boss_coord == expected, TEST_NAME, "move 16 must produce exactly the deterministic first step")
	controller.queue_free()


func _test_each_later_accepted_move_advances_once() -> void:
	const TEST_NAME := "test_each_later_accepted_move_advances_once"
	var controller := _new_controller()
	await process_frame
	_move_back_and_forth(controller, 16)
	var before := controller.boss_coord
	_move_and_close(controller, Vector2i(0, 1))
	_assert(HexMapModel.new().are_adjacent(before, controller.boss_coord), TEST_NAME, "move 17 must advance the boss once")
	controller.queue_free()


func _test_rejected_and_blocked_moves_do_not_advance_pursuit() -> void:
	const TEST_NAME := "test_rejected_and_blocked_moves_do_not_advance_pursuit"
	var controller := _new_controller()
	await process_frame
	_move_back_and_forth(controller, 15)
	var before := controller.boss_coord
	var count_before := controller.move_count
	_assert(not controller.request_move(Vector2i(4, 0)), TEST_NAME, "non-adjacent move must be rejected")
	_assert(controller.boss_coord == before and controller.move_count == count_before, TEST_NAME, "rejected move must not mutate pursuit")
	_assert(controller.request_move(Vector2i.ZERO), TEST_NAME, "move 16 fixture must be accepted")
	var after_move := controller.boss_coord
	var count_after := controller.move_count
	_assert(not controller.request_move(Vector2i(0, 1)), TEST_NAME, "active overlay must block movement")
	_assert(controller.boss_coord == after_move and controller.move_count == count_after, TEST_NAME, "blocked move must not mutate pursuit")
	controller.close_active_encounter()
	controller.queue_free()


func _test_player_entering_boss_coord_triggers_boss_encounter() -> void:
	const TEST_NAME := "test_player_entering_boss_coord_triggers_boss_encounter"
	var controller := _new_controller()
	await process_frame
	controller.player_coord = Vector2i(3, 4)
	controller.boss_coord = Vector2i(4, 4)
	_assert(controller.request_move(Vector2i(4, 4)), TEST_NAME, "player must enter adjacent boss coordinate")
	_assert(controller.has_active_encounter(), TEST_NAME, "Boss encounter must open")
	if controller.has_active_encounter():
		_assert(controller.get_active_encounter().encounter_type == HexMapModel.ENCOUNTER_BOSS, TEST_NAME, "encounter must be Boss")
	controller.close_active_encounter()
	controller.queue_free()


func _test_boss_reaching_player_triggers_boss_encounter() -> void:
	const TEST_NAME := "test_boss_reaching_player_triggers_boss_encounter"
	var controller := _new_controller()
	await process_frame
	_move_back_and_forth(controller, 15)
	controller.boss_coord = Vector2i(1, 0)
	_assert(controller.request_move(Vector2i.ZERO), TEST_NAME, "move 16 must be accepted")
	_assert(controller.boss_coord == controller.player_coord, TEST_NAME, "boss must reach player")
	_assert(controller.has_active_encounter(), TEST_NAME, "Boss encounter must open after pursuit")
	if controller.has_active_encounter():
		_assert(controller.get_active_encounter().encounter_type == HexMapModel.ENCOUNTER_BOSS, TEST_NAME, "encounter must be Boss")
	controller.close_active_encounter()
	controller.queue_free()


func _test_runtime_boss_identity_moves_and_vacated_origin_is_safe() -> void:
	const TEST_NAME := "test_runtime_boss_identity_moves_and_vacated_origin_is_safe"
	var controller := _new_controller()
	await process_frame
	if not _require_method(controller, "get_runtime_encounter_type_at", TEST_NAME):
		controller.queue_free()
		return
	var origin := controller.boss_coord
	_move_back_and_forth(controller, 16)
	_assert(controller.call("get_runtime_encounter_type_at", controller.boss_coord) == HexMapModel.ENCOUNTER_BOSS, TEST_NAME, "current boss coordinate must resolve as Boss")
	_assert(controller.call("get_runtime_encounter_type_at", origin) == HexMapModel.ENCOUNTER_SAFE, TEST_NAME, "vacated origin must resolve as Safe")
	controller.queue_free()


func _test_set_run_id_resets_sudden_death() -> void:
	const TEST_NAME := "test_set_run_id_resets_sudden_death"
	var controller := _new_controller()
	await process_frame
	_move_back_and_forth(controller, 16)
	controller.set_run_id("ac1-5-reset")
	_assert(controller.player_coord == Vector2i.ZERO, TEST_NAME, "player must reset to start")
	_assert(controller.boss_coord == Vector2i(4, 4), TEST_NAME, "boss must reset to origin")
	_assert(controller.move_count == 0, TEST_NAME, "move count must reset")
	_assert(not _is_sudden_death_active(controller, TEST_NAME), TEST_NAME, "Sudden Death must reset")
	_assert(not controller.has_active_encounter(), TEST_NAME, "active overlay must close on reset")
	controller.queue_free()


func _move_back_and_forth(controller: MapController, target_count: int) -> void:
	while controller.move_count < target_count:
		var destination := Vector2i(0, 1) if controller.player_coord == Vector2i.ZERO else Vector2i.ZERO
		_move_and_close(controller, destination)


func _move_and_close(controller: MapController, destination: Vector2i) -> void:
	controller.request_move(destination)
	if controller.has_active_encounter():
		controller.close_active_encounter()


func _is_sudden_death_active(controller: MapController, test_name: String) -> bool:
	if not _require_method(controller, "is_sudden_death_active", test_name):
		return false
	return controller.call("is_sudden_death_active")


func _require_method(object: Object, method_name: String, test_name: String) -> bool:
	if object.has_method(method_name):
		return true
	_failures.append("%s - missing method %s" % [test_name, method_name])
	return false


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC1.5 sudden death tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
