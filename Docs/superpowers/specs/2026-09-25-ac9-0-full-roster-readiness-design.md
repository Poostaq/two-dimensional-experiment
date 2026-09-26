# AC9.0 Full Roster Readiness Design

**Acceptance criterion:** AC9.0 — Implement and verify the remaining races and their commanders before habitat, habitat-town-placement, or inter-habitat-road implementation.

**Status:** Implemented and verified — 2026-09-26.

**Owner:** Project Lead — AC9.0 content-readiness delivery owner.

**CI policy:** Add required job `ac9-0-roster-readiness`. It passes only when every AC9.0 headless runner exits `0`, reports every assertion passing, emits no parser/runtime errors, and writes the required automated artifact. A failed assertion, missing expected class/commander ID, nonzero exit, or `SCRIPT ERROR` fails the job.

## Goal

Make every approved race roster production-ready before AC9 world topology work begins. The completed catalog comprises eight factions: the already implemented Goblins and the seven AC9.0 factions (Orcs, Lizardmen, Harpies, Werewolves, Humans, Elves, and Dwarves). Every faction has six regular classes with its approved three-skill loadout; every faction has a commander with the root class's three skills plus one deterministic commander skill. The five monster commanders are player-selectable. The three human-aligned commanders are enemy-only and lead authored boss-party fixtures.

## Scope and boundaries

AC9.0 contains no habitat generation, habitat ownership, town placement, roads, clan-selection UI, spawn placement, AC10 campaign behavior, progression, XP, unlocks, or respec systems. Those remain owned by AC9.1-AC9.10, AC10, and the explicitly deferred progression documents.

Existing Goblin production content is reused only after it passes the consolidated catalog, combat, presentation, and save/reload gates. Lore, data-only catalog records, a standalone debug team, and a non-persistent commander card do not satisfy readiness.

## Architecture

### Shared battle and content contract

Before faction packets are added, establish one typed, data-driven contract for class definitions, skill definitions, commander extensions, battle-unit construction, AI action eligibility, presentation metadata, and durable IDs. Reusable mechanics required by approved class sheets are delivered at this layer: Power/Defense damage handling, consumable Armor, Bleed, one-axis Poison, Stun/Stun Guard, Advantage lifecycle, actual-damage Leech, ring movement and swaps, deterministic passive/reaction dispatch, status-aware preview/commit behavior, logs, tooltips, and battle cleanup.

The shared layer owns rules and validation; faction catalogs own authored definitions, display metadata, stable identifiers, root-class mapping, and their commander-specific fourth skill. Runtime battle state owns mutable HP, statuses, cooldowns, formation slots, and trigger guards. Save state stores stable class and commander identities plus mutable run state, never localized display text or presentation-node references.

### Faction packets

After the shared foundation is green, deliver each remaining faction as an independently verifiable packet:

1. Orcs — six regular classes plus Goruk Ironline, War-Khan.
2. Lizardmen — six regular classes plus Sszek Still-Mire, Delta Strategist.
3. Werewolves — six regular classes plus Veyra Moontrace, Hunt Matriarch.
4. Harpies — six regular classes plus Kyris Windscar, Sky Matron.
5. Humans — six regular classes plus Marshal Elian Voss, rooted in Vanguard.
6. Elves — six regular classes plus Lady Saelith Moonfall, rooted in Highborn Mystic.
7. Dwarves — six regular classes plus Thane Brokk Stonevein, rooted in Forgewarden.

Each packet adds catalog loading and validation, authored skill behavior through the shared engine, deterministic player or enemy party fixtures, battle and UI presentation, save/reload reconstruction, focused automated tests, and durable evidence. The player-facing packets are Orc, Lizardman, Werewolf, and Harpy. The Human, Elf, and Dwarf packets are enemy-facing and must each provide a commander-led boss party; they are not exposed as player choices in AC9.0.

### Commander rules

Every commander inherits exactly the three approved skills of one root class and appends exactly one commander-specific fourth skill. Commander passives use explicit trigger timing, deterministic target/ally tie breaks, once-per-round or equivalent recursion guards, stale-state revalidation, counterplay, preview/log/tooltip text, and battle teardown behavior.

