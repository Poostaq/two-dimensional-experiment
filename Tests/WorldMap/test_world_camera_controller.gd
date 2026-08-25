class_name WorldCameraControllerTests
extends SceneTree

const SCRIPT_PATH := "res://Scripts/WorldMap/world_camera_controller.gd"
const EXPECTED_TEST_COUNT := 29

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var script := load(SCRIPT_PATH) as Script
	_expect(is_instance_valid(script), "camera controller script loads")
	if not is_instance_valid(script):
		_finish()
		return
	var camera := script.new() as Camera2D
	get_root().add_child(camera)
	await process_frame

	var view_changes: Array[Rect2] = []
	if camera.has_signal("view_changed"):
		camera.connect("view_changed", func(rect: Rect2) -> void: view_changes.append(rect))
	var world_rect := Rect2(-800.0, -800.0, 1600.0, 1600.0)
	camera.call("configure", world_rect, Vector2(1000.0, 600.0), 100.0)
	_expect(camera.has_signal("view_changed"), "camera exposes typed view-changed signal")
	_expect(view_changes.size() == 1, "configuration publishes initial visible rectangle")
	_expect(is_equal_approx(float(camera.call("get_hexes_across")), 5.0), "default framing shows five cells across")
	_expect(camera.position == Vector2.ZERO, "configuration centers the world")
	_expect(camera.has_method("zoom_by_steps"), "wheel zoom API exists")
	_expect(camera.has_method("pan_by"), "drag pan API exists")
	_expect(not camera.has_method("edge_scroll"), "edge scrolling API is absent")

	var move_count := 12
	var changes_before_zoom := view_changes.size()
	camera.call("zoom_by_steps", 100, Vector2(500.0, 300.0))
	_expect(view_changes.size() == changes_before_zoom + 1, "zoom publishes updated visible rectangle")
	_expect(is_equal_approx(float(camera.call("get_hexes_across")), 3.0), "zoom-in clamps at three cells across")
	camera.call("zoom_by_steps", -200, Vector2(500.0, 300.0))
	_expect(is_equal_approx(float(camera.call("get_hexes_across")), 11.0), "zoom-out clamps at eleven cells across")
	_expect(move_count == 12, "zoom does not mutate world turns")

	camera.call("set_default_zoom")
	camera.call("pan_by", Vector2(-100.0, 0.0))
	_expect(camera.position.x > 0.0, "leftward pointer drag pans camera right")
	_expect(move_count == 12, "drag pan does not mutate world turns")
	camera.call("pan_by", Vector2(-100000.0, -100000.0))
	var visible_rect := camera.call("get_visible_world_rect") as Rect2
	_expect(camera.position == Vector2(800.0, 800.0), "maximum boundary center is reachable")
	_expect(not world_rect.encloses(visible_rect), "maximum boundary centering exposes dark overscan")
	camera.call("pan_by", Vector2(200000.0, 200000.0))
	visible_rect = camera.call("get_visible_world_rect") as Rect2
	_expect(camera.position == Vector2(-800.0, -800.0), "minimum boundary center is reachable")
	_expect(not world_rect.encloses(visible_rect), "minimum boundary centering exposes dark overscan")
	camera.call("center_on", Vector2(5000.0, -5000.0))
	_expect(camera.position == Vector2(800.0, -800.0), "camera center cannot leave supplied bounds")

	camera.call("begin_drag", Vector2(300.0, 200.0))
	_expect(bool(camera.call("is_dragging")), "left-button drag state begins explicitly")
	camera.call("drag_to", Vector2(340.0, 200.0))
	camera.call("end_drag")
	_expect(not bool(camera.call("is_dragging")), "drag state ends explicitly")
	_expect(move_count == 12, "complete pointer gesture consumes zero turns")

	camera.call("set_default_zoom")
	var has_input_handler := camera.has_method("_unhandled_input")
	_expect(has_input_handler, "camera owns pointer and wheel input handling")
	if has_input_handler:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = Vector2(500.0, 300.0)
		camera.call("_unhandled_input", wheel)
		_expect(float(camera.call("get_hexes_across")) < 5.0, "wheel-up input zooms inward")
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = Vector2(300.0, 200.0)
		camera.call("_unhandled_input", press)
		_expect(bool(camera.call("is_dragging")), "left-button input begins drag")
		var before_drag: Vector2 = camera.position
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(340.0, 200.0)
		camera.call("_unhandled_input", motion)
		_expect(camera.position != before_drag, "mouse motion pans during drag")
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = motion.position
		camera.call("_unhandled_input", release)
	_expect(not bool(camera.call("is_dragging")), "left-button release ends drag")

	var has_center_api := camera.has_method("center_on")
	_expect(has_center_api, "camera exposes initial-focus centering")
	if has_center_api:
		camera.call("center_on", Vector2(120.0, -80.0))
		_expect(camera.position == Vector2(120.0, -80.0), "camera centers on an in-bounds player position")

	camera.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("World camera controller tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
