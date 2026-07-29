# AC2.4 Battle Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** End a battle exactly once with Victory when no active enemies remain or Defeat when no active player units remain, and show the correct persistent result in the battle arena.

**Architecture:** Add a pure `BattleOutcome` rules object that evaluates typed unit state without depending on scene nodes. `BattleArena` owns the battle lifecycle, latches the first terminal outcome immediately after a successful damage action, stops turn advancement and future damage, and renders a persistent result panel. The existing `exit_requested` seam remains the only map-return mechanism; rewards, revival, run completion, and encounter consumption remain deferred to their owning acceptance criteria.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ structured editing and validation, headless `SceneTree` contract tests.

---

## Scope and file map

- Create `Scripts/Battle/battle_outcome.gd`: pure typed outcome enum, side-count evaluation, and display text.
- Modify `Scripts/Battle/battle_arena.gd`: latch/reset outcome, expose it for tests/future integration, evaluate after accepted damage, freeze the completed battle, and refresh result UI.
- Modify `Scenes/battle_arena.tscn`: add a persistent result panel and label without changing the two formations or battle log.
- Create `Tests/Battle/test_ac2_4_battle_results.gd`: focused logic, integration, idempotence, and presentation contract.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: expand AC2.4's verification path and mark it complete only after all evidence gates pass.
- Create `Docs/Specs/AC2/Evidence/AC2.4/2026-07-29/automated-test.log`: captured focused and regression test output.
- Create `Docs/Specs/AC2/Evidence/AC2.4/2026-07-29/manual-runtime-check.md`: Combat and Boss victory/loss observations.
- Create `Docs/Specs/AC2/Evidence/AC2.4/2026-07-29/implementation-link.txt`: tested commit identifier.

Out of scope:

- AC2.5 reward selection or encounter-specific rewards.
- AC3.8 post-victory revival and recovery.
- AC4.1 final-boss run completion and unlocks.
- Removing or replacing the existing debug exit.
- Persistently clearing a map encounter after a win.
- A generalized state machine for future skill/effect phases.

## Acceptance and verification matrix

| Criterion | Classification | Verification path | Evidence | Status before implementation | Gap / next action |
|---|---|---|---|---|---|
| AC2.4 victory: all enemies defeated | Logic + integration + runtime | `test_ac2_4_battle_results.gd` evaluates enemy exhaustion and completes an arena after the final enemy hit; manual Combat and Boss victory paths | New focused runner, manual runtime record | FAIL | No outcome evaluator, terminal latch, or result UI exists |
| AC2.4 loss: all player units defeated | Logic + integration + runtime | Focused runner evaluates player exhaustion and completes an arena after the final player hit; manual Combat and Boss loss paths | New focused runner, manual runtime record | FAIL | Existing no-opponent seam only disables damage |
| Terminal result is stable | Integration | Focused runner calls damage again and verifies no HP, log, round, queue, or outcome mutation | New focused runner | FAIL | Arena has no terminal lifecycle state |
| Result is visible and binary | Visual + runtime | Focused UI assertion plus manual observation of exact `Victory` / `Defeat` text | Scene assertion, manual runtime record | FAIL | No result presentation exists |
| Empty/invalid configuration does not claim a result | Logic | Focused runner expects `IN_PROGRESS` for empty, null-only, invalid-side, and both-sides-inactive configurations | New focused runner | FAIL | Ambiguous invalid-state policy is not encoded |

Overall before implementation: **0/5 verification rows covered; FAIL**. AC2.4 remains unchecked until all focused, regression, GodotIQ, and manual evidence gates pass against one commit.

## Evidence-state policy

Use exactly three evidence states:

- `PASS`: the named command or manual runtime path was executed against the recorded commit and produced the expected result.
- `FAIL`: the executable ran or the manual path was attempted and produced an incorrect result.
- `BLOCKED`: the check could not run because the Godot executable, runtime bridge, display/input path, or another required runtime capability was unavailable.

An unavailable Godot executable is never a pass. Record the unavailable command, the lookup or launch error, and `BLOCKED` in the evidence artifact. A blocked focused runner, regression runner, runtime gate, visual tour, or manual Combat/Boss path prevents AC2.4 completion and keeps its checkbox unchecked; static review and parser-independent inspection may continue but cannot substitute for runtime evidence.

