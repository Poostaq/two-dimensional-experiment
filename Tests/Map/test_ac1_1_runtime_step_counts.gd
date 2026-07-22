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

	var valid_moves: Array[Dictionary] = [
		{"action": "map_move_se", "coord": Vector2i(0, 1)},
		{"action": "map_move_se", "coord": Vector2i(0, 2)},
		{"action": "map_move_se", "coord": Vector2i(0, 3)},
		{"action": "map_move_se", "coord": Vector2i(0, 4)},
		{"action": "map_move_e", "coord": Vector2i(1, 4)},
	]
	for index in valid_moves.size():
		var move: Dictionary = valid_moves[index]
		_send_action(String(move["action"]))
		await process_frame
		var destination: Vector2i = move["coord"]
		_expect_state(world, "valid move %d" % (index + 1), destination, index + 1)

	var invalid_moves: Array[String] = [
		"map_move_se",
		"map_move_sw",
	]
	for index in invalid_moves.size():
		var before_coord: Vector2i = world.player_coord
		var before_count: int = world.move_count
		_send_action(invalid_moves[index])
		await process_frame
		_expect_state(world, "invalid edge move %d" % (index + 1), before_coord, before_count)

	var final_moves: Array[Dictionary] = [
		{"action": "map_move_e", "coord": Vector2i(2, 4)},
		{"action": "map_move_e", "coord": Vector2i(3, 4)},
		{"action": "map_move_e", "coord": Vector2i(4, 4)},
	]
	for index in final_moves.size():
		var move: Dictionary = final_moves[index]
		_send_action(String(move["action"]))
		await process_frame
		var destination: Vector2i = move["coord"]
		_expect_state(world, "continued move %d" % (index + 1), destination, 6 + index)

	world.queue_free()
	_finish()


func _expect_state(world: MapController, label: String, expected_coord: Vector2i, expected_count: int) -> void:
	_assert_equal(world.player_coord, expected_coord, "%s player_coord" % label)
	_assert_equal(world.move_count, expected_count, "%s move_count" % label)
	_observations.append("%s: player_coord=%s move_count=%d" % [label, world.player_coord, world.move_count])


func _send_action(action_name: String) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)

	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)


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
