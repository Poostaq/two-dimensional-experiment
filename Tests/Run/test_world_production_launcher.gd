class_name WorldProductionLauncherTests
extends SceneTree

const LAUNCHER_PATH := "res://Scripts/Run/world_production_launcher.gd"
const EXIT_ADAPTER_PATH := "res://Scripts/Run/world_exit_adapter.gd"
const REPOSITORY_PATH := "res://Scripts/Run/world_single_slot_repository.gd"
const START_SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"

var _failures: int = 0
var _sessions: Array[Dictionary] = []


class StartServiceSpy:
    extends RefCounted

    var delegate: RefCounted
    var call_count: int = 0
    var seed_text: String = ""
    var commander_id: StringName = &""


    func _init(service: RefCounted) -> void:
        delegate = service


    func start(
        requested_seed: String,
        config: Dictionary = {},
        policy: String = "RETURN_RESULT",
        requested_commander_id: StringName = &"brakka_rustbanner"
    ) -> Dictionary:
        call_count += 1
        seed_text = requested_seed
        commander_id = requested_commander_id
        return delegate.call("start", requested_seed, config, policy, requested_commander_id)


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(LAUNCHER_PATH) or not ResourceLoader.exists(EXIT_ADAPTER_PATH):
        _fail("production launcher or exit adapter is missing")
        _finish()
        return
    var launcher_script := load(LAUNCHER_PATH) as GDScript
    var exit_script := load(EXIT_ADAPTER_PATH) as GDScript
    var repository_script := load(REPOSITORY_PATH) as GDScript
    var service_script := load(START_SERVICE_PATH) as GDScript
    var root := "user://tests/world-production-launcher"
    var blank_path := root + "/blank.json"
    var explicit_path := root + "/explicit.json"
    _cleanup(root)

    var blank_repository: RefCounted = repository_script.new(blank_path)
    var blank_service_delegate: RefCounted = service_script.new(Callable(self, "_ignore_plan"))
    var blank_service := StartServiceSpy.new(blank_service_delegate)
    var blank_exit: RefCounted = exit_script.new()
    blank_exit.set("terminate_process", false)
    var blank_launcher: Control = launcher_script.new(
        blank_service, blank_repository, blank_exit, null
    )
    blank_launcher.connect("session_ready", Callable(self, "_capture_session"))

    var has_commander_api: bool = blank_launcher.has_method("get_selected_commander_id")
    _expect(has_commander_api, "launcher exposes commander selection API")
    if has_commander_api:
        _expect(blank_launcher.call("get_selected_commander_id") == &"brakka_rustbanner", "Brakka selected by default")
        _expect(blank_launcher.call("get_commander_ids").size() == 1, "launcher exposes one catalog commander")
    _expect(
        int(blank_launcher.call("get_screen")) == int(launcher_script.Screen.MAIN),
        "launcher starts on MAIN"
    )
    blank_launcher.call("open_new_run")
    _expect(
        int(blank_launcher.call("get_screen")) == int(launcher_script.Screen.NEW_RUN),
        "Start New Run opens NEW_RUN"
    )
    blank_launcher.call("back_to_main")
    _expect(
        int(blank_launcher.call("get_screen")) == int(launcher_script.Screen.MAIN),
        "Back returns to MAIN"
    )
    blank_launcher.call("open_new_run")
    var blank_result: Dictionary = blank_launcher.call("request_start", "")
    _expect(bool(blank_result.get("ok", false)), "blank seed starts a run")
    _expect(not _sessions.is_empty(), "blank seed emits a session")
    _expect(blank_service.commander_id == &"brakka_rustbanner", "blank seed forwards selected Brakka")
    if not _sessions.is_empty():
        _expect(
            not String(_sessions.back().get("resolved_seed", "")).is_empty(),
            "blank seed resolves to nonempty stable text"
        )

    _sessions.clear()
    var repository: RefCounted = repository_script.new(explicit_path)
    var service_delegate: RefCounted = service_script.new(Callable(self, "_ignore_plan"))
    var service := StartServiceSpy.new(service_delegate)
    var exit_adapter: RefCounted = exit_script.new()
    exit_adapter.set("terminate_process", false)
    var launcher: Control = launcher_script.new(service, repository, exit_adapter, null)
    launcher.connect("session_ready", Callable(self, "_capture_session"))
    launcher.call("open_new_run")
    var explicit_result: Dictionary = launcher.call(
        "request_start",
        "chosen-seed",
        &"brakka_rustbanner"
    ) if has_commander_api else launcher.call("request_start", "chosen-seed")
    _expect(bool(explicit_result.get("ok", false)), "explicit seed starts a run")
    _expect(service.commander_id == &"brakka_rustbanner", "launcher forwards explicit commander ID")
    _expect(
        not _sessions.is_empty() and String(_sessions.back().get("resolved_seed", "")) == "chosen-seed",
        "explicit seed is preserved"
    )

    var saved_before_cancel := _read_bytes(explicit_path)
    if has_commander_api:
        var calls_before_invalid: int = service.call_count
        var invalid: Dictionary = launcher.call("request_start", "invalid-seed", &"unknown")
        _expect(not invalid.get("ok", true), "unknown commander selection is rejected")
        _expect(service.call_count == calls_before_invalid, "unknown commander is rejected before start service")
        _expect(_read_bytes(explicit_path) == saved_before_cancel, "unknown commander performs zero writes")
    launcher.call("open_new_run")
    var overwrite_result: Dictionary = launcher.call("request_start", "replacement")
    _expect(bool(overwrite_result.get("confirmation_required", false)), "existing save requests confirmation")
    _expect(
        int(launcher.call("get_screen")) == int(launcher_script.Screen.OVERWRITE_CONFIRM),
        "overwrite confirmation screen opens"
    )
    launcher.call("cancel_overwrite")
    _expect(
        int(launcher.call("get_screen")) == int(launcher_script.Screen.NEW_RUN),
        "overwrite cancellation returns to NEW_RUN"
    )
    _expect(_read_bytes(explicit_path) == saved_before_cancel, "overwrite cancellation performs zero writes")

    _sessions.clear()
    launcher.call("back_to_main")
    var continued: Dictionary = launcher.call("continue_saved_run")
    _expect(bool(continued.get("ok", false)), "Continue validates the saved run")
    _expect(not _sessions.is_empty(), "Continue emits a validated session")
    if not _sessions.is_empty():
        _expect(
            String(_sessions.back().get("resolved_seed", "")) == "chosen-seed",
            "Continue restores the persisted resolved seed"
        )

    _sessions.clear()
    launcher.call("open_new_run")
    launcher.call("request_start", "confirmed-replacement")
    var confirmed: Dictionary = launcher.call("confirm_overwrite")
    _expect(bool(confirmed.get("ok", false)), "overwrite confirmation replaces the saved run")
    _expect(service.commander_id == &"brakka_rustbanner", "overwrite confirmation preserves pending commander")
    _expect(_read_bytes(explicit_path) != saved_before_cancel, "confirmed overwrite publishes new bytes")
    _expect(
        not _sessions.is_empty()
        and String(_sessions.back().get("resolved_seed", "")) == "confirmed-replacement",
        "confirmed overwrite emits the replacement session"
    )

    launcher.call("back_to_main")
    if has_commander_api:
        _expect(launcher.call("get_selected_commander_id") == &"brakka_rustbanner", "Back restores default Brakka selection")

    launcher.call("request_exit", self)
    _expect(int(exit_adapter.get("requested_status")) == 0, "Exit requests status 0 exactly once")
    _expect(int(exit_adapter.get("request_count")) == 1, "Exit adapter is called exactly once")

    blank_launcher.free()
    launcher.free()
    _cleanup(root)
    _finish()


func _capture_session(session: Dictionary) -> void:
    _sessions.append(session)


func _ignore_plan(_plan: RefCounted) -> void:
    pass


func _read_bytes(path: String) -> PackedByteArray:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return PackedByteArray()
    var bytes := file.get_buffer(file.get_length())
    file.close()
    return bytes


func _cleanup(root: String) -> void:
    var absolute := ProjectSettings.globalize_path(root)
    var expected := ProjectSettings.globalize_path("user://tests/world-production-launcher")
    if absolute != expected:
        _fail("unsafe cleanup path")
        return
    for filename: String in ["blank.json", "explicit.json"]:
        for suffix: String in ["", ".tmp", ".bak"]:
            var path := absolute + "/" + filename + suffix
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
        print("PASS test_world_production_launcher")
    quit(1 if _failures > 0 else 0)
