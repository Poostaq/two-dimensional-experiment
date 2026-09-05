# AC3.4 Default Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Default Attack and Default Swap visibly available and usable by every player character during its turn, alongside zero-to-four character-specific skills.

**Architecture:** Preserve the implemented AC6.1 domain transactions in `BattleArena`: `preview_default_attack()` / `confirm_default_attack()` and `preview_formation_move(..., true)` / `confirm_formation_move(..., true)`. Add one battle-local default-action selection state in `battle_arena.gd` that adapts pointer input to those APIs, renders through a dedicated action strip in `battle_arena.tscn`, and cancels whenever authoritative battle state changes. Do not model the defaults as `CharacterSkill` entries because AC2.6 limits only character-specific skills and action history already distinguishes `DEFAULT_ATTACK` and `DEFAULT_SWAP`.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured scene/script operations, SceneTree test runners.

---

## Existing foundation and exact scope

Already implemented and retained:

- `BattleArena.preview_default_attack()` validates the active player actor and active enemy.
- `BattleArena.confirm_default_attack()` applies `max(1, ceil(Power) - Defense)`, records `DEFAULT_ATTACK`, advances once, and rejects stale revisions.
- `BattleFormationRules.is_move_one()` defines orthogonal adjacency in the two-row, three-lane six-slot formation.
- `BattleArena.preview_formation_move(..., true)` requires an adjacent occupied allied slot.
- `BattleArena.confirm_formation_move(..., true)` atomically exchanges the two slots, records `DEFAULT_SWAP`, and advances once.
- `Tests/Battle/test_ac6_1_combat_foundation.gd` covers the domain transactions.

Missing for AC3.4:

- discoverable Default Attack and Default Swap controls in the battle UI;
- click/confirm/cancel interaction against battlefield slots;
- disabled/rejection feedback when the current unit cannot use an action;
- criterion-specific automated, runtime, and documentation evidence.

Files to create or modify:

- Create `Tests/Battle/test_ac3_4_default_actions.gd` — UI-level contract and interaction regression runner.
- Modify `Scenes/battle_arena.tscn` — add the two default-action buttons and concise instruction/confirmation presentation.
- Modify `Scripts/Battle/battle_arena.gd` — own default-action UI state and route slot input into existing domain transactions.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — strengthen the AC3.4 verification path and check the criterion only after evidence passes.
- Create `Docs/Specs/AC3/Evidence/AC3.4/<verification-date>/implementation-link.txt`.
- Create `Docs/Specs/AC3/Evidence/AC3.4/<verification-date>/automated-test.log`.
- Create `Docs/Specs/AC3/Evidence/AC3.4/<verification-date>/manual-runtime-check.md`.

### Task 1: Establish branch and RED UI contract

**Files:**

- Create: `Tests/Battle/test_ac3_4_default_actions.gd`

- [ ] **Step 1: Start from a clean integration baseline**

Preserve unrelated workspace changes, update `main` from `origin/main`, then create `feat/ac3-4-default-actions` in the primary workspace. This repository forbids worktrees. Restore unrelated changes without staging them.

- [ ] **Step 2: Write the failing SceneTree test**

Use the established arena-instantiation pattern and assert these exact contracts:

```gdscript
class_name Ac3_4DefaultActionsTests
extends SceneTree

const ARENA_PATH: String = "res://Scenes/battle_arena.tscn"

func _run() -> void:
	await _test_controls_are_separate_from_character_skills()
	await _test_default_attack_pointer_flow()
	await _test_adjacent_swap_pointer_flow()
	await _test_invalid_and_stale_flows_do_not_mutate()
```

The fixtures must include: a current player actor with four skills, an active enemy, an adjacent active ally, a non-adjacent ally, an empty adjacent slot, and a defeated adjacent ally. Assert:

- `DefaultAttackButton` and `DefaultSwapButton` exist while the skill count remains `4/4`;
- selecting Attack and clicking an enemy creates a preview without HP/turn/revision mutation;
- confirming applies the existing Power-versus-Defense result and advances exactly once;
- selecting Swap exposes only adjacent active allied occupants as valid;
- confirming swaps exact slot indices and advances exactly once;
- enemy turns, preparation lock, battle completion, empty adjacency, defeated allies, non-adjacent allies, cancellation, and stale revision all leave HP, slots, history, revision, and turn unchanged;
- action state clears after commit, cancel, `configure_units()`, battle completion, and scene teardown.

