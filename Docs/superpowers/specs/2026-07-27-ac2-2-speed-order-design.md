# AC2.2 Speed Order Design

| Field | Value |
|---|---|
| Project | Two-Dimension Exploration |
| Source Spec | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` |
| Acceptance Criterion | AC2.2 — Faster units act earlier according to speed order |
| Owner | Project Lead |
| Prepared by | Codex |
| Date | 2026-07-27 |
| Status | Approved for implementation planning |

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

## 3. Formation and Tie-Break Contract

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

## 4. Authority and Dependencies

Implementation and review use this authority chain:

1. `.agents/policies/project-governance.md` defines the Concept → Design → Implementation → QA gate.
2. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` defines speed range `1–10`, descending speed order, one active skill per turn, and AC2.2's manual verification requirement.
3. This document defines AC2.2 behavior, interfaces, tie-breaking, scope, and verification.
4. The AC2.2 implementation plan defines implementation sequence after it exists and passes review.
5. `Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/` is the completion authority.

AC2.2 extends AC2.1's `BattleArena`, twelve stable scene-authored slots, Combat/Boss entry flow, navigation blocking, and debug exit. Existing map and AC2.1 tests remain regression authority.

## 5. Architecture

Combat rules remain separate from UI presentation:

- `BattleUnitState` is a focused typed state object for the minimum unit data AC2.2 needs.
- `BattleTurnQueue` is a pure ordering service. It validates units and returns a new ordered array without mutating its input.
- `BattleArena` owns the active debug battle state, current queue index, round number, and UI synchronization.

This boundary lets AC2.3 extend unit state with HP and active participation without moving sorting rules into scene nodes. It also lets future roster integration replace debug fixtures while preserving the queue interface.

## 6. Components and Interfaces

### 6.1 Battle Unit State

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

### 6.2 Turn Queue

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

### 6.3 Battle Arena

`BattleArena` gains:

```gdscript
var round_number: int = 1

func get_current_unit() -> BattleUnitState
func get_turn_queue() -> Array[BattleUnitState]
func advance_turn() -> void
```

On initialization, the arena creates twelve explicit deterministic debug fixtures. They occupy every player and enemy slot, use speeds within `1–10`, and include ties across front/back and both sides. The exact fixture table is part of the implementation plan and automated expected order.

The arena builds its first queue, selects index `0`, and synchronizes all unit and turn UI. `advance_turn()` moves exactly one position. When called on the final position, it increments `round_number`, rebuilds the queue from the active unit collection, and selects the new first entry.

Queue accessors return copies where needed so external callers and tests cannot silently reorder arena-owned state.

## 7. UI and Interaction

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

When no valid queue exists:

- `get_current_unit()` returns `null`.
- The current-unit label shows `No active units`.
- The advance button is disabled.
- No slot is highlighted.

The debug controls are temporary verification seams and are not production action-selection UX.

## 8. State and Error Handling

- Queue construction never mutates the caller's unit array.
- Rebuilding the same unchanged unit set returns the same identity order.
- Only one current slot is highlighted.
- One accepted button press advances one position; deferred signal handling prevents duplicate advancement from one input event.
- An empty unit collection is valid and produces the no-active-unit state.
- Invalid speed, side, slot, null entry, or duplicate occupancy produces an empty queue and a clear diagnostic.
- A round changes only when advancing past the final queue entry.
- Starting or exiting a battle does not mutate map/run state.
- Combat and Boss arenas use the same AC2.2 ordering contract.

## 9. Verification

### Automated

Create:

`res://Tests/Battle/test_ac2_2_speed_order.gd`

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

## 10. Completion Evidence

AC2.2 remains unchecked until the repository contains current passing:

- Focused AC2.2 automated output.
- Existing regression output.
- GodotIQ project validation, parser, signal, runtime, and input evidence.
- Manual runtime observations for Combat, all twelve turns, tie order, round wrap, debug exit, and Boss initialization.
- An implementation link identifying the task branch and final implementation commit.

Evidence belongs under:

`Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/`

Required artifacts are:

- `automated-test.log`
- `manual-runtime-check.md`
- `implementation-link.txt`

`Docs/Specs/GAME_DESIGN_SPEC_MVP.md` must keep AC2.2 unchecked until all required evidence exists and passes.

## 11. Future Extension Points

AC2.3 may add health and active/defeated state to `BattleUnitState`; queue rebuilding can then exclude defeated units. Later criteria may replace debug fixtures with roster/enemy composition, replace the debug advance button with completed action resolution, and respond to speed/status changes at the documented round boundary. Those extensions should preserve the pure queue contract and semantic formation tie-break.
