# AC2.1 Battle Arena Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect Combat and Boss encounters to a full-screen arena with exactly six player slots and six enemy slots while preserving the active map state.

**Architecture:** `MapController` remains the flow owner and instantiates one `BattleArena` beneath the existing UI `CanvasLayer`. `EncounterOverlay` emits a typed request only for canonical lowercase Combat/Boss constants; `BattleArena` owns scene-authored formation slots and a temporary debug-exit signal.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ scene/script tooling, headless `SceneTree` tests.

---

## File Structure

- Create: `Tests/Map/test_ac2_1_battle_arena.gd` — 11-case focused contract and runner.
- Create: `Scripts/Battle/battle_arena.gd` — arena context, slot queries, and exit signal.
- Create: `Scenes/battle_arena.tscn` — full-screen arena and two six-slot formations.
- Modify: `Scenes/encounter_overlay.tscn` — add the conditional Enter Battle action.
- Modify: `Scripts/Encounter/encounter_overlay.gd` — canonical eligibility and typed battle request.
- Modify: `Scripts/Map/map_controller.gd` — arena lifecycle, transition, reset, and navigation guard.
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — check AC2.1 only after all gates pass.
- Create: `Docs/Specs/AC2/Evidence/AC2.1/2026-07-27/{automated-test.log,manual-runtime-check.md,implementation-link.txt}`.

### Task 1: Establish the Implementation Branch

- [ ] **Step 1: Commit this plan**

```powershell
git add Docs/superpowers/plans/2026-07-27-ac2-1-battle-arena.md
git commit -m "docs: plan AC2.1 battle arena implementation"
```

- [ ] **Step 2: Start cleanly from current integration**

```powershell
git switch main
git pull --ff-only origin main
git switch -c feature/ac2-1-battle-arena
git cherry-pick c3da127 7459da6 c33293d <plan-commit>
```

Expected: the feature branch contains only current `origin/main` plus approved AC2.1 planning commits.

### Task 2: Write and Prove the Focused Contract

**Files:**

- Create: `Tests/Map/test_ac2_1_battle_arena.gd`

- [ ] **Step 1: Create the typed `SceneTree` test through GodotIQ**

The runner must define `EXPECTED_TEST_COUNT := 11`, collect failures, run the 11 cases named in the design, print each failure as `FAILED: <name> - <reason>`, and print exactly:

```text
AC2.1 battle arena tests: PASS (11/11)
```

on success before `quit(0)`. It loads real packed scenes and uses canonical `HexMapModel` constants rather than mocks or duplicated strings.

- [ ] **Step 2: Validate the test asset**

```text
validate(res://Tests/Map/test_ac2_1_battle_arena.gd, detail=brief)
check_errors(res://Tests/Map/test_ac2_1_battle_arena.gd)
```

- [ ] **Step 3: Verify RED**

```powershell
godot --headless --path . --script Tests/Map/test_ac2_1_battle_arena.gd
```

Expected: exit `1` with failures caused by missing `battle_arena.tscn`, `BattleArena`, `battle_requested`, and active-battle APIs.

- [ ] **Step 4: Commit the red contract**

```powershell
git add Tests/Map/test_ac2_1_battle_arena.gd
git commit -m "test: specify AC2.1 battle arena"
```

### Task 3: Implement the Arena Unit

**Files:**

- Create: `Scripts/Battle/battle_arena.gd`
- Create: `Scenes/battle_arena.tscn`

- [ ] **Step 1: Create the typed script through GodotIQ**

Implement this public contract:

```gdscript
class_name BattleArena
extends Control

signal exit_requested

const SIDE_SLOT_COUNT := 6

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""

func configure(coordinate: Vector2i, type: String) -> void
func get_player_slots() -> Array[Control]
func get_enemy_slots() -> Array[Control]
```

`configure()` accepts only `HexMapModel.ENCOUNTER_COMBAT` or `HexMapModel.ENCOUNTER_BOSS`, stores canonical lowercase context, and renders a capitalized presentation label. The debug button marks viewport input handled and defers `exit_requested`, matching the established overlay event-safety pattern.

- [ ] **Step 2: Build the full-screen scene through GodotIQ**

Create a full-rect `BattleArena` root with `mouse_filter = MOUSE_FILTER_STOP`, opaque background, context label, `PlayerFormation` and `EnemyFormation` containers, six scene-authored `PanelContainer` slots under each formation named `Slot0`…`Slot5`, and `ExitBattleDebugButton`. Each slot stores `side` (`"player"` or `"enemy"`) and integer `slot_index` metadata.

- [ ] **Step 3: Save and validate**

