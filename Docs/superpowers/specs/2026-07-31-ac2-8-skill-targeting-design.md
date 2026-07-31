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

### Implementation-detail non-goals

AC2.8 specifies gameplay rules, transaction safety, data boundaries needed for deterministic verification, and the minimum targeting feedback required for player comprehension. It does not require a particular number of scripts, exact class filenames, animation system, shader implementation, particle treatment, audio cue, transition timing, or production-art style. Architectural seams in this document constrain responsibility and mutation safety; equivalent implementation structures satisfy the criterion when all observable contracts and tests pass.

## Architecture

`CharacterSkill` retains its existing identity, classification, and player-facing description fields and gains typed mechanical data. Battle logic must never parse `effect_text`, `targeting_text`, `requirements_text`, or `cooldown_text`; those strings remain presentation data.

`BattleUnitState` owns mutable per-unit combat state: skill cooldown counters and temporary Speed modifiers. Its existing defensive skill-copying contract remains intact.

A focused skill rules/resolution unit owns candidate calculation, requirement checks, confirmation validation, effect application, and cooldown application. Its interfaces return structured results rather than mutating UI. This keeps targeting and mechanics independently testable and prevents `BattleArena` from becoming the only rules container.

`BattleArena` owns the interaction transaction: hovered skill preview, selected skill, targeting mode, locked targets, contextual messages, confirmation/cancellation, visual indicators, and lifecycle cleanup. It delegates rule evaluation and effect resolution, then uses the established damage, defeat, battle-log, turn, and battle-result paths.

## Implementation seams and mutation ownership

These seams describe the intended separation of responsibilities. Equivalent names and file boundaries are acceptable when they preserve the contracts and observable behavior; the physical module layout is not itself an AC2.8 acceptance requirement.

| Seam | Likely responsibility | Mutation authority |
|---|---|---|
| Skill data / typed contract | `CharacterSkill` identity, authored description, targeting mode, target rule, requirements, effect definition, and cooldown definition | Construction-time validation and defensive copying only |
| Rules evaluation | Pure target-candidate evaluation, blocking-reason evaluation, target-lock validation, and effect-plan construction | None; reports structured state only |
| Battle transaction orchestration | Interaction state, generation token, selected actor/skill, locked targets, confirm de-duplication, cancellation, and stale rejection | Transient transaction state only |
| UI presentation and indicators | Skill-panel messages/buttons and formation-slot preview, hover, invalid, and locked visuals | Control presentation only; never combat state |
| Battle integration and logging | Apply an accepted effect plan through damage, Speed, cooldown, queue, log, turn, defeat, and result paths | Sole authority for committed combat mutation |

Rules evaluation must remain callable without scene nodes. UI presentation consumes snapshots/results and never determines whether an action is legal.

### Runtime UI wiring

Skill-button hover/exit and press events, formation-slot hover/exit and press events, and Confirm/Cancel button presses are forwarded from `BattleArena` controls to the transaction orchestrator as ID-based commands. The orchestrator evaluates rules, changes transaction state, and publishes one presentation snapshot containing the state, generation, message, button visibility/enabled state, and per-unit indicator roles. `BattleArena` renders that snapshot into the existing skill panel and formation slots. Confirmed effect plans travel in the opposite direction through the guarded battle-integration seam; scene controls never call damage, Speed, cooldown, queue, log, or result mutation directly. Authoritative battle-change notifications then return to the orchestrator for stale reevaluation and a fresh presentation snapshot.

## Transaction state model

One arena owns at most one skill interaction transaction. The explicit states are:

- `IDLE` — no skill preview or action transaction.
- `PREVIEWING` — a skill is hovered; target indicators are advisory and no action is selected.
- `TARGETING` — an executable skill is selected; free targets await a lock or predefined targets are already locked and awaiting confirmation.
- `VALIDATING` — confirmation has been accepted for processing and fresh validation is running; further clicks are ignored.
- `RESOLVING` — an accepted immutable effect plan is being applied; further action input is ignored.
- `CANCELLED` — a transient cleanup state entered after explicit or lifecycle cancellation; cleanup completes before transition to `IDLE`.
- `REJECTED_STALE` — validation or authoritative state observation invalidated the transaction; no effect was applied and a concrete reason is visible.

Allowed transitions are:

| Event | Current state | Result |
|---|---|---|
| Active-skill hover enters | `IDLE` | Evaluate preview, increment generation, enter `PREVIEWING` |
| Skill hover changes | `PREVIEWING` | Replace preview under a new generation; remain `PREVIEWING` |
| Skill hover exits | `PREVIEWING` | Clear preview and enter `IDLE` |
| Usable active skill clicked | `IDLE` or matching `PREVIEWING` | Clear preview, create transaction, enter `TARGETING` |
| Unusable active skill clicked | `IDLE` or `PREVIEWING` | Clear preview, remain `IDLE`, show blocking reason; no transaction exists |
| Passive, enemy-owned, defeated, or non-current skill clicked | `IDLE` or `PREVIEWING` | Remain non-actionable, show exact blocking reason, never enter `TARGETING` |
| Candidate hovered/exited | `TARGETING` | Update hover-only indicator under the transaction generation; remain `TARGETING` |
| Valid free target clicked | `TARGETING` | Replace target lock and remain `TARGETING` |
| Invalid target clicked | `TARGETING` | Preserve existing valid lock, show invalid-target reason, remain `TARGETING` |
| Confirm clicked with complete lock | `TARGETING` | Latch confirmation and enter `VALIDATING` |
| Validation succeeds | `VALIDATING` | Freeze the returned effect plan and enter `RESOLVING` |
| Validation fails | `VALIDATING` | Clear lock, preserve reason, enter `REJECTED_STALE` |
| Resolution succeeds | `RESOLVING` | Clear transaction and enter `IDLE` after one committed action |
| Cancel clicked | `TARGETING` or `REJECTED_STALE` | Enter `CANCELLED`, clear transient state, then `IDLE` |
| Authoritative invalidation observed | `TARGETING` | Clear lock immediately and enter `REJECTED_STALE` |
| New inspected unit selected | `PREVIEWING`, `TARGETING`, or `REJECTED_STALE` | Cancel/clear transaction, then inspect in `IDLE` |
| Battle exit, completion, or reconfiguration | Any non-resolving state | Enter `CANCELLED`, clear, then `IDLE` |
| Any action input | `VALIDATING`, `RESOLVING`, or `CANCELLED` | Ignore it |

Selecting a different skill while a transaction is active does not replace the transaction. Other skill buttons are disabled in `TARGETING`, `VALIDATING`, and `RESOLVING`; synthetic or stale click callbacks are rejected by transaction ID and generation. The player must Cancel before starting another skill.

`CANCELLED` is not a player-visible resting state. `REJECTED_STALE` persists with its reason until the player cancels, selects a new inspected unit, or reselects the same skill to obtain a fresh evaluation.

## Rules and resolution interface contract

The rules layer reports immutable structured results. Concrete implementation may use typed `RefCounted` result classes, but consumers must receive the following exact fields and meanings.

### Target evaluation result

`SkillTargetEvaluation` contains:

- `actor_id: StringName`
- `skill_id: StringName`
- `targeting_mode: CharacterSkill.TargetingMode`
- `can_start: bool`
- `blocking_reason: SkillActionReason` — `NONE` only when `can_start` is true
- `valid_target_ids: Array[StringName]` — selectable candidates for free targeting
- `invalid_targets: Dictionary[StringName, SkillActionReason]` — relevant-side candidates that cannot be selected
- `affected_target_ids: Array[StringName]` — exact predefined targets; empty for free targeting before a lock
- `battle_revision: int` — authoritative revision evaluated

Target ID arrays are unique and deterministic. `can_start` describes actor/skill availability, not whether a free target has already been locked.

### Confirmation validation result

`SkillConfirmationValidation` contains:

- `accepted: bool`
- `reason: SkillActionReason` — `NONE` only when accepted
- `actor_id: StringName`
- `skill_id: StringName`
- `target_ids: Array[StringName]`
- `evaluated_revision: int`
- `effect_plan: SkillEffectPlan` — non-null only when accepted

### Rejection reason

`SkillActionReason` contains:

- `code: SkillActionReason.Code`
- `message: String`
- `actor_id: StringName`
- `skill_id: StringName`
- `target_id: StringName` — empty when the reason is not target-specific

The required codes are `NONE`, `NOT_CURRENT_ACTOR`, `ACTOR_INACTIVE`, `ENEMY_NOT_PLAYER_CONTROLLABLE`, `PASSIVE_NOT_ACTIONABLE`, `BATTLE_COMPLETE`, `POSITION_REQUIRED`, `HEALTH_REQUIRED`, `PRE_USE_COOLDOWN`, `POST_USE_COOLDOWN`, `TARGET_INVALID`, `TARGET_DEFEATED`, `TARGET_REMOVED`, `TARGET_OWNERSHIP_CHANGED`, `ROUND_CHANGED`, `TURN_ORDER_CHANGED`, `SKILL_AVAILABILITY_CHANGED`, and `REVISION_MISMATCH`.

