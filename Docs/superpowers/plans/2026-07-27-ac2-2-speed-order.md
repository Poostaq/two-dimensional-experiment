# AC2.2 Speed Order Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic descending-speed turns, stable formation tie-breaking, and a visible debug-driven current-unit loop to the AC2.1 arena.

**Architecture:** `BattleUnitState` holds scene-independent unit data and `BattleTurnQueue` validates and sorts typed unit arrays without mutation. `BattleArena` owns debug fixtures, queue/round state, and UI synchronization while the scene continues to own all presentation nodes.

**Tech Stack:** Godot 4.7.1, typed GDScript, GodotIQ structured script/scene tooling, headless `SceneTree` tests.

---

## File Structure

- Create: `Tests/Battle/test_ac2_2_speed_order.gd` — focused 12-case queue and arena contract.
- Create: `Scripts/Battle/battle_unit_state.gd` — typed unit identity, side, slot, and speed.
- Create: `Scripts/Battle/battle_turn_queue.gd` — pure validation and deterministic sorting.
- Modify: `Scripts/Battle/battle_arena.gd` — fixtures, current turn, round wrap, and UI synchronization.
- Modify: `Scenes/battle_arena.tscn` — turn status, slot labels, highlights, and advance control.
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — mark AC2.2 complete only after current evidence passes.
- Create: `Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/{automated-test.log,manual-runtime-check.md,implementation-link.txt}`.

## Fixed Debug Fixture

| Side | Slot | ID | Display | Speed |
|---|---:|---|---|---:|
| Player | 0 | `player_0` | Player Front 1 | 8 |
| Player | 1 | `player_1` | Player Front 2 | 6 |
| Player | 2 | `player_2` | Player Front 3 | 6 |
| Player | 3 | `player_3` | Player Back 1 | 4 |
| Player | 4 | `player_4` | Player Back 2 | 9 |
| Player | 5 | `player_5` | Player Back 3 | 2 |
| Enemy | 0 | `enemy_0` | Enemy Front 1 | 8 |
| Enemy | 1 | `enemy_1` | Enemy Front 2 | 7 |
| Enemy | 2 | `enemy_2` | Enemy Front 3 | 6 |
| Enemy | 3 | `enemy_3` | Enemy Back 1 | 4 |
| Enemy | 4 | `enemy_4` | Enemy Back 2 | 9 |
| Enemy | 5 | `enemy_5` | Enemy Back 3 | 2 |

Exact expected order:

```text
player_4, enemy_4, player_0, enemy_0, enemy_1, player_1,
player_2, enemy_2, player_3, enemy_3, player_5, enemy_5
```

### Task 1: Commit the Approved Plan

- [ ] **Step 1: Self-review the plan**

Run:

```powershell
$patterns = @('T' + 'BD', 'T' + 'ODO', 'implement' + ' later', 'appropriate' + ' error', 'similar' + ' to')
$patterns | ForEach-Object { rg -n --fixed-strings $_ Docs/superpowers/plans/2026-07-27-ac2-2-speed-order.md }
git diff --check
```

Expected: no placeholder matches and no whitespace errors.

- [ ] **Step 2: Commit**

```powershell
git add Docs/superpowers/plans/2026-07-27-ac2-2-speed-order.md
git commit -m "docs: plan AC2.2 speed order implementation"
```

### Task 2: Write and Prove the Focused Contract

**Files:**

- Create: `Tests/Battle/test_ac2_2_speed_order.gd`

- [ ] **Step 1: Create the failing typed `SceneTree` test through GodotIQ**

Define `EXPECTED_TEST_COUNT := 12`; run the twelve cases from the approved design; load real scripts/scenes; assert the fixed fixture order above; assert the exact `No active units` state; print each failure as `FAILED: <name> - <reason>`; print exactly `AC2.2 speed order tests: PASS (12/12)` only on success; exit `1` on any failure.

- [ ] **Step 2: Validate and verify RED**

