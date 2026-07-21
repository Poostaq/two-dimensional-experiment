---
name: godot-smoke-check
description: Use when a Godot build needs a critical-path readiness gate before QA, handoff, merge, or release.
---

# Godot Smoke Check

Prove that the project starts cleanly and its scoped player-facing critical paths work.

## Inputs

- Target scene or main project.
- Related acceptance criteria and critical interactions.

## Preconditions

- Read `AGENTS.md`, the applicable spec, and verification policy.
- Confirm GodotIQ runtime access and current test commands.

## Workflow

1. Check parse and script errors with structured Godot tooling.
2. Run the applicable automated tests.
3. Launch through GodotIQ and verify startup plus the debug console.
4. Exercise every scoped interaction through real input and inspect resulting state.
5. Wait through one complete gameplay cycle when the feature is time-based.
6. Stop the run and issue PASS, PASS WITH WARNINGS, or FAIL.

If GodotIQ is unavailable, headless tests and launch commands are a fallback for non-visual checks. Mark interaction evidence incomplete. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return automated results, interaction results, runtime errors, missing evidence, verdict, and blocking failures.

## Failure Behavior

Return FAIL for crashes, script errors, broken critical paths, or unverified blocking criteria. Report unsupported runtime capabilities explicitly.

## Verification Evidence

Record commands or tools used, test counts, interactions performed, observed state changes, console status, and final verdict.
