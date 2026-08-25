class_name WorldRuntimeModelContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 18

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var snapshot_path := "res://Scripts/WorldMap/world_runtime_snapshot.gd"
    var result_path := "res://Scripts/WorldMap/world_move_result.gd"
    var model_path := "res://Scripts/WorldMap/world_runtime_model.gd"
    _expect(ResourceLoader.exists(snapshot_path), "runtime snapshot value exists")
    _expect(ResourceLoader.exists(result_path), "typed move result exists")
    _expect(ResourceLoader.exists(model_path), "pure runtime model exists")
    if not ResourceLoader.exists(snapshot_path) or not ResourceLoader.exists(result_path) or not ResourceLoader.exists(model_path):
        _finish()
        return

    var generator: RefCounted = load("res://Scripts/WorldMap/hex_world_generator_v1.gd").new()
    var generated: Dictionary = generator.call("generate", "golden-alpha")
    _expect(bool(generated.get("ok", false)), "golden plan generates")
    var model: RefCounted = load(model_path).new()
    _expect(bool(model.call("configure", generated.get("plan"))), "valid plan configures runtime")
    var initial: RefCounted = model.call("get_snapshot")
    _expect(initial.get("player_coord") == Vector2i(-8, 0), "player starts at canonical corner")
    _expect(initial.get("boss_coord") == Vector2i(8, 0), "boss starts at canonical corner")
    _expect(initial.get("move_count") == 0, "accepted count starts at zero")
    _expect(not bool(initial.get("sudden_death_active")), "boss starts dormant")
    var duplicate: RefCounted = model.call("get_snapshot")
    _expect(initial != duplicate, "snapshots are defensive values")
    _expect(initial.call("canonical_key") == duplicate.call("canonical_key"), "defensive snapshots are byte-equivalent")

    var key_before: String = initial.call("canonical_key")
    var rejected: RefCounted = model.call("request_move", Vector2i(8, 8))
    _expect(not bool(rejected.call("is_accepted")), "invalid destination is rejected")
    _expect(model.call("get_snapshot").call("canonical_key") == key_before, "invalid rejection is atomic")

    model.call("set_surface_blocked", true)
    var blocked_before: String = model.call("get_snapshot").call("canonical_key")
    _expect(bool(model.call("get_snapshot").get("input_blocked")), "blocking state is explicit")
    rejected = model.call("request_move", Vector2i(-7, 0))
    _expect(not bool(rejected.call("is_accepted")), "blocked input is rejected")
    _expect(int(rejected.get("rejection")) == 1, "blocked rejection is typed")
    _expect(model.call("get_snapshot").call("canonical_key") == blocked_before, "blocked rejection is atomic")
    _expect(not bool(model.call("configure", null)), "null plan is rejected")
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
