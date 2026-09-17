# AC7 Battle UI Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking; use `superpowers:test-driven-development` for every behavior change.

**Goal:** Replace the MVP battle HUD presentation with the approved Living Lanes layout: readable character formations, a strongly marked and interactive turn-order ribbon, a unified skill/default-action bar, an on-demand debug drawer, and one unambiguous visual language for every battle interaction state.

**Architecture:** Keep `BattleArena` authoritative for combat state and actions. Add focused UI scene/controllers that receive snapshots or existing battle-state objects, emit user intent, and never mutate combat state directly. A pure visual-state resolver converts authoritative and transient interaction state into layered per-unit and per-action presentation models; views render those models without deciding legality. Integrate the components in `battle_arena.tscn`, leaving rules such as damage, targeting, turn advancement, Default Attack, and Default Swap in the current battle systems.

**Tech Stack:** Godot 4, typed GDScript, Control-based UI scenes, headless `SceneTree` test runners, GodotIQ scene/script operations and visual QA.

---

## Scope and constraints

- Preserve the existing 12-slot formation and combat rules.
- Present battlefield units as character-forward figures in backline/frontline living lanes, while retaining explicit grid-slot readability.
- Show the active unit with a persistent high-contrast border and `NOW` marker in the turn-order ribbon.
- Hovering or keyboard-focusing a turn-order entry highlights the matching battlefield character; leaving the entry restores the authoritative active/selected state.
- Keep full-size skill controls. Present Default Attack and Default Swap as smaller icon actions with hover/focus tooltips.
- Do not implement unrestricted movement in AC7. The second compact action is the already-supported Default Swap. A true Move action requires a separate gameplay AC.
- The debug drawer is collapsed by default, opens from a side-aligned handle, overlays the arena without shifting combat UI, and exposes battle log, live state, initiative queue, and existing debug commands.
- Use layered visual channels instead of allowing one border to overwrite another: persistent actor state uses an outer frame and `NOW`; target legality uses an inner border plus action glyph; confirmed selection uses a reticle/check marker; transient hover/focus preview uses a silhouette or soft spotlight.
- Defeated and untargetable states suppress target affordances. A selected target is stronger than a valid-target treatment, while the current actor remains visible as a separate outer layer for legal self-targeting.
- Hovering/focusing an unselected skill previews its legal targets only while no action is committed. Once an action is selected, hovering another action may show its tooltip but must not replace the committed battlefield target state.
- Distinguish Default Attack and Default Swap target sets with both iconography and text, not only color. An action with no legal target is non-activatable, carries a `NO TARGET`/prohibition marker, and explains its primary reason on hover/focus.
- Clear transient and committed layers on their defined boundaries: pointer exit, focus loss, cancel, confirmation, active-unit change, phase transition, unit defeat, and battle reset.
- Preserve mouse and keyboard operation, current action locks, preview/confirm/cancel flows, and readable information without requiring more than hover/focus or one click.

## Proposed component boundaries

| Component | Responsibility | Must not own |
|---|---|---|
| `battle_unit_view` | Character figure, slot identity, HP, role/status iconology, active/hover/target visual states | Combat state mutation |
| `battle_turn_order_ribbon` | Queue presentation, `NOW` frame, hover/focus intent keyed by stable unit ID | Turn advancement |
| `battle_action_bar` | Skill presentation, compact Attack/Swap actions, tooltips, enabled/selected states | Target validation or action resolution |
| `battle_debug_drawer` | Collapsed handle, overlay visibility, log/state/queue rendering, forwarding debug-command intent | Debug damage rules or battle-log storage |
| `battle_visual_state` | Pure resolution of actor, preview, valid, selected, invalid, unavailable, and no-target presentation states with deterministic layer precedence | Target legality, action mutation, or Control-node access |
| `battle_arena` | Authoritative orchestration, state refresh, intent handling, combat APIs | Per-control styling and layout details |

## Task 1: Establish the AC7 test seam and baseline

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Create: `Scripts/UI/battle_ui_snapshot.gd`
- Create: `Tests/Battle/test_ac7_ui_snapshot.gd`
- Reference: `Tests/Battle/test_ac3_4_default_actions.gd`

- [ ] **Step 1: Create the task branch and capture the baseline**

Run:

```powershell
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c feature/ac7-battle-ui-presentation
```

