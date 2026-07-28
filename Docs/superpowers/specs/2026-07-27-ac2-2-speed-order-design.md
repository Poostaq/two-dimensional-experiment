# AC2.2 Speed Order Design

| Field | Value |
|---|---|
| Project | Two-Dimension Exploration |
| Source Spec | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` |
| Acceptance Criterion | AC2.2 — Faster units act earlier according to speed order |
| Owner | Project Lead |
| Prepared by | Codex |
| Date | 2026-07-27 |
| Status | Review revisions incorporated; pending written-spec approval |

---

## 1. Goal

Extend the AC2.1 battle arena with deterministic unit turn ordering. Higher-speed units act first; equal-speed units use a stable formation order. The arena visibly identifies the current unit and advances one turn at a time through a temporary debug control until later acceptance criteria add real actions.

## 2. Scope

AC2.2 includes:

- A typed battle-unit state containing identity, display name, side, slot index, and speed.
- A pure turn-queue calculator that sorts active units by descending speed.
- Stable equal-speed ordering based on formation and side.
- Twelve deterministic debug units, one in each existing player and enemy slot.
- Visible unit names and speed values.
- A visible current-unit indicator, current-slot highlight, and round number.
- An `Advance Turn (Debug)` action.
- Queue rebuilding and round increment after the final unit advances.
- Automated ordering and arena-integration tests plus manual runtime verification.

AC2.2 excludes:

- Player action selection, skills, targeting, swapping, and action resolution.
- Damage, healing, HP, defeat, unit removal, victory, and loss.
- Roster, character-definition, enemy-composition, and save-data integration.
- Runtime speed changes, status effects, extra actions, and initiative randomness.
- Production turn controls, final combat presentation, animation, and audio.

## 3. Current Repository Baseline

AC2.2 starts from the completed AC2.1 implementation:

- `res://Scripts/Battle/battle_arena.gd` owns arena context, the two six-slot queries, and the existing debug-exit signal.
- `res://Scenes/battle_arena.tscn` contains the twelve scene-authored slots and `Exit Battle (Debug)`, but no combatant labels, round label, current-unit label, turn highlight, or advance-turn control.
- `res://Tests/Map/test_ac2_1_battle_arena.gd` verifies the map-to-battle transition and arena structure.
- `res://Scripts/Battle/battle_unit_state.gd`, `res://Scripts/Battle/battle_turn_queue.gd`, `res://Tests/Battle/test_ac2_2_speed_order.gd`, and the AC2.2 evidence hierarchy do not exist yet.

Those absences are planned implementation work, not prerequisites or current completion evidence. AC2.2 is not implemented and must remain unchecked until every completion gate in Section 12 passes.

## 4. Implementation Checklist

| Order | Current target | Planned change | Completion signal |
|---|---|---|---|
| 1 | `Scripts/Battle/` | Add typed `BattleUnitState` | Unit identity, side, semantic slot, and speed can be constructed independently of scene nodes. |
| 2 | `Scripts/Battle/` | Add pure `BattleTurnQueue` | Valid units sort by the total deterministic key; invalid collections return an empty queue with diagnostics. |
| 3 | `Scripts/Battle/battle_arena.gd` | Add debug fixtures, queue ownership, current-unit access, advancement, wrap, and UI synchronization | Arena state advances exactly once per request and exposes the current unit. |
| 4 | `Scenes/battle_arena.tscn` | Add unit/speed labels, round/current-unit display, acting-slot highlight support, and `Advance Turn (Debug)` | Runtime UI makes the entire order observable. |
| 5 | `Tests/Battle/` | Add the focused 12-case AC2.2 contract | Focused runner prints the exact PASS signature and exits `0`. |
| 6 | Existing tests and runtime | Run regression, GodotIQ, pointer-input, and manual checks | AC2.1 structure/transition/debug exit still pass and AC2.2 runtime behavior matches this design. |
| 7 | `Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/` | Add current automated, manual, and implementation-link artifacts | All required evidence exists and records passing results before the source criterion is checked. |

## 5. Formation and Tie-Break Contract

Each side has a front column nearest its opponent and a back column farther from its opponent. Slot indices encode formation priority independently of screen direction:

```text
|3|0|     |0|3|
|4|1|     |1|4|
|5|2|     |2|5|
  Player   Enemy
```

- Slots `0`, `1`, and `2` are the front column, ordered top to bottom.
- Slots `3`, `4`, and `5` are the back column, ordered top to bottom.
- Player and enemy scenes may mirror visually, but both use the same semantic slot indices.

The total queue key is:

```text
(-speed, side_priority, slot_index)
```

where player `side_priority` is `0` and enemy `side_priority` is `1`. Therefore, units with equal speed act in this exact order:

```text
Player 0, 1, 2, 3, 4, 5, Enemy 0, 1, 2, 3, 4, 5
```

