# AC1.5 Sudden Death Boss Pursuit Design

**Project:** Two-Dimension Exploration
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
**Acceptance Criterion:** AC1.5 — If the boss is not engaged within 15 player moves, the boss becomes empowered and moves immediately after each player move until battle is triggered
**Owner:** Project Lead
**Prepared by:** Codex
**Date:** 2026-07-25
**Status:** Approved for planning

---

## Goal

Activate Sudden Death after the player completes 15 accepted moves without engaging the boss. Beginning with the 16th accepted move, move the boss one adjacent hex toward the player after every player move until either side reaches the other and the Boss encounter opens.

## Scope

This increment adds deterministic boss pursuit and its encounter boundary:

- The first 14 accepted player moves leave Sudden Death inactive.
- The 15th accepted player move activates Sudden Death but does not move the boss.
- Starting with the 16th accepted player move, the boss takes exactly one adjacent pursuit step after each accepted player move.
- The boss follows a shortest path toward the player's new coordinate.
- Equal-length path choices use the existing `HexMapModel.NEIGHBOR_OFFSETS` order as a fixed tie-breaker.
- Entering the boss's current coordinate or being reached by the boss opens the existing Encounter overlay as a Boss encounter.
- Boss pursuit stops once the Boss encounter is active.
- Resetting the run restores the initial boss position and clears Sudden Death state.

Combat resolution, boss statistics, rewards, and post-battle behavior remain outside AC1.5.

## Architecture

### Hex Map Model

`HexMapModel` owns a pure deterministic query that selects the next adjacent coordinate on a shortest path from the boss to the player. The query does not mutate map or controller state.

The model evaluates valid neighbors in `NEIGHBOR_OFFSETS` order. It selects a neighbor with the smallest remaining hex distance to the target; the first neighbor with that distance wins. This makes equal-distance choices stable without RNG and preserves replayability for identical player routes.

### Map Controller

`MapController` remains the authority for player movement, move counting, boss position, encounter lifecycle, and marker refresh. It owns:

- a Sudden Death activation flag;
- the 15-move activation threshold;
- ordering player movement before boss movement;
- updating `boss_coord` and the boss marker;
- detecting engagement before and after pursuit;
- opening exactly one Encounter overlay for the resolved encounter.

No separate boss manager is introduced. The behavior is small enough to remain part of the map turn coordinator, while path selection stays isolated and directly testable in the model.

### Runtime Encounter Identity

The boss's current coordinate, not the original seeded corner, determines where a Boss encounter occurs at runtime. After the boss leaves the original corner, that vacated coordinate resolves as Safe because the seeded layout contains no hidden encounter beneath its forced Boss entry.

The seeded encounter layout remains deterministic and unchanged as generation data. Runtime encounter resolution applies these rules in order:

1. The current boss coordinate resolves as Boss.
2. The original boss coordinate resolves as Safe after the boss has moved away.
3. All other coordinates use their seeded Safe or Combat type.

This prevents the stationary seed marker and the moving runtime boss from creating two simultaneous Boss encounters.

## Turn and Encounter Flow

For each accepted player movement request:

1. Validate that no Encounter overlay is active and that the destination is valid and adjacent.
2. Move the player, increment `move_count`, and refresh the player/map visuals.
3. If the player's destination equals `boss_coord`, open one Boss overlay and end the turn without moving the boss.
4. If `move_count == 15`, activate Sudden Death without moving the boss.
5. If Sudden Death is active and `move_count > 15`, move the boss one deterministic shortest-path step toward the player's new coordinate and refresh the boss marker.
6. If the boss now equals the player coordinate, open one Boss overlay and end the turn.
7. Otherwise, open the normal Safe or Combat overlay for the player's entered coordinate.

Rejected, off-map, non-adjacent, and overlay-blocked requests do not change player position, `move_count`, Sudden Death state, or boss position.

The existing overlay gate serializes turns: the next player move and boss pursuit step cannot occur until the current Safe or Combat overlay is closed.

## State Reset

Initial setup and `set_run_id()` establish a fresh map state:

- `player_coord` returns to the model's start coordinate;
- `boss_coord` returns to the model's opposite-corner boss coordinate;
- `move_count` returns to zero;
- Sudden Death becomes inactive;
- the deterministic seeded encounter layout is regenerated for the selected Run ID;
- the player, boss, and tile visuals refresh to match the reset state.

An active Encounter overlay must follow the existing lifecycle rules during reset; reset behavior must not leave a stale overlay reference or allow an overlay from the previous run to affect the new run.

## Error and Edge-Case Behavior

