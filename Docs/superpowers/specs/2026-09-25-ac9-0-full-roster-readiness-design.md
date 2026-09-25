# AC9.0 Full Roster Readiness Design

**Acceptance criterion:** AC9.0 — Implement and verify the remaining races and their commanders before habitat, habitat-town-placement, or inter-habitat-road implementation.

**Status:** Approved design; implementation has not started.

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

## Delivery sequence

Split the work into these bounded milestones rather than attempting one monolithic catalog change:

1. Baseline and shared-contract audit: inventory existing Goblin seams and test coverage; record baseline validation and runtime behavior.
2. Shared mechanics foundation: finish missing typed rules and tests before a faction depends on them.
3. Catalog/presentation/persistence foundation: standardize faction-owned definitions and durable identity reconstruction.
4. Four player-faction packets: Orcs, Lizardmen, Werewolves, Harpies, in that order; each closes its own combat/save/presentation evidence.
5. Three enemy-faction packets: Humans, Elves, Dwarves; each includes the named commander and an authored boss-party fixture.
6. Full-catalog integration: verify all 48 regular classes and eight commanders, player selection reachability for all five monster commanders, deterministic enemy boss-fixture construction, and cross-run identity persistence.
7. AC9.0 evidence and documentation gate: record automated, runtime, and visual evidence; only then mark AC9.0 complete and permit AC9 habitat implementation.

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

Runtime verification must launch battle scenarios for each faction, exercise representative active, passive, movement, status, and commander actions, inspect debug output for parser/runtime errors, and prove a save/reload reconstruction. Visual verification must inspect the player commander selector and the enemy commander/boss-party battle presentation at supported resolutions.

AC9.0 remains unchecked until all evidence is stored under `Docs/Specs/AC9/Evidence/AC9.0/` and the consolidated gate passes. Habitat, town, and road implementation remain blocked until then.

## Risks and controls

- **Mechanics fan-out:** Shared mechanics are tested before and after every faction packet; packet tests may not encode faction-specific rule forks.
- **Oversized delivery:** Each faction is a separately committed, independently runnable milestone with no partial catalog exposure.
- **Save incompatibility:** Reuse the repository's explicit versioned codec dispatch; old saves remain decoded by their original schema and are never reinterpreted as AC9 topology.
- **Presentation drift:** Catalog display metadata is the sole source for cards, battle labels, logs, and tooltips; UI nodes do not invent identity.
- **Premature AC9 work:** Tests and task ordering explicitly prohibit habitat/town/road generator edits within AC9.0.

## Acceptance decision

When the final integration and evidence gate passes, update `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` to mark AC9.0 complete and link its evidence. Do not mark AC9.1 or later criteria complete as part of this work.
