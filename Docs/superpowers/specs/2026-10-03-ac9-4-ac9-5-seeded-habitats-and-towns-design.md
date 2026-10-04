# AC9.4 and AC9.5 Seeded Habitats and Towns Design

**Acceptance criteria:** AC9.4 and AC9.5.

**Status:** Approved for implementation planning on 2026-10-03; spawn orientation and habitat display were corrected by the [AC9.6 correction](2026-10-04-ac9-6-spawn-and-habitat-display-correction-design.md), and allied-area balance plus town spacing were corrected by the [AC9 town spacing and balanced habitats design](2026-10-04-ac9-town-spacing-and-balanced-habitats-design.md).

## Goal

Create a new deterministic world topology in which the player begins on the visible western edge inside the selected main clan's habitat, the enemy begins on the visible eastern edge inside an exact clipped radius-two enemy habitat, and the remaining board is divided between the main clan and its two selected allies. Each allied habitat contains exactly three owned towns; the enemy habitat contains none.

## Scope

This delivery introduces generator version 2, four stable habitat identities, nine stable town identities, explicit generated ownership, V2 canonical plan serialization, V1/V2 save compatibility, runtime recruitment from generated allied towns, and read-only topology diagnostics in the existing world debug drawer.

It builds on the merged AC9.1 player selection, AC9.2 allied coalition, and AC9.3 enemy boss selection. It does not implement habitat coloring, final town art, internal habitat roads, cross-habitat roads, enemy campaign movement, sieges, pursuit, or mutable town destruction. AC9.6 and AC9.7 will introduce the next generator version with their final road contract; V2 plans contain no roads. AC9.10 owns full player-facing habitat and topology presentation.

## Planning authority

This document is the governing design for AC9.4 and AC9.5. It supersedes the older aggregate AC9 roadmap wherever that roadmap implied one generator version for habitats, towns, and roads. The aggregate roadmap continues to govern the remaining AC9 sequence and has been reconciled to reserve generator V3 for AC9.6 and AC9.7. The road acceptance criteria remain unchanged; only their delivery version is separated from roadless V2. The approved 2026-10-04 corrections are authoritative for orientation, habitat display, exact allied-area quotas, spawn clearance, and global town spacing. The user explicitly authorized replacing the V2/V3 fixture contracts and deleting existing local saves rather than introducing another generator version.

## Chosen approach

Add `HexWorldGeneratorV2` rather than changing V1 output. V2 receives the already validated run identities through the established generator configuration seam, constructs a complete habitat-and-town plan, validates it through a V2 codec, and returns it only after every invariant passes. `WorldRunStartService` overwrites reserved generation-context keys from the validated `RunClanSelection`, `RunClanCoalition`, and `RunEnemyBossSelection`; callers cannot forge different identities through the public configuration dictionary.

`WorldPlan` remains the shared immutable topology value. Add optional habitat and town collections at the end of its constructor so V1 construction and parsing remain byte-for-byte compatible. V1 plans expose empty generated collections and continue to use their explicit legacy Goblin rules. V2 plans expose generated ownership through defensive-copy accessors.

## World plan contract

V2 retains the radius-8 board and all 217 canonical axial coordinates. It uses these stable habitat IDs in this exact order:

1. `main`
2. `ally_0`
3. `ally_1`
4. `enemy`

The `main` habitat uses `RunClanSelection.main_clan_id`. `ally_0` and `ally_1` use `RunClanCoalition.allied_clan_ids` in their already validated canonical catalog order. `enemy` uses `RunEnemyBossSelection.enemy_clan_id`.

Each habitat record contains `habitat_id`, `role`, `clan_id`, and `anchor`. Cell membership is authoritative in each V2 cell's `habitat_id`; `WorldPlan.get_habitat_cells(habitat_id)` derives and returns a canonically sorted defensive copy so membership is not duplicated in two mutable representations.

Each V2 cell retains `encounter`, `terrain`, and `town_index`, and adds `habitat_id`. Each generated town record contains:

- `town_id`: `main_town_0` through `main_town_2`, `ally_0_town_0` through `ally_0_town_2`, or `ally_1_town_0` through `ally_1_town_2`;
- `habitat_id`;
- `local_index`, from 0 through 2; and
- `coord`.

Global `town_index` values are 0 through 8 in habitat order and then local-index order. `WorldPlan.get_habitats()` and `get_towns()` return deep defensive copies. V2 validation cross-checks every habitat, town record, cell habitat, and cell town index so a coordinate cannot acquire conflicting ownership.

## Visual east and west

The current world and minimap projections place an axial coordinate horizontally according to a positive scale of `q + r / 2`. Add a shared integer geometry key `2q + r` and select extrema from the complete canonical board by that key. Canonical coordinate ordering breaks any tie.

