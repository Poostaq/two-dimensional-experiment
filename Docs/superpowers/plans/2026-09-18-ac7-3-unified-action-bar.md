# AC7.3 Unified Action Bar Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking. Work inline unless the user requests delegation. Use the primary workspace and a dedicated branch; never use a worktree in this repository.

**Goal:** Present the current character's complete skill roster together with compact Default Attack and Default Swap controls in one action bar, preserving preview, targeting, confirmation, cancellation, and active-turn ownership.

**Architecture:** Extract a presentation-only action-bar scene and controller. BattleArena remains the owner of inspected/selected skill identity, the skill transaction, default-action preview, validation, and combat execution. A small arena input adapter coordinates mutually exclusive UI selection; it does not replace either combat transaction or introduce the AC7.5 global visual-state resolver.

**Tech Stack:** Godot 4.7.2, typed GDScript, authored Control scenes, existing SceneTree test runners, GodotIQ editing and runtime verification.

**Status:** Completed inline on `feature/ac7-3-unified-action-bar`, implementation commit `db6de5b`. All five task groups are complete. See [verification and documented plan adjustments](../../Specs/AC7/Evidence/AC7.3/verification.md) for 26 passing automated runners, rendered pointer/keyboard evidence, runtime checks and the measured 1024-pixel constrained-width adjustment. Checklists below remain the original execution instructions. Planning baseline: `66257658bd16b822fc67d106a6ae86a09678d458`, branch `feature/ac7-2-turn-order-ribbon`, clean working tree before this document.

**References:** [MVP acceptance and verification](../../Specs/GAME_DESIGN_SPEC_MVP.md), [approved oracle guidance](../../Mockups/AC7/README.md), [approved visual oracle](../../Mockups/AC7/battle-ui-oracle.html), [broader plan Task 4](2026-09-17-ac7-battle-ui-presentation.md), [AC7.2 evidence](../../Specs/AC7/Evidence/AC7.2/verification.md).

## Scope and implementation choice

Use the approved unified variant: full skill tiles, a separator, two compact icons, and one contextual confirmation area. Use **Swap**, not the illustrative oracle's Move wording. Do not add an A/B selector, new skills, costs, hotkeys, combat rules, debug drawer, or global target-state language. Keep the oracle unchanged.

Three approaches were considered:

1. **Extract one action-bar view and keep arena authority (recommended).** A bounded presentation change with a clear input boundary and reusable scene.
2. Reparent everything inside the arena without a component. Lowest initial migration cost, but adds more UI responsibilities to an already large arena script.
3. Implement the full AC7 snapshot/resolver infrastructure first. Broader reuse, but unnecessarily couples AC7.3 to AC7.4 and AC7.5.

This plan specializes the existing approved design; no new visual-design approval is needed to write or execute its presentation scope.

## Inspected baseline and compatibility constraints

- `Scripts/Battle/battle_arena.gd::_refresh_skill_inspector` renders zero through four skills, including passives; current-turn synchronization includes enemy turns. Keep enemy skill inspection available and keep the action bar anchored to the current actor.
- `_create_skill_button` builds full tiles with `NumberLabel`, `NameLabel`, `KindLabel`, and `skill_id`, `skill_index`, `selected` metadata. Preserve these observable contracts in the authored tile scene.
- `select_skill` updates selection and calls `begin_skill_action` for active skills. It does not clear `_default_action_mode`. `_begin_default_action` resets the skill transaction but does not clear `_selected_skill_id`. This requires explicit coordination at the new UI boundary.
- `_on_slot_gui_input` prioritizes default-action targeting over skill targeting. Leave its authoritative routing order intact; ensure UI transitions never leave both modes pending.
- `_render_skill_transaction` currently renders both action controls and battlefield indicators. Extract only its control rendering; keep its indicator loop in the arena.
- `_render_default_action` supplies availability, selection message, and preview summary. `_confirm_default_action` already handles revision rejection; preserve that behavior and message.
- `_on_skill_button_mouse_entered` renders the detailed tooltip and calls `preview_skill_action`. Preserve the existing transaction guard against hover replacing committed targeting; suppress transaction preview while a default action is selected.
- `_refresh_skill_inspector` currently recreates tiles. The new presenter should retain buttons when actor ID and ordered skill IDs are unchanged so a benign refresh does not destroy keyboard focus.
- Existing tests use arena-owned `%SkillInspector*`, `%SkillAction*`, and `%DefaultAction*` names. Extraction changes unique-name ownership. Migrate affected test lookups to `%BattleActionBar` followed by component-local unique names; do not keep invisible duplicate panels just to satisfy old paths.
- Historical AC7.2 baseline: 25 passing runners, zero script errors, 27 convention warnings and 6 informational findings. Re-measure; these counts are not a waiver for new findings.

