# World Production Cutover Stage 5 Design

**Status:** Approved design

**Date:** 2026-08-26

**Authorities:**

- `Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md`
- `Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md`
- `Docs/superpowers/specs/2026-08-25-world-runtime-stage4-design.md`

## Purpose

Stage 5 changes production world authority from the frozen 25-cell implementation to the proven radius-8, 217-cell implementation. It adds a production run-start flow, single-run persistence, optional seed entry, transaction-aligned autosave, and the exact pre-cutover/post-cutover proof required by the migration authority.

This stage does not delete legacy production code. Legacy cleanup remains Stage 6 work after project-lead acceptance of the post-cutover packet.

## Product flow

The production main scene opens a run-start screen with three actions:

1. `Continue Saved Run`
2. `Start New Run`
3. `Exit Game`

`Start New Run` opens a separate new-run setup screen with:

- an optional world-seed input;
- `Start`;
- `Back`.

A blank seed generates a random resolved seed. An entered seed deterministically selects the world. The resolved seed persists in the save and is available in run information after the world opens.

If a saved run exists, `Start` opens a blocking overwrite confirmation. Confirming replaces the single saved run only after generation and initial save both succeed. Cancelling returns to the new-run setup screen without changing the existing save.

`Continue Saved Run` is available only when a recognized saved run exists. It validates the complete save envelope and canonical world-plan identity before opening the world.

`Exit Game` exits an interactive production process with status 0. Tests use an injected exit adapter and observe a typed request without terminating the test process.

## Concrete production entries and file map

Stage 5 pins these production scene paths:

- `Scenes/world_run_start.tscn` is the production launcher and the value assigned to `application/run/main_scene` in cutover commit `C`.
- `Scenes/world_map_runtime.tscn` is the production world composition instantiated only by the launcher after successful generation or load.
- `Scenes/world_map_runtime_preview.tscn` remains a development fixture and is never selected as the production main scene.

The implementation plan must use this file map. A path may change only through an approved design amendment before Stage 5 RED evidence is recorded.

| Path | Responsibility |
|---|---|
| `Scenes/world_run_start.tscn` | Main run-start screen, new-run seed screen, overwrite confirmation host, failure-overlay host |
| `Scripts/Run/world_production_launcher.gd` | Screen navigation, start/continue/exit orchestration, world-scene transition |
| `Scripts/Run/world_exit_adapter.gd` | Injectable interactive quit/status-0 boundary and non-terminating test result |
| `Scenes/world_map_runtime.tscn` | Production composition of Stage 4 world runtime and autosave recovery host |
| `Scripts/Run/world_run_state.gd` | Typed durable runtime value: coordinates, move/boss/encounter state, roster, formation |
| `Scripts/Save/world_run_save_codec_v2.gd` | Save V2 encoding/decoding of canonical plan plus complete `WorldRunState`; dispatch to frozen Save V1 reader |
| `Scripts/Run/world_single_slot_repository.gd` | Fixed single-slot path, existence query, validated load, atomic replacement through `WorldSaveStore` |
| `Scripts/WorldMap/world_runtime_save_coordinator.gd` | Candidate transaction serialization, exactly-once autosave, retry/discard recovery |
| `Scripts/WorldMap/world_runtime_controller.gd` | Accept injected plan/run state, expose authoritative transaction boundary, apply durable state |
| `Scenes/world_autosave_failure_overlay.tscn` | Blocking Retry Save, Return to Run-Start, Copy Diagnostics surface |
| `Scripts/UI/world_autosave_failure_overlay.gd` | Typed recovery signals and canonical diagnostics presentation |
| `Tests/Run/test_world_production_launcher.gd` | Main/new-run navigation, blank/explicit seed, overwrite, Continue, Exit adapter |
| `Tests/Run/test_world_single_slot_repository.gd` | Single-slot discovery, immutable cancellation, atomic replacement, Save V1/V2 dispatch |
| `Tests/Save/test_world_run_save_codec_v2.gd` | V2 canonical bytes, full runtime round trip, Save V1 reader preservation, failure taxonomy |
| `Tests/WorldMap/test_world_runtime_save_coordinator.gd` | Autosave/write counts, retry identity, discard-to-durable-state, UI-only no-write behavior |
| `Tests/WorldMap/test_world_production_scene.gd` | Injected startup, restored markers/HUD/Party state, no preview auto-initialization |
| `Tests/UI/test_world_autosave_failure_overlay.gd` | Blocking recovery controls and copyable diagnostics |
| `Tests/Run/test_world_cutover_entry.gd` | Project main-scene authority and absence of legacy runtime ownership after `C` |

