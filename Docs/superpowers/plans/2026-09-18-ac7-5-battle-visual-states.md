# AC7.5 Battle Visual States Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Use `superpowers:test-driven-development` for behavior changes. Steps use checkbox syntax for tracking.

**Goal:** Give every battle interaction a deterministic, accessible visual treatment, preserving authoritative action selection and clearing stale presentation at every lifecycle boundary.

**Architecture:** Keep BattleArena, BattleSkillRules and the existing transactions authoritative. Add a pure typed `BattleVisualState` resolver, feed it detached presentation inputs from the arena, and render independent layers in BattleUnitView. Reuse BattleActionBar's pointer/focus arbitration and existing targeting/confirmation APIs; do not create a second combat rules engine.

**Tech Stack:** Godot 4, typed GDScript, authored Control scenes, SceneTree regression runners, GodotIQ script/scene operations and runtime verification.

**Status:** Implemented and verified on 2026-09-18. Implementation `4625596` on `feature/ac7-5-battle-visual-states`, after verified AC7.4 (`57429e0`, `8e3410b`) was integrated into local main. See [canonical verification](../../Specs/AC7/Evidence/AC7.5/verification.md) for actual results, screenshots and implementation decisions. The checklist below is retained as the original detailed execution proposal; the completed delivery ledger supersedes its proposed intermediate commit structure.

**Delivery ledger:**

- [x] Task 1: dependency integration, dedicated branch, baseline and failing cases.
- [x] Task 2: deterministic resolver (`Request` replaces native-conflicting `Input`).
- [x] Task 3: detached legality/availability including zero-target and staged cases.
- [x] Task 4: layered views, focusable explanations and non-color markers.
- [x] Task 5: input arbitration and cleanup, preserving combat ownership.
- [x] Task 6: 28 passing runners, rendered input and 24 inspected captures, review and evidence.

The original inspection anchors below describe the pre-implementation checkout.

**References:** [MVP acceptance and verification](../../Specs/GAME_DESIGN_SPEC_MVP.md), [approved broader AC7 design, Task 6](2026-09-17-ac7-battle-ui-presentation.md), [oracle preservation guidance](../../Mockups/AC7/README.md), [AC7.3 evidence](../../Specs/AC7/Evidence/AC7.3/verification.md), [AC7.4 plan](2026-09-18-ac7-4-debug-drawer.md).

---

## Scope and approach

This specializes the approved AC7 visual-state design. Preserve the oracle HTML and combat semantics: damage, cooldowns, costs, turn ordering, formation legality, target validation, confirmation atomicity, save data and rewards. Default Swap continues to require an adjacent active ally; it does not become movement into an empty slot.

Three approaches were considered:

1. **Pure resolver plus existing arena adapters — recommended.** Centralizes precedence while retaining existing transaction and component ownership.
2. Continue adding flags to independent highlight functions. Smaller initial diff, but retains order-dependent overwrites and scattered cleanup.
3. Introduce a general UI state machine and global snapshot framework. Broader than AC7.5 and duplicates the existing transaction lifecycle.

Execute after AC7.4 has verified completion and is integrated into main. The resolver can be designed independently, but final arena integration and drawer focus/log regression checks must use the actual completed drawer. Re-read changed arena/component APIs then; the source anchors below describe AC7.3, not an assumed AC7.4 implementation.

## Inspected baseline and integration anchors