- Engaging the boss on or before move 15 opens the Boss overlay and never activates pursuit.
- The 15th move may engage the boss directly; in that case engagement takes precedence over activation.
- The boss never takes more than one step for one accepted player move.
- Closing an ordinary Encounter overlay does not move the boss.
- Invalid or blocked movement never advances the threshold.
- A path query where boss and player coordinates are equal returns the current coordinate and causes no additional movement.
- A path query with an invalid coordinate returns the boss's current coordinate; the controller does not partially mutate pursuit state.
- No RNG is used for boss pursuit.
- The boss cannot move beyond the 5x5 map because only valid model neighbors are considered.

## Verification

### Automated Model Checks

Focused `HexMapModel` tests verify:

- the selected pursuit coordinate is valid and adjacent to the boss;
- the selected coordinate reduces shortest hex distance by one;
- equal-distance alternatives use `NEIGHBOR_OFFSETS` ordering;
- repeated identical inputs return identical results;
- equal and invalid endpoints safely return the source coordinate.

### Automated Controller Checks

AC1.5 integration tests verify:

- moves 1–14 do not activate Sudden Death or move the boss;
- move 15 activates Sudden Death without moving the boss;
- move 16 produces the first boss pursuit step;
- every later accepted move produces exactly one boss step;
- blocked and rejected movement does not activate or move the boss;
- the player entering `boss_coord` opens one Boss overlay before pursuit;
- the boss reaching `player_coord` opens one Boss overlay after pursuit;
- the boss's current coordinate resolves as Boss;
- the vacated original boss coordinate resolves as Safe;
- resetting/changing the Run ID restores the boss and clears Sudden Death;
- all existing AC1.1–AC1.4 map and overlay tests remain green.

### Manual Runtime Check

Using real mouse navigation:

1. Avoid the boss for 14 accepted moves, closing each ordinary Encounter overlay, and confirm the boss remains at the opposite corner.
2. Complete move 15 and confirm Sudden Death activates while the boss remains stationary.
3. Complete move 16 and confirm the boss moves immediately afterward by one adjacent step toward the player.
4. Continue moving and confirm one boss step follows each accepted player move.
5. Confirm the boss follows the same route when the same player route is repeated.
6. Allow the boss to reach the player and confirm one Boss Encounter overlay opens.
7. Start a new Run ID and confirm the boss returns to the opposite corner with pursuit inactive.

### Traceability Matrix

| Requirement | Automated verification | Manual verification | Evidence |
|---|---|---|---|
| Activate after 15 unengaged player moves | Threshold boundary tests for moves 14, 15, and 16 | Observe activation on move 15 | `automated-test.log`, `manual-runtime-check.md` |
| Move immediately after each subsequent player move | One-step-per-accepted-move controller test | Observe pursuit after moves 16+ | `automated-test.log`, `manual-runtime-check.md` |
| Deterministic shortest-path pursuit | Model distance and tie-break tests | Repeat the same player route | `automated-test.log`, `manual-runtime-check.md` |
| Pursue until battle is triggered | Player-to-boss and boss-to-player engagement tests | Allow either engagement direction | `automated-test.log`, `manual-runtime-check.md` |
| Preserve existing map behavior | Complete `Tests/Map/*.gd` suite | Exercise overlays and rejected clicks | `automated-test.log`, `manual-runtime-check.md` |
| Reset pursuit with a new run | Controller reset test | Change Run ID and inspect state | `automated-test.log`, `manual-runtime-check.md` |

AC1.5 completion evidence must be stored under:

```text
Docs/Specs/AC1/Evidence/AC1.5/YYYY-MM-DD/automated-test.log
Docs/Specs/AC1/Evidence/AC1.5/YYYY-MM-DD/manual-runtime-check.md
Docs/Specs/AC1/Evidence/AC1.5/YYYY-MM-DD/implementation-link.txt
```

AC1.5 remains unchecked until all three current artifacts exist.

## Out of Scope

- Combat-board transition or battle resolution.
- Empowerment stat changes, boss health, damage, skills, or AI inside combat.
- Animations, audio, camera effects, or final Sudden Death presentation.
- More than one boss step per accepted player move.
- RNG-based pursuit or difficulty-specific pursuit rules.
- Save/load restoration of an in-progress pursuit.
- Post-boss-battle map behavior.

## Definition of Done

- Sudden Death activates exactly on accepted player move 15 when the boss has not been engaged.
- The boss remains stationary on move 15 and moves once after each accepted move beginning with move 16.
- Pursuit follows a deterministic shortest path with fixed tie-breaking.
- Either side reaching the other opens exactly one Boss Encounter overlay and stops pursuit.
- The moving boss is the only runtime Boss encounter; its vacated original corner is Safe.
- Resetting the run restores the initial boss position and inactive pursuit state.
- Automated regression tests and current manual evidence exist before AC1.5 is marked complete.
