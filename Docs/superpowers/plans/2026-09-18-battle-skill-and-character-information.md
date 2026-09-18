# Battle Skill and Character Information Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking. Implemented and verified on 2026-09-18 after the user authorized implementation. Implementation: `4da4935`; see the AC7.6 verification record.

**Goal:** Make skills readable and consistently sized, and provide a left-side character information panel with live statistics, effects, and passive descriptions.

**Architecture:** Keep BattleArena authoritative for battle state and action selection. Add a scene-owned information panel receiving a read-only presentation snapshot. Track its inspected unit separately from the current actor and existing skill inspector. Reuse CharacterSkill descriptions and existing combat rules.

**Tech Stack:** Godot 4, typed GDScript, Control scenes, existing headless SceneTree tests, GodotIQ.

## Authority and completion ownership

The owning MVP criterion is **AC7.6** in `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`. Authority flows from that criterion to this plan's contracts, then to the tests and runtime checks mapped in `Docs/Specs/AC7/Evidence/AC7.6/verification.md`. The project lead owns product decisions. A test result cannot silently redefine the criterion.

AC7.6 extends AC7.3 and AC7.5. It supersedes only the older AC2.6/AC2.7/AC7.3 presentation expectations that passives occupy battle skill buttons and are inspected there. Their roster validity, skill metadata, passive mechanics, default-action behavior, and active-turn ownership remain regression requirements. Existing historical PASS records stay intact; AC7.6 remains unchecked until its own verification gate passes.

**Required integration dependency: AC7.4 (debug drawer).** Its [verification record](../../Specs/AC7/Evidence/AC7.4/verification.md) identifies implementation `57429e0` and establishes overlay geometry, click-through prevention, Escape handling, focus restoration, hidden-control exclusion, and preparation/reward/recruitment modal ownership. Start implementation only from a branch containing AC7.4 or its integrated equivalent. Historical AC7.4 PASS is baseline evidence, not proof that AC7.6 coexistence works. Rerun `Tests/Battle/test_ac7_4_debug_drawer.gd` before and after changes and add the explicit two-panel overlap cases below. AC7.4 is a blocking integration gate for AC7.6 acceptance.

Evidence uses `Docs/Specs/AC7/Evidence/AC7.6/verification.md` plus an adjacent `.gdignore`. The record must identify the implementation commit, branch, date, engine/environment, exact reproduction commands, runner logs, criterion mapping, inspected screenshots with observations, baseline differences, and remaining limits. The final record reports PASS with executed logs and inspected captures; planned coverage alone never establishes completion.

## Current implementation findings

- `Scripts/UI/battle_action_bar.gd` already supports skill tooltips on hover and keyboard focus, including effect, targeting, requirements, cooldown, combo, and availability. Extend and verify this path rather than introduce a second tooltip system.
- Skill buttons use `SIZE_EXPAND_FILL`, so available space and skill count affect their width. The bar currently includes both active and passive skills.
- `BattleArena.inspect_unit()` is deliberately restricted to the acting unit. Reusing it for right-click inspection would conflict with the active-turn skill lock.
- `BattleUnitState` exposes HP, power, defense, base/effective speed, armor, speed modifiers, Advantage, Snared, and Bleed. It has no explicit class field; `BattleUnitPresentation.role_for()` provides the existing role label.
- Physical damage uses `max(1, ceil(power * multiplier) - defense)`. Defense is flat reduction, not a percentage. Armor is a separate consumable protection value.

## Recommended design

Use transient tooltips for active skills and an independent character information drawer for persistent inspection. Alternatives are a permanent skill-description area (takes battlefield space) or showing every active description in the drawer (requires another interaction to read a skill). The recommended arrangement keeps skill information close to its button and character information together.

### Skill descriptions and button sizing

- Show the existing structured skill description on hover or keyboard focus, including unavailable skills and their reason. Preserve combo information and authored targeting/requirements text.
- Keep tooltips inside the viewport, above the button where possible and below when necessary. Tooltips must not intercept input or change action selection.
- Adopt one shared skill-button size, provisionally **160 × 88 logical pixels**, to be confirmed against the current theme at implementation QA. All active skill buttons use exactly the same dimensions, independent of title length and skill count.
- Remove horizontal expansion from individual skill buttons. Allocate overflow to horizontal scrolling at narrow widths rather than resizing individual buttons. Keep focused buttons visible.
- Use at most two title lines with ellipsis for overflow; the full title remains in the tooltip and accessibility label. Availability and numbering must fit without growing the button.
- Preserve the current sizes and behavior of Default Attack, Default Swap, Confirm, and Cancel.
- Number visible active skills consecutively and resolve activation through stable skill IDs. Show an active-skill count rather than the misleading total-roster `Skills: n/4` label.