### Effect plan and guarded application

Rules validation builds an immutable `SkillEffectPlan`; it does not apply effects directly. The plan contains:

- actor, skill, and ordered target IDs;
- ordered damage operations with exact amounts;
- ordered Speed-modifier operations with amount and expiry boundary;
- post-use cooldown operation when applicable;
- `advance_turn: bool`, which is true for every accepted AC2.8 active skill;
- the authoritative battle revision from which it was built.

Battle integration applies the whole plan inside one guarded transaction. It first verifies the plan revision and transaction latch, then commits ordered operations. If either check fails, it applies nothing. No UI callback may apply individual effect operations directly.

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

Every accepted skill applies its listed effect exactly once, produces one logical action/log record, advances the acting unit's turn exactly once, and participates in defeat and battle-result evaluation. Every blocked, cancelled, stale, or rejected attempt applies no effect and does not advance the turn.

| Skill | Selection and target validity | Blocking reasons | Effect application | Cooldown semantics |
|---|---|---|---|---|
| Shield Bash | Free selection; exactly one active enemy owned by the opposing side | Non-current/inactive actor, enemy ownership, battle complete, user not in semantic front row, missing/invalid/defeated/removed target | Apply 7 damage to the confirmed target | On success set counter to 1 after the current action's tick; unavailable until one later confirmed action elapses |
| Quick Step | Predefined; exactly the active user | Non-current/inactive actor, enemy ownership, battle complete, post-use counter above zero | Add a +2 Speed modifier to self; it expires after the user's next completed action | On success set counter to 2 after the current action's tick; unavailable until two later confirmed actions elapse |
| Quick Strike | Free selection; exactly one active enemy owned by the opposing side | Non-current/inactive actor, enemy ownership, battle complete, missing/invalid/defeated/removed target | Apply 5 damage to the confirmed target | No pre-use gate or post-use counter |
| Rally | Predefined; every active ally including the user, ordered by semantic slot index; at least the active user must be present | Non-current/inactive actor, enemy ownership, battle complete, post-use counter above zero | Add an independent +2 Speed modifier to every locked target; each expires at the end of the current round | On success set counter to 2 after the current action's tick; unavailable until two later confirmed actions elapse |
| Savage Blow | Free selection; exactly one active enemy owned by the opposing side | Non-current/inactive actor, enemy ownership, battle complete, user at or below 50% HP, missing/invalid/defeated/removed target | Apply 12 damage to the confirmed target | On success set counter to 2 after the current action's tick; unavailable until two later confirmed actions elapse |
| Shadow Lunge | Predefined; exactly the deterministic farthest active enemy | Non-current/inactive actor, enemy ownership, battle complete, user not in semantic back row, round 1, or no active enemy | Apply 10 damage to the locked farthest target | Pre-use gate blocks round 1; no post-use counter |

“Above 50% HP” is strict: `current_hp * 2 > max_hp`. Exactly 50% is invalid.

Front-row slots are semantic indices 0–2 and back-row slots are indices 3–5. Defeated or invalid units are never valid targets.

Shadow Lunge chooses the active enemy with the greatest row distance from the user (`abs((target.slot_index % 3) - (user.slot_index % 3))`). Ties prefer a back-row target over a front-row target, then the highest semantic slot index. Automated tests lock this ordering explicitly.

## Minimum automated battle fixture

The focused runner uses a deterministic test-only fixture for mechanics and transaction tests. It reuses the canonical six active `CharacterSkill` definitions without changing the production player/enemy rosters.

| Unit ID | Side | Slot | Speed | HP | Purpose |
|---|---|---:|---:|---:|---|
| `player_actor` | Player | 0 by default; 4 for back-row cases | 10 | 20/20 | Current actor; receives the single active skill under test |
| `player_ally_front` | Player | 1 | 5 | 20/20 | Rally ally and ownership control |
| `player_ally_back` | Player | 5 | 4 | 20/20 | Rally ally and row coverage |
| `enemy_front` | Enemy | 0 | 3 | 20/20 | Active free-target candidate and near predefined candidate |
| `enemy_offset` | Enemy | 1 | 2 | 20/20 | Active free-target candidate and distance/tie coverage |
| `enemy_back` | Enemy | 5 | 1 | 20/20 | Active free-target candidate and farthest-target coverage |

Initial authoritative state is round 1, outcome `IN_PROGRESS`, `player_actor` at queue index 0, no cooldowns, no temporary modifiers, no defeated units, no action in progress, no transaction, and `battle_revision == 0` immediately after fixture construction. Fixture construction itself establishes revision 0 rather than incrementing it.