For the radius-8 board this produces:

- player spawn: `Vector2i(-8, 0)`, the unique westernmost coordinate;
- enemy spawn: `Vector2i(8, 0)`, the unique easternmost coordinate.

Tests independently compare the geometry key against the projection formulas used by the world view and minimap. Generator code does not assume that minimum or maximum `q` alone defines visible west or east.

## Enemy habitat

The enemy habitat contains exactly every canonical board coordinate whose hex distance from the enemy spawn is at most two. The board boundary clips the footprint naturally. On the radius-8 board the exact footprint contains these nine coordinates:

```text
(6, 0), (6, 1), (6, 2),
(7, -1), (7, 0), (7, 1),
(8, -2), (8, -1), (8, 0)
```

The enemy spawn is the `enemy` anchor. No enemy-habitat cell may contain a town. The boss encounter remains on the enemy spawn, and the existing run state initializes its mutable boss coordinate from that plan coordinate.

## Allied habitat partition

Remove the enemy footprint from the canonical board. The player spawn is the fixed `main` anchor. Rank every other allied coordinate with world-priority version 2 and namespace `habitat-anchor-v2`, then enumerate candidate pairs in ranked order for `ally_0` and `ally_1`.

For each pair, assign seeded quotas to the three anchors with world-priority namespace `habitat-quota-v2`. The 208 non-enemy cells are divided exactly as 69, 69, and 70; the first ranked anchor receives the 70-cell quota. Deterministic per-habitat frontier growth claims canonical neighbors only while that habitat remains below quota. Every claim extends an existing region, so each accepted allied habitat is connected to its anchor.

Accept only a partition that covers every non-enemy cell exactly once, reaches all three exact quotas, retains anchor ownership, and supports three spawn-cleared towns per allied habitat. If no candidate pair satisfies those constraints, generation fails atomically with `WORLD_CONSTRAINT_UNSATISFIABLE`, generator version 2, namespace `habitat`, and constraint `balanced_partition_with_town_capacity`.

## Seeded town placement

For each allied habitat in stable order, collect its member cells and exclude every coordinate less than hex distance two from either party start. Rank the remaining coordinates with world-priority version 2, namespace `habitat-town-v2`, and the habitat's stable index. A deterministic global search selects exactly three towns per habitat and first seeks a layout in which every pair among all nine towns is at least distance two.

Only when exhaustive search proves full separation impossible may the solver fall back to the layout with the fewest adjacent pairs, then the greatest total pairwise distance, with stable partition and candidate order resolving remaining ties. Assign local town indices in ranked selection order and global indices in habitat order. Mark every town cell safe. Towns are reproducible, distinct, inside their owning habitat, absent from the enemy habitat, clear of both starts, and independent of mutable RNG or call order.

## Encounters forests and roads

V2 encounter generation uses the existing FNV-1a world-priority mechanism with generator version 2. The player spawn and all nine towns are safe, and the enemy spawn is the boss encounter. Other cells retain the current seeded safe/combat distribution.

Retain ten deterministic forest clusters. Extend the existing forest solver with an optional generator-version argument whose default remains 1, then call it with version 2 from V2. This preserves V1 fixtures while giving V2 its own priority payloads and correct versioned failure records. Forests exclude both party spawns and every town.

V2 roads are an empty array, and V2 validation requires that array to remain empty. Navigation already uses hex adjacency rather than roads, so the world remains fully traversable. V1 saves keep their existing six-road minimum-spanning tree. AC9.6 and AC9.7 will create a later generator version rather than changing V2 results for an existing seed.

## Canonical serialization

Create `WorldPlanCodecV2` with a canonical line format headed by `TWDE-WORLD,2`. It serializes records in this order:

1. seed, player start, and enemy start;
2. four habitat records in stable habitat order;
3. all cells in canonical coordinate order, including `habitat_id`;
4. nine town records in global town-index order; and
5. forest records in cluster and coordinate order.

The parser rejects unknown fields, unknown habitat IDs, duplicate or missing records, noncanonical order, noncanonical integers, blank or malformed clan IDs, inconsistent town references, disconnected habitats, incorrect spawn orientation, an incorrect enemy footprint, towns outside their habitat, enemy towns, nonempty roads, or any topology that fails the complete V2 invariant set. Catalog membership and agreement with the persisted run selections are envelope-level invariants, avoiding a Run-catalog dependency inside the world-plan codec.

Add a version-dispatching `WorldPlanCodec` facade. `serialize`, `parse`, and `validate` route to V1 or V2 by the plan or canonical header and reject unsupported versions. V1 codec behavior and fixture bytes do not change. Runtime consumers use the facade instead of directly naming V1.

