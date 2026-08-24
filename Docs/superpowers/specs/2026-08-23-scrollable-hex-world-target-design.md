# Scrollable Hex World — Future Target Design

**Status:** Approved design target

**Date:** 2026-08-23

**Scope:** Future world-map direction; not yet implemented

**Current MVP authority:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`

## Purpose and authority

This document records the approved end-goal constraints for a larger world map. It does not claim that the feature exists, and it does not silently replace the current deterministic 5×5, 25-hex MVP map. The MVP remains authoritative until a separately approved implementation plan explicitly migrates the project to this design.

The target is a locally readable, scrollable hex world that supports route planning across a much larger deterministic run map without showing the full world in the main viewport. A minimap preserves global orientation.

## World geometry

- Use a true radius-8 hexagonal axial board.
- The board contains exactly `1 + 3 × 8 × 9 = 217` playable hexes.
- Valid axial coordinates satisfy `max(abs(q), abs(r), abs(-q - r)) <= 8`.
- The world boundary must visibly read as many individually separated hex cells forming one hexagonal board.
- The authoritative player start coordinate is `Vector2i(-8, 0)`.
- The authoritative boss start coordinate is `Vector2i(8, 0)`.
- These coordinates are opposite radius-8 corners with a shortest-path distance of 16 moves. They are fixed for every seed; generation does not choose or rotate the corner pair.
- If the boss has not been engaged, accepted player move 30 activates Sudden Death without moving the boss.
- Beginning with accepted player move 31, the boss takes exactly one adjacent shortest-path pursuit step after each accepted player move until either side reaches the other and the Boss encounter opens.
- Equal-length pursuit choices use `HexMapModel.NEIGHBOR_OFFSETS` order as the fixed tie-breaker, preserving the existing AC1.5 contract.
- Player engagement on or before move 30 takes precedence over activation. Rejected, off-map, non-adjacent, and overlay-blocked requests do not advance the counter, activate Sudden Death, or move the boss.
- The moving boss coordinate is the only runtime Boss encounter. Its vacated start coordinate resolves as Safe, matching AC1.5.
- Movement remains one valid adjacent hex per accepted move.

## Deterministic generation

- Every generated world is derived from the run seed.
- Replaying the same seed and generator version must reproduce identical:
  - encounter classifications;
  - town coordinates;
  - town-road connections;
  - forest-cluster cells;
  - player and boss start cells.
- Generation must not depend on wall-clock time, frame order, collection iteration order, camera traversal, or mutable global random state.
- Generation must use a dedicated seeded `RandomNumberGenerator` or equivalent owned by the world generator.
- Generator behavior is versioned through an explicit `world_generator_version`. Seed identity is the pair `(run_seed, world_generator_version)`.
- The canonical coordinate list is sorted by ascending `q`, then ascending `r`.
- Every randomized priority is derived independently from a stable hash of `world_generator_version`, `run_seed`, feature namespace, feature index when applicable, `q`, and `r`. Sorting uses the hash ascending, then canonical coordinate order as the collision tie-breaker.
- Generation must not use unbounded retries or consume one shared RNG stream whose result depends on iteration order.
- Save/reload and visiting regions in a different order must not alter the generated plan.

### Constraint solving and failure behavior

- Town and forest placement use deterministic include-first backtracking over their stable candidate order.
- Search prunes a branch only when its remaining candidates cannot satisfy the remaining count or a candidate violates a hard placement constraint.
- The first complete solution in stable search order is authoritative.
- Generation is atomic. No partial map is exposed to `MapController`, rendering, encounters, or saves.
- If exhaustive search finds no valid complete solution, generation returns a typed `WORLD_CONSTRAINT_UNSATISFIABLE` failure containing the seed, generator version, feature namespace, and failed constraint. The run does not start with fewer towns, fewer clusters, relaxed spacing, or substituted coordinates.
- Radius 8, seven towns, four-hex town spacing, and ten disjoint 3–7-cell forest clusters are treated as a validated configuration. A focused configuration-feasibility test must prove at least one solution independent of run seed; seeded ordering selects among valid solutions rather than determining whether a solution exists.

### Canonical generation contract

`world_generator_version` begins at integer `1`. Any change to hashing, canonical serialization, coordinate validity, feature order, solver policy, or generated output semantics increments this version.

The generator uses the existing project FNV-1a 32-bit constants:

- offset basis: `2166136261`;
- prime: `16777619`;
- modulus: `4294967296` (`2^32`).

Hash inputs use this exact ASCII payload:

```text
twde-wg|v=<version>|seed=<seed_hex>|ns=<namespace>|i=<index>|q=<q>|r=<r>
```

- `seed_hex` is the normalized run-seed UTF-8 byte sequence encoded as lowercase hexadecimal with two digits per byte. An empty run seed normalizes to `default-run` before encoding.
- `namespace` is a lowercase ASCII identifier containing only `a-z`, `0-9`, `_`, or `-`.
- `index`, `q`, and `r` are signed base-10 ASCII integers with no leading zeroes or leading `+`; zero is `0`.
- A non-indexed feature uses `i=-1`.
- No whitespace, Unicode normalization, locale formatting, or trailing newline appears in the hash payload.
- Starting with the offset basis, process each ASCII byte `b` from left to right as `hash = ((hash XOR b) × 16777619) mod 2^32`.
- Priority comparison uses the unsigned 32-bit hash ascending, then `q` ascending, then `r` ascending.

Generation executes in this fixed order:

1. enumerate and canonically sort the 217 valid cells;
2. assign fixed player and boss start coordinates;
3. solve seven towns;
4. construct the deterministic town minimum spanning tree;
5. solve ten forest clusters in cluster-index order;
6. assign encounter classifications, forcing player start and towns Safe and the current boss coordinate Boss;
7. validate the complete plan;
8. serialize and publish the plan atomically.

The canonical world-plan artifact is UTF-8 without BOM, uses LF line endings, and ends with one LF. Records use comma separators with no spaces. Sections and records appear in this exact order:

```text
TWDE-WORLD,1
seed,<seed_hex>
start,-8,0
boss,8,0
cell,<q>,<r>,<encounter>,<terrain>,<town_index_or_-1>
road,<a_q>,<a_r>,<b_q>,<b_r>
forest,<cluster_index>,<q>,<r>
```

- `cell` records use canonical coordinate order.
- Encounter tokens are exactly `safe`, `combat`, or `boss`; terrain tokens are exactly `plain` or `forest`.
- Town indices are assigned by canonical town-coordinate order, independent of solver discovery order.
- Each road endpoint pair is internally ordered by canonical coordinate order; road records are then sorted by first endpoint and second endpoint.
- Forest records are sorted by cluster index, then canonical coordinate order.
- The serialized artifact is the authoritative comparison and save/reload reconstruction input. Round-tripping it must reproduce byte-identical output.

### Canonical validation package

Before production generator code is accepted, the migration test commit must add this immutable fixture package:

```text
Tests/Fixtures/WorldMap/GeneratorV1/
  fnv_vectors.json
  corpus_manifest.json
  empty-seed.world
  golden-alpha.world
  golden-beta.world
  town-road-01.world
  unicode-lodz.world
  unsatisfiable-town-config.json
