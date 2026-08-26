# Scrollable World Runtime Stage 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and prove the non-production radius-8 runtime path with atomic movement, encounter transitions, Party access, move-30/31 boss pursuit, synchronized presentation, and migrated successor tests while leaving the 25-cell production path frozen.

**Architecture:** A pure `WorldRuntimeModel` owns all mutable world-map runtime state and returns immutable `WorldRuntimeSnapshot` plus typed `WorldMoveResult` values. `WorldRuntimeController` is the sole non-production scene orchestrator; it applies snapshots to the existing Stage 3 presentation and opens existing encounter, battle, and Party components without calling `MapController` or changing production authority.

**Tech Stack:** Godot 4.7 GDScript, GodotIQ structured scene/script tools, headless SceneTree test runners, Git, PowerShell evidence commands.

---

## Authority, branch, and rollback boundary

- Design: `Docs/superpowers/specs/2026-08-25-world-runtime-stage4-design.md`
- Target: `Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md`
- Migration: `Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md`
- Task branch: `feat/world-runtime-stage4`
- Integration destination: local `main` after review and project-lead choice.
- Base commit: `eab0689` (`main` immediately before the Stage 4 design branch).
- Rollback removes only Stage 4-created files and the explicitly listed WorldMap presentation extensions. It must not touch `Scenes/game_world.tscn`, `Scripts/Map`, or frozen legacy tests.
- Unrelated untracked files remain excluded: `.github/agents/race-class-designer.agent.md`, `Tests/Battle/test_active_turn_skill_lock.gd.uid`, and `Tests/Map/test_world_turn_counter.gd.uid`.

Before every `.gd` or `.tscn` edit, use GodotIQ `file_context(detail="brief")`; use `impact_check` for public signature or signal changes. After each script edit, run GodotIQ `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`.

## Concrete file map

### Create

| Path | Responsibility |
|---|---|
| `Scripts/WorldMap/world_runtime_snapshot.gd` | Immutable canonical runtime state value |
| `Scripts/WorldMap/world_move_result.gd` | Typed accepted/rejected move result |
| `Scripts/WorldMap/world_runtime_model.gd` | Pure movement, encounter, turn, and pursuit authority |
| `Scripts/WorldMap/world_runtime_controller.gd` | Stage 4 composition and snapshot application |
| `Scenes/world_map_runtime_preview.tscn` | Sole non-production runtime entry |
| `Tests/WorldMap/test_world_runtime_model.gd` | Pure transaction tests |
| `Tests/WorldMap/test_world_runtime_scene.gd` | Presentation, blocking, minimap, HUD, and camera tests |
| `Tests/WorldMap/test_world_runtime_migrated_flows.gd` | Retained AC1/AC2/AC3 successor tests |
| `Docs/Specs/WorldMap/Evidence/RuntimeStage4/**` | Baseline, RED/GREEN, isolation, runtime, and manual proof |

### Modify

| Path | Bounded change |
|---|---|
| `Scripts/WorldMap/world_cell_view.gd` | Emit axial selection/inspection signals only |
| `Scenes/world_map_cell.tscn` | Wire cell input node to `WorldCellView` |
| `Scripts/WorldMap/world_presentation_controller.gd` | Apply snapshots, highlights, marker updates, and expose typed selection signals |
| `Scripts/WorldMap/world_minimap.gd` | Move player/boss markers without rebuilding the plan |
| `Tests/WorldMap/test_world_cell_view.gd` | Selection signal contract |
| `Tests/WorldMap/test_world_minimap.gd` | Marker-update contract |
| `Tests/WorldMap/test_world_presentation_scene.gd` | Snapshot-application contract without runtime ownership |

## Fixed interfaces

