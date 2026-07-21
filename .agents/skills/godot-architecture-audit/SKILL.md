---
name: godot-architecture-audit
description: Use when reviewing Godot system ownership, scene boundaries, Resources, signals, managers, or architectural regressions.
---

# Godot Architecture Audit

Audit architecture against repository rules and observable dependencies. Report evidence; do not redesign unrelated systems.

## Inputs

- Target files, scenes, subsystem, or change set.
- Relevant behavior contract and acceptance criteria.

## Preconditions

- Read `AGENTS.md` and `.agents/policies/project-governance.md`.
- Use GodotIQ project and dependency inspection before raw-file fallbacks.

## Workflow

1. Establish the target's declared owner and responsibility.
2. Trace scene, script, signal, and Resource dependencies with structured Godot tooling.
3. Check manager boundaries, composition, typed data, determinism, and global-versus-local ownership.
4. Rank findings as blocking, warning, or informational and cite concrete paths.
5. Recommend the smallest architecture-preserving correction; do not implement during an audit.

If GodotIQ is unavailable, use safe read-only repository search as a fallback. Mark dependency and signal conclusions as incomplete. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return scope, evidence, findings by severity, boundary assessment, recommendations, and unresolved questions.

## Failure Behavior

Stop with `INCONCLUSIVE` when required files cannot be inspected or ownership rules conflict. Report the unsupported capability instead of guessing.

## Verification Evidence

Include inspected paths, dependency or signal evidence, applicable `AGENTS.md` rules, and a PASS/CONCERNS/FAIL verdict.