### Character information interaction

- Right-click an occupied battlefield character, ally or enemy, to open a panel sliding in from the left. Width: 340 logical pixels, capped to the viewport; animation duration: 0.18 seconds.
- Right-click a different character to replace the displayed information immediately. Right-click the same character to keep the panel open; close through its close button or Escape.
- Empty-slot right-clicks do nothing. Inspection does not select an action/target, consume a turn, cancel a pending action, or switch the action bar's actor.
- Keep the inspected character pinned across turn changes; refresh its information after authoritative state updates. Defeat changes the panel to a defeated state while the unit exists. Removal, battle reset, battle exit, and opening the battle-results overlay close the panel and clear its ID.
- Permit read-only inspection during preparation and between actions. During action resolution, retain the last committed snapshot and refresh after commit rather than expose partially applied state.
- Escape closes the information panel first and consumes that input; a later Escape may reach existing action-cancel handling. Opening through right-click must consume that event so it cannot reach other battle actions.
- Provide keyboard access through an Inspect input action on a focused character, initially bound to I. Restore focus only under the ownership and fallback rules in the input-precedence contract below.
- The panel overlays the battlefield without moving the formation. Only its visible rectangle intercepts pointer input; closed/hidden controls must not block the battle. Keep it above the debug drawer and below modal results. Its body scrolls independently.

### Committed snapshot and refresh contract

BattleArena owns a detached snapshot cache for **all** battlefield units, including units not currently inspected. The presenter never accepts a live `BattleUnitState`. Its input is a copied unit record plus the committed envelope below. No node, Resource, RefCounted status/skill object, or mutable authoritative collection is shared with the panel.

| Field | Meaning |
|---|---|
| `battle_epoch: int` | Increment on every setup/reset, including same-unit-ID resets; invalidates all old work. |
| `committed_revision: int` | Monotonic within an epoch, incremented only when a complete committed snapshot is published. Separate from `_battle_revision` unless that field is proven to have exactly these semantics. |
| `round_number: int`, `phase: StringName`, `current_actor_id: StringName` | Captured together with unit records at the same commit boundary. |
| `units_by_id` | Detached records keyed by stable unit ID: identity/role, HP, base/effective speed, power, defense, armor, individual effects with source/magnitude/stacks/expiry mode and value, and passive description strings. |
| `resolution_in_progress: bool` | UI-envelope flag only; may change without publishing new unit data. Shows a Resolving indicator while retaining the last committed values. |
| `inspection_generation: int`, `requested_unit_id: StringName` | UI request token, incremented on open, switch, close, and invalidation; not combat state. |

Publication rules:

1. Publish the initial cache after setup is complete and before enabling inspection. Opening before this boundary is ignored, never serviced from live partial state.
2. Before the first action mutation, set resolution-in-progress. Keep the previous cache unchanged throughout damage, reactions, status consumption/expiry, defeat handling, turn/round advancement, and outcome evaluation. Do not publish from intermediate refresh calls.
3. At the outermost successful action boundary, after those operations finish, copy all units and context, increment the committed revision, atomically replace the cache, clear the resolving flag, and refresh the pinned panel once. An outcome opening results instead closes the panel before any information refresh can restore it.
4. Stable changes outside actions (preparation confirmation, debug mutations, standalone turn advancement, removal) use the same publication function after the complete operation. Pure hover/focus/inspection never increments the revision. Audit each mutation entry point rather than rely on per-frame refresh.
5. A rejected action publishes nothing and clears the resolving flag. An aborted operation must restore stable state before publishing; while that cannot be guaranteed, close inspection and prohibit reopening until reset/recovery. Never label partial state committed.
6. Opening or switching units during resolution reads the requested unit from the previous all-unit cache and displays Resolving. If absent, show no panel for that request. After commit, re-resolve the pinned ID; close if removed, otherwise render the new record, including defeat.
7. Every deferred render/animation completion carries `(battle_epoch, committed_revision, inspection_generation, requested_unit_id)`. Apply only if epoch, generation and ID still match and revision equals the current cache revision. Discard older callbacks; schedule the current snapshot if needed. Close/reset/exit/results invalidate the request before hiding/freeing controls.

