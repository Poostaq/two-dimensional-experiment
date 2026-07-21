---
name: worldgen-determinism-audit
description: Use when procedural generation, chunk loading, spawn planning, or save/reload behavior may produce non-reproducible results.
---

# World Generation Determinism Audit

Verify that identical world seed, chunk coordinates, inputs, and versions produce identical outputs.

## Inputs

- World seed and chunk or region set.
- Outputs to compare and applicable acceptance criteria.

## Preconditions

- Read `AGENTS.md` and identify every generation entry point in scope.
- Establish a stable capture format before running comparisons.

## Workflow

1. Trace seed derivation, coordinate mixing, iteration order, and RandomNumberGenerator ownership with GodotIQ.
2. Search for uncontrolled randomness, time dependence, unstable collection order, and hidden mutable state.
3. Capture output for the same inputs in two clean runs.
4. Compare biome, terrain, decoration, gatherable, and fauna plans as applicable.
5. Test unload/reload and alternate traversal order when streaming participates.
6. Report the first divergent value and its generating path.

If GodotIQ is unavailable, automated deterministic tests are the fallback. Mark runtime streaming conclusions incomplete. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return inputs, checks, per-check status, divergence evidence, likely source, remediation recommendation, and verdict.

## Failure Behavior

Return FAIL on any reproducible divergence. Return `INCONCLUSIVE` when clean-run isolation or required runtime state is unsupported.

## Verification Evidence

Include seed, coordinates, run boundaries, capture hashes or values, traversal order, and the exact first difference.
