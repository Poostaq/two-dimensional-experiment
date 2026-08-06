# Active-Turn Skills and World Turn Counter Design

| Metadata | Value |
|---|---|
| Project | TwoDimensionExploration |
| Source Spec | `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` |
| Acceptance Criterion | AC2.6 UI hardening with AC1.1 map observability coverage, before AC3.1 |
| Owner | Project Lead |
| Prepared by | Codex |
| Date | 2026-08-06 |
| Status | Approved design; implementation pending |

This is a pre-AC3.1 hardening slice only. It does not create, rename, alter, complete, or reopen any canonical MVP acceptance-criterion ID, and it does not change any checkbox status in `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`.

## Goal

Before starting milestone 3.1, make the battle skill panel continuously show the active character's skills for the entire turn and add an always-visible world-map counter for successful movement turns.

## Scope

This change has two small UI behaviors:

1. Lock the battle skill panel to the current turn's unit, including enemy units for current debug visibility.
2. Display the existing world-map `move_count` as a top-left `Turns: N` HUD badge.

Save persistence, new turn rules, skill-system changes, and broader HUD redesign are outside scope.

## Battle Skill Panel Behavior

`BattleArena` remains the owner of battle turn state and skill-panel presentation. The panel derives its inspected unit from `get_current_unit()` whenever the turn context changes.

The arena synchronizes the skill panel:

- after units are configured and the initial turn queue is built;
- after `advance_turn()` selects the next active unit;
- after unit removal rebuilds the turn queue;
- whenever a relevant turn UI refresh needs to restore the invariant.

While the battle outcome is `IN_PROGRESS`, `inspect_unit()` does not allow a clicked player or enemy slot to replace the current unit. It resolves inspection to the active unit. This keeps the panel locked for the full turn while preserving existing slot click wiring.

Player and enemy turns follow the same presentation path. The panel continues to show the active unit's name, status, skill count, active and passive skills, hover tooltips, selection state, and existing debug targeting behavior. Skill evaluation, transactions, effects, and targeting rules do not change.

If no valid current unit exists or the battle has ended, the inspector is cleared so stale skills are not displayed.

## World Turn Counter Behavior

`MapController.move_count` remains the sole authoritative value. One accepted adjacent map move equals one turn.

The `game_world.tscn` UI canvas receives a compact top-left label. Its text format is exactly:

```text
Turns: N
```

The label shows `Turns: 0` when a run starts, updates after every accepted move, and returns to `Turns: 0` when `set_run_id()` resets the run. Invalid, non-adjacent, or blocked movement requests do not increment the model and therefore do not change the label.

The counter is run-local and intentionally has no save/load persistence in this change.

## Components

### `Scenes/battle_arena.tscn`

The existing skill inspector layout is reused without structural redesign.

### `Scripts/Battle/battle_arena.gd`

Add a focused helper that synchronizes `_inspected_unit_id` and the skill inspector with `get_current_unit()`. Call it at each turn-ownership transition and enforce the same invariant through `inspect_unit()` during an active battle.

### `Scenes/game_world.tscn`

Add the named top-left counter label beneath the existing `UI` `CanvasLayer` so it remains screen-space UI rather than map geometry.

### `Scripts/Map/map_controller.gd`

Cache the counter label with a typed `@onready` reference. Add a focused refresh helper that formats `move_count`, then call it during initial readiness, after accepted movement, and after run reset.

## Edge Cases

- An empty or exhausted battle queue clears the skill inspector.
- A defeated or removed current unit cannot leave stale skills visible after queue rebuilding.
- Enemy turns show enemy skills using the same inspector behavior as player turns.
- Clicking any non-active unit during an in-progress battle does not change the displayed unit.
- Rejected map movement leaves both `move_count` and the displayed counter unchanged.
- Opening an encounter or battle does not itself add a world turn; only the successful movement that reached the tile does.

## Verification

Battle coverage will prove:

- the first active unit's skills appear without a slot click;
- clicking another unit cannot replace the active unit in the panel;
- advancing the turn switches and locks the panel to the next player or enemy unit;
- rebuilding the queue after unit removal resynchronizes the panel;
- battle completion or absence of a current unit clears stale inspection state.

Map coverage will prove:

- the counter starts at zero;
- one accepted move increments it exactly once;
- rejected moves do not change it;
- resetting the run returns it to zero.

Implementation verification will run the focused battle and map suites, GodotIQ validation and parser checks after each script change, scene validation, and a runtime play check covering the top-left counter plus player/enemy turn transitions.

## Traceability Matrix

The focused runners do not exist yet and must be created during implementation. Existing broad suites remain regression gates; their historical assertions must be updated only where the new locked-inspector contract intentionally supersedes free inspection.

