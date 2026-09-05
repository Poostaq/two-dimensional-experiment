class_name WorldProductionLauncher
extends Control

signal screen_changed(screen: int)
signal session_ready(session: Dictionary)
signal launch_failed(error: RefCounted)

enum Screen {
    MAIN,
    NEW_RUN,
    SETTINGS,
    OVERWRITE_CONFIRM,
}

const TOOLTIP_WIDTH: float = 340.0
const TOOLTIP_OFFSET := Vector2(10.0, 8.0)
const TOOLTIP_VIEWPORT_MARGIN: float = 8.0
const TOOLTIP_HIDE_DELAY_SECONDS: float = 0.1

static var START_SERVICE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_start_service.gd")
static var REPOSITORY_SCRIPT: GDScript = load("res://Scripts/Run/world_single_slot_repository.gd")
static var EXIT_ADAPTER_SCRIPT: GDScript = load("res://Scripts/Run/world_exit_adapter.gd")
static var SAVE_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_codec_v2.gd")
static var DISPLAY_SETTINGS_SCRIPT: GDScript = load(
    "res://Scripts/Settings/display_settings_service.gd"
)
static var FAILURE_OVERLAY_SCENE: PackedScene = load(
    "res://Scenes/world_generation_failure_overlay.tscn"
)
static var WORLD_SCENE: PackedScene = load("res://Scenes/world_map_runtime.tscn")
static var WORLD_ERROR_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_generation_error.gd"
)

var _screen: Screen = Screen.MAIN
var _start_service: RefCounted
var _repository: RefCounted
var _exit_adapter: RefCounted
var _world_factory: PackedScene
var _display_settings: RefCounted
var _settings_return_screen: Screen = Screen.MAIN
var _settings_load_status: StringName = &"missing"
var _pending_seed: String = ""
var _commander_ids: Array[StringName] = GoblinCommanderCatalog.get_commander_ids()
var _selected_commander_index: int = 0
var _pending_commander_id: StringName = &""
var _failure_overlay: Control
var _presented_commander_skills: Array[CharacterSkill] = []
var _active_tooltip_target: Control
var _active_tooltip_target_mouse_inside: bool = false
var _commander_skill_tooltip_mouse_inside: bool = false
var _tooltip_hide_request_id: int = 0

@onready var _background: ColorRect = $Background
@onready var _main_center: CenterContainer = $MainCenter
@onready var _new_run_center: CenterContainer = $NewRunCenter
@onready var _settings_center: CenterContainer = $SettingsCenter
@onready var _main_screen: Control = %MainScreen
@onready var _new_run_screen: Control = %NewRunScreen
@onready var _overwrite_screen: Control = %OverwriteScreen
@onready var _overwrite_dimmer: ColorRect = $OverwriteDimmer
@onready var _overwrite_center: CenterContainer = $OverwriteCenter
@onready var _continue_button: Button = %ContinueButton
@onready var _start_new_run_button: Button = %StartNewRunButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton
@onready var _settings_screen: Control = %SettingsScreen
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _display_mode_option: OptionButton = %DisplayModeOption
@onready var _apply_settings_button: Button = %ApplySettingsButton
@onready var _back_settings_button: Button = %BackSettingsButton
@onready var _settings_status_label: Label = %SettingsStatusLabel
@onready var _seed_input: LineEdit = %SeedInput
@onready var _begin_button: Button = %BeginButton
@onready var _back_button: Button = %BackButton
@onready var _previous_commander_button: Button = %PreviousCommanderButton
@onready var _next_commander_button: Button = %NextCommanderButton
@onready var _commander_portrait: TextureRect = %CommanderPortrait
@onready var _commander_name_label: Label = %CommanderNameLabel
@onready var _commander_title_label: Label = %CommanderTitleLabel
@onready var _commander_summary_label: Label = %CommanderSummaryLabel
@onready var _commander_root_class_label: Label = %CommanderRootClassLabel
@onready var _commander_skill_buttons: Array[Button] = [
    %CommanderSkill0,
    %CommanderSkill1,
    %CommanderSkill2,
    %CommanderSkill3,
]
@onready var _commander_skill_tooltip: PanelContainer = %CommanderSkillTooltip
@onready var _commander_skill_tooltip_name: Label = %CommanderSkillTooltipName
@onready var _commander_skill_tooltip_body: Label = %CommanderSkillTooltipBody
@onready var _overwrite_confirm_button: Button = %OverwriteConfirmButton
@onready var _overwrite_cancel_button: Button = %OverwriteCancelButton
@onready var _failure_host: Control = %FailureHost
@onready var _world_host: Control = %WorldHost


