# AC1.3 Mouse Map Control Implementation Spec

**Project:** Two-Dimension Exploration  
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`  
**Acceptance Criterion:** AC1.3 - World-map navigation is controlled by mouse selection of adjacent hexes (no Q/W/E/A/S/D movement requirement)  
**Owner:** Project Lead  
**Prepared by:** Codex  
**Date:** 2026-07-23  
**Status:** Ready for implementation

---

## 1. Goal

Implement mouse-based world-map navigation for the existing 25-hex map so movement is performed by selecting adjacent destination hexes with the pointer.

This spec covers AC1.3 only. It does not add boss-battle triggering, Sudden Death behavior, combat systems, or encounter-generation changes.

---

## 2. Current Project Context

- AC1.1 map traversal baseline exists in `res://Scripts/Map/map_controller.gd` with adjacency validation through `request_move(destination)`.
- AC1.2 seeded encounter assignment exists in `res://Scripts/Map/hex_map_model.gd` and tile state rendering.
- Existing movement input is currently action-driven (`map_move_*`) and should be replaced or disabled for world-map traversal in this AC.
- Tile instances already retain coordinate data through `HexTileView.coordinate`, which can be used for click-to-coordinate mapping.

Decision: keep adjacency and boundary validation in `MapController.request_move()` and route mouse selection into this existing movement contract.

---

## 3. Design Decisions

### 3.1 Input Ownership

- World-map movement is mouse-controlled for AC1.3.
- Primary action: left mouse click.
- Keyboard movement input (Q/W/E/A/S/D) is not required and must not be the active movement path for AC1.3 verification.

### 3.2 Movement Rules

- Clicking a valid adjacent hex attempts exactly one move.
- Clicking a non-adjacent hex does not move the player.
- Clicking an invalid or out-of-map region does not move the player.
- Movement count increments only on accepted moves.
- Existing deterministic movement rules and adjacency checks remain authoritative in `request_move()`.

### 3.3 Visual Feedback

- Keep existing player, boss, safe/combat, and valid-neighbor states.
- Hover indication is required.
- Clicked-but-invalid destinations should leave the map state unchanged.

---

## 4. Proposed File Boundaries

### Modify

- `Scripts/Map/map_controller.gd`
  - Handle `InputEventMouseButton` for left-click map navigation.
  - Resolve click position to tile coordinate and call `request_move()`.
  - Remove or disable keyboard movement handling for world-map traversal.

- `Scripts/Map/hex_tile_view.gd` (optional)
  - Add helper methods or signals only if needed for click coordinate resolution.

- `Scenes/map_hex_tile.tscn` (optional)
  - Add collision or clickable area only if required by chosen click-detection approach.

### Tests

- `Tests/Map/test_map_controller_runtime.gd`
  - Update or extend to cover mouse navigation path.

- `Tests/Map/test_ac1_1_runtime_step_counts.gd`
  - Ensure move counting still increments only on valid moves under mouse input.

- `Tests/Map/test_navigation_help_ui.gd` (optional)
  - Update helper text if on-screen guidance references keyboard controls.

---

## 5. Implementation Plan

### Task 1: Add Mouse Click Navigation Path

- Capture left-click input in map controller.
- Determine target tile from click position.
- Call `request_move(target_coord)`.

Acceptance for this task:

- Adjacent-click moves succeed.
- Non-adjacent-click moves are rejected.
- Invalid clicks are ignored.

### Task 2: Disable Keyboard Movement Path

- Remove or gate action-driven movement from `_unhandled_input` for world-map traversal.

Acceptance for this task:

- Q/W/E/A/S/D are not required for map movement.
- Mouse path is the primary and verifiable control method.

### Task 3: Verify Runtime Behavior

Manual runtime checks:

1. Start `res://Scenes/game_world.tscn`.
2. Perform at least five valid adjacent mouse clicks and confirm movement each time.
3. Perform at least two non-adjacent clicks and confirm no movement occurs.
4. Perform at least one off-map click and confirm no movement occurs.
5. Confirm `move_count` increments only for valid adjacent moves.

---

## 6. Evidence Capture Requirements

Store evidence under:

```text
Docs/Specs/AC1/Evidence/AC1.3/YYYY-MM-DD/
```

Required files:

- `automated-test.log`
  - Runtime test output for updated map controller behavior.
- `manual-runtime-check.md`
  - Date, Godot version, run path, steps, observations, PASS/FAIL.
- `implementation-link.txt`
  - Commit, branch, remote, pull request status, and this spec path.

Governance rule: do not claim AC1.3 completion without spec reference, current test output, and implementation link.

---

## 7. Traceability Matrix

| Source | Requirement | Verification Type | Evidence Target |
|---|---|---|---|
| AC1.3 | Mouse click controls movement | Manual runtime check | Adjacent click advances one hex |
| AC1.3 | Non-adjacent click is rejected | Automated/runtime controller check | Player coordinate unchanged |
| AC1.3 | Invalid/off-map click is ignored | Manual runtime and controller check | Player coordinate unchanged |
| AC1.3 | Valid move counting preserved | Automated/runtime controller check | `move_count` increments only on accepted moves |

---

## 8. Out of Scope

- AC1.4 post-move Encounter overlay.
- AC1.5 Sudden Death boss pursuit behavior.
- Encounter generation changes from AC1.2.
- Combat scene transitions.
- Touch-specific gesture UX beyond standard click semantics.

---

## 9. Definition of Done

AC1.3 is complete when:

- World-map traversal is controllable by mouse selection of adjacent hexes.
- Valid adjacent clicks move the player exactly one hex.
- Non-adjacent and invalid clicks do not move the player.
- Keyboard movement is not the required navigation path for this AC.
- Runtime verification evidence exists in `Docs/Specs/AC1/Evidence/AC1.3/YYYY-MM-DD/`.
- Implementation reference is recorded in `implementation-link.txt`.
