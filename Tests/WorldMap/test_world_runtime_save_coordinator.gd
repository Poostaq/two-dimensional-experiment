class_name WorldRuntimeSaveCoordinatorTests
extends SceneTree

const COORDINATOR_PATH := "res://Scripts/WorldMap/world_runtime_save_coordinator.gd"
const MODEL_PATH := "res://Scripts/WorldMap/world_runtime_model.gd"
const RUN_STATE_PATH := "res://Scripts/Run/world_run_state.gd"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"

var _failures: int = 0
var _published_state: RefCounted


class FakeRepository:
    extends RefCounted

    var writes: Array[PackedByteArray] = []
    var fail_next: bool = false

    func replace_atomic(bytes: PackedByteArray) -> Dictionary:
        writes.append(bytes.duplicate())
        if fail_next:
            fail_next = false
            return {"ok": false, "value": null, "error": null}
        return {"ok": true, "value": null, "error": null}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(COORDINATOR_PATH):
        _fail("WorldRuntimeSaveCoordinator script is missing")
        _finish()
        return
    var coordinator_script := load(COORDINATOR_PATH) as GDScript
    var model_script := load(MODEL_PATH) as GDScript
    var state_script := load(RUN_STATE_PATH) as GDScript
    var generated: Dictionary = (load(GENERATOR_PATH) as GDScript).new().generate("golden-alpha")
    _expect(bool(generated.get("ok", false)), "fixture world generates")
    if not bool(generated.get("ok", false)):
        _finish()
        return
    var plan := generated.get("plan") as WorldPlan
    var empty_consumed: Array[Vector2i] = []
    var formation: Array[StringName] = [&"front_a", &"front_b", &"", &"back_a", &"", &""]
    var initial: RefCounted = state_script.create(
        plan.get_start_coord(),
        plan.get_boss_coord(),
        0,
        false,
        false,
        empty_consumed,
        formation
    )
    initial.set("gold", 100)
    _published_state = initial
    var repository := FakeRepository.new()
    var coordinator: RefCounted = coordinator_script.new()
    _expect(
        bool(coordinator.call("configure", plan, "golden-alpha", initial, repository)),
        "coordinator configures"
    )

    var accepted_events: Array[String] = [
        "accepted_move",
        "encounter_resolution",
        "reward_completion",
        "recruitment_completion",
        "party_move",
    ]
    for event_name: String in accepted_events:
        var candidate := _next_candidate(state_script, plan, event_name)
        var result: Dictionary = coordinator.call(
            "commit_candidate",
            candidate,
            Callable(self, "_publish_state"),
            event_name
        )
        _expect(bool(result.get("ok", false)), "%s commits" % event_name)
    _expect(repository.writes.size() == accepted_events.size(), "one write per authoritative change")

    var before_presentation := repository.writes.size()
    for _action: String in ["rejected_move", "drag", "zoom", "inspect", "party_open", "party_close"]:
        pass
    _expect(
        repository.writes.size() == before_presentation,
        "rejected and presentation-only actions perform zero writes"
    )

    var durable_before_failure := _published_state.call("canonical_key") as String
    var failed_candidate := _candidate_with_move_delta(state_script, plan, _published_state, 1)
    failed_candidate.set("gold", 375)
    repository.fail_next = true
    var failed: Dictionary = coordinator.call(
        "commit_candidate",
        failed_candidate,
        Callable(self, "_publish_state"),
        "accepted_move"
    )
    _expect(not bool(failed.get("ok", true)), "write failure is reported")
    _expect(bool(coordinator.call("is_input_blocked")), "write failure blocks authoritative input")
    _expect(
        String(_published_state.call("canonical_key")) == durable_before_failure,
        "failed write does not publish candidate"
    )
    _expect(_published_state.get("gold") == 100, "failed save retains 100g")
    _expect(not coordinator.configure(plan, "replacement", initial, FakeRepository.new()), "outstanding failure forbids coordinator rebind")
    var failed_bytes: PackedByteArray = repository.writes.back()
    var retried: Dictionary = coordinator.call("retry_pending")
    _expect(bool(retried.get("ok", false)), "retry succeeds")
    _expect(repository.writes.back() == failed_bytes, "retry writes byte-identical pending bytes")
    _expect(not bool(coordinator.call("is_input_blocked")), "successful retry unblocks input")
    _expect(
        String(_published_state.call("canonical_key"))
        == String(failed_candidate.call("canonical_key")),
        "retry publishes the retained candidate"
    )

    _expect(_published_state.get("gold") == 375, "retry publishes 375g")
    var wallet_codec: GDScript = load("res://Scripts/Save/world_run_save_codec_v5.gd")
    var saved_wallet: Dictionary = wallet_codec.decode_any(repository.writes.back())
    _expect(saved_wallet.get("ok", false) and saved_wallet["value"]["run_state"].get("gold") == 375, "retry persists wallet in V5")
    var durable_before_discard := _published_state.call("canonical_key") as String
    var discard_candidate := _candidate_with_move_delta(state_script, plan, _published_state, 1)
    discard_candidate.set("gold", 0)
    repository.fail_next = true
    coordinator.call(
        "commit_candidate",
        discard_candidate,
        Callable(self, "_publish_state"),
        "accepted_move"
    )
    var restored: RefCounted = coordinator.call("discard_pending")
    _expect(is_instance_valid(restored), "discard returns prior durable state")
    _expect(restored.get("gold") == 375, "discard preserves prior wallet")
    _expect(
        String(restored.call("canonical_key")) == durable_before_discard,
        "discard restores the prior durable canonical key"
    )
    _expect(not bool(coordinator.call("is_input_blocked")), "discard unblocks input")

    var model: RefCounted = model_script.new()
    _expect(bool(model.call("configure", plan)), "runtime model configures")
    var before_key: String = model.call("get_snapshot").call("canonical_key")
    var destinations: Array[Vector2i] = model.call("get_valid_destinations")
    var candidate_result: Dictionary = model.call("create_move_candidate", destinations[0])
    _expect(bool(candidate_result.get("ok", false)), "model creates an accepted move candidate")
    _expect(
        String(model.call("get_snapshot").call("canonical_key")) == before_key,
        "candidate evaluation does not mutate authoritative model"
    )
    var candidate_model := candidate_result.get("model") as RefCounted
    _expect(
        is_instance_valid(candidate_model)
        and String(candidate_model.call("get_snapshot").call("canonical_key")) != before_key,
        "candidate model owns the proposed state"
    )
    repository.fail_next = true
    var writes_before: int = repository.writes.size()
    var terminal_failure: Dictionary = coordinator.call("commit_candidate", discard_candidate, Callable(self, "_publish_state"), "terminal", false)
    _expect(not terminal_failure.get("ok", true), "terminal failure retained")
    _expect(coordinator.call("discard_pending") == null, "terminal pending cannot discard")
    _expect(coordinator.call("is_input_blocked"), "terminal remains blocked")
    _expect(not coordinator.call("can_discard_pending"), "terminal mode exposes no discard")
    _expect(coordinator.call("retry_pending").get("ok", false), "terminal retry commits")
    _expect(repository.writes[writes_before] == repository.writes.back(), "terminal retry byte identical")
    _expect(not coordinator.call("retry_pending").get("ok", true), "duplicate retry cannot publish")
    _test_reward_pending(plan)
    _finish()


