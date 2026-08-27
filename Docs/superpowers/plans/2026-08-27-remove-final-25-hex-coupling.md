# Remove Final 25-Hex Runtime Coupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the retired 5x5 `HexMapModel` from executable code while preserving Radius-8 behavior, historical documentation, and explicit rejection of legacy saves.

**Architecture:** Move deterministic neighbor ordering to the existing `HexWorldGeometry` authority and move shared encounter identifiers into a small `WorldEncounterType` value authority. Migrate current production and integration consumers, then delete the 25-cell model and its direct test without touching compatibility readers or historical artifacts.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured inspection/editing/validation, PowerShell, Git.

---

### Task 1: Capture the verified boundary and baseline

**Files:**
- Inspect: `Scripts/Map/hex_map_model.gd`
- Inspect: `Scripts/WorldMap/hex_world_geometry.gd`
- Inspect: `Scripts/WorldMap/world_runtime_model.gd`
- Inspect: `Scripts/Encounter/encounter_overlay.gd`
- Inspect: `Scripts/Battle/battle_arena.gd`
- Inspect: `Scripts/Battle/battle_reward_catalog.gd`
- Inspect: `Tests/Map/test_hex_map_model.gd`
- Inspect: `Tests/WorldMap/test_world_battle_entry.gd`

- [ ] **Step 1: Confirm the task branch and clean state**

Run:

```powershell
git branch --show-current
git status --short
```

Expected: branch `refactor/remove-25hex-coupling`; no uncommitted changes.

- [ ] **Step 2: Reinspect every production file before editing**

Run GodotIQ `file_context(detail="normal")` on every production and test script listed above. Run `dependency_graph(depth=2, detail="normal")` for `hex_map_model.gd`, `world_runtime_model.gd`, `encounter_overlay.gd`, and `battle_arena.gd`.

Expected: the 5x5 model supplies only encounter constants and neighbor ordering to current code; the current world, encounter, and battle systems have no dependency on its 25-cell generation, coordinates, or pursuit implementation.

- [ ] **Step 3: Capture the executable-reference inventory**

Run:

```powershell
rg -n -i "25[- ]?hex|25[- ]?cell|5x5|5×5|HexMapModel|MAP_WIDTH|MAP_HEIGHT|legacy" Scripts Scenes Tests project.godot --glob '!*.uid' --glob '!*.import'
```

Expected intentional retained hits: legacy-save detection and rejection, cutover absence assertions, and tests of those contracts. Record all `HexMapModel` hits for migration.

- [ ] **Step 4: Capture project health**

Run GodotIQ:

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: record the exact baseline counts. Stop if a parser error prevents establishing a trustworthy baseline.

### Task 2: Add the encounter authority test first

**Files:**
- Create: `Tests/WorldMap/test_world_encounter_type.gd`
- Create automatically: `Tests/WorldMap/test_world_encounter_type.gd.uid`
- Create later: `Scripts/WorldMap/world_encounter_type.gd`

- [ ] **Step 1: Create the failing test with GodotIQ `script_ops(op="create")`**

Create exactly:

```gdscript
extends SceneTree

const SCRIPT_PATH := "res://Scripts/WorldMap/world_encounter_type.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var encounter_script: GDScript = load(SCRIPT_PATH)
    _expect(encounter_script != null, "encounter authority script exists")
    if encounter_script != null:
        _expect(encounter_script.NONE == "", "none identifier")
        _expect(encounter_script.SAFE == "safe", "safe identifier")
        _expect(encounter_script.COMBAT == "combat", "combat identifier")
        _expect(encounter_script.BOSS == "boss", "boss identifier")
    _finish()


func _expect(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_encounter_type")
    quit(1 if _failures > 0 else 0)
```

- [ ] **Step 2: Validate the test script**

Run GodotIQ:

```text
validate(target="res://Tests/WorldMap/test_world_encounter_type.gd", detail="brief")
check_errors(scope="res://Tests/WorldMap/test_world_encounter_type.gd")
```

Expected: the test itself parses; runtime loading is the intended failure.

- [ ] **Step 3: Run RED**

Resolve the active Godot executable from the editor process, then run the test:

```powershell
$godot = (Get-Process -Name 'Godot*' -ErrorAction Stop | Select-Object -First 1).Path
& $godot --headless --path . --script Tests/WorldMap/test_world_encounter_type.gd
if ($LASTEXITCODE -eq 0) { throw 'Expected RED failure before authority exists' }
```

Expected: nonzero exit because `world_encounter_type.gd` does not exist.

- [ ] **Step 4: Commit the executable RED contract**

```powershell
git add -- Tests/WorldMap/test_world_encounter_type.gd Tests/WorldMap/test_world_encounter_type.gd.uid
git commit -m "test: define current world encounter identifiers"
```

### Task 3: Implement current shared authorities

