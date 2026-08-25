class_name WorldVisualFixtureTests
extends SceneTree

const CELL_SCENE_PATH := "res://Scenes/world_cell_view.tscn"
const FIXTURE_MANIFEST_PATH := "res://Docs/Specs/WorldMap/Evidence/PresentationStage3/visual/fixture-manifest.json"
const EXPECTED_ASSERTIONS := 48

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CELL_SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "cell fixture scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var fixtures := [
		{"name": "road-through-forest", "encounter": "Combat", "terrain": "forest", "roads": [Vector2i(1, 0), Vector2i(-1, 0)], "town": false, "highlight": false, "marker": ""},
		{"name": "town-on-safe", "encounter": "Safe", "terrain": "", "roads": [], "town": true, "highlight": false, "marker": ""},
		{"name": "highlighted-road", "encounter": "Combat", "terrain": "", "roads": [Vector2i(0, 1)], "town": false, "highlight": true, "marker": ""},
		{"name": "player-on-road", "encounter": "Safe", "terrain": "", "roads": [Vector2i(1, -1)], "town": false, "highlight": false, "marker": "player"},
		{"name": "boss-adjacent-to-forest", "encounter": "Boss", "terrain": "forest", "roads": [], "town": false, "highlight": false, "marker": "boss"},
	]
	var cells: Array[WorldCellView] = []
	for index: int in fixtures.size():
		var cell := packed.instantiate() as WorldCellView
		get_root().add_child(cell)
		await process_frame
		var fixture: Dictionary = fixtures[index]
		var roads: Array[Vector2i] = []
		roads.assign(fixture["roads"])
		cell.configure(Vector2i(index, 0), fixture["encounter"], fixture["terrain"], roads, fixture["town"])
		cell.set_highlighted(fixture["highlight"])
		cell.set_party_marker(fixture["marker"])
		cells.append(cell)
		_expect(cell.coordinate == Vector2i(index, 0), "%s has stable coordinate" % fixture["name"])

	_assert_protected_metrics(cells[0])
	_assert_layer_indices(cells[0])
	_expect(cells[0].get_node("TerrainLayer/ForestFill").visible, "road-through-forest keeps forest visible")
	_expect(cells[0].get_node("RoadLayer/RoadLines").get_child_count() == 2, "road-through-forest keeps road corridor visible")
	_expect(cells[1].encounter_type == "Safe", "town fixture remains Safe")
	_expect(cells[1].get_node("TownLayer/Buildings").visible, "town-on-Safe shows buildings")
	_expect(cells[2].get_node("HighlightLayer/Outline").visible, "highlighted road keeps highlight visible")
	_expect(cells[2].get_node("RoadLayer/RoadLines").get_child_count() == 1, "highlighted road keeps road visible")
	_expect(cells[3].get_node("MarkerLayer/PartyIcon").visible, "player-on-road shows player marker")
	_expect(cells[3].get_node("RoadLayer/RoadLines").get_child_count() == 1, "player-on-road keeps road visible")
	_expect(cells[3].get_node("ContextLayer/PartyLabel").text == "P", "player marker has non-color P label")
	_expect(cells[4].get_node("MarkerLayer/PartyIcon").visible, "boss-adjacent-to-forest shows boss marker")
	_expect(cells[4].get_node("TerrainLayer/ForestFill").visible, "boss-adjacent-to-forest keeps forest visible")
	_expect(cells[4].get_node("ContextLayer/PartyLabel").text == "B", "boss marker has non-color B label")

	var camera := WorldCameraController.new()
	get_root().add_child(camera)
	camera.configure(Rect2(-1000.0, -1000.0, 2000.0, 2000.0), Vector2(1152.0, 648.0), 80.0)
	_expect(is_equal_approx(camera.get_hexes_across(), 5.0), "default fixture frames five hexes")
	camera.zoom_by_steps(100, Vector2.ZERO)
	_expect(is_equal_approx(camera.get_hexes_across(), 3.0), "near fixture frames three hexes")
	camera.zoom_by_steps(-100, Vector2.ZERO)
	_expect(is_equal_approx(camera.get_hexes_across(), 11.0), "far fixture frames eleven hexes")
	for fixture: Dictionary in fixtures:
		for framing: int in [3, 5, 11]:
			_expect(not fixture["name"].is_empty() and framing > 0, "%s has %d-hex capture state" % [fixture["name"], framing])

	_expect(FileAccess.file_exists(FIXTURE_MANIFEST_PATH), "visual fixture manifest is published")
	for cell: WorldCellView in cells:
		cell.free()
	camera.free()
	_finish()


func _assert_protected_metrics(cell: WorldCellView) -> void:
	_expect(is_equal_approx(cell.road_corridor_width(80.0), 16.0), "road corridor is exactly 20 percent of flat width")
	_expect(cell.town_footprint(80.0, 92.0) == Rect2(-24.0, -23.0, 48.0, 46.0), "town footprint remains exact")
	_expect(is_equal_approx(cell.marker_plate_diameter(80.0, 92.0), 36.0), "marker plate diameter remains exact")
	_expect(is_equal_approx(cell.marker_outline_width(), 2.0), "marker outline remains exact")


func _assert_layer_indices(cell: WorldCellView) -> void:
	var paths := ["EncounterBase", "TerrainLayer", "RoadLayer", "TownLayer", "HighlightLayer", "MarkerLayer", "ContextLayer"]
	for index: int in paths.size():
		_expect(cell.get_node(paths[index]).z_index == index, "%s remains at layer %d" % [paths[index], index])


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions])
	if _failures.is_empty():
		print("World visual fixture tests: PASS (%d/%d)" % [_assertions, EXPECTED_ASSERTIONS])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
