---
name: project-stage-audit
description: Use when assessing repository progress, maturity, documentation gaps, verification readiness, or the next highest-value development step.
---

# Project Stage Audit

Assess actual repository evidence rather than inferring progress from file counts alone.

## Inputs

- Whole project or role-specific focus.
- Current roadmap, governance policy, and milestone if known.

## Preconditions

- Read `AGENTS.md`, `.agents/policies/project-governance.md`, the roadmap, and spec index.
- Use GodotIQ for the Godot project overview before directory-level fallback scans.

## Workflow

1. Inventory active specs, implementation records, tests, runtime systems, assets, and legacy obligations.
2. Compare claimed status with approvals and current verification evidence.
3. Classify the project stage and confidence using observable completion signals.
4. Identify blocking gaps, stale status, duplicated authority, and migration debt.
5. Recommend a short ordered list of next actions with rationale and dependencies.

If GodotIQ is unavailable, repository structure and document inspection are a fallback. Mark runtime and scene maturity provisional. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return stage, confidence, evidence summary, completed capabilities, gaps, risks, and ordered recommendations.

## Failure Behavior

Do not manufacture percentages from missing evidence. Report unsupported capabilities and use `INCONCLUSIVE` for affected categories.

## Verification Evidence

Include artifact counts with paths, approval states, latest test evidence, runtime health evidence, and mismatches between claims and implementation.