The existing player commander designs remain authoritative for Brakka Rustbanner, Goruk Ironline, Veyra Moontrace, Sszek Still-Mire, and Kyris Windscar. The three new enemy commanders require authored fourth-skill designs consistent with their faction identities before implementation:

- Elian Voss: Human Vanguard; command-and-Armor line leadership.
- Saelith Moonfall: Elf Highborn Mystic; precision setup and conversion.
- Brokk Stonevein: Dwarf Forgewarden; defensive line endurance.

All eight commanders receive stable IDs, root-class IDs, portrait/card metadata, readable skill tooltips, combat-log labels, and save-safe reconstruction.

**Player-selectable commanders:**

- Commander: Brakka Rustbanner — Root class: `scrapshield_bruiser`
- Commander: Goruk Ironline — Root class: `orc_iron_tusk_vanguard`
- Commander: Veyra Moontrace — Root class: `werewolf_moonfang_skirmisher`
- Commander: Sszek Still-Mire — Root class: `lizardman_venom_saurian`
- Commander: Kyris Windscar — Root class: `harpy_talon_duelist`

Human, Elf, and Dwarf commanders are enemy-only in AC9.0.

## Concrete artifact contract

Faction catalog scripts use lower-case singular faction prefixes and are created only when that faction packet begins. Each faction has `<faction>_commander_catalog.gd`; six-class rosters use `_wave_a_catalog.gd` for the first three class IDs and `_wave_b_catalog.gd` for the final three.

| Faction | Commander | Root class ID | Catalog artifacts | Expected regular `class_id` values | Faction integration test |
|---|---|---|---|---|---|
| Orc | Goruk Ironline | `orc_iron_tusk_vanguard` | `Scripts/Run/orc_commander_catalog.gd`, `Scripts/Run/orc_wave_a_catalog.gd`, `Scripts/Run/orc_wave_b_catalog.gd` | `orc_iron_tusk_vanguard`, `orc_bonebreaker_reaver`, `orc_bloodbanner_captain`, `orc_chainwarden`, `orc_war_drummer`, `orc_siegebreaker` | `Tests/Battle/test_ac9_1_orcs_integration.gd` |
| Lizardman | Sszek Still-Mire | `lizardman_venom_saurian` | `Scripts/Run/lizardman_commander_catalog.gd`, `Scripts/Run/lizardman_wave_a_catalog.gd`, `Scripts/Run/lizardman_wave_b_catalog.gd` | `lizardman_venom_saurian`, `lizardman_scale_sentinel`, `lizardman_mire_spitter`, `lizardman_fang_alchemist`, `lizardman_reed_ambusher`, `lizardman_sunscale_warder` | `Tests/Battle/test_ac9_2_lizardmen_integration.gd` |
| Werewolf | Veyra Moontrace | `werewolf_moonfang_skirmisher` | `Scripts/Run/werewolf_commander_catalog.gd`, `Scripts/Run/werewolf_wave_a_catalog.gd`, `Scripts/Run/werewolf_wave_b_catalog.gd` | `werewolf_moonfang_skirmisher`, `werewolf_pack_howler`, `werewolf_bloodtrail_stalker`, `werewolf_duskhide_ravager`, `werewolf_den_warden`, `werewolf_moonblood_seer` | `Tests/Battle/test_ac9_3_werewolves_integration.gd` |
| Harpy | Kyris Windscar | `harpy_talon_duelist` | `Scripts/Run/harpy_commander_catalog.gd`, `Scripts/Run/harpy_wave_a_catalog.gd`, `Scripts/Run/harpy_wave_b_catalog.gd` | `harpy_talon_duelist`, `harpy_storm_siren`, `harpy_gale_scout`, `harpy_skyhook_raider`, `harpy_nestguard`, `harpy_carrion_cantor` | `Tests/Battle/test_ac9_4_harpies_integration.gd` |
| Human | Marshal Elian Voss | `human_vanguard` | `Scripts/Run/human_commander_catalog.gd`, `Scripts/Run/human_wave_a_catalog.gd`, `Scripts/Run/human_wave_b_catalog.gd` | `human_vanguard`, `human_ranger`, `human_iron_sentinel`, `human_field_medic`, `human_crosbowman`, `human_duelist` | `Tests/Battle/test_ac9_5_humans_integration.gd` |
| Elf | Lady Saelith Moonfall | `elf_highborn_mystic` | `Scripts/Run/elf_commander_catalog.gd`, `Scripts/Run/elf_wave_a_catalog.gd`, `Scripts/Run/elf_wave_b_catalog.gd` | `elf_star_archer`, `elf_moon_sage`, `elf_wind_dancer`, `elf_warden_of_the_grove`, `elf_crescent_duelist`, `elf_highborn_mystic` | `Tests/Battle/test_ac9_6_elves_integration.gd` |
| Dwarf | Thane Brokk Stonevein | `dwarf_forgewarden` | `Scripts/Run/dwarf_commander_catalog.gd`, `Scripts/Run/dwarf_wave_a_catalog.gd`, `Scripts/Run/dwarf_wave_b_catalog.gd` | `dwarf_forgewarden`, `dwarf_siege_smith`, `dwarf_rune_sentinel`, `dwarf_quarrel_engineer`, `dwarf_hearthkeeper`, `dwarf_thunderbreaker` | `Tests/Battle/test_ac9_7_dwarves_integration.gd` |

