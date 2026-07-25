# AC1.4 Encounter Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open one input-blocking Encounter overlay with the correct seeded type after every accepted map move, then let `Close (Debug)` restore navigation without changing map state.

**Architecture:** A dedicated `EncounterOverlay` CanvasLayer owns presentation and emits a close request. `MapController` remains authoritative for movement, stores the sole active overlay reference, rejects movement while that reference is valid, and opens the overlay only after a move commits. The overlay is attached under the existing `UI` CanvasLayer in `game_world.tscn` so draw order and input ownership stay unambiguous.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ structured scene/script tooling, existing headless `SceneTree` tests.

---

## File Structure

- Create: `Scripts/Encounter/encounter_overlay.gd`
  - Typed encounter data, label refresh, and debug close signal.
- Create: `Scenes/encounter_overlay.tscn`
  - Full-viewport input blocker with centered Encounter panel.
- Create: `Tests/Map/test_ac1_4_encounter_overlay.gd`
  - AC1.4 integration and lifecycle tests.
- Modify: `Scripts/Map/map_controller.gd`
  - Active-overlay guard, opening, setup, and closure.
- Modify: `Tests/Map/test_ac1_1_runtime_step_counts.gd`
  - Dismiss expected overlays between sequential moves.
- Modify: `Tests/Map/test_map_controller_runtime.gd`
  - Dismiss expected overlays in multi-move controller fixtures.
- Modify: `Tests/Map/test_ac1_3_mouse_navigation.gd`
  - Close the overlay after the successful click before later navigation assertions.
- Create: `Docs/Specs/AC1/Evidence/AC1.4/2026-07-24/automated-test.log`
- Create: `Docs/Specs/AC1/Evidence/AC1.4/2026-07-24/manual-runtime-check.md`
- Create: `Docs/Specs/AC1/Evidence/AC1.4/2026-07-24/implementation-link.txt`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Check AC1.4 only after all verification and evidence succeed.

### Task 1: Start an Isolated AC1.4 Branch

- [ ] **Step 1: Confirm the documentation baseline is committed**

Run:

```powershell
git status --short --branch
git log -2 --oneline
```

Expected: the aligned AC1.4 source spec, design, implementation spec, and this plan are committed; no unrelated changes are present.

- [ ] **Step 2: Update the integration branch and create the task branch**

Run:

```powershell
git switch main
git pull --ff-only origin main
git switch -c feature/ac1-4-encounter-overlay
```

Expected: the new branch is based on current `origin/main`. If documentation commits exist only locally, push or integrate them before pulling rather than discarding them.

### Task 2: Specify the Failing Encounter Lifecycle

**Files:**

- Create: `Tests/Map/test_ac1_4_encounter_overlay.gd`
- Reference: `Docs/Specs/AC1/AC1.4_ENCOUNTER_OVERLAY_IMPLEMENTATION_SPEC.md`

- [ ] **Step 1: Inspect affected Godot files**

Use GodotIQ:

```text
file_context(res://Scripts/Map/map_controller.gd, detail=brief)
file_context(res://Scenes/game_world.tscn, detail=brief)
impact_check(res://Scripts/Map/map_controller.gd, modify_function, request_move)
```

Expected: `request_move(Vector2i) -> bool` remains the movement authority and `game_world.tscn` uses `MapController`.

- [ ] **Step 2: Create the headless AC1.4 test harness**

Create a typed `SceneTree` test with these exact test cases:

```gdscript
class_name Ac1_4EncounterOverlayTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 6

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := await _instantiate_world()
	if controller != null:
		_test_initial_state_has_no_overlay(controller)
		_test_each_encounter_type_opens_matching_overlay(controller)
		_test_rejected_move_opens_no_overlay(controller)
		_test_active_overlay_blocks_map_state_changes(controller)
		_test_debug_close_preserves_state_and_restores_navigation(controller)
		_test_reentry_opens_once_per_accepted_move(controller)
		controller.queue_free()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _instantiate_world() -> MapController:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	var controller := packed.instantiate() as MapController
	root.add_child(controller)
	await process_frame
	return controller


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC1.4 encounter overlay tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

Use the named tests to assert this public contract:

```gdscript
controller.has_active_encounter()
controller.get_active_encounter()
controller.close_active_encounter()
overlay.encounter_coordinate
overlay.encounter_type
```

For the three-type test, call `controller.set_run_id()` with deterministic fixture IDs until the existing layout supplies reachable Safe and Combat destinations. Select Safe and Combat by inspecting valid adjacent destinations through `controller.get_encounter_type_at()`; do not rely on hard-coded screen positions or random timing. Walk toward Boss while closing each expected overlay. Assert the active overlay's coordinate and type after every accepted move.

- [ ] **Step 3: Run the new test to prove it fails**

Run:

```powershell
godot --headless --path . --script Tests/Map/test_ac1_4_encounter_overlay.gd
```

Expected: FAIL because `MapController` has no active-encounter API and `EncounterOverlay` does not exist.

- [ ] **Step 4: Commit the red test**

```powershell
git add Tests/Map/test_ac1_4_encounter_overlay.gd
git commit -m "test: specify AC1.4 encounter overlay"
```

### Task 3: Build the Encounter Overlay

**Files:**

- Create: `Scripts/Encounter/encounter_overlay.gd`
- Create: `Scenes/encounter_overlay.tscn`

- [ ] **Step 1: Create the overlay script through GodotIQ**

Create:

```gdscript
class_name EncounterOverlay
extends CanvasLayer

signal close_requested

@onready var _encounter_type_label: Label = %EncounterTypeLabel

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""


func _ready() -> void:
	_refresh_text()


func configure(coordinate: Vector2i, type: String) -> void:
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_text()


func _refresh_text() -> void:
	_encounter_type_label.text = encounter_type.capitalize()


func _on_close_debug_pressed() -> void:
	close_requested.emit()
