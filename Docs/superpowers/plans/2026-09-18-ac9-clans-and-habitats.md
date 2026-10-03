# AC9 — Seeded Clans, Habitats and Roads Plan

> For implementation: use `superpowers:executing-plans` after the proposed generation/content defaults below are reviewed. Follow repository AGENTS.md and GodotIQ. Work on a dedicated task branch in the primary workspace; no worktrees.

**Status:** Aggregate roadmap. Approved criterion-specific designs supersede this document where they define a narrower delivery contract. No generator, save or scene changes have been made by this planning document.

## Planning authority and generator versions

This document governs the overall AC9 sequence and the relationships between clan selection, habitats, towns, roads, presentation, and persistence. Once an acceptance-criterion slice has an approved detailed design, that design is authoritative for the slice.

The approved [AC9.4 and AC9.5 seeded habitats and towns design](../specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md) fixes the following version split:

- Generator V2 implements AC9.4 and AC9.5: east/west spawns, four habitats, nine allied towns, and no roads.
- AC9.6 and AC9.7 retain every internal and cross-habitat road requirement below, but will implement them in generator V3 rather than changing V2 output.
- V1 and V2 saves remain immutable compatibility contracts. V3 must not reinterpret or regenerate either topology.

This split changes delivery and version ownership only. It does not remove or weaken AC9.6, AC9.7, or AC9.10.

**Goal:** Build a seeded world for the chosen clan and commander, two randomly selected allied clans, and a Human, Elven or Dwarven main enemy clan.

**Architecture:** A clan catalog owns eligibility and explicit synergy relationships. Run setup freezes selected identities before versioned pure world generators create topology: V2 creates habitats and towns, while V3 adds the final road graph. WorldPlan owns immutable topology; run state owns changing party and town state. The existing launcher and repository commit the new run atomically.

**Tech stack:** Godot 4, typed GDScript, versioned canonical generation, authored Godot scenes, SceneTree tests.

## Confirmed design

- **Required order:** implement the remaining races and their commanders before implementing habitats, habitat town placement or inter-habitat roads. Content completion is a prerequisite, not work deferred until after generation.
- Until that habitat stage is implemented, every existing town counts as Goblin habitat for recruitment. AC8 can ship against the existing town network.

- The player chooses a main clan and then a commander belonging to that clan.
- Choose exactly two distinct other allied clans randomly. At least one must be synergistic with the main clan. Together with the main clan, there are three player-allied habitats.
- After clan/commander and seed are resolved, select the main enemy clan from Human, Elven and Dwarven using the seed.
- The main enemy party contains its clan's commander and is the run's boss party.
- Spawn the enemy on the furthest western hex. Its habitat contains every on-map hex within hex distance 2 of that spawn, extending in every available map direction and clipped at the map boundary.
- Spawn the player on the easternmost hex. Place the main player clan's habitat so that it contains that starting hex.
- Each allied habitat contains exactly three randomly placed towns: nine allied towns in total.
- Only allied habitats contain towns and participate in the town-road network. The enemy habitat has no towns and requires no road connection.
- Town recruits belong to that town's owning clan.
- Town offers exclude every class already present in the current player roster, as defined by AC8.
- In V3 under AC9.6, each allied habitat's three towns receive all three internal pair connections.
- In V3 under AC9.7, every pair of allied habitats receives connections for every cross-habitat town pair tied at the minimum distance.
- Starting a new run never asks for save-overwrite confirmation. Generation/save failure must preserve the previous durable save.

## Explicit implementation proposals

- **Confirmed version split:** V2 contains habitats and nine towns with an empty road array. V3 implements AC9.6 and AC9.7 from the frozen V2 ownership and town requirements without changing V2 canonical output.
- **Proposed habitat layout:** retain the current radius-8 board provisionally; reserve the enemy radius-2 footprint, then partition remaining cells into three connected allied regions using seeded region anchors and a deterministic multi-source flood fill. Main-clan region must contain the chosen player start. Define membership for every cell and avoid overlapping habitat ownership.
- **Proposed distance metric:** shortest traversable hex-step distance, with roads initially cosmetic and no movement-cost discount. Under the current all-traversable board this equals ordinary hex distance. For a selected endpoint pair, draw one canonically tie-broken shortest route, not every possible route permutation.
- **Proposed playable scope:** monster clans (Goblins, Orcs, Lizardmen, Harpies, Werewolves); Human/Elven/Dwarven clans remain the enemy pool. Content readiness must be explicit: most existing production commander support is Goblin-specific. Do not expose a selectable clan or commander until its actual playable catalog is ready.

## Clan selection and content

Convert lore's positive synergies into catalog data; do not parse prose at runtime. Proposed main-clan-directed entries, derived from the three examples in each monster clan's `Docs/Races/<Clan>/Lore.md`:

