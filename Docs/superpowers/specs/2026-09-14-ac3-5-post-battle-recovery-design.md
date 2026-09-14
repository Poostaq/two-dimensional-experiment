# AC3.5 Post-Battle Recovery Design

## Goal

After a victorious battle, every surviving player character starts the next battle at full health, while every player character who passed out starts the next battle at 50% of maximum health rounded up. The resulting health must survive saving and reloading between battles.

## Scope

This design implements `AC3.5` from `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`.

Included:

- victory-only post-battle recovery;
- full recovery for survivors;
- half recovery, rounded upward, for passed-out characters;
- durable per-character health in the current run;
- recruitment, dismissal, formation, and Save V2 integration;
- automated and manual verification.

Excluded:

- difficulty selection or configurable recovery percentages;
- persistent battle damage for survivors;
- permanent death;
- persistence of Armor, Bleed, cooldowns, Speed modifiers, Advantage, Snared, or other battle-local state;
- new scenes or visual redesign.

## Decisions

- Recovery is hardcoded at 50% until difficulty modes are implemented.
- Odd maximum-health values round upward. The recovery formula is integer `(max_hp + 1) / 2`.
- Survivors start the next battle at full health, regardless of their remaining health at victory.
- Recovery is committed only after victory. Defeat, debug exit, or an abandoned battle does not mutate durable recovery state.
- Health follows character identity rather than formation slot.

## Architecture

`WorldRunState` owns a durable `character_hp` dictionary keyed by stable character ID. This keeps mutable run data separate from immutable catalog-authored `RunCharacter` definitions and from battle-local `BattleUnitState` objects.

At battle completion, `BattleArena` exposes a defensive player-health snapshot containing each player character's ID, final HP, and maximum HP. `WorldRuntimeController`, which already listens to `BattleArena.battle_completed`, applies the recovery rule only for a victory. It writes the result into a candidate `WorldRunState` and commits it through the existing autosave transaction. Repeated completion callbacks must be idempotent and must not apply recovery or autosave twice.

When the next battle is assembled, `RunRoster` uses the run-owned health dictionary to initialize each player `BattleUnitState.current_hp`. The battle unit still receives fresh battle-local state. The stored health value represents only the character's starting HP for the next battle.

## Component Responsibilities

### Recovery rules

A focused pure rule object computes the next-battle HP:

- `final_hp > 0` returns `max_hp`;
- `final_hp == 0` returns `(max_hp + 1) / 2`;
- invalid IDs, non-positive maximum HP, negative final HP, or final HP above maximum HP are rejected.

The rule has no scene, save, catalog, or UI dependencies.

### `BattleArena`

`BattleArena` remains the authority for battle-local player units. It provides a defensive terminal player-health snapshot after battle completion. Consumers cannot mutate arena-owned units through the snapshot.

### `WorldRuntimeController`

The controller translates a terminal victory snapshot into durable run state. It is responsible for:

- accepting recovery only for `BattleOutcome.Type.VICTORY`;
- applying it once for the active battle;
- validating every snapshot entry against the active roster and catalog maximum HP;
- creating a candidate run state;
- invoking the existing autosave coordinator;
- publishing the new durable state only when the save transaction succeeds;
- preserving the prior durable state and existing autosave recovery behavior when saving fails.

### `WorldRunState`

`WorldRunState` stores and validates `character_hp` alongside formation and other run-owned fields. It returns defensive copies from public snapshot accessors. Its canonical representation includes health so deterministic equality and Save V2 round trips account for recovery state.

Backward compatibility treats a missing `character_hp` field as an older save and initializes every rostered character to catalog maximum HP. Present but malformed health data is rejected rather than silently repaired.

### Roster lifecycle

- Starting roster characters initialize at full HP.
- A recruited character initializes at full HP.
- Dismissing a character removes its health entry.
- Moving or swapping formation slots does not alter health.
- Battle creation rejects missing, unknown, duplicate, or out-of-range present-day health entries after initialization/migration has completed.

## Data Flow

1. Battle setup resolves the active roster and reads each character's durable HP.
2. Fresh `BattleUnitState` objects are created with that HP and no stale battle-local effects.
3. Combat mutates only the battle units.
4. `BattleArena` reaches a terminal outcome and emits its existing completion event.
5. On victory, the controller requests the arena's terminal player-health snapshot.
6. The controller computes full survivor recovery and rounded-up half recovery for passed-out characters.
7. The controller writes the complete health map to a candidate `WorldRunState` and autosaves it once.
8. After a successful save, the candidate becomes durable and later battles consume its health map.
9. On defeat or non-terminal closure, the durable health map is unchanged.

## Error Handling and Atomicity

Recovery is all-or-nothing. If any snapshot entry is invalid, duplicated, unknown, or inconsistent with catalog maximum HP, the controller records an integration failure and does not publish a partial health map.

If autosave fails, the existing blocking autosave recovery flow remains authoritative. The previously durable state stays intact until retry succeeds; discarding the pending save discards the candidate recovery update as well.

Repeated battle-completion notification, reward interaction, and battle closure cannot trigger a second recovery commit.

## Verification Strategy

### Automated coverage

- Recovery-rule tests cover even and odd maximum HP, survivor restoration, passed-out recovery, and invalid input.
- `WorldRunState` tests cover validation, defensive copying, canonical-key participation, and missing-field migration.
- Save V2 tests cover encode/decode round trips with health and backward compatibility without the health field.
- Roster tests prove stored health initializes battle units, recruitment starts full, dismissal removes health, and formation movement preserves health by identity.
- Battle tests prove the terminal health snapshot is complete, player-only, immutable from the caller's perspective, and stable after completion.
- World integration tests prove victory commits and autosaves exactly once; defeat and debug closure do not commit; save failure preserves the prior durable state; and the following battle receives the committed HP.

### Regression coverage

Run the existing suites for:

- AC2.4 battle completion;
- AC2.5 reward selection;
- AC3.1 roster and recruitment;
- AC3.3 formation and party management;
- AC6.7 production Goblin integration;
- World battle entry;
- WorldRunState and Save V2;
- project validation, parser checks, signal orphan checks, and production startup.

### Manual AC3.5 check

1. Start a production run with at least two player characters.
2. Let one character reach 0 HP while another survives with less than maximum HP.
3. Win the battle and complete the normal exit/reward flow.
4. Save and reload the run before the next battle.
5. Enter the next battle.
6. Verify the passed-out character starts at `(max_hp + 1) / 2` HP.
7. Verify every survivor starts at full HP.
8. Verify formation slots are unchanged and no battle-local status carries over.

## Acceptance Mapping

| Criterion | Verification path |
|---|---|
| Passed-out characters return after victory | World integration test plus manual two-battle flow |
| Returned characters start at 50% HP | Pure recovery-rule test and next-battle integration assertion |
| Odd HP rounds upward | Pure recovery-rule test using an odd `max_hp` |
| Survivors start at full HP | Recovery-rule and next-battle integration assertions |
| Recovery survives save/reload | Save V2 round trip and manual reload step |
| Harder-difficulty reduction remains deferred | No difficulty API or configuration is introduced |

