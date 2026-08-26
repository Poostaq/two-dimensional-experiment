# World Production Cutover Stage 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy production entry with a run-start launcher that starts or continues one atomically saved radius-8 run and autosaves every authoritative transaction.

**Architecture:** Develop the launcher, Save V2, production world, and autosave coordinator behind explicit non-production scene paths while the legacy main scene remains frozen. Freeze that complete implementation as parent `P`, then create one single-parent cutover commit `C` that changes only production authority and authorized assertion disposition; generate evidence without modifying `C`.

**Tech Stack:** Godot 4.7 typed GDScript, Generator V1 canonical plans, JSON Save V2 with Save V1 reader dispatch, atomic `WorldSaveStore`, standalone headless runners, GodotIQ validation/runtime tools, PowerShell evidence capture.

---

## Authorities and fixed paths

Read before execution:

- `Docs/superpowers/specs/2026-08-26-world-production-cutover-stage5-design.md`
- `Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md`
- `Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md`
- `Docs/superpowers/specs/2026-08-25-world-runtime-stage4-design.md`

Fixed production paths:

- launcher: `res://Scenes/world_run_start.tscn`
- production world: `res://Scenes/world_map_runtime.tscn`
- single save: `user://active-world-run.json`
- evidence: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/`

Do not modify `project.godot`, frozen legacy tests, `Scenes/game_world.tscn`, or `Scripts/Map` before Task 9.

## Task 1: Land the approved design and freeze the development baseline

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/baseline/branch-provenance.txt`

- [x] **Step 1: Merge the documentation branch into local main**

```powershell
git checkout main
git pull --ff-only
git merge docs/world-production-cutover-stage5
```

Expected: clean fast-forward or single merge with no conflicts; unrelated untracked files remain unstaged.

- [x] **Step 2: Create the implementation branch**

```powershell
git checkout -b feat/world-production-cutover-stage5
```

- [x] **Step 3: Record provenance**

Create `branch-provenance.txt` containing the branch name, `git rev-parse origin/main`, `git rev-parse main`, Godot version, and the explicit statement `production_main=res://Scenes/game_world.tscn`.

- [x] **Step 4: Run the 37-run Stage 4 matrix**

Use every runner named in `Docs/Specs/WorldMap/Evidence/RuntimeStage4/green/automated-tests.log` with:

```powershell
& $godot --headless --path . --script $runner
```

Expected: 37 runners, zero nonzero exits, zero stderr bytes.

- [x] **Step 5: Commit the baseline**

```powershell
git add -- Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/baseline/branch-provenance.txt
git commit -m "test: freeze Stage 5 development baseline"
```

## Task 2: Add typed durable run state and Save V2

