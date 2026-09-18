# AC7.4 Debug Drawer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work inline unless parallel agent work is explicitly requested.

**Goal:** Move battle diagnostics into a collapsed-by-default right-edge overlay drawer without changing player-facing layout when it opens or closes.

**Architecture:** An authored drawer scene owns visibility, focus, diagnostic presentation and command intents. BattleArena retains battle state, log history, preview highlights and debug-command execution, supplying detached display data at existing presentation boundaries. No new combat manager or global visual-state resolver is required.

**Tech Stack:** Godot 4.7.2, typed GDScript, authored Control scenes, GodotIQ, existing SceneTree test runners, PowerShell/Python verification commands.

**Status:** Completed on `feature/ac7-4-debug-drawer`, implementation `57429e0`. See [verification](../../Specs/AC7/Evidence/AC7.4/verification.md) for 27 passing runners, rendered input evidence and adjustments. Checklists below preserve the original execution instructions.

**Dependency provenance:** The verified AC7.3 implementation is `db6de5b` (`feat(battle-ui): implement AC7.3 unified action bar`) on `feature/ac7-3-unified-action-bar`, based on `6625765`, as recorded in [AC7.3 verification](../../Specs/AC7/Evidence/AC7.3/verification.md). Its immediate child, `a847d7b` (`docs(ac7.3): record unified action bar verification`), records the verification and completion documentation; it is not a second implementation commit. The inspected checkout is `a847d7b` on that same branch. The working tree was clean before this plan; this plan is currently the sole untracked change. Task 1 requires updated main to contain both the implementation and its verification record before creating the AC7.4 branch.

**References:** [MVP acceptance and verification](../../Specs/GAME_DESIGN_SPEC_MVP.md), [approved oracle guidance](../../Mockups/AC7/README.md), [approved visual oracle](../../Mockups/AC7/battle-ui-oracle.html), [broader AC7 plan, Task 5](2026-09-17-ac7-battle-ui-presentation.md), [AC7.3 verification](../../Specs/AC7/Evidence/AC7.3/verification.md).

## Scope and decisions

This specializes the existing approved design. Preserve the oracle files. AC7.4 adds Battle Log, Live State, Initiative Queue and Commands sections; AC7.5's global visual-state language remains separate.

Approaches considered:

1. **Extract a drawer presenter and keep arena authority — recommended.** Isolates overlay/input concerns and follows AC7.2/AC7.3 component boundaries.
2. Reparent controls within BattleArena. Smaller initial diff, but leaves focus, visibility and diagnostic rendering in the large arena controller.
3. Introduce the full AC7 snapshot/resolver framework. Unnecessary coupling to AC7.5 and unrelated gameplay presentation.

The implementation must preserve queue construction/order, turn advancement, damage, targeting, transaction validation, rewards, preparation, save state and exit semantics. Opening, closing, scrolling, hovering or refreshing diagnostics cannot mutate battle state. Only an explicit enabled debug-command activation may invoke an existing command.

**Command discrepancy resolved:** `_on_advance_debug_pressed()` invokes `perform_debug_damage()`, which deals fixed 7 damage and advances once when battle continues. The current arena has this command and Exit, not a separate advance-only UI command. Move those two controls; label the damage command accurately, retaining its existing `AdvanceTurnDebugButton` node name for compatibility. Do not wire the illustrative oracle's separate Advance button or add a new command. Seed and pending-event values in the mockup are illustrative; omit fields without a real authoritative source.

**Viewport contract:** Verify 1152×648 and the established constrained width 1024×648. AC7.3 evidence documents formation minima that prevent a claim of support at 960 pixels. The closed layout can use space released by removing the old diagnostic rows; open and closed states of the resulting layout must have identical player-facing geometry.

## Inspected baseline and migration risks