| File / existing API | Relevant behavior and required change |
|---|---|
| `Scripts/Battle/battle_arena.gd`: `_on_action_bar_preview_changed`, `preview_skill_action`, `clear_skill_preview` | Hover currently uses transaction PREVIEWING; preserve public preview API contracts, but route the new bar battlefield preview through detached evaluation so observation cannot reset or overwrite selected actions. |
| Same: `_render_skill_transaction` | Writes `TargetIndicatorOverlay` directly from `indicator_roles`. Replace styling with one resolver/render pass; preserve snapshot and role metadata contracts where still valid. |
| Same: `_refresh_highlights`, `_reset_slot_highlights`, `_apply_current_slot_highlight` | Log feedback currently returns before current-actor rendering. Compose log feedback with the actor layer so it cannot erase current/selected states. Preserve log attacker/receiver and damage-feedback semantics. |
| Same: `_apply_turn_order_preview` | Separate ribbon overlay writer. Make this request a common refresh; resolve stable IDs to current slots each time. |
| Same: `_refresh_action_bar` | Evaluates each skill already, but rows carry only reason text and selected status. Add explicit activation and no-target fields derived from existing authoritative evaluations. |
| Same: `preview_default_attack`, `preview_formation_move` | Read-only dictionaries supply legal default-action candidates. Enumerate units through these APIs, with `default_swap=true`, rather than duplicating adjacency or attack rules. |
| Same: `_on_slot_gui_input`, `_on_slot_mouse_entered`, `_on_slot_mouse_exited` | Mouse-only slot dispatch. Add matching keyboard focus/activation through the same intent path and guard stale exits by source identity. |
| `Scripts/UI/battle_action_bar.gd`: `_refresh_details`, `clear_details`, `_select_skill` | Pointer wins over keyboard focus; same-roster refresh retains controls. `clear_details` currently clears local IDs without emitting preview end. Explicitly clear arena presentation during lifecycle cleanup and emit end for ordinary detail dismissal. |
| `Scripts/UI/battle_unit_view.gd` | Identity/HP/status presentation and a ribbon-preview setter exist. Add one layered visual render method; do not mix targeting decisions into `render_unit`. |
| `Scripts/Battle/battle_skill_rules.gd` | `evaluate_targets` returns valid/affected IDs, minimum/maximum counts and blocking reason. FREE actions can report `can_start=true` with no candidates. Authored profiles can permit zero explicit targets. Empty candidate arrays alone are not an availability rule. |
| `Scripts/Battle/skill_action_reason.gd` | Existing codes include turn, inactive actor, passive, battle complete, position/health requirements, cooldowns and target invalidation. No generic resource-cost code exists; do not invent a resource mechanic for the UI. |

## File ownership

