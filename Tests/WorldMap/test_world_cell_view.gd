class_name WorldCellViewTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_cell_view.tscn"
const EXPECTED_TEST_COUNT := 22

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "world cell scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var cell := packed.instantiate() as Node2D
	get_root().add_child(cell)
	await process_frame

	var layers := [
		["EncounterBase", 0],
		["TerrainLayer", 1],
		["RoadLayer", 2],
		["TownLayer", 3],
		["HighlightLayer", 4],
		["MarkerLayer", 5],
		["ContextLayer", 6],
	]
	for layer: Array in layers:
		var node := cell.get_node_or_null(String(layer[0])) as CanvasItem
		_expect(is_instance_valid(node), "%s exists" % layer[0])
		if is_instance_valid(node):
			_expect(node.z_index == int(layer[1]), "%s has fixed z-index %d" % [layer[0], layer[1]])

	var outline := cell.get_node_or_null("EncounterBase/Outline") as Line2D
	_expect(is_instance_valid(outline) and outline.closed and outline.width >= 2.0, "persistent closed outline is readable")

	var flat_width := 80.0
	var point_height := 92.0
	_expect(float(cell.call("road_corridor_width", flat_width)) == 16.0, "road corridor is ceil 20 percent of flat width")
	_expect(float(cell.call("road_corridor_width", 12.0)) == 4.0, "road corridor has four-pixel minimum")
	var footprint := cell.call("town_footprint", flat_width, point_height) as Rect2
	_expect(footprint == Rect2(-24.0, -23.0, 48.0, 46.0), "town footprint reserves the exact centered rectangle")
	_expect(float(cell.call("marker_plate_diameter", flat_width, point_height)) == 36.0, "marker plate uses ceil 44 percent of smaller dimension")
	_expect(is_equal_approx(float(cell.call("marker_silhouette_diameter", flat_width, point_height)), 30.4), "marker silhouette uses 38 percent maximum")
	_expect(float(cell.call("marker_outline_width")) >= 2.0, "marker plate has contrasting two-pixel outline")

	cell.queue_free()
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
		print("World cell view tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