- `Scenes/battle_arena.tscn` has 66 nodes and no drawer instance. The arena owns `%AdvanceTurnDebugButton`, `%ExitBattleDebugButton`, `%BattleLogScroll` and `%BattleLogEntries`.
- `_ready()` connects the two debug buttons once; retain exactly one route after extraction. `_on_exit_debug_pressed()` performs existing cleanup and defers `exit_requested`; do not substitute a direct signal emission.
- `_refresh_turn_ui()` updates command availability but returns early for completion and absent actors. A drawer refresh must also run on those paths and reflect preparation locking.
- `_append_log_control()` creates message/damage rows, connects damage-row hover to `preview_log_entry(index)`/`clear_log_entry_preview()`, and scrolls after a frame. Preserve message text, damage text, event ordering and newest-entry scrolling.
- `_clear_log_controls()` currently queues children for deletion. Extraction needs protection against deferred scroll work from an old battle updating the next battle's UI.
- `configure_units()` clears history, hover state, transactions and feedback generations. It must additionally collapse/reset the drawer without restoring focus to stale battle controls.
- `_render_default_action()`, `_render_skill_transaction()` and `_refresh_action_bar()` cover selection changes that do not advance a turn. Live diagnostics must refresh on those paths too.
- `get_turn_queue()` duplicates the array but shares unit objects. Serialize primitive display fields; do not pass mutable BattleUnitState objects to the drawer or sort the authoritative queue.
- Confirmed direct consumers of moved controls are `Tests/Battle/test_ac2_2_speed_order.gd` (two `%AdvanceTurnDebugButton` lookups), `Tests/Battle/test_ac2_3_damage_defeat_log.gd` (`%AdvanceTurnDebugButton`), `Tests/Battle/test_ac2_8_skill_lifecycle.gd` (`%ExitBattleDebugButton` activation), and `Tests/WorldMap/test_world_battle_entry.gd` (`%AdvanceTurnDebugButton` availability). Component extraction changes unique-name ownership; migrate all four consumers, preserving every behavioral assertion. The speed-order runner is one file with two affected lookups.
- Prior evidence reports 26 passing runners, zero script errors, 27 convention warnings and 6 informational findings. Re-measure these; historical findings are not permission to introduce new ones.

## File responsibilities