Each test creates a fresh fixture. It may apply only the named setup override needed by that case: move `player_actor` between slots 0 and 4 before queue construction, set actor HP to 10/20 or 11/20, mark/remove/change ownership of a target, seed a cooldown, advance to round 2, or add/expire a Speed modifier. Tests never depend on state left by another case.

For per-skill execution cases, `player_actor` receives exactly one copied canonical active definition, including Savage Blow or Shadow Lunge. This makes all six rule/effect contracts executable through the player transaction harness while production `enemy_0` and `enemy_4` remain player-inspectable and non-controllable. Separate fixture-contract assertions continue to verify the unchanged production roster ownership.

## Cooldown and duration semantics

Cooldown counters represent future successfully confirmed battle actions that must elapse before the skill becomes ready.

- Cooldowns decrement once after every successfully confirmed battle action.
- A cooldown applied by the action currently resolving does not decrement during that same action.
- Hover, selection, invalid clicks, cancellation, rejected confirmation, and non-action inspection do not decrement cooldowns.
- A skill is ready when its post-use counter is zero and any pre-use gate is satisfied.
- Shadow Lunge's pre-use gate is derived from battle round state and does not create a post-use counter.

Quick Step's Speed bonus expires after the affected unit completes its next action. Rally's Speed bonus expires when the current round ends. Temporary bonuses stack additively when their independent sources overlap, and each source expires according to its own duration.

Whenever Speed changes, only the unresolved portion of the current round queue is rebuilt. Units that already acted do not act again, and no active unresolved unit is dropped. The current action completes before the rebuilt order becomes authoritative.

## Ownership and action boundaries

The only actor that may start a player-facing skill transaction is the current turn's active `PLAYER` unit. That actor may start only one of its own valid active skills.

- A non-current player unit may be inspected but cannot enter `TARGETING`.
- An enemy unit and its skills may be inspected and hovered for AC2.7 descriptions, but an enemy skill can never enter a player-facing AC2.8 transaction.
- A defeated or removed unit cannot act.
- A passive skill can never transition from inspection or preview into `TARGETING`, `VALIDATING`, or `RESOLVING`.
- No UI metadata, selected inspector unit, or synthetic callback can confer action ownership; ownership comes only from authoritative battle turn state.
- Enemy AI skill selection and resolution are not introduced by AC2.8.

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

## Stale-state detection and messages

The battle owns a monotonically increasing `battle_revision`. It increments once after each committed atomic authoritative mutation that can affect actor ownership, skill availability, target validity, target calculation, effect results, or turn order—including completed effect-plan application, turn/round advancement, unit removal or ownership change, cooldown tick, modifier add/expiry, and external battle reconfiguration. Multiple field writes inside one guarded effect-plan commit produce one revision increment. Rejected validation, cancellation, hover/selection changes, presentation updates, and other transient UI events do not increment it. Target evaluation and effect plans capture the committed revision they evaluated.

While `TARGETING`, authoritative battle-change notifications trigger immediate reevaluation. If the locked action is no longer valid, the lock is cleared immediately, Confirm is disabled, indicators are removed, and the transaction enters `REJECTED_STALE`. Confirmation repeats the same validation as a mandatory backstop, so an unobserved or same-frame change still cannot resolve.

Required stale cases and exact panel messages are:

| Change | Detection rule | Message |
|---|---|---|
| Target defeated | Locked target still exists but `is_active()` is false | `Target was defeated. Select another target.` |
| Target removed | Locked target ID no longer resolves in the arena roster | `Target is no longer in battle. Select another target.` |
| Target ownership changed | Locked target no longer belongs to the skill's required side | `Target changed sides and is no longer valid.` |
| Acting ownership/current actor changed | Actor is no longer the current active player unit | `Only the current player unit can act.` |
| Battle completed | Outcome is no longer in progress | `Battle is already complete.` |
| Round progressed | Current round differs from the captured round and changes a gate or duration boundary | `Round advanced. Review this skill again.` |
| Cooldown/availability changed | Skill cooldown, position, HP requirement, active state, or definition no longer permits use | `Skill availability changed. Review this skill again.` |
| Speed/turn-order changed | Speed revision changes current actor ownership or predefined evaluation validity | `Turn order changed. Review this skill again.` |
| Unclassified revision mismatch | Captured revision differs and no more specific reason applies | `Battle state changed. Review this skill again.` |

