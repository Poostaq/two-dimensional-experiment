class_name WorldTurnCounterTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 4

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_turn_counter_starts_at_zero()
	await _test_accepted_move_increments_turn_counter_once()
	await _test_rejected_move_leaves_turn_counter_unchanged()
	await _test_set_run_id_resets_turn_counter_to_zero()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _test_turn_counter_starts_at_zero() -> void:
	var world := await _instantiate_world()
	var label := world.get_node_or_null("%TurnCounterLabel") as Label
	var layout_matches := is_instance_valid(label) \
		and label.text == "Turns: 0" \
		and label.offset_left == 16.0 \
		and label.offset_top == 16.0 \
		and label.offset_right == 136.0 \
		and label.offset_bottom == 48.0 \
		and label.get_theme_font_size("font_size") == 22
	_assert(layout_matches, "initial zero scene contract",
		"label must render Turns: 0 at offsets 16,16,136,48 with font size 22")
	_free_world(world)


func _test_accepted_move_increments_turn_counter_once() -> void:
	var world := await _instantiate_world()
	var moved := world.request_move(Vector2i(1, 0))
	_assert(moved and world.move_count == 1 and _counter_text(world) == "Turns: 1",
		"accepted move increment text", "one accepted move must render exactly one turn")
	_free_world(world)


func _test_rejected_move_leaves_turn_counter_unchanged() -> void:
	var world := await _instantiate_world()
	var moved := world.request_move(Vector2i(4, 4))
	_assert(not moved and world.move_count == 0 and _counter_text(world) == "Turns: 0",
		"rejected move unchanged text", "non-adjacent move must not mutate text")
	_free_world(world)


func _test_set_run_id_resets_turn_counter_to_zero() -> void:
	var world := await _instantiate_world()
	world.request_move(Vector2i(1, 0))
	world.set_run_id("counter-reset-run")
	_assert(world.move_count == 0 and _counter_text(world) == "Turns: 0",
		"set_run_id reset text", "run reset must reset model and label together")
	_free_world(world)


func _instantiate_world() -> MapController:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	var world := packed.instantiate() as MapController
	root.add_child(world)
	await process_frame
	await process_frame
	return world


func _counter_text(world: MapController) -> String:
	var label := world.get_node_or_null("%TurnCounterLabel") as Label
	return label.text if is_instance_valid(label) else "<missing>"


func _free_world(world: MapController) -> void:
	if is_instance_valid(world):
		world.close_active_encounter()
		world.exit_active_battle()
		world.queue_free()


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("World turn counter tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