| File | Responsibility |
|---|---|
| Create `Scenes/UI/battle_debug_drawer.tscn` | Right-edge handle, hidden panel, close button, scrolling state/queue/log sections and existing commands |
| Create `Scripts/UI/battle_debug_drawer.gd` | Local open/focus state, detached view rendering, stable log rows, generation-safe scrolling, input intents |
| Modify `Scenes/battle_arena.tscn` | Instance `%BattleDebugDrawer` outside layout containers; remove old log/command rows and stale bindings |
| Modify `Scripts/Battle/battle_arena.gd` | Build diagnostic display data, refresh presentation, forward commands/log preview and reset drawer |
| Create `Tests/Battle/test_ac7_4_debug_drawer.gd` | Structural, geometry, data, command, focus, lifecycle and mutation contracts |
| Create `Tests/Battle/capture_ac7_4_debug_drawer.gd` | Real pointer/keyboard interactions and rendered evidence at both supported widths |
| Modify `Tests/Battle/test_ac2_3_damage_defeat_log.gd` | Migrate moved-control lookup; retain all damage/log semantics |
| Modify `Tests/Battle/test_ac2_2_speed_order.gd` | Migrate both moved damage-command lookups; retain speed-order and command assertions |
| Modify `Tests/Battle/test_ac2_8_skill_lifecycle.gd` | Migrate Exit lookup and open the drawer before command activation; retain cleanup and exit assertions |
| Modify `Tests/WorldMap/test_world_battle_entry.gd` | Migrate damage-command availability lookup; retain world-to-battle entry assertions |
| Inspect `Tests/Battle/test_ac2_4_battle_results.gd` and existing AC7 test/capture runners | Migrate moved debug/log paths only if present; preserve outcome and geometry assertions |
| Create `Docs/Specs/AC7/Evidence/AC7.4/verification.md` and `.gdignore` | Actual results, logs, screenshots, migration list and limitations |
| Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` | Mark AC7.4 complete only after all required evidence passes |

Discover additional affected consumers through GodotIQ dependency/context queries. Track each path migration in evidence. Include generated `.uid` files for new scripts. No changes are planned to combat-rule, transaction, save, queue or log-model modules.

## Task 1: Establish implementation branch and baseline

- [ ] Preserve this plan before switching branches. Stash unrelated local edits and restore them afterward without staging them with AC7.4. Use the primary workspace; repository instructions prohibit worktrees.
- [ ] Update main and verify completed AC7.3 ancestry before creating the implementation branch:

```powershell
git status --short
git fetch origin
git switch main
git pull --ff-only origin main
git merge-base --is-ancestor db6de5b HEAD
if ($LASTEXITCODE -ne 0) { throw 'Updated main must contain verified AC7.3 implementation db6de5b.' }
git merge-base --is-ancestor a847d7b HEAD
if ($LASTEXITCODE -ne 0) { throw 'Updated main must contain AC7.3 verification documentation a847d7b.' }
```

Both ancestry commands must exit zero: `db6de5b` establishes the implementation dependency and `a847d7b` establishes the accompanying verified completion record. If either fails, inspect the branch graph and integrate the completed AC7.3 dependency through the repository workflow before proceeding. Do not silently implement against a pre-action-bar scene or omit its verification record. The explicit PowerShell guards prevent continuing to branch creation after a failed ancestry check.

```powershell
git switch -c feature/ac7-4-debug-drawer
```

- [ ] Call `project_summary(detail="brief")`, read relevant `GODOTIQ_RULES.md` sections, then record project `validate` and `check_errors` baseline.
- [ ] Call `file_context` for every file before editing; use `impact_check` before ownership/signature/signal changes and `dependency_graph`/scoped `signal_map` for affected consumers. Use GodotIQ reads/writes for Godot files.
- [ ] Run the baseline suite from Task 6. Save baseline logs separately from final logs. Each script edit thereafter requires its own `validate(target=file)` then `check_errors(scope=file)` cycle before editing the next script.

## Task 2: Add failing drawer contracts

**File:** `Tests/Battle/test_ac7_4_debug_drawer.gd`.

- [ ] Start with an executable missing-component test, using the existing deferred SceneTree runner convention:

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as Control
	root.add_child(arena)
	await process_frame
	var drawer := arena.get_node_or_null("%BattleDebugDrawer") as Control
	var passed: bool = is_instance_valid(drawer)
	if not passed:
		print("FAILED: arena must contain an authored BattleDebugDrawer")
	arena.queue_free()
	await process_frame
	quit(0 if passed else 1)
```

- [ ] Run the focused runner before implementation:

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/Battle/test_ac7_4_debug_drawer.gd
```

Expected initial result: nonzero exit and the missing-drawer assertion, not a parser failure.

- [ ] Expand the runner with the repository's `_failures`/`_assert` reporting pattern. Add each contract before its implementation: default collapse; handle toggle; stable formation/ribbon/bar rectangles; fresh live data; chronological log rendering; exact command routing; focus return; closed-input exclusion; reset cleanup. Use the acceptance matrix below for exact fixtures and expected results.

The geometry assertion must compare actual global rectangles before open, after two layout frames, and after close. Include both formations, all twelve slots, `%TurnOrderRibbon`, `%BattleActionBar` and the preparation/result UI when visible. Tolerance: at most one pixel in position or size. Do not accept a test that merely checks the drawer's parent type.

## Task 3: Author overlay and local input lifecycle

**Files:** new drawer scene/script; arena scene instance.

- [ ] Build this authored hierarchy using GodotIQ scene operations, save once per grouped scene edit, then inspect the saved structure:

```text
BattleDebugDrawer (Control; full rect; mouse_filter IGNORE)
  DebugHandle (Button; right-edge anchored; always present)
  DrawerPanel (PanelContainer; right-edge anchored; initially hidden; STOP)
    DrawerContents (VBoxContainer)
      Header (HBoxContainer)
        Title (Label)
        CloseButton (Button)
      DiagnosticsScroll (ScrollContainer; vertical expand)
        Diagnostics (VBoxContainer)
          LiveState (Label; wrapped)
          InitiativeQueue (Label; wrapped)
          BattleLogScroll (ScrollContainer; bounded height)
            BattleLogEntries (VBoxContainer)
      Commands (VBoxContainer)
        AdvanceTurnDebugButton (Button; "Damage closest enemy")
        ExitBattleDebugButton (Button; "Exit battle")
