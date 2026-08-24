class_name WorldGenerationFailureOverlayTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_generation_failure_overlay.tscn"
const EXPECTED_TEST_COUNT := 12
const EXPECTED_MESSAGE := "World generation failed. The run was not started."
const EXPECTED_DIAGNOSTICS := "{\"event\":\"world_generation_failed\",\"code\":\"WORLD_CONSTRAINT_UNSATISFIABLE\",\"seed_hex\":\"696d706f737369626c65\",\"generator_version\":1,\"namespace\":\"town\",\"constraint\":\"town_count=7,min_distance=4,radius=2\",\"build_version\":\"dev-test\"}"

var _failures: Array[String] = []
var _assertions: int = 0
var _return_requested: bool = false
var _copied_diagnostics: String = ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "failure overlay scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var overlay := packed.instantiate() as Control
	get_root().add_child(overlay)
	await process_frame

	_expect(overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "overlay blocks pointer input")
	_expect(is_instance_valid(overlay.get_node_or_null("%FailureMessage")), "failure message exists")
	_expect(is_instance_valid(overlay.get_node_or_null("%ReturnButton")), "return button exists")
	_expect(is_instance_valid(overlay.get_node_or_null("%CopyDiagnosticsButton")), "copy diagnostics button exists")
	_expect((overlay.get_node("%FailureMessage") as Label).text == EXPECTED_MESSAGE, "failure message is exact")
	_expect(not overlay.visible, "overlay starts hidden")

	overlay.connect("return_requested", _on_return_requested)
	overlay.connect("diagnostics_copied", _on_diagnostics_copied)
	var error := WorldGenerationError.new(
		WorldGenerationError.WORLD_CONSTRAINT_UNSATISFIABLE,
		"696d706f737369626c65",
		1,
		"town",
		"town_count=7,min_distance=4,radius=2"
	)
	overlay.call("present", error, "dev-test")
	_expect(overlay.visible, "present shows the blocking overlay")
	_expect(String(overlay.call("get_diagnostics_text")) == EXPECTED_DIAGNOSTICS, "diagnostics use canonical formatter")

	(overlay.get_node("%CopyDiagnosticsButton") as Button).pressed.emit()
	_expect(_copied_diagnostics == EXPECTED_DIAGNOSTICS, "copy emits exact diagnostics")

	(overlay.get_node("%ReturnButton") as Button).pressed.emit()
	_expect(_return_requested, "return action emits")
	_expect(not overlay.visible, "return hides the overlay")

	overlay.queue_free()
	await process_frame
	_finish()


func _on_return_requested() -> void:
	_return_requested = true


func _on_diagnostics_copied(diagnostics: String) -> void:
	_copied_diagnostics = diagnostics


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("World generation failure overlay tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
