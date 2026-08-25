# Scrollable World Runtime Integration — Stage 4 Design

**Status:** Approved design

**Date:** 2026-08-25

**Authority:** `2026-08-23-scrollable-hex-world-target-design.md` and `2026-08-23-25-to-217-hex-world-migration-design.md`

**Scope:** Non-production runtime integration for the radius-8, 217-cell world. This stage does not authorize production cutover.

## Purpose

Stage 4 connects the proven Generator V1 world plan and Stage 3 presentation to accepted player movement, encounter transitions, Party access, turn semantics, and deterministic move-30/31 boss pursuit. The current 25-cell production scene remains authoritative until a separate candidate-cutover stage passes its exact evidence rule.

`Scenes/game_world.tscn`, `Scripts/Map/map_controller.gd`, `Scripts/Map/hex_map_model.gd`, and the frozen legacy tests remain unchanged during this stage.

## Current repository state

This document is the approved pre-implementation design for Stage 4. The runtime model, runtime controller, Stage 4 scene, Stage 4 tests, and Stage 4 evidence directory intentionally do not exist at this design commit. Their absence is expected and is not evidence that Stage 4 behavior is implemented.

Repository-backed prerequisites already exist:

- Generator V1 and immutable fixtures under `Scripts/WorldMap` and `Tests/Fixtures/WorldMap/GeneratorV1`;
- Save V1 and run-start boundaries under `Scripts/Run`;
- the saved 217-cell presentation composition at `Scenes/world_map_preview.tscn`;
- `WorldPresentationController`, `WorldCameraController`, `WorldMinimap`, `WorldCellView`, and `WorldMapHud`;
- the existing `EncounterOverlay`, `BattleArena`, `PartyManagement`, `RunRoster`, and their frozen legacy integration tests.

The implementation plan must create the proposed Stage 4 files and produce RED evidence before adding runtime behavior. No acceptance statement may treat this design document as runtime proof.

## Concrete non-production entry and proposed file map

Stage 4 owns one explicit scene: `Scenes/world_map_runtime_preview.tscn`. It composes or inherits the saved Stage 3 presentation and adds `WorldRuntimeController` plus the existing encounter, battle, and Party scene resources. Tests and manual development launch this exact scene path. It is never assigned to `application/run/main_scene`, referenced by `Scenes/game_world.tscn`, or selected by normal run start before cutover.

The implementation plan may refine names only before RED evidence is generated, but must preserve these responsibilities:

| Proposed path | Responsibility |
|---|---|
| `Scripts/WorldMap/world_runtime_snapshot.gd` | Immutable value snapshot and canonical comparison form |
| `Scripts/WorldMap/world_move_result.gd` | Typed accepted/rejected transaction result |
| `Scripts/WorldMap/world_runtime_model.gd` | Pure movement, turn, blocking, encounter, and pursuit authority |
| `Scripts/WorldMap/world_runtime_controller.gd` | Non-production composition and snapshot-to-view orchestration |
| `Scenes/world_map_runtime_preview.tscn` | Sole Stage 4 development and integration entry |
| `Tests/WorldMap/test_world_runtime_model.gd` | Pure transaction and determinism contract |
| `Tests/WorldMap/test_world_runtime_scene.gd` | Scene, marker, HUD, minimap, camera, and blocking contract |
| `Tests/WorldMap/test_world_runtime_migrated_flows.gd` | Retained AC1, AC2, and AC3 successor behaviors |
| `Docs/Specs/WorldMap/Evidence/RuntimeStage4/` | Baseline, RED/GREEN, runtime-health, isolation, and manual evidence |

An automated isolation test must assert all of the following:

- `application/run/main_scene` remains `res://Scenes/game_world.tscn`;
- `Scenes/game_world.tscn` has no dependency on the Stage 4 scene or controller;
- `MapController` never imports or instantiates the Stage 4 model/controller;
- launching the Stage 4 scene requires its exact path or a test runner;
- constructing or failing Stage 4 runtime state cannot mutate a live legacy run.

## Architecture and ownership

### Pure runtime model

A new pure `RefCounted` world runtime model is initialized from one validated `WorldPlan`. It owns only mutable world-runtime state:

- player coordinate;
- moving boss coordinate;
- accepted move count;
- Sudden Death active state;
- current movement-blocking state;
- whether a Boss encounter has opened.

The model owns no scene nodes, rendering, camera behavior, filesystem I/O, save mutation, roster mutation, or overlay construction. It uses radius-8 geometry for validity, adjacency, and distance while preserving `HexMapModel.NEIGHBOR_OFFSETS` order as the pursuit tie-break contract.

`request_move(destination)` is one atomic transaction. It returns a typed move result containing either a rejection reason with an unchanged snapshot or the complete accepted transaction outcome. An accepted result records the previous and current player coordinates, previous and current boss coordinates, accepted move count, Sudden Death transition, whether the boss moved, and the encounter to open.

### Runtime controller

A new non-production world runtime controller composes:

