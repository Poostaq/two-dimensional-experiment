# AC2.8 Skill Targeting and Execution Design

**Status:** Approved

**Acceptance criterion:** AC2.8 — Skills support positional requirements, condition requirements, and either pre-use cooldowns or cooldowns applied after use.

## Goal

Make all six current active fixture skills executable through an explicit preview, targeting, and confirmation flow. The system must distinguish freely selectable targets from predefined targets, communicate valid and invalid choices before commitment, enforce typed requirements and cooldowns, and resolve each confirmed action exactly once.

## Scope

AC2.8 includes:

- Typed mechanical definitions for targeting, effects, requirements, and cooldowns.
- Free targeting for Shield Bash, Quick Strike, and Savage Blow.
- Predefined targeting for Quick Step, Rally, and Shadow Lunge.
- Skill-hover previews that identify candidate or affected units.
- A targeting mode with valid, invalid, and locked-target presentation states.
- Contextual targeting messages and Confirm/Cancel controls inside the existing skill panel.
- Execution of all six current active fixture skills.
- Positional, health, pre-use cooldown, and post-use cooldown enforcement.
- Per-skill runtime cooldown state and temporary Speed modifiers.
- Fresh validation at confirmation time, deterministic resolution, battle logging, turn advancement, defeat handling, and result integration.
- Focused automated coverage, AC2.1–AC2.7 regressions, and manual runtime evidence.

AC2.8 excludes:

- Executable passive effects; passive skills remain inspectable and non-actionable.
- Combo conditions and combo bonuses, which belong to AC2.9.
- Default attack and adjacent-swap actions, which belong to AC3.7.
- Animation, audio, final visual polish, balancing, localization, persistence, and serialization.
- Player-controlled enemy actions; enemy skills remain inspectable but cannot be executed by the player.

## Architecture

`CharacterSkill` retains its existing identity, classification, and player-facing description fields and gains typed mechanical data. Battle logic must never parse `effect_text`, `targeting_text`, `requirements_text`, or `cooldown_text`; those strings remain presentation data.

`BattleUnitState` owns mutable per-unit combat state: skill cooldown counters and temporary Speed modifiers. Its existing defensive skill-copying contract remains intact.

A focused skill rules/resolution unit owns candidate calculation, requirement checks, confirmation validation, effect application, and cooldown application. Its interfaces return structured results rather than mutating UI. This keeps targeting and mechanics independently testable and prevents `BattleArena` from becoming the only rules container.

`BattleArena` owns the interaction transaction: hovered skill preview, selected skill, targeting mode, locked targets, contextual messages, confirmation/cancellation, visual indicators, and lifecycle cleanup. It delegates rule evaluation and effect resolution, then uses the established damage, defeat, battle-log, turn, and battle-result paths.

## Typed skill contract

Each active `CharacterSkill` definition carries typed values sufficient to answer these questions without inspecting display text:

- Is the skill active or passive?
- Is its target freely selected or predefined?
- Which side can it target?
- How many targets are required, or which deterministic target rule applies?
- Which position and state requirements apply to the user or target?
- Which effect and magnitude are resolved?
- Is availability gated before use, and what cooldown is applied after use?

The implementation may express these values through enums and focused definition objects, but invalid combinations must be rejected at creation time. Examples of invalid definitions include a passive skill with an executable effect, a free-target skill requiring zero targets, an all-allies rule with enemy allegiance, and a negative cooldown duration.

The existing read-only and defensive-duplication behavior must cover every new typed field. Caller mutation cannot change a skill stored on a `BattleUnitState`.

## Exact active-skill behavior

| Skill | Targeting | Requirement | Effect | Cooldown |
|---|---|---|---|---|
| Shield Bash | Freely select one active enemy | User occupies a front-row slot | Deal 7 damage | Apply 1 action after use |
| Quick Step | Predefined self | None | Gain 2 Speed until the end of the user's next turn | Apply 2 actions after use |
| Quick Strike | Freely select one active enemy | None | Deal 5 damage | None |
| Rally | Predefined all active allies, including user | None | Each target gains 2 Speed until the end of the current round | Apply 2 actions after use |
| Savage Blow | Freely select one active enemy | User is above 50% HP | Deal 12 damage | Apply 2 actions after use |
| Shadow Lunge | Predefined farthest active enemy | User occupies a back-row slot | Deal 10 damage | Unavailable during round 1; no cooldown after use |

