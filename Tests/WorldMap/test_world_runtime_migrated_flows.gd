class_name WorldRuntimeMigratedFlowContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 2
const SCENE_PATH := "res://Scenes/world_map_runtime_preview.tscn"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(
        ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/game_world.tscn",
        "migrated flows do not cut over production"
    )
    _expect(ResourceLoader.exists(SCENE_PATH), "migrated flows have an explicit Stage 4 entry")
    _finish()


func _expect(condition: bool, message: String) -> void:
    _assertions += 1
    if not condition:
        _failures.append(message)


func _finish() -> void:
    if _assertions != EXPECTED_TEST_COUNT:
        _failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
    if _failures.is_empty():
        print("World runtime migrated flow contract tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)