```

The root instance is a sibling of the player layout, never a child of its VBox/HBox containers. Anchor the drawer to the right edge using the oracle's 354-pixel panel width as a starting design value; cap width to leave the handle reachable. Do not add drawer minimum width to the player's layout. Put Commands outside the diagnostic scrolling area so they remain reachable at 648 pixels high. Verify nested wheel scrolling and clipping during rendered QA.

- [ ] Define this presentation-only API and signal contract:

```gdscript
signal damage_requested
signal exit_requested
signal log_preview_changed(entry_index: int)
signal opened_changed(opened: bool)

func is_open() -> bool:
	return %DrawerPanel.visible
```

Implement `set_open(opened: bool, restore_focus: bool = true) -> void`, `reset_view() -> void`, `render(view: Dictionary) -> void`, `append_log_row(row: Dictionary) -> void` and `clear_log_rows() -> void` in this controller. All are new component APIs; none may access BattleArena directly.

- [ ] On open, remember the viewport's focused Control, show the panel, update handle tooltip/accessibility text and move focus to Close. On close, clear local row-preview ownership and emit `log_preview_changed(-1)`, hide the panel, then restore the saved control only if it remains valid, visible, focusable and enabled; otherwise focus the handle. Reset hides without restoring old focus. Repeated calls with unchanged visibility do not emit duplicate transitions.
- [ ] Use actual hidden visibility for the panel, not alpha-only hiding. Hidden descendants must not receive Tab, Enter, Space, mouse clicks or wheel events. Root ignores input outside the handle/panel; panel blocks click-through onto covered units. Explicit focus neighbors cycle through visible drawer controls while open; handle is the sole drawer Tab stop while closed. Escape closes the open drawer and consumes that event before action cancellation; Escape while closed retains existing behavior. Do not add a global debug hotkey.
- [ ] Connect buttons once to the corresponding intent. Label and describe both commands accessibly. A guarded handler emits no intent when closed or disabled, even if a test manually emits the button signal.
- [ ] Maintain overlay order deliberately: drawer covers ordinary battle content, but must not bypass preparation/reward/recruitment modal input ownership. Collapse when a blocking modal activates and keep its handle unavailable behind that modal; restore reachability when the modal ends. Keep existing terminal/debug-exit behavior reachable where current modal rules permit it. Verify actual input and tooltip stacking rather than relying only on z-index.

Opening and closing preserves selected skill/default action, locked targets, battle revision, HP, queue and round. Only presentation hover/detail state may clear when focus moves. This is local drawer cleanup, not AC7.5 visual-state redesign.

## Task 4: Extract diagnostics and preserve command/log behavior

**Files:** drawer script, `Scripts/Battle/battle_arena.gd`, arena scene, `Tests/Battle/test_ac2_2_speed_order.gd`, `Tests/Battle/test_ac2_3_damage_defeat_log.gd`, `Tests/Battle/test_ac2_8_skill_lifecycle.gd`, and `Tests/WorldMap/test_world_battle_entry.gd`.

- [ ] Add arena `_debug_drawer` binding to `%BattleDebugDrawer`; replace old arena-owned control bindings. Connect component intents once:

```gdscript
_debug_drawer.damage_requested.connect(_on_advance_debug_pressed)
_debug_drawer.exit_requested.connect(_on_exit_debug_pressed)
_debug_drawer.log_preview_changed.connect(_on_debug_log_preview_changed)
```

New arena adapter:

```gdscript
func _on_debug_log_preview_changed(entry_index: int) -> void:
	if entry_index < 0:
		clear_log_entry_preview()
	else:
		preview_log_entry(entry_index)
