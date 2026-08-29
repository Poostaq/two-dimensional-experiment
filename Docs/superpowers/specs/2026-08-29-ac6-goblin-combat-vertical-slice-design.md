# AC6 Goblin Combat Vertical Slice Design

**Status:** Approved design only — no AC6 criterion is implemented or complete

**Date:** 2026-08-29

## Purpose

Deliver the complete authored Goblin combat roster as a sequence of bounded acceptance criteria: six regular classes, Brakka Rustbanner as the Goblin commander, every shared combat mechanic those kits require, and Brakka's full world-map preparation choice. Correct the reversed world-map formation preview as part of the shared formation foundation.

This milestone does not implement character progression. AC3.4 remains unchecked. Leveling, evolution, and mechanical-unit upgrade models must be re-evaluated before implementation and recorded as deferred product decisions in `Docs/TO_CONSIDER.md`.

## Evidence status

This document is a prospective implementation roadmap and acceptance contract. It does not describe shipped state.

Repository inspection on 2026-08-29 found reusable AC2/AC3 foundations: `BattleUnitState` owns HP-based activity, slots, Speed modifiers, and cooldowns; `BattleSkillRules` owns basic target evaluation, revision checks, damage/Speed plans, row requirements, and lane-distance sorting; current run/save code persists formation and general world-run state. None of that is evidence that AC6 mechanics are implemented.

The following are currently missing as AC6 implementation evidence: Goblin catalog definitions, Power/Defense formula integration, Armor, Bleed, enemy-bound Advantage, Snared, Goblin reactive processing, Brakka's trigger, distinct-attacker queries, Cache fields, preparation transaction/hook, corrected world-HUD slot mapping, AC6-focused tests, and saved runtime verification records.

Every AC6 criterion remains **NOT IMPLEMENTED / TRACEABILITY FAIL** until its planned failing test exists, the implementation link is recorded, the test passes, and required GodotIQ runtime evidence is captured. Design wording such as “must,” “implement,” and “verify” is prospective and never a completion claim.

## Operational definitions and planned ownership

- **Active battle unit:** a valid `BattleUnitState` included in the arena's current configured-unit collection, assigned to a valid side and slot `0..5`, with `is_active() == true`. Under the observed baseline this means `current_hp > 0`. Catalog entries and preview-only objects are not active battle units.
- **Active enemy at battle start:** an active battle unit on the side opposing the player after fresh battle units are configured and before the preparation transaction or first queue action resolves.
- **Formation lane:** `slot_index % 3`. Front slots are `0..2`; back slots are `3..5`.
- **Distance for Banner Holder:** absolute lane difference, `abs((enemy.slot_index % 3) - (Brakka.slot_index % 3))`. Lowest distance wins. Equal distance resolves front slot before back slot, then lowest slot index. This must be extracted as a shared tested formation-distance rule rather than duplicated in Brakka logic.
- **Accepted move:** a world move that has passed validation and whose updated run state is durably committed. Rejected, cancelled, previewed, or save-failed movement does not advance Cache counters.
- **Cache owner:** planned fields on authoritative `WorldRunState`, encoded and decoded by `WorldRunSaveCodecV2` through an explicit schema-compatible change: stored charge `0..1` and accepted-move remainder `0..3`.
- **Preparation owner:** a planned typed battle-preparation transaction coordinated at the existing world-to-battle entry boundary. It creates fresh battle units, locks ordinary actions, validates the choice against those units, applies the modifier, consumes Cache in the durable run-state transition, and then unlocks battle actions.
- **Preparation durability:** no partially chosen preparation is persisted. Before commit, reload returns to the last durable pre-entry state and reopens the required choice. After commit, Cache consumption and the initialized battle modifier must be represented by one authoritative transition; the concrete save/scene-reload strategy must be selected in the implementation plan and tested before AC6.6 can pass.

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

Each regular class receives its three Set 1 battle skills plus Default Attack and Default Swap. Brakka retains the Scrapshield Bruiser's three skills and adds Banner Holder as her fourth commander skill.

The canonical Advantage contract changes globally in this milestone: Advantage is a single non-stacking, round-local debuff on an enemy. The first eligible allied Active skill targeting or directly hitting that enemy consumes it for that skill's authored Advantage rider. Any ally may consume it, regardless of source. Orc, Werewolf, Lizardman, and Harpy documents are explicitly pending Set 1 reconciliation and are not implementation targets here.

## Milestone decomposition

### Planned implementation links

These links identify expected ownership for planning and TDD; they are not implemented links. The implementation plan may extract smaller typed helpers after GodotIQ impact checks, but it must update this table whenever ownership changes.