```gdscript
# world_runtime_snapshot.gd
class_name WorldRuntimeSnapshot
extends RefCounted

var _player_coord: Vector2i
var _boss_coord: Vector2i
var _move_count: int
var _sudden_death_active: bool
var _input_blocked: bool
var _boss_encounter_open: bool

var player_coord: Vector2i:
    get: return _player_coord
var boss_coord: Vector2i:
    get: return _boss_coord
var move_count: int:
    get: return _move_count
var sudden_death_active: bool:
    get: return _sudden_death_active
var input_blocked: bool:
    get: return _input_blocked
var boss_encounter_open: bool:
    get: return _boss_encounter_open

func _init(
    player: Vector2i,
    boss: Vector2i,
    accepted_moves: int,
    sudden_death: bool,
    blocked: bool,
    boss_open: bool
) -> void:
    _player_coord = player
    _boss_coord = boss
    _move_count = accepted_moves
    _sudden_death_active = sudden_death
    _input_blocked = blocked
    _boss_encounter_open = boss_open

func duplicate_value() -> WorldRuntimeSnapshot:
    return WorldRuntimeSnapshot.new(
        player_coord, boss_coord, move_count,
        sudden_death_active, input_blocked, boss_encounter_open
    )

func canonical_key() -> String:
    return "%d,%d|%d,%d|%d|%d|%d|%d" % [
        player_coord.x, player_coord.y, boss_coord.x, boss_coord.y,
        move_count, int(sudden_death_active), int(input_blocked),
        int(boss_encounter_open),
    ]
```

```gdscript
# world_move_result.gd
class_name WorldMoveResult
extends RefCounted

enum Status { ACCEPTED, REJECTED }
enum Rejection { NONE, INPUT_BLOCKED, INVALID_DESTINATION, NOT_ADJACENT, BOSS_ENCOUNTER_OPEN }

var status: Status
var rejection: Rejection
var snapshot: WorldRuntimeSnapshot
var previous_player_coord: Vector2i
var previous_boss_coord: Vector2i
var boss_moved: bool
var encounter_type: String

func is_accepted() -> bool:
    return status == Status.ACCEPTED
```

```gdscript
# world_runtime_model.gd public surface
class_name WorldRuntimeModel
extends RefCounted

const SUDDEN_DEATH_THRESHOLD := 30

func configure(plan: WorldPlan) -> bool
func get_snapshot() -> WorldRuntimeSnapshot
func get_valid_destinations() -> Array[Vector2i]
func get_runtime_encounter_type(coord: Vector2i) -> String
func request_move(destination: Vector2i) -> WorldMoveResult
func set_surface_blocked(value: bool) -> void
func close_ordinary_encounter() -> void
func reset() -> void
```

```gdscript
# presentation/controller additions
signal cell_selected(coord: Vector2i)
signal cell_inspected(coord: Vector2i)

func apply_runtime_snapshot(snapshot: WorldRuntimeSnapshot) -> void
func set_valid_destinations(coords: Array[Vector2i]) -> void
func update_party_markers(player_coord: Vector2i, boss_coord: Vector2i) -> void
func get_world_camera() -> WorldCameraController
```

