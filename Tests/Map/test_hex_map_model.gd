extends SceneTree

const MODEL_PATH := "res://Scripts/Map/hex_map_model.gd"
const EXPECTED_TEST_COUNT := 7

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model_script: Variant = _load_model_script()
	if model_script != null:
		var model: HexMapModel = model_script.new() as HexMapModel
		_test_map_has_25_cells(model)
		_test_start_and_boss_corners(model)
		_test_neighbors_are_bounded(model)
		_test_adjacent_move_updates_player_coord(model)
		_test_out_of_bounds_move_is_rejected(model)
		_test_non_adjacent_move_is_rejected(model)
		_test_path_to_boss_exists(model)

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _load_model_script() -> Variant:
	if not ResourceLoader.exists(MODEL_PATH):
		_failures.append("test_model_script_exists - missing %s" % MODEL_PATH)
		return null

	var model_script: Variant = load(MODEL_PATH)
	if model_script == null:
		_failures.append("test_model_script_exists - failed to load %s" % MODEL_PATH)
	return model_script


func _test_map_has_25_cells(model: HexMapModel) -> void:
	var coords: Array[Vector2i] = model.get_all_coords()
	var seen: Dictionary = {}
	for coord: Vector2i in coords:
		seen[coord] = true
		_assert(model.is_valid_coord(coord), "test_map_has_25_cells", "generated invalid coord %s" % coord)

	_assert(coords.size() == 25, "test_map_has_25_cells", "expected 25 coords, got %d" % coords.size())
	_assert(seen.size() == 25, "test_map_has_25_cells", "expected 25 unique coords, got %d" % seen.size())


func _test_start_and_boss_corners(model: HexMapModel) -> void:
	var start_coord: Vector2i = model.get_start_coord()
	var boss_coord: Vector2i = model.get_boss_coord()

	_assert(start_coord == Vector2i(0, 0), "test_start_and_boss_corners", "expected start (0, 0), got %s" % start_coord)
	_assert(boss_coord == Vector2i(4, 4), "test_start_and_boss_corners", "expected boss (4, 4), got %s" % boss_coord)
	_assert(start_coord != boss_coord, "test_start_and_boss_corners", "start and boss must differ")
	_assert(model.is_valid_coord(start_coord), "test_start_and_boss_corners", "start coord must be valid")
	_assert(model.is_valid_coord(boss_coord), "test_start_and_boss_corners", "boss coord must be valid")


func _test_neighbors_are_bounded(model: HexMapModel) -> void:
	var corner_neighbors: Array[Vector2i] = model.get_neighbors(Vector2i(0, 0))

	_assert(corner_neighbors.has(Vector2i(1, 0)), "test_neighbors_are_bounded", "start should include east neighbor")
	_assert(corner_neighbors.has(Vector2i(0, 1)), "test_neighbors_are_bounded", "start should include south-east neighbor")
	_assert(not corner_neighbors.has(Vector2i(1, -1)), "test_neighbors_are_bounded", "start should exclude out-of-bounds north-east")

	for neighbor: Vector2i in corner_neighbors:
		_assert(model.is_valid_coord(neighbor), "test_neighbors_are_bounded", "neighbor must be in bounds: %s" % neighbor)


func _test_adjacent_move_updates_player_coord(model: HexMapModel) -> void:
	var player_coord := model.get_start_coord()
	var destination := Vector2i(1, 0)

	if model.are_adjacent(player_coord, destination) and model.is_valid_coord(destination):
		player_coord = destination

	_assert(player_coord == destination, "test_adjacent_move_updates_player_coord", "valid adjacent move should update player coord")


func _test_out_of_bounds_move_is_rejected(model: HexMapModel) -> void:
	var player_coord := model.get_start_coord()
	var destination := Vector2i(1, -1)

	if model.are_adjacent(player_coord, destination) and model.is_valid_coord(destination):
		player_coord = destination

	_assert(player_coord == model.get_start_coord(), "test_out_of_bounds_move_is_rejected", "out-of-bounds move should not update player coord")


func _test_non_adjacent_move_is_rejected(model: HexMapModel) -> void:
	var player_coord := model.get_start_coord()
	var destination := Vector2i(4, 4)

	if model.are_adjacent(player_coord, destination) and model.is_valid_coord(destination):
		player_coord = destination

	_assert(player_coord == model.get_start_coord(), "test_non_adjacent_move_is_rejected", "non-adjacent move should not update player coord")


func _test_path_to_boss_exists(model: HexMapModel) -> void:
	_assert(
		model.find_path_exists(model.get_start_coord(), model.get_boss_coord()),
		"test_path_to_boss_exists",
		"expected bounded adjacent path from start to boss"
	)


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := EXPECTED_TEST_COUNT - _failures.size()
	if _failures.is_empty():
		print("AC1.1 map logic tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.1 map logic tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
