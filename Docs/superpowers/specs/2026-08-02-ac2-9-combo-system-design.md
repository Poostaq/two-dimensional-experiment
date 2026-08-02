# AC2.9 Generic Combo System Design

**Acceptance criterion:** AC2.9 — Skills grant combo bonuses only when their specific combo conditions are met.

## Goal

Add a bounded, generic condition/effect combo system to the existing skill-resolution pipeline. Prove the system with Quick Strike: it deals its normal 5 damage, or 8 damage when a different allied unit previously damaged the selected target with a committed skill during the current round.

## Scope

AC2.9 includes:

- Immutable, typed combo definitions attached to character skills.
- AND-only composition across one or more combo conditions.
- A generic combo evaluator that does not branch on concrete skill IDs.
- Immutable committed skill-action history used as combo evidence.
- One initial condition type: `TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND`.
- One initial bonus-effect type: `BONUS_DAMAGE` with a positive integer magnitude.
- Quick Strike configured with the initial condition and a `+3` damage bonus.
- Combo-aware previews, confirmation summaries, action records, and battle-log presentation.
- Automated, runtime, and visual evidence closing AC2.9 without regressing AC2.1–AC2.8.

AC2.9 excludes:

- OR groups, nested expressions, counters, or user-authored condition scripts.
- Multi-stage or cross-battle combo chains.
- Healing, status, resource, cooldown, targeting, or movement bonus effects.
- Passive-triggered combos or executable passive effects.
- Serialization and persistence of combo definitions or action history.
- Enemy AI planning around combos.
- Final animation, VFX, audio, localization, and balance tuning.

## Architecture

The combo system extends the existing immutable skill and effect-plan boundaries instead of adding feature-specific orchestration to `battle_arena.gd`.

`CharacterSkill` owns an optional immutable `ComboDefinition`. A definition contains typed `ComboCondition` values and typed `ComboBonusEffect` values. Every condition must pass for the definition to activate. Definitions are data only: they contain no scene nodes, callbacks, mutable battle state, or skill-ID-specific behavior.

`BattleComboRules` evaluates a definition against the actor, proposed targets, current round, and a defensive snapshot of committed `BattleSkillActionEvent` history. It returns an immutable `ComboEvaluation` containing activation state, per-condition results, and resolved bonus operations. The evaluator dispatches by condition and effect type, never by the owning skill's ID.

`BattleSkillRules` remains the pure confirmation authority. It evaluates the normal skill effect and the combo definition together, then produces one `SkillEffectPlan`. An activated damage bonus is represented separately from base damage in the plan while contributing to the same target's final applied damage.

`BattleArena` remains the only mutation boundary. After a plan commits successfully, the arena appends one immutable action-history event and one logical action-log entry. Transaction generation and battle revision continue to guard preview, targeting, and confirmation.

## Typed combo definitions

### ComboCondition

`ComboCondition` is an immutable `RefCounted` value with:

- `condition_type: Type`

The initial enum contains:

- `TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND`

Construction rejects values outside the enum. `duplicate_condition()` returns a distinct valid copy.

### ComboBonusEffect

`ComboBonusEffect` is an immutable `RefCounted` value with:

- `effect_type: Type`
- `magnitude: int`

The initial enum contains:

- `BONUS_DAMAGE`

Construction requires a valid enum value and `magnitude > 0`. `duplicate_effect()` returns a distinct valid copy.

### ComboDefinition

`ComboDefinition` is an immutable `RefCounted` value with:

- `conditions: Array[ComboCondition]`
- `bonus_effects: Array[ComboBonusEffect]`
- `description_text: String`

Creation requires at least one valid condition, at least one valid bonus effect, and non-blank player-facing description text. It deep-copies incoming values and returns defensive deep copies from public accessors. Repeated conditions or effects are valid and follow ordinary AND/additive semantics; production Quick Strike uses one of each.

`CharacterSkill` accepts either a valid `ComboDefinition` or `null`. Only active skills may own combo definitions. Skill validation, `mechanical_definition()`, and `duplicate_skill()` preserve the full combo definition defensively. Invalid combo data causes `CharacterSkill.create()` to return `null` through the existing runtime-safe validation path.

## Quick Strike content contract

Quick Strike keeps all AC2.7 and AC2.8 behavior except for the added combo metadata:

| Field | Value |
|---|---|
| Base effect | 5 damage to one freely selected active enemy |
| Combo condition | Target was damaged earlier this round by a committed skill from a different allied actor |
| Combo bonus | +3 damage |
| Activated total | 8 damage before ordinary damage clamping |
| Combo description | `+3 damage if another ally damaged this target with a skill this round.` |

No combat rule checks `quick_strike` or any other concrete skill ID. The fixture demonstrates the generic data contract by attaching the definition to Quick Strike.

## Committed action history