Save V1 remains a supported parser for its existing canonical-plan envelope and fixtures. Production Stage 5 writes Save V2 because the durable roster, formation, encounter, and runtime transaction fields are outside the frozen Save V1 contract. Loading never regenerates a plan from the stored seed.

## Evidence directory contract

All Stage 5 artifacts live under `Docs/Specs/WorldMap/Evidence/ProductionCutoverStage5/`:

```text
ProductionCutoverStage5/
  baseline/
    branch-provenance.txt
    parent-p-sha.txt
    frozen-tests.sha256
  red/
    launcher-red.log
    save-v2-red.log
    autosave-red.log
    production-scene-red.log
  pre-cutover/
    legacy-pre-cutover.log
    frozen-tests.sha256
    godotiq-validation.json
  post-cutover/
    migrated-post-cutover.log
    save-compatibility.log
    headless-contract.log
    godotiq-validation.json
    godotiq-runtime-health.json
    performance-profile.json
    visual-review.md
    screenshots/
  manifest.json
```

`manifest.json` records the full remote base, `P`, `C`, `C^`, tool versions, commands, exit codes, artifact SHA-256 values, and project-lead decision. Evidence generation after `C` may not modify implementation files.

## Architecture

### Production launcher

A dedicated run-start scene becomes the production composition root. Its controller owns:

- main-screen and new-run-screen navigation;
- optional seed parsing and random-seed resolution;
- overwrite confirmation;
- continue-run requests;
- generation/load failure presentation;
- interactive exit requests;
- transition into the production world scene.

It does not own generation algorithms, world runtime mutation, battle rules, Party rules, or filesystem serialization.

### Run-start service

The existing run-start and save boundaries remain the authority for Generator V1 plan creation, canonical validation, atomic persistence, unsupported-version dispatch, and headless failure policy. Stage 5 may extend those interfaces only where runtime-state restoration or single-slot discovery is required.

No scene may observe a partial plan or partially decoded runtime state.

### Production world composition

A dedicated production world scene composes the proven Stage 4 runtime, presentation, camera, minimap, HUD, encounter, battle, and Party owners. It differs from `world_map_runtime_preview.tscn` in one critical way: it has no preview seed and no automatic preview initialization.

The launcher supplies a validated canonical plan and a validated runtime save state before world input becomes available. Directly setting the preview scene as the project main scene is forbidden.

### Runtime save coordinator

A focused coordinator sits at the authoritative transaction boundary. It converts a completed candidate runtime transaction into a versioned save envelope and requests an atomic write before publishing the transaction as durable UI state.

The coordinator owns persistence sequencing and failure recovery. It does not calculate movement, boss pursuit, encounter results, battle rewards, or Party formation rules.

## Save contract

The project supports one active saved run in this stage.

The save contains:

- the complete canonical Generator V1 world plan;
- resolved world seed;
- generator and save versions;
- canonical plan identity;
- player coordinate;
- boss coordinate;
- accepted-move count;
- boss activation and engagement state;
- consumed or resolved encounter state;
- Party roster and front/back formation;
- durable battle, reward, or recruitment state only where an existing owner already exposes a validated serialization contract.

Presentation-only state is excluded, including camera position, zoom, hovered cell, inspected cell, transient overlays, and open menu selection.

## Autosave contract

Autosave occurs after every completed authoritative change:

- accepted player movement and its boss-pursuit result;
- encounter resolution;
- battle and reward completion;
- recruitment completion;
- Party formation change.

Rejected moves, camera drag, camera zoom, cell inspection, hover, menu navigation, and other UI-only actions do not autosave.

Every autosave uses the existing atomic-write contract. The complete candidate envelope is validated and written before the next authoritative input is accepted.

If persistence fails:

1. further authoritative input is blocked;
2. the candidate in-memory transaction is retained only for retry;
3. `Retry Save` retries the identical candidate envelope;
4. `Return to Run-Start` discards the candidate and reloads the last durable state;
5. the game never silently continues from an unsaved authoritative state.

## Failure surfaces

### New-run failure

Generation or initial-save failure keeps the player on the new-run setup screen. The existing save remains untouched. A blocking failure overlay exposes copyable canonical diagnostics.