**Files:**
- Create: `Scripts/Run/world_run_state.gd`
- Create: `Scripts/Save/world_run_save_codec_v2.gd`
- Create: `Tests/Save/test_world_run_save_codec_v2.gd`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/red/save-v2-red.log`

- [x] **Step 1: Write the failing Save V2 runner**

The runner must construct:

```gdscript
var state := WorldRunState.new(
    Vector2i(-7, 0), Vector2i(8, -1), 31, true, false,
    {Vector2i(-7, 0): &"combat"}, roster_snapshot
)
var bytes := WorldRunSaveCodecV2.encode(plan, &"golden-alpha", state)
var decoded := WorldRunSaveCodecV2.decode(bytes)
_expect(decoded.ok, "Save V2 decodes")
_expect(decoded.value.run_state.canonical_key() == state.canonical_key(), "runtime state round trips")
_expect(
    WorldPlanCodecV1.serialize(decoded.value.plan) == WorldPlanCodecV1.serialize(plan),
    "plan bytes round trip"
)
```

Also assert `save_version == 2`, Save V1 remains readable through `decode_any`, altered plan SHA fails immutably, and roster slots retain front/back indices.

- [x] **Step 2: Capture RED**

```powershell
& $godot --headless --path . --script Tests/Save/test_world_run_save_codec_v2.gd 1> save-v2-red.stdout 2> save-v2-red.stderr
```

Expected: exit `1` because `WorldRunState`/`WorldRunSaveCodecV2` do not exist. Store the combined result in `red/save-v2-red.log`.

- [x] **Step 3: Implement `WorldRunState`**

Provide typed fields, defensive copies, `is_valid(plan) -> bool`, `to_dictionary() -> Dictionary`, `from_dictionary(value, plan) -> Dictionary`, and `canonical_key() -> String`. Reject invalid coordinates, negative moves, boss-active-before-30, duplicate roster IDs, and non-six-slot formation.

- [x] **Step 4: Implement `WorldRunSaveCodecV2`**

Use root schema `twde-run-save`, `save_version=2`, the complete canonical plan text/SHA, resolved seed, and `WorldRunState.to_dictionary()`. `decode_any()` dispatches version 1 to `WorldSaveCodecV1.decode()` and version 2 locally; it never regenerates from seed.

- [x] **Step 5: Validate and run GREEN**

Run GodotIQ validate/check-errors after each script, then:

```powershell
& $godot --headless --path . --script Tests/Save/test_world_run_save_codec_v2.gd
& $godot --headless --path . --script Tests/Save/test_world_save_codec_v1.gd
```

Expected: both exit `0` with zero stderr.

- [x] **Step 6: Commit**

```powershell
git add -- Scripts/Run/world_run_state.gd Scripts/Save/world_run_save_codec_v2.gd Tests/Save/test_world_run_save_codec_v2.gd Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/red/save-v2-red.log
git commit -m "feat: add durable world run Save V2"
```

## Task 3: Add the single-slot repository

**Files:**
- Create: `Scripts/Run/world_single_slot_repository.gd`
- Create: `Tests/Run/test_world_single_slot_repository.gd`

- [x] **Step 1: Write failing repository tests**

```gdscript
var repository := WorldSingleSlotRepository.new(test_path)
_expect(not repository.has_save(), "empty slot reports no save")
_expect(repository.replace_atomic(bytes).ok, "valid run saves atomically")
_expect(repository.has_save(), "saved slot is discoverable")
_expect(repository.load_validated().value.run_state.canonical_key() == expected_key, "continue restores state")
```

Assert overwrite cancellation performs zero writes, failed replacement preserves prior bytes, legacy fixture maps to `LEGACY_WORLD_SAVE_UNSUPPORTED`, and unsupported V2 generator maps to `WORLD_VERSION_UNSUPPORTED`.

- [x] **Step 2: Run RED**

Expected: exit `1` because the repository class is missing.

- [x] **Step 3: Implement the repository**

Constructor accepts a path defaulting to `user://active-world-run.json`. `has_save()` checks existence only. `load_validated()` reads bytes and calls `WorldRunSaveCodecV2.decode_any()`. `replace_atomic()` delegates to `WorldSaveStore.save_atomic()`.

- [x] **Step 4: Validate, run repository plus existing store tests, and commit**

```powershell
& $godot --headless --path . --script Tests/Run/test_world_single_slot_repository.gd
& $godot --headless --path . --script Tests/Save/test_world_save_store.gd
git add -- Scripts/Run/world_single_slot_repository.gd Tests/Run/test_world_single_slot_repository.gd
git commit -m "feat: add single world run repository"
```

## Task 4: Implement launcher logic and injectable exit

**Files:**
- Create: `Scripts/Run/world_exit_adapter.gd`
- Create: `Scripts/Run/world_production_launcher.gd`
- Create: `Tests/Run/test_world_production_launcher.gd`
- Modify: `Scripts/Run/world_run_start_service.gd`

- [x] **Step 1: Write failing launcher tests**

Assert initial `MAIN` screen, Start New Run transitions to `NEW_RUN`, Back returns to `MAIN`, blank input produces a nonempty resolved seed, explicit seed is preserved, existing save requests overwrite confirmation, cancellation performs zero writes, Continue emits a validated session, and Exit calls an injected adapter exactly once with status 0.

- [x] **Step 2: Run RED**

Expected: exit `1` because launcher and exit adapter are missing.

- [x] **Step 3: Implement `WorldExitAdapter`**

```gdscript
class_name WorldExitAdapter
extends RefCounted

var requested_status: int = -1
var terminate_process: bool = true

func request_exit(tree: SceneTree, status: int = 0) -> void:
    requested_status = status
    if terminate_process:
        tree.quit(status)
```

- [x] **Step 4: Implement launcher state machine**

Use `enum Screen { MAIN, NEW_RUN, OVERWRITE_CONFIRM }`. Inject `WorldRunStartService`, `WorldSingleSlotRepository`, `WorldExitAdapter`, and a `PackedScene` world factory. Resolve blank seeds through cryptographic/random system entropy converted to stable text; pass the resolved text to Generator V1.

- [x] **Step 5: Extend run-start service minimally**

Return a typed dictionary containing validated `plan`, `resolved_seed`, and initial `WorldRunState`; do not add UI or process exit behavior.

- [x] **Step 6: Validate, run launcher and frozen run-start tests, and commit**

```powershell
& $godot --headless --path . --script Tests/Run/test_world_production_launcher.gd
& $godot --headless --path . --script Tests/Run/test_world_run_start_service.gd
git add -- Scripts/Run/world_exit_adapter.gd Scripts/Run/world_production_launcher.gd Scripts/Run/world_run_start_service.gd Tests/Run/test_world_production_launcher.gd
git commit -m "feat: add production world launcher logic"
```