The presenter formats a single detached unit record using the envelope's round/phase; it never decides when a commit occurred. Duration display uses that captured round and explicit expiry semantics. Snapshot arrays and nested records are copied defensively on publication and delivery.

### Input ownership and precedence

Route each event to one owner; accepted events must not reach a second activation/cancel handler. Press events only, no key echo. The arena owns arbitration; the panel emits close intent and does not install a competing global cancel handler.

| Priority / state | Owner and exact behavior |
|---|---|
| 1. Results or another blocking modal | Modal owns pointer, Inspect, activation and Escape. Entering results invalidates/closes inspection and clears tooltip/preview sources before showing the modal. No focus restoration to the battlefield; delayed callbacks cannot reopen inspection. |
| 2. Pointer inside visible information panel | Panel controls consume pointer/wheel events. Right-click does not inspect a character behind it. Close-button activation closes only the panel. |
| 3. Escape while information panel open | Arena closes the panel and consumes Escape regardless of battlefield/action-bar focus. Preserve pending skill/default transaction and target IDs. Only a later Escape reaches the existing cancellation/drawer logic. |
| 4. Right-click on an uncovered occupied battlefield slot | Consume the event and open/switch inspection, including during active targeting. Do not invoke left-click selection, cancel, confirmation, or actor inspection. Empty slots consume right-click with no change; do not route it into action cancellation. |
| 5. Inspect (`I`) with a focused occupied battlefield slot | Open/switch inspection and consume. In an action-bar, panel, debug control, text entry, or modal, this shortcut does not inspect or activate anything. Use GUI focus checks before any unhandled-input fallback. |
| 6. Other pointer/keyboard activation outside panel | Existing battle/default/targeting behavior retains ownership and existing phase/action locks. Enter/Space on a panel control never selects a battlefield target; Enter/Space on an action-bar control retains its existing action behavior. |

Opening/switching inspection clears transient skill/ribbon/target hover sources, hides action tooltips, and invalidates deferred tooltip placement while preserving committed selected-action and target layers. Right-click does not move keyboard focus. Keyboard Inspect saves the source control and focuses the panel close button. The panel is nonmodal: Tab can leave it for visible battle controls. If focus was moved elsewhere after opening, closing must not steal it back; restore the saved source only when focus is still inside the closing panel. If that source is gone, use the current actor's visible slot, then the action bar as fallback. Pointer-close follows the same rule and restores the pre-panel focus only if the panel currently owns it.

After opening, a pre-existing focused skill must not immediately resurrect its tooltip. Re-enable detail inspection only on a fresh pointer-enter or focus-enter event on an unobscured control. Thereafter existing pointer-over-focus precedence applies, and active targeting retains its committed target display. The panel occludes both hover and tooltip drawing in its rectangle; tooltips from other visible controls remain above ordinary battle UI and below results modals. Opening the debug drawer or another overlay clears newly obscured transient sources without changing a committed selection.

AC7.4 coexistence rules: both panels may remain open. Paint order is battlefield < debug drawer < character information < blocking modal; higher visible controls own overlapping pointer input. With no blocking modal, successive Escape presses close character information first, then the debug drawer, then reach pending-action cancellation, one event per operation. Each close preserves the other panel and selected action. Restore focus only to a visible, enabled, unobscured control; if a saved debug control is hidden, use the existing battlefield/action-bar fallback. A blocking preparation, reward, or recruitment modal owns input under AC7.4's existing guard, so the earlier permission to inspect during preparation applies only when no blocking preparation modal is present. Modal entry clears tooltip/preview sources and closes character information without restoring battlefield focus; preserve AC7.4's existing drawer/handle exclusion rules.

### Panel content

1. **Identity:** display name, Class/Role using `BattleUnitPresentation.role_for()`, and defeated state when applicable. Use its existing Combatant fallback; introducing a new class system is outside this change.
2. **Health:** current/max HP and a health bar.
3. **Statistics:** effective Speed (with base value and signed modifier when changed); Damage labeled as base attack power, with a description explaining that skills and target defenses affect final damage; Damage reduction shown as a flat physical-defense amount, with the existing minimum-damage rule explained. Show Armor separately when present.
4. **Buffs and debuffs:** separate labeled groups. Each entry has a name, effect description, magnitude or stacks where meaningful, and its actual expiry condition. Distinguish remaining affected-unit actions, end-of-round expiry, and consumption; never convert all durations to generic turns. Show None for an empty group.
5. **Passives:** name and full wrapped effect description always visible in the panel. Include trigger/requirements, cooldown or usage limits, and combo text where authored and applicable. Use the existing skill metadata; do not invent missing dynamic usage information.

