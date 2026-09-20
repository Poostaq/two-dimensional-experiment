# AC9 — Seeded Clans, Habitats and Roads Plan

> For implementation: use `superpowers:executing-plans` after the proposed generation/content defaults below are reviewed. Follow repository AGENTS.md and GodotIQ. Work on a dedicated task branch in the primary workspace; no worktrees.

**Status:** Planning only; remaining choices are explicitly identified. No generator, save or scene changes have been made.

**Goal:** Build a seeded world for the chosen clan and commander, two randomly selected allied clans, and a Human, Elven or Dwarven main enemy clan.

**Architecture:** A clan catalog owns eligibility and explicit synergy relationships. Run setup freezes selected identities before a new version of the pure world generator creates habitats, towns and roads. WorldPlan owns immutable topology; run state owns changing party and town state. The existing launcher and repository commit the new run atomically.

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
- Within each allied habitat all three town pairs receive a road connection.
- For every pair of allied habitats, find the closest cross-habitat town pair and connect it. Include every pair tied for that minimum distance, as specified in the original request.
- Starting a new run never asks for save-overwrite confirmation. Generation/save failure must preserve the previous durable save.

## Explicit implementation proposals

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
7. Add all three internal town endpoint pairs for each habitat.
8. For each distinct habitat pair A/B, compute `d_min = min(distance(a,b))` over their town pairs, then add every pair with distance `d_min`.
9. Resolve one shortest traversable route per endpoint pair using a fixed neighbour order; deduplicate shared road segments. Routes cannot leave the board.
10. Validate region connectivity, town counts/ownership, routes, spawn exclusion and reachable towns; publish only a complete valid plan.

Use a new generator version and new immutable fixtures. Preserve existing v1 fixtures unchanged. Run identity includes normalized seed, generator version and selected player configuration; same inputs reproduce all initial selections and topology. Mutable siege/ruin state belongs in run saves, not in the generated plan.

## Ownership and file map

Existing integration points:

- `Scripts/Run/world_production_launcher.gd`, `Scenes/world_run_start.tscn`: clan then commander UI; remove overwrite modal and route Start directly to candidate creation.
- `Scripts/Run/world_run_start_service.gd`: selection order and atomic initial state, including AC8's 100g.
- `Scripts/Run/world_single_slot_repository.gd`: retain atomic replacement and old-save preservation on failure.
- `Scripts/WorldMap/world_plan.gd`: habitat membership, stable towns, routes and party start metadata.
- `Scripts/WorldMap/hex_world_generator_v1.gd`, `world_plan_codec_v1.gd`, `world_priority.gd`, `hex_world_geometry.gd`: inspect existing contracts; preserve v1 and add version-specific implementations.
- `Scripts/WorldMap/world_presentation_controller.gd`, `world_cell_view.gd`, `world_minimap.gd`: habitat/town presentation and road rendering from generated data.
- `Scripts/Save/world_run_save_codec_v5.gd` and existing versioned codecs: inspect current production codec routing and preserve explicit schema dispatch rather than reinterpreting old data.

Proposed new files: `Scripts/Run/clan_catalog.gd`, `Scripts/Run/run_clan_selection.gd`, `Scripts/WorldMap/hex_world_generator_v2.gd`, `Scripts/WorldMap/world_plan_codec_v2.gd`, `Scripts/WorldMap/habitat_road_rules.gd`; tests under `Tests/Run/test_ac9_clan_selection.gd`, `Tests/WorldMap/test_ac9_habitats_and_roads.gd`, and `Tests/Run/test_ac9_start_without_confirmation.gd`.

## Implementation sequence