## Source-spec verification mismatch to resolve

`Docs/Specs/GAME_DESIGN_SPEC_MVP.md` currently classifies AC2.4 as `Manual runtime check`. This plan adds deterministic automated coverage for the outcome rules, terminal lifecycle, reset behavior, idempotence, and scene presentation while retaining manual Combat/Boss checks for real interaction and layout. The implementation must therefore change the AC2.4 verification type to `Automated and manual runtime check` and replace the current manual-only path with the combined path specified in Task 5. This is an intentional verification-contract migration, not evidence that AC2.4 has passed; the criterion remains unchecked until both halves execute successfully.

### Task 1: Create the pure battle-outcome contract

**Files:**

- Create: `Scripts/Battle/battle_outcome.gd`
- Test: `Tests/Battle/test_ac2_4_battle_results.gd`

- [ ] **Step 1: Inspect impact and establish a clean task branch**

Run:

```powershell
git status --short --branch
git fetch origin
git pull --ff-only origin main
git switch -c feat/ac2-4-battle-results
```

Expected: `main` fast-forwards cleanly and the new branch is based on `origin/main`. Preserve the existing unrelated `.vscode`, `.superpowers`, `.tmp-godotiq-debug`, and UID changes without staging them; if they block the pull, stash only those exact paths and restore them after switching branches. Do not use a worktree in this repository.

Use GodotIQ before code work:

```text
project_summary(detail="brief")
validate(target="project", detail="brief")
file_context(file="res://Scripts/Battle/battle_unit_state.gd", detail="brief")
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="normal")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="add_method", target="battle outcome API")
```

Expected: the project baseline is recorded, `BattleUnitState.Side` exposes `PLAYER` and `ENEMY`, and `BattleArena` is the scene coordinator.

- [ ] **Step 2: Write the failing pure-rule tests**

Create `Tests/Battle/test_ac2_4_battle_results.gd` with the runner shell and these first cases:

```gdscript
class_name Ac2_4BattleResultsTests
extends SceneTree

const OUTCOME_PATH := "res://Scripts/Battle/battle_outcome.gd"
const UNIT_PATH := "res://Scripts/Battle/battle_unit_state.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 9

var _failures: Array[String] = []
var _outcome_script: GDScript
var _unit_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_outcome_script = load(OUTCOME_PATH) as GDScript if ResourceLoader.exists(OUTCOME_PATH) else null
	_unit_script = load(UNIT_PATH) as GDScript
	_test_active_sides_remain_in_progress()
	_test_no_active_enemies_is_victory()
	_test_no_active_players_is_defeat()
	_test_invalid_configurations_remain_in_progress()
	await _test_final_enemy_hit_latches_victory()
	await _test_final_player_hit_latches_defeat()
	await _test_completed_battle_is_immutable()
	await _test_reconfigure_resets_outcome()
	await _test_result_presentation_is_binary()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _unit(id: StringName, side: int, slot_index: int, speed: int = 5) -> BattleUnitState:
	return _unit_script.new(id, str(id), side, slot_index, speed) as BattleUnitState


func _set_hp(unit: BattleUnitState, hp: int) -> void:
	unit.current_hp = hp


func _evaluate(units: Array) -> int:
	if _outcome_script == null:
		return -1
	var typed_units: Array[BattleUnitState] = []
	for unit: Variant in units:
		typed_units.append(unit as BattleUnitState)
	return int(_outcome_script.call("evaluate", typed_units))


func _test_active_sides_remain_in_progress() -> void:
	var units: Array[BattleUnitState] = [
		_unit(&"player", BattleUnitState.Side.PLAYER, 0),
		_unit(&"enemy", BattleUnitState.Side.ENEMY, 0),
	]
	_assert(_evaluate(units) == 0, "active sides remain in progress", "expected IN_PROGRESS")


func _test_no_active_enemies_is_victory() -> void:
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0)
	_set_hp(enemy, 0)
	_assert(_evaluate([player, enemy]) == 1, "enemy exhaustion is victory", "expected VICTORY")


func _test_no_active_players_is_defeat() -> void:
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0)
	_set_hp(player, 0)
	_assert(_evaluate([player, enemy]) == 2, "player exhaustion is defeat", "expected DEFEAT")


func _test_invalid_configurations_remain_in_progress() -> void:
	var defeated_player := _unit(&"player", BattleUnitState.Side.PLAYER, 0)
	var defeated_enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0)
	_set_hp(defeated_player, 0)
	_set_hp(defeated_enemy, 0)
	var both_defeated: Array[BattleUnitState] = [defeated_player, defeated_enemy]
	var empty: Array[BattleUnitState] = []
	_assert(
		_evaluate(empty) == 0 and _evaluate(both_defeated) == 0,
		"invalid configurations remain in progress",
		"empty or simultaneously inactive sides must not claim a result"
	)
```

