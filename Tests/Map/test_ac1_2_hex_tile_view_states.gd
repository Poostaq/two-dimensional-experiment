class_name TestAc12HexTileViewStates
extends SceneTree

const TILE_SCENE_PATH := "res://Scenes/map_hex_tile.tscn"
const EXPECTED_TEST_COUNT := 1
const EXPECTED_COMBAT_FILL := Color(0.72, 0.34, 0.22, 1.0)
const EXPECTED_COMBAT_OUTLINE := Color(1.0, 0.74, 0.36, 1.0)

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var tile: HexTileView = await _create_tile()
	if tile != null:
		_test_combat_state_uses_combat_colors(tile)

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _create_tile() -> HexTileView:
	if not ResourceLoader.exists(TILE_SCENE_PATH):
		_failures.append("test_tile_scene_exists - missing %s" % TILE_SCENE_PATH)
		return null

	var scene: PackedScene = load(TILE_SCENE_PATH) as PackedScene
	if scene == null:
		_failures.append("test_tile_scene_exists - failed to load %s" % TILE_SCENE_PATH)
		return null

	var instance := scene.instantiate()
	get_root().add_child(instance)
	await process_frame

	var tile := instance as HexTileView
	if tile == null:
		_failures.append("test_tile_scene_root_is_hex_tile_view - scene root is not HexTileView")
	return tile


func _test_combat_state_uses_combat_colors(tile: HexTileView) -> void:
	tile.set_display_state("combat")

	var fill := tile.get_node("Fill") as Polygon2D
	var outline := tile.get_node("Outline") as Line2D

	_assert(fill.color == EXPECTED_COMBAT_FILL, "test_combat_state_uses_combat_colors", "expected combat fill %s, got %s" % [EXPECTED_COMBAT_FILL, fill.color])
	_assert(outline.default_color == EXPECTED_COMBAT_OUTLINE, "test_combat_state_uses_combat_colors", "expected combat outline %s, got %s" % [EXPECTED_COMBAT_OUTLINE, outline.default_color])


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := EXPECTED_TEST_COUNT - _failures.size()
	if _failures.is_empty():
		print("AC1.2 hex tile view state tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.2 hex tile view state tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
