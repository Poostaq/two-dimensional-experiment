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
static var FAILURE_OVERLAY_SCENE: PackedScene = load(
    "res://Scenes/world_generation_failure_overlay.tscn"
)

var _screen: Screen = Screen.MAIN
var _start_service: RefCounted
var _repository: RefCounted
var _exit_adapter: RefCounted
var _world_factory: PackedScene
var _pending_seed: String = ""
var _failure_overlay: Control

@onready var _main_screen: Control = %MainScreen
@onready var _new_run_screen: Control = %NewRunScreen
@onready var _overwrite_screen: Control = %OverwriteScreen
@onready var _overwrite_dimmer: ColorRect = $OverwriteDimmer
@onready var _overwrite_center: CenterContainer = $OverwriteCenter
@onready var _continue_button: Button = %ContinueButton
@onready var _start_new_run_button: Button = %StartNewRunButton
@onready var _exit_button: Button = %ExitButton
@onready var _seed_input: LineEdit = %SeedInput
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton
@onready var _overwrite_confirm_button: Button = %OverwriteConfirmButton
@onready var _overwrite_cancel_button: Button = %OverwriteCancelButton
@onready var _failure_host: Control = %FailureHost
@onready var _world_host: Control = %WorldHost


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


func _ready() -> void:
    get_viewport().size_changed.connect(_fit_to_viewport)
    _fit_to_viewport()
    _continue_button.pressed.connect(on_continue_pressed)
    _start_new_run_button.pressed.connect(on_start_new_run_pressed)
    _exit_button.pressed.connect(on_exit_pressed)
    _start_button.pressed.connect(on_start_pressed)
    _back_button.pressed.connect(on_back_pressed)
    _overwrite_confirm_button.pressed.connect(on_overwrite_confirm_pressed)
    _overwrite_cancel_button.pressed.connect(on_overwrite_cancel_pressed)
    screen_changed.connect(_show_screen)
    session_ready.connect(_on_session_ready)
    launch_failed.connect(_on_launch_failed)
    _show_screen(int(_screen))
    _refresh_continue_button()


func _fit_to_viewport() -> void:
    position = Vector2.ZERO
    size = get_viewport_rect().size


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


func on_continue_pressed() -> void:
    continue_saved_run()


func on_start_new_run_pressed() -> void:
    open_new_run()


func on_exit_pressed() -> void:
    request_exit()


func on_start_pressed() -> void:
    request_start(_seed_input.text)


func on_back_pressed() -> void:
    back_to_main()


func on_overwrite_confirm_pressed() -> void:
    confirm_overwrite()


func on_overwrite_cancel_pressed() -> void:
    cancel_overwrite()


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


func _show_screen(screen: int) -> void:
    _main_screen.visible = screen == int(Screen.MAIN)
    _new_run_screen.visible = screen == int(Screen.NEW_RUN)
    var show_overwrite := screen == int(Screen.OVERWRITE_CONFIRM)
    _overwrite_screen.visible = show_overwrite
    _overwrite_dimmer.visible = show_overwrite
    _overwrite_center.visible = show_overwrite
    if screen == int(Screen.MAIN):
        _refresh_continue_button()
    elif screen == int(Screen.NEW_RUN):
        _seed_input.grab_focus()


func _refresh_continue_button() -> void:
    if not has_saved_run():
        _continue_button.disabled = true
        return
    var loaded: Dictionary = _repository.call("load_validated")
    _continue_button.disabled = not bool(loaded.get("ok", false))


func _on_session_ready(session: Dictionary) -> void:
    if _world_factory == null:
        return
    for child: Node in _world_host.get_children():
        child.queue_free()
    var world := _world_factory.instantiate()
    _world_host.add_child(world)
    if world.has_method("apply_session"):
        world.call("apply_session", session)


func _on_launch_failed(error: RefCounted) -> void:
    if not is_instance_valid(_failure_overlay):
        _failure_overlay = FAILURE_OVERLAY_SCENE.instantiate() as Control
        _failure_host.add_child(_failure_overlay)
    _failure_overlay.call("present", error, String(ProjectSettings.get_setting(
        "application/config/version", "development"
    )))


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