- the pure runtime model;
- the existing `WorldPresentationController`;
- the existing encounter overlay and battle flow;
- the existing Party management and run-roster owners;
- the Stage 3 HUD, camera, and minimap.

The controller forwards deliberate cell selections to the model and applies the returned authoritative snapshot to presentation. It may open or close existing UI flows, but it does not duplicate their internal encounter, battle, recruitment, formation, or roster rules.

The model's immutable snapshot is the sole world-runtime source of truth. Presentation nodes never write player coordinate, boss coordinate, accepted count, Sudden Death, or blocking state. Camera and inspection actions read a snapshot or presentation data and do not call a model mutator.

Before enabling input, the controller validates every required node, resource, signal, and public adapter contract. A valid move follows this boundary:

1. request and complete one model transaction;
2. retain its complete immutable post-transaction snapshot;
3. apply that same snapshot idempotently to all world presentation consumers;
4. open the one encounter surface named by the result;
5. enable only the inputs allowed by the resulting blocking state.

If presentation application raises an error after the model transaction, the model snapshot remains authoritative, all map input is disabled, and the controller records an internal integration failure. It never reconstructs model state from partially updated nodes. Reapplying the same snapshot is the only permitted recovery operation in Stage 4 tests; there is no reverse synchronization from UI to model.

Existing system contracts used by Stage 4 are explicit:

- `EncounterOverlay.configure(coordinate, type)`, `close_requested`, and `battle_requested` own encounter presentation and the battle request boundary.
- `BattleArena.configure(coordinate, type)`, `exit_requested`, `battle_completed`, reward, and recruitment signals retain battle-flow ownership.
- `PartyManagement.configure_normal(slots)`, `move_requested`, and `close_requested` operate on the existing `RunRoster` formation owner; the world runtime model never stores formation data.
- `WorldMapHud.set_turn_state`, `set_formation`, `set_context`, `set_party_available`, and `party_requested` are the complete Stage 4 HUD adapter surface.
- The controller owns scene instances and signal connections for these adapters. `MapController` is not used as an adapter and is not called from the Stage 4 path.

### Presentation boundaries

`WorldPresentationController` remains rendering-only. It may gain narrowly scoped methods to apply runtime snapshots, marker positions, highlights, and inspection context. `WorldCellView` may emit a typed axial-coordinate selection signal. Neither class decides whether a move is valid or increments a turn.

The Stage 4 composition remains reachable only through tests, an explicit development launch, or a dedicated non-production scene. It does not change `application/run/main_scene`.

## Accepted-move transaction

The runtime model executes this exact order:

1. Reject the request when an encounter, battle, Party-management, or generation-failure surface blocks input.
2. Reject an invalid, off-board, identical, or non-adjacent destination.
3. Move the player to the accepted destination and increment accepted move count exactly once.
4. If the player entered the current boss coordinate, open one Boss encounter and end the transaction without activating or moving the boss.
5. If the accepted count became 30, activate Sudden Death without moving the boss.
6. If Sudden Death was already active before this move, take exactly one adjacent shortest-path boss step toward the player, using fixed neighbor-order tie-breaking.
7. If the boss reached the player, open one Boss encounter and end the transaction.
8. Otherwise, open the entered destination's canonical Safe or Combat encounter.
9. Publish one complete result and snapshot.

The accepted count continues increasing after Sudden Death activates. Closing or resolving an ordinary encounter enables the next move but never creates an additional boss step. Once a Boss encounter opens, map movement and pursuit remain blocked.

Rejected input, camera pan, camera zoom, inspection-only pointer movement, Party operations, and repeated input while blocked do not increment accepted move count, activate Sudden Death, move the boss, or open another encounter.

The boss's vacated coordinate resolves using its canonical underlying encounter, with the fixed boss start forced Safe after the boss moves. The moving boss coordinate is the only runtime Boss encounter.

Reset recreates the runtime state from the validated plan with player `(-8, 0)`, boss `(8, 0)`, accepted move count zero, Sudden Death dormant, and no blocking encounter.

## Presentation and interaction behavior

- Each main-map cell emits its axial coordinate when selected.
- Only valid adjacent destinations receive the strong actionable highlight.
- Hovering or inspecting a valid neighbor updates the bottom bar with its encounter and terrain without consuming a move.
- Selecting a highlighted neighbor requests one model transaction.
- After an accepted transaction, main-map markers, minimap markers, valid-neighbor highlights, countdown, boss state, context text, and Party availability refresh from one runtime snapshot.
- `Manage Party` opens the existing Party management flow and is unavailable while an encounter or battle blocks the map.
- Safe and Combat results use the existing encounter overlay and battle transition behavior. Boss engagement uses the existing Boss encounter and battle flow.
- Town and forest data remain presentation-only. Towns are already canonical Safe cells; forests do not modify movement or encounter behavior.

The camera preserves the player's chosen position after ordinary movement. After presentation updates, if the new player-marker center lies outside the current visible world rectangle, the camera centers on the player exactly once. No automatic recenter occurs while the player remains visible.

