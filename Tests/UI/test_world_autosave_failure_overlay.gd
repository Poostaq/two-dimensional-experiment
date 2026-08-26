class_name WorldAutosaveFailureOverlayTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_autosave_failure_overlay.tscn"
const ERROR_PATH := "res://Scripts/Save/world_save_error.gd"

var _failures: int = 0
var _retry_count: int = 0
var _return_count: int = 0
var _copy_count: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(SCENE_PATH):
        _fail("autosave failure overlay scene is missing")
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var overlay := packed.instantiate() as Control
    root.add_child(overlay)
    await process_frame
    _expect(overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "overlay blocks pointer input")
    _expect(is_instance_valid(overlay.get_node_or_null("%RetryButton")), "Retry action exists")
    _expect(is_instance_valid(overlay.get_node_or_null("%ReturnButton")), "Return action exists")
    _expect(is_instance_valid(overlay.get_node_or_null("%CopyButton")), "Copy action exists")
    overlay.connect("retry_requested", Callable(self, "_on_retry"))
    overlay.connect("return_requested", Callable(self, "_on_return"))
    overlay.connect("diagnostics_copied", Callable(self, "_on_copy"))
    var error_script := load(ERROR_PATH) as GDScript
    var error: RefCounted = error_script.new(
        error_script.SAVE_ENVELOPE_INVALID, "publish_temp"
    )
    overlay.call("present", error, "stage5-test")
    _expect(overlay.visible, "present shows the blocking overlay")
    (overlay.get_node("%RetryButton") as Button).pressed.emit()
    (overlay.get_node("%ReturnButton") as Button).pressed.emit()
    (overlay.get_node("%CopyButton") as Button).pressed.emit()
    _expect(_retry_count == 1, "Retry emits exactly once")
    _expect(_return_count == 1, "Return emits exactly once")
    _expect(_copy_count == 1, "Copy emits exactly once")
    overlay.queue_free()
    await process_frame
    _finish()


func _on_retry() -> void:
    _retry_count += 1


func _on_return() -> void:
    _return_count += 1


func _on_copy(_diagnostics: String) -> void:
    _copy_count += 1


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_autosave_failure_overlay")
    quit(1 if _failures > 0 else 0)