“Above 50% HP” is strict: `current_hp * 2 > max_hp`. Exactly 50% is invalid.

Front-row slots are semantic indices 0–2 and back-row slots are indices 3–5. Defeated or invalid units are never valid targets.

Shadow Lunge chooses the active enemy with the greatest row distance from the user (`abs((target.slot_index % 3) - (user.slot_index % 3))`). Ties prefer a back-row target over a front-row target, then the highest semantic slot index. Automated tests lock this ordering explicitly.

## Cooldown and duration semantics

Cooldown counters represent future successfully confirmed battle actions that must elapse before the skill becomes ready.

- Cooldowns decrement once after every successfully confirmed battle action.
- A cooldown applied by the action currently resolving does not decrement during that same action.
- Hover, selection, invalid clicks, cancellation, rejected confirmation, and non-action inspection do not decrement cooldowns.
- A skill is ready when its post-use counter is zero and any pre-use gate is satisfied.
- Shadow Lunge's pre-use gate is derived from battle round state and does not create a post-use counter.

Quick Step's Speed bonus expires after the affected unit completes its next action. Rally's Speed bonus expires when the current round ends. Temporary bonuses stack additively when their independent sources overlap, and each source expires according to its own duration.

Whenever Speed changes, only the unresolved portion of the current round queue is rebuilt. Units that already acted do not act again, and no active unresolved unit is dropped. The current action completes before the rebuilt order becomes authoritative.

## Skill-hover preview

Hovering an active skill previews targeting without entering targeting mode or mutating battle state.

For freely selectable skills:

- Every valid candidate receives a green border and a soft radial green tint strongest at the character center and fading toward the border.
- Every invalid candidate on the relevant target side receives the corresponding red border and soft radial red tint.
- Units on the irrelevant side remain neutral.

For predefined skills:

- The exact units that would be affected receive the green border and radial green tint.
- Unaffected units remain neutral.
- A self-target therefore highlights only the user; Rally highlights every active ally; Shadow Lunge highlights only the deterministically calculated farthest active enemy.

If the skill itself is unusable because of position, condition, cooldown, battle completion, ownership, or current-turn state, hover still previews its would-be target rule. The tooltip and contextual reason communicate why use is blocked. Leaving the skill removes all preview-only indicators.

Passive skill hover preserves the AC2.7 description tooltip but never creates executable targeting indicators.

## Targeting and confirmation flow

Only the current active player unit may begin an active-skill transaction.

### Starting a usable free-target skill

1. Clicking the skill clears its broad hover preview.
2. The arena enters targeting mode for that skill and acting unit.
3. The skill panel displays `Select a target for <skill>.` plus Confirm and Cancel.
4. Confirm begins disabled because no target is locked.
5. Other skill buttons remain visible but are disabled for the duration of the transaction.

While free targeting:

- Hovering a valid candidate shows a green border only.
- Hovering an invalid candidate shows a red border plus the radial red center tint.
- Leaving a candidate restores its neutral state unless it is locked.
- Clicking an invalid candidate does not lock it, enable Confirm, or mutate battle state; the panel shows `Invalid target` with the concrete reason.
- Clicking a valid candidate locks it. The locked unit keeps a green border and gains the radial green center tint.
- Selecting another valid candidate moves the single-target lock.

### Starting a usable predefined-target skill

1. Clicking the skill clears its hover preview.
2. The resolver calculates and locks the complete predefined target set immediately.
3. Every locked target receives the green border and radial green center tint.
4. The skill panel shows an action summary naming the skill and affected target or targets.
5. Confirm is enabled when the calculated set remains valid; Cancel is available.

### Confirmation

Confirm performs fresh validation of the acting unit, skill availability, requirements, cooldown, battle state, and complete target set. Validation and resolution are one guarded transaction.

- A valid confirmation resolves the effect exactly once, records the action, applies any post-use cooldown, advances the turn once, refreshes battle results, and returns the panel and formation indicators to their neutral state.
- If state became stale, no partial effect is applied. The stale target lock is cleared, Confirm is disabled, and the skill panel displays the exact reason so the player can retarget or cancel.
- Repeated confirmation input while resolution is active is ignored.

