# Stage 6 Legacy World Runtime Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the unreachable 25-cell world runtime and its legacy-only tests while preserving the post-cutover production world and compatibility contracts.

**Architecture:** Treat the old scene, controller, tile view, and their legacy-only tests as one isolated deletion unit. Preserve the shared map model and its direct test because current battle, encounter, reward, and world-runtime code still consumes its constants. Make absence executable in the existing cutover-entry test, then verify current production, persistence, generation, and migrated gameplay paths before review and local integration.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured inspection/editing/validation, PowerShell, Git.

---

### Task 1: Capture the pre-cleanup boundary

**Files:**
- Inspect: `Scenes/game_world.tscn`
- Inspect: `Scenes/map_hex_tile.tscn`
- Inspect: `Scripts/Map/map_controller.gd`
- Inspect: `Scripts/Map/hex_map_model.gd`
- Inspect: `Scripts/Map/hex_tile_view.gd`
- Inspect: `Tests/Map/*.gd`

- [ ] **Step 1: Confirm the production authority**

Run GodotIQ `file_context(file="res://Scenes/world_run_start.tscn", detail="brief")` and `file_context(file="res://Scenes/world_map_runtime.tscn", detail="brief")`.

Expected: the run-start launcher and runtime scene resolve successfully; neither depends on `Scenes/game_world.tscn` or `Scripts/Map/*`.

- [ ] **Step 2: Confirm the deletion cluster**

Run `file_context(detail="normal")` for both legacy scenes and all three legacy scripts. Run `dependency_graph(depth=2, detail="normal")` for each script.

Expected: `map_controller.gd` is used only by `game_world.tscn`; `hex_tile_view.gd` is used only by `map_hex_tile.tscn` and the legacy controller. Compiler-backed search showed that `hex_map_model.gd` still supplies encounter constants and neighbor offsets to retained battle, encounter, reward, and world-runtime code, so preserve it.

- [ ] **Step 3: Inspect every legacy test before deletion**

Run GodotIQ `file_context(detail="normal")` for every `.gd` in `Tests/Map/`. Classify a test as legacy-only only when its subject constant points to `game_world.tscn`, `map_hex_tile.tscn`, or one of the three `Scripts/Map/*` scripts.

Expected deletion set:

```text
Tests/Map/test_ac1_1_runtime_step_counts.gd
Tests/Map/test_ac1_2_encounter_determinism.gd
Tests/Map/test_ac1_2_hex_tile_view_states.gd
Tests/Map/test_ac1_2_runtime_encounter_layout.gd
Tests/Map/test_ac1_3_mouse_navigation.gd
Tests/Map/test_ac1_4_encounter_overlay.gd
Tests/Map/test_ac1_5_sudden_death.gd
Tests/Map/test_ac2_1_battle_arena.gd
Tests/Map/test_ac3_1_recruitment_integration.gd
Tests/Map/test_ac3_3_party_management_integration.gd
Tests/Map/test_hex_map_model.gd
Tests/Map/test_map_controller_runtime.gd
Tests/Map/test_world_turn_counter.gd
```

- [ ] **Step 4: Capture baseline health**

Run GodotIQ `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(scope="all", find="orphans", detail="brief")`.

Expected: record existing counts and findings; later results must introduce no cleanup-caused error.

### Task 2: Add the failing post-cleanup assertion

**Files:**
- Modify: `Tests/Run/test_world_cutover_entry.gd`

- [ ] **Step 1: Reinspect the test and impact**

Run GodotIQ `file_context(file="res://Tests/Run/test_world_cutover_entry.gd", detail="brief")` and `impact_check` for adding legacy-path assertions.

- [ ] **Step 2: Add the absence contract with `script_ops(op="patch")`**

Add below `EXPECTED_MAIN_SCENE`:

```gdscript
const REMOVED_LEGACY_PATHS: Array[String] = [
    "res://Scenes/game_world.tscn",
    "res://Scenes/map_hex_tile.tscn",
    "res://Scripts/Map/map_controller.gd",
    "res://Scripts/Map/hex_tile_view.gd",
]
```

Add after the main-scene `_expect` call:

```gdscript
    for legacy_path: String in REMOVED_LEGACY_PATHS:
        _expect(
            not FileAccess.file_exists(legacy_path),
            "legacy runtime path is removed: %s" % legacy_path
        )
```

Change `_expect` so failures report their supplied message without assuming every assertion concerns the main-scene setting:

```gdscript
func _expect(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)
```

- [ ] **Step 3: Validate the changed test**

Run GodotIQ `validate(target="res://Tests/Run/test_world_cutover_entry.gd", detail="brief")`, then `check_errors(scope="res://Tests/Run/test_world_cutover_entry.gd")`.

Expected: no parser error.

- [ ] **Step 4: Run RED**

Run:

```powershell
& $godot --headless --path . --script Tests/Run/test_world_cutover_entry.gd
```

Expected: exit `1`; failures name the four still-existing legacy paths. If `$godot` is unset, resolve the installed Godot executable first and assign its absolute path without changing repository files.

- [ ] **Step 5: Commit the executable contract**

```powershell
git add -- Tests/Run/test_world_cutover_entry.gd
git commit -m "test: require removal of legacy world runtime"
```

### Task 3: Delete the isolated legacy runtime and tests

**Files:**
- Delete: `Scenes/game_world.tscn`
- Delete: `Scenes/map_hex_tile.tscn`
- Delete: `Scripts/Map/map_controller.gd`
- Delete: `Scripts/Map/hex_tile_view.gd`
- Delete: matching `.uid` sidecars for deleted scripts
- Delete: the thirteen `Tests/Map/*.gd` files listed in Task 1 and their `.uid` sidecars