| File | Responsibility |
|---|---|
| Create `Scripts/UI/battle_visual_state.gd` | Pure typed inputs/result and deterministic layer resolver; no Nodes or combat rule calculations. |
| Modify `Scripts/UI/battle_unit_view.gd` and `Scenes/UI/battle_unit_view.tscn` | Render actor, spotlight, target, selected and unavailable channels. Preserve identity, HP, statuses, log/effect feedback. |
| Modify `Scripts/UI/battle_action_bar.gd`, `Scenes/UI/battle_action_bar.tscn`, `Scenes/UI/battle_skill_button.tscn` | Focusable unavailable controls, prohibition/no-target badges, reasons and preview intent. |
| Modify `Scripts/Battle/battle_arena.gd` | Read-only adapter, one refresh entry point, pointer/keyboard intent, existing lifecycle integration. |
| Create `Tests/Battle/test_ac7_5_battle_visual_states.gd` | Resolver matrix, arena integration, input arbitration, atomicity and lifecycle assertions. |
| Create `Tests/Battle/capture_ac7_5_battle_visual_states.gd` | Reproducible rendered state fixture and bounded screenshot capture. |
| Inspect existing `Tests/Battle/test_ac7_1_living_lanes.gd`, `test_ac7_2_turn_order_ribbon.gd`, `test_ac7_3_unified_action_bar.gd` and completed AC7.4 runner | Adjust only intentionally changed presentation assertions; retain behavior coverage. |
| Create `Docs/Specs/AC7/Evidence/AC7.5/verification.md` and `.gdignore` | Actual commands, results, inspected screenshots and limitations. |
| Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` | Mark AC7.5 complete only after automated and rendered gates pass. |

No new autoload, queue owner or generic snapshot framework is required. Check generated `.gd.uid` files into the same commits as their scripts. Arena scene changes are unnecessary unless completed AC7.4 exposes an integration need; document any addition before expanding scope.

## Visual contract

| Channel | Treatment | Precedence / non-color meaning |
|---|---|---|
| Actor frame | Persistent outer frame with `NOW` | Independent of target/selection/preview and diagnostic feedback; suppressed outside active battle or for an inactive unit. |
| Interaction spotlight | Soft outline/spotlight with `PREVIEW` | Ribbon entry preview remains observational even during targeting. Unselected skill preview is allowed only without a committed action. |
| Target border and glyph | Inner border with `SKILL`, `ATTACK` or `SWAP` identity | Hover-only skill targets use a weaker preview treatment. Attack sword and Swap opposing arrows have readable labels/descriptions. |
| Selection marker | Reticle/check with `SELECTED` | Replaces the weaker valid-target inner treatment while retaining action identity and actor frame. Means selected for confirmation, not an already executed action. |
| Invalid / unavailable | Prohibition shape plus reason, defeated identity retained | Defeated/removed/untargetable units suppress all actionable borders, glyphs and selected markers. Wrong-side/out-of-range is relative to the active action, not a permanent unit status. |
| Action availability | `NO TARGET` for no legal completion; prohibition and reason for other blockers | Focusable for explanation but cannot activate. Passive skills remain inspectable and retain their existing non-actionable selection contract. |
| Legacy feedback | Existing damage text, attacker/receiver tint, effect feedback | Render alongside the semantic channels; never erase actor, target or selected markers. |

If a selected action exists, hovering/focusing another action changes tooltip/details only. A rejected/unavailable inspection selection also must not resurrect another action's hover targets. An empty slot has no unit-target affordance. Legal zero-explicit-target/self-effect actions remain activatable and are not labeled `NO TARGET`.

## Task 1: Integration baseline and failing acceptance cases

**Files:** new AC7.5 test runner; inspect completed AC7.4 evidence and relevant arena APIs.

- [ ] Preserve this plan and the existing AC7.4 plan. Stash unrelated local work when needed; do not stage it with AC7.5. Use the primary workspace; worktrees are prohibited.
- [ ] Update main with guarded commands before starting implementation:

```powershell
git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Fetch failed.' }
git switch main
if ($LASTEXITCODE -ne 0) { throw 'Switch to main failed.' }
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) { throw 'Main update failed.' }
git merge-base --is-ancestor a847d7b HEAD
if ($LASTEXITCODE -ne 0) { throw 'Main lacks verified AC7.3 ancestry.' }
if (-not (Test-Path 'Docs/Specs/AC7/Evidence/AC7.4/verification.md')) {
    throw 'Complete and integrate verified AC7.4 before AC7.5 integration.'
}
```

- [ ] Read AC7.4 verification, confirm its implementation and documentation commits are ancestors of updated main with `git merge-base --is-ancestor`, and record their actual hashes. A file's existence alone is not proof of completed verification. Resolve missing dependency integration through the repository workflow before continuing; do not substitute the AC7.4 planning file for evidence.
- [ ] Create `feature/ac7-5-battle-visual-states` with `git switch -c feature/ac7-5-battle-visual-states` only after those gates pass. Restore relevant planning inputs; retain unrelated stashed work for restoration without staging it.
- [ ] Run GodotIQ project `validate`/`check_errors` baseline and the Task 6 automated suite. Record existing diagnostics. Use `file_context(detail="brief")` before every edit and `impact_check` before API/signal changes. After each individual script edit run `validate(target=file, detail="brief")` then `check_errors(scope=file)` before editing the next script. Use GodotIQ writes and scene operations, save scenes and inspect them.
- [ ] Add the SceneTree AC7.5 runner using the established `_failures`, deferred `_run`, printed `FAILED:` messages and nonzero exit convention. Start with the resolver cases below and prove they fail because the resolver does not exist. Add integration cases incrementally before each corresponding change.

## Task 2: Pure layer resolver

**Files:** `Scripts/UI/battle_visual_state.gd`, `Tests/Battle/test_ac7_5_battle_visual_states.gd`.

- [ ] Define the resolver contract below. These names are new proposed APIs, not claims about existing code. Availability and legality are inputs. Keep all results fresh per call.

```gdscript
class_name BattleVisualState
extends RefCounted

class Input extends RefCounted:
	var occupied: bool = false
	var active: bool = false
	var current_actor: bool = false
	var ribbon_preview: bool = false
	var action_committed: bool = false
	var valid_target: bool = false
	var selected_target: bool = false
	var hover_target: bool = false
	var action_kind: StringName = &"skill"
	var unavailable_reason: String = ""

class Layers extends RefCounted:
	var actor_frame: bool = false
	var interaction_spotlight: bool = false
	var target_border: StringName = &""
	var target_glyph: StringName = &""
	var selection_marker: bool = false
	var availability_treatment: StringName = &""
	var reason_text: String = ""

