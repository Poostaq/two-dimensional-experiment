---
name: spec-to-test-traceability
description: Use when acceptance criteria need mapping to automated tests, manual checks, runtime evidence, or implementation records.
---

# Spec to Test Traceability

Build a complete, evidence-oriented map from every acceptance criterion to at least one valid verification path.

## Inputs

- Feature and related design or verification specs.
- Test directories, manual-test corpus, and implementation record when present.

## Preconditions

- Read `AGENTS.md` and `.agents/policies/project-governance.md`.
- Treat acceptance criterion IDs as stable identifiers.

## Workflow

1. Extract every acceptance criterion and classify it as logic, integration, runtime, visual, performance, or documentation.
2. Locate existing tests and evidence using GodotIQ for Godot behavior and repository search for documents.
3. Map each criterion to concrete test names, manual steps, or validation outputs.
4. Flag missing, stale, circular, subjective, or non-binary coverage.
5. Propose the smallest additional verification needed for complete coverage.

If GodotIQ is unavailable, textual test discovery is a fallback. Mark runtime, scene, and signal coverage as unconfirmed. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return a criterion matrix with verification path, evidence location, status, gap, and recommended next action.

## Failure Behavior

Return FAIL when any blocking criterion has no verification path. Report unsupported discovery capabilities rather than claiming coverage.

## Verification Evidence

Include spec IDs, criterion text, exact test or manual-step references, latest result where available, and overall coverage counts.