The existing Goblin catalog artifacts remain the compatibility baseline: `Scripts/Run/goblin_commander_catalog.gd`, `Scripts/Run/goblin_wave_a_catalog.gd`, and `Scripts/Run/goblin_wave_b_catalog.gd`. Its class IDs are `scrapshield_bruiser`, `wirefang_skirmisher`, `snarewright`, `scrapbroker`, `shivrunner`, and `mobcaller`; its commander ID is `brakka_rustbanner`. Its regression coverage remains `Tests/Battle/test_goblin_encounter_integration.gd` plus the AC6 runners.

The corresponding design authority for every row is `Docs/Races/<Faction>/Classes.md`; no runtime code derives IDs from display names.

## Delivery sequence

Split the work into these bounded milestones rather than attempting one monolithic catalog change:

1. Baseline and shared-contract audit: inventory existing Goblin seams and test coverage; record baseline validation and runtime behavior.
2. Shared mechanics foundation: finish missing typed rules and tests before a faction depends on them.
3. Catalog/presentation/persistence foundation: standardize faction-owned definitions and durable identity reconstruction.
4. Four player-faction packets: Orcs, Lizardmen, Werewolves, Harpies, in that order; each closes its own combat/save/presentation evidence.
5. Three enemy-faction packets: Humans, Elves, Dwarves; each includes the named commander and an authored boss-party fixture.
6. Full-catalog integration: verify all 48 regular classes and eight commanders, player selection reachability for all five monster commanders, deterministic enemy boss-fixture construction, and cross-run identity persistence.
7. AC9.0 evidence and documentation gate: record automated, runtime, and visual evidence; only then mark AC9.0 complete and permit AC9 habitat implementation.

| Milestone | Owner | ETA |
|---|---|---|
| 1. Baseline and shared-contract audit | AC9.0 implementation owner | Completed 2026-09-26 |
| 2. Shared mechanics foundation | AC9.0 implementation owner | Completed 2026-09-26 |
| 3. Catalog/presentation/persistence foundation | AC9.0 implementation owner | Completed 2026-09-26 |
| 4. Player-faction packets | AC9.0 implementation owner | Completed 2026-09-26 |
| 5. Enemy-faction packets | AC9.0 implementation owner | Completed 2026-09-26 |
| 6. Full-catalog integration | AC9.0 implementation owner | Completed 2026-09-26 |
| 7. Evidence and documentation gate | Project Lead | Completed 2026-09-26 |

## Data flow

`Faction catalog -> class/commander definition -> run or boss-party fixture -> BattleUnitState -> BattleArena rules and presentation -> versioned run save -> reconstructed catalog definition on Continue`.

Catalog validation fails before a fixture, battle, or save mutation if a class has the wrong skill count, a commander has an unknown root class or incorrect four-skill loadout, an ID is duplicated, a required display field is absent, or an enemy boss fixture lacks its commander. Failed construction does not partially replace a run or mutate an existing saved roster.

## Verification contract