## New-run data flow

`WorldRunStartService` keeps its current selection and transaction ownership. After resolving and validating the player selection, coalition, and enemy boss selection, it duplicates the caller configuration and overwrites these reserved fields:

```text
main_clan_id
allied_clan_ids
enemy_clan_id
```

It then invokes the injected generator once. The default generator becomes `HexWorldGeneratorV2`. Existing test generators continue to use the `generate(seed_text, config)` interface and can inspect the reserved fields.

Generation failure returns before run-state construction or the commit callback. Successful generation initializes player and boss coordinates from the V2 plan, then follows the existing candidate assembly and atomic repository replacement flow.

## Save compatibility

Keep the outer run-save version at V8. Its existing world object already stores `generator_version`, canonical plan bytes, a checksum, and all AC9.1-AC9.3 identities; AC9.4 and AC9.5 add no new outer-envelope field.

Replace the envelope's single V1 plan codec dependency with the version-dispatching facade. Accept generator versions 1 and 2, require the envelope's generator version to equal the parsed plan version, and preserve the existing checksum and run-state validation. For a V8 save containing a V2 plan, encoding and decoding also require the `main`, `ally_0`, `ally_1`, and `enemy` habitat clan IDs to match the persisted `RunClanSelection`, ordered `RunClanCoalition`, and `RunEnemyBossSelection`. A structurally valid plan with mismatched durable identities is rejected atomically.

New runs write V8 saves containing V2 plans. Existing V8/V1 and V2-V7 legacy saves remain readable and retain their original plan topology and writer contract. Continue parses the saved canonical plan and never regenerates habitats or towns. Autosave re-encodes the same plan instance and generator version rather than upgrading it.

## Runtime ownership and recruitment

`WorldHabitatRules` dispatches by plan version:

- V1 keeps the current whole-board Goblin result, blank habitat ID, and `Legacy world v1 rule` source.
- V2 reads the cell's habitat ID, resolves the matching plan record, and returns its clan, role, stable ID, display name, anchor, cell count, and `Generated world v2` source.

`TownOwnershipRules` continues to require a valid town cell, then delegates to the habitat result. V2 codec validation guarantees that all towns are allied and enemy habitat contains none.

The runtime town-service boundary accepts V1 Goblin towns and V2 towns whose owning clan has a nonempty recruitable catalog. Remove the temporary `version == 1` and `owner == goblin` restrictions; retain explicit rejection for unsupported versions, invalid ownership, enemy ownership, and empty recruit catalogs. `TownRecruitmentRules` remains unchanged because it already accepts a clan ID and uses the shared character catalog.

## Presentation and debug diagnostics

No scene restructuring or habitat coloring is required in this delivery. The world presentation and minimap validate through the codec facade, render V2's 217 cells and nine towns, show no roads, and place their existing player and boss markers at the V2 coordinates. Full player-facing territory presentation remains AC9.10.

Extend the existing read-only world debug snapshot and presenter. The Habitat and Map sections display:

- current habitat ID, role, clan, anchor, source, and cell count;
- current town ID and owning habitat/clan when standing on a town;
- generated player and enemy start coordinates, distinct from mutable runtime positions;
- cell counts for `main`, `ally_0`, `ally_1`, and `enemy`;
- town counts for those same habitat IDs;
- the enemy footprint count; and
- the existing seed and generator version.

Expected V2 summaries include nine enemy cells and town distribution `main=3, ally_0=3, ally_1=3, enemy=0`. V1 retains its legacy habitat wording and renders generated-only values as unavailable. `WorldRuntimeController.get_debug_snapshot()` derives these values only from the committed plan and committed runtime state. Opening, refreshing, or formatting the drawer cannot mutate either.

## Failure behavior

Identity and structural-input failures use `WORLD_GENERATION_INTERNAL_ERROR`. Finite-search failures use `WORLD_CONSTRAINT_UNSATISFIABLE`. Every V2 error includes the resolved seed hex, generator version 2, a focused namespace, and one exact constraint. The primary constraints are:

- `identity_context_invalid`;
- `visual_extrema_invalid`;
- `balanced_partition_with_town_capacity`;
- `forest_cluster_count=10`; and
- codec-specific canonical or invariant constraints.

The generator returns no partial plan. Start-service failure occurs before the commit callback, V8 encoding returns no partial bytes, and repository replacement preserves the prior save byte-for-byte.

## Verification contract

### Geometry and topology

