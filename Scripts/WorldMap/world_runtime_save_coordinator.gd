class_name WorldRuntimeSaveCoordinator
extends RefCounted

static var SAVE_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_codec_v2.gd")
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")

var _plan: WorldPlan
var _resolved_seed: String = ""
var _repository: RefCounted
var _durable_state: RefCounted
var _pending_state: RefCounted
var _pending_bytes: PackedByteArray
var _pending_publish: Callable
var _input_blocked: bool = false


func configure(
    plan: WorldPlan,
    resolved_seed: String,
    durable_state: RefCounted,
    repository: RefCounted
) -> bool:
    if (
        not is_instance_valid(plan)
        or resolved_seed.is_empty()
        or not is_instance_valid(durable_state)
        or not durable_state.call("is_valid", plan)
        or not is_instance_valid(repository)
    ):
        return false
    _plan = plan
    _resolved_seed = resolved_seed
    _repository = repository
    _durable_state = _clone_state(durable_state)
    _clear_pending()
    return is_instance_valid(_durable_state)


func commit_candidate(
    candidate_state: RefCounted,
    publish: Callable,
    _event_name: String
) -> Dictionary:
    if _input_blocked or not is_instance_valid(_plan):
        return {"ok": false, "value": null, "error": null}
    if (
        not is_instance_valid(candidate_state)
        or not candidate_state.call("is_valid", _plan)
        or not publish.is_valid()
    ):
        return {"ok": false, "value": null, "error": null}
    var candidate_copy: RefCounted = _clone_state(candidate_state)
    var bytes: PackedByteArray = SAVE_CODEC_SCRIPT.encode(
        _plan,
        _resolved_seed,
        candidate_copy
    )
    if bytes.is_empty():
        return {"ok": false, "value": null, "error": null}
    var saved: Dictionary = _repository.call("replace_atomic", bytes)
    if not bool(saved.get("ok", false)):
        _pending_state = candidate_copy
        _pending_bytes = bytes.duplicate()
        _pending_publish = publish
        _input_blocked = true
        return saved
    _durable_state = candidate_copy
    publish.call(_clone_state(_durable_state))
    return {"ok": true, "value": _clone_state(_durable_state), "error": null}


func retry_pending() -> Dictionary:
    if (
        not _input_blocked
        or not is_instance_valid(_pending_state)
        or _pending_bytes.is_empty()
        or not _pending_publish.is_valid()
    ):
        return {"ok": false, "value": null, "error": null}
    var saved: Dictionary = _repository.call("replace_atomic", _pending_bytes)
    if not bool(saved.get("ok", false)):
        return saved
    _durable_state = _pending_state
    var publish := _pending_publish
    var published_copy := _clone_state(_durable_state)
    _clear_pending()
    publish.call(published_copy)
    return {"ok": true, "value": _clone_state(_durable_state), "error": null}


func discard_pending() -> RefCounted:
    if not _input_blocked:
        return _clone_state(_durable_state)
    _clear_pending()
    return _clone_state(_durable_state)


func is_input_blocked() -> bool:
    return _input_blocked


func get_durable_state() -> RefCounted:
    return _clone_state(_durable_state)


func _clone_state(state: RefCounted) -> RefCounted:
    if not is_instance_valid(state) or not is_instance_valid(_plan):
        return null
    var decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(
        state.call("to_dictionary"),
        _plan
    )
    if not bool(decoded.get("ok", false)):
        return null
    return decoded.get("value") as RefCounted


func _clear_pending() -> void:
    _pending_state = null
    _pending_bytes = PackedByteArray()
    _pending_publish = Callable()
    _input_blocked = false