Add the shared assertion/report helpers:

```gdscript
func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.4 battle result tests: PASS (%d/%d)" % [
			EXPECTED_TEST_COUNT,
			EXPECTED_TEST_COUNT,
		])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

- [ ] **Step 3: Run the focused runner and verify the expected failure**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
```

Expected: exit non-zero because `res://Scripts/Battle/battle_outcome.gd` does not exist or `evaluate` cannot return the required values.

- [ ] **Step 4: Implement the minimal pure outcome evaluator**

Create `Scripts/Battle/battle_outcome.gd` through GodotIQ `script_ops(op="create")`:

```gdscript
class_name BattleOutcome
extends RefCounted

enum Type {
	IN_PROGRESS,
	VICTORY,
	DEFEAT,
}


static func evaluate(units: Array[BattleUnitState]) -> Type:
	var has_player := false
	var has_enemy := false
	var has_active_player := false
	var has_active_enemy := false
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit):
			continue
		match unit.side:
			BattleUnitState.Side.PLAYER:
				has_player = true
				has_active_player = has_active_player or unit.is_active()
			BattleUnitState.Side.ENEMY:
				has_enemy = true
				has_active_enemy = has_active_enemy or unit.is_active()
	if not has_player or not has_enemy:
		return Type.IN_PROGRESS
	if has_active_player == has_active_enemy:
		return Type.IN_PROGRESS
	return Type.VICTORY if has_active_player else Type.DEFEAT


static func get_display_text(outcome: Type) -> String:
	match outcome:
		Type.VICTORY:
			return "Victory"
		Type.DEFEAT:
			return "Defeat"
		_:
			return ""
```

The simultaneous-inactive policy is intentionally `IN_PROGRESS`: normal sequential damage cannot produce it, and invalid fixture/configuration state must not falsely award a win or loss.

- [ ] **Step 5: Validate the new script and rerun the pure tests**

Use:

```text
validate(target="res://Scripts/Battle/battle_outcome.gd", detail="brief")
check_errors(scope="file:res://Scripts/Battle/battle_outcome.gd")
```

Then run the focused runner. Expected: the first four rule cases no longer report failures; arena integration cases still fail.

- [ ] **Step 6: Commit the pure rule**

```powershell
git add -- Scripts/Battle/battle_outcome.gd Tests/Battle/test_ac2_4_battle_results.gd
git commit -m "test: define AC2.4 battle outcome contract"
```

Expected: only the two listed files are committed.

### Task 2: Latch terminal outcomes in BattleArena

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac2_4_battle_results.gd`

- [ ] **Step 1: Add failing arena lifecycle tests**

Add these helpers and four cases to the focused runner:

```gdscript
func _instantiate_arena() -> BattleArena:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as BattleArena if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _configure(arena: BattleArena, units: Array[BattleUnitState]) -> void:
	arena.configure_units(units)


func _free_arena(arena: BattleArena) -> void:
	if is_instance_valid(arena):
		arena.queue_free()


func _test_final_enemy_hit_latches_victory() -> void:
	var arena := await _instantiate_arena()
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(enemy, 6)
	_configure(arena, [player, enemy])
	arena.perform_debug_damage()
	_assert(
		arena.get_battle_outcome() == BattleOutcome.Type.VICTORY,
		"final enemy hit latches victory",
		"expected VICTORY immediately after resolution"
	)
	_free_arena(arena)


func _test_final_player_hit_latches_defeat() -> void:
	var arena := await _instantiate_arena()
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 9)
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 8)
	_set_hp(player, 6)
	_configure(arena, [enemy, player])
	arena.perform_debug_damage()
	_assert(
		arena.get_battle_outcome() == BattleOutcome.Type.DEFEAT,
		"final player hit latches defeat",
		"expected DEFEAT immediately after resolution"
	)
	_free_arena(arena)