static func resolve(value: Input) -> Layers:
	var result := Layers.new()
	if not value.occupied:
		return result
	result.actor_frame = value.active and value.current_actor
	result.interaction_spotlight = value.active and value.ribbon_preview
	result.reason_text = value.unavailable_reason
	if not value.active or not value.unavailable_reason.is_empty():
		result.availability_treatment = &"unavailable"
		return result
	if value.action_committed:
		if value.selected_target and value.valid_target:
			result.target_border = &"selected"
			result.selection_marker = true
		elif value.valid_target:
			result.target_border = &"valid"
	elif value.hover_target:
		result.target_border = &"preview"
		result.interaction_spotlight = true
	if not result.target_border.is_empty():
		result.target_glyph = value.action_kind
	return result
```

- [ ] Add table-driven assertions for neutral, actor, ribbon, hovered skill, selected skill valid, selected target, Attack, Swap, invalid, defeated and empty states. Add these specific overlap tests using the new script via `load()`:

```gdscript
func _test_resolver_overlap() -> void:
	var resolver: Script = load("res://Scripts/UI/battle_visual_state.gd")
	var value = resolver.Input.new()
	value.occupied = true
	value.active = true
	value.current_actor = true
	value.action_committed = true
	value.valid_target = true
	value.selected_target = true
	value.action_kind = &"swap"
	var result = resolver.resolve(value)
	_assert(result.actor_frame and result.selection_marker, "actor and selection coexist")
	_assert(result.target_glyph == &"swap", "selected target keeps action identity")
	value.ribbon_preview = true
	value.hover_target = true
	result = resolver.resolve(value)
	_assert(result.target_border == &"selected" and result.interaction_spotlight,
		"preview cannot replace committed selected target")
	value.active = false
	result = resolver.resolve(value)
	_assert(not result.actor_frame and not result.selection_marker,
		"defeat suppresses actor and selected markers")
	_assert(result.target_glyph == &"" and result.target_border == &"",
		"defeat suppresses target affordances")