- [ ] **Step 1: Reconfirm impact immediately before deletion**

Run GodotIQ `impact_check` for deletion of each scene and script. Stop if any retained production scene, `Scripts/WorldMap/*`, or retained test is reported as a dependent.

- [ ] **Step 2: Delete through GodotIQ**

Use GodotIQ `file_ops(op="delete", path=...)` for every listed `.tscn`, `.gd`, and `.uid` path. Delete only the exact paths listed by Tasks 1 and 3.

- [ ] **Step 3: Verify GREEN**

Run:

```powershell
& $godot --headless --path . --script Tests/Run/test_world_cutover_entry.gd
```

Expected: exit `0` and `PASS test_world_cutover_entry`.

- [ ] **Step 4: Check for retained references**

Use GodotIQ `file_ops(op="search", query="res://Scenes/game_world.tscn")`, repeat for `map_hex_tile.tscn` and each deleted script path, then inspect any hit. Historical specifications and evidence may retain textual references; executable scenes, scripts, project configuration, and retained tests may not.

- [ ] **Step 5: Commit the deletion unit**

```powershell
git add -u -- Scenes Scripts/Map Tests/Map
git commit -m "refactor: remove legacy 25-cell world runtime"
```

### Task 4: Run successor and compatibility verification

**Files:**
- Verify: `Tests/Run/test_world_cutover_entry.gd`
- Verify: retained production, save, generator, runtime, battle, recruitment, and party runners

- [ ] **Step 1: Run the critical successor matrix**

Run each command separately and require exit `0`:

```powershell
$tests = @(
    'Tests/Run/test_world_cutover_entry.gd',
    'Tests/Run/test_world_production_launcher.gd',
    'Tests/Run/test_world_single_slot_repository.gd',
    'Tests/Save/test_world_save_codec_v1.gd',
    'Tests/Save/test_world_run_save_codec_v2.gd',
    'Tests/WorldMap/test_hex_world_generator_v1.gd',
    'Tests/WorldMap/test_world_runtime_model.gd',
    'Tests/WorldMap/test_world_runtime_migrated_flows.gd',
    'Tests/WorldMap/test_world_runtime_scene.gd',
    'Tests/WorldMap/test_world_production_scene.gd',
    'Tests/WorldMap/test_world_battle_entry.gd',
    'Tests/Run/test_ac3_1_run_roster.gd',
    'Tests/Run/test_ac3_3_party_formation.gd',
    'Tests/UI/test_ac3_3_party_management.gd'
)
foreach ($test in $tests) {
    & $godot --headless --path . --script $test
    if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
```

Expected: every runner prints its PASS summary and the loop completes without throwing.

- [ ] **Step 2: Run structural verification**

Run GodotIQ `validate(target="project", detail="normal")`, `check_errors(scope="project")`, and `signal_map(scope="all", find="orphans", detail="brief")`.

Expected: zero parser errors and no new orphan/missing signal attributable to the cleanup.

- [ ] **Step 3: Run production startup verification**

Run GodotIQ `run(action="play")`, `verify_project_runs()`, and `read_debug_console()`, then `run(action="stop")`.

Expected: configured main scene starts and the console contains no cleanup-caused error.

- [ ] **Step 4: Inspect the complete branch diff**

```powershell
git diff --check main...HEAD
git diff --stat main...HEAD
git status --short --branch
```

Expected: no whitespace errors; only the design, plan, cutover test, approved legacy cluster, and legacy-only tests differ.

### Task 5: Review, correct, and integrate

**Files:**
- Review: every path in `git diff --name-status main...HEAD`
- Modify: only files required to resolve verified review findings

- [ ] **Step 1: Invoke the code-review workflow**

Use `superpowers:requesting-code-review`. Review scope is `main...cleanup/stage6-legacy-world-runtime`; require findings to cite a concrete changed path and correctness, compatibility, test, or architecture impact.

- [ ] **Step 2: Resolve findings with technical verification**

For every blocking or correctness finding, use `superpowers:receiving-code-review`, inspect the cited evidence, apply the smallest valid correction through GodotIQ, and rerun the directly affected test plus Task 4 structural checks. Commit corrections separately:

```powershell
git add -- <exact-reviewed-paths>
git commit -m "fix: address legacy cleanup review"
```

Expected: no unresolved blocking or correctness finding.

- [ ] **Step 3: Run the final branch gate**

Repeat Task 4 in full, then confirm:

```powershell
git status --short --branch
git log --oneline main..HEAD
```

Expected: clean task branch and only cleanup-related commits.

- [ ] **Step 4: Merge into updated `main`**

```powershell
git switch main
git pull --ff-only origin main
git merge --no-ff cleanup/stage6-legacy-world-runtime -m "merge: remove legacy world runtime"
```

Expected: merge succeeds without incorporating `stash@{0}`.

- [ ] **Step 5: Verify the merge result**

On `main`, rerun `test_world_cutover_entry.gd`, the full Task 4 successor matrix, GodotIQ project validation, project parser checks, signal-orphan scan, and configured-main-scene startup.

Expected: all gates match the verified branch result.

- [ ] **Step 6: Preserve the prior workspace state**

Confirm the stash still exists:

```powershell
git stash list
```

Expected: `codex-preserve-before-stage6-legacy-cleanup-2026-08-27` remains present and unapplied. Do not drop or apply it automatically.