Cancel clears the selected action, target locks, hover state, contextual messages, and action controls without changing HP, Speed, cooldowns, turn order, logs, or battle result.

### Clicking an unusable skill

An unusable skill does not enter targeting mode. The skill panel temporarily displays the concrete blocking reason, such as:

- `Requires a front-row position.`
- `Requires more than 50% HP.`
- `Ready in 2 actions.`
- `Unavailable during round 1.`
- `Only the current player unit can act.`

The ordinary skill layout remains visible. Confirm and Cancel are hidden because no transaction exists.

## Skill-panel presentation

The existing scene-owned skill panel remains the single surface for inspection and action control. It gains a contextual action region containing:

- A targeting or blocking message.
- A selected-action summary.
- Confirm and Cancel buttons.

The contextual region is hidden during ordinary inspection. Individual labels and buttons are visible only when their state requires them:

- Targeting message and Cancel appear during an active transaction.
- Confirm appears during an active transaction and is disabled until the target set is complete and valid.
- Blocking feedback appears after an unusable skill click and clears on the next relevant selection, inspection change, or lifecycle reset.
- The action summary appears only after a valid target set is locked.

Skill buttons remain visible. During targeting, unrelated skill buttons are disabled so a second skill cannot replace an active transaction accidentally.

## Indicator presentation

Targeting visuals are overlays on formation slots rather than replacements for existing slot content.

| State | Border | Center tint | Persistence |
|---|---|---|---|
| Hover preview: valid | Green | Soft radial green | Until skill hover exits |
| Hover preview: invalid | Red | Soft radial red | Until skill hover exits |
| Targeting hover: valid | Green | None | Until unit hover exits |
| Targeting hover: invalid | Red | Soft radial red | Until unit hover exits |
| Locked target | Green | Soft radial green | Until retarget, cancel, rejection, or resolution |
| Neutral | Existing slot style | None | Default |

The green/red treatments must remain distinguishable where practical without color alone, through border treatment, status text, or another accessible cue. Targeting overlays must coexist predictably with current-turn, attacker, receiver, and defeated presentation and must not obscure names, HP, or status.

## Effect resolution and battle integration

Damage effects use the established HP clamping, feedback, defeat, target exclusion, battle-log, and result-evaluation paths. A multi-target action produces one logical skill action while recording enough receiver information for deterministic inspection and testing.

Speed effects update effective Speed without overwriting the unit's base Speed. Queue rebuilding follows the cooldown and duration rules above. Expiration refreshes effective Speed and the unresolved queue using the same deterministic ordering.

Every confirmed skill consumes the acting unit's one active action for the turn. No other action may resolve from that unit during the same turn.

## Lifecycle and defensive behavior

- Changing the inspected character cancels an active targeting transaction and clears all indicators.
- Hover exit clears preview-only indicators but never clears a locked target.
- Battle completion, arena reconfiguration, exit, and new-battle setup clear all skill-action state.
- Removing, defeating, or invalidating the acting unit cancels its transaction.
- Removing, defeating, or invalidating a locked target forces fresh validation; confirmation cannot resolve against stale state.
- Rapid hover changes and stale deferred callbacks cannot restore superseded indicators.
- Foreign skill IDs, foreign unit IDs, duplicate target IDs, and incomplete target sets are rejected.
- Enemy, defeated, non-current, and passive skill selections remain inspectable but cannot start a player action.
- All rejected and cancelled paths are mutation-free for combat state.
- Confirmation and resolution are idempotent while an action is in progress.

## Verification strategy

### Automated coverage

Create a focused AC2.8 test runner that verifies:

- Valid typed mechanical definitions survive defensive copying.
- Every invalid enum combination, negative cooldown, impossible target count, and mismatched allegiance/rule definition is rejected.
- All six active fixtures match the exact behavior table.
- Shield Bash, Quick Strike, and Savage Blow calculate the same free-target candidate sets and accept only one active enemy.
- Quick Step locks self, Rally locks all active allies including the user, and Shadow Lunge deterministically locks the farthest active enemy.
- Defeated, invalid, foreign-side, and otherwise ineligible units are excluded or marked invalid as appropriate.
- Front/back row requirements use semantic slot indices.
- Savage Blow accepts above 50% HP and rejects exactly or below 50%.
- Shadow Lunge is unavailable in round 1 and ready from round 2 onward.
- Post-use cooldowns apply after resolution, do not tick immediately, tick once per later confirmed action, and reach ready state at zero.
- Hover previews produce exact valid, invalid, affected, and neutral indicator states without battle mutation.
- Starting free targeting clears the broad preview, shows contextual controls, and disables Confirm.
- Valid and invalid unit hover use their exact indicator contracts.
- Invalid clicks do not lock or mutate; valid clicks lock exactly one target and enable Confirm.
- Predefined skills lock their complete target sets immediately.
- Cancel is mutation-free and clears every transient UI state.
- Confirmation revalidates stale target, requirement, cooldown, and battle state.
- Every valid action resolves its exact effect once, advances once, logs once, and applies its cooldown once.
- Quick Step and Rally Speed modifiers expire at their defined boundaries.
- Speed changes rebuild only unresolved queue entries without duplicates or omissions.
- Damage integrates with defeat, target removal, battle result, and existing feedback behavior.
- Inspection change, defeat, battle completion, reconfiguration, exit, and new battle clear transient state.
- Passive, enemy, defeated, and non-current skills cannot start an action.
- Contextual messages and buttons are hidden when not needed.

Run the focused AC2.1 through AC2.7 runners as regressions after AC2.8 passes.

### Manual runtime coverage

At the 1152×648 target viewport:

1. Hover every active skill and verify its free-candidate or exact predefined-target preview.
2. Confirm green and red preview borders and radial center tints remain readable without obscuring unit information.
3. Start a free-target skill and verify the broad preview disappears, the same skill panel shows the targeting message and contextual buttons, and Confirm is disabled.
4. Hover valid and invalid candidates and verify their distinct targeting-mode treatments.
5. Click an invalid candidate and verify the exact reason appears without mutation.
6. Lock and retarget a valid candidate, verifying only the current lock retains the green border and center tint.
7. Start every predefined skill and verify the complete affected target set locks immediately.
8. Cancel both targeting styles and verify complete cleanup without mutation.
9. Confirm all six active skills and verify exact damage or Speed effects, one log/action/turn advance, cooldown timing, modifier expiration, and queue behavior.
10. Exercise front/back, HP, round-1, cooldown, ownership, passive, defeated, and battle-complete rejection paths.
11. Invalidate a locked target before confirmation and verify stale resolution is rejected safely.
12. Verify targeting messages, action summaries, Confirm, Cancel, and blocking reasons appear only when needed inside the existing skill panel.
13. Verify the panel and indicators remain inside the viewport with no clipping, overlap, or stale presentation.

Record the automated log, manual runtime record, and tested implementation commit under `Docs/Specs/AC2/Evidence/AC2.8/<verification-date>/`. All evidence must identify the same implementation commit.

## Documentation closeout

After the focused runner, regressions, runtime checks, and evidence gates pass:

1. Change the AC2.8 checkbox in `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` from `[ ]` to `[x]`.
2. Replace its manual-only verification row with an automated and manual runtime contract naming free/predefined targeting, target previews and locks, confirmation/cancellation, requirements, pre/post cooldowns, all six active effects, temporary Speed behavior, lifecycle cleanup, and target-viewport checks.
3. Confirm the MVP document contains exactly one AC2.8 acceptance row and one AC2.8 verification row.
4. Keep AC2.9 unchecked and do not claim combo behavior.

## Completion boundary

AC2.8 is complete when all six current active fixture skills execute through the approved hover, targeting, lock, Confirm/Cancel, and resolution flow; typed rules enforce every target, position, condition, and cooldown contract; invalid or stale actions remain mutation-free; cooldown and temporary Speed state behave deterministically; existing battle systems and AC2.1–AC2.7 regressions remain green; matching evidence is recorded against one tested implementation commit; and the MVP acceptance and verification rows are formally closed. Passive effects, combo bonuses, default actions, and final production presentation remain outside this criterion.