## Task 5: Build the run-start scene

**Files:**
- Create: `Scenes/world_run_start.tscn`
- Create: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Write failing scene assertions**

Assert exact unique nodes `%ContinueButton`, `%StartNewRunButton`, `%ExitButton`, `%SeedInput`, `%StartButton`, `%BackButton`, `%OverwriteConfirmButton`, `%OverwriteCancelButton`, `%FailureHost`, and `%WorldHost`. Assert seed controls are hidden on initial main screen and Continue disabled without a save.

- [ ] **Step 2: Run RED**

Expected: exit `1` because `Scenes/world_run_start.tscn` is absent.

- [ ] **Step 3: Build the scene with GodotIQ**

Use `build_scene`/`node_ops`, attach `WorldProductionLauncher`, connect buttons to typed controller methods, instance `world_generation_failure_overlay.tscn` only on failure, save, and inspect with GodotIQ tour.

- [ ] **Step 4: Validate, run scene test, and commit**

```powershell
& $godot --headless --path . --script Tests/UI/test_world_run_start_scene.gd
git add -- Scenes/world_run_start.tscn Tests/UI/test_world_run_start_scene.gd
git commit -m "feat: add production run-start scene"
```

## Task 6: Add transaction-aligned autosave

**Files:**
- Create: `Scripts/WorldMap/world_runtime_save_coordinator.gd`
- Create: `Tests/WorldMap/test_world_runtime_save_coordinator.gd`
- Modify: `Scripts/WorldMap/world_runtime_model.gd`
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`

- [ ] **Step 1: Write failing coordinator tests**

Use a fake repository counting writes. Assert one write per accepted move, encounter resolution, reward completion, recruitment completion, and Party move; zero writes for rejected move, drag, zoom, inspect, Party open/close without mutation. Force a write failure and assert authoritative input blocks, retry writes identical bytes, and discard restores the prior durable canonical key.

- [ ] **Step 2: Run RED**

Expected: exit `1` because the coordinator is missing and controller does not expose candidate transactions.

- [ ] **Step 3: Implement candidate/commit model boundary**

Add defensive model cloning or candidate-state construction so a move can be evaluated without publishing. The coordinator encodes and saves the candidate; on success the controller publishes its snapshot, and on failure retains the candidate only for retry.

- [ ] **Step 4: Connect all authoritative owners**

Route encounter close, battle reward, recruitment completion, and Party formation mutation through the same coordinator. Presentation-only actions bypass it.

- [ ] **Step 5: Validate, run focused Stage 4 regressions, and commit**

```powershell
& $godot --headless --path . --script Tests/WorldMap/test_world_runtime_save_coordinator.gd
& $godot --headless --path . --script Tests/WorldMap/test_world_runtime_model.gd
& $godot --headless --path . --script Tests/WorldMap/test_world_runtime_scene.gd
& $godot --headless --path . --script Tests/WorldMap/test_world_runtime_migrated_flows.gd
git add -- Scripts/WorldMap/world_runtime_save_coordinator.gd Scripts/WorldMap/world_runtime_model.gd Scripts/WorldMap/world_runtime_controller.gd Tests/WorldMap/test_world_runtime_save_coordinator.gd
git commit -m "feat: autosave authoritative world transactions"
```

## Task 7: Build production world and autosave recovery

**Files:**
- Create: `Scenes/world_map_runtime.tscn`
- Create: `Scenes/world_autosave_failure_overlay.tscn`
- Create: `Scripts/UI/world_autosave_failure_overlay.gd`
- Create: `Tests/UI/test_world_autosave_failure_overlay.gd`
- Create: `Tests/WorldMap/test_world_production_scene.gd`

- [ ] **Step 1: Write failing production-scene and recovery tests**

Assert production scene has `auto_initialize_runtime=false`, rejects missing injected session, restores plan/runtime/roster before input, and hosts exactly one blocking autosave failure overlay. Assert Retry, Return, and Copy signals and that Return requests launcher restoration.

- [ ] **Step 2: Run RED**

Expected: both runners exit `1` because the artifacts are absent.

- [ ] **Step 3: Build scripts/scenes with GodotIQ**

Derive the production scene composition from the proven Stage 4 scene resources without inheriting preview auto-start. Build the recovery overlay as a saved scene with dark blocking dimmer and three explicit actions.

- [ ] **Step 4: Validate, visually inspect, run tests, and commit**

```powershell
& $godot --headless --path . --script Tests/UI/test_world_autosave_failure_overlay.gd
& $godot --headless --path . --script Tests/WorldMap/test_world_production_scene.gd
git add -- Scenes/world_map_runtime.tscn Scenes/world_autosave_failure_overlay.tscn Scripts/UI/world_autosave_failure_overlay.gd Tests/UI/test_world_autosave_failure_overlay.gd Tests/WorldMap/test_world_production_scene.gd
git commit -m "feat: add durable production world composition"
```

## Task 8: Freeze the exact cutover parent `P`

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/pre-cutover/legacy-pre-cutover.log`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/pre-cutover/frozen-tests.sha256`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/pre-cutover/godotiq-validation.json`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/baseline/parent-p-sha.txt`

- [ ] **Step 1: Run every new test and the full 37-run matrix**

Expected: zero failures and zero unexpected stderr.

- [ ] **Step 2: Run GodotIQ project validation, errors, signals, preview, launcher-by-path, and production-world-by-path health checks**

Expected: zero parser/runtime errors and no new orphan signals.

- [ ] **Step 3: Commit the implementation and identify `P`**

Commit all implementation changes. The resulting implementation commit is `P`. Generate `parent-p-sha.txt` and the pre-cutover artifacts against that exact committed tree, but leave those evidence files unstaged until the evidence-only commit after `C`; this avoids a self-referential SHA artifact changing `P`.

- [ ] **Step 4: Merge the development branch into updated `main` and create cutover branch**

```powershell
git checkout main
git pull --ff-only
git merge feat/world-production-cutover-stage5
git checkout -b cutover/world-production-stage5
```

Assert `git rev-parse HEAD` equals recorded `P` before Task 9.

## Task 9: Create the single cutover commit `C`

**Files:**
- Modify: `project.godot`
- Create: `Tests/Run/test_world_cutover_entry.gd`

- [ ] **Step 1: Write the cutover authority test before changing settings**

```gdscript
_expect(
    ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/world_run_start.tscn",
    "production authority is the Stage 5 launcher"
)
```

Run it against `P`. Expected: exit `1` because main still points to `res://Scenes/game_world.tscn`.

