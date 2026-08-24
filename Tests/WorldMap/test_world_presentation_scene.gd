class_name WorldPresentationSceneTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_map_preview.tscn"
const EXPECTED_TEST_COUNT := 19

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/game_world.tscn",
		"production main scene remains frozen"
	)
	var packed := load(SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "non-production preview scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var preview := packed.instantiate() as Node2D
	get_root().add_child(preview)
	await process_frame
	await process_frame

	_expect(bool(preview.call("is_plan_presented")), "fixture plan is presented atomically")
	_expect(int(preview.call("get_main_cell_count")) == 217, "main map contains 217 cells")
	_expect(preview.get_node("%WorldCells").get_child_count() == 217, "main cells are individually instantiated")
	_expect(int(preview.call("get_forest_cluster_count")) == 10, "all ten forest clusters are represented")
	_expect(int(preview.call("get_town_count")) == 7, "all seven towns are represented")
	_expect(int(preview.call("get_road_count")) == 6, "seven towns use a six-edge spanning road network")
	_expect(preview.call("get_player_coord") == Vector2i(-8, 0), "player marker uses canonical start")
	_expect(preview.call("get_boss_coord") == Vector2i(8, 0), "boss marker uses canonical boss start")
	_expect(is_instance_valid(preview.get_node_or_null("%WorldCamera")), "world camera is composed")
	_expect(is_instance_valid(preview.get_node_or_null("%WorldMinimap")), "minimap is composed")
	_expect(is_instance_valid(preview.get_node_or_null("%WorldMapHud")), "HUD is composed")
	_expect(
		int(preview.call("get_plan_instance_id"))
		== int(preview.get_node("%WorldMinimap").call("get_plan_instance_id")),
		"main map and minimap share one logical plan"
	)
	var before_count := int(preview.call("get_main_cell_count"))
	_expect(not bool(preview.call("present_plan", null)), "invalid plan is rejected")
	_expect(int(preview.call("get_main_cell_count")) == before_count, "invalid plan creates no partial presentation")
	_expect(
		ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/game_world.tscn",
		"preview does not change production authority"
	)
	_expect(not preview.has_method("request_move"), "Stage 3 preview owns no runtime movement")
	_expect(not preview.has_method("resolve_encounter"), "Stage 3 preview owns no encounter flow")

	preview.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("World presentation scene tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
