---
name: runtime-performance-profile
description: Use when frame time, streaming, memory, rendering, physics, AI, or load-time behavior needs evidence-based performance analysis.
---

# Runtime Performance Profile

Measure before recommending optimization. Separate observed bottlenecks from static-analysis candidates.

## Inputs

- Target system, scene, route, or gameplay workload.
- Target hardware class and available budgets or baselines.

## Preconditions

- Read `AGENTS.md` performance constraints.
- Define workload duration, counters, warm-up, and comparison baseline.

## Workflow

1. Inspect likely hot paths and active-node ownership with GodotIQ.
2. Run a repeatable workload and capture CPU, rendering, physics, memory, and load-time evidence available to the environment.
3. Identify the top measured bottlenecks and distinguish them from unconfirmed candidates.
4. Check chunk activation, distant processing, MultiMesh use, allocation churn, and resource loading where relevant.
5. Rank recommendations by measured impact, risk, and implementation cost.

If GodotIQ profiling is unavailable, static inspection and headless timing are fallback evidence only. Label estimates and require target-hardware confirmation. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return workload, environment, budgets, measurements, bottlenecks, recommendations, confidence, and follow-up measurements.

## Failure Behavior

Return `INCONCLUSIVE` rather than guessing when the workload cannot be reproduced or measurements are unsupported.

## Verification Evidence

Include tool and build identity, sample duration, observed values, baseline delta, and which recommendations remain hypotheses.