## Task 1: Freeze Stage 4 baseline and create RED harnesses

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/baseline/base-sha.txt`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/baseline/frozen-tests.sha256`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/baseline/frozen-legacy.log`
- Create: `Tests/WorldMap/test_world_runtime_model.gd`
- Create: `Tests/WorldMap/test_world_runtime_scene.gd`
- Create: `Tests/WorldMap/test_world_runtime_migrated_flows.gd`

- [ ] **Step 1: Record provenance and frozen hashes**

Run PowerShell from the repository root:

```powershell
git rev-parse main
git rev-parse HEAD
git diff --exit-code main -- Scenes/game_world.tscn Scripts/Map Tests/Map
Get-FileHash -Algorithm SHA256 Tests/Map/*.gd Tests/Run/test_ac3_1_run_roster.gd Tests/Run/test_ac3_3_party_formation.gd
```

Expected: base begins at `eab0689`; isolation exits `0`; hashes are recorded verbatim in the evidence files.

- [ ] **Step 2: Run the complete frozen suite**

Use the Godot executable path already proven in project evidence and run every frozen test named by the migration authority. Record each script path, exit code, and assertion summary in `frozen-legacy.log`.

Expected: every runner exits `0`; no frozen file changes.

- [ ] **Step 3: Create three compiling RED runners**

Each runner extends `SceneTree`, tracks assertion count, prints a named PASS summary, and exits `1` on failures. The model runner must load the three proposed value/model scripts by `load()` and assert they exist. The scene runner must load `res://Scenes/world_map_runtime_preview.tscn`. The migrated-flow runner must assert production remains `res://Scenes/game_world.tscn` and the Stage 4 entry exposes runtime movement, encounter, Party, and battle inspection methods.

- [ ] **Step 4: Validate and run RED**

Run:

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_model.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_scene.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_migrated_flows.gd
```

Expected: all three fail only because the proposed Stage 4 files/scene do not exist. Save stdout/stderr beneath `Docs/Specs/WorldMap/Evidence/RuntimeStage4/red/`.

- [ ] **Step 5: Commit**

```powershell
git add -- Tests/WorldMap/test_world_runtime_*.gd Docs/Specs/WorldMap/Evidence/RuntimeStage4
git commit -m "test: lock Stage 4 runtime integration contract"
```

## Task 2: Implement immutable values and rejected transactions

**Files:**
- Create: `Scripts/WorldMap/world_runtime_snapshot.gd`
- Create: `Scripts/WorldMap/world_move_result.gd`
- Create: `Scripts/WorldMap/world_runtime_model.gd`
- Test: `Tests/WorldMap/test_world_runtime_model.gd`

- [ ] **Step 1: Extend RED assertions**

Add tests that generate `golden-alpha`, configure the model, and assert:

```gdscript
var initial := model.get_snapshot()
_expect(initial.player_coord == Vector2i(-8, 0), "player starts at canonical corner")
_expect(initial.boss_coord == Vector2i(8, 0), "boss starts at canonical corner")
_expect(initial.move_count == 0, "accepted count starts at zero")
_expect(not initial.sudden_death_active, "boss starts dormant")
var key_before := initial.canonical_key()
var rejected := model.request_move(Vector2i(8, 8))
_expect(not rejected.is_accepted(), "invalid destination is rejected")
_expect(model.get_snapshot().canonical_key() == key_before, "rejection is atomic")
model.set_surface_blocked(true)
rejected = model.request_move(Vector2i(-7, 0))
_expect(rejected.rejection == WorldMoveResult.Rejection.INPUT_BLOCKED, "blocked input is typed")
_expect(model.get_snapshot().canonical_key() != key_before, "blocking state is represented explicitly")
```

- [ ] **Step 2: Run RED**

Expected: failure for missing `WorldRuntimeSnapshot`, `WorldMoveResult`, and `WorldRuntimeModel`.

- [ ] **Step 3: Implement the fixed value interfaces and minimal model**

Implement `configure()` by rejecting null or `WorldPlanCodecV1.validate(plan) != null`, retaining the plan, and calling `reset()`. `get_snapshot()` must always return `duplicate_value()`. `get_valid_destinations()` filters `HexWorldGeometry.NEIGHBOR_OFFSETS` in fixed order against plan cells. Rejection helpers must attach a duplicate unchanged snapshot.

- [ ] **Step 4: Validate and run GREEN**

Expected: zero GodotIQ issues/errors for each new script; rejection and initialization assertions pass.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/WorldMap/world_runtime_snapshot.gd Scripts/WorldMap/world_move_result.gd Scripts/WorldMap/world_runtime_model.gd Tests/WorldMap/test_world_runtime_model.gd
git commit -m "feat: add pure world runtime state"
```

## Task 3: Implement accepted movement and move-30/31 pursuit

**Files:**
- Modify: `Scripts/WorldMap/world_runtime_model.gd`
- Modify: `Tests/WorldMap/test_world_runtime_model.gd`

- [ ] **Step 1: Add RED transaction vectors**

Drive a deterministic adjacent route that avoids the boss for 31 moves, closing each ordinary encounter between requests. Assert every accepted result increments once, result snapshot equals model snapshot, move 30 changes `sudden_death_active` with `boss_moved == false`, and move 31 changes the boss by one adjacent shortest-path step. Add a tie fixture where two steps reduce distance and assert the first `HexMapModel.NEIGHBOR_OFFSETS` candidate wins. Add direct player-to-boss and boss-to-player engagement fixtures and assert exactly one `boss` encounter followed by `BOSS_ENCOUNTER_OPEN` rejection.

- [ ] **Step 2: Run RED**

Expected: accepted movement, pursuit, and encounter assertions fail while initialization/rejection remains green.

- [ ] **Step 3: Implement the exact transaction**

Use this order inside `request_move()`:

```gdscript
var before := get_snapshot()
var was_active := _sudden_death_active
_player_coord = destination
_move_count += 1
if _player_coord == _boss_coord:
    return _accept(before, false, "boss", true)
if _move_count == SUDDEN_DEATH_THRESHOLD:
    _sudden_death_active = true
if was_active:
    _boss_coord = _get_pursuit_step(_boss_coord, _player_coord)
    if _boss_coord == _player_coord:
        return _accept(before, true, "boss", true)
return _accept(before, was_active, get_runtime_encounter_type(_player_coord), false)
```

`_get_pursuit_step()` iterates `HexMapModel.NEIGHBOR_OFFSETS` and selects the first valid neighbor whose distance is strictly smaller than the current best. `get_runtime_encounter_type()` returns `boss` only at the moving boss, forces `(8, 0)` to `safe` after the boss vacates it, and otherwise reads the plan cell encounter.

- [ ] **Step 4: Validate and run GREEN twice**

Run the model runner twice in clean processes and compare PASS output. Expected: identical assertion count and exit `0` both times.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/WorldMap/world_runtime_model.gd Tests/WorldMap/test_world_runtime_model.gd
git commit -m "feat: add deterministic world movement and pursuit"
```

## Task 4: Add snapshot-driven presentation adapters

**Files:**
- Modify: `Scripts/WorldMap/world_cell_view.gd`
- Modify: `Scenes/world_map_cell.tscn`
- Modify: `Scripts/WorldMap/world_minimap.gd`
- Modify: `Scripts/WorldMap/world_presentation_controller.gd`
- Modify: `Tests/WorldMap/test_world_cell_view.gd`
- Modify: `Tests/WorldMap/test_world_minimap.gd`
- Modify: `Tests/WorldMap/test_world_presentation_scene.gd`

- [ ] **Step 1: Add RED signal and adapter assertions**

Assert cell input emits `selected(coordinate)` and `inspected(coordinate)` without changing cell data. Assert `WorldMinimap.update_party_markers()` changes both icon positions but preserves plan instance ID and camera footprint. Assert applying a snapshot moves exactly one player marker and one boss marker, refreshes six valid-neighbor highlights, and does not expose `request_move()` on `WorldPresentationController`.

- [ ] **Step 2: Run RED**

Expected: missing signals and update methods only.

- [ ] **Step 3: Implement adapters through GodotIQ**

Add typed cell signals and use `_unhandled_input` or the scene's existing input control to emit only pointer selection/inspection. Store instantiated cells by coordinate in `WorldPresentationController`. Implement `apply_runtime_snapshot()` as idempotent marker removal/addition plus `WorldMinimap.update_party_markers()`. Implement `set_valid_destinations()` by comparing the supplied set with each stored cell and calling `set_highlighted()`.

- [ ] **Step 4: Validate scenes/scripts and run GREEN**

Expected: cell, minimap, and presentation runners all exit `0`; project main scene setting is unchanged.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/WorldMap/world_cell_view.gd Scenes/world_map_cell.tscn Scripts/WorldMap/world_minimap.gd Scripts/WorldMap/world_presentation_controller.gd Tests/WorldMap/test_world_cell_view.gd Tests/WorldMap/test_world_minimap.gd Tests/WorldMap/test_world_presentation_scene.gd
git commit -m "feat: add world runtime presentation adapters"
```

## Task 5: Compose the isolated Stage 4 runtime scene

**Files:**
- Create: `Scripts/WorldMap/world_runtime_controller.gd`
- Create: `Scenes/world_map_runtime_preview.tscn`
- Modify: `Tests/WorldMap/test_world_runtime_scene.gd`

- [ ] **Step 1: Add RED composition assertions**

Load the exact Stage 4 scene and assert: one validated Generator V1 plan is shared; runtime snapshot starts canonical; production main remains frozen; no `MapController` node exists; cell selection accepts only highlighted neighbors; marker/minimap/HUD state matches the result; camera pan/zoom leaves `canonical_key()` unchanged.

- [ ] **Step 2: Run RED**

Expected: scene/controller missing while pure model tests stay green.

- [ ] **Step 3: Build the scene and controller**

Use GodotIQ `scene_map` on `world_map_preview.tscn`, then `build_scene`/`node_ops(validate=true)` to create the saved Stage 4 scene with Stage 3 presentation composition, controller, encounter host, battle host, and Party host. The controller must validate dependencies before enabling cell input, generate/present one fixture plan for the non-production preview, configure `WorldRuntimeModel`, connect cell/HUD signals, and call one `_apply_snapshot()` method after every accepted result.

- [ ] **Step 4: Apply snapshots in one direction**

`_apply_snapshot(snapshot)` calls presentation marker/highlight methods, HUD `set_turn_state()`, HUD formation/context/availability setters, then the camera visibility rule. It never reads runtime fields back from those nodes. On an exception or missing dependency, set `_integration_failed = true`, call `model.set_surface_blocked(true)`, and reject later selections.

- [ ] **Step 5: Validate, tour, and run GREEN**

Run GodotIQ `validate`, `check_errors`, `run(action="play", scene="res://Scenes/world_map_runtime_preview.tscn")`, `verify_project_runs`, debug console, and one screenshot. Expected: runtime scene starts with no errors; tests exit `0`; production remains untouched.

- [ ] **Step 6: Commit**

```powershell
git add -- Scripts/WorldMap/world_runtime_controller.gd Scenes/world_map_runtime_preview.tscn Tests/WorldMap/test_world_runtime_scene.gd
git commit -m "feat: compose non-production world runtime"
```

## Task 6: Integrate encounter, battle, Party, and roster flows

**Files:**
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`
- Modify: `Scenes/world_map_runtime_preview.tscn`
- Modify: `Tests/WorldMap/test_world_runtime_scene.gd`
- Modify: `Tests/WorldMap/test_world_runtime_migrated_flows.gd`

- [ ] **Step 1: Add RED migrated-flow assertions**

Assert one accepted Safe/Combat move opens one configured `EncounterOverlay`; repeated cell input is rejected while open; closing an ordinary overlay clears model blocking without moving the boss; `battle_requested` opens one configured `BattleArena`; battle exit restores map blocking state; `party_requested` opens one `PartyManagement.configure_normal()` instance; formation moves mutate `RunRoster` only and then refresh HUD; Party close consumes zero moves.

- [ ] **Step 2: Run RED**

Expected: overlay/Party/battle ownership assertions fail; pure movement remains green.

- [ ] **Step 3: Implement existing public adapter contracts**

Instantiate the existing packed scenes in the Stage 4 hosts. Connect `EncounterOverlay.close_requested` and `battle_requested`; `BattleArena.exit_requested`, `battle_completed`, reward, and recruitment signals; `PartyManagement.move_requested` and `close_requested`; and `WorldMapHud.party_requested`. Before opening any surface call `model.set_surface_blocked(true)`. Only ordinary encounter close, completed/closed battle, or Party close may clear the matching controller-owned blocker. Boss encounter close must not unblock movement.

- [ ] **Step 4: Run migrated GREEN plus frozen regressions**

Expected: all three Stage 4 runners exit `0`; frozen AC1, AC2, AC3, roster, formation, and world-turn runners remain byte/hash unchanged and exit `0`.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/WorldMap/world_runtime_controller.gd Scenes/world_map_runtime_preview.tscn Tests/WorldMap/test_world_runtime_scene.gd Tests/WorldMap/test_world_runtime_migrated_flows.gd
git commit -m "feat: integrate world runtime flows"
```

## Task 7: Prove conditional camera recentering and runtime isolation

**Files:**
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`
- Modify: `Tests/WorldMap/test_world_runtime_scene.gd`
- Modify: `Tests/WorldMap/test_world_runtime_migrated_flows.gd`

- [ ] **Step 1: Add RED camera vectors**

Center the camera so the next destination remains inside `get_visible_world_rect()` and assert accepted movement does not change camera position. Then center away from the next destination, accept the move, and assert camera position becomes `presentation.axial_to_world(snapshot.player_coord)` exactly once. Pan and zoom afterward and assert runtime `canonical_key()` remains unchanged.

- [ ] **Step 2: Implement the exact visibility contract**

```gdscript
func _recenter_if_player_hidden(snapshot: WorldRuntimeSnapshot) -> void:
    var marker_center := _presentation.axial_to_world(snapshot.player_coord)
    if not _world_camera.get_visible_world_rect().has_point(marker_center):
        _world_camera.center_on(marker_center)
```

Call this once at the end of successful snapshot application and never from inspection, minimap, or camera signals.

- [ ] **Step 3: Add production-isolation assertions**

Assert no dependency path from `Scenes/game_world.tscn` or `Scripts/Map/map_controller.gd` to Stage 4 files, main scene unchanged, Stage 4 scene launch requires explicit path, and failed model configuration creates zero cells/surfaces/runtime mutations.

- [ ] **Step 4: Run GREEN and commit**

```powershell
git add -- Scripts/WorldMap/world_runtime_controller.gd Tests/WorldMap/test_world_runtime_scene.gd Tests/WorldMap/test_world_runtime_migrated_flows.gd
git commit -m "test: prove Stage 4 camera and production isolation"
```

## Task 8: Produce Stage 4 evidence and request review

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/green/automated-tests.log`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/green/frozen-tests.sha256`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/green/isolation-proof.txt`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/green/godotiq-validation.json`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/green/runtime-health.json`
- Create: `Docs/Specs/WorldMap/Evidence/RuntimeStage4/manual-review.md`

- [x] **Step 1: Run the full automated matrix**

Run all `Tests/WorldMap/test_*.gd`, all frozen tests named by the migration authority, and the existing Generator V1, Save V1, Presentation Stage 3, and camera-edge suites. Record exact commands, assertion summaries, stderr, and exit codes. Expected: zero failures.

- [x] **Step 2: Run GodotIQ project gates**

Run project `validate`, project `check_errors`, `signal_map(find="orphans")`, runtime preview `verify_project_runs`, and production main `verify_project_runs`. Expected: zero parser/runtime errors and no new orphan signals.

- [x] **Step 3: Record isolation**

```powershell
git diff --exit-code main -- Scenes/game_world.tscn Scripts/Map Tests/Map
git diff --name-only main...HEAD
git status --short
```

Expected: isolation exit `0`; only Stage 4 and approved WorldMap presentation paths differ; unrelated untracked exclusions remain untouched.

- [x] **Step 4: Perform manual runtime review**

Using the explicit Stage 4 scene, record observations for valid-neighbor movement, Safe/Combat overlay, Party open/close, camera preservation/recenter, move 30 activation, move 31 pursuit, later pursuit, and one Boss engagement. Capture one screenshot only where it materially proves synchronized main-map/minimap boss movement.

- [x] **Step 5: Request code and architecture review**

Review against the Stage 4 design, target design WM-T07/WM-T10/WM-T11, migration isolation, and evidence packet. Fix every Critical or Important finding and rerun affected plus full gates.

- [x] **Step 6: Commit evidence**

```powershell
git add -- Docs/Specs/WorldMap/Evidence/RuntimeStage4
git commit -m "test: record Stage 4 runtime evidence"
```

## Final acceptance checklist

- [x] Pure model state is the sole runtime authority and snapshots are defensive immutable values.
- [x] Rejected moves are typed and atomic.
- [x] Move 30 activates without pursuit; move 31 and every later accepted unengaged move has exactly one pursuit step.
- [x] Both engagement directions open one Boss encounter and permanently block map movement.
- [x] Main map, minimap, highlights, HUD, encounter, and Party state derive from one snapshot.
- [x] Camera-only/UI-only actions consume zero moves and cause no boss movement.
- [x] Conditional camera recenter uses the implemented visible-rectangle contract.
- [x] Migrated AC1/AC2/AC3 successor flows pass through the explicit Stage 4 scene.
- [x] Full frozen legacy suite and hashes remain unchanged and green.
- [x] Generator V1, Save V1, Stage 3, and edge-centering regressions remain green.
- [x] Production main scene remains `Scenes/game_world.tscn`; `Scripts/Map` and frozen tests are unchanged.
- [x] GodotIQ project validation, parse, signal, preview runtime, and production runtime gates pass.
- [x] No cutover, legacy cleanup, or unrelated feature is included.