| Main clan | Eligible guaranteed-synergy partners |
|---|---|
| Goblins | Orcs, Werewolves, Lizardmen |
| Orcs | Goblins, Lizardmen, Harpies |
| Lizardmen | Orcs, Werewolves, Goblins |
| Harpies | Goblins, Orcs, Werewolves |
| Werewolves | Goblins, Lizardmen, Harpies |

Selection proposal: enumerate canonical unordered pairs from eligible clans excluding the main clan; retain pairs containing at least one listed synergy partner; choose one pair using a dedicated seed-derived selection namespace. This samples valid pairs without bias from selecting a guaranteed partner first. Two synergistic allies are allowed. Empty eligible lists are a typed setup failure, never a duplicate clan or silent relaxation.

Use stable IDs for clans, commanders, habitats, towns and boss-party members. Author at least one playable commander and recruit catalog for each exposed player clan, and one commander-led boss party for each of the three enemy clans. Combat balance and full new skill kits are distinct content tasks: existing two-unit debug encounter teams are not automatically valid commander boss parties.

Complete the remaining race/commander implementation stage before habitat work: Orcs, Lizardmen, Harpies and Werewolves for the player coalition, and remaining Human, Elven and Dwarven race/commander content for enemy parties. Reuse already implemented content after verification. The stage covers approved class/skill catalogs, commander mechanics, identity/presentation, battle integration and save/reload; lore documents or placeholder commander records do not satisfy it. The minimum content statement above is not permission to bypass the remaining approved race/commander scope. Detailed race/commander designs and their implementation plans should be completed in that preceding stage.

## Deterministic generation contract

1. Validate the player clan/commander pair and normalize or generate the seed once. Display and persist the resolved seed.
2. Select the allied pair and main enemy clan with independent seed namespaces; UI preview calls must not consume selection state.
3. Create canonical board cells and resolve western enemy spawn from the actual rendered axial orientation. Test that it is visually west rather than assuming minimum q always identifies a unique western tip.
4. Reserve the enemy habitat as `hex_distance(cell, enemy_spawn) <= 2`, clipped to the board.
5. Construct connected allied habitats with sufficient legal capacity for three towns each and the selected player start.
6. Place three distinct towns in each allied habitat using seeded ordering and finite deterministic constraint search. Exclude party starting cells. Do not inherit v1's global seven-town/four-hex-spacing constraints without a feasibility check.
7. Validate V2 region connectivity, town counts/ownership, spawn exclusion, forest exclusions and the required empty road array; publish only a complete valid V2 plan.
8. In V3, add all three internal town endpoint pairs for each habitat.
9. In V3, for each distinct habitat pair A/B, compute `d_min = min(distance(a,b))` over their town pairs, then add every pair with distance `d_min`.
10. In V3, resolve one shortest traversable route per endpoint pair using a fixed neighbour order; deduplicate shared road segments. Routes cannot leave the board.
11. Validate the complete V3 habitat, town and road topology before publication.

Use explicit immutable generator versions and fixtures. V2 freezes AC9.4/AC9.5 habitat and town output with no roads; V3 freezes AC9.6/AC9.7 road output. Preserve existing V1 and V2 fixtures unchanged. Run identity includes normalized seed, generator version and selected player configuration; same inputs reproduce every feature owned by that version. Mutable siege/ruin state belongs in run saves, not in the generated plan.

## Ownership and file map

Existing integration points:

- `Scripts/Run/world_production_launcher.gd`, `Scenes/world_run_start.tscn`: clan then commander UI; remove overwrite modal and route Start directly to candidate creation.
- `Scripts/Run/world_run_start_service.gd`: selection order and atomic initial state, including AC8's 100g.
- `Scripts/Run/world_single_slot_repository.gd`: retain atomic replacement and old-save preservation on failure.
- `Scripts/WorldMap/world_plan.gd`: habitat membership, stable towns, routes and party start metadata.
- `Scripts/WorldMap/hex_world_generator_v1.gd`, `world_plan_codec_v1.gd`, `world_priority.gd`, `hex_world_geometry.gd`: inspect existing contracts; preserve v1 and add version-specific implementations.
- `Scripts/WorldMap/world_presentation_controller.gd`, `world_cell_view.gd`, `world_minimap.gd`: habitat/town presentation and road rendering from generated data.
- `Scripts/Save/world_run_save_codec_v5.gd` and existing versioned codecs: inspect current production codec routing and preserve explicit schema dispatch rather than reinterpreting old data.

Proposed topology files are split by version: `Scripts/WorldMap/hex_world_generator_v2.gd` and `world_plan_codec_v2.gd` own AC9.4/AC9.5; later `hex_world_generator_v3.gd`, `world_plan_codec_v3.gd`, and `habitat_road_rules.gd` own AC9.6/AC9.7. Focused tests likewise separate habitat/town fixtures from road fixtures. Earlier AC9.1-AC9.3 file proposals have been superseded by their approved detailed designs and implementations.

