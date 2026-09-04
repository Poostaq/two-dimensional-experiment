class_name DisplaySettingsService
extends RefCounted

enum Mode { WINDOWED, FULLSCREEN }

const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_MODE := Mode.WINDOWED
const DEFAULT_PATH := "user://display_settings.cfg"
const SUPPORTED_RESOLUTIONS: Array[Vector2i] = [
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
    Vector2i(2560, 1440),
]
const SUPPORTED_MODES: Array[int] = [Mode.WINDOWED, Mode.FULLSCREEN]

static var DISPLAY_ADAPTER_SCRIPT: GDScript = load(
    "res://Scripts/Settings/display_adapter.gd"
)

var _display_adapter: RefCounted
var _settings_path: String
var _committed_config: Dictionary = _default_config()


func _init(display_adapter: RefCounted = null, settings_path: String = DEFAULT_PATH) -> void:
    _display_adapter = (
        display_adapter
        if is_instance_valid(display_adapter)
        else DISPLAY_ADAPTER_SCRIPT.new()
    )
    _settings_path = settings_path


func get_supported_resolutions() -> Array[Vector2i]:
    return SUPPORTED_RESOLUTIONS.duplicate()


func get_supported_modes() -> Array[int]:
    return SUPPORTED_MODES.duplicate()


func get_committed_config() -> Dictionary:
    return _committed_config.duplicate(true)


func load_and_apply() -> Dictionary:
    if not FileAccess.file_exists(_settings_path):
        _committed_config = _default_config()
        _apply_runtime(_committed_config)
        return {
            "ok": true,
            "load_status": &"missing",
            "config": get_committed_config(),
        }
    var file := ConfigFile.new()
    var load_error := file.load(_settings_path)
    if load_error != OK:
        return _restore_defaults_after_load_failure()
    var candidate := {
        "resolution": Vector2i(
            int(file.get_value("display", "width", -1)),
            int(file.get_value("display", "height", -1))
        ),
        "mode": _decode_mode(String(file.get_value("display", "mode", ""))),
    }
    if not _is_valid_config(candidate):
        return _restore_defaults_after_load_failure()
    _committed_config = candidate
    _apply_runtime(_committed_config)
    return {
        "ok": true,
        "load_status": &"ok",
        "config": get_committed_config(),
    }


func apply_and_save(resolution: Vector2i, mode: int) -> Dictionary:
    var candidate := {"resolution": resolution, "mode": mode}
    if not _is_valid_config(candidate):
        return {
            "ok": false,
            "save_ok": false,
            "config": get_committed_config(),
        }
    _committed_config = candidate
    _apply_runtime(_committed_config)
    var file := ConfigFile.new()
    file.set_value("display", "width", resolution.x)
    file.set_value("display", "height", resolution.y)
    file.set_value("display", "mode", _encode_mode(mode))
    _ensure_parent_directory()
    var save_error := file.save(_settings_path)
    return {
        "ok": true,
        "save_ok": save_error == OK,
        "save_error": save_error,
        "config": get_committed_config(),
    }


func _apply_runtime(config: Dictionary) -> void:
    var mode: int = int(config["mode"])
    var resolution: Vector2i = config["resolution"]
    _display_adapter.call("set_window_mode", mode)
    if mode == Mode.WINDOWED:
        _display_adapter.call("set_window_size", resolution)


func _restore_defaults_after_load_failure() -> Dictionary:
    _committed_config = _default_config()
    _apply_runtime(_committed_config)
    return {
        "ok": true,
        "load_status": &"defaults_restored",
        "config": get_committed_config(),
    }


func _is_valid_config(config: Dictionary) -> bool:
    return (
        config.has("resolution")
        and config.has("mode")
        and config["resolution"] is Vector2i
        and SUPPORTED_RESOLUTIONS.has(config["resolution"])
        and SUPPORTED_MODES.has(int(config["mode"]))
    )


func _encode_mode(mode: int) -> String:
    return "fullscreen" if mode == Mode.FULLSCREEN else "windowed"


func _decode_mode(value: String) -> int:
    if value == "windowed":
        return Mode.WINDOWED
    if value == "fullscreen":
        return Mode.FULLSCREEN
    return -1


func _ensure_parent_directory() -> void:
    var base_directory := _settings_path.get_base_dir()
    if base_directory.is_empty():
        return
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_directory))


static func _default_config() -> Dictionary:
    return {"resolution": DEFAULT_RESOLUTION, "mode": DEFAULT_MODE}
