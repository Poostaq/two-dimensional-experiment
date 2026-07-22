class_name TestNavigationHelpUi
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 4
const EXPECTED_LABELS := {
	"KeyNW": "Q",
	"KeyNE": "W",
	"KeyE": "E",
	"KeyW": "A",
	"KeySW": "S",
	"KeySE": "D",
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node = _instantiate_world()
	if world != null:
		root.add_child(world)
		await process_frame
		await process_frame
		_test_help_overlay_exists(world)
		_test_help_overlay_has_center_hex(world)
		_test_help_overlay_has_direction_labels(world)
		_test_help_overlay_does_not_capture_input(world)
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


func _get_help(world: Node) -> Control:
	if not world.has_node("UI/NavigationHelp"):
		return null
	return world.get_node("UI/NavigationHelp") as Control


func _test_help_overlay_exists(world: Node) -> void:
	var help: Control = _get_help(world)
	_assert(help != null, "test_help_overlay_exists", "expected UI/NavigationHelp control")
	if help == null:
		return
	_assert(help.visible, "test_help_overlay_exists", "navigation help should be visible")


func _test_help_overlay_has_center_hex(world: Node) -> void:
	var help: Control = _get_help(world)
	if help == null:
		_failures.append("test_help_overlay_has_center_hex - missing UI/NavigationHelp")
		return

	_assert(help.has_node("HexDiagram/CenterHex"), "test_help_overlay_has_center_hex", "expected HexDiagram/CenterHex")
	var center_hex: Label = help.get_node("HexDiagram/CenterHex") as Label
	_assert(center_hex != null, "test_help_overlay_has_center_hex", "CenterHex should be a Label")
	if center_hex != null:
		_assert(center_hex.text == "HEX", "test_help_overlay_has_center_hex", "expected center label HEX, got %s" % center_hex.text)


func _test_help_overlay_has_direction_labels(world: Node) -> void:
	var help: Control = _get_help(world)
	if help == null:
		_failures.append("test_help_overlay_has_direction_labels - missing UI/NavigationHelp")
		return

	for label_name: String in EXPECTED_LABELS.keys():
		var path := "HexDiagram/%s" % label_name
		_assert(help.has_node(path), "test_help_overlay_has_direction_labels", "missing %s" % path)
		if help.has_node(path):
			var label: Label = help.get_node(path) as Label
			_assert(label != null, "test_help_overlay_has_direction_labels", "%s should be a Label" % path)
			if label != null:
				_assert(label.text == EXPECTED_LABELS[label_name], "test_help_overlay_has_direction_labels", "expected %s text %s, got %s" % [label_name, EXPECTED_LABELS[label_name], label.text])


func _test_help_overlay_does_not_capture_input(world: Node) -> void:
	var help: Control = _get_help(world)
	if help == null:
		_failures.append("test_help_overlay_does_not_capture_input - missing UI/NavigationHelp")
		return
	_assert(help.mouse_filter == Control.MOUSE_FILTER_IGNORE, "test_help_overlay_does_not_capture_input", "navigation help should ignore mouse input")


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := EXPECTED_TEST_COUNT - _failures.size()
	if _failures.is_empty():
		print("Navigation help UI tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("Navigation help UI tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
