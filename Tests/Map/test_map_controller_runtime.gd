class_name TestMapControllerRuntime
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 8

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node = _instantiate_world()
	if world != null:
		root.add_child(world)
		await process_frame
		await process_frame
		_test_scene_has_expected_controller(world)
		_test_runtime_has_25_tiles(world)
		_test_player_starts_at_corner(world)
		_test_boss_marker_is_opposite_corner(world)
		_test_valid_adjacent_move_updates_state(world)
		_test_invalid_edge_move_is_rejected(world)
		_test_non_adjacent_move_is_rejected(world)
		_test_valid_path_toward_boss_exists(world)
		world.queue_free()

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _instantiate_world() -> Node:
	if not ResourceLoader.exists(GAME_WORLD_PATH):
		_failures.append("test_game_world_scene_exists - missing %s" % GAME_WORLD_PATH)
		return null

	var packed_scene: PackedScene = load(GAME_WORLD_PATH) as PackedScene
	if packed_scene == null:
		_failures.append("test_game_world_scene_exists - failed to load %s" % GAME_WORLD_PATH)
		return null

	return packed_scene.instantiate()


func _test_scene_has_expected_controller(world: Node) -> void:
	_assert(world is MapController, "test_scene_has_expected_controller", "game_world root should be MapController")
	_assert(world.has_node("MapRoot"), "test_scene_has_expected_controller", "MapRoot node should exist")
	_assert(world.has_node("MapRoot/PlayerMarker"), "test_scene_has_expected_controller", "PlayerMarker node should exist")
	_assert(world.has_node("MapRoot/BossMarker"), "test_scene_has_expected_controller", "BossMarker node should exist")


func _test_runtime_has_25_tiles(world: Node) -> void:
	var map_root: Node = world.get_node("MapRoot")
	var tile_count := 0
	for child: Node in map_root.get_children():
		if child is HexTileView:
			tile_count += 1
	_assert(tile_count == 25, "test_runtime_has_25_tiles", "expected 25 generated tiles, got %d" % tile_count)


func _test_player_starts_at_corner(world: Node) -> void:
	_assert(world.player_coord == Vector2i(0, 0), "test_player_starts_at_corner", "expected player at (0, 0), got %s" % world.player_coord)


func _test_boss_marker_is_opposite_corner(world: Node) -> void:
	_assert(world.boss_coord == Vector2i(4, 4), "test_boss_marker_is_opposite_corner", "expected boss at (4, 4), got %s" % world.boss_coord)
	var boss_marker: Node2D = world.get_node("MapRoot/BossMarker") as Node2D
	_assert(boss_marker.position == world.axial_to_world(Vector2i(4, 4)), "test_boss_marker_is_opposite_corner", "boss marker should be placed on boss coord")


func _test_valid_adjacent_move_updates_state(world: Node) -> void:
	var moved: bool = world.request_move(Vector2i(1, 0))
	_assert(moved, "test_valid_adjacent_move_updates_state", "adjacent move should return true")
	_assert(world.player_coord == Vector2i(1, 0), "test_valid_adjacent_move_updates_state", "expected player at (1, 0), got %s" % world.player_coord)
	_assert(world.move_count == 1, "test_valid_adjacent_move_updates_state", "expected move_count 1, got %d" % world.move_count)


func _test_invalid_edge_move_is_rejected(world: Node) -> void:
	world.player_coord = Vector2i(0, 0)
	world.move_count = 0
	var moved: bool = world.request_move(Vector2i(1, -1))
	_assert(not moved, "test_invalid_edge_move_is_rejected", "out-of-bounds adjacent offset should return false")
	_assert(world.player_coord == Vector2i(0, 0), "test_invalid_edge_move_is_rejected", "out-of-bounds move should keep player at start")
	_assert(world.move_count == 0, "test_invalid_edge_move_is_rejected", "out-of-bounds move should not increment move_count")


func _test_non_adjacent_move_is_rejected(world: Node) -> void:
	world.player_coord = Vector2i(0, 0)
	world.move_count = 0
	var moved: bool = world.request_move(Vector2i(4, 4))
	_assert(not moved, "test_non_adjacent_move_is_rejected", "non-adjacent boss jump should return false")
	_assert(world.player_coord == Vector2i(0, 0), "test_non_adjacent_move_is_rejected", "non-adjacent move should keep player at start")
	_assert(world.move_count == 0, "test_non_adjacent_move_is_rejected", "non-adjacent move should not increment move_count")


func _test_valid_path_toward_boss_exists(world: Node) -> void:
	world.player_coord = Vector2i(0, 0)
	world.move_count = 0
	var path: Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(0, 2),
		Vector2i(0, 3),
		Vector2i(0, 4),
		Vector2i(1, 4),
		Vector2i(2, 4),
		Vector2i(3, 4),
		Vector2i(4, 4),
	]

	for destination: Vector2i in path:
		if not world.request_move(destination):
			_failures.append("test_valid_path_toward_boss_exists - failed moving to %s" % destination)
			return

	_assert(world.player_coord == Vector2i(4, 4), "test_valid_path_toward_boss_exists", "expected player to reach boss coord, got %s" % world.player_coord)
	_assert(world.move_count == path.size(), "test_valid_path_toward_boss_exists", "expected move_count %d, got %d" % [path.size(), world.move_count])


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := EXPECTED_TEST_COUNT - _failures.size()
	if _failures.is_empty():
		print("AC1.1 runtime map controller tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.1 runtime map controller tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
