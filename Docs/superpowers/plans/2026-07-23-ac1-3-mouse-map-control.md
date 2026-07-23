# AC1.3 Mouse Map Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make adjacent world-map hexes selectable with the left mouse button while disabling Q/W/E/A/S/D traversal.

**Architecture:** Each `HexTileView` performs polygon-accurate pointer hit testing in its own canvas transform, emits coordinate-bearing selection and hover signals, and renders hover by widening its outline without replacing the current encounter/player state. `MapController` connects tile selection to its existing authoritative `request_move()` method, so adjacency, bounds, and move counting remain unchanged.

**Tech Stack:** Godot 4.7, typed GDScript, existing headless `SceneTree` tests, GodotIQ validation/runtime tools.

---

## File Structure

- Modify: `Scripts/Map/hex_tile_view.gd`
  - Add pointer hit testing, `tile_selected`, `hover_changed`, and independent hover rendering.
- Modify: `Scripts/Map/map_controller.gd`
  - Connect tile selection to `request_move()` and remove action-driven keyboard traversal.
- Create: `Tests/Map/test_ac1_3_mouse_navigation.gd`
  - Verify adjacent, non-adjacent, invalid-button, keyboard-disabled, and hover behavior through real input events.
- Create: `Docs/Specs/AC1/Evidence/AC1.3/2026-07-23/automated-test.log`
  - Capture the complete map test suite.
- Create: `Docs/Specs/AC1/Evidence/AC1.3/2026-07-23/manual-runtime-check.md`
  - Record GodotIQ runtime input/state observations.
- Create: `Docs/Specs/AC1/Evidence/AC1.3/2026-07-23/implementation-link.txt`
  - Record branch, commit, source spec, and implementation plan.
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Mark AC1.3 complete only after evidence exists.

### Task 1: Specify Mouse Navigation Behavior

- [ ] Add `test_ac1_3_mouse_navigation.gd` with five independent checks:
  - a left click at an adjacent tile center changes `player_coord` and increments `move_count` once;
  - a left click at a non-adjacent tile center changes neither value;
  - a right click at an adjacent tile changes neither value;
  - a `map_move_se` action event changes neither value;
  - mouse motion into and out of a tile emits hover changes and changes/restores outline width.
- [ ] Run the new test and confirm it fails because tile selection/hover signals do not exist and keyboard movement remains active.

### Task 2: Add Tile Pointer Input

- [ ] Add typed `tile_selected(coordinate: Vector2i)` and `hover_changed(coordinate: Vector2i, is_hovered: bool)` signals.
- [ ] Add `_unhandled_input()` handling for mouse motion and pressed left mouse buttons.
- [ ] Convert viewport coordinates with `get_global_transform_with_canvas().affine_inverse()` and test against `$Fill.polygon` using `Geometry2D.is_point_in_polygon()`.
- [ ] Maintain `_is_hovered`, emit only on transitions, and render hover with a wider outline so existing display-state colors remain authoritative.
- [ ] Validate `hex_tile_view.gd`, check parser errors, and rerun the new test to confirm only controller routing/keyboard assertions remain red.

### Task 3: Route Selection and Disable Keyboard Traversal

- [ ] Remove `ACTION_OFFSETS` and action iteration from `MapController._unhandled_input()`.
- [ ] Connect every instantiated tile's `tile_selected` signal to `_on_tile_selected(coordinate)`.
- [ ] Route `_on_tile_selected()` directly to `request_move(coordinate)` and mark the viewport event handled in the tile after emission.
- [ ] Validate `map_controller.gd`, check parser errors, and rerun the AC1.3 test until all five checks pass.
- [ ] Run every `Tests/Map/*.gd` script and confirm all existing AC1.1/AC1.2/navigation-help tests remain green.

### Task 4: Runtime Verification and Evidence

- [ ] Run the main scene with GodotIQ, verify project startup, and inspect the debug console.
- [ ] Use real pointer clicks at tile centers while inspecting `player_coord` and `move_count`: valid adjacent click increments once; non-adjacent and off-map clicks do not.
- [ ] Capture the complete automated suite output in `automated-test.log`.
- [ ] Write the runtime observations and implementation reference.
- [ ] Mark AC1.3 checked only after all evidence files exist.
- [ ] Run project-wide validation, parser checks, orphan-signal checks, the complete map suite, and final runtime verification.
- [ ] Commit only AC1.3 implementation, tests, plan, evidence, and the AC1.3 completion checkbox.

## Self-Review

- Spec coverage: left-click traversal, adjacency rejection, invalid/off-map rejection, move-count preservation, keyboard-path removal, hover feedback, evidence, and traceability are covered.
- Placeholder scan: no TBD/TODO placeholders remain; runtime-derived commit identifiers are written only after the implementation commit exists.
- Type consistency: both signals carry `Vector2i`; controller selection continues to use `request_move(Vector2i) -> bool`.
- Scope: no boss battle, Sudden Death, encounter generation, combat, touch gesture, or unrelated scene-layout work is included.