- [ ] Prerequisite (AC9.0): Implement and verify the remaining races and their commanders, including their approved classes/skills, playable or enemy-party integration and durable identities. Record content verification before beginning habitat, habitat-town or inter-habitat-road implementation. AC8 uses existing Goblin towns throughout this stage.
- [ ] Task 1 (AC9.1, AC9.2, AC9.4, AC9.5): After the content prerequisite passes, add explicit clan/synergy data and selection fixtures before UI integration; enforce eastern player start and town-free western enemy territory as part of the habitat-enabled world version.
- [ ] Task 2 (AC9.1-AC9.3, AC9.8): Test seeded pair selection: three distinct allies total, guaranteed synergy, all eligible enemy clans reachable across a seed corpus, stable replay, invalid commander rejection and no selection on Continue.
- [ ] Task 3 (AC9.4, AC9.5, AC9.8): Add versioned generation fixtures for habitats and nine allied towns. Include finite-search failures and independent expected geometry checks.
- [ ] Task 4 (AC9.6, AC9.7): Implement/test internal all-pairs roads and every tied closest cross-habitat town pair. Add cases with one minimum pair and multiple equal minima.
- [ ] Task 5 (AC9.0, AC9.3): Integrate the already completed race/commander/recruit/boss catalogs into generated runs. Boss victory requires defeating the commander-led party, rather than merely reaching its origin hex. Missing prerequisite content blocks this stage; do not substitute a debug team.
- [ ] Task 6 (AC9.1, AC9.9): Connect clan/commander selection, resolved seed and Start without confirmation. Preserve current save until candidate generation and persistence both succeed; prevent duplicate Start submissions.
- [ ] Task 7 (AC9.8, AC9.10): Version shared saves for AC8–AC10. Proposed compatibility policy: keep old worlds readable through their existing version; new rules apply to newly generated runs. Do not regenerate a saved old map using v2. Confirm compatibility scope before implementation.
- [ ] Task 8 (AC9.4-AC9.7, AC9.10): Add habitat/town/road presentation via authored Godot scene components and existing world presentation. Test that displayed west, territory membership and road endpoints match the plan.
- [ ] Task 9 (AC9.9): Update design-spec criteria and mark the overwrite-confirmation portion of the deferred AC5.1 documents superseded by AC9. AC9 does not reactivate unrelated deferred meta-progression work.

## Acceptance and verification

- Remaining races and commanders have implementation and combat/save verification evidence before habitat implementation begins. Existing two-enemy teams alone do not satisfy commander readiness.
- Before habitats are enabled, all existing towns use Goblin recruitment with AC8's roster-class filter; no topology change is required for this interim behavior.
- Same resolved seed, player setup and generator version produce identical clan selections, habitats, towns, roads and initial party identities after restart.
- Player setup produces one main clan plus two distinct allies, with at least one main-clan synergy partner.
- Exactly three towns belong to each allied habitat. No town or allied region overlaps the reserved enemy territory.
- Enemy starts at the visible westernmost hex. Its habitat is exactly the on-map distance-2 footprint.
- Player starts at the visible easternmost hex inside the main clan's habitat. The enemy habitat has zero towns and is excluded from town-road endpoint pairing.
- Each habitat's three towns have all three pair connections. Every habitat pair includes all equal-minimum cross-town endpoint connections, with shared segments represented once.
- All roads and town hexes are valid/reachable. Unsatisfiable generation returns a clear failure without partial world/save mutation.
- Existing save + Start goes straight to generation; no overwrite-confirmation screen. Failed generation/save retains the old save; successful start replaces it once.
- Continue restores saved clan identities and topology rather than drawing again.

Run the new SceneTree tests with `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/<test-path>.gd`, plus existing geometry, world-start, repository, save and production-scene regressions. Require exit code 0 and no parser/runtime errors. GodotIQ visual verification must inspect map direction, each habitat, roads and launcher flow. No tests were run for this planning-only change.

## Dependencies

Delivery order: AC8 gold and recruitment on existing towns treated as Goblin habitat; remaining race and commander implementation/verification; AC9 habitat generation, clan-owned towns and roads; then AC10 siege/pursuit integration. AC8 does not depend on generated habitats. The remaining races and commanders are a hard prerequisite for habitat work. AC10 depends on the resulting town graph, commander party and save schema. Preserve interim world versions explicitly rather than silently remapping their towns when habitat generation is introduced.