```text
save_scene(res://Scenes/battle_arena.tscn)
validate(res://Scripts/Battle/battle_arena.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_arena.gd)
validate(res://Scenes/battle_arena.tscn, detail=brief)
```

- [ ] **Step 4: Run the focused test**

Expected: arena structure/configuration cases pass; transition cases remain red.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_arena.gd Scenes/battle_arena.tscn
git commit -m "feat: add AC2.1 battle arena formations"
```

### Task 4: Connect Encounter Entry

**Files:**

- Modify: `Scenes/encounter_overlay.tscn`
- Modify: `Scripts/Encounter/encounter_overlay.gd`

- [ ] **Step 1: Run GodotIQ context and impact checks**

```text
file_context(res://Scripts/Encounter/encounter_overlay.gd, detail=brief)
file_context(res://Scenes/encounter_overlay.tscn, detail=brief)
impact_check(res://Scripts/Encounter/encounter_overlay.gd, modify_function, configure)
```

- [ ] **Step 2: Add the contract**

Add:

```gdscript
signal battle_requested(coordinate: Vector2i, encounter_type: String)

func can_enter_battle() -> bool:
	return encounter_type == HexMapModel.ENCOUNTER_COMBAT or encounter_type == HexMapModel.ENCOUNTER_BOSS
```

Show/enable `EnterBattleButton` only when `can_enter_battle()` is true. On press, mark input handled and defer emission using stored canonical context. Do not alter Safe close behavior.

- [ ] **Step 3: Add the scene-authored button, save, and validate each file**

Expected: overlay-focused cases become green without AC1.4 regressions.

- [ ] **Step 4: Commit**

```powershell
git add Scripts/Encounter/encounter_overlay.gd Scenes/encounter_overlay.tscn
git commit -m "feat: request battles from combat encounters"
```

### Task 5: Integrate Arena Lifecycle

**Files:**

- Modify: `Scripts/Map/map_controller.gd`

- [ ] **Step 1: Run GodotIQ context and impact checks**

Check `request_move`, `set_run_id`, `_open_encounter`, and the new signal handler before editing.

- [ ] **Step 2: Add lifecycle APIs**

Add `BATTLE_ARENA_SCENE_PATH`, `_battle_arena_scene`, `_active_battle`, and:

```gdscript
func has_active_battle() -> bool
func get_active_battle() -> BattleArena
func exit_active_battle() -> void
```

Make `request_move()` reject when either encounter or battle is active. Make `set_run_id()` close both. Connect `overlay.battle_requested` to `_on_battle_requested()`.

- [ ] **Step 3: Implement guarded transition**

The handler must confirm the request came from the active overlay, accept only canonical Combat/Boss values, refuse duplicates, instantiate/configure the arena, close the overlay, connect one-shot debug exit, and add the arena beneath `_ui_layer`. Instantiation failure must leave no stale active reference.

- [ ] **Step 4: Validate and verify GREEN**

```powershell
godot --headless --path . --script Tests/Map/test_ac2_1_battle_arena.gd
```

Expected: `AC2.1 battle arena tests: PASS (11/11)` and exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Map/map_controller.gd Tests/Map/test_ac2_1_battle_arena.gd
git commit -m "feat: connect encounters to AC2.1 arena"
```

### Task 6: Regression, Runtime QA, and Evidence

- [ ] **Step 1: Run every map test independently**

```powershell
Get-ChildItem Tests/Map/*.gd | ForEach-Object {
    & godot --headless --path . --script $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

- [ ] **Step 2: Run structured gates**

```text
validate(project, detail=brief)
check_errors(project)
signal_map(scope=all, find=orphans, detail=brief)
verify_project_runs(scene=main, check_scope=project, stop_after=true)
```

- [ ] **Step 3: Perform visual/runtime QA**

Enter Combat and Boss through real pointer input, confirm the 6+6 opposing layout and input blocking, debug-exit with unchanged state, and verify Safe remains unchanged. Capture one screenshot per final visual verification point.

- [ ] **Step 4: Create evidence**

Create the exact three artifacts and contents required by the approved design under `Docs/Specs/AC2/Evidence/AC2.1/2026-07-27/`.

- [ ] **Step 5: Mark complete only after evidence passes**

Change AC2.1 to `[x]`, rerun the focused test and project gates, then commit:

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.1/2026-07-27
git commit -m "docs: record AC2.1 verification evidence"
```

## Self-Review

- All approved scope has a concrete task and verification path.
- Canonical values are lowercase and referenced through `HexMapModel` constants.
- Test output, runner commands, failure behavior, evidence contents, and completion gate are explicit.
- Type signatures remain consistent across overlay, arena, controller, and tests.
- Safe behavior, unit population, combat resolution, rewards, and production exit remain outside scope.