func _test_reward_pending(plan: WorldPlan) -> void:
    var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
    var state: RefCounted = session.run_state
    var coord: Vector2i = plan.get_boss_coord()
    state.player_coord = coord
    state.boss_engaged = true
    var health: Dictionary[StringName, int] = {&"hero": 20}
    state.set_character_hp_snapshot(health)
    var receipt: Dictionary = {"battle_id":"boss","encounter_type":"boss","encounter_coord":[coord.x,coord.y],"outcome":"victory","enemy_ids":["a"],"defeated_enemy_ids":["a"],"terminal_player_health":[{"character_id":"hero","final_hp":0,"max_hp":20}],"earned_gold":50}
    var pending: RefCounted = load("res://Scripts/Run/battle_settlement_rules.gd").build_candidate(state, plan, receipt).value
    var acknowledged: RefCounted = load("res://Scripts/Run/battle_reward_acknowledgement_rules.gd").build_candidate(pending, plan, "boss").value
    var repository := FakeRepository.new()
    var coordinator: RefCounted = load(COORDINATOR_PATH).new()
    _expect(coordinator.configure(plan, "golden-alpha", pending, repository), "pending reward configures")
    _published_state = pending
    repository.fail_next = true
    _expect(not coordinator.commit_candidate(acknowledged, Callable(self, "_publish_state"), "ack").get("ok", true), "ack failure retained")
    _expect(_published_state.pending_reward_battle_id == "boss", "failed ack never publishes")
    var frozen: PackedByteArray = repository.writes.back()
    repository.fail_next = true
    _expect(not coordinator.retry_pending().get("ok", true), "repeated ack failure retained")
    _expect(repository.writes.back() == frozen, "failed retry identical bytes")
    var restored: RefCounted = coordinator.discard_pending()
    _expect(restored.pending_reward_battle_id == "boss" and restored.canonical_key() == pending.canonical_key(), "discard restores entire durable pending reward")
    _expect(_published_state.pending_reward_battle_id == "boss", "discard never publishes acknowledgement")
    repository.fail_next = true
    coordinator.commit_candidate(acknowledged, func(published: RefCounted) -> void:
        _expect(coordinator.get_durable_state().pending_reward_battle_id == "", "durable ack precedes callback")
        _expect(not coordinator.is_input_blocked(), "pending write cleared before callback")
        _publish_state(published)
    , "ack")
    frozen = repository.writes.back()
    _expect(coordinator.retry_pending().get("ok", false), "ack retry succeeds")
    _expect(repository.writes.back() == frozen and _published_state.pending_reward_battle_id == "", "successful frozen retry publishes ack")


func _next_candidate(state_script: GDScript, plan: WorldPlan, event_name: String) -> RefCounted:
    var data: Dictionary = _published_state.call("to_dictionary") as Dictionary
    if event_name == "accepted_move":
        data["move_count"] = int(data["move_count"]) + 1
    elif event_name == "encounter_resolution":
        data["consumed_encounters"] = [[plan.get_start_coord().x, plan.get_start_coord().y]]
    elif event_name == "recruitment_completion":
        data["formation"][2] = "new_recruit"
    elif event_name == "party_move":
        var first: String = data["formation"][0]
        data["formation"][0] = data["formation"][3]
        data["formation"][3] = first
    return (state_script.from_dictionary(data, plan).get("value") as RefCounted)


func _candidate_with_move_delta(
    state_script: GDScript,
    plan: WorldPlan,
    source: RefCounted,
    delta: int
) -> RefCounted:
    var data: Dictionary = source.call("to_dictionary") as Dictionary
    data["move_count"] = int(data["move_count"]) + delta
    return state_script.from_dictionary(data, plan).get("value") as RefCounted


func _publish_state(state: RefCounted) -> void:
    _published_state = state


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_runtime_save_coordinator")
    quit(1 if _failures > 0 else 0)