Expected: the branch is created from the current remote `main`. Commit or otherwise preserve the AC7 spec and this plan as relevant inputs; stash unrelated local work and restore it only after the task branch is ready.

- [ ] **Step 2: Run the existing battle regression baseline**

Use GodotIQ to run the project and verify that the battle scene starts. Then run every existing Battle `SceneTree` runner:

```powershell
$battle_tests = Get-ChildItem -LiteralPath Tests/Battle -Filter 'test_*.gd' -File | Sort-Object Name
foreach ($battle_test in $battle_tests) {
  & godot --headless --path . --script ('res://' + ($battle_test.FullName.Substring((Get-Location).Path.Length + 1) -replace '\\','/'))
  if ($LASTEXITCODE -ne 0) { throw "Battle test failed: $($battle_test.Name)" }
}
```

Expected: the project reaches the battle screen and all pre-existing Battle tests pass. Record any pre-existing failure before changing code.

- [ ] **Step 3: Write a failing snapshot contract test**

Create `test_ac7_ui_snapshot.gd` covering a typed read-only presentation snapshot with at least:

- current round and phase label;
- stable current-unit ID;
- ordered stable unit IDs for the visible turn queue;
- selected action and target IDs;
- a monotonically increasing revision or equivalent refresh discriminator.

Expected: FAIL because `BattleUiSnapshot` and the arena snapshot factory do not exist.

- [ ] **Step 4: Add the minimal typed snapshot model and arena factory**

Before editing, inspect both files with GodotIQ `file_context`; run `impact_check` for the new public factory. Implement `BattleUiSnapshot` as a typed `RefCounted` value object and add a small `BattleArena.get_ui_snapshot()` factory that reads existing authoritative state without changing it.

- [ ] **Step 5: Validate and make the snapshot test pass**

Run GodotIQ `validate(target=file, detail="brief")` and `check_errors(scope=file)` after each script change, then run `test_ac7_ui_snapshot.gd`.

Expected: PASS; repeated reads without state changes are equivalent, and an authoritative state change produces an updated snapshot/revision.

- [ ] **Step 6: Commit the seam**

```powershell
git add Scripts/UI/battle_ui_snapshot.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac7_ui_snapshot.gd
git commit -m "feat(battle-ui): add typed presentation snapshot"
```

## Task 2: AC7.1 — Build Living Lanes character views

**Files:**

- Create: `Scenes/UI/battle_unit_view.tscn`
- Create: `Scripts/UI/battle_unit_view.gd`
- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Create: `Tests/Battle/test_ac7_1_living_lanes.gd`

- [ ] **Step 1: Write the failing living-lanes test**

Test that the arena exposes two visually distinct sides, each with explicit backline/frontline lanes; all 12 formation slots remain addressable; an occupied unit view renders identity, HP, role, and current statuses; and empty slots remain visibly identifiable.

Expected: FAIL because the reusable unit view and required lane hierarchy are absent.

- [ ] **Step 2: Create the reusable unit-view controller**

After `file_context`, implement typed render methods for identity, HP, role/status icons, and these independent visual flags: `is_current`, `is_hovered_from_turn_order`, `is_selected`, `is_valid_target`, `is_defeated`. Define an explicit priority so hover never hides target/defeated information.

- [ ] **Step 3: Build the unit-view scene**

Use GodotIQ scene operations to create the character-forward Control scene. Include a portrait/figure area, name, HP bar/value, role marker, compact status-icon row, slot/lane marker, and layered state borders. Use theme overrides/resources rather than duplicated per-node styling.

- [ ] **Step 4: Recompose the arena formation**

Use `scene_map` before edits. Replace only the current formation presentation containers with four readable lanes: player backline/frontline and enemy frontline/backline. Preserve the existing formation-slot IDs and click targets so combat selection behavior does not change.

- [ ] **Step 5: Bind authoritative states to views**

Update `battle_arena.gd` minimally: instantiate/map unit views by stable unit ID and slot ID, feed their render state during the existing UI refresh, and forward unit clicks into the existing selection/targeting handlers.

- [ ] **Step 6: Verify AC7.1**

Run the new test, then the existing formation, damage/defeat/log, skills, and default-actions tests.

Expected: all pass; defeated/empty/occupied slots remain distinguishable and combat behavior is unchanged.

- [ ] **Step 7: Perform the first visual tour**

