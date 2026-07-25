# AC1.5 Sudden Death Boss Pursuit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Activate Sudden Death on accepted player move 15, then move the boss one deterministic shortest-path step after each accepted move beginning with move 16 until either side triggers the Boss encounter.

**Architecture:** `HexMapModel` provides pure hex-distance and deterministic next-step queries using `NEIGHBOR_OFFSETS` as the tie-break authority. `MapController` owns threshold state, turn ordering, runtime Boss identity, marker refresh, engagement, encounter lifecycle, and reset behavior. A single headless AC1.5 test asset names every model and controller requirement.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ structured script tooling, existing headless `SceneTree` tests.

---

## File Structure

- Create: `Tests/Map/test_ac1_5_sudden_death.gd`
  - Four pure model cases and nine controller integration cases named in the approved design.
- Modify: `Scripts/Map/hex_map_model.gd`
  - Pure `get_hex_distance()` and `get_pursuit_step()` queries.
- Modify: `Scripts/Map/map_controller.gd`
  - Sudden Death state, runtime encounter identity, turn ordering, pursuit, engagement, and complete run reset.
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Mark AC1.5 complete only after automated, runtime, and evidence gates pass.
- Create: `Docs/Specs/AC1/Evidence/AC1.5/2026-07-25/automated-test.log`
- Create: `Docs/Specs/AC1/Evidence/AC1.5/2026-07-25/manual-runtime-check.md`
- Create: `Docs/Specs/AC1/Evidence/AC1.5/2026-07-25/implementation-link.txt`

### Task 1: Establish the Implementation Branch

- [ ] **Step 1: Confirm the approved planning baseline**

Run:

```powershell
git status --short --branch
git log -3 --oneline
```

Expected: the AC1.5 design, source verification alignment, and this plan are committed with no unrelated changes.

- [ ] **Step 2: Update `main` and create the implementation branch**

Run:

```powershell
git switch main
git pull --ff-only origin main
git switch -c feature/ac1-5-sudden-death
```

Expected: the feature branch starts from current `origin/main`. If the planning commit is not yet integrated, integrate or push it before branching; do not discard it or copy unrelated changes.

### Task 2: Specify the Failing AC1.5 Contract

**Files:**

- Create: `Tests/Map/test_ac1_5_sudden_death.gd`
- Reference: `Docs/superpowers/specs/2026-07-25-ac1-5-sudden-death-design.md`

- [ ] **Step 1: Inspect affected Godot APIs and impact**

Use GodotIQ:

```text
file_context(res://Scripts/Map/hex_map_model.gd, detail=brief)
file_context(res://Scripts/Map/map_controller.gd, detail=brief)
impact_check(res://Scripts/Map/hex_map_model.gd, add_function, get_pursuit_step)
impact_check(res://Scripts/Map/map_controller.gd, modify_function, request_move)
validate(project, detail=brief)
```

Expected: `HexMapModel` remains a pure `RefCounted` model, while `MapController.request_move(Vector2i) -> bool` remains the accepted-move authority.

- [ ] **Step 2: Create the typed headless test harness through GodotIQ**

Create `Tests/Map/test_ac1_5_sudden_death.gd` with `class_name Ac1_5SuddenDeathTests`, `extends SceneTree`, and these exact cases:

```gdscript
const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 13

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pursuit_step_is_adjacent_and_reduces_distance()
	_test_pursuit_tie_break_uses_neighbor_order()
	_test_pursuit_step_is_deterministic()
	_test_invalid_or_equal_endpoints_stay_put()

	var controller := await _instantiate_world()
	if controller != null:
		_test_moves_before_threshold_keep_boss_idle(controller)
		_test_move_fifteen_activates_without_pursuit(controller)
		_test_move_sixteen_starts_one_step_pursuit(controller)
		_test_each_later_accepted_move_advances_once(controller)
		_test_rejected_and_blocked_moves_do_not_advance_pursuit(controller)
		_test_player_entering_boss_coord_triggers_boss_encounter(controller)
		_test_boss_reaching_player_triggers_boss_encounter(controller)
		_test_runtime_boss_identity_moves_and_vacated_origin_is_safe(controller)
		_test_set_run_id_resets_sudden_death(controller)
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
		print("AC1.5 sudden death tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

Use controller helpers that close each expected ordinary overlay before the next accepted move. Build deterministic player routes from `HexMapModel.get_neighbors()` rather than screen coordinates or timing. Each named test resets through `set_run_id("ac1-5-fixture")` so cases do not share pursuit state.

- [ ] **Step 3: Encode exact assertions**

The four model tests call:

```gdscript
model.get_hex_distance(from_coord, to_coord)
model.get_pursuit_step(from_coord, to_coord)
```

They assert adjacency, distance reduction by one, `NEIGHBOR_OFFSETS` tie-breaking, repeatability, and source-coordinate fallback for equal or invalid endpoints.

The nine controller tests call:

```gdscript
controller.is_sudden_death_active()
controller.get_runtime_encounter_type_at(coord)
controller.request_move(destination)
controller.has_active_encounter()
controller.get_active_encounter()
controller.close_active_encounter()
```

They assert the exact move-14/15/16 boundary, one boss step per later accepted move, no mutation on rejected or blocked requests, engagement in both directions, moving Boss identity, Safe vacated origin, and reset of `player_coord`, `boss_coord`, `move_count`, active overlay, and Sudden Death.

- [ ] **Step 4: Validate and prove the test fails**

Use:

```text
validate(res://Tests/Map/test_ac1_5_sudden_death.gd, detail=brief)
check_errors(res://Tests/Map/test_ac1_5_sudden_death.gd)
```

Then run:

```powershell
godot --headless --path . --script Tests/Map/test_ac1_5_sudden_death.gd
```

Expected: FAIL because `get_hex_distance`, `get_pursuit_step`, `is_sudden_death_active`, and `get_runtime_encounter_type_at` do not yet exist.

- [ ] **Step 5: Commit the red contract**

```powershell
git add Tests/Map/test_ac1_5_sudden_death.gd
git commit -m "test: specify AC1.5 sudden death pursuit"
```

### Task 3: Add Deterministic Pursuit Queries

**Files:**

- Modify: `Scripts/Map/hex_map_model.gd`
- Test: `Tests/Map/test_ac1_5_sudden_death.gd`

- [ ] **Step 1: Add pure distance and pursuit functions through GodotIQ**

Insert after `are_adjacent()`:

```gdscript
func get_hex_distance(from_coord: Vector2i, to_coord: Vector2i) -> int:
	if not is_valid_coord(from_coord) or not is_valid_coord(to_coord):
		return -1
	var delta := to_coord - from_coord
	return int((abs(delta.x) + abs(delta.y) + abs(delta.x + delta.y)) / 2)


func get_pursuit_step(from_coord: Vector2i, to_coord: Vector2i) -> Vector2i:
	if not is_valid_coord(from_coord) or not is_valid_coord(to_coord):
		return from_coord
	if from_coord == to_coord:
		return from_coord

	var best_coord := from_coord
	var best_distance := get_hex_distance(from_coord, to_coord)
	for neighbor: Vector2i in get_neighbors(from_coord):
		var neighbor_distance := get_hex_distance(neighbor, to_coord)
		if neighbor_distance < best_distance:
			best_coord = neighbor
			best_distance = neighbor_distance
	return best_coord
```

Because `get_neighbors()` preserves `NEIGHBOR_OFFSETS` order and replacement occurs only for a strictly smaller distance, the first equal-distance best candidate wins.

- [ ] **Step 2: Validate the model**

Use:

```text
validate(res://Scripts/Map/hex_map_model.gd, detail=brief)
check_errors(res://Scripts/Map/hex_map_model.gd)
```

Expected: no convention or parser errors.

- [ ] **Step 3: Run the AC1.5 test**

Run:

```powershell
godot --headless --path . --script Tests/Map/test_ac1_5_sudden_death.gd
```

Expected: the four model cases pass; controller cases still fail on missing Sudden Death APIs.

- [ ] **Step 4: Commit the model unit**

```powershell
git add Scripts/Map/hex_map_model.gd Tests/Map/test_ac1_5_sudden_death.gd
git commit -m "feat: add deterministic boss pursuit query"
```

### Task 4: Integrate Sudden Death Turn Ordering

**Files:**

- Modify: `Scripts/Map/map_controller.gd`
- Test: `Tests/Map/test_ac1_5_sudden_death.gd`

- [ ] **Step 1: Reinspect controller impact**

Use GodotIQ:

```text
file_context(res://Scripts/Map/map_controller.gd, detail=brief)
impact_check(res://Scripts/Map/map_controller.gd, modify_function, request_move)
impact_check(res://Scripts/Map/map_controller.gd, modify_function, set_run_id)
validate(project, detail=brief)
```

Record the baseline before editing.

- [ ] **Step 2: Add typed state and inspection APIs**

Add:

```gdscript
const SUDDEN_DEATH_MOVE_THRESHOLD := 15

var _sudden_death_active: bool = false


func is_sudden_death_active() -> bool:
	return _sudden_death_active


func get_runtime_encounter_type_at(coord: Vector2i) -> String:
	if not _model.is_valid_coord(coord):
		return HexMapModel.ENCOUNTER_NONE
	if coord == boss_coord:
		return HexMapModel.ENCOUNTER_BOSS
	if coord == _model.get_boss_coord():
		return HexMapModel.ENCOUNTER_SAFE
	return get_encounter_type_at(coord)
```

Keep `get_encounter_type_at()` as the immutable seeded-layout query required by AC1.2. Use `get_runtime_encounter_type_at()` for tile state and overlays.

- [ ] **Step 3: Make `set_run_id()` a complete run reset**

After normalizing the Run ID, close the active overlay and reset:

```gdscript
close_active_encounter()
player_coord = _model.get_start_coord()
boss_coord = _model.get_boss_coord()
move_count = 0
_sudden_death_active = false
encounter_types = _model.get_encounter_types_for_run(run_id)
_refresh_visual_state()
```

The `_model == null` guard remains before model access.

- [ ] **Step 4: Replace the accepted-move tail with explicit turn resolution**

After player mutation:

```gdscript
player_coord = destination
move_count += 1
_refresh_visual_state()

if player_coord == boss_coord:
	_open_encounter(destination, HexMapModel.ENCOUNTER_BOSS)
	return true

if move_count == SUDDEN_DEATH_MOVE_THRESHOLD:
	_sudden_death_active = true
elif _sudden_death_active and move_count > SUDDEN_DEATH_MOVE_THRESHOLD:
	boss_coord = _model.get_pursuit_step(boss_coord, player_coord)
	_refresh_visual_state()
	if boss_coord == player_coord:
		_open_encounter(destination, HexMapModel.ENCOUNTER_BOSS)
		return true

_open_encounter(destination, get_runtime_encounter_type_at(destination))
return true
```

Change `_open_encounter` to accept the resolved type:

```gdscript
func _open_encounter(destination: Vector2i, encounter_type: String) -> void:
```

and configure with:

```gdscript
overlay.configure(destination, encounter_type)
```

Update `_get_tile_state_for_encounter()` to match on `get_runtime_encounter_type_at(coord)`.

- [ ] **Step 5: Validate and run the focused test**

Use:

```text
validate(res://Scripts/Map/map_controller.gd, detail=brief)
check_errors(res://Scripts/Map/map_controller.gd)
```

Run:

```powershell
godot --headless --path . --script Tests/Map/test_ac1_5_sudden_death.gd
```

Expected: `AC1.5 sudden death tests: PASS (13/13)`.

- [ ] **Step 6: Commit controller integration**

```powershell
git add Scripts/Map/map_controller.gd Tests/Map/test_ac1_5_sudden_death.gd
git commit -m "feat: activate AC1.5 sudden death pursuit"
```

### Task 5: Run Regression and Architecture Gates

- [ ] **Step 1: Run every map test independently**

Run:

```powershell
Get-ChildItem Tests/Map/*.gd | ForEach-Object {
    & godot --headless --path . --script $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every script exits `0`; AC1.5 reports `PASS (13/13)`.

- [ ] **Step 2: Run structured project checks**

Use GodotIQ:

```text
validate(project, detail=brief)
check_errors(project)
signal_map(all, find=orphans, detail=brief)
```

Expected: no new convention, parser, or signal-wiring failures.

- [ ] **Step 3: Commit any necessary fixture-only alignment**

If an older test requires a reset helper because `set_run_id()` now performs a complete run reset, edit only that test after `file_context(detail=brief)`, validate/check it individually, rerun the full suite, and commit:

```powershell
git add Tests/Map
git commit -m "test: align map fixtures with AC1.5 reset"
```

Do not weaken production reset behavior to preserve stale fixture assumptions.

### Task 6: Runtime Verification and Evidence

**Files:**

- Create: `Docs/Specs/AC1/Evidence/AC1.5/2026-07-25/automated-test.log`
- Create: `Docs/Specs/AC1/Evidence/AC1.5/2026-07-25/manual-runtime-check.md`
- Create: `Docs/Specs/AC1/Evidence/AC1.5/2026-07-25/implementation-link.txt`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`

- [ ] **Step 1: Verify startup health**

Use GodotIQ:

```text
run(play, scene=main, detail=brief)
verify_project_runs()
read_debug_console()
```

Expected: the main scene starts with no parser or runtime errors.

- [ ] **Step 2: Execute the manual AC1.5 route**

Using real pointer input, close each ordinary overlay and record:

1. Boss position after accepted moves 1–14.
2. Sudden Death state and boss position after move 15.
3. Player and boss positions immediately after move 16.
4. One boss step after every later accepted move.
5. The repeated route for the same Run ID.
6. The Boss overlay when either side reaches the other.
7. Reset state after changing the Run ID.

Use `state_inspect` for `player_coord`, `boss_coord`, `move_count`, and `_sudden_death_active`; use `verify_motion` for the boss marker when motion evidence is needed. Stop the game after verification.

- [ ] **Step 3: Capture evidence**

Write the complete map-suite output to `automated-test.log`. Record the Godot version, scene, Run ID, move-by-move coordinates, expected/observed results, and PASS/FAIL status in `manual-runtime-check.md`.

Record branch, final implementation commit, source spec, design spec, plan, and PR status in `implementation-link.txt`.

- [ ] **Step 4: Run final gates**

Use:

```text
validate(project, detail=brief)
check_errors(project)
signal_map(all, find=orphans, detail=brief)
run(play, scene=main, detail=brief)
verify_project_runs()
read_debug_console()
run(stop, detail=brief)
```

Expected: no new convention, parser, signal, startup, or runtime failures.

- [ ] **Step 5: Mark AC1.5 complete and commit evidence**

Only after all automated, manual, and structured gates pass, change AC1.5 from `[ ]` to `[x]`.

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC1/Evidence/AC1.5
git commit -m "docs: record AC1.5 verification evidence"
```

## Self-Review

- Spec coverage: all 13 named cases map to the approved AC1.5 design and its traceability matrix.
- Placeholder scan: implementation steps contain exact APIs, code, commands, expected results, and evidence locations.
- Type consistency: `get_hex_distance(Vector2i, Vector2i) -> int`, `get_pursuit_step(Vector2i, Vector2i) -> Vector2i`, `is_sudden_death_active() -> bool`, and `get_runtime_encounter_type_at(Vector2i) -> String` are consistent across tests and implementation.
- Authority consistency: `get_encounter_type_at()` remains seeded AC1.2 authority; `get_runtime_encounter_type_at()` owns moving Boss identity for AC1.5.
- Timing consistency: move 15 activates without pursuit; move 16 is the first pursuit step.
- Scope: no combat resolution, boss statistics, animation, save/load, or post-battle behavior is introduced.
