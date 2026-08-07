# Pre-3.1 Active Skills and World Turn Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the battle skill panel locked to the current player or enemy unit for the full turn and show the existing successful world-map move count as a top-left `Turns: N` badge.

**Architecture:** `BattleArena` remains the sole owner of current-turn inspection and restores the skill-panel invariant through one idempotent synchronization helper. `MapController.move_count` remains the sole world-turn value; a scene-owned label renders it through one refresh helper. Two focused headless runners prove the new contracts, while existing AC2.x battle and map runners remain mandatory regressions.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured scene/script operations, PowerShell, Git.

---

## Scope and file map

- Create `Tests/Battle/test_active_turn_skill_lock.gd`: five focused battle lock cases and exact `PASS (5/5)` output.
- Modify `Scripts/Battle/battle_arena.gd`: synchronize the inspector to `get_current_unit()` and reject non-current inspection during active battles.
- Modify `Tests/Battle/test_ac2_6_character_skills.gd`, `Tests/Battle/test_ac2_7_skill_preview.gd`, and `Tests/Battle/test_ac2_8_skill_arena.gd`: replace superseded free-inspection setup with current-turn fixtures; preserve their original assertions otherwise.
- Create `Tests/Map/test_world_turn_counter.gd`: four focused counter cases and exact `PASS (4/4)` output.
- Modify `Scenes/game_world.tscn`: add the scene-owned `%TurnCounterLabel` under `UI` using GodotIQ.
- Modify `Scripts/Map/map_controller.gd`: render `move_count` during ready, accepted move, and run reset.
- Create `Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/{automated-test.log,manual-runtime-check.md,implementation-link.txt}`: one cross-cutting evidence package tied to one implementation SHA.

Do not modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`; this hardening slice creates no MVP AC and changes no checkbox.

### Task 1: Establish the implementation branch and baseline

**Files:**
- Inspect only: repository status, `main`, test inventory, approved design

- [ ] **Step 1: Preserve unrelated work and create the required task branch**

Follow `AGENTS.md`: do not use a worktree. If the primary workspace contains unrelated changes, stash them with an explicit name before switching branches. Then update `main` and create the task branch:

```powershell
git status --short --branch
git stash push --include-untracked -m 'user-work-before-pre-3-1-ui-hardening'
git switch main
git pull --ff-only origin main
git switch -c feat/pre-3-1-active-skills-turn-counter
```

Expected: the new branch is based on current `origin/main`, `git status --short` is empty, and the named stash remains listed. If there are no unrelated changes, omit the stash command. Ensure the approved design and this plan are present on the task branch before implementation; bring over only these two documentation commits/files, not unrelated AC2.9 changes.

- [ ] **Step 2: Run baseline GodotIQ checks**

```text
project_summary(detail="brief")
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
```

Expected: project summary identifies `TwoDimensionExploration`; record existing warnings separately. Stop if parser errors or new orphan signals prevent a reliable baseline.

- [ ] **Step 3: Run the existing regression inventory before edits**

```powershell
$test_scripts = @(
    Get-ChildItem -LiteralPath 'Tests/Battle' -Filter 'test_*.gd' -File
    Get-ChildItem -LiteralPath 'Tests/Map' -Filter 'test_*.gd' -File
) | Sort-Object FullName
foreach ($test_script in $test_scripts) {
    $resource_path = 'res://' + $test_script.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
    & godot --headless --path . --script $resource_path
    if ($LASTEXITCODE -ne 0) { throw "Baseline failed: $resource_path" }
}
```

Expected: every existing runner exits `0`, prints its own `PASS` summary, and prints no `FAILED:` line. Record any pre-existing failure before changing code.

### Task 2: Add the focused active-turn skill lock runner

**Files:**
- Create: `Tests/Battle/test_active_turn_skill_lock.gd`
- Reference: `Scenes/battle_arena.tscn`

- [ ] **Step 1: Inspect the test and arena context through GodotIQ**

```text
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="brief")
file_context(file="res://Tests/Battle/test_ac2_6_character_skills.gd", detail="brief")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="modify function behavior", target="inspect_unit/_refresh_turn_ui")
```

Expected: `BattleArena` owns `get_current_unit`, `inspect_unit`, `advance_turn`, `remove_battle_unit`, and the existing inspector nodes.

- [ ] **Step 2: Create the failing focused runner with GodotIQ `script_ops(op="create")`**

Create a typed `SceneTree` runner with these exact entry points and helpers:

```gdscript
class_name ActiveTurnSkillLockTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 5

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_initial_turn_locks_skill_panel_to_current_unit()
	await _test_non_current_slot_click_cannot_override_active_unit()
	await _test_turn_advance_syncs_skill_panel_for_player_and_enemy()
	await _test_current_unit_removal_rebuilds_queue_and_syncs_skill_panel()
	await _test_no_current_unit_or_battle_end_clears_skill_panel()
	_report()
	quit(1 if not _failures.is_empty() else 0)