func _test_completed_battle_is_immutable() -> void:
	var arena := await _instantiate_arena()
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(enemy, 6)
	_configure(arena, [player, enemy])
	arena.perform_debug_damage()
	var log_count := arena.get_battle_log_entries().size()
	var round_before := arena.round_number
	arena.perform_debug_damage()
	_assert(
		arena.get_battle_log_entries().size() == log_count
		and arena.round_number == round_before
		and enemy.current_hp == 0
		and arena.get_battle_outcome() == BattleOutcome.Type.VICTORY,
		"completed battle is immutable",
		"terminal calls must not mutate HP, log, round, or outcome"
	)
	_free_arena(arena)


func _test_reconfigure_resets_outcome() -> void:
	var arena := await _instantiate_arena()
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 9)
	var defeated_enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(defeated_enemy, 6)
	_configure(arena, [player, defeated_enemy])
	arena.perform_debug_damage()
	var fresh_enemy := _unit(&"fresh_enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_configure(arena, [player, fresh_enemy])
	_assert(
		arena.get_battle_outcome() == BattleOutcome.Type.IN_PROGRESS,
		"reconfigure resets outcome",
		"new battle must start IN_PROGRESS"
	)
	_free_arena(arena)
```

- [ ] **Step 2: Run and verify lifecycle tests fail**

Run the focused runner. Expected: exit non-zero with missing `get_battle_outcome` and/or terminal-state failures.

- [ ] **Step 3: Add BattleArena outcome state and API**

Use `file_context` and `impact_check` again immediately before patching. Patch `Scripts/Battle/battle_arena.gd` through GodotIQ `script_ops(op="patch")` to add:

```gdscript
signal battle_completed(outcome: BattleOutcome.Type)

var _battle_outcome: BattleOutcome.Type = BattleOutcome.Type.IN_PROGRESS


func get_battle_outcome() -> BattleOutcome.Type:
	return _battle_outcome


func is_battle_complete() -> bool:
	return _battle_outcome != BattleOutcome.Type.IN_PROGRESS
```

Reset outcome inside `configure_units` before the UI refresh:

```gdscript
_battle_outcome = BattleOutcome.Type.IN_PROGRESS
```

Guard `perform_debug_damage` at its first line:

```gdscript
if is_battle_complete() or _action_in_progress:
	return
```

Replace the post-resolution advance segment with:

```gdscript
_show_resolution_feedback(entry)
var resolved_outcome := BattleOutcome.evaluate(_units)
if resolved_outcome == BattleOutcome.Type.IN_PROGRESS:
	_advance_after_action(attacker.unit_id)
else:
	_complete_battle(resolved_outcome)
_action_in_progress = false
_refresh_turn_ui()
```

Add the terminal latch:

```gdscript
func _complete_battle(outcome: BattleOutcome.Type) -> void:
	if is_battle_complete() or outcome == BattleOutcome.Type.IN_PROGRESS:
		return
	_battle_outcome = outcome
	_turn_queue.clear()
	_current_turn_index = 0
	battle_completed.emit(_battle_outcome)
```

Update `advance_turn` to begin with:

```gdscript
if is_battle_complete() or _turn_queue.is_empty():
	return
```

The outcome is evaluated only after a successful damage result and log append. Configuration alone does not announce victory or defeat; this preserves AC2.3's safe fixture behavior and prevents invalid pre-defeated setups from firing completion.

- [ ] **Step 4: Validate and parser-check the arena**

Use:

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="file:res://Scripts/Battle/battle_arena.gd")
signal_map(scope="file:res://Scripts/Battle/battle_arena.gd", find="missing", detail="brief")
```

Expected: no convention, parser, or missing-signal errors. An unconsumed `battle_completed` signal is acceptable for AC2.4 because it is the typed future integration seam for AC2.5/AC4.1.

- [ ] **Step 5: Run the focused runner**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
```

Expected: lifecycle cases pass; only the not-yet-built presentation case may fail.

- [ ] **Step 6: Commit the lifecycle integration**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_4_battle_results.gd
git commit -m "feat: latch terminal battle outcomes"
```

### Task 3: Present the persistent result state

**Files:**

- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac2_4_battle_results.gd`

- [ ] **Step 1: Add the failing binary-presentation test**

Add:

```gdscript
func _test_result_presentation_is_binary() -> void:
	var victory_arena := await _instantiate_arena()
	var victor := _unit(&"victor", BattleUnitState.Side.PLAYER, 0, 9)
	var final_enemy := _unit(&"final_enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(final_enemy, 6)
	_configure(victory_arena, [victor, final_enemy])
	victory_arena.perform_debug_damage()
	var victory_panel := victory_arena.get_node_or_null("%BattleResultPanel") as Control
	var victory_label := victory_arena.get_node_or_null("%BattleResultLabel") as Label

	var defeat_arena := await _instantiate_arena()
	var final_player := _unit(&"final_player", BattleUnitState.Side.PLAYER, 0, 8)
	var defeating_enemy := _unit(&"defeating_enemy", BattleUnitState.Side.ENEMY, 0, 9)
	_set_hp(final_player, 6)
	_configure(defeat_arena, [defeating_enemy, final_player])
	defeat_arena.perform_debug_damage()
	var defeat_panel := defeat_arena.get_node_or_null("%BattleResultPanel") as Control
	var defeat_label := defeat_arena.get_node_or_null("%BattleResultLabel") as Label

	_assert(
		victory_panel != null and victory_panel.visible
		and victory_label != null and victory_label.text == "Victory"
		and defeat_panel != null and defeat_panel.visible
		and defeat_label != null and defeat_label.text == "Defeat",
		"result presentation is binary",
		"expected persistent exact Victory and Defeat labels"
	)
	_free_arena(victory_arena)
	_free_arena(defeat_arena)
```

- [ ] **Step 2: Run and verify the presentation test fails**

Run the focused runner. Expected: exit non-zero because `%BattleResultPanel` and `%BattleResultLabel` do not exist.

- [ ] **Step 3: Add the result panel to the scene**

Before editing:

```text
file_context(file="res://Scenes/battle_arena.tscn", detail="normal")
scene_tree(root="BattleArena", depth=3, detail="full")
```

Confirm the existing hierarchy before mutation:

```text
BattleArena
├── Background
└── Margin
    └── VBox
        ├── EncounterTypeLabel
        ├── Formations
        ├── TurnStatus
        ├── DebugControls
        └── BattleLogPanel
```

Use GodotIQ `node_ops(validate=true)` to add `BattleResultPanel` as a direct child of `BattleArena/Margin/VBox`, at sibling index `3`: immediately after `TurnStatus` and immediately before `DebugControls`. Do not parent it under `Formations`, `TurnStatus`, `DebugControls`, or `BattleLogPanel`, and do not reorder any existing child. The resulting hierarchy must be:

```text
BattleArena/Margin/VBox
├── EncounterTypeLabel
├── Formations
├── TurnStatus
├── BattleResultPanel
│   └── BattleResultLabel
├── DebugControls
└── BattleLogPanel
```

Create:

```text
BattleResultPanel: PanelContainer
  unique_name_in_owner = true
  visible = false
  mouse_filter = MOUSE_FILTER_IGNORE
  size_flags_horizontal = SIZE_SHRINK_CENTER

BattleResultLabel: Label
  unique_name_in_owner = true
  text = ""
  horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  theme_override_font_sizes/font_size = 32
```

Because the panel participates in `VBox` layout rather than floating over it, it must not cover the formations, log, or debug exit. Save with GodotIQ `save_scene`, then rerun `scene_tree(root="BattleArena/Margin/VBox", depth=2, detail="full")` and confirm the exact order above.

- [ ] **Step 4: Wire presentation into BattleArena**

After `file_context`, patch the script through GodotIQ:

```gdscript
@onready var _battle_result_panel: PanelContainer = %BattleResultPanel
@onready var _battle_result_label: Label = %BattleResultLabel
```

Add:

```gdscript
func _refresh_result_ui() -> void:
	var complete := is_battle_complete()
	_battle_result_panel.visible = complete
	_battle_result_label.text = BattleOutcome.get_display_text(_battle_outcome)
```

Call `_refresh_result_ui()` from `_refresh_turn_ui()` before its current-unit early return. When complete, render a terminal status and disable damage:

```gdscript
if is_battle_complete():
	_current_unit_label.text = BattleOutcome.get_display_text(_battle_outcome)
	_advance_debug_button.disabled = true
	_refresh_highlights()
	return
```

Update `_refresh_highlights()` so transient damage feedback may finish, but once it expires a completed battle has no gold current-unit highlight:

```gdscript
if is_battle_complete():
	return
```

Place this guard after hovered/transient entry handling and before current-unit highlighting. Historical log hover remains available after completion and stays presentation-only.

- [ ] **Step 5: Validate scene and script, then rerun the focused runner**

Use:

```text
validate(target="res://Scenes/battle_arena.tscn", detail="brief")
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="file:res://Scripts/Battle/battle_arena.gd")
```

Run the focused test. Expected exact success signature:

```text
AC2.4 battle result tests: PASS (9/9)
```

and process exit `0`.

- [ ] **Step 6: Perform visual QA**

Run the project, enter a Combat arena, drive it to each result, and use GodotIQ visual inspection:

```text
run(action="play")
verify_project_runs()
explore(mode="tour")
```

Confirm the result panel is centered, readable, persistent, does not obscure either formation or the battle log, and the debug exit remains usable. If layout changes are needed, use GodotIQ scene operations, save, and tour again.

- [ ] **Step 7: Commit presentation**

```powershell
git add -- Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_4_battle_results.gd
git commit -m "feat: present AC2.4 battle results"
```

### Task 4: Run regression, runtime, and signal gates

**Files:**

- Test: `Tests/Battle/test_ac2_4_battle_results.gd`
- Verify: all existing `Tests/**/*.gd`

- [ ] **Step 1: Run the focused AC2.4 runner**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
```

Expected: `AC2.4 battle result tests: PASS (9/9)` and exit `0`.

- [ ] **Step 2: Run combat regressions**

```powershell
godot --headless --path . --script res://Tests/Map/test_ac2_1_battle_arena.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_2_speed_order.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_3_damage_defeat_log.gd
```

Expected: each runner prints its documented PASS signature and exits `0`. In particular, AC2.3's one-sided configuration remains a disabled no-op until a successful damage transaction produces the AC2.4 result.

- [ ] **Step 3: Run the complete test corpus**

Discover runners:

```powershell
rg --files Tests -g 'test_*.gd' | Sort-Object
```

Run every discovered script headlessly, one process per runner. Expected: every runner exits `0`; no parser or resource-load errors.

- [ ] **Step 4: Run project-wide GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="missing", detail="brief")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: no validation errors, parser errors, or missing signal definitions. Record `battle_completed` as an intentional future-facing orphan if the tool reports it; do not add a fake listener.