Run the battle scene with GodotIQ and use `explore(mode="tour")`. Verify at the project's reference viewport and one smaller viewport that characters do not overlap, lanes read immediately, and HP/status data is legible. Fix issues and tour again.

- [ ] **Step 8: Commit AC7.1**

```powershell
git add Scenes/UI/battle_unit_view.tscn Scripts/UI/battle_unit_view.gd Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac7_1_living_lanes.gd
git commit -m "feat(battle-ui): present formations as living lanes"
```

## Task 3: AC7.2 — Add the interactive turn-order ribbon

**Files:**

- Create: `Scenes/UI/battle_turn_order_ribbon.tscn`
- Create: `Scripts/UI/battle_turn_order_ribbon.gd`
- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Scripts/UI/battle_unit_view.gd`
- Create: `Tests/Battle/test_ac7_2_turn_order_ribbon.gd`

- [ ] **Step 1: Write the failing ribbon behavior tests**

Cover queue order, active-unit `NOW` state, persistent high-contrast active border, hover linkage, keyboard-focus linkage, restoration on exit/focus loss, missing/defeated-unit safety, and refresh after turn advancement.

Expected: FAIL because the ribbon does not exist.

- [ ] **Step 2: Implement the ribbon as a presentation-only controller**

After `file_context`, add typed rendering from ordered stable unit IDs. Emit hover/focus intent such as `unit_preview_changed(unit_id, active)` and activation intent if clicking an entry is useful for inspection. Do not advance turns or select combat targets inside the ribbon.

- [ ] **Step 3: Build and integrate the ribbon scene**

Use GodotIQ scene operations to place the ribbon at the top of the battle viewport. Each entry must expose portrait/icon, short name, and accessibility text; the current entry must use more than color alone (`NOW`, border, scale/shape treatment).

- [ ] **Step 4: Link ribbon intent to battlefield highlighting**

In `BattleArena`, resolve the stable ID to the mapped `battle_unit_view`, set the hover/focus visual flag, and clear only that transient flag when preview ends. Preserve active, selected, valid-target, and defeated layers.

- [ ] **Step 5: Verify AC7.2 and regressions**

Run `test_ac7_2_turn_order_ribbon.gd`, `test_active_turn_skill_lock.gd`, `test_ac2_6_character_skills.gd`, and the complete Battle suite.

Expected: all pass; advancing the turn moves `NOW`, and pointer/keyboard previews highlight exactly one matching battlefield character.

- [ ] **Step 6: Visual and interaction QA**

Use a GodotIQ tour plus close inspection of the current entry and both team formations. Manually verify pointer hover, keyboard focus, rapid movement between entries, defeated entries, and queue refresh.

- [ ] **Step 7: Commit AC7.2**

```powershell
git add Scenes/UI/battle_turn_order_ribbon.tscn Scripts/UI/battle_turn_order_ribbon.gd Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Scripts/UI/battle_unit_view.gd Tests/Battle/test_ac7_2_turn_order_ribbon.gd
git commit -m "feat(battle-ui): add interactive turn order ribbon"
```

## Task 4: AC7.3 — Unify skills with compact Default Attack and Swap

**Files:**

- Create: `Scenes/UI/battle_action_bar.tscn`
- Create: `Scripts/UI/battle_action_bar.gd`
- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Create: `Tests/Battle/test_ac7_3_unified_action_bar.gd`
- Regression: `Tests/Battle/test_ac3_4_default_actions.gd`
- Regression: `Tests/Battle/test_active_turn_skill_lock.gd`

- [ ] **Step 1: Write failing action-bar tests**

Test that character skills use primary full-size controls; Attack and Swap use smaller icon controls; both compact controls expose hover/focus tooltip text and accessible names; selected/disabled/cooldown/resource states are readable; and input delegates to the existing preview/confirm/cancel flows.

Expected: FAIL because the controls are not unified in the new action bar.

- [ ] **Step 2: Implement the action-bar presenter**

After `file_context`, implement rendering from the active unit and action state. Emit only intent events for skill selection, Default Attack, Default Swap, confirm, and cancel. Keep validation, costs, targeting, action locks, and resolution in existing systems.

- [ ] **Step 3: Build the action-bar scene**

Use GodotIQ scene operations to create a bottom bar with a visually dominant skill strip and a separated compact utility cluster for Attack and Swap. Ensure icons have focusable hit targets large enough for input even if their painted glyphs are small.

- [ ] **Step 4: Integrate with existing APIs**

Wire emitted intents to the current battle-arena methods for skill selection, attack preview/confirm, swap preview/confirm, and cancel. Remove or hide superseded duplicate controls so only one action variant is visible at a time.

- [ ] **Step 5: Verify AC7.3 and behavior preservation**

Run the new test plus `test_ac3_4_default_actions.gd`, `test_active_turn_skill_lock.gd`, and `test_ac2_6_character_skills.gd`.

Expected: all pass; action results match the pre-AC7 implementation, while presentation and discoverability meet AC7.3.

- [ ] **Step 6: Visual QA at normal and constrained widths**

Verify no duplicated skill/default-action panels, tooltips remain on-screen, compact icons do not compete with skills, and disabled states remain understandable without color alone.

- [ ] **Step 7: Commit AC7.3**

```powershell
git add Scenes/UI/battle_action_bar.tscn Scripts/UI/battle_action_bar.gd Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac7_3_unified_action_bar.gd
git commit -m "feat(battle-ui): unify skills and default actions"
```

## Task 5: AC7.4 — Add the overlay debug drawer

**Files:**

- Create: `Scenes/UI/battle_debug_drawer.tscn`
- Create: `Scripts/UI/battle_debug_drawer.gd`
- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Create: `Tests/Battle/test_ac7_4_debug_drawer.gd`
- Regression: `Tests/Battle/test_ac2_3_damage_defeat_log.gd`

- [ ] **Step 1: Write failing debug-drawer tests**

Cover collapsed-by-default state, persistent side handle, one-click open/close, overlay behavior without arena reflow, battle-log rendering, live current-unit/round/phase/selection state, initiative queue rendering, existing debug-command forwarding, and state refresh while open.

Expected: FAIL because the debug information is not in a collapsible overlay drawer.

- [ ] **Step 2: Implement the drawer controller**

After `file_context`, add typed methods to render the battle log and UI snapshot. The controller owns visibility and tab/section presentation only. It emits debug-command intent to `BattleArena` and contains no damage or turn logic.

- [ ] **Step 3: Build the overlay scene**

Use GodotIQ scene operations to create a right-edge arrow/chevron handle and an overlay panel with Battle Log, Live State, Initiative Queue, and Commands sections. Ensure the handle remains reachable while collapsed and the panel traps neither battle input nor keyboard focus after closing.

- [ ] **Step 4: Move existing debug presentation into the drawer**

Reparent or replace the current always-visible battle log/debug controls, preserving their authoritative data and commands. Ensure opening the drawer does not resize the arena, turn ribbon, lanes, or action bar.

- [ ] **Step 5: Verify AC7.4 and regressions**

Run `test_ac7_4_debug_drawer.gd`, `test_ac2_3_damage_defeat_log.gd`, and the full Battle suite.

Expected: all pass; logs continue to update while collapsed, and opening shows the latest entries and live state.

- [ ] **Step 6: Visual and input QA**

Tour collapsed and expanded states. Check overlay opacity/readability, scroll behavior, escape/close handling, side-handle alignment, tooltip conflicts, and interaction after repeated open/close cycles.

- [ ] **Step 7: Commit AC7.4**

```powershell
git add Scenes/UI/battle_debug_drawer.tscn Scripts/UI/battle_debug_drawer.gd Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac7_4_debug_drawer.gd
git commit -m "feat(battle-ui): add overlay debug drawer"
```

## Task 6: AC7.5 — Establish the battle visual-state language

**Files:**

- Create: `Scripts/UI/battle_visual_state.gd`
- Modify: `Scripts/UI/battle_unit_view.gd`
- Modify: `Scripts/UI/battle_action_bar.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Scenes/UI/battle_unit_view.tscn`
- Modify: `Scenes/UI/battle_action_bar.tscn`
- Create: `Tests/Battle/test_ac7_5_battle_visual_states.gd`

- [ ] **Step 1: Write the failing visual-state matrix tests**

Create table-driven cases for neutral, current actor, turn-order hover/focus, hovered-skill valid target, selected-action valid target, selected target, Attack target, Swap target, invalid target, defeated/untargetable unit, and action-with-no-legal-target. Include overlapping cases: current actor plus self-target, valid plus selected target, defeated former target, and turn-order preview while an action is selected.

Expected: FAIL because no centralized resolver or typed layered presentation model exists.

- [ ] **Step 2: Define the pure presentation model and precedence rules**

After GodotIQ `file_context`, create a typed `BattleVisualState` `RefCounted` model/resolver with independent fields for `actor_frame`, `interaction_spotlight`, `target_border`, `target_glyph`, `selection_marker`, `availability_treatment`, and `reason_text`. Resolve them with these rules:

1. Defeated/untargetable availability suppresses all target borders, glyphs, and selection markers.
2. Confirmed selection replaces the valid-target inner border with a stronger reticle/check marker.
3. Current actor remains a separate outer frame, including legal self-target cases.
4. Hover/focus preview is transient and never replaces committed selected-action state.
5. Attack and Swap use distinct glyphs and accessible labels; color is supplementary.

Keep legality as an input from existing combat APIs. The resolver must not calculate ranges, adjacency, costs, cooldowns, or requirements.

- [ ] **Step 3: Make the matrix tests pass**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac7_5_battle_visual_states.gd
```