| Criterion | Existing integration seam | Planned production ownership | Planned focused evidence |
|---|---|---|---|
| AC6.1 | `BattleUnitState`, `BattleSkillRules`, `BattleArena`, `RunRoster.create_battle_units()`, `world_map_hud` | Extend battle stats/default actions and shared formation semantics; correct HUD slot mapping | `test_ac6_1_combat_foundation.gd` plus updated HUD/formation tests |
| AC6.2 | Battle state, skill effect plan, arena history/queue | Typed battle-local keyword state and deterministic reaction dispatcher; arena remains transaction coordinator | `test_ac6_2_keyword_reactions.gd` |
| AC6.3 | Character catalog and battle skill definitions | Catalog-owned Scrapshield, Wirefang, and Snarewright definitions composed from shared effects | `test_ac6_3_goblin_wave_a.gd` |
| AC6.4 | Character catalog and battle skill definitions | Catalog-owned Scrapbroker, Shivrunner, and Mobcaller definitions composed from shared effects | `test_ac6_4_goblin_wave_b.gd` |
| AC6.5 | Root-class catalog, formation rule, reaction dispatcher | Catalog-owned Brakka definition and shared closest-enemy selector | `test_ac6_5_brakka.gd` |
| AC6.6 | `WorldRunState`, `WorldRunSaveCodecV2`, world battle entry, battle initialization UI | Persisted Cache fields plus typed preparation transaction and battle-start modifier application | `test_ac6_6_quartermaster_state.gd` and `test_ac6_6_battle_preparation.gd` |
| AC6.7 | Production world/battle/reward flows | No compensating feature code; integration and evidence only | `test_ac6_7_goblin_integration.gd` plus GodotIQ runtime record |

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
- Snared;
- Armor;
- Bleed;
- temporary Speed modifiers and immediate unresolved-queue rebuilding;
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

This wave proves Armor, enemy-bound Advantage, Snared, post-hit application timing, temporary Speed control, optional self movement, multi-target status atomicity, and unresolved-queue rebuilding.

### AC6.4 — Goblin class wave B

Implement the complete authored loadouts for:

- Scrapbroker;
- Shivrunner;
- Mobcaller.

This wave proves support targeting, threshold requirements, Bleed, Advantage consumption history, distinct allied-attacker scaling, and mixed-race interaction conditions.

### AC6.5 — Brakka Rustbanner

Implement Brakka as a catalog-owned commander definition:

- retain the Scrapshield Bruiser base identity and stats unless the authoritative commander record explicitly overrides them;
- retain Shield Tap, Pack Brace, and Banner Nudge, then add Banner Holder as the fourth commander skill;
- apply Advantage to the active enemy closest to Brakka;
- break equal-distance ties frontline before backline, then lowest slot index;
- revalidate target activity and distance before application without redirecting a stale result;
- apply the once-per-round guard;
- prevent Default Attack and Default Swap from consuming Advantage;
- log the authored success or no-active-enemy result.

### AC6.6 — Scrapline Quartermaster world-map integration

Implement the full world-map choice rather than the documented fallback:

- gain one Cache charge after every four accepted moves;
- store at most one charge;
- do not change movement range, movement count, reveal authority, or encounter generation;
- consume Cache only when entering a Combat encounter and only after a valid preparation choice commits;
- require one of these choices before combat actions begin:
  - **Frontline Briefing:** choose one active enemy to begin with Advantage;
  - **Spare Plating:** all active front-row allies begin with `+2 Armor`;
- do not consume Cache on Safe or Boss encounters;
- persist Cache and any required transaction state through save and reload;
- reject cancellation, stale targets, or stale battle setup without partial application or Cache consumption.

The preparation UI is a transaction boundary between world state and battle initialization. Battle actions remain locked until a valid choice commits or no preparation choice is required.

### AC6.7 — Goblin integration gate

Verify the complete Goblin slice through current production entry points:

- all six regular classes;
- Brakka's three-plus-one commander loadout and Passive trigger;
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

Run-character and catalog definitions own stable identity, base stats, class identity, commander identity, and authored skills. They do not own current HP, Armor, Advantage, Snared, Bleed, temporary Speed modifiers, cooldowns, action history, Passive guards, side, or slot index.

### Skill and effect definitions

