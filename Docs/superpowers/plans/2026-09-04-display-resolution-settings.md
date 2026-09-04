# Display Resolution Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent main-menu Settings screen for 1280×720, 1920×1080, and 2560×1440 resolution choices plus Windowed and Fullscreen modes, defaulting to 1920×1080 Windowed.

**Architecture:** A focused `DisplaySettingsService` owns validation, committed preferred window size, `ConfigFile` persistence, and ordered display application through an injectable `DisplayAdapter`. `WorldProductionLauncher` adds `Screen.SETTINGS`, maintains pending UI state, and delegates all OS display work to the service; `world_run_start.tscn` owns the responsive settings layout.

**Tech Stack:** Godot 4.7, typed GDScript, `DisplayServer`, `ConfigFile`, scene-native `Control`/container UI, headless `SceneTree` tests, GodotIQ structured scene/script operations.

**Approved design:** `Docs/superpowers/specs/2026-09-04-display-resolution-settings-design.md`

---

## File Map

- Create `Scripts/Settings/display_adapter.gd`: the only production wrapper around `DisplayServer`.
- Create `Scripts/Settings/display_settings_service.gd`: supported-value catalog, validation, committed state, persistence, and ordered application.
- Create `Tests/Settings/test_display_settings_service.gd`: deterministic unit coverage using a fake adapter and isolated `user://tests/display-settings` files.
- Modify `project.godot`: canonical 1920×1080 Windowed project defaults; preserve `canvas_items` and `expand`.
- Modify `Scripts/Run/world_production_launcher.gd`: inject/use the service, add `SETTINGS`, navigation, selector synchronization, Apply/Back semantics, and status text.
- Modify `Scenes/world_run_start.tscn`: Settings button and responsive Settings screen controls.
- Modify `Tests/Run/test_world_production_launcher.gd`: launcher state, return navigation, apply delegation, and pending-state tests.
- Modify `Tests/UI/test_world_run_start_scene.gd`: required controls, signal behavior, focus order, and 1280×720 fit.

### Task 1: Build the deterministic display-settings service

**Files:**

- Create: `Scripts/Settings/display_adapter.gd`
- Create: `Scripts/Settings/display_settings_service.gd`
- Create: `Tests/Settings/test_display_settings_service.gd`

- [ ] **Step 1: Baseline the project and inspect every target before editing**

Use GodotIQ:

```text
project_summary(detail="brief")
validate(target="project", detail="brief")
file_context(file="res://Scripts/Run/world_production_launcher.gd", detail="brief")
file_context(file="res://Tests/Run/test_world_production_launcher.gd", detail="brief")
```

Expected: the project summary identifies Godot 4; baseline validation is recorded; the two existing files return structured context. New files do not require `file_context` until after creation.

- [ ] **Step 2: Write the failing service test**

Create `Tests/Settings/test_display_settings_service.gd` through `godotiq_script_ops(op="create")`. The test must define a `FakeDisplayAdapter` that records ordered dictionaries and must exercise the complete public contract:

```gdscript
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
            Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)
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
    _expect(adapter.calls == [
        {"operation": &"mode", "value": 0},
        {"operation": &"size", "value": Vector2i(1920, 1080)},
    ], "windowed load changes mode before size")

    adapter.calls.clear()
    var fullscreen: Dictionary = service.call("apply_and_save", Vector2i(2560, 1440), 1)
    _expect(fullscreen.get("ok", false), "fullscreen selection applies")
    _expect(fullscreen.get("save_ok", false), "fullscreen selection saves")
    _expect(adapter.calls == [
        {"operation": &"mode", "value": 1},
    ], "fullscreen changes mode without resizing fullscreen surface")
    _expect(
        service.call("get_committed_config") == {
            "resolution": Vector2i(2560, 1440), "mode": 1
        },
        "fullscreen retains preferred window size"
    )

    adapter.calls.clear()
    var restored: Dictionary = service.call("apply_and_save", Vector2i(2560, 1440), 0)
    _expect(restored.get("ok", false), "windowed selection applies")
    _expect(adapter.calls == [
        {"operation": &"mode", "value": 0},
        {"operation": &"size", "value": Vector2i(2560, 1440)},
    ], "windowed restoration changes mode before exact preferred size")

    var reloaded_adapter := FakeDisplayAdapter.new()
    var reloaded: RefCounted = service_script.new(reloaded_adapter, path)
    var round_trip: Dictionary = reloaded.call("load_and_apply")
    _expect(round_trip.get("load_status") == &"ok", "valid saved settings load cleanly")
    _expect(round_trip.get("config") == restored.get("config"), "settings survive restart")

    var unsupported: Dictionary = service.call("apply_and_save", Vector2i(1600, 900), 0)
    _expect(not unsupported.get("ok", true), "unsupported resolution is rejected")
    var invalid_mode: Dictionary = service.call("apply_and_save", Vector2i(1920, 1080), 9)
    _expect(not invalid_mode.get("ok", true), "unsupported mode is rejected")

    _write_partial_config(path)
    var partial_service: RefCounted = service_script.new(FakeDisplayAdapter.new(), path)
    var partial_load: Dictionary = partial_service.call("load_and_apply")
    _expect(partial_load.get("load_status") == &"defaults_restored", "partial file warns")
    _expect(
        partial_load.get("config") == {"resolution": Vector2i(1920, 1080), "mode": 0},
        "partial file restores complete defaults"
    )

    _write_invalid_config(path)
    var invalid_adapter := FakeDisplayAdapter.new()
    var invalid_service: RefCounted = service_script.new(invalid_adapter, path)
    var invalid_load: Dictionary = invalid_service.call("load_and_apply")
    _expect(invalid_load.get("load_status") == &"defaults_restored", "invalid file warns")
    _expect(
        invalid_load.get("config") == {"resolution": Vector2i(1920, 1080), "mode": 0},
        "invalid file restores complete defaults"
    )

    var blocker_path := TEST_ROOT + "/blocker"
    var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
    blocker.store_string("not a directory")
    blocker.close()
    var save_failure_adapter := FakeDisplayAdapter.new()
    var save_failure_service: RefCounted = service_script.new(
        save_failure_adapter,
        blocker_path + "/settings.cfg"
    )
    var save_failure: Dictionary = save_failure_service.call(
        "apply_and_save", Vector2i(1280, 720), 0
    )
    _expect(save_failure.get("ok", false), "save failure keeps runtime apply successful")
    _expect(not save_failure.get("save_ok", true), "save failure is explicit")
    _expect(
        save_failure_service.call("get_committed_config") == {
            "resolution": Vector2i(1280, 720), "mode": 0
        },
        "save failure retains committed runtime configuration"
    )

    _cleanup()
    _finish()


func _write_invalid_config(path: String) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
    var config := ConfigFile.new()
    config.set_value("display", "width", 1600)
    config.set_value("display", "height", 900)
    config.set_value("display", "mode", "unknown")
    config.save(path)


func _write_partial_config(path: String) -> void:
    var config := ConfigFile.new()
    config.set_value("display", "width", 1280)
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
```

- [ ] **Step 3: Run the service test and verify the red state**

Run:

```powershell
godot --headless --path . --script res://Tests/Settings/test_display_settings_service.gd
```

Expected: exit `1` with `display settings service exists` because the production files do not exist.

- [ ] **Step 4: Create the production adapter**

Create `Scripts/Settings/display_adapter.gd` through `godotiq_script_ops(op="create")`:

```gdscript
class_name DisplayAdapter
extends RefCounted


func set_window_mode(mode: int) -> void:
    var server_mode := (
        DisplayServer.WINDOW_MODE_FULLSCREEN
        if mode == DisplaySettingsService.Mode.FULLSCREEN
        else DisplayServer.WINDOW_MODE_WINDOWED
    )
    DisplayServer.window_set_mode(server_mode)


func set_window_size(size: Vector2i) -> void:
    DisplayServer.window_set_size(size)
```

- [ ] **Step 5: Create the settings service**

Create `Scripts/Settings/display_settings_service.gd` through `godotiq_script_ops(op="create")`. Implement these exact constants and methods:

```gdscript
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

var _display_adapter: RefCounted
var _settings_path: String
var _committed_config: Dictionary = _default_config()


func _init(display_adapter: RefCounted = null, settings_path: String = DEFAULT_PATH) -> void:
    _display_adapter = display_adapter if is_instance_valid(display_adapter) else DisplayAdapter.new()
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
        return {"ok": true, "load_status": &"missing", "config": get_committed_config()}
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
    return {"ok": true, "load_status": &"ok", "config": get_committed_config()}


func apply_and_save(resolution: Vector2i, mode: int) -> Dictionary:
    var candidate := {"resolution": resolution, "mode": mode}
    if not _is_valid_config(candidate):
        return {"ok": false, "save_ok": false, "config": get_committed_config()}
    _committed_config = candidate
    _apply_runtime(_committed_config)
    var file := ConfigFile.new()
    file.set_value("display", "width", resolution.x)
    file.set_value("display", "height", resolution.y)
    file.set_value("display", "mode", _encode_mode(mode))
    var save_error := file.save(_settings_path)
    return {
        "ok": true,
        "save_ok": save_error == OK,
        "save_error": save_error,
        "config": get_committed_config(),
    }


func _apply_runtime(config: Dictionary) -> void:
    var mode := int(config["mode"])
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
        and SUPPORTED_RESOLUTIONS.has(config["resolution"] as Vector2i)
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


static func _default_config() -> Dictionary:
    return {"resolution": DEFAULT_RESOLUTION, "mode": DEFAULT_MODE}
```

Use `load()` references for scripts created in this session if Godot cannot resolve the new `class_name` cache immediately. Do not add this service as an autoload.

- [ ] **Step 6: Validate each created script and run the green service test**

After creating each `.gd`, run its own cycle:

```text
validate(target="res://Scripts/Settings/display_adapter.gd", detail="brief")
check_errors(scope="file:res://Scripts/Settings/display_adapter.gd")
validate(target="res://Scripts/Settings/display_settings_service.gd", detail="brief")
check_errors(scope="file:res://Scripts/Settings/display_settings_service.gd")
validate(target="res://Tests/Settings/test_display_settings_service.gd", detail="brief")
check_errors(scope="file:res://Tests/Settings/test_display_settings_service.gd")
```

Then run:

```powershell
godot --headless --path . --script res://Tests/Settings/test_display_settings_service.gd
```

Expected: exit `0` and `PASS test_display_settings_service`; fake calls prove Windowed mode precedes resize, Fullscreen does not overwrite preferred size, persistence round-trips, invalid input does not mutate, and save failure remains non-blocking.

- [ ] **Step 7: Commit the service slice**

```powershell
git add -- Scripts/Settings/display_adapter.gd Scripts/Settings/display_settings_service.gd Tests/Settings/test_display_settings_service.gd
git commit -m "feat: add persistent display settings service"
```

### Task 2: Establish canonical project display defaults

**Files:**

- Modify: `project.godot`

- [ ] **Step 1: Record the existing display block**

Read only the `[display]` section. Expected baseline:

```ini
[display]

window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- [ ] **Step 2: Add the 1920×1080 Windowed defaults**

Use Godot's project-settings editor or a GodotIQ project-setting operation if available. The resulting section must be:

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/window_width_override=1920
window/size/window_height_override=1080
window/size/mode=0
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

Do not change stretch mode or aspect policy. `mode=0` is the Windowed project default; runtime persistence remains service-owned.

- [ ] **Step 3: Verify startup defaults and commit**

Run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://Tests/Settings/test_display_settings_service.gd
```

Expected: project import exits `0`; service test remains green.

```powershell
git add -- project.godot
git commit -m "config: default display to 1920x1080 windowed"
```

### Task 3: Add Settings state and delegation to the launcher

**Files:**

- Modify: `Tests/Run/test_world_production_launcher.gd`
- Modify: `Scripts/Run/world_production_launcher.gd`

- [ ] **Step 1: Inspect impact before changing the launcher signature and enum**

Use GodotIQ:

```text
file_context(file="res://Scripts/Run/world_production_launcher.gd", detail="normal")
impact_check(file="res://Scripts/Run/world_production_launcher.gd", action="change_signature", target="_init")
impact_check(file="res://Scripts/Run/world_production_launcher.gd", action="change_enum", target="Screen")
file_context(file="res://Tests/Run/test_world_production_launcher.gd", detail="normal")
```

Expected: identify the launcher scene and test constructor callers. Keep the new constructor argument last with a default so existing callers remain source-compatible.

- [ ] **Step 2: Extend the launcher test with a display-settings spy**

Before production edits, add a `DisplaySettingsSpy` to `test_world_production_launcher.gd`:

```gdscript
class DisplaySettingsSpy:
    extends RefCounted

    var committed: Dictionary = {"resolution": Vector2i(1920, 1080), "mode": 0}
    var apply_count: int = 0
    var last_resolution := Vector2i.ZERO
    var last_mode: int = -1
    var save_ok: bool = true

    func get_supported_resolutions() -> Array[Vector2i]:
        return [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]

    func get_supported_modes() -> Array[int]:
        return [0, 1]

    func load_and_apply() -> Dictionary:
        return {"ok": true, "load_status": &"missing", "config": committed.duplicate(true)}

    func get_committed_config() -> Dictionary:
        return committed.duplicate(true)

    func apply_and_save(resolution: Vector2i, mode: int) -> Dictionary:
        apply_count += 1
        last_resolution = resolution
        last_mode = mode
        committed = {"resolution": resolution, "mode": mode}
        return {"ok": true, "save_ok": save_ok, "config": committed.duplicate(true)}
```

Construct the launcher with this spy as the fifth argument. Add assertions using public methods so they do not require a ready scene tree:

```gdscript
_expect(launcher_script.Screen.has("SETTINGS"), "launcher exposes SETTINGS screen")
launcher.call("open_settings")
_expect(
    int(launcher.call("get_screen")) == int(launcher_script.Screen.SETTINGS),
    "Settings opens from MAIN"
)
launcher.call("back_from_settings")
_expect(
    int(launcher.call("get_screen")) == int(launcher_script.Screen.MAIN),
    "Settings Back returns to recorded MAIN"
)
launcher.call("open_settings")
var applied: Dictionary = launcher.call("apply_display_settings", Vector2i(1280, 720), 1)
_expect(applied.get("ok", false), "launcher delegates valid display settings")
_expect(display_spy.apply_count == 1, "Apply delegates exactly once")
_expect(display_spy.last_resolution == Vector2i(1280, 720), "Apply forwards resolution")
_expect(display_spy.last_mode == 1, "Apply forwards mode")
launcher.call("back_from_settings")
_expect(display_spy.apply_count == 1, "Back performs no settings write")
```

Also set `save_ok=false`, Apply once, and assert the returned result remains `ok=true` and `save_ok=false`, proving runtime application is not rolled back by persistence failure.

- [ ] **Step 3: Run the launcher test and verify the red state**

```powershell
godot --headless --path . --script res://Tests/Run/test_world_production_launcher.gd
```

Expected: exit `1` because `Screen.SETTINGS`, the fifth constructor dependency, and settings methods are absent.

- [ ] **Step 4: Implement launcher state and service delegation**

Patch through `godotiq_script_ops(op="patch")`:

```gdscript
enum Screen {
    MAIN,
    NEW_RUN,
    SETTINGS,
    OVERWRITE_CONFIRM,
}

static var DISPLAY_SETTINGS_SCRIPT: GDScript = load(
    "res://Scripts/Settings/display_settings_service.gd"
)

var _settings_return_screen: Screen = Screen.MAIN
var _display_settings: RefCounted
var _settings_load_status: StringName = &"missing"
```

Extend `_init` with `display_settings: RefCounted = null` as the last parameter and initialize it from the injected spy or `DISPLAY_SETTINGS_SCRIPT.new()`. Add:

```gdscript
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
```

During `_ready`, call `load_and_apply()` before `_show_screen`, store its `load_status`, and later synchronize the scene controls in Task 4. Do not call `DisplayServer` or `ConfigFile` from the launcher.

- [ ] **Step 5: Validate and run the launcher/service tests**

```text
validate(target="res://Scripts/Run/world_production_launcher.gd", detail="brief")
check_errors(scope="file:res://Scripts/Run/world_production_launcher.gd")
validate(target="res://Tests/Run/test_world_production_launcher.gd", detail="brief")
check_errors(scope="file:res://Tests/Run/test_world_production_launcher.gd")
```

```powershell
godot --headless --path . --script res://Tests/Settings/test_display_settings_service.gd
godot --headless --path . --script res://Tests/Run/test_world_production_launcher.gd
```

Expected: both exit `0`; all existing seed, commander, overwrite, Continue, and Exit checks remain green.

- [ ] **Step 6: Commit the launcher behavior slice**

```powershell
git add -- Scripts/Run/world_production_launcher.gd Tests/Run/test_world_production_launcher.gd
git commit -m "feat: add launcher display settings flow"
```

### Task 4: Build and wire the main-menu Settings screen

**Files:**

- Modify: `Tests/UI/test_world_run_start_scene.gd`
- Modify: `Scenes/world_run_start.tscn`
- Modify: `Scripts/Run/world_production_launcher.gd`