The ordering is deterministic and contains no random tie-break.

## 6. Authority and Dependencies

Implementation and review use this authority chain:

1. `.agents/policies/project-governance.md` defines the Concept → Design → Implementation → QA gate.
2. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` defines speed range `1–10`, descending speed order, one active skill per turn, and AC2.2's manual verification requirement.
3. This document defines AC2.2 behavior, interfaces, tie-breaking, scope, and verification.
4. The AC2.2 implementation plan defines implementation sequence after it exists and passes review.
5. `Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/` is the completion authority.

AC2.2 extends AC2.1's `BattleArena`, twelve stable scene-authored slots, Combat/Boss entry flow, navigation blocking, and debug exit. Existing map and AC2.1 tests remain regression authority.

## 7. Architecture

Combat rules remain separate from UI presentation:

- `BattleUnitState` is a focused typed state object for the minimum unit data AC2.2 needs.
- `BattleTurnQueue` is a pure ordering service. It validates units and returns a new ordered array without mutating its input.
- `BattleArena` owns the active debug battle state, current queue index, round number, and UI synchronization.

This boundary lets AC2.3 extend unit state with HP and active participation without moving sorting rules into scene nodes. It also lets future roster integration replace debug fixtures while preserving the queue interface.

## 8. Components and Interfaces

### 8.1 Battle Unit State

`Scripts/Battle/battle_unit_state.gd` defines `class_name BattleUnitState` and:

```gdscript
enum Side {
	PLAYER,
	ENEMY,
}

var unit_id: StringName
var display_name: String
var side: Side
var slot_index: int
var speed: int

func _init(
	id: StringName,
	name: String,
	unit_side: Side,
	unit_slot_index: int,
	unit_speed: int
) -> void
```

The unit model has no scene-node reference. `unit_id` is stable queue/test identity; `display_name` is presentation only.

### 8.2 Turn Queue

`Scripts/Battle/battle_turn_queue.gd` defines `class_name BattleTurnQueue` and:

```gdscript
const MIN_SPEED := 1
const MAX_SPEED := 10
const SIDE_SLOT_COUNT := 6

static func build(units: Array[BattleUnitState]) -> Array[BattleUnitState]
```

`build()`:

1. Validates every entry.
2. Rejects speeds outside `1–10`.
3. Rejects slot indices outside `0–5`.
4. Rejects duplicate `(side, slot_index)` occupancy.
5. Copies the input collection.
6. Sorts by descending speed, then player before enemy, then ascending semantic slot index.
7. Returns the sorted copy.

Invalid input is a programmer/configuration error. The method reports a clear error and returns an empty typed array so the arena can enter a safe no-active-unit state.

### 8.3 Battle Arena

`BattleArena` gains:

```gdscript
var round_number: int = 1

func get_current_unit() -> BattleUnitState
func get_turn_queue() -> Array[BattleUnitState]
func configure_units(units: Array[BattleUnitState]) -> void
func advance_turn() -> void
```

On initialization, the arena creates twelve explicit deterministic debug fixtures and passes them through `configure_units()`. They occupy every player and enemy slot, use speeds within `1–10`, and include ties across front/back and both sides. The exact fixture table is part of the implementation plan and automated expected order.

`configure_units()` replaces the arena-owned unit collection with a typed copy, rebuilds the queue, resets the queue index, and synchronizes the UI. It is the future roster/enemy-composition integration seam and lets focused tests exercise empty and invalid collections without manipulating scene internals.

The arena builds its first queue, selects index `0`, and synchronizes all unit and turn UI. `advance_turn()` moves exactly one position. When called on the final position, it increments `round_number`, rebuilds the queue from the active unit collection, and selects the new first entry.

Queue accessors return copies where needed so external callers and tests cannot silently reorder arena-owned state.

## 9. UI and Interaction

Each occupied slot visibly shows:

- Debug unit display name.
- Speed value.
- Existing side and slot identity.

The arena adds:

- A `Round` label.
- A `Current Unit` label containing display name, side/position, and speed.
- A clear highlight on exactly the acting unit's slot.
- An `Advance Turn (Debug)` button.

Pressing the button advances exactly one unit and refreshes the labels and highlight. The existing `Exit Battle (Debug)` behavior remains unchanged.

The empty/no-active-unit UI contract is:

| Observable | Required state |
|---|---|
| `get_turn_queue()` | Empty typed array |
| `get_current_unit()` | `null` |
| Round label | Retains the current round number; it does not increment |
| Current-unit label | Exact text `No active units` |
| `Advance Turn (Debug)` | Disabled |
| Slot highlights | Zero highlighted slots |
| `advance_turn()` call | No state mutation and no error |

Focused integration tests must assert every row rather than relying on visual inspection alone.

The debug controls are temporary verification seams and are not production action-selection UX.

## 10. State and Error Handling

- Queue construction never mutates the caller's unit array.
- Rebuilding the same unchanged unit set returns the same identity order.
- Only one current slot is highlighted.
- One accepted button press advances one position; deferred signal handling prevents duplicate advancement from one input event.
- An empty unit collection is valid and produces the no-active-unit state.
- Invalid speed, side, slot, null entry, or duplicate occupancy produces an empty queue and a clear diagnostic.
- Invalid construction and an intentionally empty unit collection converge on the same testable no-active-unit UI state, while diagnostics distinguish invalid input from a valid empty battle.
- A round changes only when advancing past the final queue entry.
- Starting or exiting a battle does not mutate map/run state.
- Combat and Boss arenas use the same AC2.2 ordering contract.

## 11. Verification

### Automated

Create:

`res://Tests/Battle/test_ac2_2_speed_order.gd`

