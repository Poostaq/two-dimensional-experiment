class_name TestAc12RuntimeEncounterLayout
extends SceneTree

const SCENE_PATH := "res://Scenes/game_world.tscn"
const RUN_ID_A := "AC1.2-A"
const RUN_ID_B := "AC1.2-B"
const EXPECTED_TEST_COUNT := 5

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller: MapController = await _create_controller()
	if controller != null and _controller_has_ac12_api(controller):
		_test_default_layout_exists(controller)
		_test_same_run_id_keeps_matching_layout(controller)
		_test_different_run_id_changes_layout(controller)
		_test_controller_reports_start_safe(controller)
		_test_controller_reports_boss_boss(controller)

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _create_controller() -> MapController:
	if not ResourceLoader.exists(SCENE_PATH):
		_failures.append("test_scene_exists - missing %s" % SCENE_PATH)
		return null

	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		_failures.append("test_scene_exists - failed to load %s" % SCENE_PATH)
		return null

	var instance := scene.instantiate()
	get_root().add_child(instance)
	await process_frame

	var controller := instance as MapController
	if controller == null:
		_failures.append("test_scene_root_is_map_controller - scene root is not MapController")
	return controller


func _controller_has_ac12_api(controller: MapController) -> bool:
	var has_api := true
	for method_name: String in ["get_encounter_layout", "set_run_id", "get_encounter_type_at"]:
		if not controller.has_method(method_name):
			_failures.append("test_controller_has_ac12_api - missing %s" % method_name)
			has_api = false
	return has_api


func _test_default_layout_exists(controller: MapController) -> void:
	var layout: Dictionary = controller.get_encounter_layout()
	_assert(layout.size() == 25, "test_default_layout_exists", "expected 25 encounter entries, got %d" % layout.size())


func _test_same_run_id_keeps_matching_layout(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	var first_layout: Dictionary = controller.get_encounter_layout()

	controller.set_run_id(RUN_ID_A)
	var second_layout: Dictionary = controller.get_encounter_layout()

	_assert(_layouts_match(first_layout, second_layout), "test_same_run_id_keeps_matching_layout", "same Run ID produced different controller layouts")


func _test_different_run_id_changes_layout(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	var first_layout: Dictionary = controller.get_encounter_layout()

	controller.set_run_id(RUN_ID_B)
	var second_layout: Dictionary = controller.get_encounter_layout()

	_assert(not _layouts_match(first_layout, second_layout), "test_different_run_id_changes_layout", "fixture Run IDs AC1.2-A and AC1.2-B must differ by at least one non-boss tile")


func _test_controller_reports_start_safe(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	_assert(controller.get_encounter_type_at(Vector2i(0, 0)) == HexMapModel.ENCOUNTER_SAFE, "test_controller_reports_start_safe", "expected start Safe")


func _test_controller_reports_boss_boss(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	_assert(controller.get_encounter_type_at(Vector2i(4, 4)) == HexMapModel.ENCOUNTER_BOSS, "test_controller_reports_boss_boss", "expected boss Boss")


func _layouts_match(first_layout: Dictionary, second_layout: Dictionary) -> bool:
	if first_layout.size() != second_layout.size():
		return false

	for coord: Vector2i in first_layout.keys():
		if not second_layout.has(coord):
			return false
		if first_layout[coord] != second_layout[coord]:
			return false

	return true


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := EXPECTED_TEST_COUNT - _failures.size()
	if _failures.is_empty():
		print("AC1.2 runtime encounter layout tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.2 runtime encounter layout tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
