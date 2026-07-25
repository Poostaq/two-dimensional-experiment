# AC1.4 Encounter Overlay Implementation Spec

**Project:** Two-Dimension Exploration
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
**Acceptance Criterion:** AC1.4 — Entering any map hex automatically opens an Encounter overlay for that hex's seeded encounter type
**Owner:** Project Lead
**Prepared by:** Codex
**Date:** 2026-07-24
**Status:** Ready for implementation

---

## 1. Goal

Open one input-blocking Encounter overlay immediately after every accepted post-initialization map move. Display the destination's deterministic Safe, Combat, or Boss type and provide a temporary `Close (Debug)` control that returns to the unchanged map state.

## 2. Current Project Context

- AC1.1 supplies bounded adjacent movement and move counting in `res://Scripts/Map/map_controller.gd`.
- AC1.2 supplies deterministic Safe, Combat, and Boss encounter types through `MapController.get_encounter_type_at()`.
- AC1.3 supplies mouse selection through `HexTileView.tile_selected`.
- `res://Scenes/game_world.tscn` is the single world scene. Its UI ownership point for AC1.4 is an existing `UI` `CanvasLayer`; the Encounter overlay must be attached under that layer so draw order and input ownership remain unambiguous.
- `MapController.request_move()` currently accepts valid adjacent moves without an active-overlay guard.

## 3. Behavioral Contract

### 3.1 Entry

- Initial map setup is not an entry and opens no overlay.
- Every accepted move opens exactly one overlay after coordinate, count, and visuals update.
- The overlay receives the entered `Vector2i` coordinate and the existing encounter type.
- The overlay is parented under `game_world.tscn`'s `UI` `CanvasLayer`, not directly under map tiles or model nodes.
- Invalid, off-map, and non-adjacent selections open no overlay.

### 3.2 Active State

- `_active_encounter_overlay == null` means navigation is available.
- A valid active reference means `request_move()` returns `false` before validation or state mutation.
- The active reference is assigned before the overlay can receive input.
- The overlay's full-viewport Control consumes pointer input so tile selection cannot leak through.

### 3.3 Debug Closure

- `Close (Debug)` emits `close_requested`.
- The controller removes the active overlay, clears its reference, and restores navigation.
- Closure does not alter coordinate, move count, run ID, or encounter layout.
- Duplicate or stale close requests are harmless.
- Closing does not reopen the overlay; a later accepted move does.

## 4. File Boundaries

### Create

- `Scenes/encounter_overlay.tscn`
  - Full-viewport input blocker, encounter panel, title, type label, and debug Close button.
- `Scripts/Encounter/encounter_overlay.gd`
  - Typed setup data, label refresh, and `close_requested` signal.
- `Tests/Map/test_ac1_4_encounter_overlay.gd`
  - Entry, type, blocking, closure, and re-entry integration checks.
- `Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/automated-test.log`
- `Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/manual-runtime-check.md`
- `Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/implementation-link.txt`

### Modify

- `Scripts/Map/map_controller.gd`
  - Load the overlay scene, guard movement, attach it under the `UI` `CanvasLayer`, open after accepted movement, and handle closure.
- `Tests/Map/test_ac1_1_runtime_step_counts.gd`
  - Close each expected overlay before the next valid test move.
- `Tests/Map/test_map_controller_runtime.gd`
  - Preserve controller regression intent while accounting for the active encounter gate.
- `Tests/Map/test_ac1_3_mouse_navigation.gd`
  - Close the overlay after the accepted click where later checks require navigation.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Mark AC1.4 complete only after the evidence package exists.

## 5. Verification Requirements

Automated verification must prove:

- initialization has no active overlay;
- accepted Safe, Combat, and Boss entries each open one overlay with the matching coordinate and type;
- rejected movement does not open an overlay;
- movement is rejected without mutation while an overlay is active;
- Close preserves coordinate, count, run ID, and encounter layout;
- navigation resumes after Close;
- Close does not reopen the overlay;
- a later accepted move, including re-entry, opens exactly one new overlay;
- all AC1.1–AC1.3 map tests remain green after their fixture lifecycle is updated.

Safe and Combat automated fixtures must be selected deterministically through the existing encounter lookup contract. Tests may iterate `set_run_id()` over a bounded list of fixture IDs, inspect valid adjacent destinations with `get_encounter_type_at()`, and choose the first reachable Safe and Combat destinations for the current run. Boss verification may follow the existing deterministic boss path, closing each expected overlay between accepted moves. Fixture selection must not depend on hard-coded visual positions or random timing.

Manual runtime verification must use real mouse input to:

1. Confirm no overlay appears at startup.
2. Enter fixture Safe, Combat, and Boss hexes and confirm immediate matching labels.
3. Attempt a map click while the overlay is open and confirm no movement.
4. Press `Close (Debug)` and confirm coordinate/count remain unchanged.
5. Enter another adjacent hex and confirm a new overlay opens once.

## 6. Traceability Matrix

| Source | Requirement | Verification target | Evidence |
|---|---|---|---|
| AC1.4 | No startup overlay | `test_initial_state_has_no_overlay` | Automated log; manual startup observation |
| AC1.4 | Every accepted type opens matching overlay | `test_each_encounter_type_opens_matching_overlay` | Automated log; Safe/Combat/Boss runtime table |
| AC1.4 | Rejected selection opens none | `test_rejected_move_opens_no_overlay` | Automated log; non-adjacent runtime check |
| AC1.4 | Overlay blocks map mutation | `test_active_overlay_blocks_map_state_changes` | Automated log; background-click runtime check |
| AC1.4 | Debug Close preserves state and resumes navigation | `test_debug_close_preserves_state_and_restores_navigation` | Automated log; close/resume runtime check |
| AC1.4 | One overlay per accepted entry | `test_reentry_opens_once_per_accepted_move` | Automated log; re-entry runtime check |
| AC1.1–AC1.3 | Existing map behavior remains valid | Complete `Tests/Map/*.gd` suite | Automated log |

## 7. Evidence Governance

AC1.4 remains unchecked until these current artifacts exist:

```text
Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/automated-test.log
Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/manual-runtime-check.md
Docs/Specs/AC1/Evidence/AC1.4/YYYY-MM-DD/implementation-link.txt
```

The implementation link records the branch, commit, source spec, implementation spec, and plan. Completion requires current test output and manual runtime observations.

## 8. Out of Scope

- Encounter resolution and content choices.
- Combat boards, enemies, skills, damage, victory, or defeat.
- Rewards, recruitment, persistence, and meta-progression.
- AC1.5 Sudden Death behavior.
- Save/load restoration of an open overlay.
- Consuming or suppressing encounters on revisited hexes.

## 9. Definition of Done

- Every accepted post-initialization entry opens exactly one matching Encounter overlay.
- The overlay prevents map state changes until closed.
- `Close (Debug)` preserves the entered state and restores navigation.
- Automated and manual verification cover Safe, Combat, Boss, rejection, blocking, closure, and re-entry.
- Regression tests pass.
- Governance evidence exists before AC1.4 is checked.
