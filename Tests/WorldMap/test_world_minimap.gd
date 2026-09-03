class_name WorldMinimapTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_minimap.tscn"
const EXPECTED_TEST_COUNT := 28

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "world minimap scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var generated := HexWorldGeneratorV1.new().generate("golden-alpha")
	_expect(bool(generated.get("ok", false)), "golden plan generates")
	if not generated.get("ok", false):
		_finish()
		return
	var plan := generated["plan"] as WorldPlan
	var canonical_before := WorldPlanCodecV1.serialize(plan)
	var minimap := packed.instantiate() as Control
	get_root().add_child(minimap)
	await process_frame

	var minimap_rect := minimap.get_global_rect()
	_expect(is_equal_approx(minimap_rect.position.x, 0.0), "minimap is flush left")
	_expect(is_equal_approx(minimap_rect.position.y, 48.0), "minimap touches the top bar")
	_expect(is_equal_approx(minimap_rect.size.x, 225.0), "minimap width is 75 percent")
	_expect(is_equal_approx(minimap_rect.size.y, 225.0), "minimap height is 75 percent")

	_expect(bool(minimap.call("configure", plan, plan.get_start_coord(), plan.get_boss_coord())), "valid plan configures")
	_expect(int(minimap.call("get_cell_count")) == 217, "minimap contains all 217 cells")
	_expect(minimap.get_node("%Cells").get_child_count() == 217, "cells are individually represented")
	var cells_are_hexes := true
	for child: Node in minimap.get_node("%Cells").get_children():
		var polygon := child as Polygon2D
		if not is_instance_valid(polygon) or polygon.polygon.size() != 6:
			cells_are_hexes = false
			break
	_expect(cells_are_hexes, "every miniature cell is a six-point hexagon")
	_expect(int(minimap.call("get_town_count")) == 7, "all seven towns are shown")
	_expect(minimap.get_node("%Towns").get_child_count() == 7, "towns have seven distinct markers")
	_expect((minimap.get_node("%PlayerIcon") as Sprite2D).visible, "player icon is visible")
	_expect((minimap.get_node("%PlayerIcon") as Sprite2D).modulate == Color("55d879"), "player icon is green")
	_expect((minimap.get_node("%PlayerLabel") as Label).text == "P", "player has a non-color label")
	_expect((minimap.get_node("%BossIcon") as Sprite2D).visible, "boss icon is visible")
	_expect((minimap.get_node("%BossIcon") as Sprite2D).modulate == Color("ef5b62"), "boss icon is red")
	_expect((minimap.get_node("%BossLabel") as Label).text == "B", "boss has a non-color label")
	_expect(minimap.call("get_player_coord") == Vector2i(-8, 0), "player marker uses runtime coordinate")
	_expect(minimap.call("get_boss_coord") == Vector2i(8, 0), "boss marker uses runtime coordinate")

	var plan_id_before := int(minimap.call("get_plan_instance_id"))
	var footprint_during_marker_update := minimap.call("get_camera_footprint") as PackedVector2Array
	minimap.call("update_party_markers", Vector2i(-7, 0), Vector2i(7, 0))
	_expect(minimap.call("get_player_coord") == Vector2i(-7, 0), "runtime update moves minimap player coordinate")
	_expect(minimap.call("get_boss_coord") == Vector2i(7, 0), "runtime update moves minimap boss coordinate")
	_expect((minimap.get_node("%PlayerIcon") as Sprite2D).position != (minimap.get_node("%BossIcon") as Sprite2D).position, "runtime party markers remain distinct")
	_expect(int(minimap.call("get_plan_instance_id")) == plan_id_before, "party update preserves logical plan identity")
	_expect(minimap.call("get_camera_footprint") == footprint_during_marker_update, "party update preserves camera footprint")

	var footprint_before := minimap.call("get_camera_footprint") as PackedVector2Array
	minimap.call("update_camera_footprint", Rect2(-80.0, -60.0, 160.0, 120.0))
	var footprint_after := minimap.call("get_camera_footprint") as PackedVector2Array
	_expect(footprint_after.size() == 4 and footprint_after != footprint_before, "camera footprint updates as a four-corner outline")
	_expect(WorldPlanCodecV1.serialize(plan) == canonical_before, "camera update does not mutate canonical plan")
	_expect(
		(minimap.call("project_axial", Vector2i(-8, 0)) as Vector2).x
		< (minimap.call("project_axial", Vector2i(8, 0)) as Vector2).x,
		"axial projection preserves west-to-east board orientation"
	)

	minimap.queue_free()
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
		print("World minimap tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