Represent speed modifiers individually so positive and negative effects cannot hide each other through a net zero value. Keep Bleed source/stack count distinct from damage. Explain Advantage according to its actual mechanic, not an assumed damage bonus. Armor displays its amount and consumption condition rather than a fabricated duration.

Remove passive buttons only from action-bar presentation. Keep the complete skill roster, passive reaction dispatch, save data, and roster validation unchanged. Characters with no active skills retain their default action controls and show a clear empty active-skill state.

## Implementation sequence

### 1. Establish baseline and information contract

**Reference:** `Scripts/Battle/battle_unit_state.gd`, `Scripts/Battle/battle_damage_rules.gd`, `Scripts/UI/battle_unit_presentation.gd`, `Scripts/Battle/character_skill.gd`.
**Create:** `Scripts/UI/battle_character_info_presenter.gd`, `Tests/Battle/test_battle_character_info_presenter.gd`.
**Modify:** `Scripts/Battle/battle_arena.gd` for committed-cache ownership/publication; `Scripts/Battle/battle_unit_state.gd` only if required read-only snapshot accessors are missing. Put mutation-boundary integration cases in `Tests/Battle/test_battle_character_inspection.gd`, introduced in this task and extended in task 4.

- [x] Update main from origin and create a dedicated branch in the primary workspace; preserve unrelated work according to AGENTS.md. Do not use a worktree.
- [x] Capture project validation and existing Battle tests before edits.
- [x] Confirm AC7.4 implementation ancestry/integrated behavior and capture `test_ac7_4_debug_drawer.gd` baseline. Inspect `Scripts/UI/battle_debug_drawer.gd` and its arena integration before changing Escape/focus arbitration; keep drawer behavior owned by the existing component.
- [x] Implement the committed cache and detached presenter inputs defined above, including all-unit capture, atomic publication, epoch/revision/request guards and resolving-state labeling. Audit action and non-action mutation boundaries in BattleArena; the presenter must not read a live unit.
- [x] Add snapshot tests that pause between damage and reactions, open a previously uninspected unit mid-resolution, switch twice, then complete the action. Assert old committed values throughout resolution and exactly one new revision with complete post-action values. Cover rejected actions, standalone updates, removal, same-ID reset, result-modal invalidation, nested-copy mutation, and out-of-order deferred callbacks.
- [x] Add meaningful tests for modified speed, flat defense versus armor, individual cancelling speed modifiers, Bleed source count, effect expiry wording, empty groups, and passive descriptions. Assert that building information does not alter combat state.
- [x] If an expiry/source value lacks a read-only accessor, add the smallest snapshot accessor in `battle_unit_state.gd` after an impact check; do not parse private fields or advance effect timers to obtain display data.

### 2. Standardize the action bar

**Modify:** `Scenes/UI/battle_skill_button.tscn`, `Scenes/UI/battle_action_bar.tscn`, `Scripts/UI/battle_action_bar.gd`, `Scripts/Battle/battle_arena.gd`.
**Update:** `Tests/Battle/test_ac7_3_unified_action_bar.gd`.

- [x] Filter active skills when building action-bar presentation rows; do not filter the authoritative roster.
- [x] Apply the shared button size, bounded title layout, and narrow-window scrolling. Update numbering/counts and any keyboard bindings to match visible active skill IDs.
- [x] Retain existing hover/focus descriptions, unavailable reasons, viewport clamping, and transient cleanup. Verify description rendering before making any tooltip changes.
- [x] Test zero, one, and four active skills, long names, and mixed active/passive rosters. Compare actual button dimensions after layout, not only minimum-size settings. Assert default controls retain baseline sizes.
- [x] Update older tests that explicitly expect passive buttons to assert panel visibility instead; preserve passive combat-behavior assertions.

### 3. Build the information panel

**Create:** `Scenes/UI/battle_character_info_panel.tscn`, `Scripts/UI/battle_character_info_panel.gd`, `Tests/Battle/test_battle_character_info_panel.gd`.
**Modify:** `Scenes/battle_arena.tscn`.

- [x] Create a scene-owned left overlay with identity/close header and a scrolling body containing health, statistics, buffs, debuffs, and passives.
- [x] Add presentation rendering, open/close animation, focus behavior, and a close-request signal. Keep battle mutations out of this component.
- [x] Cancel/replace an in-flight animation when reopening or closing rapidly. Recompute panel bounds on viewport resize and keep hidden controls noninteractive.
- [x] Test empty and long content, repeated open/close, switching units during animation, and destruction while an animation is active.

