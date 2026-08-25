class_name WorldRuntimeModelContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 68

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
    _expect(initial is WorldRuntimeSnapshot, "snapshot uses the typed public contract")
    _expect(initial != duplicate, "snapshots are defensive values")
    _expect(duplicate is WorldRuntimeSnapshot, "duplicate preserves snapshot type")
    _expect(initial.call("canonical_key") == duplicate.call("canonical_key"), "defensive snapshots are byte-equivalent")

    var key_before: String = initial.call("canonical_key")
    var rejected: RefCounted = model.call("request_move", Vector2i(8, 8))
    _expect(not bool(rejected.call("is_accepted")), "invalid destination is rejected")
    _expect(int(rejected.get("rejection")) == WorldMoveResult.Rejection.INVALID_DESTINATION, "invalid rejection is typed")
    _expect(rejected.get("snapshot").call("canonical_key") == key_before, "invalid result carries unchanged snapshot")
    _expect(model.call("get_snapshot").call("canonical_key") == key_before, "invalid rejection is atomic")

    model.call("set_surface_blocked", true)
    var blocked_before: String = model.call("get_snapshot").call("canonical_key")
    _expect(bool(model.call("get_snapshot").get("input_blocked")), "blocking state is explicit")
    rejected = model.call("request_move", Vector2i(-7, 0))
    _expect(not bool(rejected.call("is_accepted")), "blocked input is rejected")
    _expect(int(rejected.get("rejection")) == WorldMoveResult.Rejection.INPUT_BLOCKED, "blocked rejection is typed")
    _expect(rejected.get("snapshot").call("canonical_key") == blocked_before, "blocked result carries unchanged snapshot")
    _expect(model.call("get_snapshot").call("canonical_key") == blocked_before, "blocked rejection is atomic")
    _run_transaction_contract(model, key_before)
    model.call("reset")
    _expect(not model.call("get_valid_destinations").is_empty(), "configured runtime is usable before failed reconfiguration")
    _expect(not bool(model.call("configure", null)), "null plan is rejected")
    _expect(model.call("get_valid_destinations").is_empty(), "failed reconfiguration leaves no usable destinations")
    _expect(bool(model.call("get_snapshot").get("input_blocked")), "failed reconfiguration blocks runtime input")
    _finish()