func _test_initial_turn_locks_skill_panel_to_current_unit() -> void:
	var arena := await _arena_with_units(_three_turn_units())
	var current := arena.get_current_unit()
	_assert(current.unit_id == &"player_fast"
		and arena.get_inspected_unit_id() == current.unit_id
		and _inspector_name(arena) == current.display_name,
		"initial lock", "initial current unit must own the skill panel")
	_free_arena(arena)

func _test_non_current_slot_click_cannot_override_active_unit() -> void:
	var arena := await _arena_with_units(_three_turn_units())
	var non_current := arena.get_unit_by_id(&"enemy_mid")
	var slot := arena.call("_get_slot_for_unit", non_current) as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	arena.call("_on_slot_gui_input", event, slot)
	_assert(arena.get_inspected_unit_id() == &"player_fast"
		and _inspector_name(arena) == "Player Fast",
		"click override rejection", "non-current slot clicks must not replace the current unit")
	_free_arena(arena)

func _test_turn_advance_syncs_skill_panel_for_player_and_enemy() -> void:
	var arena := await _arena_with_units(_three_turn_units())
	arena.advance_turn()
	var enemy_locked := arena.get_current_unit().unit_id == &"enemy_mid"
		and arena.get_inspected_unit_id() == &"enemy_mid"
		and _inspector_name(arena) == "Enemy Mid"
	arena.advance_turn()
	var player_locked := arena.get_current_unit().unit_id == &"player_slow"
		and arena.get_inspected_unit_id() == &"player_slow"
		and _inspector_name(arena) == "Player Slow"
	_assert(enemy_locked and player_locked, "turn advance sync",
		"player and enemy turn changes must immediately replace inspector ownership")
	_free_arena(arena)

func _test_current_unit_removal_rebuilds_queue_and_syncs_skill_panel() -> void:
	var arena := await _arena_with_units(_three_turn_units())
	var removed := arena.remove_battle_unit(&"player_fast")
	_assert(removed and arena.get_current_unit().unit_id == &"enemy_mid"
		and arena.get_inspected_unit_id() == &"enemy_mid"
		and _inspector_name(arena) == "Enemy Mid",
		"removal rebuild sync", "queue rebuild must lock to its new current unit")
	_free_arena(arena)

func _test_no_current_unit_or_battle_end_clears_skill_panel() -> void:
	var empty_arena := await _arena_with_units([])
	var empty_cleared := empty_arena.get_current_unit() == null
		and empty_arena.get_inspected_unit_id() == &""
		and (empty_arena.get_node("%SkillInspectorPromptLabel") as Label).visible
	_free_arena(empty_arena)
	var finisher := _unit(&"finisher", "Finisher", BattleUnitState.Side.PLAYER, 20, 20)
	var victim := _unit(&"victim", "Victim", BattleUnitState.Side.ENEMY, 10, 1)
	var finished_arena := await _arena_with_units([finisher, victim])
	finished_arena.perform_debug_damage()
	await process_frame
	var end_cleared := finished_arena.is_battle_complete()
		and finished_arena.get_inspected_unit_id() == &""
		and (finished_arena.get_node("%SkillInspectorPromptLabel") as Label).visible
	_assert(empty_cleared and end_cleared, "no current or battle end",
		"empty and terminal battles must not retain stale skills")
	_free_arena(finished_arena)

func _arena_with_units(units: Array) -> BattleArena:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var typed: Array[BattleUnitState] = []
	for unit: BattleUnitState in units:
		typed.append(unit)
	arena.configure_units(typed)
	await process_frame
	return arena

func _three_turn_units() -> Array[BattleUnitState]:
	return [
		_unit(&"player_fast", "Player Fast", BattleUnitState.Side.PLAYER, 30),
		_unit(&"enemy_mid", "Enemy Mid", BattleUnitState.Side.ENEMY, 20),
		_unit(&"player_slow", "Player Slow", BattleUnitState.Side.PLAYER, 10),
	]

