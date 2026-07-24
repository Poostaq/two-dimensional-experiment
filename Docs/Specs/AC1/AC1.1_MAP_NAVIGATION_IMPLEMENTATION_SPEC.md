# AC1.1 Map Navigation Implementation Spec

**Project:** Two-Dimension Exploration  
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`  
**Acceptance Criterion:** AC1.1 - Player can move on a 25-hex (5x5) map from starting corner toward opposite-corner boss objective  
**Owner:** Project Lead
**Prepared by:** Codex with `godot-implementation` planning input
**Date:** 2026-07-21  
**Status:** Implemented; evidence recorded  

---

## 1. Goal

Implement the first playable world-map slice: a visible 25-hex map, a player marker that starts in one corner, a boss objective marker in the opposite corner, and movement that allows the player to advance only through valid adjacent hexes.

This spec covers AC1.1 only. It deliberately excludes seeded encounter assignment, automatic boss battle entry, the 15-move Sudden Death rule, combat, rewards, roster state, and meta-progression.

---

## 2. Current Project Context

- Godot project: Godot 4.7 configuration, mobile feature enabled.
- Current scene: `res://Scenes/game_world.tscn`.
- Current scene structure from GodotIQ file-context inspection: one `Node2D` root, no scripts. Live editor/runtime state was not available during planning.
- Current script count: zero.
- Current autoload count: zero.
- GodotIQ editor bridge status during planning: addon not connected, so live editor state and runtime verification were unavailable.
- Repository status note: the initial planning pass could not detect a `.git` repository. That is historical only; the current environment has a git repository at `D:\Projects\two-dimension-exploration` with `origin` configured. Implementation workers must use current `git status`, branch, and project workflow state rather than relying on the initial planning note.

Decision: implement AC1.1 as a 2D map feature in the existing `Node2D` scene. Do not introduce autoloads yet; AC1.1 state is local to the world-map scene.

---

## 3. Design Decisions

### 3.1 Hex Coordinate Model

Use bounded axial coordinates for the MVP map.

- Coordinate type: `Vector2i(q, r)`.
- Valid coordinate range: `q` from `0` to `4`, `r` from `0` to `4`.
- Total cells: `5 * 5 = 25`.
- Start coordinate: `Vector2i(0, 0)`.
- Boss objective coordinate: `Vector2i(4, 4)`.
- Board shape: 5x5 axial parallelogram.

The neighbor offsets are:

```gdscript
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]
```

Rationale: axial coordinates make adjacency rules explicit and deterministic. A bounded 5x5 parallelogram satisfies the MVP's 25-hex requirement while keeping pathfinding, movement validation, and later encounter seeding straightforward.

### 3.2 Movement Rules

- The player starts at `Vector2i(0, 0)`.
- The boss objective is visible at `Vector2i(4, 4)`.
- A move is valid only when the destination is both adjacent to the current player coordinate and inside the 5x5 bounds.
- Valid moves update `player_coord`.
- Invalid moves leave `player_coord` unchanged.
- Each accepted move increments `move_count`, but no move limit is enforced for AC1.1.
- Moving onto a destination does not open encounter presentation in AC1.1; AC1.4 owns the post-move Encounter overlay.

### 3.3 Visual Behavior

- Render all 25 hexes at scene start.
- Highlight the current player hex.
- Mark the boss objective hex.
- Visually distinguish valid neighboring destination hexes from non-valid destinations.
- Keep the visual layer simple: flat 2D hex polygons or tile scenes are sufficient for AC1.1.

### 3.4 Input Behavior

AC1.1 is input-modality agnostic. The map controller should accept movement requests from whichever input layer is active in the current milestone.

Recommended movement actions:

- `map_move_e`
- `map_move_ne`
- `map_move_nw`
- `map_move_w`
- `map_move_sw`
- `map_move_se`

Each input action maps to one axial neighbor offset.

---

## 4. Proposed File Boundaries

### Create

- `Scripts/Map/hex_map_model.gd`
  - Owns map constants, valid coordinate generation, bounds checks, neighbor lookup, and adjacency checks.

- `Scripts/Map/map_controller.gd`
  - Owns scene-level map state, player coordinate, move count, movement request handling, and visual refresh calls.

- `Scripts/Map/hex_tile_view.gd`
  - Owns one visible hex tile's coordinate, display state, and selected/hover visual state if click support is added.

- `Scenes/map_hex_tile.tscn`
  - Reusable 2D tile scene with a polygon body, outline, optional label/debug coordinate text, and script `hex_tile_view.gd`.

- `Tests/Map/test_hex_map_model.gd`
  - Lightweight headless verification script for pure map logic.

### Modify

- `Scenes/game_world.tscn`
  - Attach `map_controller.gd` to the root or to a child `MapController`.
  - Add a `MapRoot` `Node2D` container for generated/instanced hex tiles.
  - Add marker nodes for player and boss objective, or let `map_controller.gd` create them at runtime.

