class_name WorldPresentationSceneTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_map_preview.tscn"
const EXPECTED_TEST_COUNT := 57

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
	var road_cell_count := 0
	for cell: Node in preview.get_node("%WorldCells").get_children():
		if cell.get_node("RoadLayer/RoadLines").get_child_count() > 0:
			road_cell_count += 1
	_expect(road_cell_count > 6, "town-to-town routes populate every traversed cell road layer")
	_expect(preview.call("get_player_coord") == Vector2i(-8, 0), "player marker uses canonical start")
	_expect(preview.call("get_boss_coord") == Vector2i(8, 0), "boss marker uses canonical boss start")
	_expect(is_instance_valid(preview.get_node_or_null("%WorldCamera")), "world camera is composed")
	_expect(is_instance_valid(preview.get_node_or_null("%WorldMinimap")), "minimap is composed")
	_expect(is_instance_valid(preview.get_node_or_null("%WorldMapHud")), "HUD is composed")
	var camera := preview.get_node("%WorldCamera") as WorldCameraController
	var minimap := preview.get_node("%WorldMinimap") as WorldMinimap
	var footprint_before := minimap.get_camera_footprint()
	camera.pan_by(Vector2(-80.0, 0.0))
	_expect(minimap.get_camera_footprint() != footprint_before, "minimap footprint updates live after camera pan")
	footprint_before = minimap.get_camera_footprint()
	camera.zoom_by_steps(-1, Vector2(576.0, 324.0))
	_expect(minimap.get_camera_footprint() != footprint_before, "minimap footprint updates live after camera zoom")

	var canonical_corners: Array[Vector2i] = [
		Vector2i(-8, 0),
		Vector2i(-8, 8),
		Vector2i(0, -8),
		Vector2i(0, 8),
		Vector2i(8, -8),
		Vector2i(8, 0),
	]
	var framing_steps: Array[int] = [100, 0, -100]
	var framing_labels: Array[int] = [3, 5, 11]
	var plan_id_before := int(preview.call("get_plan_instance_id"))
	for framing_index: int in framing_steps.size():
		camera.set_default_zoom()
		camera.zoom_by_steps(framing_steps[framing_index], Vector2(576.0, 324.0))
		for corner: Vector2i in canonical_corners:
			var target := Vector2(preview.call("axial_to_world", corner))
			camera.center_on(target)
			_expect(
				camera.position.is_equal_approx(target),
				"radius-8 corner %s centers at %d-hex framing" % [corner, framing_labels[framing_index]]
			)
	camera.set_default_zoom()
	camera.zoom_by_steps(-100, Vector2(576.0, 324.0))
	camera.center_on(Vector2(preview.call("axial_to_world", Vector2i(-8, 0))))
	var left_edge_footprint := minimap.get_camera_footprint()
	_expect(
		left_edge_footprint[0].x < minimap.get_node("%PlayerIcon").position.x,
		"left-edge minimap footprint overscans beyond the map"
	)
	camera.center_on(Vector2(preview.call("axial_to_world", Vector2i(8, 0))))
	var right_edge_footprint := minimap.get_camera_footprint()
	_expect(right_edge_footprint != left_edge_footprint, "minimap footprint follows opposite-edge camera centering")
	_expect(
		right_edge_footprint[1].x > minimap.get_node("%BossIcon").position.x,
		"right-edge minimap footprint overscans beyond the map"
	)
	_expect(int(preview.call("get_plan_instance_id")) == plan_id_before, "camera framing preserves logical plan identity")

	camera.center_on(Vector2(99999.0, 99999.0))
	_expect(camera.position.is_equal_approx(Vector2(640.0, 552.0)), "positive camera limit equals canonical cell-center bounds")
	camera.center_on(Vector2(-99999.0, -99999.0))
	_expect(camera.position.is_equal_approx(Vector2(-640.0, -552.0)), "negative camera limit equals canonical cell-center bounds")
	_expect(
		int(preview.call("get_plan_instance_id"))
		== int(preview.get_node("%WorldMinimap").call("get_plan_instance_id")),
		"main map and minimap share one logical plan"
	)
	var runtime_plan_id := int(preview.call("get_plan_instance_id"))
	var runtime_snapshot := WorldRuntimeSnapshot.new(Vector2i(-7, 0), Vector2i(7, 0), 1, false, false, false)
	_expect(bool(preview.call("apply_runtime_snapshot", runtime_snapshot)), "valid runtime snapshot applies atomically")
	_expect(preview.call("get_player_coord") == Vector2i(-7, 0), "snapshot moves main-map player marker")
	_expect(preview.call("get_boss_coord") == Vector2i(7, 0), "snapshot moves main-map boss marker")
	_expect(minimap.get_player_coord() == Vector2i(-7, 0), "snapshot moves minimap player marker")
	_expect(minimap.get_boss_coord() == Vector2i(7, 0), "snapshot moves minimap boss marker")
	var player_marker_count := 0
	var boss_marker_count := 0
	for cell: Node in preview.get_node("%WorldCells").get_children():
		var label := cell.get_node("ContextLayer/PartyLabel") as Label
		if label.visible and label.text == "P":
			player_marker_count += 1
		elif label.visible and label.text == "B":
			boss_marker_count += 1
	_expect(player_marker_count == 1, "snapshot renders exactly one player marker")
	_expect(boss_marker_count == 1, "snapshot renders exactly one boss marker")
	_expect(int(preview.call("get_plan_instance_id")) == runtime_plan_id, "snapshot preserves logical plan identity")
	var valid_destinations: Array[Vector2i] = [Vector2i(-8, 0), Vector2i(-7, -1)]
	preview.call("set_valid_destinations", valid_destinations)
	var highlighted_count := 0
	for cell: Node in preview.get_node("%WorldCells").get_children():
		if (cell.get_node("HighlightLayer/Outline") as Line2D).visible:
			highlighted_count += 1
	_expect(highlighted_count == 2, "valid destinations drive exactly two cell highlights")
	valid_destinations.clear()
	preview.call("set_valid_destinations", valid_destinations)
	highlighted_count = 0
	for cell: Node in preview.get_node("%WorldCells").get_children():
		if (cell.get_node("HighlightLayer/Outline") as Line2D).visible:
			highlighted_count += 1
	_expect(highlighted_count == 0, "empty destinations clear all cell highlights")
	_expect(not preview.has_method("request_move"), "presentation adapter does not own movement requests")

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