`Tests/Battle/` is an intentional new test boundary. Existing tests live under `Tests/Map/` because all completed criteria entered through map navigation and the AC2.1 focused test verifies the map-to-arena transition. AC2.2 introduces pure battle-domain models and arena-local turn behavior, so its focused test belongs beside that domain rather than extending the map test area. Cross-system transition coverage remains in `Tests/Map/test_ac2_1_battle_arena.gd`.

Run from the repository root:

```powershell
godot --headless --path . --script Tests/Battle/test_ac2_2_speed_order.gd
```

The focused test must exit `0` and print:

```text
AC2.2 speed order tests: PASS (12/12)
```

The twelve cases verify:

1. Higher speed always precedes lower speed.
2. Equal-speed player units order `0→5`.
3. Equal-speed enemy units order `0→5`.
4. Equal-speed players precede equal-speed enemies.
5. Mixed speeds and ties produce the exact expected twelve-unit order.
6. Rebuilding unchanged units produces identical identity order.
7. Invalid speed is rejected.
8. Duplicate side/slot occupancy is rejected.
9. The arena's initial current-unit display matches the queue head.
10. Each debug-button press advances exactly once.
11. The acting-slot highlight moves from the prior unit to the new current unit.
12. Advancing after the final entry wraps to the first unit and increments the round exactly once.

The test runner prints failures as `FAILED: <name> - <reason>`, omits the PASS signature when any case fails, and exits `1`.

Cases 7 and 8 must also assert the complete no-active-unit UI contract: exact label text, disabled advance button, no highlighted slots, unchanged round number, and no mutation after `advance_turn()`.

All existing map and AC2.1 tests run independently as the regression gate. GodotIQ validation, parser checks, orphan-signal checks, runtime startup, debug-console health, and real pointer-input verification are also required.

### Manual Runtime Check

1. Enter a real Combat battle.
2. Confirm all twelve slots display debug units and speed values.
3. Confirm the current-unit label and exactly one highlighted slot match the highest-speed queue head.
4. Press `Advance Turn (Debug)` through all twelve entries.
5. Confirm speeds never increase as the round progresses.
6. For every tie, confirm player front `0→2`, player back `3→5`, enemy front `0→2`, and enemy back `3→5`.
7. Confirm the thirteenth state returns to the first unit and changes Round 1 to Round 2.
8. Confirm `Exit Battle (Debug)` preserves map state.
9. Enter a Boss battle and confirm the same initialization and ordering behavior.

## 12. Completion Evidence

AC2.2 remains unchecked until every gate below is satisfied by the same implementation commit:

1. `automated-test.log` exists and records the focused AC2.2 PASS signature, every existing regression test with exit `0`, GodotIQ validation/parser/orphan-signal results, Godot version, branch, and tested commit.
2. `manual-runtime-check.md` exists and records PASS observations for Combat initialization, all twelve turns, descending speeds, every tie boundary, exactly one current highlight, round wrap, empty/no-active-unit UI behavior, debug exit with preserved map state, and Boss initialization.
3. `implementation-link.txt` exists and identifies the source spec, this design, the implementation plan, task branch, final implementation commit, changed scripts/scenes/tests, and all evidence paths.
4. The commit recorded in all three artifacts is identical to the implementation under test; stale or pre-change evidence does not qualify.
5. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` is changed from `[ ]` to `[x]` only after gates 1–4 pass.

Evidence belongs under:

`Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/`

The absence of any artifact, any FAIL/INCONCLUSIVE result, a mismatched commit, or an incomplete manual observation keeps AC2.2 unchecked.

## 13. Future Extension Points

AC2.3 extends `BattleUnitState` with HP and active participation. `BattleTurnQueue` excludes defeated units while preserving AC2.2's descending-speed and semantic formation tie-break contract for every active unit. Later criteria may replace debug fixtures with roster/enemy composition and respond to speed/status changes at the documented round boundary without changing that ordering contract.
