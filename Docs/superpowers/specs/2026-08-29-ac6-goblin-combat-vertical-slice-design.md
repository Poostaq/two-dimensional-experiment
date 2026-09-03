# AC6 Goblin Combat Vertical Slice Design

**Status:** AC6.1 through AC6.5 implemented and evidenced; AC6.6–AC6.7 remain incomplete

**Date:** 2026-08-29

## Purpose

Deliver the complete authored Goblin combat roster as a sequence of bounded acceptance criteria: six regular classes, Brakka Rustbanner as the Goblin commander, every shared combat mechanic those kits require, and Brakka's full world-map preparation choice. Correct the reversed world-map formation preview as part of the shared formation foundation.

This milestone does not implement character progression. AC3.4 remains unchecked. Leveling, evolution, and mechanical-unit upgrade models must be re-evaluated before implementation and recorded as deferred product decisions in `Docs/TO_CONSIDER.md`.

## Evidence status

This document is the acceptance contract and evidence ledger. AC6.1 and AC6.2 describe implemented shared foundations, AC6.3 and AC6.4 supply all six authored regular Goblin classes, and AC6.5 supplies Brakka and her production run-selection path; later criteria remain prospective until their own evidence gates pass.

Repository inspection on 2026-08-29 found reusable AC2/AC3 foundations. AC6.1 subsequently implemented the Power/Defense, Default-action, movement, history, and formation foundation; AC6.2 subsequently implemented the shared keyword and Passive foundation recorded below.

The following remain missing as later AC6 implementation evidence: Cache fields, the preparation transaction/hook and UI, Cache save/reload coverage, and the AC6.6–AC6.7 focused/runtime records.

Each AC6 criterion remains **NOT IMPLEMENTED / TRACEABILITY FAIL** until its planned failing test exists, the implementation link is recorded, the test passes, and required GodotIQ runtime evidence is captured. AC6.1 through AC6.5 have earned those bounded records; this does not complete the overall AC6 milestone.

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

### Implementation ownership and links

Rows with recorded commits and passing evidence identify implemented ownership; rows without them remain planned TDD ownership. Later implementation plans may extract smaller typed helpers after GodotIQ impact checks, but must update this table whenever ownership changes.

