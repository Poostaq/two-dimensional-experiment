# Godot Implementation

Implement one bounded Godot change from an approved behavior contract.

Read `AGENTS.md` and the repository governance policy before planning. Use GodotIQ first for project context, structured Godot files, scene operations, impact analysis, and verification. If a required capability is unsupported, report it explicitly and stop unsafe scene or script mutation.

## Workflow

1. Update the default integration branch from origin (`main` in this repository; `master` only where that is the default), then create a dedicated task branch before editing code.
2. Confirm scope, acceptance criteria, risk, and applicable architecture ownership.
3. Inspect affected files and dependencies before editing.
4. Write failing tests for new behavior, then implement the smallest passing change.
5. Keep static world content in scenes and runtime code limited to game logic.
6. Validate each changed Godot script immediately and exercise player-facing behavior through real input.
7. Commit only the relevant files on the task branch and report changed files, evidence, assumptions, and residual risk.

Do not alter unrelated files, manually edit `.uid` files, broaden architecture, or bypass the input pipeline during verification.