## File responsibilities

| File | Change and responsibility |
|---|---|
| `Scenes/UI/battle_action_bar.tscn` | Create authored unified panel, identity block, skill strip, compact actions, contextual confirmation, tooltip/readout |
| `Scenes/UI/battle_skill_button.tscn` | Create authored full tile with existing label names and a readable availability label |
| `Scripts/UI/battle_action_bar.gd` | Create presenter: render detached view data, retain tile identity, emit input intents, manage local tooltip/focus presentation |
| `Scenes/battle_arena.tscn` | Replace separate action panels with one `%BattleActionBar` instance; preserve lanes, ribbon, preparation/reward/debug controls |
| `Scripts/Battle/battle_arena.gd` | Build presentation data, route intents through existing methods, remove extracted control rendering and stale node bindings |
| `Tests/Battle/test_ac7_3_unified_action_bar.gd` | New component, integration, selection, availability, lifecycle and accessibility contracts |
| `Tests/Battle/capture_ac7_3_unified_action_bar.gd` | New rendered pointer/keyboard fixture and viewport evidence |
| `Tests/Battle/test_ac2_6_character_skills.gd` | Update component-local node lookups and authored scene expectations; preserve behavioral assertions |
| `Tests/Battle/test_ac2_7_skill_preview.gd` | Update moved tooltip/control lookups if referenced |
| `Tests/Battle/test_ac2_8_skill_scene.gd` | Update moved action-control lookups if referenced |
| `Tests/Battle/test_ac3_4_default_actions.gd` | Update moved default-action control lookups |
| `Tests/Battle/test_active_turn_skill_lock.gd` | Update moved inspector lookups; preserve both-side ownership and rejected-click identity tests |
| `Tests/Battle/capture_ac7_2_turn_order_ribbon.gd` | Update moved action-control lookups only if needed; preserve rendered ribbon interactions |
| `Docs/Specs/AC7/Evidence/AC7.3/verification.md` and `.gdignore` | Create during implementation: commands, results, screenshots, deviations |
| `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` | Mark AC7.3 only after acceptance evidence passes |

Use GodotIQ dependency and context queries to identify any additional tests with moved node references. Change only their paths; record every such migration in evidence.

## Task 1: Establish branch, baseline, and dependency map

- [ ] Preserve this plan before switching branches. Stash unrelated changes if present and restore them afterward without staging them with AC7.3. Update integration and require completed AC7.2 ancestry:

```powershell
git status --short
git fetch origin
git switch main
git pull --ff-only origin main
git merge-base --is-ancestor 6625765 HEAD
git switch -c feature/ac7-3-unified-action-bar
```

The ancestry command must succeed. If AC7.2 has not reached main, inspect the branch graph and integrate the completed dependency through the repository workflow before creating the feature branch; do not silently start from a pre-ribbon scene. Carry this plan onto the feature branch if necessary.

- [ ] Call `project_summary(detail="brief")`, read relevant `GODOTIQ_RULES.md` sections, and capture `validate(target="project")` and `check_errors(scope="project")` baseline.
- [ ] Run `file_context` for arena, scene, and affected tests; use `dependency_graph`, `signal_map`, and `impact_check` before changing arena signatures, bindings, or scene ownership. Use structured reads for Godot files.
- [ ] Run the baseline suite using the bounded runner in Task 5. Save results separately from final evidence. Investigate existing failures before attributing them to this change.

## Task 2: Write failing unified-bar contracts

- [ ] Create the new SceneTree runner with the existing `_failures`/`_assert`/nonzero-exit pattern, deferred `_run`, and arena cleanup. Start with an executable structural failure:

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as Control
	root.add_child(arena)
	await process_frame
	var bar := arena.get_node_or_null("%BattleActionBar") as Control
	var passed: bool = is_instance_valid(bar)
	if not passed:
		print("FAILED: arena must contain one authored BattleActionBar")
	arena.queue_free()
	await process_frame
	quit(0 if passed else 1)
