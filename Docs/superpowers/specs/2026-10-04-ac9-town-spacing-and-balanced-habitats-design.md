# AC9 Town Spacing and Balanced Allied Habitats

**Date:** 2026-10-04
**Status:** Approved for implementation planning on 2026-10-04

## Goal

Correct the generated AC9 world topology so the three town-bearing allied habitats occupy equal areas and towns are distributed across the map instead of appearing on adjacent hexes. The enemy habitat keeps its previously approved footprint and is excluded from allied-area balancing.

This design extends the corrected AC9.4-AC9.6 topology contract. It preserves the western player start, eastern enemy start, race-based habitat presentation, three towns per allied habitat, and nine V3 internal roads.

## Current behavior

`WorldHabitatSolverV2` accepts the first connected three-way allied partition with enough raw cells for three towns per habitat. It then takes the first three seed-ranked candidates in each habitat. Neither step considers habitat area balance, town-to-town distance, or distance from the two starting coordinates.

The current golden V2/V3 topology demonstrates the resulting skew: the allied habitats contain 62, 125, and 21 cells, while several town pairs occupy adjacent hexes.

## Placement contract

The radius-eight board continues to contain 217 cells. The enemy habitat remains the exact clipped radius-two footprint approved for AC9.4 and contains 9 cells. It is not resized or included in the allied balance calculation.

The remaining 208 cells must be assigned to `main`, `ally_0`, and `ally_1` as a permutation of 69, 69, and 70 cells. The seed deterministically selects which allied habitat receives the additional cell. This one-cell difference is the closest possible integer division and is a mandatory invariant, not a best-effort preference.

Every habitat remains connected and contains its canonical anchor. Each allied habitat contains exactly three towns; the enemy habitat contains none.

Every town must be at hex distance 2 or greater from both the player starting coordinate and the enemy starting coordinate. This spawn-clearance rule is mandatory even when the preferred town-to-town spacing is infeasible.

Across all nine towns, every pair should be at hex distance 2 or greater. Generation must first search for a layout with no adjacent town pairs. A closer town-to-town layout is permitted only after the finite deterministic search proves that no fully separated layout exists among the valid balanced partitions.

When fallback is necessary, layouts are compared in this order:

1. fewest adjacent town pairs;
2. greatest total pairwise town distance;
3. stable partition order; and
4. seed-ranked candidate order.

Generation fails only when it cannot construct a connected 69/69/70 allied partition containing three eligible towns per habitat while respecting both spawn-clearance rules.

## Architecture

`WorldHabitatSolverV2` remains the topology orchestrator. It retains the exact enemy-footprint construction and deterministic seed-ranked allied-anchor enumeration. For each anchor combination it constructs a connected, quota-aware allied partition. Frontier expansion may claim a cell only for a habitat that has not reached its assigned 69- or 70-cell quota; every claim extends that habitat from its anchor. A candidate is rejected if expansion cannot cover every non-enemy cell without exceeding a quota or if any hard town-capacity rule cannot be met.

Partition and frontier decisions use canonical coordinate order, the existing versioned world priority, and stable habitat order. Search is finite and does not use mutable RNG, elapsed-time budgets, or dictionary iteration order. Valid balanced partitions are passed to town placement in their deterministic search order.

Create `WorldTownPlacementSolverV2` as a small stateless rules component. It accepts the seed, a balanced habitat assignment, the player start, and the enemy start. It:

1. removes both starts and every cell less than distance 2 from either start;
2. builds a seed-ranked candidate list for each allied habitat;
3. searches for exactly three towns per habitat with zero adjacent pairs globally;
4. returns the first fully separated result in deterministic partition and candidate order; and
5. retains the best fallback encountered when no fully separated result exists.

The search uses exhaustive depth-first selection with habitat quotas and branch pruning. It stops exploring a branch when a habitat can no longer meet its quota, when its adjacent-pair score already exceeds the best fallback, or when a zero-adjacency choice cannot improve the current full-solution search. The fixed nine-town output bounds the selected depth. Exhaustive completion, rather than a time or iteration cutoff, is what authorizes fallback.

The town solver returns the canonical town coordinates plus internal diagnostics: adjacent-pair count, total pairwise distance, and whether full spacing was achieved. Those diagnostics are used for selection and tests only; no new fields are persisted in `WorldPlan`.