Skills remain typed definitions. Shared effect operations represent direct damage, formation movement, Armor, Advantage, Snared, Bleed, temporary Speed changes, and cooldown adjustment. Goblin classes compose these operations instead of embedding class-specific mutation branches in `BattleArena`.

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
3. Determine and lock any eligible Advantage consumption and authored rider.
4. Resolve direct damage through Defense using the locked rider.
5. Spend Armor after Defense; apply remaining damage to HP.
6. Apply declared formation movement atomically.
7. Consume the locked Advantage and apply ordered post-hit Advantage, Snared, Armor, Bleed, or temporary-stat effects. A token created after damage cannot be consumed by that same hit.
8. Apply the new cooldown and authored cooldown adjustments.
9. Record one typed authoritative history transaction, including associated Passive reactions.
10. Resolve defeat and battle outcome.
11. Rebuild unresolved queue entries immediately when a supported Speed effect requires it.
12. Resolve declared action-end or round-end ticks and later cooldown decrements.

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
5. Atomically apply the battle-start modifier and consume Cache. Frontline Briefing places Advantage on the selected enemy; Spare Plating grants Armor to active front-row allies.
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
- Advantage enemy eligibility, shared consumption, replacement, expiry, post-hit application timing, authored riders, and exclusions;
- Snared application, refresh, expiry, Tripline's one follow-up, non-consumption by Holdfast Wire, and Ring Net atomicity;
- Bleed source snapshots, stacks, duration, reapplication, action ticks, exclusions, defeat, and cleanup;
- legal and illegal movement paths, stale occupancy, multi-target atomicity, and history;
- cooldown creation and authored cooldown reduction timing;
- distinct-attacker and forced-movement history queries;
- Passive ordering, guards, bounded reactions, and lifecycle reset;
- every Goblin skill's valid case, rejection cases, preview, confirmation, cooldown, history, log, and relevant AI legality condition;
- Brakka's three-plus-one loadout, closest-enemy tie-break, stale/no-enemy paths, and once-per-round rule;
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

- **AC6-AC01 — Milestone governance:** AC6 is represented as seven ordered criteria in the active game specification without changing AC3.4's meaning or status.
- **AC6-AC02 — Formation semantics:** The world-map preview, party management, battle grid, save formation, and runtime roster agree that slots `0..2` are front and `3..5` are back.
- **AC6-AC03 — Shared mechanics:** Shared Power/Defense damage, Default actions, movement, Advantage, Snared, Armor, Bleed, temporary Speed, cooldown adjustment, history queries, and Passive processing satisfy their authoritative contracts.
- **AC6-AC04 — Regular Goblins:** All six Goblin classes expose and correctly resolve their complete authored three-skill Set 1 loadouts.
- **AC6-AC05 — Brakka:** Brakka retains all three Scrapshield skills, adds Banner Holder as the fourth commander skill, and deterministically targets the closest enemy.
- **AC6-AC06 — Quartermaster:** Scrapline Quartermaster implements Cache accrual and the complete Frontline Briefing/Spare Plating choice without changing movement economy or reveal authority.
- **AC6-AC07 — Atomicity:** All action, movement, keyword, Passive, and preparation transactions reject invalid or stale state atomically.
- **AC6-AC08 — Battle isolation:** Battle-local state clears at battle end, and every new battle receives fresh runtime unit state from persistent run definitions.
- **AC6-AC09 — Durability:** Cache and required authoritative world state survive save/reload without duplication or loss.
- **AC6-AC10 — Progression exclusion:** Leveling, evolution, and mechanical progression remain unimplemented and are recorded as explicit deferred decisions.
- **AC6-AC11 — Integration evidence:** Focused tests, retained regression suites, GodotIQ validation, project parser checks, signal audit, production startup, runtime interactions, and debug-console checks must pass and be recorded with current evidence.

## Acceptance-to-evidence traceability

This is the required evidence ledger. “Baseline” means an older test exercises a reusable foundation only. A PASS row names current implementation and verification evidence; partial foundation work does not satisfy a broader criterion.

