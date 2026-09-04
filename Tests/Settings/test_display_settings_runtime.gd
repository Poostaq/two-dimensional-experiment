class_name DisplaySettingsRuntimeTests
extends SceneTree

const SERVICE_PATH := "res://Scripts/Settings/display_settings_service.gd"
const SETTINGS_PATH := "user://tests/display-settings-runtime/settings.cfg"

var _failures: Array[String] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _cleanup()
    var service_script := load(SERVICE_PATH) as GDScript
    var service: RefCounted = service_script.new(null, SETTINGS_PATH)
    var resolutions: Array[Vector2i] = [
        Vector2i(1280, 720),
        Vector2i(1920, 1080),
        Vector2i(2560, 1440),
    ]

    for resolution: Vector2i in resolutions:
        var windowed: Dictionary = service.call("apply_and_save", resolution, 0)
        await _settle_display()
        _expect(windowed.get("ok", false), "%s Windowed applies" % resolution)
        _expect(windowed.get("save_ok", false), "%s Windowed saves" % resolution)
        _expect(
            DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
            "%s uses Windowed mode" % resolution
        )
        _expect(
            DisplayServer.window_get_size() == resolution,
            "%s Windowed uses the exact requested size; observed %s" % [
                resolution,
                DisplayServer.window_get_size(),
            ]
        )

        var fullscreen: Dictionary = service.call("apply_and_save", resolution, 1)
        await _settle_display()
        _expect(fullscreen.get("ok", false), "%s Fullscreen applies" % resolution)
        _expect(fullscreen.get("save_ok", false), "%s Fullscreen saves" % resolution)
        _expect(
            DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
            "%s preference activates Fullscreen" % resolution
        )
        _expect(
            service.call("get_committed_config").get("resolution") == resolution,
            "%s remains preferred while Fullscreen" % resolution
        )

        var restored: Dictionary = service.call("apply_and_save", resolution, 0)
        await _settle_display()
        _expect(restored.get("ok", false), "%s restores Windowed" % resolution)
        _expect(
            DisplayServer.window_get_size() == resolution,
            "%s restores exact preferred Windowed size; observed %s" % [
                resolution,
                DisplayServer.window_get_size(),
            ]
        )

    service.call("apply_and_save", Vector2i(1280, 720), 1)
    await _settle_display()
    var reloaded: RefCounted = service_script.new(null, SETTINGS_PATH)
    var reload_result: Dictionary = reloaded.call("load_and_apply")
    await _settle_display()
    _expect(reload_result.get("load_status") == &"ok", "restart load is valid")
    _expect(
        reload_result.get("config") == {
            "resolution": Vector2i(1280, 720),
            "mode": 1,
        },
        "restart restores 1280x720 preferred Fullscreen"
    )

    reloaded.call("apply_and_save", Vector2i(1920, 1080), 0)
    await _settle_display()
    _expect(
        DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
        "runtime test leaves Windowed mode"
    )
    _expect(
        DisplayServer.window_get_size() == Vector2i(1920, 1080),
        "runtime test leaves canonical 1920x1080 size"
    )

    _cleanup()
    if _failures.is_empty():
        print("PASS test_display_settings_runtime (6/6 combinations + restart)")
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)


func _settle_display() -> void:
    await process_frame
    await process_frame


func _cleanup() -> void:
    var root_path := SETTINGS_PATH.get_base_dir()
    var absolute := ProjectSettings.globalize_path(root_path)
    var expected := ProjectSettings.globalize_path("user://tests/display-settings-runtime")
    if absolute != expected:
        _failures.append("unsafe display-settings runtime cleanup path")
        return
    var settings_absolute := ProjectSettings.globalize_path(SETTINGS_PATH)
    if FileAccess.file_exists(settings_absolute):
        DirAccess.remove_absolute(settings_absolute)
    if DirAccess.dir_exists_absolute(absolute):
        DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures.append(message)
