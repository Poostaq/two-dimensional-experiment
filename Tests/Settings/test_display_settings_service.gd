class_name DisplaySettingsServiceTests
extends SceneTree

const SERVICE_PATH := "res://Scripts/Settings/display_settings_service.gd"
const TEST_ROOT := "user://tests/display-settings"

var _failures: int = 0


class FakeDisplayAdapter:
    extends RefCounted

    var calls: Array[Dictionary] = []


    func set_window_mode(mode: int) -> void:
        calls.append({"operation": &"mode", "value": mode})


    func set_window_size(size: Vector2i) -> void:
        calls.append({"operation": &"size", "value": size})


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _cleanup()
    _expect(ResourceLoader.exists(SERVICE_PATH), "display settings service exists")
    if not ResourceLoader.exists(SERVICE_PATH):
        _finish()
        return
    var service_script := load(SERVICE_PATH) as GDScript
    var path := TEST_ROOT + "/settings.cfg"
    var adapter := FakeDisplayAdapter.new()
    var service: RefCounted = service_script.new(adapter, path)

    _expect(
        service.call("get_supported_resolutions") == [
            Vector2i(1280, 720),
            Vector2i(1920, 1080),
            Vector2i(2560, 1440),
        ],
        "supported resolutions are exact and ordered"
    )
    _expect(service.call("get_supported_modes") == [0, 1], "supported modes are exact")

    var first_load: Dictionary = service.call("load_and_apply")
    _expect(first_load.get("ok", false), "missing file loads defaults")
    _expect(first_load.get("load_status") == &"missing", "missing file is not a warning")
    _expect(
        first_load.get("config") == {"resolution": Vector2i(1920, 1080), "mode": 0},
        "first launch defaults to 1920x1080 Windowed"
    )
    _expect(
        adapter.calls == [
            {"operation": &"mode", "value": 0},
            {"operation": &"size", "value": Vector2i(1920, 1080)},
        ],
        "windowed load changes mode before size"
    )

    adapter.calls.clear()
    var fullscreen: Dictionary = service.call(
        "apply_and_save", Vector2i(2560, 1440), 1
    )
    _expect(fullscreen.get("ok", false), "fullscreen selection applies")
    _expect(fullscreen.get("save_ok", false), "clean first save creates its parent directory")
    _expect(
        adapter.calls == [{"operation": &"mode", "value": 1}],
        "fullscreen changes mode without resizing fullscreen surface"
    )
    _expect(
        service.call("get_committed_config") == {
            "resolution": Vector2i(2560, 1440),
            "mode": 1,
        },
        "fullscreen retains preferred window size"
    )

    adapter.calls.clear()
    var restored: Dictionary = service.call(
        "apply_and_save", Vector2i(2560, 1440), 0
    )
    _expect(restored.get("ok", false), "windowed selection applies")
    _expect(
        adapter.calls == [
            {"operation": &"mode", "value": 0},
            {"operation": &"size", "value": Vector2i(2560, 1440)},
        ],
        "windowed restoration changes mode before exact preferred size"
    )

    var reloaded_adapter := FakeDisplayAdapter.new()
    var reloaded: RefCounted = service_script.new(reloaded_adapter, path)
    var round_trip: Dictionary = reloaded.call("load_and_apply")
    _expect(round_trip.get("load_status") == &"ok", "valid saved settings load cleanly")
    _expect(round_trip.get("config") == restored.get("config"), "settings survive restart")

    var calls_before_invalid: int = adapter.calls.size()
    var committed_before_invalid: Dictionary = service.call("get_committed_config")
    var unsupported: Dictionary = service.call(
        "apply_and_save", Vector2i(1600, 900), 0
    )
    _expect(not unsupported.get("ok", true), "unsupported resolution is rejected")
    var invalid_mode: Dictionary = service.call(
        "apply_and_save", Vector2i(1920, 1080), 9
    )
    _expect(not invalid_mode.get("ok", true), "unsupported mode is rejected")
    _expect(adapter.calls.size() == calls_before_invalid, "invalid values do not touch display")
    _expect(
        service.call("get_committed_config") == committed_before_invalid,
        "invalid values do not mutate committed settings"
    )

    _write_partial_config(path)
    var partial_service: RefCounted = service_script.new(FakeDisplayAdapter.new(), path)
    var partial_load: Dictionary = partial_service.call("load_and_apply")
    _expect(
        partial_load.get("load_status") == &"defaults_restored",
        "partial file reports a load warning"
    )
    _expect(
        partial_load.get("config") == {"resolution": Vector2i(1920, 1080), "mode": 0},
        "partial file restores complete defaults"
    )

    _write_invalid_config(path)
    var invalid_service: RefCounted = service_script.new(FakeDisplayAdapter.new(), path)
    var invalid_load: Dictionary = invalid_service.call("load_and_apply")
    _expect(
        invalid_load.get("load_status") == &"defaults_restored",
        "invalid file reports a load warning"
    )
    _expect(
        invalid_load.get("config") == {"resolution": Vector2i(1920, 1080), "mode": 0},
        "invalid file restores complete defaults"
    )

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
    var blocker_path := TEST_ROOT + "/blocker"
    var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
    blocker.store_string("not a directory")
    blocker.close()
    var save_failure_service: RefCounted = service_script.new(
        FakeDisplayAdapter.new(),
        blocker_path + "/settings.cfg"
    )
    var save_failure: Dictionary = save_failure_service.call(
        "apply_and_save", Vector2i(1280, 720), 0
    )
    _expect(save_failure.get("ok", false), "save failure keeps runtime apply successful")
    _expect(not save_failure.get("save_ok", true), "save failure is explicit")
    _expect(
        save_failure_service.call("get_committed_config") == {
            "resolution": Vector2i(1280, 720),
            "mode": 0,
        },
        "save failure retains committed runtime configuration"
    )

    _cleanup()
    _finish()


func _write_partial_config(path: String) -> void:
    var config := ConfigFile.new()
    config.set_value("display", "width", 1280)
    config.save(path)


func _write_invalid_config(path: String) -> void:
    var config := ConfigFile.new()
    config.set_value("display", "width", 1600)
    config.set_value("display", "height", 900)
    config.set_value("display", "mode", "unknown")
    config.save(path)


func _cleanup() -> void:
    var absolute := ProjectSettings.globalize_path(TEST_ROOT)
    var expected := ProjectSettings.globalize_path("user://tests/display-settings")
    if absolute != expected:
        _fail("unsafe display-settings cleanup path")
        return
    for filename: String in ["settings.cfg", "blocker"]:
        var path := absolute + "/" + filename
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)
    if DirAccess.dir_exists_absolute(absolute):
        DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_display_settings_service")
    quit(1 if _failures > 0 else 0)