This rule maps directly to the implemented camera contract. The controller obtains the rectangle from `WorldCameraController.get_visible_world_rect()`, obtains the marker center from `WorldPresentationController.axial_to_world(snapshot.player_coord)`, checks `Rect2.has_point(marker_center)`, and calls `WorldCameraController.center_on(marker_center)` only when that check is false. Camera methods never receive or mutate the runtime model.

The minimap updates both party markers after every accepted transaction, including boss pursuit. Camera footprint behavior remains independent of turn state.

## Typed results and failure behavior

Move rejection reasons are stable typed values covering at least:

- input blocked;
- invalid destination;
- destination not adjacent;
- Boss encounter already open.

A rejection returns the unchanged pre-request snapshot. No partial marker, HUD, minimap, encounter, roster, reward, save, or battle state may be applied.

Invalid or unsupported world plans fail before runtime composition. Existing `WorldRunStartService` generation failures retain their approved typed, interactive, and headless behavior.

Presentation application is snapshot-driven. If a required runtime presentation dependency cannot apply a valid result, the controller blocks further movement and reports an internal integration error. It does not issue another model transaction, silently retry, or relax the result.

## Testing and migration proof

### Pure model tests

Automated tests cover:

- initial and reset snapshots;
- all rejection paths with byte-equivalent unchanged snapshots;
- accepted adjacent movement;
- exactly one accepted-count increment;
- move 30 activation without pursuit;
- move 31 first pursuit step;
- every later accepted unengaged move producing one pursuit step;
- fixed neighbor-order pursuit tie-breaking;
- player-initiated Boss engagement;
- boss-initiated Boss engagement;
- ordinary encounter close without an extra boss step;
- moving Boss identity and Safe vacated start;
- camera and UI-only operations causing zero runtime mutation.

### Scene integration tests

The non-production entry proves:

- clicked highlighted neighbors request the matching coordinate;
- main-map and minimap player markers update together;
- main-map and minimap boss markers update after pursuit;
- valid-neighbor highlights refresh from the new coordinate;
- HUD countdown and active state match the runtime snapshot;
- contextual inspection shows canonical encounter and terrain;
- encounter, battle, Party, and failure surfaces block movement;
- Party access uses the existing six-slot Front/Back formation owner;
- camera remains fixed while the player is visible and recenters once when the player leaves the visible rectangle;
- one matching encounter surface opens per accepted move;
- no production main-scene authority changes.

### Migrated successor fixtures

Retained AC1, AC2, and AC3 assertions receive Generator V1 successor fixtures through the non-production entry. Frozen legacy tests remain unchanged and green. A successor fixture must pass before any retained behavior can later be retired from the legacy entry.

Stage 4 evidence records:

- RED and GREEN commands and logs;
- full frozen legacy test hashes and results;
- pure runtime and integration results;
- GodotIQ project validation, parse checks, signal-orphan checks, and runtime health;
- manual movement, encounter, Party, move-30 activation, move-31 pursuit, and engagement observations;
- proof that `Scenes/game_world.tscn`, `Scripts/Map`, and frozen tests are unchanged.

The first implementation-plan task anchors this burden to the repository by creating the three named Stage 4 test runners and `Docs/Specs/WorldMap/Evidence/RuntimeStage4/baseline/`. Every later task names its exact runner, expected RED assertion, GREEN assertion count, and evidence output. Manual observations supplement automated gates and never substitute for them.

## Acceptance criteria

Stage 4 is complete only when:

1. The pure model implements the approved accepted-move transaction atomically.
2. Move 30 activates without pursuit; move 31 and later accepted unengaged moves produce exactly one deterministic pursuit step.
3. Both player-initiated and boss-initiated engagement open exactly one Boss encounter and stop further map transactions.
4. Main-map, minimap, highlights, HUD, encounter state, and Party availability derive from one runtime snapshot.
5. Camera-only and UI-only actions cause zero runtime mutation.
6. Conditional camera recentering follows the approved visible-rectangle rule.
7. Migrated successor tests cover retained movement, encounter, battle, Party, roster, and turn semantics through the non-production entry.
8. The complete frozen legacy suite remains unchanged and green.
9. Generator V1, Save V1, Stage 3 presentation, and camera edge-centering regressions remain green.
10. Production authority remains the 25-cell `Scenes/game_world.tscn`; no cutover or legacy cleanup occurs.

## Explicit exclusions

Stage 4 does not include:

- production cutover;
- deletion or modification of the legacy world implementation;
- legacy-save conversion;
- new town services, shops, healing, quests, or recruitment rules;
- forest movement costs or encounter modifiers;
- road movement bonuses;
- mobile layout or touch controls;
- automatic camera tracking while the player remains visible;
- changes to battle, recruitment, roster, or Party rules unrelated to world integration.

## Approval record

The project lead approved option 1, the pure runtime-model architecture, and all behavior in this document on 2026-08-25.