- [ ] **Step 1: Add failing scene-contract tests**

Call `file_context` for both targets before editing. Extend `REQUIRED_UNIQUE_NODES` with:

```gdscript
&"SettingsScreen",
&"SettingsButton",
&"ResolutionOption",
&"DisplayModeOption",
&"ApplySettingsButton",
&"BackSettingsButton",
&"SettingsStatusLabel",
```

After instantiating the scene at 1280×720, assert:

```gdscript
var settings_button := scene.get_node("%SettingsButton") as Button
var settings_screen := scene.get_node("%SettingsScreen") as Control
var resolution := scene.get_node("%ResolutionOption") as OptionButton
var display_mode := scene.get_node("%DisplayModeOption") as OptionButton
var apply_button := scene.get_node("%ApplySettingsButton") as Button
var back_button := scene.get_node("%BackSettingsButton") as Button

_expect(resolution.item_count == 3, "resolution selector has exactly three choices")
_expect(resolution.get_item_text(0) == "1280 × 720", "first resolution is 1280x720")
_expect(resolution.get_item_text(1) == "1920 × 1080", "second resolution is 1920x1080")
_expect(resolution.get_item_text(2) == "2560 × 1440", "third resolution is 2560x1440")
_expect(display_mode.item_count == 2, "mode selector has exactly two choices")
_expect(display_mode.get_item_text(0) == "Windowed", "Windowed is first")
_expect(display_mode.get_item_text(1) == "Fullscreen", "Fullscreen is second")

settings_button.pressed.emit()
await process_frame
_expect(settings_screen.visible, "Settings button opens Settings screen")
_expect(not scene.get_node("%MainScreen").visible, "Settings hides Main screen")
_expect(resolution.selected == 1, "default resolution selector is 1920x1080")
_expect(display_mode.selected == 0, "default display mode is Windowed")

var viewport_rect := Rect2(Vector2.ZERO, Vector2(1280, 720))
for control: Control in [resolution, display_mode, apply_button, back_button]:
    _expect(
        viewport_rect.encloses(control.get_global_rect()),
        "%s fits inside 1280x720" % control.name
    )
```

Change selector indices without pressing Apply, emit Back, reopen Settings, and assert both selectors return to the committed indices. Then change both selectors, emit Apply, and assert reopening preserves the applied indices. Inject the existing scene test's dependencies so the production service does not resize the headless test window.

- [ ] **Step 2: Run the scene test and verify the red state**

```powershell
godot --headless --path . --script res://Tests/UI/test_world_run_start_scene.gd
```

Expected: exit `1` because the seven unique controls are absent.

- [ ] **Step 3: Build the Settings scene hierarchy with GodotIQ**

Use structured scene tooling only:

```text
file_context(file="res://Scenes/world_run_start.tscn", detail="normal")
```

Open `world_run_start.tscn` in the editor, then add in one validated `node_ops` batch:

```text
SettingsCenter (CenterContainer, full-rect anchors)
└── SettingsScreen (PanelContainer, unique name, min 520×420)
    └── SettingsMargin (MarginContainer, 32px margins)
        └── SettingsVBox (VBoxContainer, 16px separation)
            ├── SettingsTitle (Label, text "Settings", centered, 32px font)
            ├── ResolutionLabel (Label, text "Resolution")
            ├── ResolutionOption (OptionButton, unique name, min height 48)
            ├── DisplayModeLabel (Label, text "Display Mode")
            ├── DisplayModeOption (OptionButton, unique name, min height 48)
            ├── SettingsStatusLabel (Label, unique name, centered, autowrap, min height 44)
            └── SettingsButtons (HBoxContainer, centered, 12px separation)
                ├── ApplySettingsButton (Button, unique name, text "Apply", min 140×48)
                └── BackSettingsButton (Button, unique name, text "Back", min 140×48)
```

Add `SettingsButton` to the existing main-menu button container immediately before Exit, with text `Settings`, unique name, and the same minimum size/theme as its sibling buttons. Set `SettingsCenter.visible=false` initially. Populate the two `OptionButton` item lists in the scene, not dynamically in code. Set explicit focus neighbors in visual order: Resolution → Display Mode → Apply → Back → Resolution.

Call `save_scene()`, then re-run `file_context` to confirm 69 nodes (54 baseline plus the exact 15 nodes above, adjusting only if Godot inserts no implicit nodes) and all required unique names.