Expected: PASS for every single and overlapping state case.

- [ ] **Step 4: Render layered unit states**

Update `battle_unit_view.gd` and its scene so outer actor frame, transient spotlight, inner target border/glyph, selected reticle, and unavailable treatment have separate nodes. Ensure setting or clearing one channel cannot erase another. Add text/icon equivalents and accessible descriptions for every critical state.

- [ ] **Step 5: Add skill-hover previews without mutating selection**

Update the action bar to emit preview-start/preview-end intent keyed by action ID for pointer hover and keyboard focus. In `BattleArena`, ask the existing targeting system for legal targets and feed those IDs to the resolver without selecting the action. If an action is already selected, preserve its battlefield state and limit other-action hover to tooltip presentation.

- [ ] **Step 6: Represent unavailable actions and no-target reasons**

Render an unavailable action as non-activatable with a prohibition marker and a specific primary reason selected from the authoritative failure result: `No legal targets`, `Wrong turn`, `Insufficient resource`, `On cooldown`, `Requirement not met`, or `Actor unavailable`. Do not infer these reasons from UI state.

- [ ] **Step 7: Wire deterministic cleanup boundaries**

Clear preview state on pointer exit and focus loss. Clear preview and committed selection on cancel, confirmation, active-unit change, phase transition, relevant unit defeat, and battle reset. Refresh all affected views in one pass so no frame displays a mixture of old and new turn state.