- `project.godot`
  - Add AC1.1 input actions.
  - Set `run/main_scene` to `res://Scenes/game_world.tscn`.

---

## 5. Implementation Plan

### Task 1: Add Pure Hex Map Logic

Create `Scripts/Map/hex_map_model.gd` with a typed class that exposes:

- `get_all_coords() -> Array[Vector2i]`
- `is_valid_coord(coord: Vector2i) -> bool`
- `get_neighbors(coord: Vector2i) -> Array[Vector2i]`
- `are_adjacent(from_coord: Vector2i, to_coord: Vector2i) -> bool`
- `get_start_coord() -> Vector2i`
- `get_boss_coord() -> Vector2i`
- `find_path_exists(from_coord: Vector2i, to_coord: Vector2i) -> bool`

Acceptance for this task:

- The generated coordinate list contains exactly 25 unique coordinates.
- Start and boss coordinates are valid and different.
- A path exists from start to boss using only valid adjacent moves.
- Out-of-bounds coordinates are rejected.

### Task 2: Add Map Controller State

Create `Scripts/Map/map_controller.gd` and attach it to `Scenes/game_world.tscn`.

Controller responsibilities:

- Initialize `HexMapModel`.
- Store `player_coord`.
- Store `boss_coord`.
- Store `move_count`.
- Convert active input events into movement requests.
- Reject invalid movement without changing state.
- Emit a clear signal or call a refresh method after accepted movement.

Acceptance for this task:

- Player state begins at `Vector2i(0, 0)`.
- Boss objective state is `Vector2i(4, 4)`.
- Adjacent movement updates state.
- Non-adjacent movement and out-of-bounds movement do not update state.

### Task 3: Render the 25-Hex Map

Create `Scenes/map_hex_tile.tscn` and `Scripts/Map/hex_tile_view.gd`.

Rendering responsibilities:

- Instance one tile for each coordinate from `HexMapModel`.
- Place each tile using a single axial-to-world conversion function.
- Show all 25 cells within the camera view.
- Mark the player tile and boss objective tile distinctly.
- Mark valid neighboring moves distinctly after each player move.

Acceptance for this task:

- Runtime view shows exactly 25 hexes.
- Player marker starts on the start corner.
- Boss marker appears on the opposite corner.
- Player marker moves only to valid adjacent tiles.

### Task 4: Wire Input Actions

Modify `project.godot` to define map movement actions and make `res://Scenes/game_world.tscn` the runnable main scene.

Required application setup:

```ini
[application]
run/main_scene="res://Scenes/game_world.tscn"
```

Acceptance for this task:

- The project has an explicit `run/main_scene` entry pointing to `res://Scenes/game_world.tscn`.
- The project input map contains all six `map_move_*` actions.
- Each movement action attempts exactly one corresponding axial neighbor move.
- Invalid edge inputs do not move the player.
- Movement remains deterministic and independent of frame rate.

### Task 5: Add Verification

Create `Tests/Map/test_hex_map_model.gd` for pure logic checks and run manual runtime verification for the scene.

Automated logic checks:

- `test_map_has_25_cells`
- `test_start_and_boss_corners`
- `test_neighbors_are_bounded`
- `test_adjacent_move_updates_player_coord`
- `test_out_of_bounds_move_is_rejected`
- `test_non_adjacent_move_is_rejected`
- `test_path_to_boss_exists`

Manual runtime check:

1. Start `res://Scenes/game_world.tscn`.
2. Confirm exactly 25 visible hexes.
3. Confirm the player marker starts in one corner.
4. Confirm the boss objective marker appears in the opposite corner.
5. Move through at least five valid adjacent hexes toward the boss objective.
6. Attempt at least two invalid edge moves and confirm the player marker does not move.
7. Confirm the player can continue advancing toward the boss objective through valid adjacency.

---

## 6. Evidence Capture Requirements

Completion evidence must be stored before AC1.1 is marked complete. The evidence package belongs under:

```text
Docs/Specs/AC1/Evidence/AC1.1/YYYY-MM-DD/
```

Required files:

- `automated-test.log`
  - Command:

    ```powershell
    godot --headless --path . --script res://Tests/Map/test_hex_map_model.gd
    ```

  - Expected pass output format:

    ```text
    AC1.1 map logic tests: PASS (7/7)
    ```

  - Expected failure output format:

    ```text
    AC1.1 map logic tests: FAIL (<passed>/7)
    FAILED: <test_name> - <reason>
    ```

- `manual-runtime-check.md`
  - Must include the exact date, Godot version, scene run path, tester role/name, each manual step from Task 5, observed result for each step, and overall PASS or FAIL.

- `runtime-screenshot.png`
  - Must show the 25-hex map with the player marker at or after a valid movement step and the boss objective visible.

