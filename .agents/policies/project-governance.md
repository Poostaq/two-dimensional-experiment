# Project Governance — 2D Game Development

This file is the replaceable policy seam between reusable agent capabilities and the repository's current development workflow.

## Lean Development Gate (Small-to-Medium 2D Game)

1. **Concept** — Gameplay Systems Designer formalizes core loop, mechanics, and rules (no code)
2. **Design** — Write one-page game spec with acceptance criteria
3. **Implementation** — Godot Implementation agent + GodotIQ for coding
4. **QA** — Godot QA Playtester runs smoke gate and gameplay validation

## Authority

- The project lead owns product decisions.
- Agentic reviewers provide technical validation (optional for small scope).
- Document exceptions rather than hiding them.

## Branch and Commit Workflow

When starting code work, agents must first update the default integration branch from origin, then create a dedicated task branch for the change.

- Use `main` in this repository; use `master` only in repositories where that is the default integration branch.
- Do not carry unrelated local changes onto the task branch. Stash or use an isolated worktree when needed.
- Commit the completed code change on the task branch with only relevant files staged.
- Push the branch when the user asks for remote handoff or review.

## Completion Evidence

Provide: spec reference, test results, and implementation link. Do not claim completion without current evidence.
