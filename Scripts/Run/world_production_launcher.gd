class_name WorldProductionLauncher
extends Control

signal screen_changed(screen: int)
signal session_ready(session: Dictionary)
signal launch_failed(error: RefCounted)

enum Screen {
    MAIN,
    NEW_RUN,
    OVERWRITE_CONFIRM,
}

static var START_SERVICE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_start_service.gd")
static var REPOSITORY_SCRIPT: GDScript = load("res://Scripts/Run/world_single_slot_repository.gd")
static var EXIT_ADAPTER_SCRIPT: GDScript = load("res://Scripts/Run/world_exit_adapter.gd")
static var SAVE_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_codec_v2.gd")

var _screen: Screen = Screen.MAIN
var _start_service: RefCounted
var _repository: RefCounted
var _exit_adapter: RefCounted
var _world_factory: PackedScene
var _pending_seed: String = ""


func _init(
    start_service: RefCounted = null,
    repository: RefCounted = null,
    exit_adapter: RefCounted = null,
    world_factory: PackedScene = null
) -> void:
    _start_service = (
        start_service
        if is_instance_valid(start_service)
        else START_SERVICE_SCRIPT.new(Callable(self, "_accept_generated_plan"))
    )
    _repository = repository if is_instance_valid(repository) else REPOSITORY_SCRIPT.new()
    _exit_adapter = exit_adapter if is_instance_valid(exit_adapter) else EXIT_ADAPTER_SCRIPT.new()
    _world_factory = world_factory


func get_screen() -> Screen:
    return _screen


func has_saved_run() -> bool:
    return bool(_repository.call("has_save"))


func open_new_run() -> void:
    _set_screen(Screen.NEW_RUN)


func back_to_main() -> void:
    _pending_seed = ""
    _set_screen(Screen.MAIN)


func request_start(seed_text: String) -> Dictionary:
    var resolved_seed := _resolve_seed(seed_text)
    if has_saved_run():
        _pending_seed = resolved_seed
        _set_screen(Screen.OVERWRITE_CONFIRM)
        return {
            "ok": false,
            "confirmation_required": true,
            "error": null,
        }
    return _create_and_persist(resolved_seed)


func confirm_overwrite() -> Dictionary:
    if _screen != Screen.OVERWRITE_CONFIRM or _pending_seed.is_empty():
        return {"ok": false, "confirmation_required": false, "error": null}
    var resolved_seed := _pending_seed
    _pending_seed = ""
    return _create_and_persist(resolved_seed)


func cancel_overwrite() -> void:
    _pending_seed = ""
    _set_screen(Screen.NEW_RUN)


func continue_saved_run() -> Dictionary:
    var loaded: Dictionary = _repository.call("load_validated")
    if not bool(loaded.get("ok", false)):
        _emit_failure(loaded.get("error") as RefCounted)
        _set_screen(Screen.MAIN)
        return loaded
    var session := loaded.get("value", {}) as Dictionary
    session_ready.emit(session)
    return {"ok": true, "value": session, "error": null}


func request_exit(tree: SceneTree = null) -> void:
    var target_tree := tree if tree != null else get_tree()
    _exit_adapter.call("request_exit", target_tree, 0)


func _create_and_persist(resolved_seed: String) -> Dictionary:
    var started: Dictionary = _start_service.call("start", resolved_seed)
    if not bool(started.get("ok", false)):
        _emit_failure(started.get("error") as RefCounted)
        _set_screen(Screen.NEW_RUN)
        return started
    var bytes: PackedByteArray = SAVE_CODEC_SCRIPT.encode(
        started.get("plan") as RefCounted,
        String(started.get("resolved_seed", resolved_seed)),
        started.get("run_state") as RefCounted
    )
    var saved: Dictionary = _repository.call("replace_atomic", bytes)
    if not bool(saved.get("ok", false)):
        _emit_failure(saved.get("error") as RefCounted)
        _set_screen(Screen.NEW_RUN)
        return saved
    var session := {
        "plan": started.get("plan"),
        "resolved_seed": String(started.get("resolved_seed", resolved_seed)),
        "run_state": started.get("run_state"),
    }
    session_ready.emit(session)
    return {"ok": true, "value": session, "error": null}


func _resolve_seed(seed_text: String) -> String:
    if not seed_text.is_empty():
        return seed_text
    return Crypto.new().generate_random_bytes(16).hex_encode()


func _set_screen(next_screen: Screen) -> void:
    if _screen == next_screen:
        return
    _screen = next_screen
    screen_changed.emit(int(_screen))


func _emit_failure(error: RefCounted) -> void:
    if is_instance_valid(error):
        launch_failed.emit(error)


func _accept_generated_plan(_plan: RefCounted) -> void:
    pass