- [ ] **Step 8: Verify interaction behavior and regressions**

Run the AC7.5 test, AC7.2 ribbon test, AC7.3 action-bar test, `test_ac3_4_default_actions.gd`, `test_active_turn_skill_lock.gd`, and `test_ac2_6_character_skills.gd`.

Expected: all pass; hover/focus is observational, selection remains authoritative, and no stale state survives any cleanup boundary.

- [ ] **Step 9: Perform visual QA of the state matrix**

At 1152×648, capture and inspect current actor, turn-order preview, skill-hover preview, selected skill targets, selected target, Attack targets, Swap targets, no-valid-target action, defeated target cleanup, and legal self-target overlap. Repeat hover cases with keyboard focus and verify equivalent feedback.

- [ ] **Step 10: Commit AC7.5**

```powershell
git add Scripts/UI/battle_visual_state.gd Scripts/UI/battle_unit_view.gd Scripts/UI/battle_action_bar.gd Scripts/Battle/battle_arena.gd Scenes/UI/battle_unit_view.tscn Scenes/UI/battle_action_bar.tscn Tests/Battle/test_ac7_5_battle_visual_states.gd
git commit -m "feat(battle-ui): unify battle visual states"
```

## Task 7: Responsive polish, accessibility, and final acceptance gate

**Files:**

