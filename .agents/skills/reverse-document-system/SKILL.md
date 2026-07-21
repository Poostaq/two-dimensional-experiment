---
name: reverse-document-system
description: Use when implemented Godot behavior lacks an accurate design, architecture, interface, or verification document.
---

# Reverse Document System

Describe observed implementation separately from inferred intent. Never turn accidental behavior into policy without review.

## Inputs

- System, feature, scene, or script scope.
- Requested document type and target artifact, if known.

## Preconditions

- Read `AGENTS.md`, `.agents/policies/project-governance.md`, and related existing specs.
- Identify authoritative code and legacy documentation for the scope.

## Workflow

1. Inspect execution flow, data ownership, interfaces, signals, Resources, tests, and scene usage with GodotIQ.
2. Separate facts, inferred intent, contradictions, and unanswered product decisions.
3. Map behavior to the repository's current spec templates without copying obsolete workflow language.
4. Draft architecture, data contracts, failure modes, determinism, performance, and verification sections as applicable.
5. Present gaps and decision points before proposing authoritative status.

If GodotIQ is unavailable, structured repository inspection is the fallback for non-scene facts. Mark scene wiring and runtime claims incomplete. Never edit scenes or scripts without structured Godot tooling.

## Output Contract

Return observed behavior, inferred intent, contradictions, draft document content, traceability links, and decisions requiring project-lead confirmation.

## Failure Behavior

Do not invent missing intent. Return `INCONCLUSIVE` for behavior that cannot be traced or reproduced and report unsupported capabilities.

## Verification Evidence

Include source paths, dependency or signal evidence, tests consulted, runtime observations, and a fact-versus-inference label for material claims.
