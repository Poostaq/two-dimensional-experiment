class_name TestAc11RuntimeStepCounts
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 8

var _failures: Array[String] = []
var _observations: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var packed_scene: PackedScene = load(GAME_WORLD_PATH) as PackedScene
	if packed_scene == null:
		_failures.append("Could not load %s" % GAME_WORLD_PATH)
		_finish()
		return

	var world: MapController = packed_scene.instantiate() as MapController
	if world == null:
		_failures.append("Could not instantiate GameWorld as MapController")
		_finish()
		return

	root.add_child(world)
	await process_frame

	_expect_state(world, "start", Vector2i(0, 0), 0)
	_expect_state(world, "boss objective", Vector2i(0, 0), 0)
	_assert_equal(world.boss_coord, Vector2i(4, 4), "boss objective should be opposite corner")

	var valid_moves: Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(0, 2),
		Vector2i(0, 3),
		Vector2i(0, 4),
		Vector2i(1, 4),
	]
	for index in valid_moves.size():
		var destination: Vector2i = valid_moves[index]
		_click_tile(world, destination)
		await process_frame
		_expect_state(world, "valid move %d" % (index + 1), destination, index + 1)
		_close_expected_encounter(world, "valid move %d" % (index + 1))

	var invalid_moves: Array[Vector2i] = [
		Vector2i(4, 0),
		Vector2i(4, 4),
	]
	for index in invalid_moves.size():
		var before_coord: Vector2i = world.player_coord
		var before_count: int = world.move_count
		_click_tile(world, invalid_moves[index])
		await process_frame
		_expect_state(world, "invalid non-adjacent move %d" % (index + 1), before_coord, before_count)

	var final_moves: Array[Vector2i] = [
		Vector2i(2, 4),
		Vector2i(3, 4),
		Vector2i(4, 4),
	]
	for index in final_moves.size():
		var destination: Vector2i = final_moves[index]
		_click_tile(world, destination)
		await process_frame
		_expect_state(world, "continued move %d" % (index + 1), destination, 6 + index)
		_close_expected_encounter(world, "continued move %d" % (index + 1))

	world.queue_free()
	_finish()


func _expect_state(world: MapController, label: String, expected_coord: Vector2i, expected_count: int) -> void:
	_assert_equal(world.player_coord, expected_coord, "%s player_coord" % label)
	_assert_equal(world.move_count, expected_count, "%s move_count" % label)
	_observations.append("%s: player_coord=%s move_count=%d" % [label, world.player_coord, world.move_count])


func _click_tile(world: MapController, destination: Vector2i) -> void:
	var tiles: Dictionary = world.get("_tiles")
	var tile: HexTileView = tiles.get(destination) as HexTileView
	if tile == null:
		_failures.append("Could not find tile %s" % destination)
		return

	var event := InputEventMouseButton.new()
	event.position = tile.get_global_transform_with_canvas() * Vector2.ZERO
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	tile._unhandled_input(event)


func _close_expected_encounter(world: MapController, label: String) -> void:
	if not world.has_active_encounter():
		_failures.append("%s expected active encounter after accepted move" % label)
		return
	world.close_active_encounter()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s; expected %s, got %s" % [message, expected, actual])


func _finish() -> void:
	for observation in _observations:
		print(observation)

	if _failures.is_empty():
		print("AC1.1 runtime step-count check: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("AC1.1 runtime step-count check: FAIL (%d failures)" % _failures.size())
	quit(1)
