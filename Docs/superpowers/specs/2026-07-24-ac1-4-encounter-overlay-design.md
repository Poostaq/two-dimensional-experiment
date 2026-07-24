# AC1.4 Encounter Overlay Design

**Project:** Two-Dimension Exploration  
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`  
**Acceptance Criterion:** AC1.4 — Entering any map hex automatically opens an Encounter overlay for that hex's seeded encounter type
**Owner:** Project Lead  
**Prepared by:** Codex  
**Date:** 2026-07-24  
**Status:** Approved for planning

---

## Goal

Open an `Encounter` overlay immediately after every accepted move onto a map hex. The overlay provides a reusable transition boundary for future Safe, Combat, and Boss encounter implementations.

## Scope

This increment adds encounter presentation and lifecycle behavior only:

- Every accepted move onto a Safe, Combat, or Boss hex opens the overlay.
- The overlay identifies the entered hex's encounter type.
- The overlay blocks map interaction while visible.
- A clearly labeled debug Close button dismisses the overlay.
- Dismissal leaves the player on the entered hex and restores map navigation.

The initial starting hex does not open an encounter during map initialization. Invalid, off-map, and non-adjacent selections do not open an encounter.

## Architecture

### Encounter Overlay

A dedicated encounter overlay scene owns temporary encounter presentation. It is instantiated above the existing map rather than replacing the world scene, so the current run, generated layout, player coordinate, and move count remain intact.

The overlay accepts the entered coordinate and encounter type as setup data. Its root UI consumes pointer input across the viewport, preventing clicks from reaching the map. It emits a close request when the debug Close button is pressed.

### Map-to-Encounter Boundary

`MapController.request_move()` remains the authority for bounds, adjacency, coordinate updates, and move counting. After a move has been accepted and the map state updated, the controller reads the destination's existing encounter type and opens the overlay.

Encounter presentation must not be opened from rejected movement paths. Opening occurs once per accepted entry event; dismissing the overlay does not reopen it. Re-entering a hex through a later accepted move opens a new overlay.

The controller stores the active overlay in `_active_encounter_overlay`. A valid reference means navigation is unavailable. `request_move()` checks this guard before bounds or adjacency validation and before any coordinate or counter mutation.

The controller assigns the active reference before the overlay becomes interactive. When the overlay requests closure, the controller disconnects and removes it, clears the reference, and permits navigation again. A duplicate close request or a close request with no active overlay is a harmless no-op.

## Data Flow

1. The player selects an adjacent destination.
2. `MapController.request_move(destination)` validates the request.
3. An accepted move updates `player_coord`, increments `move_count`, and refreshes map visuals.
4. The controller obtains the destination's encounter type from the existing deterministic encounter layout.
5. The controller instantiates the Encounter overlay with the destination coordinate and type.
6. The overlay blocks map input until its debug Close button is pressed.
7. The controller dismisses the overlay without changing the player coordinate, move count, run ID, or encounter layout.

## Presentation

The temporary overlay contains:

- A full-viewport input-blocking background.
- An `Encounter` title.
- Encounter-type text for `Safe`, `Combat`, or `Boss`.
- A button labeled `Close (Debug)`.

No battle board, enemy roster, rewards, encounter choices, animation, or permanent visual styling is required in this increment.

## Error and Edge-Case Behavior

- If movement is rejected, no overlay is created.
- If an overlay is already active, further movement requests are rejected without changing map state.
- The encounter type comes from the existing map layout; the overlay does not generate or mutate encounters.
- Closing an overlay when none is active is a harmless no-op.
- Closing preserves the entered coordinate and the move count produced by that entry.
- Initial map setup does not count as entering a hex and does not open the overlay.

## Verification

Automated checks in `Tests/Map/test_ac1_4_encounter_overlay.gd` cover:

- accepted entry onto a Safe hex opens one overlay with `Safe`;
- accepted entry onto a Combat hex opens one overlay with `Combat`;
- accepted entry onto the Boss hex opens one overlay with `Boss`;
- initial map setup opens no overlay;
- rejected movement opens no overlay;
- map movement is blocked while the overlay is active;
- debug Close removes the overlay without changing coordinate or move count;
- navigation resumes after Close;
- dismissing an overlay does not reopen it;
- later re-entry through a valid move opens a new overlay.

Runtime verification uses real mouse input to enter each encounter type, confirms immediate presentation without a confirmation step, confirms background map clicks are blocked, and confirms Close returns control at the same coordinate.

### Traceability Matrix

| Requirement | Automated verification | Manual verification | Evidence |
|---|---|---|---|
| Initial setup opens no overlay | `test_initial_state_has_no_overlay` | Launch the world and inspect the initial map | `automated-test.log`, `manual-runtime-check.md` |
| Safe, Combat, and Boss entries open the matching overlay | `test_each_encounter_type_opens_matching_overlay` | Enter one fixture hex of each type | `automated-test.log`, `manual-runtime-check.md` |
| Rejected movement opens no overlay | `test_rejected_move_opens_no_overlay` | Click a non-adjacent hex | `automated-test.log`, `manual-runtime-check.md` |
| Active overlay blocks movement and duplicate opening | `test_active_overlay_blocks_map_state_changes` | Click the map behind the overlay | `automated-test.log`, `manual-runtime-check.md` |
| Debug Close preserves map state and restores navigation | `test_debug_close_preserves_state_and_restores_navigation` | Close, inspect coordinate/count, then enter another adjacent hex | `automated-test.log`, `manual-runtime-check.md` |
| Re-entry opens once per accepted move | `test_reentry_opens_once_per_accepted_move` | Close and later return to a previously visited hex | `automated-test.log`, `manual-runtime-check.md` |

AC1.4 completion evidence must be stored under:

```text
Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/automated-test.log
Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/manual-runtime-check.md
Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/implementation-link.txt
```

AC1.4 remains unchecked until all three current artifacts exist.

## Out of Scope

- Resolving Safe, Combat, or Boss encounters.
- Combat-system behavior from AC2.x.
- Rewards, recruitment, health, party management, or meta-progression.
- AC1.5 Sudden Death boss movement.
- Persisting an open overlay across save/load.
- Preventing or changing later encounters when a previously visited hex is re-entered.

## Definition of Done

- Every accepted post-initialization hex entry opens the Encounter overlay exactly once.
- The overlay reports the existing encounter type.
- Map navigation cannot change state while the overlay is visible.
- `Close (Debug)` returns to the map on the entered hex with navigation restored.
- Safe, Combat, and Boss entry behavior is covered by passing automated tests and current manual runtime evidence before AC1.4 is marked complete.
- No encounter-resolution or combat mechanics are introduced.
