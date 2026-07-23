class_name Ac1_3MouseNavigationTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 6

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller: MapController = _instantiate_world()
	if controller != null:
		root.add_child(controller)
		await process_frame
		await process_frame

		_test_adjacent_left_click_moves_once(controller)
		_test_non_adjacent_left_click_is_rejected(controller)
		_test_off_map_left_click_is_ignored(controller)
		_test_right_click_is_ignored(controller)
		_test_keyboard_action_is_ignored(controller)
		_test_hover_feedback_transitions(controller)
		controller.queue_free()

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _instantiate_world() -> MapController:
	var packed_scene: PackedScene = load(GAME_WORLD_PATH) as PackedScene
	if packed_scene == null:
		_failures.append("test_game_world_loads - failed to load %s" % GAME_WORLD_PATH)
		return null
	return packed_scene.instantiate() as MapController


func _test_adjacent_left_click_moves_once(controller: MapController) -> void:
	var destination := Vector2i(0, 1)
	var before_count := controller.move_count
	if not _send_mouse_button_to_tile(controller, destination, MOUSE_BUTTON_LEFT):
		_failures.append("test_adjacent_left_click_moves_once - tile does not support pointer input")
		return

	_assert(
		controller.player_coord == destination and controller.move_count == before_count + 1,
		"test_adjacent_left_click_moves_once",
		"expected one move to %s, got coord=%s count=%d" % [destination, controller.player_coord, controller.move_count]
	)


func _test_non_adjacent_left_click_is_rejected(controller: MapController) -> void:
	var before_coord := controller.player_coord
	var before_count := controller.move_count
	if not _send_mouse_button_to_tile(controller, Vector2i(4, 4), MOUSE_BUTTON_LEFT):
		return

	_assert(
		controller.player_coord == before_coord and controller.move_count == before_count,
		"test_non_adjacent_left_click_is_rejected",
		"non-adjacent click changed coord or move count"
	)


func _test_right_click_is_ignored(controller: MapController) -> void:
	var before_coord := controller.player_coord
	var before_count := controller.move_count
	if not _send_mouse_button_to_tile(controller, Vector2i(0, 2), MOUSE_BUTTON_RIGHT):
		return

	_assert(
		controller.player_coord == before_coord and controller.move_count == before_count,
		"test_right_click_is_ignored",
		"right click changed coord or move count"
	)


func _test_off_map_left_click_is_ignored(controller: MapController) -> void:
	var before_coord := controller.player_coord
	var before_count := controller.move_count
	var event := InputEventMouseButton.new()
	event.position = Vector2(-1000.0, -1000.0)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	for tile: HexTileView in controller.get("_tiles").values():
		tile._unhandled_input(event)

	_assert(
		controller.player_coord == before_coord and controller.move_count == before_count,
		"test_off_map_left_click_is_ignored",
		"off-map click changed coord or move count"
	)


func _test_keyboard_action_is_ignored(controller: MapController) -> void:
	var before_coord := controller.player_coord
	var before_count := controller.move_count
	var event := InputEventAction.new()
	event.action = "map_move_se"
	event.pressed = true
	if controller.has_method("_unhandled_input"):
		controller._unhandled_input(event)

	_assert(
		controller.player_coord == before_coord and controller.move_count == before_count,
		"test_keyboard_action_is_ignored",
		"map_move_se remains an active movement path"
	)


func _test_hover_feedback_transitions(controller: MapController) -> void:
	var tile: Node = _get_tile(controller, Vector2i(1, 1))
	if tile == null or not tile.has_method("_unhandled_input") or not tile.has_signal("hover_changed"):
		_failures.append("test_hover_feedback_transitions - tile lacks hover input or signal")
		return

	var outline: Line2D = tile.get_node("Outline") as Line2D
	var default_width := outline.width
	var hover_states: Array[bool] = []
	tile.connect("hover_changed", func(_coord: Vector2i, is_hovered: bool) -> void: hover_states.append(is_hovered))

	var enter_event := InputEventMouseMotion.new()
	enter_event.position = tile.get_global_transform_with_canvas() * Vector2.ZERO
	tile._unhandled_input(enter_event)
	var hover_width := outline.width

	var exit_event := InputEventMouseMotion.new()
	exit_event.position = Vector2(-1000.0, -1000.0)
	tile._unhandled_input(exit_event)

	_assert(
		hover_states == [true, false] and hover_width > default_width and is_equal_approx(outline.width, default_width),
		"test_hover_feedback_transitions",
		"expected enter/exit signals and temporary outline widening"
	)


func _send_mouse_button_to_tile(controller: MapController, coord: Vector2i, button_index: MouseButton) -> bool:
	var tile: Node = _get_tile(controller, coord)
	if tile == null or not tile.has_method("_unhandled_input") or not tile.has_signal("tile_selected"):
		return false

	var event := InputEventMouseButton.new()
	event.position = tile.get_global_transform_with_canvas() * Vector2.ZERO
	event.button_index = button_index
	event.pressed = true
	tile._unhandled_input(event)
	return true


func _get_tile(controller: MapController, coord: Vector2i) -> Node:
	var tiles: Dictionary = controller.get("_tiles")
	if not tiles.has(coord):
		_failures.append("get_tile - missing coordinate %s" % coord)
		return null
	return tiles[coord] as Node


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := maxi(0, EXPECTED_TEST_COUNT - _failures.size())
	if _failures.is_empty():
		print("AC1.3 mouse navigation tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.3 mouse navigation tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