**Files:**
- Create: `Scripts/WorldMap/world_encounter_type.gd`
- Create automatically: `Scripts/WorldMap/world_encounter_type.gd.uid`
- Modify: `Scripts/WorldMap/world_runtime_model.gd`

- [ ] **Step 1: Reconfirm impact before changing the runtime model**

Run GodotIQ `file_context(file="res://Scripts/WorldMap/world_runtime_model.gd", detail="normal")` and `impact_check(file="res://Scripts/WorldMap/world_runtime_model.gd", action="modify_function", target="_get_pursuit_step", change_description="Use the Radius-8 geometry authority for deterministic neighbor ordering", detail="brief")`.

Expected: no signature change and no affected caller contract.

- [ ] **Step 2: Create `WorldEncounterType` through GodotIQ**

Use `script_ops(op="create", path="res://Scripts/WorldMap/world_encounter_type.gd")` with:

```gdscript
class_name WorldEncounterType
extends RefCounted

const NONE := ""
const SAFE := "safe"
const COMBAT := "combat"
const BOSS := "boss"
```

- [ ] **Step 3: Replace the legacy geometry reference**

Use `script_ops(op="patch")` on `world_runtime_model.gd`:

```text
search:  for offset: Vector2i in HexMapModel.NEIGHBOR_OFFSETS:
replace: for offset: Vector2i in HexWorldGeometry.NEIGHBOR_OFFSETS:
```

- [ ] **Step 4: Validate each changed script separately**

Run `validate(detail="brief")` followed by `check_errors` for `world_encounter_type.gd`, then repeat for `world_runtime_model.gd`.

Expected: zero parser errors in both scripts.

- [ ] **Step 5: Run GREEN for the new authority and geometry**

```powershell
& $godot --headless --path . --script Tests/WorldMap/test_world_encounter_type.gd
if ($LASTEXITCODE -ne 0) { throw 'Encounter authority test failed' }
& $godot --headless --path . --script Tests/WorldMap/test_hex_world_geometry.gd
if ($LASTEXITCODE -ne 0) { throw 'Geometry test failed' }
& $godot --headless --path . --script Tests/WorldMap/test_world_runtime_model.gd
if ($LASTEXITCODE -ne 0) { throw 'Runtime model test failed' }
```

Expected: all three runners print their PASS summary.

- [ ] **Step 6: Commit authority ownership**

```powershell
git add -- Scripts/WorldMap/world_encounter_type.gd Scripts/WorldMap/world_encounter_type.gd.uid Scripts/WorldMap/world_runtime_model.gd
git commit -m "refactor: move shared world constants to current authorities"
```

### Task 4: Migrate encounter and battle consumers

**Files:**
- Modify: `Scripts/Encounter/encounter_overlay.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Scripts/Battle/battle_reward_catalog.gd`
- Modify: `Tests/WorldMap/test_world_battle_entry.gd`

- [ ] **Step 1: Reinspect and check impact**

Run `file_context(detail="normal")` for all four files. Run `impact_check(action="modify_function")` for `EncounterOverlay.can_enter_battle`, `BattleArena.configure`, and `BattleRewardCatalog.get_options_for`, describing identifier-authority replacement without signature or value changes.

Expected: caller contracts remain unchanged.

- [ ] **Step 2: Patch the encounter overlay**

Replace:

```gdscript
return encounter_type == HexMapModel.ENCOUNTER_COMBAT or encounter_type == HexMapModel.ENCOUNTER_BOSS
```

with:

```gdscript
return encounter_type == WorldEncounterType.COMBAT or encounter_type == WorldEncounterType.BOSS
```

- [ ] **Step 3: Patch battle configuration**

In `battle_arena.gd`, replace both `HexMapModel.ENCOUNTER_COMBAT` and `HexMapModel.ENCOUNTER_BOSS` with `WorldEncounterType.COMBAT` and `WorldEncounterType.BOSS`.

- [ ] **Step 4: Patch reward selection**

In `battle_reward_catalog.gd`, replace the two `HexMapModel` encounter constants with their `WorldEncounterType` equivalents.

- [ ] **Step 5: Patch the current world-battle integration test**

In `test_world_battle_entry.gd`, replace:

```gdscript
runtime.call("_on_battle_requested", Vector2i.ZERO, HexMapModel.ENCOUNTER_COMBAT)
```

with:

```gdscript
runtime.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
```

- [ ] **Step 6: Validate and parse-check one file at a time**

For each modified file, run GodotIQ `validate(target=<file>, detail="brief")`, then `check_errors(scope=<file>)` before continuing.

Expected: no parser errors.

- [ ] **Step 7: Run focused encounter and battle tests**

```powershell
$tests = @(
    'Tests/WorldMap/test_world_battle_entry.gd',
    'Tests/Battle/test_ac2_4_battle_results.gd',
    'Tests/Battle/test_ac2_5_reward_selection.gd'
)
foreach ($test in $tests) {
    & $godot --headless --path . --script $test
    if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
```

Expected: every runner passes.

- [ ] **Step 8: Commit consumer migration**