- [ ] **Step 5: Run the runtime gate**

```text
run(action="play")
verify_project_runs()
read_debug_console()
state_inspect(query="active battle outcome, current unit, action disabled state")
run(action="stop")
```

Expected: project starts, no runtime errors appear, Victory/Defeat matches the defeated side, the damage action is disabled, and no active current unit remains after completion.

If the Godot executable or runtime bridge is unavailable, record the exact launch failure and mark this gate `BLOCKED`; do not write `PASS`, infer success from static checks, or continue to AC2.4 completion.

### Task 5: Record evidence and close the criterion

**Files:**

- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.4/2026-07-29/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.4/2026-07-29/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.4/2026-07-29/implementation-link.txt`

- [ ] **Step 1: Capture automated evidence**

Write the exact commands, PASS signatures, exit codes, and GodotIQ validation/signal/runtime results to `automated-test.log`. Each gate must be labeled `PASS`, `FAIL`, or `BLOCKED`. If the Godot executable is unavailable, include the failed executable lookup/launch output and label every dependent headless or runtime gate `BLOCKED`; do not summarize a blocked, failing, or stale run as passing.

- [ ] **Step 2: Execute and record manual runtime verification**

Record these binary observations in `manual-runtime-check.md`:

```markdown
# AC2.4 Manual Runtime Check