| Criterion | Existing integration seam | Planned production ownership | Planned focused evidence |
|---|---|---|---|
| AC6.1 | `BattleUnitState`, `BattleSkillRules`, `BattleArena`, `RunRoster.create_battle_units()`, `world_map_hud` | Extend battle stats/default actions and shared formation semantics; correct HUD slot mapping | `test_ac6_1_combat_foundation.gd` plus updated HUD/formation tests |
| AC6.2 | Battle state, skill effect plan, arena history/queue | Implemented by `0ce9d12`, `d134cad`, `961de03`, `8471292`, `5893e6c`, `f62538d`, `034e3ab`, and `23ecb94`; arena remains transaction coordinator | `test_ac6_2_keyword_reactions.gd`: 113/113 on 2026-08-31 |
| AC6.3 | Character catalog and battle skill definitions | Catalog-owned Scrapshield, Wirefang, and Snarewright definitions composed from shared effects | `test_ac6_3_goblin_wave_a.gd` |
| AC6.4 | Character catalog and battle skill definitions | Implemented by `740367b`, `cf36b8b`, `4374683`, `d1d48eb`, `ef3a000`, and `519110d`; catalog-owned Scrapbroker, Shivrunner, and Mobcaller definitions compose shared history-aware effects | `test_ac6_4_goblin_wave_b.gd`: 93/93 on 2026-09-01 |
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
| AC6-AC01 | Documentation | This design and the active game specification | Document diff confirming AC6.1–AC6.7 plus unchanged AC3.4; implementation-plan links per criterion | **PASS (2026-09-03):** the active specification marks AC6.1–AC6.7 complete, the criterion plans are retained under `Docs/superpowers/plans/`, and AC3.4 remains unchanged. |
| AC6-AC02 | Logic / visual | `test_ac3_3_party_formation.gd` preserves slot indices; `test_world_map_hud.gd` asserts canonical labels | Exact `0..2 -> FrontSlot0..2`, `3..5 -> BackSlot0..2` assertions; production GodotIQ HUD inspection; battle conversion comparison | **PASS (2026-08-29):** HUD 25/25, party formation 37/37, production UI map and screenshot agree |
| AC6-AC03 | Logic | `test_ac6_1_combat_foundation.gd` covers fresh Power/Defense, physical damage, shared formation rules, Default Attack, movement, Default Swap, and authoritative committed-action history | `test_ac6_2_keyword_reactions.gd`, with focused cases for each canonical lifecycle rule | **PASS (2026-08-31):** AC6.1 passes 40/40 and AC6.2 passes 113/113; shared Advantage, Snared, Armor, Bleed, temporary Speed, cooldown adjustment, history queries, bounded deterministic Passives, rejection atomicity, and cleanup are implemented. Authored Goblin loadouts remain AC6-AC04. |
| AC6-AC04 | Logic / integration | Four-slot presentation and generic CharacterSkill tests only | `test_ac6_3_goblin_wave_a.gd`, `test_ac6_4_goblin_wave_b.gd`, and catalog/loadout assertions for all 18 regular skills | **PASS (2026-09-01):** AC6.3 and AC6.4 implement and verify all six regular Goblin classes and all 18 Set 1 skills, including Wave B history-derived effects, conditional armor, mixed-side ordered targeting, invalid-confirmation atomicity, and production arena resolution. |
| AC6-AC05 | Logic / runtime | Shared formation, reaction, keyword, launcher, roster, and save seams | `test_ac6_5_brakka.gd`: three-plus-one loadout, activity filter, distance, tie order, stale target, no enemy, once-per-round, Advantage exclusions, and runtime log check | **PASS (2026-09-02):** Brakka is the sole selectable commander, occupies slot 1, retains Scrapshield's three skills, appends Banner Holder, and resolves its guarded closest-enemy Advantage through the shared arena path. |
| AC6-AC06 | Integration / runtime | Existing world battle entry and save tests provide entry/save seams only | `test_ac6_6_quartermaster_state.gd`, `test_ac6_6_battle_preparation.gd`, and production Cache-to-choice-to-battle runtime walkthrough | **PASS (2026-09-03):** AC6.6 evidence proves Cache accrual, both preparation choices, action locking, atomic failure/retry, offered/committed reload, cleanup, and Safe/Boss exclusion. |
| AC6-AC07 | Logic | AC2.8 revision confirmation plus AC6.1 stale default-action and stale-occupancy snapshots | Each later AC6 mechanic must prove rejection leaves every owned state unchanged; preparation cancellation/staleness receives dedicated cases | **PASS (2026-09-03):** AC6.2, AC6.5, and AC6.6 focused runners prove stale/rejected keyword, Passive, target, setup, cancellation, and failed-save paths remain atomic. |
| AC6-AC08 | Integration | Fresh Power/Defense conversion is isolated; existing battle configuration and reward/next-battle tests prove generic transitions | `test_ac6_7_goblin_integration.gd` ends battle, starts another, and asserts no HP/status/cooldown/reaction-guard leakage | **PASS (2026-09-03):** the 104-assertion production runner covers real targeting, movement, reward replacement, party rearrangement, save/reload, preparation, formation persistence, and fresh next-battle HP, Speed, Armor, Advantage, Snared, Bleed, cooldown, history, and Passive-guard state. |
| AC6-AC09 | Save / integration | `test_world_run_save_codec_v2.gd` round-trips current run state and formation | Codec and integration tests cover Cache charge/remainder, legacy defaults, corrupt bounds, pre-choice reload, and post-commit single consumption | **PASS (2026-09-03):** AC6.6 codec/runtime evidence and AC6.7's reload-to-next-battle path preserve exact Cache/formation state and consume one ready Cache exactly once. |
| AC6-AC10 | Documentation | Goblin class and commander docs mark progression deferred | `TO_CONSIDER.md` entry plus repository search proving no Goblin level/evolution/mechanical implementation was added | **PASS (2026-09-03):** the exclusion search found no implementation under `Scripts`, `Scenes`, or `Tests`; Goblin class, commander, and consideration docs retain explicit progression deferral. |
| AC6-AC11 | Runtime / integration | Earlier bounded regression gates and GodotIQ startup/parser checks | Current full suite; GodotIQ validate/check-errors/orphan-signal gate; production startup; recorded formation, Goblin skill, reward, next-battle, Cache, save/reload checks | **PASS (2026-09-03):** all 61 retained runners pass; AC6.7 passes 104/104 twice deterministically; 145 scripts parse with zero errors; signal analysis finds zero orphans; production startup captures zero runtime/script errors. Project validation reports 0 errors with 26 pre-existing warnings and 6 informational findings. |

