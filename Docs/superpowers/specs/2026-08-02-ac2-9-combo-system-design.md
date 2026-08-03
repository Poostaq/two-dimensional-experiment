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

`BattleComboRules` evaluates a definition against the actor, proposed targets, current round, and a defensive snapshot of committed `BattleActionLogEntry` history. It returns an immutable `ComboEvaluation` containing activation state, per-condition results, and resolved bonus operations. The evaluator dispatches by condition and effect type, never by the owning skill's ID.

`BattleSkillRules` remains the pure confirmation authority. It evaluates the normal skill effect and the combo definition together, then produces one `SkillEffectPlan`. An activated damage bonus is represented separately from base damage in the plan while contributing to the same target's final applied damage.

`BattleArena` remains the only mutation boundary. After a plan commits successfully, the arena appends one immutable `BattleActionLogEntry`; that entry is both the logical battle log and the sole authoritative committed-skill history record. Transaction generation and battle revision continue to guard preview, targeting, and confirmation.

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

The focused test fixture also creates `combo_probe` / Combo Probe as a separate active, single-target, 5-damage skill. It receives an independently duplicated combo definition with the same condition and `+3` effect. It is not added to the production roster. Pure evaluation and full confirmation/resolution tests must produce identical results for Quick Strike and Combo Probe, preventing a hidden concrete skill-ID branch from satisfying AC2.9.

## Authoritative committed action history

`BattleActionLogEntry` remains the single immutable record of one successfully committed skill action. AC2.9 extends it with the history facts required for generic combo evaluation:

- `sequence_number: int`
- `round_number: int`
- `actor_id: StringName`
- `actor_side: BattleUnitState.Side`
- `skill_id: StringName`
- `target_ids: Array[StringName]`
- `damage_results: Array[BattleDamageResult]`
- `base_damage_by_target: Dictionary[StringName, int]`
- `combo_bonus_damage_by_target: Dictionary[StringName, int]`
- `combo_activated: bool`
- Existing non-damage action fields, including Speed target IDs

Construction requires a positive sequence and round, non-empty actor and skill IDs, a valid side, unique non-empty target IDs, and damage-breakdown entries whose IDs are included in `target_ids` and whose values are non-negative. Base plus combo bonus must equal each damage result's requested damage. Arrays, dictionaries, and nested damage results are copied on input and output. `duplicate_entry()` returns a distinct deep copy suitable for rule evaluation.

The arena appends an entry only after the complete effect plan commits. Preview, selection, cancellation, rejected confirmation, stale confirmation, duplicate callbacks, debug damage, and failed or partial attempts never create entries. One confirmed skill action creates exactly one entry even when it affects multiple targets. Presentation renders from this same entry; there is no second event collection and no derivation or synchronization path to maintain.

`BattleArena.get_committed_action_history_snapshot() -> Array[BattleActionLogEntry]` is the only arena-facing history API. It returns a newly allocated array of `duplicate_entry()` values in ascending `sequence_number` order. The arena passes this snapshot explicitly to `BattleSkillRules`, which passes it unchanged to `BattleComboRules`; neither rules class holds an arena reference or fetches global state. Tests and runtime inspection use the same snapshot method rather than reading `_battle_action_log_entries`.

The authoritative `_battle_action_log_entries` array is reset by battle configuration, teardown, and exit cleanup. Battle completion clears interactive combo presentation but retains the completed battle's entries for result-screen log inspection; those entries are discarded at teardown or when the next battle is configured. Earlier-round entries may remain in the array during a battle, but the condition filters strictly by `round_number`; therefore they cannot activate a current-round combo.

## Condition semantics

`TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND` passes for a proposed target only when at least one earlier history event satisfies every rule below:

1. The event round equals the current round.
2. The event actor side equals the current actor's side.
3. The event actor ID differs from the current actor ID.
4. A `damage_results` item identifies the proposed target ID.
5. That result's applied damage is greater than zero.

The setup actor does not need to remain active after its committed hit. Its later defeat or removal does not erase valid history from the current round.

The condition fails for damage by the same actor, damage by an enemy, damage to another target, zero applied damage, debug damage, non-damage effects, rejected or cancelled attempts, and events from earlier rounds.

For a single-target skill, the definition activates when every condition passes for the selected target. The initial AC2.9 system rejects a combo definition on skills whose target rule can resolve multiple targets, because aggregate `all` versus `any` target semantics are deliberately deferred until a concrete multi-target combo is designed.

