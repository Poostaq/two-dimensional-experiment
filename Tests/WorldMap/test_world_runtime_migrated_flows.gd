class_name WorldRuntimeMigratedFlowContractTests
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
        "migrated flows do not cut over production"
    )
    _expect(ResourceLoader.exists(SCENE_PATH), "migrated flows have an explicit Stage 4 entry")
    if not ResourceLoader.exists(SCENE_PATH):
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var runtime := packed.instantiate()
    _expect(runtime.has_method("request_move"), "migrated movement has one request boundary")
    _expect(runtime.has_method("has_active_encounter"), "migrated encounter state is inspectable")
    _expect(runtime.has_method("close_active_encounter"), "migrated encounter close is explicit")
    _expect(runtime.has_method("has_active_battle"), "migrated battle state is inspectable")
    _expect(runtime.has_method("open_party_management"), "migrated Party flow is explicit")
    _expect(runtime.has_method("has_active_party_management"), "migrated Party state is inspectable")
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
        print("World runtime migrated flow contract tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)