func _unit(id: StringName, display_name: String, side: BattleUnitState.Side,
		speed: int, hp: int = 20) -> BattleUnitState:
	var skill := CharacterSkill.new(&"probe", "Probe", CharacterSkill.Kind.PASSIVE,
		"Test effect.", "Test target.", "None", "None")
	var skills: Array[CharacterSkill] = [skill]
	return BattleUnitState.new(id, display_name, side, 0, speed, hp, skills)

func _inspector_name(arena: BattleArena) -> String:
	return (arena.get_node("%SkillInspectorUnitNameLabel") as Label).text

func _free_arena(arena: BattleArena) -> void:
	if is_instance_valid(arena):
		arena.queue_free()

func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])

func _report() -> void:
	if _failures.is_empty():
		print("Active-turn skill lock tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

- [ ] **Step 3: Validate the new test and prove RED**

```text
validate(target="res://Tests/Battle/test_active_turn_skill_lock.gd", detail="brief")
check_errors(scope="res://Tests/Battle/test_active_turn_skill_lock.gd")
```

```powershell
godot --headless --path . --script res://Tests/Battle/test_active_turn_skill_lock.gd
```

Expected: parser checks pass, but the runner exits nonzero with `FAILED:` entries for initial lock, click rejection, turn synchronization, queue rebuild synchronization, and terminal clearing. Parser errors do not count as RED.

### Task 3: Enforce active-turn inspector ownership

**Files:**
- Modify: `Scripts/Battle/battle_arena.gd` near `inspect_unit`, `_refresh_turn_ui`, and inspector helpers
- Test: `Tests/Battle/test_active_turn_skill_lock.gd`

- [ ] **Step 1: Re-read context and run impact analysis immediately before editing**

```text
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="brief")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="add helper and change inspection behavior", target="inspect_unit/_refresh_turn_ui")
```

- [ ] **Step 2: Add the idempotent synchronization helper with `script_ops(op="patch")`**

Add this helper beside the existing inspector refresh functions:

```gdscript
func _sync_skill_inspector_to_current_turn() -> void:
	if _battle_outcome != BattleOutcome.Type.IN_PROGRESS:
		_clear_skill_inspector()
		return
	var current_unit := get_current_unit()
	if not is_instance_valid(current_unit) or not current_unit.is_active():
		_clear_skill_inspector()
		return
	if _inspected_unit_id != current_unit.unit_id:
		_selected_skill_id = &""
		_hide_skill_tooltip()
		_skill_transaction.reset()
	_inspected_unit_id = current_unit.unit_id
	_refresh_skill_inspector()
```

Patch `inspect_unit` so active battles always resolve to the current unit:

```gdscript
func inspect_unit(unit_id: StringName) -> void:
	if _battle_outcome == BattleOutcome.Type.IN_PROGRESS:
		_sync_skill_inspector_to_current_turn()
		return
	var unit := get_unit_by_id(unit_id)
	if not is_instance_valid(unit):
		_clear_skill_inspector()
		return
	_selected_skill_id = &""
	_inspected_unit_id = unit.unit_id
	_refresh_skill_inspector()
```

Call `_sync_skill_inspector_to_current_turn()` once inside `_refresh_turn_ui()` after queue/current/outcome state is authoritative and before final highlight rendering. Do not add separate state stores or signals. Because `configure_units`, `advance_turn`, `remove_battle_unit`, and completion already converge on `_refresh_turn_ui()`, this one call is the transition seam.

- [ ] **Step 3: Validate the changed script**

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_arena.gd")
```

Expected: no new convention or parser errors.

- [ ] **Step 4: Run the focused runner to prove GREEN**

```powershell
godot --headless --path . --script res://Tests/Battle/test_active_turn_skill_lock.gd
```

Expected: exit `0` and `Active-turn skill lock tests: PASS (5/5)`.

- [ ] **Step 5: Commit the focused battle behavior**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_active_turn_skill_lock.gd
git diff --cached --check
git commit -m "feat: lock skill panel to active battle unit"
```

### Task 4: Align historical battle UI tests with the locked contract

**Files:**
- Modify: `Tests/Battle/test_ac2_6_character_skills.gd`
- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_arena.gd`

- [ ] **Step 1: Inspect all affected test contexts through GodotIQ**

Run `file_context(detail="brief")` for all three files, then use `script_ops(op="read")` to review only the affected test functions. The known dynamic inspection callers are in:

```text
Tests/Battle/test_ac2_6_character_skills.gd
Tests/Battle/test_ac2_7_skill_preview.gd
Tests/Battle/test_ac2_8_skill_arena.gd
```

- [ ] **Step 2: Replace free inspection setup with current-turn fixtures**

In tests that need a named unit's skill UI, advance the arena deterministically until that unit owns the turn before asserting. Use this exact helper instead of weakening production locking or mutating unit speed:

```gdscript
func _advance_until_current(arena: BattleArena, unit_id: StringName) -> bool:
	for _index: int in arena.get_turn_queue().size():
		var current := arena.get_current_unit()
		if is_instance_valid(current) and current.unit_id == unit_id:
			return true
		arena.advance_turn()
	return false
```

Where a test needs to switch from one inspected unit to another, configure a fresh fixture with the second unit current; do not call `inspect_unit()` to bypass the new invariant. Update superseded assertions as follows:

- AC2.6 initial inspector expectation becomes the initial current unit, not neutral.
- AC2.6 empty-slot input remains a no-op and must preserve the current unit.
- AC2.6 reconfiguration expects the newly configured current unit, unless the roster is empty.
- AC2.6 defeated-unit inspection cases use a currently acting fixture before defeat; after terminal defeat they expect the inspector cleared.
- AC2.7 tooltip tests make `player_0` or `player_4` current before hovering their buttons.
- AC2.8 arena tests make `player_ui` current before selecting its skill.

Do not change skill metadata, targeting rules, tooltip text, damage, cooldown, combo, or transaction expectations.

- [ ] **Step 3: Validate each changed test separately**

```text
validate(target="res://Tests/Battle/test_ac2_6_character_skills.gd", detail="brief")
check_errors(scope="res://Tests/Battle/test_ac2_6_character_skills.gd")
validate(target="res://Tests/Battle/test_ac2_7_skill_preview.gd", detail="brief")
check_errors(scope="res://Tests/Battle/test_ac2_7_skill_preview.gd")
validate(target="res://Tests/Battle/test_ac2_8_skill_arena.gd", detail="brief")
check_errors(scope="res://Tests/Battle/test_ac2_8_skill_arena.gd")
```

- [ ] **Step 4: Run the focused test and all battle regressions**

```powershell
$battle_tests = Get-ChildItem -LiteralPath 'Tests/Battle' -Filter 'test_*.gd' -File | Sort-Object FullName
foreach ($test_script in $battle_tests) {
    $resource_path = 'res://' + $test_script.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
    & godot --headless --path . --script $resource_path
    if ($LASTEXITCODE -ne 0) { throw "Battle regression failed: $resource_path" }
}
```

Expected: all runners exit `0`, every runner prints `PASS`, the focused runner prints `Active-turn skill lock tests: PASS (5/5)`, and no output contains `FAILED:`.

- [ ] **Step 5: Commit regression alignment**

```powershell
git add -- Tests/Battle/test_ac2_6_character_skills.gd Tests/Battle/test_ac2_7_skill_preview.gd Tests/Battle/test_ac2_8_skill_arena.gd
git diff --cached --check
git commit -m "test: align battle UI suites with active-turn lock"
```

### Task 5: Add the focused world turn counter runner

**Files:**
- Create: `Tests/Map/test_world_turn_counter.gd`
- Reference: `Scenes/game_world.tscn`

- [ ] **Step 1: Inspect map context before creating the test**

```text
file_context(file="res://Scripts/Map/map_controller.gd", detail="brief")
file_context(file="res://Scenes/game_world.tscn", detail="brief")
file_context(file="res://Tests/Map/test_map_controller_runtime.gd", detail="brief")
```

- [ ] **Step 2: Create the failing focused runner with GodotIQ `script_ops(op="create")`**

```gdscript
class_name WorldTurnCounterTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const EXPECTED_TEST_COUNT := 4

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _test_turn_counter_starts_at_zero()
	await _test_accepted_move_increments_turn_counter_once()
	await _test_rejected_move_leaves_turn_counter_unchanged()
	await _test_set_run_id_resets_turn_counter_to_zero()
	_report()
	quit(1 if not _failures.is_empty() else 0)

func _test_turn_counter_starts_at_zero() -> void:
	var world := await _instantiate_world()
	_assert(_counter_text(world) == "Turns: 0", "initial zero text",
		"new world must render zero successful moves")
	_free_world(world)

func _test_accepted_move_increments_turn_counter_once() -> void:
	var world := await _instantiate_world()
	var moved := world.request_move(Vector2i(1, 0))
	_assert(moved and world.move_count == 1 and _counter_text(world) == "Turns: 1",
		"accepted move increment text", "one accepted move must render exactly one turn")
	_free_world(world)

func _test_rejected_move_leaves_turn_counter_unchanged() -> void:
	var world := await _instantiate_world()
	var moved := world.request_move(Vector2i(4, 4))
	_assert(not moved and world.move_count == 0 and _counter_text(world) == "Turns: 0",
		"rejected move unchanged text", "non-adjacent move must not mutate text")
	_free_world(world)

func _test_set_run_id_resets_turn_counter_to_zero() -> void:
	var world := await _instantiate_world()
	world.request_move(Vector2i(1, 0))
	world.set_run_id("counter-reset-run")
	_assert(world.move_count == 0 and _counter_text(world) == "Turns: 0",
		"set_run_id reset text", "run reset must reset model and label together")
	_free_world(world)

func _instantiate_world() -> MapController:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	var world := packed.instantiate() as MapController
	root.add_child(world)
	await process_frame
	await process_frame
	return world

func _counter_text(world: MapController) -> String:
	var label := world.get_node_or_null("%TurnCounterLabel") as Label
	return label.text if is_instance_valid(label) else "<missing>"

func _free_world(world: MapController) -> void:
	if is_instance_valid(world):
		world.close_active_encounter()
		world.exit_active_battle()
		world.queue_free()

func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])

