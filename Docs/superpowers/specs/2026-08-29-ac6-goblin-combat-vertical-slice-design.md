# AC6 Goblin Combat Vertical Slice Design

**Status:** Approved design; awaiting written-spec review

**Date:** 2026-08-29

## Purpose

Deliver the complete authored Goblin combat roster as a sequence of bounded acceptance criteria: six regular classes, Brakka Rustbanner as the Goblin commander, every shared combat mechanic those kits require, and Brakka's full world-map preparation choice. Correct the reversed world-map formation preview as part of the shared formation foundation.

This milestone does not implement character progression. AC3.4 remains unchecked. Leveling, evolution, and mechanical-unit upgrade models must be re-evaluated before implementation and recorded as deferred product decisions in `Docs/TO_CONSIDER.md`.

## Authority and content boundary

The authored behavior comes from:

- `Docs/Races/Goblins/Classes.md`;
- `Docs/Races/Goblins/Commanders.md`;
- `Docs/Races/COMMANDER_PROGRESSION_BRIEF_V1.md`;
- `Docs/Mechanics/SkillAuthoringContract.md`;
- `Docs/Mechanics/SkillKeywords.md`;
- `Docs/Mechanics/FormationMovement.md`.

AC6 includes these regular Goblin classes:

1. Scrapshield Bruiser;
2. Wirefang Skirmisher;
3. Snarewright;
4. Scrapbroker;
5. Shivrunner;
6. Mobcaller.

Each regular class receives its authored Opener, Converter, Pivot, and Signature Passive, plus Default Attack and Default Swap. Brakka is a Scrapshield Bruiser commander variant whose Banner Holder replaces Pack Wall while preserving the four-character-skill limit.

## Milestone decomposition

### AC6.1 — Goblin combat foundation

Implement the shared rules needed by later Goblin criteria:

- authoritative Power and Defense values on fresh battle-unit state;
- direct physical damage using `max(1, ceil(Power * multiplier) - effective Defense)`;
- Default Attack and Default Swap;
- six-slot formation movement and declared rotational paths;
- target and path preview data;
- deterministic action history for damage and movement;
- queue rebuilding when an authored effect changes unresolved action ordering;
- exact row semantics: slots `0..2` are the front row and slots `3..5` are the back row.

The world-map formation preview must use the same row contract as party management and battle. Its current reversed mapping is corrected here and protected by an automated regression test.

### AC6.2 — Goblin keyword and passive foundation

Implement the reusable mechanics required by Goblin kits:

- Advantage;
- Armor;
- Bleed;
- authored cooldown reduction;
- movement-history and distinct-attacker history queries;
- deterministic Passive trigger processing;
- once-per-action and once-per-round guards;
- bounded reaction chains and self-trigger prevention;
- keyword, passive, cooldown, and movement cleanup at battle end.

Keyword behavior must follow `SkillKeywords.md`. No class-local approximation may replace the shared contract.

### AC6.3 — Goblin class wave A

Implement the complete authored loadouts for:

- Scrapshield Bruiser;
- Wirefang Skirmisher;
- Snarewright.

This wave proves hostile and allied formation movement, Armor, Advantage, movement-conditioned targeting, movement-history conditions, multi-target movement atomicity, and movement-triggered Passives.

### AC6.4 — Goblin class wave B

Implement the complete authored loadouts for:

- Scrapbroker;
- Shivrunner;
- Mobcaller.

This wave proves support targeting, threshold requirements, Bleed, Advantage riders, distinct allied-attacker scaling, allied movement, and mixed-race interaction conditions.

### AC6.5 — Brakka Rustbanner

Implement Brakka as a catalog-owned commander definition:

- retain the Scrapshield Bruiser base identity and stats unless the authoritative commander record explicitly overrides them;
- replace Pack Wall with Banner Holder;
- grant Advantage to the next active unresolved ally that owns a currently legal Active Advantage rider;
- revalidate recipient activity, queue order, and rider legality before application;
- apply the once-per-round guard;
- prevent Default Attack and Default Swap from consuming Advantage;
- log the authored success or no-recipient result.

### AC6.6 — Scrapline Quartermaster world-map integration

Implement the full world-map choice rather than the documented fallback:

- gain one Cache charge after every four accepted moves;
- store at most one charge;
- do not change movement range, movement count, reveal authority, or encounter generation;
- consume Cache only when entering a Combat encounter and only after a valid preparation choice commits;
- require one of these choices before combat actions begin:
  - **Frontline Briefing:** choose one active front-row ally to begin with Advantage;
  - **Spare Plating:** all active front-row allies begin with `+2 Armor`;
- do not consume Cache on Safe or Boss encounters;
- persist Cache and any required transaction state through save and reload;
- reject cancellation, stale targets, or stale battle setup without partial application or Cache consumption.

The preparation UI is a transaction boundary between world state and battle initialization. Battle actions remain locked until a valid choice commits or no preparation choice is required.

### AC6.7 — Goblin integration gate