- `implementation-link.txt`
  - Must include one implementation reference in this format:

    ```text
    Commit: <full_commit_sha>
    Branch: <branch_name>
    Remote: <origin_url>
    Pull Request: <url or "not opened">
    Spec: Docs/Specs/AC1/AC1.1_MAP_NAVIGATION_IMPLEMENTATION_SPEC.md
    ```

Governance rule: do not claim AC1.1 completion without the spec reference, current test result log, and implementation link.

---

## 7. Traceability Matrix

| Source | Requirement | Verification Type | Evidence Target | Evidence Artifact |
|---|---|---|---|---|
| AC1.1 | Player can move on a 25-hex map | Automated logic and manual runtime | `test_map_has_25_cells`; runtime count of 25 visible tiles | `automated-test.log`; `manual-runtime-check.md`; `runtime-screenshot.png` |
| AC1.1 | Map is 5x5 | Automated logic | `test_map_has_25_cells`; coordinate bounds `0..4` for `q` and `r` | `automated-test.log` |
| AC1.1 | Player starts in a corner | Automated logic and manual runtime | `test_start_and_boss_corners`; visual player marker on `Vector2i(0, 0)` | `automated-test.log`; `manual-runtime-check.md`; `runtime-screenshot.png` |
| AC1.1 | Boss objective is opposite corner | Automated logic and manual runtime | `test_start_and_boss_corners`; visual boss marker on `Vector2i(4, 4)` | `automated-test.log`; `manual-runtime-check.md`; `runtime-screenshot.png` |
| AC1.1 | Player moves through valid adjacent hexes | Automated logic and manual runtime | `test_adjacent_move_updates_player_coord`; input-based runtime movement | `automated-test.log`; `manual-runtime-check.md` |
| AC1.1 | Player cannot move through invalid hexes | Automated logic and manual runtime | `test_out_of_bounds_move_is_rejected`; `test_non_adjacent_move_is_rejected`; invalid edge movement check | `automated-test.log`; `manual-runtime-check.md` |
| AC1.1 | Player can move toward boss objective | Automated logic and manual runtime | `test_path_to_boss_exists`; manual route toward boss | `automated-test.log`; `manual-runtime-check.md` |

Coverage status: implemented coverage with recorded automated and manual runtime evidence under `Docs/Specs/AC1/Evidence/AC1.1/2026-07-21/`.

---

## 8. Out of Scope

- Seeded Safe/Combat/Boss encounter types.
- Run ID determinism.
- Opening an Encounter overlay after entering a hex.
- Sudden Death and boss pursuit.
- Combat scene creation.
- Roster, recruitment, rewards, equipment, or meta-progression.
- Save/load persistence.
- Full mobile touch UX polish.

---

## 9. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| The MVP phrase "5x5 hex map" can imply either an offset-row rectangle or axial parallelogram. | Later systems could assume a different layout shape. | This spec explicitly selects a bounded axial 5x5 parallelogram for AC1.1. If design wants offset rows later, change the map model before AC1.2 builds seeded content. |
| AC1.1 may accidentally absorb AC1.2-AC1.5 behavior. | Scope expands before the map is proven. | Keep encounter types, mouse-input ownership, boss battle triggers, and Sudden Death out of this implementation. |
| The project has no existing script architecture. | Early file choices can set a messy precedent. | Keep map logic pure and separate from scene/controller code. Avoid autoloads until cross-scene state exists. |
| GodotIQ editor bridge was unavailable during planning. | Live scene state and unsaved editor changes were not visible. | Before implementation, call `godotiq_project_summary`, `godotiq_file_context`, and editor-aware write tools. Verify with GodotIQ once the addon is connected. |
| No test framework is present. | Automated verification could become ad hoc. | Start with a lightweight headless GDScript test script for pure map logic; introduce a formal Godot test framework only if broader coverage needs justify it. |

---

## 10. Definition of Done

AC1.1 is complete when:

- `Scenes/game_world.tscn` runs as the main scene.
- `project.godot` contains `run/main_scene="res://Scenes/game_world.tscn"`.
- `project.godot` contains all six `map_move_*` input actions.
- The map displays exactly 25 hexes.
- The player marker starts at `Vector2i(0, 0)`.
- The boss objective marker displays at `Vector2i(4, 4)`.
- Directional input moves the player only to adjacent valid hexes.
- Invalid edge and non-adjacent movement attempts are rejected without changing player state.
- A valid adjacent route from start to boss objective exists.
- Automated map-logic checks pass.
- Manual runtime verification is recorded with the exact date, command or editor run path, and observed result.
- Evidence files exist under `Docs/Specs/AC1/Evidence/AC1.1/YYYY-MM-DD/`.
- `implementation-link.txt` identifies the commit, branch, remote, pull request status, and this spec path.
