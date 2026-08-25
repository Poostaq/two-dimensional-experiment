class_name WorldCellViewTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_cell_view.tscn"
const EXPECTED_TEST_COUNT := 47

var _failures: Array[String] = []
var _assertions: int = 0
var _selected_coords: Array[Vector2i] = []
var _inspected_coords: Array[Vector2i] = []


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
	var marker_outline := cell.get_node_or_null("MarkerLayer/Outline") as Line2D
	_expect(is_instance_valid(marker_outline) and marker_outline.closed and marker_outline.width >= 2.0, "marker outline is rendered as closed geometry")

	var road_edges: Array[Vector2i] = [Vector2i(1, 0)]
	cell.call("configure", Vector2i(2, -1), "Combat", "forest", road_edges, true)
	_expect(cell.has_signal("selected"), "cell exposes selection intent without owning movement")
	_expect(cell.has_signal("inspected"), "cell exposes inspection intent without mutating data")
	cell.connect("selected", _on_cell_selected)
	cell.connect("inspected", _on_cell_inspected)
	cell.call("request_selection")
	cell.call("request_inspection")
	_expect(_selected_coords == [Vector2i(2, -1)], "selection emits configured coordinate exactly once")
	_expect(_inspected_coords == [Vector2i(2, -1)], "inspection emits configured coordinate exactly once")
	_expect(cell.coordinate == Vector2i(2, -1), "selection and inspection preserve coordinate")
	_expect(cell.encounter_type == "Combat", "selection and inspection preserve encounter data")
	_expect(cell.terrain_type == "forest" and cell.is_town, "selection and inspection preserve terrain and town data")
	_expect((cell.get_node("TerrainLayer/ForestFill") as Polygon2D).visible, "forest terrain is shown independently")
	_expect((cell.get_node("TownLayer/Buildings") as Node2D).visible, "town buildings are shown")
	_expect(cell.get_node("RoadLayer/RoadLines").get_child_count() == 1, "one road corridor is drawn for one edge")
	_expect((cell.get_node("EncounterBase/Fill") as Polygon2D).color != Color("526b5b"), "encounter base remains independently configurable")
	cell.call("set_highlighted", true)
	_expect((cell.get_node("HighlightLayer/Outline") as Line2D).visible, "highlight layer can be enabled")
	cell.call("set_highlighted", false)
	_expect(not (cell.get_node("HighlightLayer/Outline") as Line2D).visible, "highlight layer can be cleared")
	cell.call("set_party_marker", "player")
	_expect((cell.get_node("MarkerLayer/PartyIcon") as Sprite2D).visible, "player icon is visible")
	_expect((cell.get_node("MarkerLayer/Plate") as Polygon2D).visible, "player readability plate is visible")
	_expect(marker_outline.visible, "rendered marker outline is visible with player")
	_expect((cell.get_node("ContextLayer/PartyLabel") as Label).text == "P", "player has a non-color label")
	_expect((cell.get_node("MarkerLayer/PartyIcon") as Sprite2D).modulate == Color("55d879"), "player icon is green")
	cell.call("set_party_marker", "boss")
	_expect((cell.get_node("ContextLayer/PartyLabel") as Label).text == "B", "boss has a non-color label")
	_expect((cell.get_node("MarkerLayer/PartyIcon") as Sprite2D).modulate == Color("ef5b62"), "boss icon is red")
	cell.call("set_party_marker", "")
	_expect(not (cell.get_node("MarkerLayer/PartyIcon") as Sprite2D).visible, "empty marker hides the icon")
	_expect(not (cell.get_node("MarkerLayer/Plate") as Polygon2D).visible, "empty marker hides the plate")
	_expect(not marker_outline.visible, "empty marker hides the rendered outline")
	_expect(not (cell.get_node("ContextLayer/PartyLabel") as Label).visible, "empty marker hides the label")

	cell.queue_free()
	await process_frame
	_finish()


func _on_cell_selected(coord: Vector2i) -> void:
	_selected_coords.append(coord)


func _on_cell_inspected(coord: Vector2i) -> void:
	_inspected_coords.append(coord)


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