## Evaluation and effect planning

`BattleComboRules.evaluate(...) -> ComboEvaluation` receives the combo definition, actor, ordered proposed targets, current round, and the `Array[BattleActionLogEntry]` returned by `BattleArena.get_committed_action_history_snapshot()`. It never mutates its inputs and has no reference to the arena.

`ComboEvaluation` contains:

- `has_combo: bool`
- `activated: bool`
- `condition_results: Array[ComboConditionResult]`
- `bonus_operations: Array[Dictionary]`
- `diagnostic_code: DiagnosticCode`

`has_combo` distinguishes a skill with no combo definition from a configured combo whose conditions failed. Each condition result identifies its condition type, pass/fail state, and relevant target IDs. Activated bonus operations identify the effect type, magnitude, and ordered target IDs.

If no definition exists, evaluation returns `has_combo == false`, `activated == false`, and no operations. If a valid definition exists but any condition fails, evaluation returns `has_combo == true`, `activated == false`, and no operations. If all conditions pass, every configured bonus effect becomes an ordered bonus operation.

For `BONUS_DAMAGE`, `BattleSkillRules` includes both base and bonus amounts in the confirmation result and effect plan. Each item in `SkillEffectPlan.damage_operations: Array[Dictionary]` uses exactly this schema:

```gdscript
{
    &"target_id": StringName,
    &"base_damage": int,
    &"combo_bonus_damage": int,
    &"total_requested_damage": int,
}
```

`target_id` must be non-empty. `base_damage` and `combo_bonus_damage` must be non-negative. `total_requested_damage` must equal `base_damage + combo_bonus_damage` and must be positive. A non-combo damage operation stores `combo_bonus_damage == 0`; an activated Quick Strike or Combo Probe operation stores `base_damage == 5`, `combo_bonus_damage == 3`, and `total_requested_damage == 8`. Operations remain ordered by the skill's resolved target order. `SkillEffectPlan` validates and deep-copies every operation at construction and returns defensive copies. Actual HP loss remains clamped by the existing damage resolver and is stored separately in the authoritative action entry's `BattleDamageResult`.

Confirmation always reevaluates combo eligibility using the current battle revision and history. An action built from an older revision follows the existing stale rejection path and mutates nothing.

## Resolution order and atomicity

A confirmed combo-capable skill follows this order:

1. Revalidate actor, skill, target, cooldown, battle state, revision, and combo conditions.
2. Build one immutable effect plan containing base and optional bonus values.
3. Enter the existing guarded resolution latch.
4. Apply the total requested damage through `BattleDamageResolver`.
5. Apply existing cooldown, modifier-expiry, defeat, result, queue, and turn rules.
6. Increment the battle revision once for the atomic action.
7. Append one immutable `BattleActionLogEntry` containing actor side, base, bonus, requested total, actual applied damage, and combo state.
8. Render the logical battle log from that same authoritative entry.
9. Return the transaction and presentation to the existing neutral state.

Any failure before commit produces no HP change, cooldown change, action-log/history entry, revision increment, or turn advancement. Re-entry and duplicate confirmation remain blocked by the existing latch and generation guards.

## History and presentation lifecycle

`_battle_action_log_entries` is the sole authoritative collection. Combo readiness, target roles, summaries, and tooltip state are derived presentation and are never stored as a second history source.

| Boundary | Authoritative `_battle_action_log_entries` | Transaction and combo presentation | Snapshot API |
|---|---|---|---|
| Initial arena construction | Empty | Neutral/hidden | Returns an empty new array |
| `configure_battle(...)` | Clear before installing new units and round state | Cancel transaction; clear hover, lock, message, summary, and combo-ready roles | Subsequent call returns only entries from the new battle |
| Successful committed skill | Append exactly one immutable entry after effect application | Re-render from current state, then return to neutral after resolution | Returns all entries in ascending sequence order as deep copies |
| Rejected, cancelled, stale, or duplicate action | Unchanged | Clear or retain state according to the existing transaction result; never claim a committed combo | Returns content equal to the pre-attempt snapshot |
| Round advance | Retain all entries | Reevaluate; earlier-round entries cannot produce combo-ready state | Returns retained entries; evaluator filters by exact round |
| Battle completion | Retain entries for result-screen log inspection | Cancel transaction and clear all interactive combo presentation | Returns the completed battle's entries read-only by copy |
| Arena exit or teardown | Clear | Cancel transaction and clear all combo presentation | Returns an empty new array if the arena remains inspectable |
| Next battle configuration | Clear before accepting new actions | Start neutral with no combo-ready state | Returns an empty new array |

