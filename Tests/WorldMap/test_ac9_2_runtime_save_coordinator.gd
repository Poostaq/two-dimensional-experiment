extends SceneTree

const COORDINATOR_PATH := "res://Scripts/WorldMap/world_runtime_save_coordinator.gd"
const START_SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const STATE_PATH := "res://Scripts/Run/world_run_state.gd"
const V7_CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v7.gd"
const WORLD_PLAN_PATH := "res://Scripts/WorldMap/world_plan.gd"

var _failures: int = 0
var _publish_count: int = 0


class FakeRepository:
    extends RefCounted

    var writes: Array[PackedByteArray] = []
    var durable_bytes: PackedByteArray = "durable-sentinel".to_utf8_buffer()


    func replace_atomic(bytes: PackedByteArray) -> Dictionary:
        writes.append(bytes.duplicate())
        durable_bytes = bytes.duplicate()
        return {"ok": true, "value": null, "error": null}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var started: Dictionary = load(START_SERVICE_PATH).new(
        func(_plan: RefCounted) -> void: pass,
        (load(GENERATOR_PATH) as GDScript).new()
    ).start("ac9-vector-1")
    _expect(started.get("ok", false), "fixture run starts")
    if not started.get("ok", false):
        _finish()
        return

    var repository := FakeRepository.new()
    var coordinator: RefCounted = load(COORDINATOR_PATH).new()
    var configured: bool = bool(coordinator.call(
        "configure",
        started.plan,
        started.resolved_seed,
        started.run_state,
        repository,
        started.selection,
        started.coalition
    ))
    _expect(configured, "coordinator accepts V7 selection and coalition")
    if not configured:
        _finish()
        return

    var state_data: Dictionary = started.run_state.to_dictionary()
    state_data["move_count"] = int(state_data["move_count"]) + 1
    var candidate_result: Dictionary = load(STATE_PATH).from_dictionary(
        state_data,
        started.plan
    )
    _expect(candidate_result.get("ok", false), "autosave candidate builds")
    if not candidate_result.get("ok", false):
        _finish()
        return

    var committed: Dictionary = coordinator.call(
        "commit_candidate",
        candidate_result.value,
        func(_state: RefCounted) -> void: pass,
        "accepted_move"
    )
    _expect(committed.get("ok", false), "autosave commits")
    _expect(repository.writes.size() == 1, "autosave writes exactly once")
    if repository.writes.size() == 1:
        var root: Variant = JSON.parse_string(repository.writes[0].get_string_from_utf8())
        _expect(root is Dictionary, "autosave is JSON")
        if root is Dictionary:
            _expect(root.get("save_version") == 7, "autosave remains V7")
            _expect(
                root.world.get("allied_clan_ids") == ["orc", "werewolf"],
                "autosave preserves canonical allied clans"
            )
        var decoded: Dictionary = load(V7_CODEC_PATH).decode_any(repository.writes[0])
        _expect(decoded.get("ok", false), "autosave decodes through V7")
        if decoded.get("ok", false):
            _expect(
                decoded.value.coalition.allied_clan_ids
                == started.coalition.allied_clan_ids,
                "autosave restores rather than rerolls coalition"
            )

    var v6_repository := FakeRepository.new()
    var v6_coordinator: RefCounted = load(COORDINATOR_PATH).new()
    _expect(
        bool(v6_coordinator.call(
            "configure",
            started.plan,
            started.resolved_seed,
            started.run_state,
            v6_repository,
            started.selection
        )),
        "selection-only coordinator configures"
    )
    var v6_commit: Dictionary = v6_coordinator.call(
        "commit_candidate",
        candidate_result.value,
        func(_state: RefCounted) -> void: pass,
        "accepted_move"
    )
    _expect(v6_commit.get("ok", false), "selection-only autosave commits")
    _expect(v6_repository.writes.size() == 1, "selection-only autosave writes once")
    if v6_repository.writes.size() == 1:
        var v6_root: Variant = JSON.parse_string(
            v6_repository.writes[0].get_string_from_utf8()
        )
        _expect(
            v6_root is Dictionary and v6_root.get("save_version") == 6,
            "selection-only autosave remains V6"
        )
        if v6_root is Dictionary:
            _expect(
                not v6_root.world.has("allied_clan_ids"),
                "selection-only autosave does not invent allies"
            )
    _test_invalid_v2_plan_does_not_replace_save()
    _finish()


func _test_invalid_v2_plan_does_not_replace_save() -> void:
    var started: Dictionary = load(START_SERVICE_PATH).new(
        func(_plan: RefCounted) -> void: pass
    ).start("invalid-v2-save")
    _expect(started.get("ok", false), "V2 save fixture starts")
    if not started.get("ok", false):
        return
    var source_plan: RefCounted = started.plan
    var invalid_plan: WorldPlan = load(WORLD_PLAN_PATH).new(
        source_plan.get_version(),
        source_plan.get_seed_hex(),
        source_plan.get_start_coord(),
        source_plan.get_boss_coord(),
        source_plan.get_cells(),
        source_plan.get_roads(),
        [],
        source_plan.get_habitats(),
        source_plan.get_towns()
    )
    var repository := FakeRepository.new()
    var durable_before: PackedByteArray = repository.durable_bytes.duplicate()
    var coordinator: RefCounted = load(COORDINATOR_PATH).new()
    _expect(
        coordinator.configure(
            invalid_plan,
            started.resolved_seed,
            started.run_state,
            repository,
            started.selection,
            started.coalition,
            started.enemy_boss_selection
        ),
        "coordinator accepts state before serialization gate"
    )
    _publish_count = 0
    var result: Dictionary = coordinator.commit_candidate(
        started.run_state,
        Callable(self, "_capture_publish"),
        "invalid-v2-plan"
    )
    _expect(not result.get("ok", true), "invalid V2 plan is not committed")
    _expect(repository.writes.is_empty(), "invalid V2 plan performs no replacement write")
    _expect(repository.durable_bytes == durable_before, "invalid V2 plan preserves durable bytes")
    _expect(_publish_count == 0, "invalid V2 plan is never published")
    _expect(not coordinator.is_input_blocked(), "serialization rejection leaves input unblocked")


func _capture_publish(_state: RefCounted) -> void:
    _publish_count += 1


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_ac9_2_runtime_save_coordinator")
    quit(1 if _failures > 0 else 0)