### Continue-run failure

Malformed, unsupported, or legacy-save failure keeps the player on the main run-start screen and does not modify the source save.

A recognized pre-cutover 25-cell save returns only `LEGACY_WORLD_SAVE_UNSUPPORTED`. A recognized canonical save with an unsupported generator version returns only `WORLD_VERSION_UNSUPPORTED`.

### Autosave failure

The world displays a blocking recovery surface with:

- `Retry Save`;
- `Return to Run-Start`;
- `Copy Diagnostics`.

Returning reloads the last durable save and never publishes the failed candidate as durable state.

### Headless behavior

In-process tests receive typed results and never terminate the process. Production-style headless failure writes exactly one canonical JSON record to stderr, writes no failure payload to stdout, and exits with status 70.

Interactive `Exit Game` terminates normally with status 0 through an injectable exit adapter.

## Cutover boundary

Let `P` be the exact intended cutover parent and `C` the single-parent cutover commit.

Before `C`, `Scenes/game_world.tscn` remains production authority and all frozen legacy tests remain unchanged.

The cutover implementation may be developed and tested behind explicit non-production entries before `C`. The commit `C` performs only the approved authority switch and authorized assertion disposition:

- changes `application/run/main_scene` to the production run-start launcher;
- enables the production world composition supplied by the launcher;
- replaces or retires only legacy assertions explicitly authorized by the migration authority.

`C` contains no post-cutover evidence. The evidence-only commit follows `C`. Any implementation change after evidence begins invalidates the candidate and requires a new `C`.

## Executable verification inventory

All standalone runners use:

```powershell
& $godot --headless --path . --script <runner>
```

Each command must exit `0` and write zero bytes to stderr unless the runner explicitly verifies production-headless failure output.

| Gate | Exact runner or command | Required artifact |
|---|---|---|
| Launcher navigation and Exit | `Tests/Run/test_world_production_launcher.gd` | `post-cutover/migrated-post-cutover.log` |
| Single-slot and overwrite immutability | `Tests/Run/test_world_single_slot_repository.gd` | `post-cutover/save-compatibility.log` |
| Save V2 and Save V1 dispatch | `Tests/Save/test_world_run_save_codec_v2.gd` plus existing `Tests/Save/test_world_save_codec_v1.gd` | `post-cutover/save-compatibility.log` |
| Autosave transaction contract | `Tests/WorldMap/test_world_runtime_save_coordinator.gd` | `post-cutover/migrated-post-cutover.log` |
| Production world restoration | `Tests/WorldMap/test_world_production_scene.gd` | `post-cutover/migrated-post-cutover.log` |
| Autosave recovery UI | `Tests/UI/test_world_autosave_failure_overlay.gd` | `post-cutover/migrated-post-cutover.log` |
| Cutover authority | `Tests/Run/test_world_cutover_entry.gd` | `post-cutover/migrated-post-cutover.log` |
| Generator V1 | `Tests/WorldMap/test_generator_v1_fixture_author.gd`, `Tests/WorldMap/test_generator_v1_fixture_integrity.gd`, `Tests/WorldMap/test_hex_world_generator_v1.gd`, `Tests/WorldMap/test_hex_world_geometry.gd`, `Tests/WorldMap/test_world_constraint_solver_v1.gd`, `Tests/WorldMap/test_world_plan_codec_v1.gd`, `Tests/WorldMap/test_world_priority_v1.gd` | `post-cutover/migrated-post-cutover.log` |
| Save/run-start/headless | `Tests/Save/test_world_save_codec_v1.gd`, `Tests/Save/test_world_save_store.gd`, `Tests/Run/test_world_run_start_service.gd`, `Tests/Run/test_world_headless_failure.gd`, `Tests/Run/test_world_headless_exit_process.gd` | `post-cutover/save-compatibility.log`, `post-cutover/headless-contract.log` |
| Presentation/Stage 4/camera edge | `Tests/WorldMap/test_world_camera_controller.gd`, `Tests/WorldMap/test_world_cell_view.gd`, `Tests/WorldMap/test_world_minimap.gd`, `Tests/WorldMap/test_world_presentation_profile.gd`, `Tests/WorldMap/test_world_presentation_scene.gd`, `Tests/WorldMap/test_world_runtime_migrated_flows.gd`, `Tests/WorldMap/test_world_runtime_model.gd`, `Tests/WorldMap/test_world_runtime_scene.gd`, `Tests/WorldMap/test_world_visual_fixtures.gd` | `post-cutover/migrated-post-cutover.log` |
| Frozen legacy at `P` | the 15 paths in `RuntimeStage4/baseline/frozen-tests.sha256` | `pre-cutover/legacy-pre-cutover.log`, `pre-cutover/frozen-tests.sha256` |
| Frozen-file identity | recompute SHA-256 and compare byte-for-byte with the Stage 4 baseline | `pre-cutover/frozen-tests.sha256` |
| Godot structure | GodotIQ `validate(target="project")`, `check_errors(scope="project")`, `signal_map(find="orphans")` | both `godotiq-validation.json` files |
| Runtime health | GodotIQ `verify_project_runs(scene="res://Scenes/world_run_start.tscn")` and launch/continue interaction checks for `Scenes/world_map_runtime.tscn` | `post-cutover/godotiq-runtime-health.json` |
| Production main scene | `Tests/Run/test_world_cutover_entry.gd` directly asserts `ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/world_run_start.tscn"`; GodotIQ `verify_project_runs(scene="main")` proves that configured authority starts cleanly | `post-cutover/migrated-post-cutover.log`, `post-cutover/godotiq-runtime-health.json` |
| Performance | 60-second production-world profile at 1920×1080 on the approved low-to-mid-end baseline | `post-cutover/performance-profile.json` |
| Visual | project-lead review of launcher, seed screen, overwrite, restored world, autosave failure | `post-cutover/visual-review.md`, `post-cutover/screenshots/` |
| Ancestry | `git rev-parse C^`, `git rev-parse P`, and `git rev-list --parents -n 1 C` | `manifest.json` |