The same private cleanup routine clears transaction and presentation state at configuration, completion, exit, and teardown. The authoritative collection is cleared only at configuration, exit, and teardown, preserving the completed battle log until the arena lifecycle ends or a replacement battle begins.

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
- `Scripts/Battle/battle_combo_rules.gd`: pure generic condition and bonus-effect evaluation.
- `Scripts/Battle/character_skill.gd`: optional combo metadata and validation integration.
- `Scripts/Battle/skill_effect_plan.gd`: explicit base, combo bonus, and requested damage values.
- `Scripts/Battle/battle_action_log_entry.gd`: sole authoritative committed-skill history and combo-aware logical action record, with defensive duplication.
- `Scripts/Battle/battle_skill_rules.gd`: composes normal and combo evaluation into confirmation plans.
- `Scripts/Battle/battle_arena.gd`: authoritative action-history ownership, `get_committed_action_history_snapshot()`, atomic entry recording, and presentation wiring.
- `Scenes/battle_arena.tscn`: any additional scene-owned Combo tooltip label or indicator styling.
- `Tests/Battle/test_ac2_9_combo_system.gd`: focused model, evaluator, history, integration, presentation, and lifecycle coverage.
- Existing AC2.6–AC2.8 tests: constructor and fixture updates preserving all prior contracts.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: final AC2.9 checkbox and verification contract after evidence passes.
- `Docs/Specs/AC2/Evidence/AC2.9/2026-08-02/*`: automated log, manual runtime record, and implementation link.

## Verification contract

The focused AC2.9 automated runner proves:

1. Condition, effect, definition, evaluation-result, and authoritative action-entry construction rejects every invalid boundary at runtime.
2. All public arrays, dictionaries, nested values, duplicated definitions, and history snapshots are defensive.
3. Multiple conditions use AND semantics.
4. Generic evaluation activates without inspecting a concrete skill ID: a test-only `combo_probe` skill with a different ID and display name but an independently duplicated equivalent combo definition must produce the same failed and activated evaluations and the same 5/8 damage integration results as Quick Strike.
5. Quick Strike and `combo_probe` each request 8 damage only after a different allied actor dealt positive committed skill damage to the same target during the same round.
6. Same-actor, enemy, other-target, zero-damage, debug, cancelled, rejected, stale, and earlier-round inputs do not activate the bonus.
7. A setup actor's later defeat or removal does not invalidate its committed current-round history.
8. Confirmation reevaluates current history and revision; stale preview state cannot grant a bonus.
9. Every damage operation contains exactly `target_id`, `base_damage`, `combo_bonus_damage`, and `total_requested_damage`; invalid arithmetic or values are rejected, and returned operations are defensive copies.
10. Combo resolution applies once, advances once, increments revision once, and records exactly one authoritative `BattleActionLogEntry`; no parallel committed-event collection exists.
11. `get_committed_action_history_snapshot()` preserves sequence order, deep-copies every entry and nested value, and is the only history input passed through `BattleSkillRules` into `BattleComboRules`.
12. Every lifecycle row in the history and presentation matrix is tested, including retained completed-battle entries, exact clear boundaries, neutral presentation, and empty replacement-battle snapshots.
13. Tooltip, targeting, hover, lock, confirmation, and log presentation match the configured combo state.

Regression verification runs every AC2.1–AC2.8 focused runner individually, GodotIQ project validation, project parser/error checks, and orphan-signal inspection. Runtime verification starts Play, confirms clean debugger output, inspects authoritative history/revision values, and exercises both the qualifying and non-qualifying Quick Strike paths. Visual QA uses the target 1152×648 viewport and a post-fix tour.

## Completion criteria

AC2.9 is complete only when the generic typed model, pure evaluator, immutable history, Quick Strike fixture, atomic resolution, player-visible combo feedback, and lifecycle cleanup all match this design; the focused AC2.9 suite and AC2.1–AC2.8 regressions pass; runtime and visual checks pass without debugger errors; evidence files identify one tested implementation commit; and the MVP acceptance and verification rows are formally closed.
