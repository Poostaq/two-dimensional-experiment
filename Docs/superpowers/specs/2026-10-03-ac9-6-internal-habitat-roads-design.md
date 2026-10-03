# AC9.6 Internal Habitat Roads Design

**Status:** Approved on 2026-10-03

**Acceptance criterion:** AC9.6 — Within each allied habitat, each of its three towns has a road connection to both others: all three town pairs are connected.

## Purpose

AC9.6 introduces the first road-bearing version of the generated habitat world. Generator V3 preserves the complete V2 habitat, town, forest, encounter, and spawn topology for the same seed and player configuration, then adds the three unordered town pairs inside each of the three allied habitats. The resulting plan contains exactly nine internal road records.

This design supersedes the earlier aggregate AC9 roadmap only where that roadmap assigned both AC9.6 and AC9.7 to V3. V3 now belongs exclusively to AC9.6. AC9.7 will introduce V4 for cross-habitat roads, so neither criterion mutates an already published generator version.

## Scope

AC9.6 includes:

- a pure V3 internal-road rules component;
- a V3 generator that derives its non-road topology from the frozen V2 behavior;
- a strict V3 codec and facade dispatch;
- production new-run cutover from V2 to V3;
- run-save compatibility for V3 world-plan bytes;
- deterministic fixtures and automated/runtime verification;
- documentation and acceptance evidence updates.

AC9.6 does not include:

- cross-habitat endpoint selection or roads, which belong to AC9.7 and V4;
- habitat coloring, final road art, minimap road styling, or other presentation work, which belongs to AC9.10;
- movement discounts or road-dependent navigation;
- mutable road state, sieges, ruins, or enemy campaign behavior;
- any change to V1 or V2 canonical bytes, parsing, validation, or fixtures.

## Version Contract

The world generator versions are immutable contracts:

- V1 remains the legacy seven-town minimum-spanning-tree world.
- V2 remains the AC9.4/AC9.5 habitat world with nine allied towns and an empty road array.
- V3 contains the same non-road topology as V2 plus the nine AC9.6 internal town-pair roads.
- V4 is reserved for AC9.7 cross-habitat roads.

For a fixed seed and identity configuration, V3 must reproduce V2 cells, habitats, towns, forests, encounters, and spawn coordinates exactly. Only the plan version and road collection may differ. Existing V1 and V2 saves continue through their current codec paths and are never regenerated through V3.

## Architecture

### Internal road rules

Create `Scripts/WorldMap/habitat_road_rules_v3.gd` as a focused, stateless rules component. Its public entry point accepts the nine canonical V2 town records and returns either a complete canonical road collection or a typed generation error.

The component groups towns by the canonical allied habitat order `main`, `ally_0`, `ally_1`. Each group must contain local town indices `0`, `1`, and `2` exactly once. It emits these local-index pairs in this order for every habitat:

1. `(0, 1)`
2. `(0, 2)`
3. `(1, 2)`

Each road record uses the existing immutable endpoint shape:

```gdscript
{
    "a": Vector2i,
    "b": Vector2i,
}
```

The lower local index supplies `a`; the higher local index supplies `b`. This avoids orientation ambiguity and gives the codec a single canonical order. Endpoints must be distinct, on-board town coordinates owned by the same allied habitat. Enemy habitat endpoints and duplicate unordered pairs are invalid.

### Deterministic route interpretation

Road records remain endpoint pairs because the existing presentation derives a shortest contiguous hex route from each pair using `HexWorldGeometry.get_neighbors()` in fixed neighbor order. V3 validation independently walks the same rule and requires every step to remain on the canonical radius-eight board, strictly reduce distance to the destination, and finish after exactly the endpoint hex distance.

AC9.6 road paths may cross habitat boundaries because the acceptance criterion constrains town ownership and connectivity, not every intermediate road hex. Roads remain cosmetic and do not change traversability or movement cost.

### V3 generator

Create `Scripts/WorldMap/hex_world_generator_v3.gd`. It must reuse the frozen V2 generation path rather than copy and gradually diverge from the V2 habitat solver. The V3 generator:

1. validates the same identity configuration as V2;
2. generates the V2 plan for the same seed and configuration;
3. builds the nine internal roads from the returned town records;
4. creates a new `WorldPlan` with version `3`, deep-copied V2 collections, and the V3 road collection;
5. validates the complete candidate with the V3 codec before publishing it.

Any V2 generation, road-rule, or V3 validation failure returns `{ok=false, plan=null, error=...}`. No partial V3 plan is exposed.

### V3 codec

Create `Scripts/WorldMap/world_plan_codec_v3.gd` with header `TWDE-WORLD,3`. Its canonical record order is the V2 order with nine `road` records inserted after the nine towns and before forest records:

```text
road,<a_q>,<a_r>,<b_q>,<b_r>
```

The V3 codec delegates the complete non-road contract to V2 instead of copying its parser and validators. Serialization creates a temporary version-2 shadow plan with the V3 plan's cells, habitats, towns, forests, spawns, and an empty road array; `WorldPlanCodecV2` validates and serializes that shadow plan. V3 then changes only the header and inserts its canonical road records. Parsing performs the inverse transformation, lets V2 parse and validate the roadless bytes, then creates a V3 plan from the parsed V2 collections and parsed roads. This makes V2 equivalence an executable boundary and keeps the frozen V2 implementation unchanged.

The parser accepts exactly nine canonical road records, constructs a V3 plan, runs road validation, and requires `serialize(parsed_plan) == bytes`. Validation requires the V2 shadow plan to pass every V2 invariant, then adds:

- exactly nine roads;
- exactly three roads for each allied habitat;
- all three unordered local-index pairs per habitat;
- no enemy or cross-habitat endpoints;
- every endpoint resolves to a unique town;
- no self-edge, duplicate edge, reversed duplicate, extra field, or noncanonical order;
- every derived shortest route remains on-board and reaches its destination.

`Scripts/WorldMap/world_plan_codec.gd` adds V3 serialize, parse, and validate dispatch without changing V1 or V2 branches.

### Production cutover and persistence

`Scripts/Run/world_run_start_service.gd` uses `HexWorldGeneratorV3` for newly created runs. Continue remains decode-only and never invokes a generator. The existing run-save envelope must accept plan version 3 while continuing to require that the envelope version matches the decoded plan version and that persisted clan identities match the plan.

No migration rewrites V1 or V2 plans. A saved V2 run continues as V2; only a newly created run receives V3.

## Error Handling

Road construction and validation use the existing `WorldGenerationError` contract. Failures identify generator version `3`, preserve the normalized seed where available, and use a road-specific feature namespace. Stable constraint identifiers distinguish malformed town input, missing habitat pairs, invalid endpoints, duplicate pairs, noncanonical ordering, invalid routes, codec records, and version mismatch.

The new-run transaction keeps its current atomic behavior: generation or serialization failure must not replace the prior durable save.

## Verification Strategy

### Automated logic tests

A focused road-rules test proves:

- the three canonical unordered pairs are emitted for one habitat;
- all three allied habitats produce exactly nine roads;
- endpoints correspond to towns in the same habitat;
- input order does not alter canonical output;
- malformed, missing, duplicate, enemy, and cross-owned town records fail without partial roads;
- every derived route is contiguous, shortest, deterministic, and on-board.

### Generator tests

A V3 generator test compares V2 and V3 across a fixed seed/configuration corpus. It requires identical non-road topology, exactly nine canonical roads, clean/interleaved determinism, no cross-habitat roads, and complete failure isolation.

### Codec and fixture tests

The V3 codec test covers canonical bytes, round-trip identity, facade dispatch, golden fixture/hash, record reordering, missing/extra/reversed/duplicate roads, invalid endpoints, invalid routes, unsupported versions, and unchanged V1/V2 fixture hashes.

### Run/save integration tests

Start-service and save-codec tests prove that new runs publish V3, V3 round-trips through the current save envelope, V1/V2 remain readable, Continue does not regenerate, and a V3 failure preserves the prior save.

### Runtime gate

After all focused tests pass, run project validation and parser checks, verify the main scene starts without runtime errors, create a new run through the production path, and inspect the active plan to confirm version `3`, nine towns, and nine roads. Visual road styling is not an AC9.6 gate.

## Acceptance Traceability

| Requirement | Verification path | Completion evidence |
|---|---|---|
| Three towns per allied habitat are pairwise connected | Road-rules and V3 generator tests assert pairs `(0,1)`, `(0,2)`, `(1,2)` for all three habitats | Focused test log |
| Exactly nine internal connections | Generator and codec tests assert nine canonical road records | Focused test and fixture logs |
| Connections remain inside their allied habitat | Rule and codec rejection tests resolve each endpoint through canonical town ownership | Negative-test log |
| Generation is deterministic | Seed/configuration corpus, interleaving test, and golden V3 fixture hash | Fixture and determinism logs |
| V1/V2 remain immutable | Existing fixture-integrity suites and explicit facade regression assertions | Regression logs |
| New runs use the AC9.6 topology | Start-service/save tests plus Play-mode state inspection | Integration and runtime logs |

AC9.6 is complete only when every row has current passing evidence and the main MVP specification links to the recorded verification artifact.