The implementation plan must expand these gates into RED/GREEN steps and exact PowerShell capture commands. It may group runners into a matrix driver, but the resulting log must name every executed runner, exit code, assertion summary, and stderr byte count.

### Automated product-flow proofs

- production launch opens the run-start screen;
- main screen exposes Continue, Start New Run, and Exit Game;
- Start New Run opens the separate seed screen;
- Back returns without mutation;
- blank seed resolves and persists a generated seed;
- explicit seed produces deterministic canonical output;
- existing save requires overwrite confirmation;
- overwrite cancellation preserves the existing save byte-for-byte;
- Continue loads the single durable run;
- Exit Game uses the injected test adapter and interactive status 0 path.

### Save and runtime proofs

- each authoritative transaction produces exactly one atomic autosave;
- camera and UI-only actions produce zero save writes;
- save/reload reproduces player, boss, move, encounter, roster, and formation state;
- autosave failure blocks authoritative input;
- retry writes the identical candidate envelope;
- return discards the candidate and restores the last durable snapshot;
- unsupported legacy and unsupported canonical versions remain immutable typed failures.

### Regression and runtime gates

- Generator V1, Save V1, Presentation Stage 3, Runtime Stage 4, camera-edge, headless, and migrated suites pass;
- frozen legacy tests and hashes pass against `P`;
- successor tests pass against `C`;
- GodotIQ project validation and error checks contain no new Stage 5 issue;
- production launcher and production world pass runtime startup and interaction checks;
- visual review covers main screen, seed screen, overwrite confirmation, world entry, and failure recovery;
- performance profiling runs on the approved low-to-mid-end desktop baseline.

## Evidence and approval

The cutover packet follows the migration authority and records:

- full remote base SHA;
- full `P` SHA;
- full `C` SHA;
- proof that `git rev-parse C^` equals `P`;
- commands, environment, results, and SHA-256 artifact hashes;
- pre-cutover legacy results;
- post-cutover successor results;
- save, headless, GodotIQ, runtime-health, visual, and performance evidence;
- project-lead acceptance.

## Rollback and cleanup

Before acceptance, rollback restores production authority to `P`. It does not modify evidence or promise cross-boundary save compatibility.

After acceptance, defects are fixed forward with targeted evidence. Stage 6 may remove unreachable legacy production code and replace obsolete test entry points, but it preserves historical evidence, unsupported-legacy fixtures, and supported Generator V1 readers.

## Explicit exclusions

Stage 5 does not add:

- multiple save slots;
- seed browsing or seed history;
- cloud saves;
- legacy-save conversion;
- manual save controls;
- persistence of camera or other presentation-only state;
- legacy cleanup before post-cutover acceptance.