Verify the complete Goblin slice through current production entry points:

- all six regular classes;
- Brakka's commander loadout and Passive replacement;
- real target and movement-path selection;
- keyword presentation and logs;
- formation rearrangement before and after battles;
- victory, reward, and next-battle transitions;
- Cache accrual, save/reload, preparation choice, and battle-start application;
- fresh battle state and cleanup;
- mixed-party interaction rules;
- clean startup and debug console.

No earlier criterion is considered complete solely because AC6.7 compensates for missing focused evidence.

## Architecture

### Battle-unit state

`BattleUnitState` is the authoritative runtime owner of mutable per-battle unit state. It holds effective combat values and battle-local keyword state without mutating run-character definitions. Each battle receives fresh unit instances from the run roster.

Run-character and catalog definitions own stable identity, base stats, class identity, commander identity, and authored skills. They do not own current HP, Armor, Advantage, Bleed, cooldowns, movement history, Passive guards, side, or slot index.

### Skill and effect definitions

Skills remain typed definitions. Shared effect operations represent direct damage, formation movement, Armor, Advantage, Bleed, and cooldown adjustment. Goblin classes compose these operations instead of embedding class-specific mutation branches in `BattleArena`.

Stable class, unit, skill, keyword-source, and commander IDs are catalog-owned. UI labels are presentation data and never serve as identity.

### Battle ownership

`BattleArena` continues to own:

- action preview and transaction lifecycle;
- authoritative revalidation and confirmation;
- target and path locking;
- ordered effect resolution;
- Passive reaction processing;
- action history and battle log presentation;
- queue advancement and rebuilding;
- defeat and outcome evaluation;
- cleanup and reward transition.

Supporting value objects and evaluators should be extracted when they isolate one rule and can be tested without a scene. The arena must not become the only place where keyword or movement correctness can be tested.

### Formation contract

Each side has six semantic slots arranged as three rows of paired back/front cells:

- front row: slots `0`, `1`, and `2`;
- back row: slots `3`, `4`, and `5`.

Party management, battle presentation, world-map preview, targeting rules, commander preparation, save formation, and runtime conversion must use this exact contract.

### Passive processing

Passive reactions are deterministic and visible. Eligible reactions process by authored timing, then stable side/slot order where a tie-break is needed. Every Passive declares a frequency guard. A Passive cannot trigger itself, and reaction chains stop after the bounded authored downstream reaction unless both definitions explicitly name a further interaction.

Passive effects join the triggering history transaction or create a typed reaction entry. Silent state mutation is not allowed.

## Authoritative action resolution

A confirmed action resolves in this order:

1. Revalidate actor, target, position, path, cooldown, conditions, and Advantage eligibility.
2. Lock all targets and declared movement paths.
3. Resolve direct damage through Defense.
4. Spend Armor after Defense; apply remaining damage to HP.
5. Apply declared formation movement atomically.
6. Apply or consume Advantage, Armor, or Bleed.
7. Apply the new cooldown and authored cooldown adjustments.
8. Record one typed authoritative history transaction, including associated Passive reactions.
9. Resolve defeat and battle outcome.
10. Rebuild unresolved queue entries when a supported effect requires it.
11. Resolve declared action-end or round-end ticks and later cooldown decrements.

Invalid, stale, or partially illegal actions reject before mutation. Rejection produces no damage, movement, keyword consumption, keyword application, cooldown, Passive trigger, or history entry.

## Formation movement

Formation movement uses declared legal rotational paths within one side's six slots. The preview exposes the complete path and resulting occupancy before confirmation.

For multi-unit or multi-target movement:

- validate every target and path against one locked pre-commit state;
- reject the whole action if any path, target, or occupancy becomes invalid;
- apply movements in the authored declared order only after full validation;
- record before/after slot information in authoritative history.

Movement conditions distinguish voluntary allied movement from forced hostile movement and record the source unit and skill. This history supports Snarewright, Scrapshield, Wirefang, and commander triggers without reading presentation state.

## Scrapline Quartermaster transaction

Cache belongs to authoritative run state and is persisted by the current save boundary. Accepted world moves update Cache only after the move is durably committed.

On Combat entry with Cache available:

1. Build the fresh battle party from the run roster.
2. Open the preparation transaction before ordinary battle actions are enabled.
3. Present Frontline Briefing and Spare Plating.
4. Revalidate the selected option and any selected frontline unit.
5. Atomically apply the battle-start modifier and consume Cache.
6. Record the committed preparation in world/battle diagnostics and enable battle actions.

Safe and Boss entry bypass this transaction without consuming Cache. Closing, cancelling, stale selection, save failure, or scene teardown cannot partially apply preparation or consume the charge.

## Progression deferral

AC3.4 remains the authority for character progression and stays unchecked. AC6 does not assign levels, XP, evolution branches, or mechanical upgrade tracks to Goblins or any other race.

Implementation of AC6 must add explicit `TO_CONSIDER` entries for:

- the leveling model and how regular units and commanders receive and spend progression;
- evolution-unit identity, thresholds, class replacement, and state migration;
- mechanical-unit permanent upgrades, acquisition, persistence, and balance boundaries.

Commander levels and XP values in the current progression brief are design candidates, not executable AC6 rules.

## Error handling and safety

- Unknown or duplicate stable IDs fail definition construction.
- Invalid loadouts, unsupported effects, and missing mechanic dependencies fail before battle entry.
- Stale preview revisions reject atomically.
- Unsupported target/path combinations expose a readable rejection reason.
- Save failure leaves Cache, movement, and preparation state at the last durable authority and blocks further conflicting input.
- Battle teardown clears every battle-local keyword, cooldown, history helper, and Passive guard.
- No runtime or UI error path may mutate run-character definitions.

## Testing strategy

Every criterion uses test-first development. Each behavior must be observed failing for the expected missing-rule reason before production implementation.

### Focused automated coverage

- front/back row semantics across world HUD, party management, battle, and roster conversion;
- damage rounding, minimum damage, Defense, Armor cap, absorption order, and zero-damage direct hits;
- Advantage recipient eligibility, replacement, expiry, consumption, authored riders, and exclusions;
- Bleed source snapshots, stacks, duration, reapplication, action ticks, exclusions, defeat, and cleanup;
- legal and illegal movement paths, stale occupancy, multi-target atomicity, and history;
- cooldown creation and authored cooldown reduction timing;
- distinct-attacker and forced-movement history queries;
- Passive ordering, guards, bounded reactions, and lifecycle reset;
- every Goblin skill's valid case, rejection cases, preview, confirmation, cooldown, history, log, and relevant AI legality condition;
- Brakka's loadout replacement, Banner Holder selection, no-recipient path, and once-per-round rule;
- Cache accrual, cap, persistence, encounter filtering, preparation choices, cancellation, stale selection, atomic consumption, and battle-start state;
- fresh battle isolation and save/reload behavior.

### Runtime coverage

Use GodotIQ through production scenes to verify:

- world preview row labels and exact slot membership;
- party rearrangement followed by matching battle placement;
- each Goblin class using its defining sequence;
- hostile and allied movement previews and confirmations;
- Armor, Advantage, and Bleed presentation and logs;
- Brakka's Passive and complete Quartermaster flow;
- victory, reward, world return, next encounter, and fresh next battle;
- save/reload with Cache and Goblin roster state;
- no parser, runtime, orphan-signal, or debug-console errors.

## Acceptance criteria

1. AC6 is represented as seven ordered criteria in the active game specification without changing AC3.4's meaning or status.
2. The world-map preview, party management, battle grid, save formation, and runtime roster agree that slots `0..2` are front and `3..5` are back.
3. Shared Power/Defense damage, Default actions, movement, Advantage, Armor, Bleed, cooldown adjustment, history queries, and Passive processing satisfy their authoritative contracts.
4. All six Goblin classes expose and correctly resolve their complete authored four-skill loadouts.
5. Brakka replaces Pack Wall with Banner Holder and does not exceed four character-specific skills.
6. Scrapline Quartermaster implements Cache accrual and the complete Frontline Briefing/Spare Plating choice without changing movement economy or reveal authority.
7. All action, movement, keyword, Passive, and preparation transactions reject invalid or stale state atomically.
8. Battle-local state clears at battle end, and every new battle receives fresh runtime unit state from persistent run definitions.
9. Cache and required authoritative world state survive save/reload without duplication or loss.
10. Leveling, evolution, and mechanical progression remain unimplemented and are recorded as explicit deferred decisions.
11. Focused tests, retained regression suites, GodotIQ validation, project parser checks, signal audit, production startup, runtime interactions, and debug-console checks pass with current evidence.

## Exclusions

- No leveling, XP gain, tier unlocking, commander specialization, evolution, or mechanical-unit upgrade implementation.
- No non-Goblin class or commander implementation except shared mechanics needed by Goblin interactions.
- No equipment system work from AC3.5 or AC3.6.
- No meta-progression or cross-run unlock work.
- No change to world generation, encounter distribution, movement count, boss activation, or reveal authority.
- No general combat AI implementation beyond typed legality and authored preference hooks required to keep definitions complete.
- No balance guarantees beyond the authored Goblin values and deterministic formulas; tuning follows functional verification.

## Implementation and review policy

Implement criteria in dependency order: AC6.1 through AC6.7. Each criterion receives a focused failing test, minimal implementation, focused verification, and retained regression run before the next begins. Multi-file changes require GodotIQ impact checks and project validation before and after.

Code work occurs on the dedicated AC6 task branch in the primary workspace. Preserve unrelated user changes and never stage them with AC6 work. Commit bounded criteria separately where practical. Do not push unless explicitly requested.

## Rollback

Before integration, abandon or revert the AC6 task branch. After integration, revert the bounded AC6 commits in reverse dependency order. Save-schema changes introduced for Cache require compatibility readers or explicit version rejection before removal; never silently reinterpret persisted data.