```text
validate(res://Tests/Battle/test_ac2_2_speed_order.gd, detail=brief)
check_errors(res://Tests/Battle/test_ac2_2_speed_order.gd)
```

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script Tests/Battle/test_ac2_2_speed_order.gd
```

Expected: nonzero exit because `BattleUnitState`, `BattleTurnQueue`, arena turn APIs, and UI nodes do not exist.

- [ ] **Step 3: Commit the red contract**

```powershell
git add Tests/Battle/test_ac2_2_speed_order.gd
git commit -m "test: specify AC2.2 speed order"
```

### Task 3: Implement Unit State and Pure Queue

**Files:**

- Create: `Scripts/Battle/battle_unit_state.gd`
- Create: `Scripts/Battle/battle_turn_queue.gd`
- Test: `Tests/Battle/test_ac2_2_speed_order.gd`

- [ ] **Step 1: Create `BattleUnitState` through GodotIQ**

Implement `class_name BattleUnitState extends RefCounted`, `enum Side { PLAYER, ENEMY }`, the five typed fields and constructor specified by the design.

- [ ] **Step 2: Validate the script and check parsing**

```text
validate(res://Scripts/Battle/battle_unit_state.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_unit_state.gd)
```

- [ ] **Step 3: Create `BattleTurnQueue` through GodotIQ**

Implement `class_name BattleTurnQueue extends RefCounted`, constants `MIN_SPEED := 1`, `MAX_SPEED := 10`, `SIDE_SLOT_COUNT := 6`, and:

```gdscript
static func build(units: Array[BattleUnitState]) -> Array[BattleUnitState]
```

Validate nulls, enum sides, speed, slot range, and unique `(side, slot_index)`. Return an empty typed array with a diagnostic on invalid input. Duplicate the array before `sort_custom`; compare descending speed, then ascending side enum (`PLAYER` before `ENEMY`), then ascending slot index.

- [ ] **Step 4: Validate, parse, and run focused tests**

Expected: queue cases 1–8 pass; arena cases 9–12 remain red.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/Battle/battle_unit_state.gd Scripts/Battle/battle_turn_queue.gd
git commit -m "feat: add deterministic battle turn queue"
```

### Task 4: Implement Arena Turn State and UI

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Scenes/battle_arena.tscn`
- Test: `Tests/Battle/test_ac2_2_speed_order.gd`

- [ ] **Step 1: Inspect impact before editing**

```text
file_context(res://Scripts/Battle/battle_arena.gd, detail=brief)
file_context(res://Scenes/battle_arena.tscn, detail=brief)
impact_check(res://Scripts/Battle/battle_arena.gd, action=modify_function, target=_ready, change_description="initialize AC2.2 turn state and UI")
```

- [ ] **Step 2: Add scene-authored UI with GodotIQ**

Under `Margin/VBox`, add `TurnStatus` with unique-name labels `RoundLabel` and `CurrentUnitLabel`. Add unique-name `AdvanceTurnDebugButton` before the existing exit button. Under each of the twelve slots, add a `VBoxContainer` with `UnitNameLabel` and `SpeedLabel`. Use readable minimum sizes and centered text; do not replace the existing formations or debug exit.

- [ ] **Step 3: Add arena behavior through GodotIQ**

Add typed node references, `_units`, `_turn_queue`, `_current_turn_index`, and `round_number := 1`. Implement the design APIs:

```gdscript
func configure_units(units: Array[BattleUnitState]) -> void
func get_turn_queue() -> Array[BattleUnitState]
func get_current_unit() -> BattleUnitState
func advance_turn() -> void
```

Create the fixed fixtures exactly as tabulated. Initialize metadata before fixtures. Connect advance once; one press calls `advance_turn()` once. Render names/speeds by `(side, slot_index)`, reset every slot to neutral modulation, highlight only the current slot, show `Round N`, show `<display> | Speed <n>` for an active unit, and enforce the exact empty-state contract.

- [ ] **Step 4: Validate each changed file**

```text
validate(res://Scripts/Battle/battle_arena.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_arena.gd)
validate(res://Scenes/battle_arena.tscn, detail=brief)
```

- [ ] **Step 5: Verify GREEN**

Run the focused test. Expected: exact `AC2.2 speed order tests: PASS (12/12)` and exit `0`.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_arena.gd Scenes/battle_arena.tscn
git commit -m "feat: show AC2.2 speed-ordered turns"
```

### Task 5: Regression, Runtime QA, and Evidence

- [ ] **Step 1: Run all headless tests independently**

Run every `Tests/Map/*.gd` and `Tests/Battle/*.gd` with the explicit Godot executable. Expected: every process exits `0`, no output contains `FAILED:`, and the AC2.2 signature is exact.

- [ ] **Step 2: Run structured GodotIQ gates**

```text
validate(project, detail=brief)
check_errors(project)
signal_map(scope=all, find=orphans, detail=brief)
verify_project_runs(scene=main, check_scope=project, stop_after=true)
```

- [ ] **Step 3: Perform real runtime/UI verification**

Use `run(play)` and `ui_map` before pointer input. Enter a real Combat battle, verify all speed labels and the queue head, click `Advance Turn (Debug)` through twelve transitions, verify the exact tie order and Round 2 wrap, verify empty-state behavior through `configure_units([])`, debug-exit with preserved map state, and repeat initialization in Boss. Use one screenshot for the final populated state and one for the empty state, then stop.

- [ ] **Step 4: Create exact evidence**

Create `automated-test.log`, `manual-runtime-check.md`, and `implementation-link.txt` under `Docs/Specs/AC2/Evidence/AC2.2/2026-07-27/` with the fields and same-commit gates required by the approved design.

- [ ] **Step 5: Mark AC2.2 complete only after evidence passes**

Change AC2.2 to `[x]`, rerun the focused test and structured gates, then commit only the source spec and evidence:

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.2/2026-07-27
git commit -m "docs: record AC2.2 verification evidence"
```

## Self-Review

- Every approved scope item maps to a task and exact file.
- The fixture identities, speeds, tie order, APIs, labels, success signature, failure behavior, and evidence gate are explicit.
- `Tests/Battle/` is intentionally introduced for battle-domain behavior; AC2.1 transition coverage remains in `Tests/Map/`.
- No later damage, action, skill, roster, or victory behavior is included.