```

- [ ] Run `validate` and `check_errors` on the test, then execute it. Expected: exit 1 for absent bar, not a parser failure.
- [ ] Extend the runner with the cases below, using current debug fixtures and `BattleUnitState.new` fixtures as in the existing runners. Each assertion must inspect state or rendered controls, not just the presence of a signal connection.

| Case | Required assertion |
|---|---|
| Roster sizes 0–4 | Exactly that many full tiles in original order; Active/Passive labels and skill metadata retained; defaults remain available for a zero-skill player when legal |
| Layout | One visible action-bar panel; Attack and Swap each 44×44 minimum hit targets with smaller glyphs; full tiles retain readable names |
| Selection transitions | Skill → Attack → Swap → Skill leaves only one selected presentation and one targeting flow; confirmation dispatches exactly once to the selected flow |
| Passive inspection | Passive can show details/selection, never starts or confirms a combat action; switching to it clears pending UI action selection |
| Preview preservation | Skill hover/focus leaves locked skill targets intact; hovering a skill during Attack/Swap does not change that default preview |
| Cancel | Clears pending action selection and confirmation; does not change HP, slots, revision, action count or turn |
| Confirmation | Valid Attack, occupied adjacent Swap, free-target and predefined skills match existing effect/turn results; stale revision causes no commit |
| Availability | No adjacent ally disables Swap with a reason; preparation and terminal state prohibit action activation; cooldown/requirements are described from existing evaluation data |
| Ownership | Other-unit clicks cannot change current actor; enemy turn retains existing inspection semantics; default actions remain unavailable on enemy turns |
| Lifecycle | Turn change, actor removal, defeat, preparation, completion and reset clear stale tooltips/confirmation; reused IDs do not retain old selection |
| Focus | Keyboard focus exposes full names/details; benign refresh retains tile instance/focus; removed focus owner moves to a surviving control, never a freed node |

Do not invent resource costs or change enemy skill API behavior. Distinguish an inspectable unavailable skill from an executable action: details may remain reachable while existing rules reject execution.

## Task 3: Author the component and presentation contract

- [ ] Create scenes with GodotIQ scene/node operations, validate ownership, and save. Author this hierarchy with containers rather than fixed screen coordinates:

```text
BattleActionBar (PanelContainer)
  Content (VBoxContainer)
    SkillInspectorPromptLabel
    SkillInspectorBody (HBoxContainer)
      SkillInspectorCharacterBlock (VBoxContainer)
        SkillInspectorUnitNameLabel / SkillInspectorStatusLabel / SkillInspectorCountLabel
      SkillScroll (ScrollContainer)
        SkillInspectorSkills (HBoxContainer; full tile instances)
      DefaultActions (HBoxContainer)
        DefaultAttackButton / DefaultSwapButton
    SkillInspectorEmptyLabel
    ActionConfirmation (HBoxContainer)
      ActionText (VBoxContainer: ActionMessageLabel / ActionSummaryLabel)
      ConfirmButton / CancelButton
    DetailReadout (Label; keyboard-accessible details/reason text)
  SkillTooltipPanel (existing detailed tooltip fields, overlay presentation)
```

Use component-local unique names for referenced controls. Set the root instance unique name to `BattleActionBar` in the arena. Keep full tile `NumberLabel`, `NameLabel`, `KindLabel`; add `AvailabilityLabel` without shrinking existing name text. Use authored icon resources or theme icons, with distinct Attack/Swap silhouettes; do not depend on emoji font support.

- [ ] Define the component's typed public boundary:

```gdscript
class_name BattleActionBar
extends PanelContainer

signal skill_selected(skill_id: StringName)
signal skill_preview_changed(skill_id: StringName)
signal default_attack_requested
signal default_swap_requested
signal confirm_requested
signal cancel_requested