- Implementation commit: `<full commit SHA>`
- Combat victory: PASS/FAIL/BLOCKED — final enemy hit shows persistent `Victory`.
- Combat defeat: PASS/FAIL/BLOCKED — final player hit shows persistent `Defeat`.
- Boss victory: PASS/FAIL/BLOCKED — final enemy hit shows persistent `Victory`.
- Boss defeat: PASS/FAIL/BLOCKED — final player hit shows persistent `Defeat`.
- Terminal freeze: PASS/FAIL/BLOCKED — further damage input changes no HP, log, round, queue, or result.
- Historical log inspection: PASS/FAIL/BLOCKED — hover remains presentation-only after completion.
- Exit behavior: PASS/FAIL/BLOCKED — existing debug exit closes the arena without a runtime error.
- Layout: PASS/FAIL/BLOCKED — result remains readable without obscuring formations or battle history.

Overall: PASS/FAIL/BLOCKED
```

- [ ] **Step 3: Migrate the source spec from manual-only to combined verification**

In `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`, locate the existing AC2.4 verification row:

```markdown
| `AC2.4` | Manual runtime check | Complete one battle by defeating all enemies and one battle by losing all player units, verifying the correct win/loss result in each case. |
```

Replace that entire row—not a second duplicate row—with:

```markdown
| `AC2.4` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_4_battle_results.gd` to verify pure outcome evaluation, final-hit victory and defeat, terminal idempotence, reset behavior, and exact persistent result presentation. Then complete Combat and Boss battles in both directions, confirming `Victory` after all enemies fall, `Defeat` after all player units fall, frozen combat mutation after completion, readable persistent presentation, and a working debug exit. |
```

