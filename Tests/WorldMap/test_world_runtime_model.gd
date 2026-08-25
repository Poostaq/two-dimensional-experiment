class_name WorldRuntimeModelContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 3

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(
        ResourceLoader.exists("res://Scripts/WorldMap/world_runtime_snapshot.gd"),
        "runtime snapshot value exists"
    )
    _expect(
        ResourceLoader.exists("res://Scripts/WorldMap/world_move_result.gd"),
        "typed move result exists"
    )
    _expect(
        ResourceLoader.exists("res://Scripts/WorldMap/world_runtime_model.gd"),
        "pure runtime model exists"
    )
    _finish()


func _expect(condition: bool, message: String) -> void:
    _assertions += 1
    if not condition:
        _failures.append(message)


func _finish() -> void:
    if _assertions != EXPECTED_TEST_COUNT:
        _failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
    if _failures.is_empty():
        print("World runtime model contract tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)