### 4. Wire independent character inspection

**Modify:** `Scripts/Battle/battle_arena.gd`, `project.godot` for the Inspect action.
**Create:** `Tests/Battle/test_battle_character_inspection.gd`.

- [x] Add a separate character-information unit ID; preserve `_inspected_unit_id` and its actor-lock contract.
- [x] Implement the input-ownership table in arena arbitration and slot GUI handling, including modal guards, event consumption, focused-slot eligibility, and tooltip invalidation. Do not add a second global cancel listener in the panel.
- [x] Refresh only from the committed cache and enforce all four deferred-callback tokens; close at the documented lifecycle boundaries.
- [x] Assert inspection preserves current actor, selected skill, default-action mode, pending target/transaction, HP, turn queue, round, and battle log.
- [x] Cover ally/enemy inspection, empty slots, switching characters, preparation, action resolution, turn changes, defeat/removal, reset, and Escape precedence.
- [x] Add overlap tests using dispatched pointer/key events: right-click during skill/Attack/Swap targeting; Inspect with action-bar versus slot focus; opening while a tooltip callback is queued; Escape with panel plus targeting; panel pointer input above a unit; Tab leaving the panel before close; source removal; and results appearing during open animation. Assert each event has one owner, selected IDs remain stable, obscured previews clear, and modal/closed UI never returns battlefield focus.
- [x] Extend `Tests/Battle/test_battle_character_inspection.gd` with AC7.4 integration fixtures: open panels in both orders during Attack and Swap targeting; dispatch three separate Escape presses and assert panel, drawer, then action cancellation; exercise overlap pointer/wheel blocking, saved drawer focus after drawer closure, and preparation/reward/recruitment modal entry with both panels open. Assert unchanged formation rectangles and hidden-panel Tab exclusion. Rerun `Tests/Battle/test_ac7_4_debug_drawer.gd` unchanged unless an assertion is explicitly superseded by this documented coexistence contract; preserve all standalone drawer checks.

### 5. Verify and record acceptance

- [x] Run GodotIQ `file_context` before each edit and `impact_check` before API/signal changes. Validate and check parser errors after each script change. Use GodotIQ scene writes while the editor is open.
- [x] Run the new tests, then all existing `Tests/Battle/test_*.gd` runners with `godot --headless --path . --script res://Tests/Battle/<runner>.gd`; require exit code zero. Also run `Tests/WorldMap/test_world_battle_entry.gd`.
- [x] Finish with project validation, project error checks, and orphan-signal inspection.
- [x] Run the battle through GodotIQ play, verify_project_runs, and debug-console checks. Check the actual UI at the established 1152×648 and 1024×648 sizes plus 1920×1080, including the longest descriptions, unavailable skills, passive-only roster, and a unit with several simultaneous effects.
- [x] Visually confirm equal button dimensions, unchanged default controls, readable tooltips, leftward panel origin/sliding motion, panel scrolling, and no pointer leakage. Verify selecting/confirming/cancelling an action still works after inspection.
- [x] Populate `Docs/Specs/AC7/Evidence/AC7.6/verification.md`, retaining the adjacent `.gdignore`. Link actual runner logs and inspected captures for every mapping row; record implementation commit/environment, exact reproduction, baseline differences and limits. Never mark planned/unexecuted checks PASS.
- [x] Update the AC7.6 MVP traceability row to link final results and check its acceptance box only after all mapped checks pass. Keep AC2.6/AC2.7/AC7.3 historical evidence and the explicit presentation supersession note. Commit only relevant implementation, tests, and documentation on the task branch. Push only if requested.

## Acceptance gate

AC7.6 is complete only when all five contract rows in its verification record have actual PASS evidence: skill sizing/descriptions; character content/passives; atomic snapshot freshness; input/focus arbitration; and lifecycle/regressions. The MVP checkbox stays unchecked if any row is NOT RUN, failing, or supported only by a plan. Require the implementation commit, successful runner/error checks and inspected runtime captures, then record the final status in both the verification file and MVP traceability row.

The input/focus and lifecycle rows must include current AC7.4 regression and two-panel coexistence results. Missing or failing AC7.4 integration evidence blocks AC7.6 even if all new standalone panel tests pass.

Implemented inspection of both allies and enemies, direct passive descriptions, flat damage reduction, and the sizes/animation above. No gameplay balance changes. Work is on its dedicated branch; no remote push was requested.