# render(view: Dictionary) -> void consumes the schema below.
# It updates controls only and never emits action intent while rendering.
```

`render(view)` consumes a detached dictionary with these required keys:

| Key | Type and source |
|---|---|
| `actor_id`, `actor_name`, `actor_status` | StringName/String/String, from current inspected unit |
| `skills` | Array[Dictionary], one row per owned skill in order |
| `selected_skill_id` | StringName; empty while a default action is selected |
| `default_mode` | int, existing arena DefaultActionMode |
| `attack_enabled`, `swap_enabled` | bool, existing availability predicates |
| `attack_reason`, `swap_reason` | String, descriptive availability messages |
| `message`, `summary` | String, from active existing transaction/default preview |
| `confirm_visible`, `confirm_enabled`, `cancel_visible`, `cancel_enabled` | bool, derived from the active flow only |

Each skill row contains `skill_id: StringName`, `index: int`, `name: String`, `kind: int`, `selected: bool`, `availability_text: String`, and `tooltip: String`. Compose tooltip text from the existing effect, targeting, requirements, cooldown and optional combo fields. Availability text comes from existing skill evaluation; do not duplicate the rule engine in the component. Passive rows identify themselves as passive and remain inspectable.

- [ ] Move tile/tooltip rendering from the arena into this component. Keep buttons keyed by actor plus ordered skill IDs; update existing tiles on same-roster refresh and recreate only when membership changes. Use `set_pressed_no_signal` for selection styling and retain `selected` metadata. Render selection with a border/marker and text, not color alone.
- [ ] Connect compact buttons and Confirm/Cancel to the declared signals once. Connect tile activation to `skill_selected`; pointer/focus detail entry to `skill_preview_changed`, with empty StringName on final exit. Track hovered and focused tiles independently: pointer detail wins, keyboard detail resumes on pointer exit, late exits cannot clear a newer detail owner.
- [ ] Give compact controls exact accessible names `Default Attack` and `Default Swap`, tooltips including unavailable reasons, visible keyboard focus, and 44×44 hit regions. Keep the detail/readout accessible even when a disabled button cannot receive focus; do not rely solely on disabled-control tooltips.
- [ ] Keep tooltip bounds inside the viewport using the existing clamping approach. Hide stale tooltip on roster/context change. Use horizontal scrolling for the skill strip at constrained width; keyboard focus must scroll its tile into view. Confirm/Cancel and both defaults remain reachable.
- [ ] After each script creation/edit, run its `validate` then `check_errors` before editing another script. Save scenes and verify structure through GodotIQ.

## Task 4: Integrate arena authority and migrate references

- [ ] Replace old scene panels with the single component and update arena onready references. Connect its six signals once in `_ready`. Remove old button signal wiring to prevent double confirmation. Preserve preparation, rewards, debug controls, lane and ribbon layout.
- [ ] Add `_on_action_bar_skill_selected`, `_on_action_bar_preview_changed`, `_on_action_bar_confirm`, `_on_action_bar_cancel`, and `_refresh_action_bar` to the arena. Route default request signals through existing default handlers. Use this coordination order:

```text
Skill activation:
  reject input during preparation/completion/action resolution;
  clear default mode and preview;
  cancel/reset an old pending skill transaction through its existing lifecycle;
  call select_skill(id), preserving passive inspection behavior;
  refresh unified controls.
Attack/Swap activation:
  use existing availability guards;
  clear selected skill ID and tooltip;
  call existing _begin_default_action(mode);
  refresh unified controls.
Confirm:
  if default mode != NONE: call _confirm_default_action();
  otherwise: call confirm_skill_action();
  refresh from actual resulting state, including rejection.
Cancel:
  dispatch to the selected flow's existing cancellation;
  clear UI selected skill identity and tooltip;
  refresh unified controls.
Skill detail hover/focus:
  show details;
  only call preview_skill_action when default mode == NONE;
  preserve the skill transaction's existing state guard;
  clear_skill_preview only when leaving the final detail source.