- [ ] **Step 2: Change production authority with the Godot editor context**

Use GodotIQ editor execution:

```gdscript
ProjectSettings.set_setting("application/run/main_scene", "res://Scenes/world_run_start.tscn")
ProjectSettings.save()
```

Do not edit `project.godot` with raw filesystem tools.

- [ ] **Step 3: Preserve legacy tests as historical pre-cutover runners**

Do not edit the frozen legacy tests in `C`. Their 25-cell assertions remain explicit historical pre-cutover runners, while the already-green radius-8 and move-30/31 successor runners own production proof. Legacy deletion or test relocation remains Stage 6 cleanup after acceptance.

- [ ] **Step 4: Run cutover test and compile check**

Expected: cutover test exits `0`; GodotIQ project check-errors reports zero.

- [ ] **Step 5: Commit exactly once**

```powershell
git add -- project.godot Tests/Run/test_world_cutover_entry.gd
git commit -m "feat: cut over production to radius-8 world"
```

Record full `C`, assert `git rev-list --parents -n 1 C` has one parent, and assert `git rev-parse C^` equals `P`. Do not amend `C` after this point.

## Task 10: Produce post-cutover evidence and request acceptance

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/migrated-post-cutover.log`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/save-compatibility.log`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/headless-contract.log`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/godotiq-validation.json`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/godotiq-runtime-health.json`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/performance-profile.json`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/visual-review.md`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/post-cutover/screenshots/`
- Create: `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/manifest.json`

- [ ] **Step 1: Run the complete post-cutover matrix against unchanged `C`**

Capture every runner, assertion summary, exit code, and stderr byte count. Include all tests named by the design inventory.

- [ ] **Step 2: Run GodotIQ gates**

Run project validate/check-errors/signal-orphans, `verify_project_runs(scene="main")`, Continue interaction, new-run blank seed, explicit seed, overwrite cancel/confirm, and autosave recovery.

- [ ] **Step 3: Run visual and performance proof**

Capture approved screenshots for launcher, seed setup, overwrite, restored world, and autosave failure. Run the 60-second 1920×1080 profile on the approved reference machine and record hardware/OS/build/timing/memory.

- [ ] **Step 4: Build and verify manifest**

Record remote base, `P`, `C`, `C^`, commands, tool versions, artifact hashes, and pending project-lead decision. Assert every file hash matches after manifest creation.

- [ ] **Step 5: Commit evidence only**

```powershell
git add -- Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5
git diff --cached --name-only
git commit -m "test: record Stage 5 production cutover evidence"
```

Expected staged paths: evidence directory only.

- [ ] **Step 6: Request project-lead acceptance**

Do not delete legacy production code until acceptance. Stage 6 cleanup requires a separate approved plan.