func _init(
    start_service: RefCounted = null,
    repository: RefCounted = null,
    exit_adapter: RefCounted = null,
    world_factory: PackedScene = null,
    display_settings: RefCounted = null
) -> void:
    _start_service = (
        start_service
        if is_instance_valid(start_service)
        else START_SERVICE_SCRIPT.new(Callable(self, "_accept_generated_plan"))
    )
    _repository = repository if is_instance_valid(repository) else REPOSITORY_SCRIPT.new()
    _exit_adapter = exit_adapter if is_instance_valid(exit_adapter) else EXIT_ADAPTER_SCRIPT.new()
    _world_factory = world_factory if world_factory != null else WORLD_SCENE
    _display_settings = (
        display_settings
        if is_instance_valid(display_settings)
        else DISPLAY_SETTINGS_SCRIPT.new()
    )


func _ready() -> void:
    var display_load: Dictionary = _display_settings.call("load_and_apply")
    _settings_load_status = display_load.get("load_status", &"defaults_restored")
    _populate_settings_options()
    _configure_settings_focus()
    get_viewport().size_changed.connect(_fit_to_viewport)
    _fit_to_viewport()
    _continue_button.pressed.connect(on_continue_pressed)
    _start_new_run_button.pressed.connect(on_start_new_run_pressed)
    _settings_button.pressed.connect(on_settings_pressed)
    _exit_button.pressed.connect(on_exit_pressed)
    _apply_settings_button.pressed.connect(on_apply_settings_pressed)
    _back_settings_button.pressed.connect(on_back_settings_pressed)
    _begin_button.pressed.connect(on_start_pressed)
    _back_button.pressed.connect(on_back_pressed)
    _previous_commander_button.pressed.connect(on_previous_commander_pressed)
    _next_commander_button.pressed.connect(on_next_commander_pressed)
    for index: int in _commander_skill_buttons.size():
        var button: Button = _commander_skill_buttons[index]
        button.mouse_entered.connect(
            _on_commander_skill_mouse_entered.bind(index, button)
        )
        button.mouse_exited.connect(_hide_commander_skill_tooltip.bind(button))
        button.focus_entered.connect(_show_commander_skill_tooltip.bind(index, button))
        button.focus_exited.connect(_on_commander_skill_focus_exited.bind(button))
    _commander_skill_tooltip.mouse_filter = Control.MOUSE_FILTER_STOP
    for child: Node in _commander_skill_tooltip.find_children("*", "Control"):
        (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    _commander_skill_tooltip.mouse_entered.connect(
        _on_commander_skill_tooltip_mouse_entered
    )
    _commander_skill_tooltip.mouse_exited.connect(
        _on_commander_skill_tooltip_mouse_exited
    )
    _commander_skill_tooltip_name.add_theme_font_size_override("font_size", 18)
    _commander_skill_tooltip_body.add_theme_font_size_override("font_size", 16)
    _overwrite_confirm_button.pressed.connect(on_overwrite_confirm_pressed)
    _overwrite_cancel_button.pressed.connect(on_overwrite_cancel_pressed)
    screen_changed.connect(_show_screen)
    session_ready.connect(_on_session_ready)
    launch_failed.connect(_on_launch_failed)
    _show_screen(int(_screen))
    _refresh_continue_button()
    _refresh_commander_ui()


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
    _pending_commander_id = &""
    _selected_commander_index = 0
    _set_screen(Screen.MAIN)


func open_settings() -> void:
    if _screen == Screen.OVERWRITE_CONFIRM:
        return
    _settings_return_screen = _screen
    _set_screen(Screen.SETTINGS)


func back_from_settings() -> void:
    if _screen != Screen.SETTINGS:
        return
    _set_screen(_settings_return_screen)


func apply_display_settings(resolution: Vector2i, mode: int) -> Dictionary:
    return _display_settings.call("apply_and_save", resolution, mode) as Dictionary


func get_display_settings_config() -> Dictionary:
    return _display_settings.call("get_committed_config") as Dictionary


func get_commander_ids() -> Array[StringName]:
    return _commander_ids.duplicate()


func get_selected_commander_id() -> StringName:
    return _selected_commander_id()


func request_start(seed_text: String, commander_id: StringName = &"") -> Dictionary:
    var resolved_commander_id: StringName = (
        commander_id if not commander_id.is_empty() else _selected_commander_id()
    )
    if not _commander_ids.has(resolved_commander_id):
        return {
            "ok": false,
            "confirmation_required": false,
            "error": WORLD_ERROR_SCRIPT.new(
                WORLD_ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                "",
                1,
                "production-launcher",
                "invalid_commander_id=%s" % String(resolved_commander_id)
            ),
        }
    var resolved_seed := _resolve_seed(seed_text)
    if has_saved_run():
        _pending_seed = resolved_seed
        _pending_commander_id = resolved_commander_id
        _set_screen(Screen.OVERWRITE_CONFIRM)
        return {
            "ok": false,
            "confirmation_required": true,
            "error": null,
        }
    return _create_and_persist(resolved_seed, resolved_commander_id)


func confirm_overwrite() -> Dictionary:
    if _screen != Screen.OVERWRITE_CONFIRM or _pending_seed.is_empty():
        return {"ok": false, "confirmation_required": false, "error": null}
    var resolved_seed := _pending_seed
    var commander_id := _pending_commander_id
    _pending_seed = ""
    _pending_commander_id = &""
    return _create_and_persist(resolved_seed, commander_id)


func cancel_overwrite() -> void:
    _pending_seed = ""
    _pending_commander_id = &""
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


func on_settings_pressed() -> void:
    open_settings()


func on_apply_settings_pressed() -> void:
    var resolutions: Array = _display_settings.call("get_supported_resolutions")
    var modes: Array = _display_settings.call("get_supported_modes")
    if (
        _resolution_option.selected < 0
        or _resolution_option.selected >= resolutions.size()
        or _display_mode_option.selected < 0
        or _display_mode_option.selected >= modes.size()
    ):
        _settings_status_label.text = "Unable to apply unsupported display settings."
        return
    var resolution: Vector2i = resolutions[_resolution_option.selected]
    var mode: int = int(modes[_display_mode_option.selected])
    var result := apply_display_settings(resolution, mode)
    if not bool(result.get("ok", false)):
        _settings_status_label.text = "Unable to apply unsupported display settings."
    elif not bool(result.get("save_ok", false)):
        _settings_status_label.text = (
            "Display changed, but settings could not be saved. Try Apply again."
        )
    else:
        _settings_load_status = &"ok"
        _settings_status_label.text = "Display settings applied."


func on_back_settings_pressed() -> void:
    back_from_settings()


func on_exit_pressed() -> void:
    request_exit()


func on_start_pressed() -> void:
    request_start(_seed_input.text)


func on_back_pressed() -> void:
    back_to_main()


func on_previous_commander_pressed() -> void:
    if not _can_cycle_commanders():
        return
    _selected_commander_index = wrapi(_selected_commander_index - 1, 0, _commander_ids.size())
    _refresh_commander_ui()


func on_next_commander_pressed() -> void:
    if not _can_cycle_commanders():
        return
    _selected_commander_index = wrapi(_selected_commander_index + 1, 0, _commander_ids.size())
    _refresh_commander_ui()


func on_overwrite_confirm_pressed() -> void:
    confirm_overwrite()


func on_overwrite_cancel_pressed() -> void:
    cancel_overwrite()


func _create_and_persist(resolved_seed: String, commander_id: StringName) -> Dictionary:
    var started: Dictionary = _start_service.call(
        "start",
        resolved_seed,
        {},
        "RETURN_RESULT",
        commander_id
    )
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
    _settings_center.visible = screen == int(Screen.SETTINGS)
    _settings_screen.visible = screen == int(Screen.SETTINGS)
    var show_overwrite := screen == int(Screen.OVERWRITE_CONFIRM)
    _overwrite_screen.visible = show_overwrite
    _overwrite_dimmer.visible = show_overwrite
    _overwrite_center.visible = show_overwrite
    if screen == int(Screen.MAIN):
        _refresh_continue_button()
        _settings_button.grab_focus()
    elif screen == int(Screen.NEW_RUN):
        _refresh_commander_ui()
        _seed_input.grab_focus()
    elif screen == int(Screen.SETTINGS):
        _sync_settings_controls()
        _resolution_option.grab_focus()


func _populate_settings_options() -> void:
    _resolution_option.clear()
    for label: String in ["1280 × 720", "1920 × 1080", "2560 × 1440"]:
        _resolution_option.add_item(label)
    _display_mode_option.clear()
    for label: String in ["Windowed", "Fullscreen"]:
        _display_mode_option.add_item(label)


func _configure_settings_focus() -> void:
    _resolution_option.focus_neighbor_bottom = _resolution_option.get_path_to(
        _display_mode_option
    )
    _display_mode_option.focus_neighbor_top = _display_mode_option.get_path_to(
        _resolution_option
    )
    _display_mode_option.focus_neighbor_bottom = _display_mode_option.get_path_to(
        _apply_settings_button
    )
    _apply_settings_button.focus_neighbor_top = _apply_settings_button.get_path_to(
        _display_mode_option
    )
    _apply_settings_button.focus_neighbor_right = _apply_settings_button.get_path_to(
        _back_settings_button
    )
    _back_settings_button.focus_neighbor_left = _back_settings_button.get_path_to(
        _apply_settings_button
    )


func _sync_settings_controls() -> void:
    var config := get_display_settings_config()
    var resolutions: Array = _display_settings.call("get_supported_resolutions")
    var modes: Array = _display_settings.call("get_supported_modes")
    _resolution_option.select(resolutions.find(config.get("resolution", Vector2i.ZERO)))
    _display_mode_option.select(modes.find(int(config.get("mode", -1))))
    if _settings_load_status == &"defaults_restored":
        _settings_status_label.text = (
            "Saved display settings could not be loaded. Defaults restored."
        )
    elif not _settings_status_label.text.begins_with("Display changed"):
        _settings_status_label.text = ""


func _refresh_commander_ui() -> void:
    if not is_node_ready():
        return
    var can_cycle: bool = _can_cycle_commanders()
    _previous_commander_button.disabled = not can_cycle
    _next_commander_button.disabled = not can_cycle
    var presentation: Dictionary = GoblinCommanderCatalog.get_presentation(_selected_commander_id())
    var valid: bool = not presentation.is_empty()
    _begin_button.disabled = not valid
    if not valid:
        _commander_name_label.text = "Commander unavailable"
        _commander_title_label.text = ""
        _commander_summary_label.text = ""
        _commander_root_class_label.text = ""
        return
    _commander_name_label.text = String(presentation.get("display_name", ""))
    _commander_title_label.text = String(presentation.get("title", ""))
    _commander_summary_label.text = String(presentation.get("summary", ""))
    _commander_root_class_label.text = "Root class · %s" % String(
        presentation.get("root_class_name", "")
    )
    _commander_portrait.tooltip_text = String(presentation.get("portrait_label", ""))
    var skills: Array = presentation.get("skills", [])
    _presented_commander_skills.clear()
    for value: Variant in skills:
        var presented_skill := value as CharacterSkill
        if is_instance_valid(presented_skill):
            _presented_commander_skills.append(presented_skill)
    var abbreviations: Array[String] = ["ST", "PB", "BN", "BH"]
    for index: int in _commander_skill_buttons.size():
        var button: Button = _commander_skill_buttons[index]
        button.text = abbreviations[index]
        button.disabled = index >= _presented_commander_skills.size()
        button.tooltip_text = ""
    if (
        is_instance_valid(_active_tooltip_target)
        and not _commander_skill_buttons.has(_active_tooltip_target)
    ):
        _tooltip_hide_request_id += 1
        _active_tooltip_target = null
        _active_tooltip_target_mouse_inside = false
        _commander_skill_tooltip_mouse_inside = false
        _commander_skill_tooltip.hide()


func _on_commander_skill_mouse_entered(index: int, target: Control) -> void:
    _active_tooltip_target_mouse_inside = true
    _show_commander_skill_tooltip(index, target)


func _show_commander_skill_tooltip(index: int, target: Control) -> void:
    if index < 0 or index >= _presented_commander_skills.size():
        return
    var skill: CharacterSkill = _presented_commander_skills[index]
    _tooltip_hide_request_id += 1
    _active_tooltip_target = target
    _commander_skill_tooltip_name.text = skill.display_name
    _commander_skill_tooltip_body.text = "\n".join([
        _format_cooldown(skill.cooldown_text),
        skill.effect_text,
        _format_target(skill.targeting_text),
    ])
    _commander_skill_tooltip.show()
    _position_commander_skill_tooltip.call_deferred(target)


func _on_commander_skill_focus_exited(target: Control) -> void:
    _schedule_commander_skill_tooltip_hide(target)


func _on_commander_skill_tooltip_mouse_entered() -> void:
    _commander_skill_tooltip_mouse_inside = true
    _tooltip_hide_request_id += 1


func _on_commander_skill_tooltip_mouse_exited() -> void:
    _commander_skill_tooltip_mouse_inside = false
    _schedule_commander_skill_tooltip_hide(_active_tooltip_target)


func _hide_commander_skill_tooltip(target: Control) -> void:
    if target != _active_tooltip_target:
        return
    _active_tooltip_target_mouse_inside = false
    _schedule_commander_skill_tooltip_hide(target)


func _schedule_commander_skill_tooltip_hide(target: Control) -> void:
    if not is_instance_valid(target):
        return
    _tooltip_hide_request_id += 1
    var request_id: int = _tooltip_hide_request_id
    await get_tree().create_timer(TOOLTIP_HIDE_DELAY_SECONDS).timeout
    if request_id != _tooltip_hide_request_id or target != _active_tooltip_target:
        return
    if (
        _active_tooltip_target_mouse_inside
        or _commander_skill_tooltip_mouse_inside
        or target.has_focus()
    ):
        return
    _active_tooltip_target = null
    _commander_skill_tooltip.hide()


func _position_commander_skill_tooltip(target: Control) -> void:
    if target != _active_tooltip_target or not _commander_skill_tooltip.visible:
        return
    _commander_skill_tooltip.reset_size()
    _commander_skill_tooltip.size.x = TOOLTIP_WIDTH
    var viewport_size := get_viewport_rect().size
    var desired := target.global_position + Vector2(target.size.x, 0.0) + TOOLTIP_OFFSET
    var minimum := Vector2.ONE * TOOLTIP_VIEWPORT_MARGIN
    var maximum := viewport_size - _commander_skill_tooltip.size - minimum
    maximum.x = maxf(maximum.x, minimum.x)
    maximum.y = maxf(maximum.y, minimum.y)
    _commander_skill_tooltip.global_position = desired.clamp(minimum, maximum)


func _format_cooldown(value: String) -> String:
    var compact := value.strip_edges()
    if compact.begins_with("CD") and compact.substr(2).is_valid_int():
        var turns := compact.substr(2).to_int()
        return "Cooldown: %d %s" % [turns, "turn" if turns == 1 else "turns"]
    if compact.begins_with("Cooldown:"):
        return compact
    return "Cooldown: %s" % compact


func _format_target(value: String) -> String:
    var target := value.strip_edges()
    return target if target.begins_with("Target:") else "Target: %s" % target


func _refresh_continue_button() -> void:
    if not has_saved_run():
        _continue_button.disabled = true
        return
    var loaded: Dictionary = _repository.call("load_validated")
    _continue_button.disabled = not bool(loaded.get("ok", false))


func _on_session_ready(session: Dictionary) -> void:
    if _world_factory == null:
        _emit_world_open_failure(session, "world_factory_missing")
        return
    for child: Node in _world_host.get_children():
        child.queue_free()
    var world := _world_factory.instantiate()
    _world_host.add_child(world)
    if world is WorldRuntimeController:
        var runtime_world := world as WorldRuntimeController
        runtime_world.launcher_return_requested.connect(_on_world_launcher_return_requested)
    if not world.has_method("apply_session") or not bool(world.call("apply_session", session)):
        world.queue_free()
        _emit_world_open_failure(session, "session_apply_failed")
        return
    _set_launcher_surface_visible(false)


func _on_world_launcher_return_requested() -> void:
    for child: Node in _world_host.get_children():
        child.queue_free()
    _set_launcher_surface_visible(true)
    back_to_main()


func _set_launcher_surface_visible(value: bool) -> void:
    _background.visible = value
    _main_center.visible = value
    _new_run_center.visible = value
    _settings_center.visible = value and _screen == Screen.SETTINGS
    if not value:
        _overwrite_dimmer.hide()
        _overwrite_center.hide()


func _emit_world_open_failure(session: Dictionary, constraint: String) -> void:
    var plan := session.get("plan") as RefCounted
    var error := WORLD_ERROR_SCRIPT.new(
        WORLD_ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
        plan.get_seed_hex() if is_instance_valid(plan) else "",
        plan.get_version() if is_instance_valid(plan) else 1,
        "production-launcher",
        constraint
    ) as RefCounted
    _emit_failure(error)


func _on_launch_failed(error: RefCounted) -> void:
    if not is_instance_valid(_failure_overlay):
        _failure_overlay = FAILURE_OVERLAY_SCENE.instantiate() as Control
        _failure_host.add_child(_failure_overlay)
    _failure_overlay.call("present", error, String(ProjectSettings.get_setting(
        "application/config/version", "development"
    )))


func _selected_commander_id() -> StringName:
    if _commander_ids.is_empty():
        return &""
    return _commander_ids[_selected_commander_index]


func _can_cycle_commanders() -> bool:
    return _commander_ids.size() > 1


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