Automated checks must prove:

- every regular class loads its exact approved three-skill definition and every commander loads its root three plus exactly one commander skill;
- every required shared mechanic handles application, caps, refresh/expiry, invalid/stale/cancelled actions, and battle teardown without mutation leaks;
- deterministic targeting, passive guards, action ordering, AI eligibility, logs, and tooltips work for commander and regular skills;
- all player-facing commanders can be constructed from valid selectable identities, and invalid faction/commander identities are rejected atomically;
- each enemy faction constructs an authored commander-led party, not a generic debug encounter;
- save/reload preserves class IDs, commander IDs, root-class IDs, display metadata resolution, formation, and legal mutable battle/run state;
- Goblin behavior and existing AC6/AC8 contracts remain green.

Each faction integration runner named in the artifact contract asserts all six exact class IDs, constructs each class with exactly three approved skills, constructs the named commander with its root three plus exactly one fourth skill, rejects unknown IDs without mutation, resolves representative active/passive behavior, and performs a save/reload identity round trip. Human, Elf, and Dwarf runners additionally construct their authored commander-led boss-party fixture. Shared-mechanics runners provide their own focused assertions; packet tests must not replace them.

Runtime verification must launch battle scenarios for each faction, exercise representative active, passive, movement, status, and commander actions, inspect debug output for parser/runtime errors, and prove a save/reload reconstruction. Visual verification must inspect the player commander selector and the enemy commander/boss-party battle presentation at supported resolutions.

### Numerical acceptance thresholds

- **Automated:** 100% of assertions pass in every AC9.0 runner and all named Goblin/AC6/AC8 regressions; every headless invocation exits `0`.
- **Catalog:** exactly 48 regular class IDs and exactly 8 commander IDs construct once; each regular class has exactly 3 skills and each commander exactly 4.
- **Persistence:** 100% of eight commander IDs and 48 regular class IDs round-trip through the supported save/reload path without ID, root-class, formation, or presentation-resolution drift.
- **Runtime:** `read_debug_console` contains 0 parser errors, 0 runtime errors, and 0 unhandled exceptions for the representative faction scenarios.
- **Visual:** 2 required screenshots per reviewed surface—1152×648 and 1920×1080—match their approved golden fixtures for the player commander selector and each enemy commander/boss-party presentation.

AC9.0 remains unchecked until all evidence is stored under `Docs/Specs/AC9/Evidence/AC9.0/` and the consolidated gate passes. Habitat, town, and road implementation remain blocked until then.

## Risks and controls

- **Mechanics fan-out:** Shared mechanics are tested before and after every faction packet; packet tests may not encode faction-specific rule forks.
- **Oversized delivery:** Each faction is a separately committed, independently runnable milestone with no partial catalog exposure.
- **Save incompatibility:** Reuse the repository's explicit versioned codec dispatch; old saves remain decoded by their original schema and are never reinterpreted as AC9 topology.
- **Presentation drift:** Catalog display metadata is the sole source for cards, battle labels, logs, and tooltips; UI nodes do not invent identity.
- **Premature AC9 work:** Tests and task ordering explicitly prohibit habitat/town/road generator edits within AC9.0.

## Acceptance decision

When the final integration and evidence gate passes, update `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` to mark AC9.0 complete and link its evidence. Do not mark AC9.1 or later criteria complete as part of this work.

## Evidence checklist

- [x] `ac9-0-roster-readiness` is defined and its complete job payload passes locally; output is stored in `Docs/Specs/AC9/Evidence/AC9.0/automated-test.log`.
- [x] Every faction integration test named in the concrete artifact contract is green and represented in `automated-test.log`.
- [x] Shared-mechanics, catalog, persistence, Goblin, AC6, and AC8 regression runners are green and represented in `automated-test.log`.
- [x] Required 1152×648 and 1920×1080 golden-fixture comparisons, runtime commands, and debug-console result are recorded in `Docs/Specs/AC9/Evidence/AC9.0/rendered-qa.log`.
- [x] `Docs/Specs/AC9/Evidence/AC9.0/verification.md` links the two logs, lists generated screenshots, confirms every numerical threshold, and records the Project Lead's AC9.0 sign-off.