`BattleSkillActionEvent` is an immutable record of one successfully committed skill action:

- `round_number: int`
- `actor_id: StringName`
- `actor_side: BattleUnitState.Side`
- `skill_id: StringName`
- `target_ids: Array[StringName]`
- `applied_damage_by_target: Dictionary[StringName, int]`
- `combo_activated: bool`

Construction requires a positive round, non-empty actor and skill IDs, a valid side, unique non-empty target IDs, and damage entries whose IDs are included in `target_ids` and whose values are non-negative. Arrays and dictionaries are copied on input and output.

The arena appends an event only after the complete effect plan commits. Preview, selection, cancellation, rejected confirmation, stale confirmation, duplicate callbacks, debug damage, and failed or partial attempts never create events. One confirmed skill action creates exactly one event even when it affects multiple targets.

History is reset when a battle is configured or torn down. Earlier-round events may remain in the in-memory array during a battle, but the condition filters strictly by `round_number`; therefore they cannot activate a current-round combo. Consumers receive defensive snapshots rather than the arena's mutable array.

## Condition semantics

`TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND` passes for a proposed target only when at least one earlier history event satisfies every rule below:

1. The event round equals the current round.
2. The event actor side equals the current actor's side.
3. The event actor ID differs from the current actor ID.
4. The proposed target ID exists in `applied_damage_by_target`.
5. Applied damage for that target is greater than zero.

The setup actor does not need to remain active after its committed hit. Its later defeat or removal does not erase valid history from the current round.

The condition fails for damage by the same actor, damage by an enemy, damage to another target, zero applied damage, debug damage, non-damage effects, rejected or cancelled attempts, and events from earlier rounds.

For a single-target skill, the definition activates when every condition passes for the selected target. The initial AC2.9 system rejects a combo definition on skills whose target rule can resolve multiple targets, because aggregate `all` versus `any` target semantics are deliberately deferred until a concrete multi-target combo is designed.

## Evaluation and effect planning

`BattleComboRules.evaluate(...) -> ComboEvaluation` receives the combo definition, actor, ordered proposed targets, current round, and a defensive history snapshot. It never mutates its inputs.

`ComboEvaluation` contains:

- `has_combo: bool`
- `activated: bool`
- `condition_results: Array[ComboConditionResult]`
- `bonus_operations: Array[Dictionary]`
- `diagnostic_code: DiagnosticCode`

`has_combo` distinguishes a skill with no combo definition from a configured combo whose conditions failed. Each condition result identifies its condition type, pass/fail state, and relevant target IDs. Activated bonus operations identify the effect type, magnitude, and ordered target IDs.

If no definition exists, evaluation returns `has_combo == false`, `activated == false`, and no operations. If a valid definition exists but any condition fails, evaluation returns `has_combo == true`, `activated == false`, and no operations. If all conditions pass, every configured bonus effect becomes an ordered bonus operation.

For `BONUS_DAMAGE`, `BattleSkillRules` includes both base and bonus amounts in the confirmation result and effect plan. The plan retains one logical damage resolution per target with explicit `base_damage`, `combo_bonus_damage`, and `total_requested_damage` fields. `total_requested_damage` equals base plus bonus. Actual HP loss remains clamped by the existing damage resolver and is what the committed action event records.

Confirmation always reevaluates combo eligibility using the current battle revision and history. An action built from an older revision follows the existing stale rejection path and mutates nothing.

## Resolution order and atomicity

A confirmed combo-capable skill follows this order:

1. Revalidate actor, skill, target, cooldown, battle state, revision, and combo conditions.
2. Build one immutable effect plan containing base and optional bonus values.
3. Enter the existing guarded resolution latch.
4. Apply the total requested damage through `BattleDamageResolver`.
5. Apply existing cooldown, modifier-expiry, defeat, result, queue, and turn rules.
6. Increment the battle revision once for the atomic action.
7. Append one immutable `BattleSkillActionEvent` using actual applied damage.
8. Append one logical action-log entry containing base, bonus, requested total, applied total, and combo state.
9. Return the transaction and presentation to the existing neutral state.

Any failure before commit produces no HP change, cooldown change, history event, action-log entry, revision increment, or turn advancement. Re-entry and duplicate confirmation remain blocked by the existing latch and generation guards.

## Presentation

Quick Strike's tooltip adds a Combo row below the existing cooldown row:

`Combo: +3 damage if another ally damaged this target with a skill this round.`

Skills without a combo definition do not render a Combo row. Passive skills remain inspectable and non-actionable.

During free-target preview and targeting:

- Every ordinary legal target retains the AC2.8 valid-target presentation.
- A legal target satisfying the combo definition also receives a distinct `combo_ready` indicator role.
- Hovering or locking a qualifying target shows `Combo ready: +3 damage` and an 8-damage action summary.
- Hovering or locking a non-qualifying legal target shows the ordinary 5-damage summary and no combo-ready claim.
- Locked-target readability remains visible when combo-ready styling is added; the combo role does not erase valid, invalid, hover, or lock meaning.

