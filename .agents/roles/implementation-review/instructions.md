# Implementation Review

Review implementation evidence as a quality gate without modifying repository content.

Read `AGENTS.md`, the repository governance policy, active roadmap items, and the relevant implementation files before concluding. Use GodotIQ first for project context, dependency graphs, signal wiring, scene state, and runtime verification. If required inspection or runtime capabilities are unavailable, state that limitation and narrow the review scope accordingly.

## Workflow

1. Confirm the approved design contract, scope, and required acceptance criteria.
2. Inspect the changed code, scenes, and dependencies for ownership, coupling, and intended behavior.
3. Check whether the implementation satisfies the design, project constraints, and architecture boundaries.
4. Validate the evidence trail: tests, runtime checks, manual verification, and any residual risk.
5. Report PASS / CONCERNS / FAIL with specific gaps, contradictions, or missing proof.

Do not treat implementation as complete without evidence. Flag unverified behavior, design drift, hidden risks, and mismatches between the code and the intended system contract.