```

Use `script_ops(create)` because this is a new script created during this session.

- [ ] **Step 2: Validate the script**

Use:

```text
validate(res://Scripts/Encounter/encounter_overlay.gd, detail=brief)
check_errors(res://Scripts/Encounter/encounter_overlay.gd)
```

Expected: no convention or parser errors.

- [ ] **Step 3: Build the overlay scene through GodotIQ**

Create `res://Scenes/encounter_overlay.tscn` with:

```text
EncounterOverlay (CanvasLayer, encounter_overlay.gd)
└── InputBlocker (ColorRect, full-rect anchors, mouse_filter=STOP)
    └── CenterContainer (full-rect anchors)
        └── PanelContainer
            └── VBoxContainer
                ├── TitleLabel ("Encounter")
                ├── EncounterTypeLabel (unique_name_in_owner=true)
                └── CloseDebugButton ("Close (Debug)")
```

Connect `CloseDebugButton.pressed` to `_on_close_debug_pressed`. Give `InputBlocker` a translucent background so the map remains recognizable but visibly unavailable. Use `node_ops(validate=true)`, save the scene, then inspect it through `file_context`.

- [ ] **Step 4: Validate and commit the overlay unit**

Use:

```text
validate(res://Scenes/encounter_overlay.tscn, detail=brief)
check_errors(res://Scripts/Encounter/encounter_overlay.gd)
```

Then:

```powershell
git add Scripts/Encounter/encounter_overlay.gd Scenes/encounter_overlay.tscn
git commit -m "feat: add encounter overlay presentation"
```

### Task 4: Integrate the Overlay with Map Movement

**Files:**

- Modify: `Scripts/Map/map_controller.gd`

- [ ] **Step 1: Reinspect impact before changing the controller**

Use:

```text
file_context(res://Scripts/Map/map_controller.gd, detail=brief)
impact_check(res://Scripts/Map/map_controller.gd, modify_function, request_move)
validate(project, detail=brief)
```

Record the baseline validation counts.

- [ ] **Step 2: Add the overlay state and public inspection contract**

Add:

```gdscript
const ENCOUNTER_OVERLAY_SCENE_PATH := "res://Scenes/encounter_overlay.tscn"

var _encounter_overlay_scene: PackedScene
var _active_encounter_overlay: EncounterOverlay
var _ui_layer: CanvasLayer
```

Load it in `_ready()` with `load()`, then add:

```gdscript
func has_active_encounter() -> bool:
	return is_instance_valid(_active_encounter_overlay)


func get_active_encounter() -> EncounterOverlay:
	return _active_encounter_overlay if has_active_encounter() else null


func close_active_encounter() -> void:
	if not has_active_encounter():
		_active_encounter_overlay = null
		return
	var overlay := _active_encounter_overlay
	_active_encounter_overlay = null
	overlay.queue_free()
```

- [ ] **Step 3: Guard movement before all validation and mutation**

Change the beginning and successful end of `request_move()` to:

```gdscript
func request_move(destination: Vector2i) -> bool:
	if has_active_encounter():
		return false
	if not _model.is_valid_coord(destination):
		return false
	if not _model.are_adjacent(player_coord, destination):
		return false

	player_coord = destination
	move_count += 1
	_refresh_visual_state()
	_open_encounter(destination)
	return true
```

- [ ] **Step 4: Add the single-open lifecycle**

Add:

```gdscript
func _open_encounter(destination: Vector2i) -> void:
	if has_active_encounter():
		return
	var overlay := _encounter_overlay_scene.instantiate() as EncounterOverlay
	_active_encounter_overlay = overlay
	overlay.configure(destination, get_encounter_type_at(destination))
	overlay.close_requested.connect(close_active_encounter, CONNECT_ONE_SHOT)
	_ui_layer.add_child(overlay)
```

The reference assignment precedes `add_child()`, so the movement guard is active before the overlay becomes interactive. Resolve `_ui_layer` from the `UI` CanvasLayer in `game_world.tscn`; create or fail loudly during setup if the scene no longer provides that ownership node.

- [ ] **Step 5: Validate and run the focused test**

Use:

```text
validate(res://Scripts/Map/map_controller.gd, detail=brief)
check_errors(res://Scripts/Map/map_controller.gd)
```

Run:

```powershell
godot --headless --path . --script Tests/Map/test_ac1_4_encounter_overlay.gd
```

Expected: `AC1.4 encounter overlay tests: PASS (6/6)`.

- [ ] **Step 6: Commit the integration**

```powershell
git add Scripts/Map/map_controller.gd Tests/Map/test_ac1_4_encounter_overlay.gd
git commit -m "feat: open encounters after accepted map moves"
```

### Task 5: Adapt Existing Movement Fixtures

**Files:**

- Modify: `Tests/Map/test_ac1_1_runtime_step_counts.gd`
- Modify: `Tests/Map/test_map_controller_runtime.gd`
- Modify: `Tests/Map/test_ac1_3_mouse_navigation.gd`

- [ ] **Step 1: Inspect every affected test with GodotIQ**

Use `file_context(detail=brief)` for all three scripts. Do not change production behavior to preserve a test fixture that now omits a required Close action.

- [ ] **Step 2: Add an explicit fixture dismissal helper**

Add where sequential accepted moves occur:

```gdscript
func _close_expected_encounter(controller: MapController) -> void:
	if not controller.has_active_encounter():
		_failures.append("expected an active encounter after accepted move")
		return
	controller.close_active_encounter()
```

Call it after asserting each accepted move and before requesting the next move. In the AC1.3 test, close after `_test_adjacent_left_click_moves_once()` so subsequent input checks begin with navigation available.

- [ ] **Step 3: Validate and run each changed test separately**

After each script change:

```text
validate(res://Tests/Map/<changed-test>.gd, detail=brief)
check_errors(res://Tests/Map/<changed-test>.gd)
```

Then run that script headlessly. Expected: its existing PASS summary remains unchanged.

- [ ] **Step 4: Run the complete map suite**

Run every `Tests/Map/*.gd` script individually with:

```powershell
Get-ChildItem Tests/Map/*.gd | ForEach-Object {
    & godot --headless --path . --script $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every script exits `0`, including AC1.4 at `PASS (6/6)`.

- [ ] **Step 5: Commit fixture alignment**

```powershell
git add Tests/Map/test_ac1_1_runtime_step_counts.gd Tests/Map/test_map_controller_runtime.gd Tests/Map/test_ac1_3_mouse_navigation.gd
git commit -m "test: align map fixtures with encounter lifecycle"
```

### Task 6: Runtime Verification and Evidence

**Files:**

- Create: `Docs/Specs/AC1/Evidence/AC1.4/2026-07-24/automated-test.log`
- Create: `Docs/Specs/AC1/Evidence/AC1.4/2026-07-24/manual-runtime-check.md`
- Create: `Docs/Specs/AC1/Evidence/AC1.4/2026-07-24/implementation-link.txt`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`

- [ ] **Step 1: Verify startup and runtime health**

Use GodotIQ:

```text
run(play, res://Scenes/game_world.tscn)
verify_project_runs(check_scope=project, stop_after=false)
read_debug_console()
```

Expected: the game starts with no parser/runtime errors and no Encounter overlay at initialization.

- [ ] **Step 2: Perform the manual AC1.4 path with real input**

Use `ui_map` and real pointer input. For Safe, Combat, and Boss fixtures:

1. Click an adjacent destination.
2. Confirm the overlay appears immediately with the matching type.
3. Click the covered map and inspect `player_coord`/`move_count`; neither changes.
4. Click `Close (Debug)`.
5. Confirm the overlay is gone and coordinate/count are unchanged.
6. Continue until all three encounter types have been observed.

Expected: every accepted entry opens once; rejected/background input never mutates state; closing restores navigation.

- [ ] **Step 3: Capture evidence**

Write the complete suite output to `automated-test.log`. Record the Godot version, scene, fixture run ID, coordinates, expected/observed values, and PASS/FAIL table in `manual-runtime-check.md`.

After the final implementation commit exists, obtain its identifier:

```powershell
git rev-parse HEAD
```

Write that exact output to the `Commit:` field in `implementation-link.txt`, together with branch `feature/ac1-4-encounter-overlay`, the source spec, implementation spec, plan paths, and `PR: not opened unless remote review is requested`.

- [ ] **Step 4: Run final project gates**

Use:

```text
validate(project, detail=brief)
check_errors(project)
signal_map(all, find=orphans, detail=brief)
verify_project_runs(scene=main, check_scope=project, stop_after=true)
```

Expected: no new convention, parser, signal, startup, or runtime failures.

- [ ] **Step 5: Mark AC1.4 complete and commit evidence**

Only after Steps 1–4 pass, change AC1.4 from `[ ]` to `[x]`.

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC1/Evidence/AC1.4
git commit -m "docs: record AC1.4 verification evidence"
```

## Self-Review

- Spec coverage: every retained AC1.4 requirement maps to implementation, named automated checks, manual steps, and evidence.
- Placeholder scan: no implementation work is deferred; the evidence hash instruction explicitly requires the actual commit identifier.
- Type consistency: `EncounterOverlay.configure(Vector2i, String)`, `encounter_coordinate: Vector2i`, and `encounter_type: String` match the existing controller encounter API.
- Lifecycle consistency: active-reference assignment precedes interactivity; the guard precedes all movement mutation; closure clears the reference without changing map state.
- Scope: encounter resolution, combat, rewards, persistence, AC1.5, and revisit-consumption rules remain excluded.