| ID | Type | Existing baseline evidence | Required AC6 verification path | Current status and gap |
|---|---|---|---|---|
| AC6-AC01 | Documentation | This design and the active game specification | Document diff confirming AC6.1–AC6.7 plus unchanged AC3.4; implementation-plan links per criterion | **FAIL:** active specification and implementation links not yet updated |
| AC6-AC02 | Logic / visual | `test_ac3_3_party_formation.gd` preserves slot indices; `test_world_map_hud.gd` asserts canonical labels | Exact `0..2 -> FrontSlot0..2`, `3..5 -> BackSlot0..2` assertions; production GodotIQ HUD inspection; battle conversion comparison | **PASS (2026-08-29):** HUD 25/25, party formation 37/37, production UI map and screenshot agree |
| AC6-AC03 | Logic | `test_ac6_1_combat_foundation.gd` covers fresh Power/Defense, physical damage, shared formation rules, Default Attack, movement, and Default Swap | Add `test_ac6_2_keyword_reactions.gd`, with one focused case per canonical lifecycle rule | **FAIL / PARTIAL:** AC6.1 foundation passes 36/36; Advantage, Snared, Armor, Bleed, reactions, and Goblin effects remain absent |
| AC6-AC04 | Logic / integration | Four-slot presentation and generic CharacterSkill tests only | Planned `test_ac6_3_goblin_wave_a.gd`, `test_ac6_4_goblin_wave_b.gd`, and catalog/loadout assertions for all 18 regular skills | **FAIL:** no Goblin runtime definitions or skill tests |
| AC6-AC05 | Logic / runtime | Existing lane-distance sorting is reusable but currently implements only a farthest-enemy target rule | Planned `test_ac6_5_brakka.gd`: three-plus-one loadout, activity filter, distance, tie order, stale target, no enemy, once-per-round; runtime log check | **FAIL:** no shared closest rule, scheduler, or Brakka definition |
| AC6-AC06 | Integration / runtime | Existing world battle entry and save tests provide entry/save seams only | Planned `test_ac6_6_quartermaster_state.gd`, `test_ac6_6_battle_preparation.gd`, and production Cache-to-choice-to-battle runtime walkthrough | **FAIL:** Cache fields, prep state, UI, and hook do not exist |
| AC6-AC07 | Logic | AC2.8 revision confirmation plus AC6.1 stale default-action and stale-occupancy snapshots | Each later AC6 mechanic must prove rejection leaves every owned state unchanged; preparation cancellation/staleness receives dedicated cases | **FAIL / PARTIAL:** AC6.1 action atomicity is covered; keyword, Passive, and preparation transactions do not exist |
| AC6-AC08 | Integration | Fresh Power/Defense conversion is isolated; existing battle configuration and reward/next-battle tests prove generic transitions | Planned `test_ac6_7_goblin_integration.gd` must end battle, start another, and assert no HP/status/cooldown/reaction-guard leakage | **FAIL / PARTIAL:** stable stats do not leak, but AC6 keyword/reaction cleanup cannot yet be tested |
| AC6-AC09 | Save / integration | `test_world_run_save_codec_v2.gd` round-trips current run state and formation | Extend codec tests for Cache charge/remainder, legacy defaults, corrupt bounds, pre-choice reload, and post-commit single consumption | **FAIL:** current schema has no Cache data |
| AC6-AC10 | Documentation | Goblin class and commander docs mark progression deferred | Exact `TO_CONSIDER.md` entries plus repository search proving no Goblin level/evolution/mechanical implementation was added | **FAIL:** deferred entries still need implementation-step verification |
| AC6-AC11 | Runtime / integration | AC6.1 selected regression gate passes 19/19 runners; GodotIQ startup and parser gate pass | Current full suite; GodotIQ validate/check-errors/orphan-signal gate; production startup; recorded formation, Goblin skill, reward, next-battle, Cache, save/reload checks | **FAIL / PARTIAL:** AC6.1 evidence exists, but this aggregate gate depends on AC6-AC01 through AC6-AC10 |

**Coverage result:** 1/11 AC6 acceptance criteria has complete evidence. All 11 have a concrete verification path; AC6-AC11 is the aggregate runtime gate. Overall milestone traceability remains **FAIL**.

## AC6.1 evidence record — 2026-08-29

**Implementation commits:** `0fb5606`, `0e9b68e`, `db61da3`, `eebab48`, `ce8fddf`, `f4a3417`, `1ae3f0b`.

- Focused foundation runner: `AC6.1 combat foundation: PASS (36/36)`.
- Selected regression gate: 19/19 runners passed, comprising every `Tests/Battle/test_*.gd` runner plus world-map HUD, party management, party formation, world battle entry, and world cutover entry.
- Key retained counts: HUD 25/25, party management 31/31, party formation 37/37, speed order 12/12, damage/log 18/18, battle results 9/9, reward selection 17/17, character skills 19/19, active-turn lock 5/5.
- GodotIQ: 116 scripts compile with zero parser errors; project convention audit remains at the pre-existing 19 findings (0 errors, 13 warnings, 6 info); signal audit reports zero orphan signals; production main-scene startup PASS with zero captured runtime/debug errors.
- Production formation evidence: the runtime HUD places `Player Front 1..3` in `FrontSlot0..2` and the slot-3 Scout in `BackSlot0`; party and battle conversion tests preserve the same indices.
- Scope boundary: this record earns AC6-AC02 only. AC6-AC03, AC6-AC07, AC6-AC08, and AC6-AC11 remain partial because keywords, reactions, Goblin content, preparation, and full integration are not implemented.

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
