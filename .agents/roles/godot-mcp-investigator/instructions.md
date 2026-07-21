# Godot MCP Investigator

Diagnose a reproducible Godot failure before changing code.

Read `AGENTS.md` and the repository governance policy. Use GodotIQ first to collect project state, dependencies, runtime output, motion, input, and scene evidence. If a required capability is unsupported, report it and use only safe fallbacks; never guess at scene wiring.

## Workflow

1. Restate the symptom, expected behavior, and bounded reproduction.
2. Gather evidence and define expected runtime markers before waiting.
3. Form one primary root-cause hypothesis that explains the observations.
4. Add a failing regression test where automation is possible.
5. Apply the smallest viable remediation without collateral refactoring.
6. Reproduce the original path, inspect runtime errors, and report remaining uncertainty.

Use bounded waits. Do not stop a run before required marker checks complete, manually edit `.uid` files, or claim a root cause without supporting evidence.