**Coverage result:** 11/11 AC6 acceptance criteria have complete evidence. AC6-AC11 passes the aggregate runtime gate. Overall milestone traceability is **PASS**.

## AC6.1 evidence record — 2026-08-29

**Implementation commits:** `0fb5606`, `0e9b68e`, `db61da3`, `eebab48`, `ce8fddf`, `f4a3417`, `1ae3f0b`, `b041602`.

- Focused foundation runner: `AC6.1 combat foundation: PASS (39/39)`.
- Selected regression gate: 19/19 runners passed, comprising every `Tests/Battle/test_*.gd` runner plus world-map HUD, party management, party formation, world battle entry, and world cutover entry.
- Key retained counts: HUD 25/25, party management 31/31, party formation 37/37, speed order 12/12, damage/log 18/18, battle results 9/9, reward selection 17/17, character skills 19/19, active-turn lock 5/5.
- GodotIQ: 116 scripts compile with zero parser errors; project convention audit remains at the pre-existing 19 findings (0 errors, 13 warnings, 6 info); signal audit reports zero orphan signals; production main-scene startup PASS with zero captured runtime/debug errors.
- Production formation evidence: the runtime HUD places `Player Front 1..3` in `FrontSlot0..2` and the slot-3 Scout in `BackSlot0`; party and battle conversion tests preserve the same indices.
- Scope boundary: this record earns AC6-AC02 only. AC6-AC03, AC6-AC07, AC6-AC08, and AC6-AC11 remain partial because keywords, reactions, Goblin content, preparation, and full integration are not implemented.

## AC6.2 evidence record — 2026-08-31

**Implementation commits:** `0ce9d12`, `d134cad`, `961de03`, `8471292`, `5893e6c`, `f62538d`, `034e3ab`, `23ecb94`.

- Focused runner, executed twice after the final fixes with a waited Godot process: `AC6.2 keyword reactions: PASS (113/113)` both times.
- Current Battle regression gate: 15/15 `Tests/Battle/test_*.gd` runners passed. Counted retained results include Speed 12/12, damage/log 18/18, battle results 9/9, rewards 17/17, character skills 19/19, AC6.1 40/40, and active-turn lock 5/5; the remaining runners printed their PASS markers and exited 0.
- Exact focused command shape on Windows: `Start-Process -FilePath <godot> -ArgumentList @('--headless', '--path', <project>, '--script', 'res://Tests/Battle/test_ac6_2_keyword_reactions.gd') -NoNewWindow -Wait -PassThru`. The same waited loop was used for all 15 Battle runners; ordinary invocation of the Steam GUI-subsystem executable is not accepted as evidence because it returns before the child process finishes.
- Project checks: GodotIQ validation inspected 124 scripts and 12 scenes with 0 errors, 12 warnings, and 6 info findings; signal analysis found 0 orphan signals. A fresh waited headless editor process exited 0 after loading project scripts. The live-editor `check_errors(scope="project")` probe reports one low-confidence, line-less `reload error 22` for the already-loaded focused runner; the same file compiles and passes 113/113 in fresh processes, so this is recorded as an editor cache/in-use caveat rather than a parser failure.
- Runtime startup: GodotIQ `verify_project_runs(scene="main", check_scope="scene")` returned PASS; `world_run_start.tscn` attached successfully and the captured console contained 0 runtime errors and 0 script errors.
- Scope boundary: this record earns AC6-AC03 only. AC6.3–AC6.7 remain incomplete: no authored Goblin catalog/loadouts, Brakka closest-enemy implementation, Cache/preparation flow, save integration, or full next-battle runtime walkthrough exists yet.

## AC6.3 evidence record — 2026-08-31

**Implementation commits:** `57ca9e9`, `ad11d50`, `51ae711`, `ce0bb27`, `587361b`, `5c1b0a5`, `37f9b89`, `b6b8821`.