```

`fnv_vectors.json` contains at least these independently reproduced vectors:

| Canonical payload | Unsigned decimal | Hexadecimal |
|---|---:|---:|
| `twde-wg\|v=1\|seed=64656661756c742d72756e\|ns=town\|i=-1\|q=-8\|r=0` | `1594024070` | `0x5f02e086` |
| `twde-wg\|v=1\|seed=676f6c64656e2d616c706861\|ns=town\|i=-1\|q=0\|r=0` | `3643676249` | `0xd92e1659` |
| `twde-wg\|v=1\|seed=756e69636f64652dc582c3b364c5ba\|ns=forest-size\|i=3\|q=0\|r=0` | `2873815939` | `0xab4af383` |

The five generator corpus seeds and mandatory summary assertions are:

| Fixture | Input seed | Normalized seed hex | Expected towns in canonical order | Expected forest sizes by cluster index |
|---|---|---|---|---|
| `empty-seed.world` | empty string | `64656661756c742d72756e` | `(-6,0) (-6,4) (-6,8) (-1,-4) (3,-5) (3,-1) (3,4)` | `3,5,7,6,5,5,5,6,7,3` |
| `golden-alpha.world` | `golden-alpha` | `676f6c64656e2d616c706861` | `(-4,0) (-4,4) (1,2) (1,6) (2,-3) (3,-8) (8,-2)` | `5,6,3,7,4,6,5,7,4,5` |
| `golden-beta.world` | `golden-beta` | `676f6c64656e2d62657461` | `(-5,-1) (1,-8) (1,-2) (1,3) (1,7) (7,-8) (7,-4)` | `3,4,4,5,6,7,5,4,4,5` |
| `town-road-01.world` | `town-road-01` | `746f776e2d726f61642d3031` | `(-6,3) (-6,7) (-3,-2) (-3,8) (0,2) (6,-5) (6,-1)` | `7,6,5,5,5,4,7,6,7,6` |
| `unicode-lodz.world` | `unicode-łódź` | `756e69636f64652dc582c3b364c5ba` | `(-8,3) (-8,7) (-5,-1) (0,-8) (1,2) (1,6) (6,1)` | `6,6,4,7,4,5,6,5,4,6` |

Every `.world` fixture contains the complete canonical artifact, not only the summary values. `corpus_manifest.json` records for each fixture its seed text, seed hex, byte length, SHA-256, 217 cell count, seven town count, six road-edge count, ten cluster count, cluster sizes, and canonical artifact filename. SHA-256 validates fixture integrity; FNV-1a remains the generation-priority hash.

The first five lines of `empty-seed.world` are fixed:

```text
TWDE-WORLD,1
seed,64656661756c742d72756e
start,-8,0
boss,8,0
cell,-8,0,safe,plain,-1
```

`unsatisfiable-town-config.json` injects radius `2`, town count `7`, minimum town distance `4`, player `(-2,0)`, and boss `(2,0)`. The expected result is `WORLD_CONSTRAINT_UNSATISFIABLE` in namespace `town`, zero published cells, and no save mutation.

Golden artifacts are reviewed and committed before production generator implementation. Production tests consume them read-only and may not regenerate or approve changed goldens automatically. Any intentional golden change requires a generator-version increment, a reviewed fixture-diff artifact, and project-lead approval.

### Generation failure presentation

- `MapController` owns the run-creation transaction because it already owns run ID, world-map state, overlays, and reset coordination.
- A pure future `HexWorldGenerator` returns either a complete immutable world plan or a typed failure; it never creates UI or mutates `MapController`.
- `Scenes/game_world.tscn` owns one input-blocking `WorldGenerationFailureOverlay` under its existing UI layer. The overlay is instantiated or shown only from the `MapController` failure branch.
- Generation completes before map tiles are populated, pointer input is enabled, or a new run is committed to save state.
- `WORLD_CONSTRAINT_UNSATISFIABLE` aborts run creation while remaining in `game_world.tscn`; the failed world never becomes interactive.
- The player sees one blocking message: `World generation failed. The run was not started.`
- The failure surface provides `Return` and `Copy Diagnostics`. `Return` exits to the pre-run surface owned by the migration flow without loading or committing a run. It does not silently retry, relax constraints, choose a different seed, or continue with partial state.
- Copied diagnostics and the structured error log contain the error code, run-seed hex, generator version, feature namespace, failed constraint, and build version. Release presentation may hide raw fields, but the copy action and log retain them.
- `MapController` emits one structured `world_generation_failed` record through the project's error/logging boundary before showing the overlay. The payload schema matches copied diagnostics and excludes stack traces from release presentation.
- The failed run creates no world save, run-history entry, reward state, or partial roster mutation.

### Headless and CI failure contract

- `HexWorldGenerator.generate()` returns a typed result containing either one complete immutable world plan or one `WorldGenerationError`. Expected constraint failures are values, not thrown exceptions.
- Headless execution never instantiates `WorldGenerationFailureOverlay`, accesses display APIs, or waits for user input.
- Automated unit and integration runners use failure policy `RETURN_RESULT`. They assert the typed error and continue the test process; the generator and `MapController` do not call `SceneTree.quit()` in this policy.
- A production-style headless run-start entry uses failure policy `EXIT_PROCESS`. On generation failure it writes exactly one canonical JSON object to standard error and requests `SceneTree.quit(70)`. Exit status `70` is the authoritative generation-failure signal.
- The canonical JSON object uses UTF-8, one physical line, LF termination, JSON escaping, and this key order: `event`, `code`, `seed_hex`, `generator_version`, `namespace`, `constraint`, `build_version`.
- The `event` value is `world_generation_failed`; the remaining values match `WorldGenerationError` and the interactive diagnostic payload.
- Standard output remains available for the runner's normal machine-readable result and must not contain the failure object.
- Before returning or exiting, the headless path verifies that no map cells were published and no save, run-history, reward, roster, encounter, battle, or partial world state was created.
- Unexpected internal exceptions are caught at the headless run-start boundary, converted to `WORLD_GENERATION_INTERNAL_ERROR`, logged using the same schema, and exit with status `70`; debug builds may emit a stack trace only after the canonical one-line record.

Example constraint-failure line:

```json
{"event":"world_generation_failed","code":"WORLD_CONSTRAINT_UNSATISFIABLE","seed_hex":"64656661756c742d72756e","generator_version":1,"namespace":"town","constraint":"town_count=7,min_distance=4,radius=2","build_version":"dev-test"}
```

Headless verification owns three binary outcomes: `RETURN_RESULT` receives the exact typed error without quitting; `EXIT_PROCESS` produces the exact stderr schema and exit status `70`; both paths prove zero partial mutation.

### Save and generator-version compatibility

The future run-save payload owns a `world` object with these required fields:

```text
world.generator_version
world.run_seed_utf8_hex
world.canonical_plan_utf8
world.canonical_plan_sha256
world.runtime_player_coord
world.runtime_boss_coord
world.move_count
world.sudden_death_active
```

- Save files store the complete canonical plan as UTF-8 text in addition to seed and generator version. Runtime state never requires regenerating terrain or landmarks with the newest generator.
- Saving validates the plan, serializes it canonically, computes SHA-256, and writes the save atomically through the future run-save owner. `MapController` supplies world and runtime state but does not perform filesystem I/O.
- Loading verifies UTF-8 validity, SHA-256, grammar, generator version, 217-cell geometry, fixed starts, feature constraints, and runtime coordinates before publishing state.
- For generator version `1`, loading then serializing without mutation must reproduce byte-identical `canonical_plan_utf8`.
- A save with a supported older generator version loads its stored complete plan through that version's read-only parser; it is not regenerated or silently upgraded with newer generation rules.
- A save whose generator version has no supported parser fails atomically with `WORLD_VERSION_UNSUPPORTED`, remains unmodified, and returns to the save-selection or pre-run surface with copyable diagnostics.
- A pre-cutover 25-cell save has no 217-cell canonical plan. Before the production cutover commit, it remains owned exclusively by the frozen 25-cell production path; it cannot be converted in place to radius 8.
- The migration authority defines a zero-duration post-cutover compatibility window: legacy loading ends at the exact production cutover commit `C`. In `C` and every descendant, selecting a recognized 25-cell save returns `LEGACY_WORLD_SAVE_UNSUPPORTED` without modifying or deleting the file.
- No load failure may replace, truncate, migrate, or delete the source save automatically.

### Canonical world failure taxonomy

The following codes are disjoint and no adapter may substitute one for another:

| Code | Exact trigger | Required boundary behavior |
|---|---|---|
| `WORLD_CONSTRAINT_UNSATISFIABLE` | A supported Generator configuration completes deterministic exhaustive search without a valid full plan | Return generation failure atomically; publish no plan |
| `WORLD_GENERATION_INTERNAL_ERROR` | An unexpected exception or invariant failure occurs inside generation or its run-start boundary | Convert at the boundary; preserve diagnostic cause outside release UI; publish no plan |
| `WORLD_VERSION_UNSUPPORTED` | A structurally recognized canonical-world save declares a generator version for which the build has no read-only parser | Reject load atomically; do not regenerate, upgrade, or mutate the save |
| `LEGACY_WORLD_SAVE_UNSUPPORTED` | A structurally recognized pre-cutover 25-cell save lacks the canonical world-plan contract | Reject load atomically; do not reinterpret it as a Generator-version failure |

Dispatch order is structural envelope recognition, legacy-format recognition, generator-version dispatch, stored-plan validation, and only then run restoration. A recognized legacy envelope always maps to `LEGACY_WORLD_SAVE_UNSUPPORTED`; a recognized canonical-world envelope with an unavailable parser always maps to `WORLD_VERSION_UNSUPPORTED`. Neither load failure converts to a generation failure because generation is not invoked. Constraint failures convert to `WORLD_GENERATION_INTERNAL_ERROR` only when an unexpected implementation fault prevents the declared deterministic result; a valid unsatisfiable result retains `WORLD_CONSTRAINT_UNSATISFIABLE`. Malformed or unrecognized general save envelopes remain owned by the future run-save specification and may not be mislabeled as any of these four world failures.

## Encounter and terrain layers

- Safe, Combat, and Boss remain the encounter classifications.
- Terrain presentation is a separate layer from encounter classification.
- A forest hex retains its underlying encounter type.
- A road does not replace or alter a hex's encounter type.
- Player position, boss position, valid destinations, towns, and encounter states must remain readable above terrain decoration.

### Visual layer precedence

Render each cell in this fixed back-to-front order:

1. cell outline and encounter-color base;
2. terrain fill and forest decoration;
3. road corridor;
4. town buildings;
5. hover and valid-destination treatment;
6. player or boss party marker;
7. tooltip and contextual UI.

- Forest generation excludes towns, player start, and boss start, so those cells never combine forest art with their landmark or party origin.
- A road may cross a forest cell. The road owns a centered clear corridor at least 20% of the hex's flat-to-flat width; forest sprites are clipped or omitted inside that corridor while the forest terrain tint may remain.
- At every zoom fixture, road corridor width is `ceil(0.20 × F)` pixels, where `F` is the rendered flat-to-flat cell width, with a minimum of 4 pixels. The forest exclusion mask extends 2 rendered pixels beyond each corridor edge.
- Town buildings reserve the centered rectangle `[-0.30F, +0.30F] × [-0.25H, +0.25H]`, where `H` is rendered point-to-point cell height, and fully replace optional terrain sprites in that footprint.
- Hover and valid-destination treatments use the outer cell border and may not recolor or cover roads, buildings, or party markers.
- Player and boss markers use a centered readability plate with diameter `ceil(0.44 × min(F,H))`, a minimum 2-pixel contrasting outline, and a maximum marker silhouette diameter of `0.38 × min(F,H)`.
- Visual regression fixtures render road-through-forest, town-on-Safe, highlighted road, player-on-road, and boss-adjacent-to-forest cases at 3-, 5-, and 11-hex-across zoom. Each fixture owns a region-of-interest mask; deterministic rendering passes with zero changed pixels inside protected corridor, building-footprint, and marker-plate masks and at most 0.5% changed pixels outside those masks after approved baseline updates.

## Town generation

- Generate exactly seven towns per run.
- Each town occupies exactly one hex.
- Every town hex is a Safe encounter.
- Town coordinates are selected through seeded deterministic randomness.
- Towns must not occupy the player start, boss start, or their immediately adjacent cells.
- Towns must be at least four hex-distance apart to prevent accidental clustering.
- Town candidates are the canonical valid-coordinate list after removing the two start cells and their valid neighbors.
- The town solver selects the first complete seven-coordinate solution under the stable seeded candidate priority and four-distance constraint.
- A town is represented visually by a compact group of buildings contained within its hex.
- Towns do not currently imply shops, healing, recruitment, quests, or a new encounter type.

## Road generation

- Roads are visual navigation landmarks only.
- Roads do not restrict adjacency, reduce move cost, avoid turn cost, or guarantee an optimal route.
- Roads connect towns to towns; they do not need to connect the player start or boss.
- All seven towns must belong to one connected road network.
- Build the network deterministically as a minimum spanning tree over town coordinates using hex distance as edge weight.
- Resolve equal-weight edge choices through stable coordinate ordering.
- Road rendering may curve within and between cells, but it must preserve the generated town-to-town topology.

## Forest generation

- Generate exactly ten forest clusters per run.
- Each cluster contains 3–7 edge-connected hexes.
- Each cluster's target size is `3 + (stable_cluster_size_hash % 5)`.
- Forest candidates exclude player start, boss start, all towns, and all previously selected forest cells.
- For each cluster index `0..9`, connected candidate sets of the target size are enumerated through include-first backtracking. Frontier cells are ordered by their feature-specific stable hash and canonical coordinate tie-breaker.
- The outer solver backtracks across cluster choices when a locally valid cluster would prevent completion of later clusters.
- A cluster must be contiguous under the six axial neighbor directions.
- The ten clusters are cell-disjoint. Adjacency between separate clusters is permitted visually, but cluster identity remains the deterministic generation record used for verification.
- Forests are visual terrain only and do not change movement cost, accessibility, encounter weighting, or combat rules.
- Forest art must not obscure town buildings, roads, encounter classification, party markers, or valid-neighbor highlighting.

## Main viewport and controls

- The world map is larger than the viewport and scrollable.
- At default zoom, approximately five hexes fit across the usable map viewport.
- Mouse-wheel zoom ranges from approximately three hexes across at maximum zoom-in to eleven hexes across at maximum zoom-out.
- Support click-drag panning.
- Do not support edge scrolling.
- Camera movement and zoom do not consume world turns.
- Camera bounds must prevent losing the complete world beyond the navigable viewport.
- The current player position should be centered when the map first opens unless restoring a saved camera state.

## Player and boss markers

- Reuse the repository-root `icon.svg` silhouette for both parties.
- Tint the player-party marker green.
- Tint the boss-party marker red.
- Preserve enough contrast that marker identity does not depend on color alone; tooltip text, labels, outline treatment, or another non-color cue must distinguish them.
- Markers must remain readable over Safe, Combat, forest, town, road, and valid-destination presentations.

## Accepted-move and pursuit transaction

An accepted map move is one atomic transaction in this exact order:

1. validate that no encounter, battle, party-management, or generation-failure surface blocks input and that the destination is a valid adjacent cell;
2. move the player to the destination and increment `move_count` exactly once;
3. if the player entered the current boss coordinate, open one Boss encounter and end the transaction without activating or moving the boss;
4. otherwise, if `move_count == 30`, activate Sudden Death without moving the boss;
5. otherwise, if Sudden Death is active and `move_count > 30`, move the boss exactly one deterministic shortest-path step toward the player's new coordinate;
6. if the boss reached the player, open one Boss encounter and end the transaction;
7. otherwise, open the entered destination's Safe or Combat encounter overlay;
8. refresh map, minimap, countdown, and valid-neighbor presentation from authoritative state.

The accepted count continues increasing while Sudden Death is active. The player retains normal adjacent movement between move 31 and engagement; every accepted move is followed by exactly one pursuit step. Once a Boss encounter opens, map input and pursuit stop. Closing or resolving an ordinary encounter enables the next player move but never creates an extra boss step. Rejected input and UI-only camera movement never increment the count or move the boss.

## Minimap

- Keep the minimap persistently visible on the world-map screen.
- Render the complete 217-cell hexagonal board as 217 individually distinguishable miniature hexes, not as one solid hex polygon.
- Show all seven towns.
- Show the green player `icon.svg` marker.
- Show the red boss `icon.svg` marker.
- Show the current main-camera footprint as a subtle viewport outline.
- Roads may be shown at reduced contrast when they remain legible; forest clusters and encounter colors may be simplified to avoid noise.
- Updating the camera or party positions must update the minimap without changing generated world state.

## HUD layout

- The top HUD shows:
  - current accepted move count;
  - the 30-move boss-activation threshold;
  - exact moves remaining before activation;
  - current dormant or active boss state.
- The bottom-left HUD shows a compact six-slot party formation:
  - three Back Line slots;
  - three Front Line slots;
  - occupied and empty state;
  - direct access to `Manage Party`.
- The remaining bottom bar shows contextual navigation information, including:
  - instruction to choose a highlighted adjacent hex;
  - currently inspected destination's encounter type;
  - visual terrain such as forest, town, or road when applicable;
  - valid-destination feedback.
- Do not expand the compact formation into the full party-management layout on the map screen.

## Visual readability constraints

- Every main-map cell needs a persistent outline or gutter at every supported zoom level.
- The world and minimap must visibly read as tessellations of many cells, even though the overall board boundary is hexagonal.
- Valid adjacent destinations need stronger emphasis than ordinary encounter or terrain colors.
- Roads sit above terrain but below towns, party markers, and interaction highlights.
- Town buildings sit above the underlying Safe-hex treatment.
- Player and boss markers sit above every cell-level layer.
- The minimap camera outline must remain visible without hiding town or party markers.

## Performance and resource budgets

The Windows desktop reference baseline is:

- Windows 11 64-bit;
- Intel Core i3-12100F, four cores/eight threads;
- AMD Radeon RX 6500 XT with 4 GB VRAM;
- 16 GB dual-channel DDR4;
- SSD storage;
- 1920×1080 display, 60 Hz, native resolution;
- release/export build with VSync disabled for profiler capture and enabled for the player-facing manual check.

Equivalent hardware may be used only when its CPU single-thread performance, GPU class, VRAM, and RAM are no stronger than this baseline. Evidence records the exact CPU, GPU, driver, RAM, OS build, Godot version, renderer, export mode, resolution, and VSync state. On that reference system:

- target 60 frames per second during continuous drag pan and wheel zoom;
- p95 frame time must not exceed 16.67 ms during a 60-second map interaction capture;
- p99 frame time must not exceed 33.33 ms;
- world-map CPU work, excluding engine presentation and GPU wait, must remain at or below 4 ms p95 while panning;
- minimap camera-footprint updates must remain at or below 1 ms p95;
- initial generation must complete within 500 ms p95 and 2 seconds maximum across the approved deterministic seed corpus;
- incremental memory attributable to the generated world plan, 217 main cells, 217 minimap cells, roads, towns, forests, markers, and HUD must remain below 64 MiB;
- steady-state idle map presentation performs no per-frame world regeneration and no unbounded allocation growth;
- the renderer may keep all 217 logical cells resident, but it must not create duplicate logical world plans for the main map and minimap;
- any failure to meet a budget blocks migration completion or requires an approved budget amendment with captured profiler evidence.

## Explicit exclusions

This design does not add:

- edge scrolling;
- keyboard camera panning requirements;
- town shops, healing, quests, recruitment, or services;
- road movement bonuses or restrictions;
- forest movement or encounter modifiers;
- fog of war;
- region streaming requirements;
- save-format changes;
- mobile gesture behavior;
- a replacement for the existing full-screen party-management interface.

## Acceptance criteria for a future implementation

- **WM-T01 — Geometry:** The generated board contains exactly 217 unique valid radius-8 axial cells.
- **WM-T02 — Canonical generation:** Identical seed and generator version reproduce byte-equivalent canonical world-plan output across clean runs, save/reload, and alternate camera traversal orders.
- **WM-T03 — Landmarks:** The map generates exactly seven mutually spaced Safe towns and ten contiguous forest clusters of 3–7 cells.
- **WM-T04 — Roads:** Every town is reachable and belongs to one deterministic town-to-town road network.
- **WM-T05 — Party origins:** The player starts at `(-8, 0)`, the boss starts at `(8, 0)`, and they use green/red tinted root `icon.svg` markers.
- **WM-T06 — Camera framing:** Default camera framing shows approximately five hexes across; wheel zoom remains within the approximately 3–11 range.
- **WM-T07 — Camera input:** Click-drag pan and wheel zoom work without consuming turns; edge scrolling is absent.
- **WM-T08 — Cell readability:** Main-map and minimap cells remain individually distinguishable.
- **WM-T09 — Minimap content:** The minimap shows all 217 cells, seven towns, player, boss, and camera footprint.
- **WM-T10 — HUD and Party access:** The top boss countdown, compact bottom-left Front/Back formation, contextual bottom bar, and `Manage Party` access remain readable at the desktop target resolution.
- **WM-T11 — Sudden Death:** Move 30 activates Sudden Death without pursuit; move 31 and each later accepted unengaged move produce exactly one deterministic shortest-path boss step until one Boss encounter opens.
- **WM-T12 — Atomic failure:** Impossible generation input returns `WORLD_CONSTRAINT_UNSATISFIABLE` atomically with no partial world state.
- **WM-T13 — Failure presentation:** A generation failure aborts run creation, creates no save or partial mutation, shows the blocking failure surface, and records copyable structured diagnostics.
- **WM-T14 — Layer precedence:** Roads, forests, towns, highlights, and party markers obey the fixed layer order and clear-space rules at every supported zoom.
- **WM-T15 — Performance:** Generation, frame-time, minimap-update, memory, and idle-allocation measurements remain within the stated budgets on the named minimum supported desktop.
- **WM-T16 — Migration gate:** Production cutover occurs only when frozen legacy, migrated, new, GodotIQ, runtime, performance, and manual/visual gates pass against the required implementation commits and evidence package.
- **WM-T17 — Save compatibility:** Generator V1 saves round-trip the complete canonical plan byte-for-byte; supported older versions use their stored-plan reader; legacy and unsupported saves fail or remain on their documented path without source-file mutation.
- **WM-T18 — Headless failure:** Headless tests receive a typed error without UI or process exit, while production-style headless run start emits one canonical stderr record, exits with status 70, and creates no partial state.

## Verification and traceability matrix

| Criterion | Verification owner | Automated evidence | Manual or visual evidence |
|---|---|---|---|
| WM-T01 | Pure world-model tests | Coordinate count, uniqueness, validity, six-direction adjacency, canonical ordering | Full-board minimap inspection |
| WM-T02 | Pure generator and serialization tests | Known FNV vectors, exact payload bytes, same-seed artifact equality, traversal-order independence, round-trip equality, generator-version identity | Reopen one recorded seed and compare canonical artifact and landmarks |
| WM-T03 | Pure generator tests | Seven Safe towns, protected-cell exclusion, pairwise distance at least four, ten connected disjoint forest clusters of target size | Town and cluster readability on map and minimap |
| WM-T04 | Pure generator and rendering-contract tests | Deterministic minimum spanning tree, six edges for seven towns, stable equal-weight tie-breaks | Every town visibly belongs to one network |
| WM-T05 | Pure world-model and map-controller tests | Player `(-8, 0)`, boss `(8, 0)`, distance 16, seed independence, root-icon resource identity | Initial green/red markers on map and minimap |
| WM-T06 | World-map scene tests | Default framing and 3–11 zoom clamp | Screenshots at minimum, default, and maximum zoom |
| WM-T07 | World-map scene tests | Drag pan, wheel zoom, no turn mutation, no edge-scroll input path, bounded camera | Desktop pointer and wheel interaction |
| WM-T08 | World-map scene and visual regression tests | 217 outlined main cells and 217 outlined minimap cells at all zoom fixtures | Cell separation inspection at minimum, default, and maximum zoom |
| WM-T09 | World-map scene tests | 217 minimap cells, seven towns, both party markers, camera footprint state | Pan and zoom while inspecting minimap updates |
| WM-T10 | Existing AC3.3 regressions plus world-map scene tests | Six semantic slots, Front/Back labels, countdown values, guidance state, `Manage Party` availability gates | HUD readability and Party overlay transition |
| WM-T11 | Existing AC1.5 suite migrated to radius-8 fixtures | Exact accepted-move transaction order, move 30 activation, move 31 first step, one later step, neighbor-order tie-break, both engagement directions, reset | Avoid boss for 30 moves and observe pursuit until engagement |
| WM-T12 | Pure generator and map-controller tests | Forced unsatisfiable configuration returns the typed error; no partial plan reaches the controller | Failure surface opens before world interaction |
| WM-T13 | Run-start integration and structured-log tests | No save/history/roster mutation, exact error payload, copy action content | Blocking message and Return behavior |
| WM-T14 | Rendering-contract and visual regression tests | Fixed layer indices, road clear-corridor mask, protected forest exclusions, marker plate bounds | Representative road/forest/town/highlight/marker overlap screenshots |
| WM-T15 | Runtime performance profile owned by migration evidence | 60-second pan/zoom capture, generation seed corpus timing, memory delta, idle-allocation check | Reference hardware, resolution, build, and profiler capture recorded |
| WM-T16 | Migration evidence audit | Pre-cutover legacy results, post-cutover migrated/new results, GodotIQ validation and runtime health tied to required commits | Current manual and visual evidence with implementation references |
| WM-T17 | Run-save serialization and compatibility tests | V1 byte-identical round trip, stored-plan load, supported-old-version reader, legacy path, unsupported-version failure, source-file immutability | Load representative V1, legacy, and unsupported saves through the player-facing flow |
| WM-T18 | Headless generator and subprocess integration tests | `RETURN_RESULT` typed error, absent display access, exact stderr bytes, empty stdout failure channel, exit status 70, internal-error conversion, zero partial mutation | CI artifact preserves command, stderr, stdout, and process status |

## Migration test ownership

### Frozen legacy proof gates before cutover

The following current runners remain mandatory and unchanged on the 25-cell implementation until the migration commit is ready:

- `Tests/Map/test_hex_map_model.gd`;
- `Tests/Map/test_map_controller_runtime.gd`;
- `Tests/Map/test_ac1_1_runtime_step_counts.gd`;
- `Tests/Map/test_ac1_2_encounter_determinism.gd`;
- `Tests/Map/test_ac1_2_hex_tile_view_states.gd`;
- `Tests/Map/test_ac1_2_runtime_encounter_layout.gd`;
- `Tests/Map/test_ac1_3_mouse_navigation.gd`;
- `Tests/Map/test_ac1_4_encounter_overlay.gd`;
- `Tests/Map/test_ac1_5_sudden_death.gd`.

### Assertions retained through migrated fixtures

- AC1.3 valid adjacent pointer selection, invalid/off-map rejection, and keyboard-movement exclusion remain behavioral requirements; fixtures migrate to radius-8 coordinates and coexist with camera drag/zoom tests.
- AC1.4 one matching blocking overlay per accepted destination remains unchanged; fixtures add town and forest presentation cases without introducing new encounter types.
- AC1.5 activation timing shape, one-step pursuit, `NEIGHBOR_OFFSETS` tie-break, moving Boss identity, engagement in both directions, rejected-input behavior, and run reset remain unchanged; only the threshold fixture changes from 15/16 to 30/31 and coordinates migrate to radius 8.
- AC3.3 party-management integration remains a mandatory regression gate because the world-map HUD continues to open the same authoritative Party Management flow.

### Legacy assertions replaced after cutover

- Exact 25-cell count, bounded `q/r` range `0..4`, start `(0, 0)`, boss `(4, 4)`, 5×5 placement, and 15/16 threshold assertions retire only after their radius-8 successors pass.
- The current coordinate-specific AC1.2 layout fixtures remain historical evidence. Future encounter determinism is proven through the canonical versioned world-plan artifact and migrated Safe/Combat distribution assertions.
- Retired assertions remain in the evidence history; they are not rewritten to imply they tested the 217-cell world.

### New proof gates required for cutover

The migration plan must create and own focused runners for:

- canonical hashing, serialization, and round-trip equivalence;
- 217-cell geometry and fixed starts;
- town, road, forest, and atomic-failure constraint solving;
- 30/31 move transaction sequencing;
- camera pan/zoom bounds and absence of edge scrolling;
- 217-cell minimap state and camera footprint;
- visual layer precedence and readability;
- performance, generation-time, and memory budgets.

The production cutover may occur only on one implementation commit where all frozen legacy gates pass immediately before migration, all migrated and new gates pass immediately after migration, GodotIQ project validation and runtime health pass, and current manual/visual evidence identifies that same commit.

### Commit-level cutover and approval sequence

1. **Migration authority commit:** add and obtain project-lead approval for the dedicated migration specification. No production behavior changes.
2. **Golden RED commit:** add the immutable Generator V1 validation package and failing canonical generator/save contract tests. Record the fixture-review approval.
3. **Domain GREEN commit:** implement radius-8 geometry, canonical hashing/serialization, constraint solver, road/forest/town plan, typed failures, and save parsers without changing the production main-scene authority.
4. **Presentation GREEN commit:** implement the scrollable map, minimap, markers, HUD, overlap masks, camera controls, and failure overlay behind a non-production migration entry point.
5. **Integration GREEN commit:** integrate `MapController`, accepted-move sequencing, AC1.5 30/31 pursuit, Party access, and save/load compatibility while the 25-cell production entry remains available for legacy gates.
6. **Pre-cutover evidence commit:** record passing frozen legacy gates against the exact parent of the intended cutover commit. The evidence manifest records full SHA, commands, outputs, reference hardware, and artifact hashes.
7. **Cutover implementation commit:** switch production world authority from the 25-cell path to Generator V1, remove only the superseded production entry, and retain the documented legacy save reader and historical evidence.
8. **Post-cutover evidence commit:** without changing implementation, record migrated/new automated results, full regressions, GodotIQ validation, signal-orphan check, runtime health, deterministic corpus hashes, save round trips, performance profile, and manual/visual checks against the exact cutover implementation SHA.
9. **Project-lead approval:** approve the evidence manifest and criterion matrix. Only then may the new migration criteria be marked complete and the 25-cell implementation be classified as retired rather than merely bypassed.

The evidence packet belongs under `Docs/Specs/WorldMap/Evidence/GeneratorV1/YYYY-MM-DD/` and contains:

```text
authority.md
implementation-link.txt
criterion-matrix.md
legacy-pre-cutover.log
automated-post-cutover.log
golden-corpus-manifest.json
save-compatibility.log
godotiq-validation.log
runtime-health.log
performance-profile.md
manual-runtime-check.md
visual-regression-manifest.json
approval.md
```

Every artifact names either the pre-cutover parent SHA or the cutover implementation SHA as applicable. The post-cutover evidence commit may contain evidence only; any implementation change invalidates the packet and restarts post-cutover verification.

## Normative cutover and headless policy summary

This section is the single concise authority for the three final boundary rules. Detailed procedures and evidence remain in the sections above.

### Exact cutover SHA rule

- Let `C` be the full Git SHA of step 7, the Cutover implementation commit.
- Let `P` be `C^`, the single first parent of `C`.
- Production authority changes from the 25-cell world to Generator V1 only in `C`; no earlier commit is a production cutover.
- The pre-cutover evidence packet runs the complete frozen legacy gate set against `P` and records `P` in every legacy artifact.
- The post-cutover evidence packet runs the migrated and new gate set against `C` and records `C` in every post-cutover artifact.
- `C` is acceptable only when the recorded legacy result for `P` passes, the recorded migrated/new result for `C` passes, and `C` is the direct child of `P`.
- The evidence-only commit after `C` may add records but no implementation change. Any implementation change creates a new candidate `C`, a new parent `P`, and requires both evidence phases again.

### Frozen legacy-test rule

- From approval of the migration authority through successful verification of candidate `C`, the named 25-cell legacy test files and their expected values are frozen.
- No migration commit before `C` may weaken, skip, rename, delete, rewrite, or conditionally bypass a frozen legacy assertion.
- Frozen legacy tests must pass at `P`. They are retired or migrated only by the approved changes in `C`, and only after the post-cutover successors pass at `C`.
- A failure at `P` blocks creating or approving `C`; a failure at `C` leaves the 25-cell world authoritative.

### Headless failure-policy rule

| Execution context | Policy | UI behavior | Failure result | Process behavior |
|---|---|---|---|---|
| Unit or integration test runner | `RETURN_RESULT` | Never instantiate or access the overlay/display path | Return exact typed `WorldGenerationError` to the test | Do not call `SceneTree.quit()`; test process continues |
| Production-style headless run-start entry | `EXIT_PROCESS` | Never instantiate or access the overlay/display path | Write one canonical `world_generation_failed` JSON line to stderr | Request `SceneTree.quit(70)` and finish with exit status `70` |

Both policies must prove zero partial publication or mutation. Tests may not validate `EXIT_PROCESS` by substituting `RETURN_RESULT`; subprocess verification must assert stderr bytes and exit status 70 directly.

## Future planning boundary

No separate 25-hex-to-217-hex migration specification or implementation plan exists as of 2026-08-23. This design is not that migration artifact.

Before implementation changes the canonical MVP or production scenes, a dedicated migration specification must:

- name the replacement acceptance criteria for the larger world;
- map each frozen current criterion to its successor verification:
  - AC1.1 remains the authority for adjacent traversal and current 25-cell evidence;
  - AC1.2 remains the authority for seeded encounter determinism and current 25-cell evidence;
  - AC1.3 remains the authority for pointer selection of adjacent destinations;
  - AC1.4 remains the authority for one matching Encounter overlay after an accepted move;
  - AC1.5 remains the authority for activation-without-pursuit on the threshold move, deterministic pursuit beginning on the next accepted move, moving Boss identity, engagement, and reset;
- identify which current tests are migrated, retained as regression coverage, or retired with historical evidence;
- define `world_generator_version` persistence and save compatibility;
- set camera, rendering, generation-time, and memory budgets;
- name file ownership and an ordered cutover that never leaves the production branch with mixed 25-cell and 217-cell authority;
- require current AC1.1–AC1.5 regression gates to remain green until the replacement criteria pass against one implementation commit.

AC1.1–AC1.5 remain checked and frozen as evidence of the current MVP only. Their existing evidence does not prove this future design, and this design does not alter their status. The migration specification must be approved before an implementation plan is written.