```powershell
git add -- Scripts/Encounter/encounter_overlay.gd Scripts/Battle/battle_arena.gd Scripts/Battle/battle_reward_catalog.gd Tests/WorldMap/test_world_battle_entry.gd
git commit -m "refactor: decouple battle flow from legacy map model"
```

### Task 5: Delete the retired model and direct test

**Files:**
- Delete: `Scripts/Map/hex_map_model.gd`
- Delete: `Scripts/Map/hex_map_model.gd.uid`
- Delete: `Tests/Map/test_hex_map_model.gd`
- Delete: `Tests/Map/test_hex_map_model.gd.uid`
- Delete if present: `Tests/Map/test_world_turn_counter.gd.uid`

- [ ] **Step 1: Prove no executable consumer remains**

Run:

```powershell
rg -n "HexMapModel" Scripts Scenes Tests project.godot --glob '!Scripts/Map/hex_map_model.gd' --glob '!Tests/Map/test_hex_map_model.gd'
```

Expected: no output and exit code `1`, meaning no retained executable reference exists.

- [ ] **Step 2: Reconfirm deletion impact**

Run GodotIQ `file_context(detail="normal")` and `dependency_graph(depth=2, detail="normal")` for the model and direct test immediately before deletion.

Expected: no retained production or test dependency.

- [ ] **Step 3: Delete exact paths through GodotIQ file operations**

Delete the four model/test paths. Delete `Tests/Map/test_world_turn_counter.gd.uid` only if it exists without a matching `.gd` script.

- [ ] **Step 4: Run the absence and compatibility gates**

```powershell
$tests = @(
    'Tests/Run/test_world_cutover_entry.gd',
    'Tests/Save/test_world_save_codec_v1.gd',
    'Tests/Save/test_world_run_save_codec_v2.gd',
    'Tests/Run/test_world_single_slot_repository.gd'
)
foreach ($test in $tests) {
    & $godot --headless --path . --script $test
    if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
```

Expected: the removed-runtime assertion and all legacy-save rejection contracts pass.

- [ ] **Step 5: Commit the deletion**

```powershell
git add -u -- Scripts/Map Tests/Map
git commit -m "refactor: remove retired 25-hex map model"
```

### Task 6: Run the complete verification gate

**Files:**
- Verify: all changed files
- Verify: current world, battle, save, launcher, and cutover runners

- [ ] **Step 1: Verify remaining old-map references by category**

Run:

```powershell
rg -n -i "25[- ]?hex|25[- ]?cell|5x5|5×5|HexMapModel|MAP_WIDTH|MAP_HEIGHT|legacy" Scripts Scenes Tests project.godot --glob '!*.uid' --glob '!*.import'
```

Expected: no `HexMapModel`, `MAP_WIDTH`, or `MAP_HEIGHT` hit. Remaining legacy/5x5 hits must be limited to explicit save rejection, compatibility fixtures, and cutover absence assertions.

- [ ] **Step 2: Run the successor matrix**

```powershell
$tests = @(
    'Tests/WorldMap/test_world_encounter_type.gd',
    'Tests/WorldMap/test_hex_world_geometry.gd',
    'Tests/WorldMap/test_world_runtime_model.gd',
    'Tests/WorldMap/test_world_runtime_migrated_flows.gd',
    'Tests/WorldMap/test_world_runtime_scene.gd',
    'Tests/WorldMap/test_world_production_scene.gd',
    'Tests/WorldMap/test_world_battle_entry.gd',
    'Tests/Run/test_world_cutover_entry.gd',
    'Tests/Run/test_world_production_launcher.gd',
    'Tests/Run/test_world_single_slot_repository.gd',
    'Tests/Save/test_world_save_codec_v1.gd',
    'Tests/Save/test_world_run_save_codec_v2.gd',
    'Tests/Battle/test_ac2_4_battle_results.gd',
    'Tests/Battle/test_ac2_5_reward_selection.gd'
)
foreach ($test in $tests) {
    & $godot --headless --path . --script $test
    if ($LASTEXITCODE -ne 0) { throw "Failed: $test" }
}
```

Expected: every runner prints its PASS summary and the loop completes.

- [ ] **Step 3: Run structural checks**

Run GodotIQ:

```text
validate(target="project", detail="normal")
check_errors(scope="project")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: zero cleanup-caused errors and no new orphan signals compared with Task 1.

- [ ] **Step 4: Run production startup**

Run GodotIQ `run(action="play")`, `verify_project_runs()`, `read_debug_console()`, then `run(action="stop")`.

Expected: the configured launcher and Radius-8 world start without cleanup-caused runtime or script errors.

- [ ] **Step 5: Inspect the final diff and repository state**

```powershell
git diff --check main...HEAD
git diff --name-status main...HEAD
git status --short --branch
```

Expected: clean task branch; only the approved design, plan, new authority/test, migrated consumers, and deleted 25-cell model/test differ.