- [ ] **Step 3: Run RED**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac3_4_default_actions.gd
```

Expected: FAIL because `DefaultAttackButton` and `DefaultSwapButton` do not exist.

- [ ] **Step 4: Commit RED**

```powershell
git add Tests/Battle/test_ac3_4_default_actions.gd
git commit -m "test: define AC3.4 default action UI contract"
```

### Task 2: Add the default-action strip to the arena scene

**Files:**

- Modify: `Scenes/battle_arena.tscn`
- Test: `Tests/Battle/test_ac3_4_default_actions.gd`

- [ ] **Step 1: Inspect before mutation**

Use GodotIQ `file_context(file="res://Scenes/battle_arena.tscn", detail="brief")`. Add the controls with `node_ops(validate=true)` under the existing inspector/action area; do not hand-edit the scene.

- [ ] **Step 2: Add exact scene-owned controls**

Add unique-name nodes:

```text
DefaultActionsRegion (VBoxContainer)
  DefaultActionsLabel (Label, text="Default actions")
  DefaultActionsButtons (HBoxContainer)
    DefaultAttackButton (Button, text="Attack")
    DefaultSwapButton (Button, text="Swap")
  DefaultActionMessageLabel (Label, text="")
  DefaultActionSummaryLabel (Label, text="")
  DefaultActionConfirmation (HBoxContainer)
    DefaultActionConfirmButton (Button, text="Confirm")
    DefaultActionCancelButton (Button, text="Cancel")
```

Set keyboard focus on all four buttons, keep both default actions visible for every inspected player character, and use disabled state plus the message label for temporary unavailability. Do not add these controls to `SkillInspectorSkills`.

- [ ] **Step 3: Save and validate**

Use `save_scene()`, then `validate(target="res://Scenes/battle_arena.tscn", detail="brief")` and `check_errors(scope="res://Scenes/battle_arena.tscn")`. Expected: no new errors or incomplete controls.

- [ ] **Step 4: Commit**

```powershell
git add Scenes/battle_arena.tscn
git commit -m "feat: add battle default action controls"
```

### Task 3: Route UI input through the existing transactions

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac3_4_default_actions.gd`

- [ ] **Step 1: Inspect impact before editing**

Run GodotIQ `file_context(..., detail="brief")` and `impact_check` for the slot-input handler and `_refresh_turn_ui()`. Read/patch only through `script_ops`.

- [ ] **Step 2: Add typed UI state**

Use a private enum and locked preview dictionary:

```gdscript
enum DefaultActionMode { NONE, ATTACK, SWAP }

var _default_action_mode: DefaultActionMode = DefaultActionMode.NONE
var _default_action_preview: Dictionary = {}
```

Add `@onready` references for the six new interactive/presentation controls. Connect pressed signals in `_ready()`.

- [ ] **Step 3: Implement selection and cancellation**

`_on_default_attack_pressed()` and `_on_default_swap_pressed()` must first call `_can_current_player_act()`. Attack prompts `Select an active enemy.`; Swap prompts `Select an adjacent active ally.`. Starting either mode cancels any skill transaction. `_cancel_default_action()` resets mode/preview and refreshes indicators without changing authoritative state.

- [ ] **Step 4: Adapt battlefield clicks**

In the existing slot input path, give an active default-action mode priority over inspection:

```gdscript
match _default_action_mode:
	DefaultActionMode.ATTACK:
		_default_action_preview = preview_default_attack(current.unit_id, clicked_unit_id)
	DefaultActionMode.SWAP:
		_default_action_preview = preview_formation_move(current.unit_id, clicked_slot, true)
```

An invalid target keeps the mode active, clears the preview, and shows a binary reason. A valid preview locks actor, target/occupant, source/destination slots, and revision; it enables Confirm but performs no mutation.

- [ ] **Step 5: Confirm through existing APIs**

`_confirm_default_action()` must call only the existing confirmation method matching the mode, using every locked preview field. On success clear the action state; on rejection clear the stale preview, retain no partial mutation, and show `Battle state changed; choose the action again.`

- [ ] **Step 6: Apply lifecycle and availability rules**

Disable both buttons unless the current unit is an active player unit and battle input is unlocked. Disable Swap when no adjacent active allied occupant exists. Cancel default-action UI state from `configure_units()`, preparation activation, battle completion, successful turn advance, and `_exit_tree()`. Refresh slot indicators after selection, invalid click, cancel, commit, and authoritative change.

- [ ] **Step 7: Validate and prove GREEN**