```

- [ ] Introduce `_build_debug_view() -> Dictionary` and `_refresh_debug_drawer() -> void` in BattleArena. Supply primitive values only, with this schema:

```text
phase: String                  Preparation / Complete / Resolving / Player turn / Enemy turn / No active units
round: int                     round_number
actor_id: StringName            current actor ID, empty if absent
actor_name: String             current actor display name, "None" if absent
outcome: String                existing BattleOutcome display text
revision: int                  _battle_revision
selected_action: String        Default Attack / Default Swap / selected skill name / None
target_summary: String         existing default preview or skill transaction summary
transaction_state: String      existing BattleSkillTransaction.State name
queue_rows: Array[Dictionary]  index, unit_id, display_name, effective_speed, active, current
damage_enabled: bool          existing command legality, including preparation and in-progress guards
exit_enabled: bool             existing exit availability
```

Phase is a derived diagnostic label, not a new authoritative state machine. Resolve completion/preparation before actor-side labels. Selection uses existing `_default_action_mode`, `_selected_skill_id` and transaction/default presentation data; never evaluate a new action or modify a transaction merely to display diagnostics. Include IDs to disambiguate equal display names.

Queue rows serialize `get_turn_queue()` in its existing order, with current actor marked explicitly. Do not reconstruct a future schedule, re-sort by speed or mutate the queue. If a stale inactive row exists in authoritative state, label it inactive; the diagnostic view should reveal that state rather than silently repairing it.

- [ ] Refresh diagnostics at the end of turn/UI updates, including both early-return branches, after selection/target/default presentation updates, after authoritative state notifications, preparation changes and completion. Coalesce to one deferred refresh if needed, without a per-frame polling loop. The drawer must be fresh within one idle frame and synchronously refreshed when opened. Prevent recursive calls between drawer render and arena refresh.
- [ ] Preserve `_append_log_control(entry, index)` as the existing arena insertion boundary; move row-node creation into the drawer. Build a detached row once at insertion using existing formatting. Its schema is `{index: int, sequence: int, text: String, previewable: bool}`. MESSAGE rows retain exact text and do not emit participant previews. DAMAGE rows retain round, names, applied damage, HP and defeated marker; freeze display text so later removal does not erase history. Keep index tied to authoritative history, not visible row count.
- [ ] Continue appending diagnostics while closed. Reopening must show every entry exactly once and scroll to the newest row after layout. Do not rebuild existing rows during a live-state/queue refresh; preserve row identity and focus. `clear_log_rows()` removes rows from the container immediately before queue-freeing them and increments a generation counter. Deferred scrolling checks that generation and tree validity after waiting a frame, preventing old-battle updates.
- [ ] Hovering a damage row forwards its original history index. Closing, pointer exit, reset and row removal clear only that preview; stale exits from an older row cannot clear a newer row's preview. Preserve existing green-attacker/red-receiver feedback and transient feedback timing.
- [ ] In `configure_units()`, reset the drawer and cancel deferred view/log work before repopulation; readiness guards must preserve pre-ready configuration behavior. Reused IDs cannot retain old labels, queue rows, log entries or focus references. On arena exit, no pending callback should touch freed Controls.
- [ ] Remove the old always-visible log/command containers. Migrate test lookup scope using the component, for example:

```gdscript
var drawer := arena.get_node("%BattleDebugDrawer") as Control
var button := drawer.get_node("%AdvanceTurnDebugButton") as Button
```

Keep existing command methods and combat logic unchanged. No invisible duplicate controls or compatibility panels.

- [ ] Explicitly migrate both damage-button lookups in `Tests/Battle/test_ac2_2_speed_order.gd`, the damage-button lookup in `Tests/Battle/test_ac2_3_damage_defeat_log.gd`, the Exit lookup in `Tests/Battle/test_ac2_8_skill_lifecycle.gd`, and the damage-button availability lookup in `Tests/WorldMap/test_world_battle_entry.gd`. Each lookup resolves through `%BattleDebugDrawer`. Where a runner activates a command, first call `drawer.set_open(true)` and allow a layout frame; in particular, the lifecycle test must open before emitting Exit's `pressed` signal. Retain existing speed-order, damage, lifecycle cleanup, exit and world-entry assertions; do not bypass the new closed-command guard to keep old fixtures passing. Availability-only assertions can inspect the closed drawer's button state.

## Task 5: Verify behavior and rendered input

**Files:** both new AC7.4 runners; `Tests/Battle/test_ac2_2_speed_order.gd`, `Tests/Battle/test_ac2_3_damage_defeat_log.gd`, `Tests/Battle/test_ac2_8_skill_lifecycle.gd`, and `Tests/WorldMap/test_world_battle_entry.gd`.

- [ ] Exercise these automated cases with real fixture units and before/after battle snapshots:

| Contract | Fixture and expected result |
|---|---|
| Default state | Fresh arena: panel hidden, handle visible, no hidden descendant in focus traversal |
| Toggle and geometry | Repeated handle/Close/Escape cycles: twelve slots, lanes, ribbon and action bar retain global rectangles at both widths |
| Read-only UI | Open/render/scroll/close repeatedly: HP, round, actor, queue IDs, revision, log count, transaction and selected target unchanged |
| Live state | Select skill, target, Attack and Swap; cancel; advance normally; preparation, completion and empty queue: displayed fields match current arena state within a frame |
| Queue | Twelve units, speed ties, duplicate names, defeat/removal and rollover: correct authoritative order/IDs/current marker without queue mutation |
| Hidden updates | Execute actions while drawer closed, reopen: latest state and all log rows, no duplicates, newest entry visible |
| Existing damage command | Deterministic two-side fixture: one click causes one 7-damage action, one entry, one turn advance; final hit preserves terminal semantics |
| Command guards | Preparation, completion, no target and action-in-progress: damage disabled and activation mutates nothing; closed commands cannot activate |
| Existing exit command | One activation runs existing cleanup and emits exit once after its deferred boundary |
| Log preview | Damage hover preserves participant feedback; MESSAGE rows have no preview; exit/close/reset clears hovered history; delayed older exits do not clear newer previews |
| Focus | Open moves focus inside; Close/Escape restores valid focus; freed/disabled original target falls back to handle; closed panel is absent from Tab traversal |
| Reset race | Append then reset before scroll await resumes, reusing IDs: collapsed empty history, Round 1, no stale scroll/highlight/focus callback |
| Modal boundaries | Preparation/reward/recruitment input remains authoritative; drawer cannot click through or steal focus from blocking UI |

- [ ] In the capture fixture, send viewport mouse motion/button events and key events instead of testing only emitted signals. Click handle, damage row, Close and damage command; traverse with Tab/Shift-Tab, activate with Enter/Space and close with Escape. Test a selected action before opening and verify Escape closes only the drawer. Test clicking a drawer-covered unit does not select it, then clicking that unit after close behaves normally.
- [ ] Capture collapsed, expanded, scrolled-history and focus-visible states at 1152×648 and 1024×648. Inspect every screenshot for clipped text, commands, handle reachability, opaque panel background, tooltip overlap and unchanged underlying geometry. Use the approved oracle as the visual reference; do not change the oracle to match an implementation defect.
- [ ] Run AC7.4 and all four confirmed direct consumers as the focused migration gate before the full Task 6 suite:

```powershell
$ac74Godot = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$ac74FocusedTests = @(
    'res://Tests/Battle/test_ac7_4_debug_drawer.gd'
    'res://Tests/Battle/test_ac2_2_speed_order.gd'
    'res://Tests/Battle/test_ac2_3_damage_defeat_log.gd'
    'res://Tests/Battle/test_ac2_8_skill_lifecycle.gd'
    'res://Tests/WorldMap/test_world_battle_entry.gd'
)
foreach ($ac74Test in $ac74FocusedTests) {
    & $ac74Godot --headless --path . --script $ac74Test
    if ($LASTEXITCODE -ne 0) { throw "AC7.4 migration regression failed: $ac74Test" }
}
```

Expected: all five runners exit zero, no failed assertions/parser errors, and unchanged authoritative command behavior. Record each runner's result separately in evidence. Task 6's full Battle glob includes speed-order, damage/log and lifecycle; its explicit WorldMap entry covers the fourth consumer. Commit component, integration and tests with explicit relevant paths after verification; use `feat(battle-ui): add AC7.4 overlay debug drawer`.

## Task 6: Final regression gate and evidence

- [ ] Use a bounded runner from the repository root; the executable is the measured AC7.3 path. Verify it exists/version before execution, and record any actual replacement path.

```powershell
@'
from pathlib import Path
import subprocess
exe = r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
tests = sorted(Path('Tests/Battle').glob('test_*.gd')) + [
    Path('Tests/Run/test_ac3_3_party_formation.gd'),
    Path('Tests/WorldMap/test_world_battle_entry.gd'),
    Path('Tests/UI/test_ac6_6_preparation_ui.gd'),
]
for test in tests:
    result = subprocess.run([exe, '--headless', '--path', '.', '--script',
                             'res://' + test.as_posix()],
                            capture_output=True, text=True, timeout=60)
    output = result.stdout + result.stderr
    print(test, result.returncode)
    print(output)
    assert result.returncode == 0
    assert 'SCRIPT ERROR' not in output and 'FAILED:' not in output