func _run_transaction_contract(model: RefCounted, initial_key: String) -> void:
    _expect(model.has_method("get_valid_destinations"), "runtime exposes valid destinations")
    _expect(model.has_method("close_ordinary_encounter"), "runtime exposes ordinary encounter close")
    _expect(model.has_method("get_runtime_encounter_type"), "runtime exposes moving encounter identity")
    if not model.has_method("get_valid_destinations") or not model.has_method("close_ordinary_encounter") or not model.has_method("get_runtime_encounter_type"):
        return
    model.call("set_surface_blocked", false)
    var identical_before: String = model.call("get_snapshot").call("canonical_key")
    var identical: WorldMoveResult = model.call("request_move", Vector2i(-8, 0))
    _expect(identical.rejection == WorldMoveResult.Rejection.NOT_ADJACENT, "identical destination uses typed non-adjacent rejection")
    _expect(identical.snapshot.canonical_key() == identical_before, "identical result carries unchanged snapshot")
    _expect(model.call("get_snapshot").call("canonical_key") == identical_before, "identical rejection is atomic")
    var distant: WorldMoveResult = model.call("request_move", Vector2i(0, 0))
    _expect(distant.rejection == WorldMoveResult.Rejection.NOT_ADJACENT, "distant valid cell uses typed non-adjacent rejection")
    _expect(distant.snapshot.canonical_key() == identical_before, "distant result carries unchanged snapshot")
    _expect(model.call("get_snapshot").call("canonical_key") == identical_before, "distant rejection is atomic")
    var destinations: Array = model.call("get_valid_destinations")
    _expect(destinations.has(Vector2i(-7, 0)), "canonical neighbor is a valid destination")

    var route_ok := true
    for move_number: int in range(1, 30):
        var destination := Vector2i(-7, 0) if move_number % 2 == 1 else Vector2i(-8, 0)
        var result: RefCounted = model.call("request_move", destination)
        route_ok = route_ok and bool(result.call("is_accepted"))
        if move_number < 29:
            model.call("close_ordinary_encounter")
    _expect(route_ok, "moves 1 through 29 are accepted deterministically")
    _expect(model.call("get_snapshot").get("move_count") == 29, "accepted count reaches 29")
    model.call("close_ordinary_encounter")

    var move_30: RefCounted = model.call("request_move", Vector2i(-8, 0))
    _expect(move_30 is WorldMoveResult, "accepted move uses typed result contract")
    _expect(bool(move_30.call("is_accepted")), "move 30 is accepted")
    _expect(move_30.get("snapshot").get("move_count") == 30, "move 30 increments once")
    _expect(bool(move_30.get("snapshot").get("sudden_death_active")), "move 30 activates Sudden Death")
    _expect(not bool(move_30.get("boss_moved")), "move 30 does not move boss")
    _expect(move_30.get("snapshot").get("boss_coord") == Vector2i(8, 0), "boss remains at start on move 30")
    model.call("close_ordinary_encounter")

    var move_31: RefCounted = model.call("request_move", Vector2i(-8, 1))
    _expect(bool(move_31.call("is_accepted")), "move 31 is accepted")
    _expect(move_31.get("snapshot").get("move_count") == 31, "move 31 increments once")
    _expect(bool(move_31.get("boss_moved")), "move 31 moves boss exactly once")
    _expect(move_31.get("snapshot").get("boss_coord") == Vector2i(7, 0), "pursuit uses fixed neighbor tie-break")
    _expect(String(move_31.get("encounter_type")) != "boss", "unengaged move 31 opens ordinary encounter")
    _expect(
        move_31.get("snapshot").call("canonical_key") == model.call("get_snapshot").call("canonical_key"),
        "accepted result publishes authoritative snapshot"
    )
    var before_close: RefCounted = model.call("get_snapshot")
    model.call("close_ordinary_encounter")
    var after_close: RefCounted = model.call("get_snapshot")
    _expect(after_close.get("move_count") == before_close.get("move_count"), "encounter close consumes no move")
    _expect(after_close.get("boss_coord") == before_close.get("boss_coord"), "encounter close creates no boss step")
    _expect(not bool(after_close.get("input_blocked")), "ordinary encounter close unblocks input")
    _expect(model.call("get_runtime_encounter_type", Vector2i(8, 0)) == "safe", "vacated boss start resolves Safe")

    model.call("reset")
    _expect(model.call("get_snapshot").call("canonical_key") == initial_key, "reset restores canonical initial state")
    var direct_ok := true
    var direct_result: RefCounted
    for q: int in range(-7, 9):
        direct_result = model.call("request_move", Vector2i(q, 0))
        direct_ok = direct_ok and bool(direct_result.call("is_accepted"))
        if q < 8:
            model.call("close_ordinary_encounter")
    _expect(direct_ok, "direct adjacent route reaches boss")
    _expect(direct_result.get("encounter_type") == "boss", "player-initiated engagement opens Boss encounter")
    _expect(bool(direct_result.get("snapshot").get("boss_encounter_open")), "player engagement latches Boss encounter")
    var boss_rejected: RefCounted = model.call("request_move", Vector2i(7, 0))
    _expect(int(boss_rejected.get("rejection")) == 4, "Boss encounter blocks later movement")

    model.call("reset")
    for move_number: int in range(1, 31):
        var destination := Vector2i(-7, 0) if move_number % 2 == 1 else Vector2i(-8, 0)
        model.call("request_move", destination)
        model.call("close_ordinary_encounter")
    var boss_caught_player := false
    var later_counts_exact := true
    var later_steps_adjacent := true
    var later_steps_shorter := true
    var later_results_mark_move := true
    for pursuit_move: int in range(31, 61):
        var destination := Vector2i(-7, 0) if pursuit_move % 2 == 1 else Vector2i(-8, 0)
        var pursuit_before: WorldRuntimeSnapshot = model.call("get_snapshot")
        var pursuit_result: WorldMoveResult = model.call("request_move", destination)
        var pursuit_after: WorldRuntimeSnapshot = pursuit_result.snapshot
        later_counts_exact = later_counts_exact and pursuit_after.move_count == pursuit_before.move_count + 1
        later_steps_adjacent = later_steps_adjacent and HexWorldGeometry.get_hex_distance(pursuit_before.boss_coord, pursuit_after.boss_coord) == 1
        later_steps_shorter = later_steps_shorter and HexWorldGeometry.get_hex_distance(pursuit_after.boss_coord, destination) < HexWorldGeometry.get_hex_distance(pursuit_before.boss_coord, destination)
        later_results_mark_move = later_results_mark_move and pursuit_result.boss_moved
        if pursuit_result.encounter_type == "boss":
            boss_caught_player = true
            break
        model.call("close_ordinary_encounter")
    var caught_snapshot: WorldRuntimeSnapshot = model.call("get_snapshot")
    _expect(later_counts_exact, "every later pursuit transaction increments exactly once")
    _expect(later_steps_adjacent, "every later pursuit moves exactly one adjacent cell")
    _expect(later_steps_shorter, "every later pursuit step strictly reduces distance")
    _expect(later_results_mark_move, "every later pursuit result records one boss move")
    _expect(boss_caught_player, "boss-initiated pursuit reaches player")
    _expect(caught_snapshot.move_count >= 31, "boss engagement occurs after pursuit begins")
    _expect(caught_snapshot.boss_encounter_open, "boss-initiated engagement latches Boss encounter")
    var caught_key := caught_snapshot.canonical_key()
    var caught_rejection: WorldMoveResult = model.call("request_move", Vector2i(-7, 0))
    _expect(caught_rejection.rejection == WorldMoveResult.Rejection.BOSS_ENCOUNTER_OPEN, "boss-initiated engagement blocks later movement")
    _expect(caught_rejection.snapshot.canonical_key() == caught_key, "post-engagement rejection is atomic")


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
