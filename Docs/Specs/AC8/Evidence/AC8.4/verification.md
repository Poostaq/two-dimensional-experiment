# AC8.4 ownership verification — 2026-09-20

Result: **PASS for the ownership prerequisite** on `feat/ac8-4-town-ownership`. Production/test commits: `09bca93` (pure rule) and `d40f492` (runtime/reload). Base: AC8.3 `5cb6ed4`. The evidence commit adds documentation only.

The shared rule resolves every validated world-v1 town to `goblin`, rejects non-towns and unsupported world versions, and does not mutate topology or run state. Runtime queries and candidate-model copies delegate to that rule. No save schema, generator, scene, recruitment UI or wallet behavior changed.

## Automated verification

All **16 required runners** passed with exit 0, explicit PASS output and no script/runtime ERROR. [Gate results](gate-results.json) list the exact runners; each `gate-*.log` includes its exact command. Four baseline runners also passed before implementation.

The two focused runners were observed failing for the expected missing rule/API before implementation (`red-rule-*` and `red-runtime-*`). Their final gate runs pass. Coverage includes all seven canonical fixture towns, all non-town cells, invalid local records, null/off-map queries, unknown versions, candidate copies, and every town on three generated seeds across save versions 2, 3, 4 and 5. Exact canonical bytes protect roads, cells, forests and spawns; restored/live state dictionaries remain unchanged by queries.

Plan correction: the first reload run failed its raw road-array equality check, despite identical canonical bytes. Diagnostic output shows only array ordering differs: generation order versus the codec's canonical sorted order. The final test compares restored roads with a parsed canonical baseline and still requires byte-identical full plans. No production codec or generator change was needed. Intermediate `green-runtime-*` and `diagnostic-*` logs retain this failed assertion; final acceptance uses `gate-*`.

Reproduce from repository root (substitute the other paths in gate-results.json):

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 1800 --script res://Tests/WorldMap/test_ac8_4_town_ownership_reload.gd
```

Execution captured stdout/stderr using Python `subprocess.run` with a 120-second timeout per process. Engine: Godot 4.7.2 stable Steam. Timeout, absent PASS, nonzero exit or ERROR fails the gate.

## Runtime verification

GodotIQ play and verify_project_runs passed. The production launcher used a separate repository path, `user://ac8-4-verification-20260920.json`; the normal active save was not replaced. Seed: `ac8-town-runtime`, world version 1.

- All seven towns resolved to Goblin: `(-8,2)`, `(-8,8)`, `(-5,4)`, `(-4,-4)`, `(-2,8)`, `(1,0)`, `(1,4)`.
- State inspection confirmed the production session was applied. Initial player `(-8,0)`, boss `(8,0)`, move count 0.
- Controller `request_move((-8,1))` accepted; player became `(-8,1)`, move count 1.
- Stopped/restarted the game and invoked production Continue using the same disposable repository. Continue succeeded; player `(-8,1)`, boss `(8,0)`, move count 1, all seven ownership results and the serialized-plan fingerprint were identical.
- Debug consoles after movement and after restart were empty. Game stopped after QA. No visual changes required screenshots.

[Runtime tool output](runtime.json) records start, ownership snapshots, movement, Continue and the final console check. The fingerprint is SHA-256 of hex-encoded canonical bytes, used consistently before/after; automated tests additionally compare bytes directly.

## Static checks and review

Per-script GodotIQ validation/check_errors completed. Production files have zero convention issues. Project baseline: 0 validation errors, 31 warnings, 5 informational findings; final: 0 errors, 33 warnings, 5 informational findings. The two added warnings are `class_name_missing` on standalone SceneTree test runners, consistent with existing runner style. Final project parser check: 209 scripts, 0 errors. Scoped runtime-model signal inspection found no orphan/missing signals.

Independent read-only review approved both the pure-rule and runtime/reload slices for specification compliance and code quality, with no blocking findings.

The local main branch was synchronized with origin (already contained origin), then the task branch was fast-forwarded to the required local AC8.3 commits. Unrelated pre-existing edits/untracked documents were stashed for the switch and restored afterward. The parent AC8 plan and MVP were already uncommitted user documents; their targeted ownership-status updates remain unstaged to avoid committing unrelated planning changes.

## Acceptance limits

Only the parent plan's AC8.4 ownership prerequisite passes. The broader MVP AC8.4 checkbox remains unchecked: filtered offers belong to AC8.5/AC8.6. Actual habitat-enabled explicit ownership and missing-owner validation belong to AC9 after its content prerequisite. Unknown world versions already fail closed here. AC8.5–AC8.8 are not accepted by this record.