- [ ] **Step 4: Wire selectors, status semantics, and navigation in the launcher**

Before patching, run `file_context` and `impact_check` for `_ready` and `_show_screen`. Add typed `@onready` references for the seven unique controls and `SettingsCenter`. Connect Settings, Apply, and Back in `_ready`.

Implement these helpers through `godotiq_script_ops(op="patch")`:

```gdscript
func on_settings_pressed() -> void:
    open_settings()


func on_apply_settings_pressed() -> void:
    var resolutions: Array[Vector2i] = _display_settings.call("get_supported_resolutions")
    var modes: Array[int] = _display_settings.call("get_supported_modes")
    if (
        _resolution_option.selected < 0
        or _resolution_option.selected >= resolutions.size()
        or _display_mode_option.selected < 0
        or _display_mode_option.selected >= modes.size()
    ):
        _settings_status_label.text = "Unable to apply unsupported display settings."
        return
    var result := apply_display_settings(
        resolutions[_resolution_option.selected],
        modes[_display_mode_option.selected]
    )
    if not bool(result.get("ok", false)):
        _settings_status_label.text = "Unable to apply unsupported display settings."
    elif not bool(result.get("save_ok", false)):
        _settings_status_label.text = "Display changed, but settings could not be saved. Try Apply again."
    else:
        _settings_load_status = &"ok"
        _settings_status_label.text = "Display settings applied."


func on_back_settings_pressed() -> void:
    back_from_settings()


func _sync_settings_controls() -> void:
    var config := get_display_settings_config()
    var resolutions: Array[Vector2i] = _display_settings.call("get_supported_resolutions")
    var modes: Array[int] = _display_settings.call("get_supported_modes")
    _resolution_option.select(resolutions.find(config.get("resolution", Vector2i.ZERO)))
    _display_mode_option.select(modes.find(int(config.get("mode", -1))))
    if _settings_load_status == &"defaults_restored":
        _settings_status_label.text = "Saved display settings could not be loaded. Defaults restored."
    elif _settings_status_label.text != "Display settings applied.":
        _settings_status_label.text = ""
```

Update `_show_screen` so Main, New Run, Settings, and overwrite modal visibility are mutually coherent. On `SETTINGS`, call `_sync_settings_controls()` and focus `_resolution_option`. On Settings Back, call `_sync_settings_controls()` before leaving or rely on it when reopening; in either case pending selector edits must never mutate committed state.

Update `_set_launcher_surface_visible` so `SettingsCenter` follows the launcher surface and never remains visible over the world runtime.

- [ ] **Step 5: Validate the scene and each changed script, then run focused tests**

```text
validate(target="res://Scenes/world_run_start.tscn", detail="normal")
validate(target="res://Scripts/Run/world_production_launcher.gd", detail="brief")
check_errors(scope="file:res://Scripts/Run/world_production_launcher.gd")
validate(target="res://Tests/UI/test_world_run_start_scene.gd", detail="brief")
check_errors(scope="file:res://Tests/UI/test_world_run_start_scene.gd")
```

```powershell
godot --headless --path . --script res://Tests/Settings/test_display_settings_service.gd
godot --headless --path . --script res://Tests/Run/test_world_production_launcher.gd
godot --headless --path . --script res://Tests/UI/test_world_run_start_scene.gd
```

Expected: all exit `0`; scene output contains `PASS test_world_run_start_scene`; no existing launcher behavior regresses.

- [ ] **Step 6: Run visual QA at the smallest resolution**

Use GodotIQ:

```text
run(action="play")
verify_project_runs()
read_debug_console()
ui_map()
explore(mode="tour")
```

Set Windowed 1280×720 via the Settings UI and Apply. Confirm Main and Settings have no clipping, the selectors and buttons are readable, focus order is correct, and no control overlaps. If visual issues are found, fix the scene through `node_ops`, `save_scene()`, and repeat the tour. Stop the game after the verification point.

- [ ] **Step 7: Commit the UI slice**

```powershell
git add -- Scenes/world_run_start.tscn Scripts/Run/world_production_launcher.gd Tests/Run/test_world_production_launcher.gd Tests/UI/test_world_run_start_scene.gd
git commit -m "feat: add main menu display settings screen"
```

### Task 5: Complete regression, persistence, and resolution verification

**Files:**