`WorldHabitatSolverV2` compares valid partition results globally. It returns immediately on the first fully spaced result because partition order and candidate order are already canonical. If no partition produces full spacing, it returns the fallback with the fewest adjacent pairs, then greatest total distance, then earliest stable partition and candidate order.

## Codec and version behavior

`WorldPlanCodecV2` adds structural validation for:

- the exact 9-cell enemy footprint;
- allied habitat counts equal to a permutation of 69, 69, and 70;
- the canonical seeded assignment of the 70-cell allied quota;
- connected habitats and required anchor ownership;
- exactly three towns in each allied habitat;
- every town at least distance 2 from both starts; and
- canonical town selection for the stored balanced partition.

Canonical town validation reruns the pure town-placement rules against the stored habitat assignment and decoded canonical seed. A town moved to another otherwise legal cell is rejected when it does not match that partition's deterministic selection. The codec need not rerun every alternative partition; generator-level corpus and determinism tests prove global partition selection.

V3 continues to derive its complete non-road topology from V2, so it inherits the balanced habitats and corrected towns before constructing its nine internal roads. Road identities and the three pairs per allied habitat do not change; only their endpoint coordinates and canonical serialized bytes may change.

This is an explicitly approved in-place correction to the current V2/V3 contract. V2 and V3 golden fixtures, corpus fixtures, hashes, and dependent expectations will be regenerated. V1 behavior and fixture bytes remain unchanged. Existing local saves were deliberately deleted, so no save migration or compatibility shim is introduced.

## Failure behavior

Generation remains atomic. It must never publish a partial partition, fewer than nine towns, a spawn-adjacent town, or an unbalanced allied topology.

If no candidate produces a connected quota-complete partition with mandatory town capacity and spawn clearance, generation returns `WORLD_CONSTRAINT_UNSATISFIABLE`, generator version 2, namespace `habitat`, and a focused balanced-partition/town-capacity constraint. A town-spacing fallback is a successful result, not an error, because it is allowed only after exhaustive proof that complete global separation is unavailable.

Malformed or altered persisted topology continues to fail through the codec's existing typed validation path. V3 delegates non-road validation to V2 before validating road records.

## Verification strategy

Implementation follows test-driven development. Initial failing tests must establish the new balance and spacing rules before production changes.

Focused solver coverage includes:

- exact allied counts 69, 69, and 70 across the existing deterministic seed and identity corpus;
- the unchanged exact 9-cell enemy footprint;
- complete board coverage, exclusivity, habitat connectivity, and anchor ownership;
- deterministic selection of the habitat receiving the 70th cell;
- exactly three towns in each allied habitat and none in the enemy habitat;
- town distance of at least 2 from both starting coordinates;
- global pairwise town distance of at least 2 whenever a fully separated layout exists;
- a synthetic infeasible candidate set proving the minimum-adjacency fallback and total-distance tie break;
- clean/interleaved determinism and repeated generation equality; and
- atomic unsatisfiable failure with no partial result.

Codec coverage mutates otherwise valid plans to prove rejection of an unbalanced allied count, altered enemy footprint, disconnected habitat, town inside spawn clearance, and noncanonical town replacement. Round-trip and canonical-byte tests cover the regenerated V2 and V3 fixtures.

V3 tests prove that all nine roads still connect the three canonical pairs inside each allied habitat after endpoint relocation. V1 golden and corpus fixtures must remain byte-for-byte unchanged.

Final verification includes focused SceneTree suites, the complete affected world-generation/save/runtime regression set, per-script GodotIQ validation and parser checks, project validation, orphan-signal inspection, normal Play startup, and a production new-run inspection confirming:

- generator version 3;
- western player and eastern enemy starts;
- allied habitat counts 69/69/70;
- enemy habitat count 9;
- nine towns satisfying mandatory spawn clearance;
- the selected global town-spacing result; and
- nine valid internal roads.

## Out of scope

This correction does not resize the enemy habitat, add enemy towns, alter road connectivity rules, change terrain or encounter distribution beyond existing town safety overrides, add habitat coloring, change movement rules, or introduce a new save format or generator version.
