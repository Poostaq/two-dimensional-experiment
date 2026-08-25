class_name WorldRuntimeSceneContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 8
const SCENE_PATH := "res://Scenes/world_map_runtime_preview.tscn"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(
        ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/game_world.tscn",
        "production main scene remains frozen"
    )
    _expect(ResourceLoader.exists(SCENE_PATH), "explicit non-production runtime scene exists")
    if not ResourceLoader.exists(SCENE_PATH):
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var runtime := packed.instantiate()
    _expect(runtime.has_method("get_runtime_snapshot"), "runtime scene exposes typed snapshot inspection")
    _expect(runtime.has_method("request_move"), "runtime scene exposes movement request boundary")
    _expect(runtime.has_method("get_valid_destinations"), "runtime scene exposes valid destinations")
    _expect(runtime.has_method("get_plan_instance_id"), "runtime scene exposes shared plan identity")
    _expect(runtime.has_method("get_world_camera"), "runtime scene exposes camera verification boundary")
    _expect(runtime.has_method("has_integration_failed"), "runtime scene exposes integration failure state")
    runtime.free()
    _finish()


func _expect(condition: bool, message: String) -> void:
    _assertions += 1
    if not condition:
        _failures.append(message)


func _finish() -> void:
    if _assertions != EXPECTED_TEST_COUNT:
        _failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
    if _failures.is_empty():
        print("World runtime scene contract tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)