- Verify: all files changed by Tasks 1–4
- Create: `Docs/Specs/DisplaySettings/Evidence/2026-09-04/automated-test.log`
- Create: `Docs/Specs/DisplaySettings/Evidence/2026-09-04/manual-runtime-check.md`
- Create: `Docs/Specs/DisplaySettings/Evidence/2026-09-04/implementation-link.txt`

- [ ] **Step 1: Run the automated regression set**

Run each command independently and capture complete output:

```powershell
godot --headless --path . --script res://Tests/Settings/test_display_settings_service.gd
godot --headless --path . --script res://Tests/Run/test_world_production_launcher.gd
godot --headless --path . --script res://Tests/UI/test_world_run_start_scene.gd
godot --headless --path . --script res://Tests/UI/test_world_map_hud.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_scene.gd
godot --headless --path . --script res://Tests/Run/test_world_cutover_entry.gd
```

Expected: every runner exits `0`. The HUD and battle UI regressions are required because their viewport assumptions are the highest risk when moving from the historical 1152×648 evidence size.

- [ ] **Step 2: Run the full GodotIQ project gate**

```text
validate(target="project", detail="normal")
check_errors(scope="project")
signal_map(find="orphans")
```

Expected: no new errors, parser failures, incomplete controls, or orphaned settings signals. Compare validation results to the Task 1 baseline and document unrelated pre-existing findings separately.

- [ ] **Step 3: Execute the six-combination runtime matrix**

Start the game through GodotIQ. For each combination below, select the values, press Apply, inspect state with `ui_map`, check the debug console, and record PASS/FAIL:

| ID | Resolution | Mode | Expected |
|---|---:|---|---|
| D1 | 1280×720 | Windowed | Window is exactly 1280×720; Main and Settings fit |
| D2 | 1920×1080 | Windowed | Window is exactly 1920×1080; Main and Settings fit |
| D3 | 2560×1440 | Windowed | Window is exactly 2560×1440; Main and Settings fit |
| D4 | 1280×720 preferred | Fullscreen | Fullscreen activates; preferred size remains 1280×720 |
| D5 | 1920×1080 preferred | Fullscreen | Fullscreen activates; preferred size remains 1920×1080 |
| D6 | 2560×1440 preferred | Fullscreen | Fullscreen activates; preferred size remains 2560×1440 |

After each fullscreen case, switch to Windowed and confirm the window returns to that case's exact preferred size. Use at most one screenshot per windowed resolution; `state_inspect`/`ui_map` should supply data evidence.

- [ ] **Step 4: Verify restart persistence and non-Apply behavior**

Apply 1280×720 Fullscreen, stop the game, relaunch, and confirm both selectors and actual mode reload as 1280×720 preferred Fullscreen. Switch selectors to 2560×1440 Windowed, press Back without Apply, reopen Settings, and confirm 1280×720 Fullscreen remains committed. Finally Apply 1920×1080 Windowed so the developer workspace is left at the canonical default.

- [ ] **Step 5: Inspect representative gameplay surfaces**

At 1280×720 Windowed, verify through the normal launcher flow:

- Main menu and Settings screen;
- New Run commander screen and skill tooltip;
- world-map HUD, party panel, minimap, and encounter overlay;
- battle arena, four-skill inspector, tooltip clamping, result/reward overlay.

Expected: all surfaces remain usable without clipping or overlap and the debugger contains zero new runtime/script errors. Any failure blocks completion and must be fixed with a focused test first.

- [ ] **Step 6: Record evidence and tested commit**

Create the three evidence files. `manual-runtime-check.md` must include date, branch, Godot version, OS, the D1–D6 table, restart result, Back-without-Apply result, representative-surface results, debugger state, and screenshot paths. `automated-test.log` must contain commands, exits, and PASS output. After implementation commits are stable, write the tested commit SHA to `implementation-link.txt`; all evidence must name that same SHA.

- [ ] **Step 7: Run final verification before completion**

Re-run the three focused tests plus the GodotIQ project gate after evidence changes. Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only the intended implementation and evidence files are staged. Existing unrelated untracked `.tmp`, `.import`, and `.uid` files remain untouched and unstaged.

- [ ] **Step 8: Commit evidence**

```powershell
git add -- Docs/Specs/DisplaySettings/Evidence/2026-09-04
git commit -m "test: record display settings verification"
```

Do not push unless the user requests remote handoff or review.