```

The snippet uses dynamic local values solely to access nested classes through a runtime-loaded Script. In the final runner, use explicit nested types once Godot's class scan has registered the new script; do not introduce `preload()` for a script created this session.

- [ ] Assert repeated identical inputs produce equal fields, inputs remain unchanged, changing one returned result does not affect later calls, and selected-but-no-longer-valid never displays a selected marker. Run the focused runner and per-script checks. Commit resolver and tests with `feat(battle-ui): add deterministic visual state resolver`.

## Task 3: Read-only legality and action availability adapter

**Files:** `Scripts/Battle/battle_arena.gd`, AC7.5 test runner.

- [ ] Add failing cases that observe a ready skill, cooldown, wrong turn, defeated actor, no enemies, no adjacent ally, predefined self action, authored zero-target action, and a mixed-side multi-target action missing its required second side. Snapshot HP, cooldowns, queue IDs, current actor, round, battle revision, action records, selected skill, default preview and full transaction state before and after observation; every value must match.
- [ ] Add arena-owned detached hover identity and a local presentation generation. Keep battle revision authoritative; never increment it for hovering, focus or rendering. Proposed new methods are `_evaluate_visual_skill(actor_id: StringName, skill_id: StringName) -> SkillTargetEvaluation` and `_refresh_visual_states() -> void`. The evaluation method performs the same `BattleSkillRules.evaluate_targets` call as `preview_skill_action`, without calling transaction `preview`, `reset`, `begin` or confirmation execution.
- [ ] Build skill action rows from the authoritative evaluation. Preserve the exact existing blocking reason first; preparation/action-in-progress gates take precedence because the arena owns those locks. Distinguish `can_activate`, `no_legal_completion`, `reason_text` and `inspectable`. Passive rows stay inspectable but never activatable.
- [ ] Do not use `valid_target_ids.is_empty()` as the universal availability check. For PREDEFINED actions use affected IDs and the existing validator. For FREE/authored actions respect minimum/maximum cardinality and ordered target-side stages. Zero explicit targets are legal when the existing confirmation validator accepts an empty selection. For staged/multi-target actions, find whether any complete candidate selection is accepted by `BattleSkillRules.validate_confirmation`, without applying its returned plan. Enumerate distinct candidate IDs in stable evaluation order, prune using authored counts/sides, and stop at the first accepted completion. Current formations bound candidates to 12 slots; cache evaluation within a refresh, not across authoritative revisions. Preserve existing optional-move behavior: use an empty optional move path and do not invent mandatory movement rules.
- [ ] If there is no legal completion and no stronger authoritative blocker, present `NO TARGET` and `No legal targets for this action.` Include an existing validator reason when it explains the missing completion. Derive this from evaluator/validator results, never UI text or guessed ranges. Do not modify combat validators to make a UI fixture pass.
- [ ] For default actions enumerate `preview_default_attack(current_id, candidate_id)` and `preview_formation_move(current_id, candidate.slot_index, true)`; collect only nonempty results. Keep selected IDs from `_default_action_preview`. Actor/turn/preparation locks remain stronger than no-target reasons. Attack and Swap receive distinct action kinds.
- [ ] Convert the committed skill snapshot's valid/affected/locked targets to resolver inputs, preserving multi-selection order, predefined affected units and combo metadata. Treat active selection as committed even when it has no chosen target yet. For zero-target self effects, distinguish the displayed affected actor from an explicit selected target; do not fabricate transaction target IDs.
- [ ] Run AC7.5, AC2.8 lifecycle/targeting, AC3.4 and active-turn-lock regressions before committing `feat(battle-ui): adapt authoritative targeting for visual states`.

## Task 4: Layered views and accessible action controls

**Files:** unit view and action bar scripts/scenes, skill button scene, arena render integration, AC7.5 runner.

- [ ] Add scene assertions for independent layer nodes, non-intercepting overlays and keyboard-readable descriptions before adding nodes. Test an actor targeting itself, a selected valid target, a defeated former target and ribbon preview during selection.
- [ ] Author separate actor-frame/`NOW`, spotlight, target border/glyph, selected reticle and prohibition/reason controls in `battle_unit_view.tscn`. Reuse existing overlays where possible, retain required node names/metadata for existing contracts, and set decorative overlay `mouse_filter=IGNORE` and `focus_mode=NONE`. Overlay visibility must not change card/container minimum size or obscure identity, health, status or damage feedback.
- [ ] Add `render_visual_state(layers: BattleVisualState.Layers) -> void` to BattleUnitView. Set every channel on every render, including the false/empty case. Keep descriptions additive to identity/HP/status text. Render `NOW`, `PREVIEW`, action identity, `SELECTED` and unavailable explanation as text/icon/shape cues as specified in the visual table. Do not append descriptions repeatedly on benign refresh.
- [ ] Route `_refresh_highlights`, `_render_skill_transaction` and `_apply_turn_order_preview` through `_refresh_visual_states`. Preserve legacy feedback separately within that composed refresh; remove competing writes to the semantic channels. Avoid recursion: the resolver pass must not call transaction mutators or a refresh helper that calls it again. Render a complete detached snapshot in one synchronous pass after authoritative state is settled.
- [ ] Extend action rows with the availability fields from Task 3. Keep unavailable action tiles in keyboard navigation. Use `focus_mode=ALL` and a guarded activation handler rather than relying on `Button.disabled` to deliver focus events. Mark unavailable state in accessibility description and visible prohibition/`NO TARGET` badge; preserve default action accessible names `Default Attack` and `Default Swap`. Native disabled-button assertions must be migrated to activation-guard and focus tests when intentional; retain tests proving no action can execute.
- [ ] Guard `_select_skill`, `_request_attack` and `_request_swap` using the current row availability. A refused Active/default action leaves the selected action and transaction untouched and shows its reason. Passive inspection retains AC2.6/AC7.3 selection behavior. Recheck availability in the arena intent handler as well, so queued/direct signals cannot bypass it.
- [ ] Keep unavailable explanations reachable by both pointer and keyboard during wrong-turn, preparation and completed phases. Suppress battlefield previews and forbidden actions in those phases, but do not let `details_allowed=false` hide every explanation. Separate informational availability details from actionable hover preview.
- [ ] Run the focused resolver/UI runner and AC7.1–AC7.4 regressions. Verify repeated refresh preserves focus and does not duplicate signals. Commit `feat(battle-ui): render accessible layered battle states` with only relevant scenes/scripts/tests.

## Task 5: Input arbitration and complete cleanup

**Files:** arena, action bar, unit view scene/script as needed, AC7.5 runner.

- [ ] Route the existing `skill_preview_changed(skill_id)` through detached hover evaluation. Reuse pointer-over-focus arbitration from `_refresh_details`. Add source identity/generation guards so a late exit from A cannot clear B. Empty preview ID clears only the transient skill source, never selected action/targets.
- [ ] Preserve public `preview_skill_action` behavior for its existing callers. A direct legacy PREVIEWING snapshot and the bar's observational preview both feed the resolver through explicit input selection; do not allow both to write overlays independently. No committed transaction is changed by detail hover.
- [ ] Give occupied battlefield cards keyboard focus and handle `ui_accept` through the same slot activation helper as a left click. Focus enter/exit uses the same hover-target intent as pointer enter/exit, with pointer precedence and source guards. Keep formation identity and selection behavior unchanged; empty slots cannot become Default Swap targets. Include focus-visible treatment separate from selection.
- [ ] Implement the cleanup matrix and test each boundary before adding its wiring:

| Boundary | Required result |
|---|---|
| Pointer exits while keyboard focus remains | Recompute from the focused source; clear the exited pointer source only. |
| Focus exits while pointer remains | Keep pointer preview; clear old focus source. |
| Both sources leave / action details clear | No hover-only target/spotlight remains; committed selection and actor remain. |
| Another action is hovered during selected action | Tooltip changes; selected target IDs, valid set and transaction remain identical. |
| Cancel or successful confirmation | Clear transient action preview, selected action and target layers; re-render current authoritative actor. Require a fresh input transition before reopening cleared hover. |
| Failed/stale confirmation | Preserve existing transaction rejection/message behavior; never display stale selected IDs or claim success. |
| Turn/round actor change, preparation, completion, reset | Invalidate all transient generations, clear committed presentation according to existing transaction lifecycle, render the new phase atomically. |
| Relevant target defeat/removal | Remove its target and selected affordances immediately; use authoritative transaction invalidation, never silently select a replacement. |
| Swap/relocation without turn transition | Resolve IDs to new slots; no old-slot highlight remains. If turn advances, normal turn cleanup wins. |
| Cooldown/status/revision change | Re-evaluate availability and candidates; retain a valid observational source only when still legal. Follow existing transaction invalidation policy for committed state. |
| Drawer opens/focus moves to it | Clear obscured hover/details and log preview as applicable; preserve committed action/targets and actor. Closing does not invent a new selection. |
| Teardown / deferred tooltip callback | No callback changes a freed/reconfigured view or restores a stale generation. |

- [ ] Pair synthetic signal tests with actual pointer movement, Tab/Shift+Tab and Enter/Space in Task 6. Test rapid A→B→late-A-exit, pointer preview over focused skill, cancel while focus remains, reset with identical actor/skill IDs, invalid activation, and no-op repeated refresh. Preserve HP, queue, action history and transaction snapshots for all observational cases.
- [ ] Run the full Task 6 regression suite before committing `feat(battle-ui): unify preview lifecycle and keyboard targeting`.

## Task 6: Regression, rendered evidence and completion

**Files:** both AC7.5 runners, evidence directory and MVP spec.

- [ ] Use the established Godot executable, verifying that it exists and recording its actual version. Run the focused script during development:

```powershell
$ac75Godot = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
if (-not (Test-Path -LiteralPath $ac75Godot)) { throw 'Locate the installed Godot executable.' }
& $ac75Godot --version
& $ac75Godot --headless --path . --script res://Tests/Battle/test_ac7_5_battle_visual_states.gd
if ($LASTEXITCODE -ne 0) { throw 'AC7.5 failed.' }
```

Expected after each completed task: the applicable new assertions pass, no parser errors, process exit zero. Final suite uses per-runner timeouts and checks error output as well as exit status:

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
assert Path(exe).is_file()
assert Path('Tests/Battle/test_ac7_4_debug_drawer.gd') in tests
assert Path('Tests/Battle/test_ac7_5_battle_visual_states.gd') in tests
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

- [ ] Run project `validate`, project `check_errors` and `signal_map(find="orphans")`; compare to baseline. Do not weaken negative-data tests or remove behavior assertions to get green results. Record actual runner count rather than assuming the future AC7.4 baseline.
- [ ] Create the capture fixture using the existing AC7 capture runner conventions. Configure deterministic actor/ally/enemy units and actual authored skills for self, ally, enemy, multi/staged and zero-explicit-target cases; use rule-accepted fixtures, not fabricated visual flags, for integration captures. Include current+self+selected, selected+valid, ribbon+selected, Attack, Swap, no-target, cooldown, defeated and cleanup states. A capture failure exits nonzero; run with a 60-second subprocess timeout.
- [ ] Inspect captures at **1152×648 and 1024×648**. The latter is the measured AC7.3 constrained-width baseline; do not claim 960-pixel support. Confirm overlays never cover HP/identity/status and tooltips/readouts fit; unavailable controls remain focusable; glyphs actually render; grayscale/non-color reading distinguishes actor/preview/valid/selected/Attack/Swap/unavailable.
- [ ] Exercise actual pointer and keyboard input through skills, default controls, cards and ribbon, including unavailable reasons. Verify both legal confirmation and rejected activation. Inspect drawer open/closed, log hover plus actor/selected layers, preparation, battle completion and reset. Capture one screenshot per verification point and describe what it demonstrates; metadata-only success is not visual evidence.
- [ ] Use GodotIQ `run(action="play")` → `verify_project_runs()` → `read_debug_console()` → `state_inspect` for relevant values → screenshot for changed visuals → `run(action="stop")`. Follow scene-work tour/inspect verification, inspect screenshots and fix any issue before capturing again. Confirm production world-to-battle entry still runs without new errors.
- [ ] Record actual executable/version, dependency hashes, branch/implementation commit, commands and per-runner results, input cases, screenshot paths, source migrations and deviations in `Docs/Specs/AC7/Evidence/AC7.5/verification.md`. Add `.gdignore`. Leave AC7.5 unchecked until every row below has passing evidence.
- [ ] Review the final diff for combat-rule changes, duplicate overlay writers, hover-triggered transaction mutations, missing lifecycle guards, hidden unavailable explanations and changes to the preserved oracle. Run `git diff --check`; stage only relevant paths. Commit implementation and then evidence/spec completion with `docs(ac7.5): record battle visual state verification`. Push only when requested.

## Acceptance traceability

The canonical record for every row below is `Docs/Specs/AC7/Evidence/AC7.5/verification.md`. Store screenshots/logs in that directory, reference them with relative links from the record, and include `Docs/Specs/AC7/Evidence/AC7.5/.gdignore` to prevent Godot importing evidence artifacts. Link the record from the AC7.5 acceptance row in `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` when the criterion passes.

For the final evidence commit, stage these exact documentation paths, then explicitly add only the screenshot/log files referenced by the record:

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC7/Evidence/AC7.5/verification.md Docs/Specs/AC7/Evidence/AC7.5/.gdignore
git diff --cached --check
git diff --cached --stat
git commit -m "docs(ac7.5): record battle visual state verification"
```

