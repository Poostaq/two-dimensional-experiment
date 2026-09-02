extends SceneTree

const SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"

var _failures: int = 0
var _commit_count: int = 0
var _committed_plan: RefCounted


class GeneratorSpy:
    extends RefCounted

    var call_count: int = 0


    func generate(_seed_text: String, _config: Dictionary) -> Dictionary:
        call_count += 1
        return {}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var service_script: GDScript = load(SERVICE_PATH)
    if service_script == null:
        _fail("WorldRunStartService script is missing")
        _finish()
        return
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"))

    var success: Dictionary = service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"brakka_rustbanner"
    )
    _assert_true(success.get("ok", false), "successful run start")
    _assert_equal(_commit_count, 1, "success commits once")
    _assert_true(_committed_plan != null, "complete plan committed")
    if _committed_plan != null:
        _assert_equal(_committed_plan.get_cells().size(), 217, "committed cell count")
    if success.get("ok", false):
        var formation: Array[StringName] = success["run_state"].formation
        _assert_equal(formation[0], &"player_0", "left frontline starter retained")
        _assert_equal(formation[1], &"brakka_rustbanner", "Brakka occupies middle frontline")
        _assert_equal(formation[2], &"player_2", "right frontline starter retained")

    var generator_spy := GeneratorSpy.new()
    var rejecting_service: RefCounted = service_script.new(
        Callable(self, "_commit_plan"),
        generator_spy
    )
    var commits_before: int = _commit_count
    var invalid: Dictionary = rejecting_service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"unknown"
    )
    _assert_true(not invalid.get("ok", true), "unknown commander rejected")
    _assert_equal(generator_spy.call_count, 0, "invalid commander does not generate")
    _assert_equal(_commit_count, commits_before, "invalid commander does not commit")
    _assert_equal(invalid["error"].feature_namespace, "run-start", "invalid commander namespace")
    _assert_equal(
        invalid["error"].failed_constraint,
        "invalid_commander_id=unknown",
        "invalid commander constraint"
    )

    var before := {
        "save_bytes": PackedByteArray([1, 2, 3]),
        "history": 4,
        "roster": 5,
        "rewards": 6,
        "encounter": 7,
        "battle": 8,
        "published_cells": 217,
    }
    var snapshot: Dictionary = before.duplicate(true)
    var impossible := {
        "radius": 2,
        "town_count": 7,
        "town_min_distance": 4,
        "start": Vector2i(-2, 0),
        "boss": Vector2i(2, 0),
    }
    var failed: Dictionary = service.start("impossible", impossible, "RETURN_RESULT")
    _assert_true(not failed.get("ok", true), "failed run start")
    _assert_equal(failed["error"].code, "WORLD_CONSTRAINT_UNSATISFIABLE", "typed generation failure")
    _assert_equal(_commit_count, 1, "failure does not commit")
    _assert_equal(before, snapshot, "external state unchanged")

    var wrong_policy: Dictionary = service.start("golden-alpha", {}, "EXIT_PROCESS")
    _assert_true(not wrong_policy.get("ok", true), "service rejects process policy")
    _assert_equal(wrong_policy["error"].code, "WORLD_GENERATION_INTERNAL_ERROR", "policy failure code")
    _assert_equal(_commit_count, 1, "wrong policy does not commit")
    _finish()


func _commit_plan(plan: RefCounted) -> void:
    _commit_count += 1
    _committed_plan = plan


func _assert_true(value: bool, label: String) -> void:
    if not value:
        _fail(label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_start_service")
    quit(1 if _failures > 0 else 0)