func _report() -> void:
	if _failures.is_empty():
		print("World turn counter tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

- [ ] **Step 3: Validate and prove RED**

```text
validate(target="res://Tests/Map/test_world_turn_counter.gd", detail="brief")
check_errors(scope="res://Tests/Map/test_world_turn_counter.gd")
```

```powershell
godot --headless --path . --script res://Tests/Map/test_world_turn_counter.gd
```

Expected: parser checks pass; runner exits nonzero and reports the label as missing. Parser errors do not count as RED.

### Task 6: Add and render the top-left world turn counter

**Files:**
- Modify: `Scenes/game_world.tscn`
- Modify: `Scripts/Map/map_controller.gd`
- Test: `Tests/Map/test_world_turn_counter.gd`

- [ ] **Step 1: Add the scene-owned label through GodotIQ**

Open `res://Scenes/game_world.tscn`, then run one `node_ops` batch:

```json
{
  "scene": "res://Scenes/game_world.tscn",
  "detail": "brief",
  "operations": [
    {
      "op": "add_child",
      "parent": "UI",
      "type": "Label",
      "name": "TurnCounterLabel",
      "properties": {
        "unique_name_in_owner": true,
        "offset_left": 16.0,
        "offset_top": 16.0,
        "offset_right": 136.0,
        "offset_bottom": 48.0,
        "text": "Turns: 0",
        "theme_override_font_sizes/font_size": 22
      }
    }
  ]
}
```

Run `save_scene()`. Verify the unique `%TurnCounterLabel` through structured scene inspection and `validate(target="res://Scenes/game_world.tscn", detail="brief")`. Do not edit `.tscn` directly.

- [ ] **Step 2: Patch `MapController` through GodotIQ**

First run:

```text
file_context(file="res://Scripts/Map/map_controller.gd", detail="brief")
impact_check(file="res://Scripts/Map/map_controller.gd", action="add scene label reference and refresh helper", target="_ready/set_run_id/request_move")
```

Add the typed reference:

```gdscript
@onready var _turn_counter_label: Label = %TurnCounterLabel
```

Add the helper:

```gdscript
func _refresh_turn_counter() -> void:
	_turn_counter_label.text = "Turns: %d" % move_count
```

Call `_refresh_turn_counter()` after `_refresh_visual_state()` in `_ready()`, after `move_count = 0` in `set_run_id()`, and immediately after `move_count += 1` in `request_move()`. Do not call it on rejected-move return paths and do not add a second counter variable.

- [ ] **Step 3: Validate each changed asset**

```text
validate(target="res://Scenes/game_world.tscn", detail="brief")
validate(target="res://Scripts/Map/map_controller.gd", detail="brief")
check_errors(scope="res://Scripts/Map/map_controller.gd")
```

Expected: no incomplete label, convention, or parser errors.

- [ ] **Step 4: Run the focused map suite and map regressions**

```powershell
godot --headless --path . --script res://Tests/Map/test_world_turn_counter.gd
$map_tests = Get-ChildItem -LiteralPath 'Tests/Map' -Filter 'test_*.gd' -File | Sort-Object FullName
foreach ($test_script in $map_tests) {
    $resource_path = 'res://' + $test_script.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
    & godot --headless --path . --script $resource_path
    if ($LASTEXITCODE -ne 0) { throw "Map regression failed: $resource_path" }
}
```

Expected: `World turn counter tests: PASS (4/4)`, every map runner exits `0`, and no output contains `FAILED:`.

- [ ] **Step 5: Commit the counter slice**

```powershell
git add -- Scenes/game_world.tscn Scripts/Map/map_controller.gd Tests/Map/test_world_turn_counter.gd
git diff --cached --check
git commit -m "feat: show world map turn counter"
```

### Task 7: Run complete automated and runtime verification

**Files:**
- Inspect: all scoped production and test files

- [ ] **Step 1: Run project-level GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
```

Expected: no new convention, parser, or orphan-signal failures.

- [ ] **Step 2: Run every battle and map runner**

```powershell
$test_scripts = @(
    Get-ChildItem -LiteralPath 'Tests/Battle' -Filter 'test_*.gd' -File
    Get-ChildItem -LiteralPath 'Tests/Map' -Filter 'test_*.gd' -File
) | Sort-Object FullName
foreach ($test_script in $test_scripts) {
    $resource_path = 'res://' + $test_script.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
    & godot --headless --path . --script $resource_path
    if ($LASTEXITCODE -ne 0) { throw "Regression failed: $resource_path" }
}
```

Expected: both focused signatures appear, every existing AC2.x battle and map suite prints `PASS`, every command exits `0`, and no output contains `FAILED:`.

- [ ] **Step 3: Run runtime readiness and inspect state**

```text
run(action="play")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

Expected: Play starts with no failing script/runtime errors. Use `state_inspect` to confirm `MapController.move_count` changes `0 -> 1` after one accepted move and the visible label text changes `Turns: 0 -> Turns: 1`.

- [ ] **Step 4: Perform the manual binary matrix**

At the project viewport, record PASS/FAIL and observed unit/text for:

```text
B1 initial player turn automatically shows current player's skills
B2 clicking a non-current player or enemy does not replace panel ownership
B3 advancing to an enemy shows that enemy's skills
B4 advancing again updates to the next current unit
B5 removing the current unit locks to the rebuilt queue's current unit
B6 terminal/no-current state clears stale skills
M1 map starts with top-left "Turns: 0"
M2 one accepted move renders "Turns: 1"
M3 rejected move leaves text unchanged
M4 set_run_id reset renders "Turns: 0"
```

Use `explore(mode="tour")` after Play is running because the scene changed visually. Describe every screenshot, fix clipping/overlap if found, then tour again. Use at most one screenshot per verification point. Finish with `read_debug_console()` and `run(action="stop")`.

Expected: all ten scenarios PASS, the counter is top-left and readable, both sides' current skills are visible, and debugger state has no new errors.

### Task 8: Capture traceable completion evidence

**Files:**
- Create: `Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/implementation-link.txt`

- [ ] **Step 1: Identify and test one implementation SHA**

```powershell
$implementation_sha = (git rev-parse HEAD).Trim()
$implementation_sha
```

Rerun Task 7's project checks and full test loop against this exact SHA. Do not modify production or tests afterward without creating a new commit and rerunning evidence.

- [ ] **Step 2: Write the automated evidence**

`automated-test.log` must contain the implementation SHA, date, every exact command, each exit code, both focused PASS signatures, each regression PASS summary, and the project validation/parser/orphan/runtime results. A command not run against the recorded SHA cannot be marked PASS.

- [ ] **Step 3: Write the manual evidence**

`manual-runtime-check.md` must contain the same SHA, viewport, final debugger state, and a table with IDs `B1`-`B6` and `M1`-`M4`, each with `PASS` or `FAIL` plus observed active unit, inspector unit, or counter text. Include the top-left visual result and any pre-existing warnings.

- [ ] **Step 4: Write and verify the implementation link**

Write only the tested SHA plus a trailing newline to `implementation-link.txt`, then run:

```powershell
$evidence = 'Docs/Specs/AC2/Evidence/AC2.6/2026-08-06'
$sha = (Get-Content -Raw "$evidence/implementation-link.txt").Trim()
$auto = Get-Content -Raw "$evidence/automated-test.log"
$manual = Get-Content -Raw "$evidence/manual-runtime-check.md"
if (-not $auto.Contains($sha) -or -not $manual.Contains($sha)) { throw 'Evidence SHA mismatch' }
foreach ($scenario in 'B1','B2','B3','B4','B5','B6','M1','M2','M3','M4') {
    if (-not $manual.Contains("$scenario | PASS")) { throw "Missing manual PASS: $scenario" }
}
```

Expected: exit `0`; every artifact references one SHA and all ten manual rows pass.

- [ ] **Step 5: Commit evidence separately**

```powershell
git add -- Docs/Specs/AC2/Evidence/AC2.6/2026-08-06
git diff --cached --check
git commit -m "test: record pre-3.1 UI hardening evidence"
```

### Task 9: Final Definition of Done gate and handoff

**Files:**
- Inspect only: task branch, scoped commits, evidence package, preserved stash

- [ ] **Step 1: Verify the final committed tree**

Use `superpowers:verification-before-completion`, then rerun Task 7 against `HEAD`. Confirm:

```text
Active-turn skill lock tests: PASS (5/5)
World turn counter tests: PASS (4/4)
```

Also require every AC2.x battle suite and every map suite green, no new GodotIQ errors, ten manual PASS rows, and one consistent evidence SHA.

- [ ] **Step 2: Audit branch scope**

```powershell
git status --short --branch
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
git stash list
```

Expected: no uncommitted scoped changes; commits contain only the design/plan, scoped production/tests, and evidence. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` is unchanged by this slice. Any `user-work-before-pre-3-1-ui-hardening` stash remains preserved.

- [ ] **Step 3: Report completion without changing MVP authority**

Report branch and `HEAD`, design/plan paths, changed production/test files, focused and regression results, GodotIQ/runtime results, manual scenario aggregate, evidence directory and tested SHA, and any pre-existing warnings. State explicitly that no MVP AC ID or checkbox changed.

- [ ] **Step 4: Offer integration choices**

Use `superpowers:finishing-a-development-branch` and ask the user to choose local merge, push/PR, keep branch, or discard. Do not merge, push, delete, or restore/drop the preserved stash without the user's explicit selection.

## As-built reconciliation

- AC2.6 and AC2.7 use `_advance_to_unit`, a behaviorally identical bounded, asserted helper to the planned `_advance_until_current`; the naming difference is accepted.
- AC2.8 retains its direct inspect call because the `configure_units` speeds already make `player_ui` current. The call is therefore a redundant no-op, the suite remains green, and no helper is needed.
- Battle synchronization intentionally supersedes the planned snippet: rejected or repeated inspect inputs are no-ops; authoritative `_refresh_turn_ui` calls always refresh presentation; selection resets only when ownership changes; tooltip cleanup flows through `_refresh_skill_inspector -> _clear_skill_rows -> _hide_skill_tooltip`; and presentation synchronization does not reset the transaction, preserving the existing revision and revalidation lifecycle as authoritative.
- Runtime warnings at `character_skill.gd:132`, `character_skill.gd:202`, and `character_skill.gd:245` for shadowed `effect`, plus `battle_unit_state.gd:45` for int-as-enum, are pre-existing debt from older commits. They are parser/runtime nonblocking and excluded from this feature's scope.

## Plan self-review

- Approved scope maps to Tasks 2-6; no save persistence, new turn rules, or HUD redesign is included.
- All five battle and four map cases have exact test names, runner files, RED/GREEN commands, and PASS signatures.
- Battle ownership remains in `BattleArena`; map ownership remains in `MapController.move_count`; no duplicate state is introduced.
- Dependencies are acyclic: focused RED tests precede production changes, regression alignment follows the intentional contract change, then full verification precedes evidence.
- Negative paths cover non-current clicks and rejected moves; lifecycle paths cover turn advance, queue rebuild, terminal state, and run reset.
- Existing AC2.x battle and map suites are mandatory regressions.
- Evidence and handoff preserve the rule that this slice changes no canonical MVP acceptance criterion or checkbox.