| Coverage | Exact test case | Target test file | Production targets |
|---|---|---|---|
| Battle: initial lock | `_test_initial_turn_locks_skill_panel_to_current_unit` | `Tests/Battle/test_active_turn_skill_lock.gd` (create) | `Scripts/Battle/battle_arena.gd` |
| Battle: click override rejection | `_test_non_current_slot_click_cannot_override_active_unit` | `Tests/Battle/test_active_turn_skill_lock.gd` (create) | `Scripts/Battle/battle_arena.gd` |
| Battle: turn advance sync | `_test_turn_advance_syncs_skill_panel_for_player_and_enemy` | `Tests/Battle/test_active_turn_skill_lock.gd` (create) | `Scripts/Battle/battle_arena.gd` |
| Battle: removal/rebuild sync | `_test_current_unit_removal_rebuilds_queue_and_syncs_skill_panel` | `Tests/Battle/test_active_turn_skill_lock.gd` (create) | `Scripts/Battle/battle_arena.gd` |
| Battle: no current/battle end | `_test_no_current_unit_or_battle_end_clears_skill_panel` | `Tests/Battle/test_active_turn_skill_lock.gd` (create) | `Scripts/Battle/battle_arena.gd` |
| Map: initial zero text | `_test_turn_counter_starts_at_zero` | `Tests/Map/test_world_turn_counter.gd` (create) | `Scenes/game_world.tscn`, `Scripts/Map/map_controller.gd` |
| Map: accepted move text | `_test_accepted_move_increments_turn_counter_once` | `Tests/Map/test_world_turn_counter.gd` (create) | `Scripts/Map/map_controller.gd` |
| Map: rejected move text | `_test_rejected_move_leaves_turn_counter_unchanged` | `Tests/Map/test_world_turn_counter.gd` (create) | `Scripts/Map/map_controller.gd` |
| Map: run reset text | `_test_set_run_id_resets_turn_counter_to_zero` | `Tests/Map/test_world_turn_counter.gd` (create) | `Scripts/Map/map_controller.gd` |

## Exact Test Execution

Run the focused suites from the repository root:

```powershell
godot --headless --path . --script res://Tests/Battle/test_active_turn_skill_lock.gd
godot --headless --path . --script res://Tests/Map/test_world_turn_counter.gd
```

Expected focused PASS signatures and exit code:

```text
Active-turn skill lock tests: PASS (5/5)
World turn counter tests: PASS (4/4)
```

Each command must exit `0`. Any `FAILED:` line, parser error, runtime error, missing PASS signature, or nonzero exit code is a failure.

Run the required battle and map regressions from the repository root:

```powershell
$test_scripts = @(
    Get-ChildItem -LiteralPath 'Tests/Battle' -Filter 'test_*.gd' -File
    Get-ChildItem -LiteralPath 'Tests/Map' -Filter 'test_*.gd' -File
) | Sort-Object FullName
foreach ($test_script in $test_scripts) {
    $resource_path = 'res://' + $test_script.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
    & godot --headless --path . --script $resource_path
    if ($LASTEXITCODE -ne 0) { throw "Regression failed: $resource_path" }
}
```

Expected regression signature: every discovered AC2.x battle runner and map runner exits `0`, prints its own `PASS` summary, and prints no `FAILED:` line. This includes the existing `Tests/Battle/test_ac2_6_character_skills.gd` and `Tests/Map/test_map_controller_runtime.gd` suites plus the two new focused runners.

After each changed script, run GodotIQ `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`. After all changes, run:

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

Expected result: no new convention, parser, orphan-signal, or runtime errors; Play starts successfully. Stop Play after the manual checks.

## Completion Evidence

Before marking the work complete, create this consolidated package:

```text
Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/automated-test.log
Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/manual-runtime-check.md
Docs/Specs/AC2/Evidence/AC2.6/2026-08-06/implementation-link.txt
```

The AC2.6 destination is intentional: this is one cross-cutting pre-3.1 readiness package whose primary behavior hardens the character-skill UI; the included AC1.1 map HUD checks are supporting observability evidence and do not change AC1.1 or AC2.6 authority.

`automated-test.log` records the tested commit SHA, exact focused and regression commands, exit codes, and PASS signatures. `manual-runtime-check.md` records PASS/FAIL for initial player lock, rejected slot override, enemy-turn skill visibility, turn-advance synchronization, queue rebuild, battle-end clearing, initial `Turns: 0`, accepted-move increment, rejected-move stability, run reset, top-left placement, and debugger state. `implementation-link.txt` contains the same tested implementation SHA. All three artifacts must reference the same commit.

## Definition of Done

- [ ] All nine named focused test cases pass with the exact `5/5` and `4/4` PASS signatures.
- [ ] The battle panel always identifies the current unit during an in-progress player or enemy turn; a non-current click cannot change it.
- [ ] No-current and completed-battle states display no stale unit skills.
- [ ] The top-left label reads exactly `Turns: N`, starts and resets at `0`, increments once per accepted move, and never changes for rejected moves.
- [ ] GodotIQ project validation, parser checks, orphan-signal check, runtime readiness, and debugger checks report no new failures.
- [ ] Every existing AC2.x battle suite and every map suite remains green.
- [ ] The three evidence artifacts exist at the dated AC2.6 path and reference one tested implementation SHA.
- [ ] Only scoped implementation, test, scene, and evidence files are included in the completion commits.