'@ | python -
```

Expected: all Battle runners plus the three integration runners pass (27 total if AC7.4 is the only new test runner). Preserve intentional negative-data checks; compare their output to baseline instead of weakening assertions.

- [ ] Run the rendered capture fixture with a 60-second subprocess timeout:

```powershell
@'
import subprocess
exe = r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
result = subprocess.run([exe, '--path', '.', '--rendering-method', 'gl_compatibility',
                         '--script', 'res://Tests/Battle/capture_ac7_4_debug_drawer.gd'],
                        capture_output=True, text=True, timeout=60)
output = result.stdout + result.stderr
print(output)
assert result.returncode == 0
assert 'SCRIPT ERROR' not in output and 'FAILED:' not in output
'@ | python -
```

- [ ] Run GodotIQ project `validate`, project `check_errors`, and `signal_map(find="orphans")`; compare with baseline and resolve newly introduced findings. Launch the production entry with `run(action="play")`, call `verify_project_runs()`, inspect `read_debug_console()` and relevant `state_inspect` values. After scene work use `explore(mode="tour")`; describe each captured view, fix issues and repeat affected checks. Stop the game after verification.
- [ ] Review the final diff for combat changes, duplicated connections, hidden duplicate UI, altered oracle files and out-of-scope AC7.5 behavior. Run `git diff --check` and verify only relevant files are staged.
- [ ] Create evidence `.gdignore` and `verification.md`. Record branch/implementation commit, actual Godot version/path, baseline and final results, exact commands, real-input cases, screenshots, node-path migrations, command/mockup discrepancy and any limitations. Map each matrix row to evidence. Mark only AC7.4 complete after all required rows pass; leave AC7.5 pending.
- [ ] Commit evidence/spec updates with explicit file paths using `docs(ac7.4): record debug drawer verification`. Push only when requested.

**Done means:** The drawer is collapsed by default, opens without reflow, displays live diagnostics and existing commands, preserves combat/log semantics, restores usable input after close/reset, passes automated and inspected rendered checks, and is committed on the dedicated implementation branch with evidence.