This resolves the plan/spec mismatch. It may be committed with the implementation because it describes the new required verification contract, but it does not mark AC2.4 complete.

- [ ] **Step 4: Mark the source criterion complete only after combined evidence passes**

Confirm all of the following are `PASS`, not `BLOCKED`: the focused automated runner, regression corpus, GodotIQ runtime/visual gates, and all manual Combat/Boss observations. Only then change:

```markdown
- [ ] AC2.4 — Player wins if all enemies defeated; loses if all units defeated
```

to:

```markdown
- [x] AC2.4 — Player wins if all enemies defeated; loses if all units defeated
```

Do not claim AC2.5, AC3.8, or AC4.1 behavior.

- [ ] **Step 5: Record the implementation link**

Write the full tested commit SHA followed by a newline to `implementation-link.txt`:

```text
<full tested commit SHA>
```

All three evidence artifacts must identify the same implementation commit.

- [ ] **Step 6: Self-review spec coverage and placeholders**

Run:

```powershell
rg -n "T(BD)|T(ODO)|implement la[t]er|fill in det[a]ils|appropriate error handl[i]ng|similar to Ta[s]k" Docs/superpowers/plans/2026-07-29-ac2-4-battle-results.md
rg -n "AC2\\.4|BattleOutcome|battle_completed|Victory|Defeat" Docs/superpowers/plans/2026-07-29-ac2-4-battle-results.md Docs/Specs/GAME_DESIGN_SPEC_MVP.md
git diff --check
git status --short
```

Expected: no placeholder hits, no whitespace errors, every AC2.4 behavior maps to an implementation and verification step, and unrelated user files remain unstaged.

- [ ] **Step 7: Commit documentation and evidence**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.4/2026-07-29
git commit -m "docs: record AC2.4 completion evidence"
```

- [ ] **Step 8: Final verification against the committed state**

Rerun the focused runner and inspect:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
git status --short --branch
git log -3 --oneline
```

Expected: focused PASS `(9/9)`, the task branch contains only intentional AC2.4 commits, and unrelated pre-existing workspace changes are not included. Push only when remote handoff or review is requested.

## Completion boundary

AC2.4 is complete only when the same commit has:

1. Focused AC2.4 PASS `(9/9)` with exit `0`.
2. AC2.1, AC2.2, AC2.3, and full-corpus regression PASS.
3. GodotIQ project, parser, signal, runtime, and visual gates recorded as PASS.
4. Manual Combat and Boss victory and defeat observations recorded as PASS.
5. Matching automated, manual, and implementation-link evidence.
6. AC2.4 checked in the source spec.

Any missing, stale, failed, or blocked artifact; unavailable executable; incorrect result; mutable terminal state; unreadable presentation; parser/runtime error; or accidental claim of AC2.5/AC3.8/AC4.1 keeps AC2.4 unchecked. `BLOCKED` is an honest evidence state, never a synonym for `PASS`.