- Modify as required: `Scenes/UI/battle_unit_view.tscn`
- Modify as required: `Scenes/UI/battle_turn_order_ribbon.tscn`
- Modify as required: `Scenes/UI/battle_action_bar.tscn`
- Modify as required: `Scenes/UI/battle_debug_drawer.tscn`
- Modify as required: corresponding `Scripts/UI/*.gd`
- Modify: `docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `docs/verification/ac7-battle-ui-presentation.md`

- [ ] **Step 1: Run project-wide static checks**

Use GodotIQ `validate(target="project")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`.

Expected: no new convention, parser, compilation, or orphan-signal failures.

- [ ] **Step 2: Run the complete automated acceptance set**

Run all AC7 tests and the complete set of Battle `SceneTree` runners, including AC2.3, AC2.6, AC3.4, and active-turn locking.

Expected: zero failures. Save command output or a concise run record in the verification document.

- [ ] **Step 3: Execute the runtime verification recipe**

Use GodotIQ in this order: `run(action="play")` → `verify_project_runs()` → `read_debug_console()` → relevant `state_inspect` checks → one screenshot per verification state → `run(action="stop")`.

Capture evidence for:

1. Living Lanes with occupied, empty, statused, and defeated states.
2. Current turn framed with `NOW` and the matching unit highlighted through pointer hover.
3. The same linkage through keyboard focus.
4. Skills plus compact Attack and Swap, with tooltips and no duplicate action panels.
5. Debug drawer collapsed, expanded, populated, and closed without layout shift.
6. The complete AC7.5 state matrix, including skill-hover preview, selected targets, Attack/Swap differentiation, a no-legal-target reason, and legal self-target overlap.

- [ ] **Step 4: Check responsive and accessibility criteria**

At the reference viewport and one smaller supported viewport, verify no overlap/clipping, keyboard reachability, visible focus, readable contrast, text/icon redundancy for critical states, and no tooltip escaping the viewport.

- [ ] **Step 5: Record traceability evidence**

In `docs/verification/ac7-battle-ui-presentation.md`, map each AC7 criterion to its automated test, manual/runtime check, result, and evidence location. Update the MVP spec verification status only from collected evidence; do not mark an AC complete from implementation alone.

- [ ] **Step 6: Review the final diff and commit evidence/docs**

```powershell
git diff --check
git status --short
git add docs/Specs/GAME_DESIGN_SPEC_MVP.md docs/verification/ac7-battle-ui-presentation.md
git commit -m "docs(mvp): record AC7 battle UI verification"
```

Expected: only AC7 implementation, tests, and evidence are present on the task branch.

## Acceptance traceability matrix

| Criterion | Automated evidence | Runtime/manual evidence | Current baseline |
|---|---|---|---|
| AC7.1 Living Lanes | `test_ac7_1_living_lanes.gd` plus formation/combat regressions | Visual tour of all four lanes and unit states | PARTIAL: formation slots and HP exist; character-forward lanes do not |
| AC7.2 Turn Order Ribbon | `test_ac7_2_turn_order_ribbon.gd` plus turn-lock regressions | Pointer and keyboard linkage captures | PARTIAL: queue data exists; ribbon, `NOW` frame, and linked highlight do not |
| AC7.3 Unified Action Bar | `test_ac7_3_unified_action_bar.gd` plus skills/default-action regressions | Tooltip, constrained-width, and duplicate-panel checks | PARTIAL: mechanics exist in separate presentation areas |
| AC7.4 Debug Drawer | `test_ac7_4_debug_drawer.gd` plus damage/log regression | Collapsed/expanded/no-reflow captures | PARTIAL: log/debug controls exist but are always visible |
| AC7.5 Battle Visual State Language | `test_ac7_5_battle_visual_states.gd` plus ribbon, skill, default-action, and turn-lock regressions | Pointer/keyboard state-matrix captures and cleanup checks | PARTIAL: several highlights exist, but there is no centralized precedence, hover-target preview, no-target reason system, or exhaustive cleanup contract |

## Definition of done

- AC7.1–AC7.5 each have passing automated coverage and recorded runtime evidence.
- Existing AC2 and AC3 battle tests remain green.
- The UI exposes all essential combat information through direct visibility, hover/focus, or one click.
- Pointer and keyboard users receive equivalent turn-order highlighting and tooltip information.
- Current actor, preview, valid target, selected target, Attack target, Swap target, and unavailable states remain distinguishable in isolation and permitted combinations without relying on color alone.
- Hover previews never mutate committed action selection, unavailable actions explain their primary reason, and no stale highlight survives a cleanup boundary.
- Default Attack and Default Swap retain their existing rules and are not confused with a newly invented Move action.
- No superseded battle/action/debug UI remains visible alongside the new components.
- Godot reports no new parser/runtime errors or orphaned signals.
- The MVP specification is updated only with evidence-backed status.