- Focused runner: `AC6.3 Goblin wave A: 116/116 assertions passed.` It covers immutable authoring contracts, semantic targets, exact class IDs/stats/loadouts, Power percentages, Advantage consumption, one-to-two target locking, optional Move 1, Tripline's one-shot delayed Advantage, and authoritative two-target Ring Net resolution.
- Current Battle regression gate: 16/16 `Tests/Battle/test_*.gd` runners passed after the legacy predefined-target regression was reproduced and fixed. Retained counted results include Speed 12/12, damage/log 18/18, battle results 9/9, rewards 17/17, character skills 19/19, AC6.1 40/40, AC6.2 113/113, AC6.3 116/116, and active-turn lock 5/5.
- The waited Windows command shape remains `Start-Process -FilePath <godot> -ArgumentList @('--headless', '--path', <project>, '--script', <runner>) -Wait -PassThru`, used for the focused runner and all 16 Battle runners.
- Project checks: GodotIQ validation inspected 130 scripts and 12 scenes with 0 errors, 12 warnings, and 6 info findings; signal analysis found 0 orphan signals. The live-editor project parser probe retains the known low-confidence, line-less `reload error 22` on the AC6.2 runner, while that runner compiles and passes 113/113 in a fresh waited process.
- Runtime startup: GodotIQ `verify_project_runs(scene="main", check_scope="scene")` returned PASS; `world_run_start.tscn` attached and produced 0 captured runtime errors and 0 script errors.
- Scope boundary: this record completes AC6.3 and advances AC6-AC04/AC6-AC11 only partially. Wave B, Brakka, Cache/preparation, save integration, and full next-battle integration remain AC6.4–AC6.7.

## AC6.4 evidence record — 2026-09-01

**Implementation commits:** `740367b`, `cf36b8b`, `4374683`, `d1d48eb`, `ef3a000`, `519110d`.

- Focused runner, executed twice from the final tree: `AC6.4 Goblin wave B: 93/93 assertions passed.` The two outputs were identical (`DIFF_LINES=0`).
- The focused coverage proves exact Scrapbroker, Shivrunner, and Mobcaller identities, stats, loadouts, cooldowns, targeting, action-history predicates, distinct-attacker scaling, conditional Armor, allied-hit and different-race requirements, invalid-confirmation rejection, and actual `BattleArena` resolution for all nine Wave B skills.
- Current Battle regression gate: 17/17 `Tests/Battle/test_*.gd` runners exited 0. Retained counted results include Speed 12/12, damage/log 18/18, battle results 9/9, rewards 17/17, character skills 19/19, AC6.1 40/40, AC6.2 113/113, AC6.3 116/116, AC6.4 93/93, and active-turn lock 5/5.
- Project checks: GodotIQ validation inspected 132 scripts and 12 scenes with 0 errors, 12 warnings, and 6 info findings; project parsing checked all 132 scripts with 0 errors; signal analysis found 0 orphan signals. The reported missing engine UI signals are test-emitted built-ins rather than project signal-definition defects.
- Runtime startup: GodotIQ `verify_project_runs(scene="main", check_scope="scene", stop_after=true)` returned PASS; `world_run_start.tscn` attached and produced 0 captured runtime errors and 0 script errors.
- Scope boundary: this record completes AC6.4 and AC6-AC04. Brakka, Cache/preparation, save integration, and the full next-battle integration remain AC6.5–AC6.7; AC6-AC11 remains the aggregate milestone gate.

## AC6.5 evidence record — 2026-09-02

**Implementation commits:** `2162bf5`, `bca2260`, `e414dc9`, `d47ee26`, `de42dd9`, `6df1358`, `ba38503`, `f3f2498`.

- Focused runner passed twice with byte-identical output: `AC6.5 Brakka: PASS (70/70)`.
- The runner covers exact commander identity/stats/race/loadout/presentation, every selector tie layer, once-per-round action-start dispatch, source and expiry, stale activity/distance without redirect, no-enemy logs, next-round reuse, and Advantage consumption exclusions.
- All 18 Battle runners exited 0. The bounded launcher, run-start service, Save V2, roster, formation, UI scene, and production cutover runners also exited 0.
- Project checks: 134 scripts and 12 scenes validated with 0 errors; all 134 scripts parsed with 0 errors; signal analysis found 0 orphan signals; production startup passed with 0 captured runtime/script errors.
- Production UI inspection at 1152x648 confirmed the approved two-column commander screen, disabled portrait-adjacent arrows, four skill squares, optional seed, and bottom Begin action. Evidence is stored under `Docs/Specs/AC6/Evidence/AC6.5/2026-09-02/`.
- Scope boundary: this record completes AC6.5 and AC6-AC05, advances AC6-AC07/AC6-AC08/AC6-AC11 only partially, and leaves Cache/preparation and the full next-battle integration to AC6.6–AC6.7.

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