- Prove the integer horizontal key has the same ordering as both production projection formulas.
- Assert the exact eastern and western spawn coordinates.
- Assert the exact nine-cell enemy footprint independently of generator output.
- Assert complete, exclusive coverage of all 217 cells by four habitats.
- Assert every habitat is connected and both party spawns belong to their required habitat.
- Assert three unique towns in every allied habitat and zero enemy towns.
- Assert all town and spawn encounter overrides and forest exclusions.

### Determinism and serialization

- Lock one canonical V2 golden fixture, including habitats, towns, encounters, forests, and empty roads.
- Repeat identical inputs in clean and interleaved calls and compare canonical bytes and SHA-256 hashes.
- Exercise a fixed seed corpus across every playable main clan and confirm invariant preservation.
- Reject malformed, reordered, overlapping, disconnected, wrongly owned, or noncanonical V2 plans.
- Preserve the exact existing V1 fixture corpus and V1 canonical bytes.

### Integration persistence and diagnostics

- Prove start-service identity injection and one generator invocation after all three selections.
- Prove failed generation prevents run-state construction, commit, and save replacement.
- Round-trip V8/V2 saves, reject every plan-versus-selection identity mismatch, and prove Continue invokes no selector or generator.
- Retain V8/V1 and V2-V7 decode plus schema-appropriate autosave regressions.
- Recruit from generated towns belonging to each playable allied clan and reject non-town or unsupported ownership.
- Verify the debug snapshot and presenter expose V2 topology, retain V1 legacy text, handle unavailable data safely, and never mutate the plan.
- Run the production world and capture one visual verification showing the player marker on the west and enemy marker on the east, with nine towns and no roads.

## File responsibilities

- Modify `Scripts/WorldMap/hex_world_geometry.gd`: shared rendered-horizontal ordering and extrema helpers.
- Modify `Scripts/WorldMap/world_priority.gd` only if a dedicated pair-ranking helper is needed; retain all V1 payloads unchanged.
- Modify `Scripts/WorldMap/world_plan.gd`: optional immutable habitat/town collections and defensive accessors.
- Create `Scripts/WorldMap/world_habitat_solver_v2.gd`: seeded anchor search, deterministic partitioning, capacity checks, and town selection.
- Create `Scripts/WorldMap/hex_world_generator_v2.gd`: V2 generation orchestration and complete-plan publication.
- Modify `Scripts/WorldMap/world_constraint_solver_v1.gd`: optional version parameter for forest solving with a default of 1.
- Create `Scripts/WorldMap/world_plan_codec_v2.gd`: canonical V2 encoding, parsing, and validation.
- Create `Scripts/WorldMap/world_plan_codec.gd`: V1/V2 dispatch facade.
- Modify `Scripts/Run/world_run_start_service.gd`: inject validated identities and use V2 by default.
- Modify `Scripts/Save/world_run_save_envelope.gd`: generator-version dispatch while retaining V8 shape.
- Modify `Scripts/WorldMap/world_runtime_model.gd`, `world_presentation_controller.gd`, and `world_minimap.gd`: validate V1/V2 plans through the facade.
- Modify `Scripts/WorldMap/world_habitat_rules.gd` and `town_ownership_rules.gd`: generated V2 habitat and town ownership with V1 compatibility.
- Modify `Scripts/WorldMap/world_runtime_controller.gd`: V2 recruitment availability and committed topology diagnostics.
- Modify `Scripts/UI/world_debug_presenter.gd`: format generated habitat, town, spawn, and topology summaries.
- Create `Tests/WorldMap/test_ac9_habitats_and_towns.gd`: geometry, partition, town, determinism, failure, and corpus coverage.
- Create `Tests/WorldMap/test_world_plan_codec_v2.gd`: canonical fixture, round-trip, malformed input, and V1 preservation.
- Add `Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world`: canonical V2 fixture.
- Extend start-service, V8 save, runtime-model, presentation, minimap, recruitment, and debug-presenter tests at their existing paths.

## Risks and controls

The main determinism risk is allowing queue order, dictionary iteration, or mutable RNG state to decide borders. Stable habitat order, canonical coordinates, fixed neighbor order, versioned hash namespaces, and golden bytes make each decision explicit.

The main compatibility risk is teaching V8 to read V2 plans while preserving V1. A dedicated plan-codec facade, exact generator-version equality, unchanged V1 code paths, and the complete legacy fixture corpus prevent reinterpretation.

The main ownership risk is duplicating clan rules across generation, runtime, recruitment, and diagnostics. The run selections remain the authority for chosen identities, the generated plan owns spatial assignment, habitat rules resolve cell ownership, and recruitment consumes only that resolved clan ID.

The main scope risk is partially implementing roads. V2 explicitly requires no roads, and AC9.6/AC9.7 must use a later generator version. This prevents later road work from silently changing existing V2 runs.