A revision change that does not invalidate the actor, skill, or exact locked target set may refresh the transaction to the new revision and remain `TARGETING`. It must not silently change a predefined locked target set; if reevaluation selects different predefined targets, the old lock is cleared and the transaction is rejected as stale.

## Callback and re-entry safety

Every preview and transaction receives a monotonically increasing generation. Hover, deferred positioning, slot-enter/exit, target-click, and skill-click callbacks capture both the generation and relevant actor/skill/target ID. Before changing presentation or transaction state, a callback must match the current generation, state, and IDs.

- A newer skill hover supersedes all older preview callbacks.
- Leaving hover increments the preview generation before clearing indicators, so a delayed preview cannot restore them.
- Entering `TARGETING` increments the generation and invalidates every `PREVIEWING` callback.
- Rapid candidate enter/exit events are last-event-wins within the same transaction generation; they may change hover-only indicators but never the locked indicator.
- Rapid target clicks may replace a free-target lock only while the transaction remains `TARGETING`; a click captured before cancellation or skill change is ignored afterward.
- The first eligible Confirm click atomically sets a confirmation latch before entering `VALIDATING`. Further Confirm, target, skill, or Cancel callbacks are ignored in `VALIDATING` and `RESOLVING`.
- The confirmation latch is cleared only when resolution finishes or transaction cleanup completes.
- Deferred tooltip or preview layout work may update geometry only; it cannot change candidate evaluation, locked targets, messages, or combat state.
- A callback with a freed control, unresolved unit, foreign transaction ID, mismatched generation, or unexpected state returns without side effects.

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

Create `Tests/Battle/test_ac2_8_skill_targeting.gd` as the focused AC2.8 runner. It must verify:

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
- `_test_stale_target_rejection_clears_lock_without_mutation()` covers defeat, removal, ownership change, battle completion, round change, cooldown/availability change, and turn-order change with each exact rejection message.
- `_test_failed_confirmation_has_no_partial_mutation()` snapshots HP, effective Speed, modifiers, cooldowns, queue, turn, round, logs, and outcome before every rejected confirmation and proves exact equality afterward.
- `_test_confirmation_reentry_resolves_once()` fires repeated confirmation in the same frame and proves one effect plan, one damage/Speed application, one cooldown application, one log record, and one turn advance.
- `_test_callback_generation_supersedes_stale_events()` delivers old hover, deferred preview, target-click, and skill-click callbacks after a newer generation and proves they cannot change indicators, messages, locks, state, or combat data.

Run the focused AC2.1 through AC2.7 runners as regressions after AC2.8 passes.

### Explicit acceptance notes

AC2.8 fails if any of the following is observed, even when all six happy-path skills appear usable:

- A stale target remains confirmable after defeat, removal, ownership change, battle completion, or relevant revision change.
- Any failed confirmation applies partial damage, Speed, modifier, cooldown, queue, log, turn, round, or outcome mutation.
- Re-entrant confirmation resolves more than once.
- A superseded callback restores an old preview, message, target lock, or actionable state.

### Acceptance traceability

| Contract | Classification | Automated path | Manual/runtime path | Completion evidence |
|---|---|---|---|---|
| Typed target, requirement, effect, and cooldown rules | Logic | Definition and fixture cases in `test_ac2_8_skill_targeting.gd` | Inspect all six authored tooltips and actions | AC2.8 automated log |
| Free and predefined target previews/locks | Integration + visual | Candidate, indicator-state, free-lock, and predefined-lock cases | Manual steps 1–7 at 1152×648 | Automated log + manual record |
| Position, HP, pre-use, and post-use blocking | Logic + integration | Front/back, exact-50%, round-1, and cooldown counter cases | Manual step 10 | Automated log + manual record |
| Six exact effects and turn advancement | Integration | Per-skill effect-plan and resolution cases | Manual step 9 | Automated log + manual record |
| Stale rejection and zero partial mutation | Integration | Named stale and failed-confirmation tests above | Manual step 11 | Automated log + manual record |
| Confirmation de-duplication | Logic + integration | Named re-entry test above | Rapid Confirm input during manual step 9 | Automated log + manual record |
| Callback supersession safety | Integration | Named generation test above | Rapid hover/selection exercise during manual steps 1 and 6 | Automated log + manual record |
| Lifecycle cleanup and contextual visibility | Integration + visual | Cleanup and hidden-when-unused cases | Manual steps 8, 12, and 13 | Automated log + manual record |

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
9. Using the test-only player execution fixture described above, confirm all six active skills and verify exact damage or Speed effects, one log/action/turn advance, cooldown timing, modifier expiration, and queue behavior. The harness is verification-only and does not change production roster ownership.
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