The logical battle-log entry explicitly reports the base amount, combo bonus, requested total, applied damage, and whether the combo activated. Non-combo actions keep their existing concise presentation.

All tooltip and targeting states must remain inside the 1152×648 target viewport without clipping or overlap. Combo presentation reuses scene-owned controls and indicator overlays; it does not create runtime terrain, structures, or scene hierarchy in code.

## Invalid and unsupported data

Invalid definitions are rejected during construction and cannot enter a valid skill roster. This includes invalid enum values, empty condition or effect arrays, blank description text, non-positive bonus damage, passive ownership, and attachment to a multi-target skill under the AC2.9 target-semantics boundary.

Runtime evaluators fail closed if they receive malformed or unsupported data despite construction guards. They return `activated == false`, no bonus operations, and a typed diagnostic code. They never partially apply a bonus or throw an assertion-dependent gameplay failure.

Player-facing invalid-action messages remain owned by the existing skill validation and transaction flow. Internal combo diagnostic codes support tests and debugging without exposing implementation terminology to players.

## File responsibilities

- `Scripts/Battle/combo_condition.gd`: immutable typed condition value.
- `Scripts/Battle/combo_bonus_effect.gd`: immutable typed bonus-effect value.
- `Scripts/Battle/combo_definition.gd`: validated AND-only definition with defensive deep copies.
- `Scripts/Battle/combo_condition_result.gd`: immutable per-condition evaluation evidence.
- `Scripts/Battle/combo_evaluation.gd`: immutable aggregate activation result and diagnostic.
- `Scripts/Battle/battle_skill_action_event.gd`: immutable committed skill-history event.
- `Scripts/Battle/battle_combo_rules.gd`: pure generic condition and bonus-effect evaluation.
- `Scripts/Battle/character_skill.gd`: optional combo metadata and validation integration.
- `Scripts/Battle/skill_effect_plan.gd`: explicit base, combo bonus, and requested damage values.
- `Scripts/Battle/battle_action_log_entry.gd`: combo-aware logical action record.
- `Scripts/Battle/battle_skill_rules.gd`: composes normal and combo evaluation into confirmation plans.
- `Scripts/Battle/battle_arena.gd`: defensive history ownership, atomic event recording, and presentation wiring.
- `Scenes/battle_arena.tscn`: any additional scene-owned Combo tooltip label or indicator styling.
- `Tests/Battle/test_ac2_9_combo_system.gd`: focused model, evaluator, history, integration, presentation, and lifecycle coverage.
- Existing AC2.6–AC2.8 tests: constructor and fixture updates preserving all prior contracts.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: final AC2.9 checkbox and verification contract after evidence passes.
- `Docs/Specs/AC2/Evidence/AC2.9/2026-08-02/*`: automated log, manual runtime record, and implementation link.

## Verification contract

The focused AC2.9 automated runner proves:

1. Condition, effect, definition, result, and event construction rejects every invalid boundary at runtime.
2. All public arrays, dictionaries, nested values, duplicated definitions, and history snapshots are defensive.
3. Multiple conditions use AND semantics.
4. Generic evaluation activates without inspecting a concrete skill ID.
5. Quick Strike requests 8 damage only after a different allied actor dealt positive committed skill damage to the same target during the same round.
6. Same-actor, enemy, other-target, zero-damage, debug, cancelled, rejected, stale, and earlier-round inputs do not activate the bonus.
7. A setup actor's later defeat or removal does not invalidate its committed current-round history.
8. Confirmation reevaluates current history and revision; stale preview state cannot grant a bonus.
9. Combo resolution applies once, advances once, increments revision once, and records exactly one history event and one logical log entry.
10. History and combo presentation clear on battle reconfiguration, completion, exit, and new battle setup.
11. Tooltip, targeting, hover, lock, confirmation, and log presentation match the configured combo state.

Regression verification runs every AC2.1–AC2.8 focused runner individually, GodotIQ project validation, project parser/error checks, and orphan-signal inspection. Runtime verification starts Play, confirms clean debugger output, inspects authoritative history/revision values, and exercises both the qualifying and non-qualifying Quick Strike paths. Visual QA uses the target 1152×648 viewport and a post-fix tour.

## Completion criteria

AC2.9 is complete only when the generic typed model, pure evaluator, immutable history, Quick Strike fixture, atomic resolution, player-visible combo feedback, and lifecycle cleanup all match this design; the focused AC2.9 suite and AC2.1–AC2.8 regressions pass; runtime and visual checks pass without debugger errors; evidence files identify one tested implementation commit; and the MVP acceptance and verification rows are formally closed.