| Requirement | Automated evidence | Rendered / real-input evidence |
|---|---|---|
| Deterministic layered language | Resolver matrix and repeatability; actor+self+selected overlap | Actor/selected/valid layers distinguishable together |
| Ribbon preview | AC7.2 plus preview-with-selection and relocation cases | Pointer and keyboard spotlight moves to exactly one matching unit |
| Hovered skill target preview | Detached observation and mixed-input arbitration | Self/ally/enemy/multi hover and focus show equivalent legal sets |
| Selected skill/default targets | Snapshot stability and confirmation regressions | Hovering another action never replaces committed targets |
| Attack/Swap distinction | Default preview API candidate parity | Sword/arrow, label and selected treatment distinguish both |
| Invalid, defeated and unavailable | Suppression, activation guards and stale rejection | Prohibition/defeat labels retain identity and readable reason |
| No legal targets | FREE empty, PREDEFINED empty, staged missing side; legal zero-target exception | Focusable `NO TARGET` and specific reason; zero-target action remains usable |
| Cleanup | Every Task 5 boundary, identical-ID reset and deferred callbacks | No stale highlight after exits, cancel, confirm, turn/phase change or defeat |
| Accessibility | Focus traversal/activation, names/descriptions, no color-only states | Tab/Shift+Tab/Enter/Space and pointer parity at both viewports |
| Compatibility | All Battle runners and listed integration runners | Drawer/log coexistence and production battle smoke |

**Done means:** AC7.5 has passing automated and inspected rendered evidence, observational UI input preserves authoritative combat/transaction state, all prior AC7 contracts remain usable, and relevant code/evidence are committed on the dedicated branch. Planning alone does not satisfy the criterion.