Run GodotIQ validation/error checks for `battle_arena.gd`, then:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac3_4_default_actions.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_1_combat_foundation.gd
godot --headless --path . --script res://Tests/Battle/test_active_turn_skill_lock.gd
```

Expected: all runners exit `0`; the new runner proves presentation and pointer orchestration, while retained runners prove mechanics and input locks.

- [ ] **Step 8: Commit**

```powershell
git add Scripts/Battle/battle_arena.gd Tests/Battle/test_ac3_4_default_actions.gd
git commit -m "feat: expose default actions in battle"
```

### Task 4: Regression, runtime evidence, and traceability

**Files:**

- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC3/Evidence/AC3.4/<verification-date>/implementation-link.txt`
- Create: `Docs/Specs/AC3/Evidence/AC3.4/<verification-date>/automated-test.log`
- Create: `Docs/Specs/AC3/Evidence/AC3.4/<verification-date>/manual-runtime-check.md`

- [ ] **Step 1: Run automated regression**

Run every `Tests/Battle/test_*.gd`, plus the production battle-entry/cutover runner. Capture commands, exit codes, assertion totals, branch, and commit in `automated-test.log`.

- [ ] **Step 2: Run the GodotIQ project gate**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans")
verify_project_runs(scene="main", check_scope="project", stop_after=true)
```

Expected: no new validation issue, parser/runtime error, or orphan signal relative to baseline.

- [ ] **Step 3: Perform the AC3.4 runtime matrix**

At 1152x648, enter a production battle and record PASS/FAIL for:

1. a four-skill character still shows exactly four character skills plus separate Attack and Swap controls;
2. Attack target preview changes no state; Confirm deals correct damage and advances once;
3. Swap highlights only adjacent active allies; Confirm exchanges exact slots and advances once;
4. Swap is disabled with no adjacent active ally;
5. both actions are unavailable on enemy turns, during preparation, and after battle completion;
6. Cancel and invalid clicks do not mutate HP, slots, history, revision, or turn;
7. action state does not survive the next turn or next battle;
8. the debug console contains no script/runtime errors.

Use `state_inspect` for HP, slot, turn, revision, and history evidence. Use one `explore(mode="inspect")` capture for the action strip and target indication, then stop Play.

- [ ] **Step 4: Update traceability only after PASS**

Replace AC3.4's manual-only verification row with the new runner plus runtime matrix. Mark `[x]` only when every blocking row passes. The evidence matrix must classify AC3.4 as integration/runtime and link exact files, results, gaps, and next action.

- [ ] **Step 5: Commit the earned evidence**

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC3/Evidence/AC3.4
git commit -m "docs: record AC3.4 verification evidence"
```

## Traceability matrix

| Criterion | Verification path | Evidence location | Current status | Gap | Next action |
|---|---|---|---|---|---|
| Every character has Default Attack in addition to 0–4 skills | Existing `test_ac6_1_combat_foundation.gd`; new `test_ac3_4_default_actions.gd`; runtime row 1–2 | AC6.1 test plus planned AC3.4 logs | PARTIAL | Mechanics exist; player-facing access is absent | Tasks 1–3 |
| Every character has adjacent Default Swap | Existing AC6.1 swap transaction; new adjacent/non-adjacent/defeated/empty UI cases; runtime rows 3–4 | AC6.1 test plus planned AC3.4 logs | PARTIAL | Mechanics exist; discoverable UI selection is absent | Tasks 1–3 |
| Defaults coexist with character-specific skills | New four-skill UI fixture and runtime row 1 | Planned AC3.4 test/runtime record | FAIL | No criterion-specific UI evidence | Tasks 1–4 |
| Actions obey battle locks and are atomic | Existing stale transaction tests; active-turn lock runner; new UI lifecycle cases | Existing AC6.1/lock tests plus planned AC3.4 log | PARTIAL | UI state cleanup and invalid-click behavior unverified | Tasks 3–4 |

Overall current coverage: 0/4 fully evidenced, 3/4 partial, 1/4 missing. AC3.4 remains unchecked until Task 4 passes.

## Self-review outcome

- Spec coverage: both default actions, coexistence with skills, adjacency, availability, atomic rejection, turn consumption, and lifecycle cleanup map to named tests and runtime rows.
- Placeholder scan: `<verification-date>` is an execution-time evidence directory token, not an undefined implementation decision; all behavior and target files are specified.
- Type consistency: the plan reuses the current `DefaultActionMode`, preview dictionaries, `BattleActionRecord.Kind.DEFAULT_ATTACK/DEFAULT_SWAP`, and existing preview/confirm signatures without adding a parallel domain model.