```

These are UI adapters, not new combat entry points. Keep public `begin_skill_action`, `confirm_skill_action`, default preview/confirm methods, rules, transactions, queue advancement, revision checks and action-log semantics unchanged. Do not broaden this task into combat bug fixes.

- [ ] Implement `_refresh_action_bar` by combining current inspector data, `_skill_transaction.presentation_snapshot()`, and existing default render predicates/messages. Move existing default message strings into arena state rather than reading labels as state. Choose one confirmation source: default mode when active, otherwise the skill snapshot. Do not generate both panels and hide one.
- [ ] Retain battlefield indicator rendering in `_render_skill_transaction`; replace its control writes with a unified-bar refresh. Replace `_render_default_action` control writes likewise. Avoid render recursion: snapshot builders only read, component render only paints, signals only originate from input.
- [ ] Update existing selection/turn/reset refresh boundaries to refresh the component. Preserve `_sync_skill_inspector_to_current_turn` and non-current-click rejection. Ensure direct existing API calls still update the view even when they bypass the new UI adapter.
- [ ] Migrate tests using moved unique names. Example replacement for skill-strip lookup:

```gdscript
var bar := arena.get_node("%BattleActionBar") as Control
var skill_rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
```

Replace two old Confirm/Cancel control expectations with one contextual pair while preserving their enabled/visible assertions for each flow. Keep all effect, targeting, turn-lock, viewport, tile identity and tooltip-content assertions. Record deliberate structural changes; never delete a failing behavior test to obtain a pass.
- [ ] Run new AC7.3 tests and the four MVP-required regressions. Expected: every runner exits zero, without new parser errors, failures or orphaned connections. Commit relevant component, arena and test files after checks pass:

```powershell
git diff --check
git add Scenes/UI/battle_action_bar.tscn Scenes/UI/battle_skill_button.tscn Scripts/UI/battle_action_bar.gd Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac7_3_unified_action_bar.gd
git commit -m "feat(battle-ui): unify skills and default actions"
```

Explicitly stage any reviewed test-path migrations and generated `.uid` files as well before committing; do not use `git add .`.

## Task 5: Regression, rendered input, and acceptance evidence

- [ ] Run all Battle runners and integration smoke regressions with bounded processes. Reuse this command for the Task 1 baseline, omitting the new test until created:

```powershell
@'
from pathlib import Path
import subprocess
exe = r'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
assert Path(exe).is_file(), exe
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
    assert result.returncode == 0, test
    assert 'SCRIPT ERROR' not in output and 'FAILED:' not in output, test
'@ | python -
```

Expected: all runners pass, including AC7.1/7.2, skill previews/targeting, default actions and active-turn locking. Compare deliberate negative-data validation output against baseline.

- [ ] Add the rendered fixture using viewport mouse and keyboard events, following `capture_ac7_2_turn_order_ribbon.gd`. Exercise 1152×648 and 960×648 with four skills; tab through the entire bar and leave it; activate defaults and skills; target, cancel, confirm, and inspect disabled reasons. Include the zero-skill player and an enemy turn. Assert geometry after layout settles; do not infer usability from signal emission alone.
- [ ] Capture: normal unified bar; maximum roster at constrained width; Attack selected with target; Swap selected with ally; skill preview/confirmation; keyboard details and focus; cooldown/unavailable state. Verify no clipped skill names, offscreen tooltip, duplicate panels, hidden defaults or overlapping confirmation. Compare the unified oracle, documenting necessary layout differences without changing it.
- [ ] Run `run(play)` → `verify_project_runs()` → `read_debug_console()` → `state_inspect`. Use `explore(mode="tour")` and targeted inspection for scene QA, describing inspected images and fixing defects before rerunning. Stop with `run(stop)`. Use a single screenshot per verification point, with `delivery="legacy"` if images are not forwarded.
- [ ] Run final project `validate`, `check_errors`, and `signal_map(find="orphans")`. Review the diff to confirm no combat rule, queue, save, transaction, or resolution changes. Run `git diff --check`.
- [ ] Create evidence directory `.gdignore` and `verification.md`; record actual executable/version, branch/commit, commands, results, baseline differences, input cases, inspected screenshots, node-path migrations and limitations. Mark only AC7.3 complete in the MVP spec when every acceptance row below passes. Commit evidence and status update with explicit paths; push only when requested.

## Acceptance traceability

| Requirement | Automated gate | Runtime evidence |
|---|---|---|
| Full skill roster and compact defaults in one bar | AC7.3 roster/hierarchy/geometry contracts; AC2.6 | Four-skill and zero-skill screenshots, no duplicate panels |
| Accessible Attack and Swap | Names, tooltips, focusability, target dimensions, unavailable reasons | Pointer and keyboard detail/focus checks |
| Shared selection | Transition matrix, one contextual Confirm/Cancel source | Skill → Attack → Swap → Skill through real input |
| Existing preview/target/confirm/cancel | AC2.7/AC2.8, AC3.4 and new cross-mode cases | Free/predefined targets, cancel, valid and stale confirmation |
| Turn ownership and lifecycle | Active-turn lock, AC7.3 reset/removal/phase cases | Player/enemy transitions and preparation/completion |
| Prior UI remains usable | AC7.1/AC7.2 and integration runners | Ribbon linkage, readable lanes and constrained-width bar |

**Done means:** AC7.3 has passing automated and inspected rendered evidence; the normal project entry runs without new errors; only relevant changes are committed on the dedicated branch. AC7.4 and AC7.5 remain pending.