## Implementation sequence

- [ ] Prerequisite (AC9.0): Implement and verify the remaining races and their commanders, including their approved classes/skills, playable or enemy-party integration and durable identities. Record content verification before beginning habitat, habitat-town or inter-habitat-road implementation. AC8 uses existing Goblin towns throughout this stage.
- [ ] Task 1 (AC9.1, AC9.2, AC9.4, AC9.5): After the content prerequisite passes, add explicit clan/synergy data and selection fixtures before UI integration; enforce eastern player start and town-free western enemy territory as part of the habitat-enabled world version.
- [ ] Task 2 (AC9.1-AC9.3, AC9.8): Test seeded pair selection: three distinct allies total, guaranteed synergy, all eligible enemy clans reachable across a seed corpus, stable replay, invalid commander rejection and no selection on Continue.
- [ ] Task 3 (AC9.4, AC9.5, AC9.8): Implement generator V2 and versioned fixtures for habitats and nine allied towns with an explicitly empty road array. Include finite-search failures and independent expected geometry checks. Follow the approved AC9.4/AC9.5 design.
- [ ] Task 4 (AC9.6, AC9.7): Implement generator V3 and test internal all-pairs roads plus every tied closest cross-habitat town pair. Add cases with one minimum pair and multiple equal minima. Preserve V2 fixtures and saved topology unchanged.
- [ ] Task 5 (AC9.0, AC9.3): Integrate the already completed race/commander/recruit/boss catalogs into generated runs. Boss victory requires defeating the commander-led party, rather than merely reaching its origin hex. Missing prerequisite content blocks this stage; do not substitute a debug team.
- [ ] Task 6 (AC9.1, AC9.9): Connect clan/commander selection, resolved seed and Start without confirmation. Preserve current save until candidate generation and persistence both succeed; prevent duplicate Start submissions.
- [ ] Task 7 (AC9.8, AC9.10): Preserve generator-version dispatch in shared saves for AC8–AC10. Keep old worlds readable through their existing version; new rules apply only to newly generated runs. Never regenerate a saved V1 or V2 map through a later generator.
- [ ] Task 8 (AC9.10): After V3 roads exist, add the complete habitat/town/road player-facing presentation via authored Godot scene components and the existing world presentation. AC9.4/AC9.5 provide marker placement, town rendering and read-only debug diagnostics only; test full territory and road presentation under AC9.10.
- [ ] Task 9 (AC9.9): Update design-spec criteria and mark the overwrite-confirmation portion of the deferred AC5.1 documents superseded by AC9. AC9 does not reactivate unrelated deferred meta-progression work.

## Acceptance and verification

- Remaining races and commanders have implementation and combat/save verification evidence before habitat implementation begins. Existing two-enemy teams alone do not satisfy commander readiness.
- Before habitats are enabled, all existing towns use Goblin recruitment with AC8's roster-class filter; no topology change is required for this interim behavior.
- Same resolved seed, player setup and generator version reproduce every feature owned by that version after restart: V2 reproduces selections, habitats, towns and initial party identities with no roads; V3 additionally reproduces the final road graph.
- Player setup produces one main clan plus two distinct allies, with at least one main-clan synergy partner.
- Exactly three towns belong to each allied habitat. No town or allied region overlaps the reserved enemy territory.
- Enemy starts at the visible westernmost hex. Its habitat is exactly the on-map distance-2 footprint.
- Player starts at the visible easternmost hex inside the main clan's habitat. The enemy habitat has zero towns and is excluded from town-road endpoint pairing.
- V3 gives each habitat's three towns all three internal pair connections. Every habitat pair includes all equal-minimum cross-town endpoint connections, with shared segments represented once.
- All V2 town hexes and all later V3 roads are valid/reachable. Unsatisfiable generation returns a clear failure without partial world/save mutation.
- Existing save + Start goes straight to generation; no overwrite-confirmation screen. Failed generation/save retains the old save; successful start replaces it once.
- Continue restores saved clan identities and topology rather than drawing again.

Run the new SceneTree tests with `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/<test-path>.gd`, plus existing geometry, world-start, repository, save and production-scene regressions. Require exit code 0 and no parser/runtime errors. V2 visual verification inspects map direction, party markers, habitats and nine towns; V3 and AC9.10 verification add roads and complete topology presentation. No tests were run for this planning-only change.

## Dependencies

Delivery order: AC8 gold and recruitment on existing towns treated as Goblin habitat; remaining race and commander implementation/verification; AC9.4/AC9.5 V2 habitat and clan-owned town generation; AC9.6/AC9.7 V3 roads; AC9.10 presentation; then AC10 siege/pursuit integration. AC8 does not depend on generated habitats. The remaining races and commanders are a hard prerequisite for habitat work. AC10 depends on the V3 town graph, commander party and save schema. Preserve V1, V2 and later versions explicitly rather than silently remapping saved topology.
