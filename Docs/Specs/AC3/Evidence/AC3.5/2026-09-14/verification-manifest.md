# AC3.5 Post-Battle Recovery Verification

Date: 2026-09-14

Implementation revision tested: `de6d909`

Godot: `4.7.2.stable.steam.ed1daf0bf`

## Verdict

PASS WITH WARNINGS. Automated acceptance and regression coverage passed, and the production main scene launched with a clean runtime debug console. A complete two-battle player-input traversal was not completed in this session; its behavioral steps are covered by the focused world integration runner, while manual interaction remains a documented follow-up rather than fabricated evidence.

## Acceptance traceability

| AC3.5 behavior | Verification path | Result |
|---|---|---|
| Passed-out characters return after victory | `Tests/Run/test_ac3_5_post_battle_recovery.gd`; `Tests/WorldMap/test_ac3_5_recovery_integration.gd` | PASS |
| Passed-out characters start at 50% HP; odd maximum HP rounds upward | Recovery rule runner and next-battle integration assertions | PASS |
| Survivors start at full HP | Recovery rule runner and next-battle integration assertions | PASS |
| Recovery is victory-only and completion is idempotent | World integration runner | PASS |
| Recovery survives save/reload | World integration runner and Save V2 regression runner | PASS |
| Health follows character identity through roster/formation changes | AC3.1 and AC3.3 focused runners | PASS |
| Battle completion, rewards, battle entry, and production Goblins remain compatible | AC2.4, AC2.5, world battle entry, and AC6.7 focused runners | PASS |
| Harder-difficulty reduction | Deferred by design; no difficulty API/configuration exists in MVP | N/A |

## Automated test evidence

Executable:

`D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

Command pattern:

`<godot-executable> --headless --path . --script res://<runner>`

| Runner | Exit code |
|---|---:|
| `Tests/Run/test_ac3_5_post_battle_recovery.gd` | 0 |
| `Tests/WorldMap/test_ac3_5_recovery_integration.gd` | 0 |
| `Tests/Battle/test_ac2_4_battle_results.gd` | 0 |
| `Tests/Battle/test_ac2_5_reward_selection.gd` | 0 |
| `Tests/Run/test_ac3_1_run_roster.gd` | 0 |
| `Tests/Run/test_ac3_3_party_formation.gd` | 0 |
| `Tests/UI/test_ac3_3_party_management.gd` | 0 |
| `Tests/WorldMap/test_world_battle_entry.gd` | 0 |
| `Tests/WorldMap/test_ac6_7_goblin_integration.gd` | 0 |
| `Tests/Save/test_world_run_save_codec_v2.gd` | 0 |

The runners are silent on success and do not publish assertion totals, so no assertion count is claimed. All ten processes returned exit code 0.

## Structured project and runtime checks

- GodotIQ `validate(target="project", detail="brief")`: 153 scripts and 12 scenes checked; 0 errors, 27 warnings, 6 informational findings.
- GodotIQ `signal_map(scope="project", find="orphans", detail="brief")`: 30 signals defined, 96 emissions, 108 connections, 0 orphan signals. It also reported 17 built-in UI-signal emissions as missing definitions in test scripts; these are not orphan project signals.
- GodotIQ `run(action="play", scene="main")`: success; runtime attached to `res://Scenes/world_run_start.tscn`.
- GodotIQ `read_debug_console(...)`: 0 runtime errors, 0 script errors, 0 entries.
- GodotIQ `run(action="stop")`: stopped cleanly.

## Warning and limitation

GodotIQ `check_errors(scope="project")` and the preflight phase of `verify_project_runs(scene="main", check_scope="project")` reported four low-confidence, line-less `Script reload failed (error 22)` entries for:

- `Scripts/Run/run_character.gd`
- `Scripts/Run/run_roster.gd`
- `Scripts/WorldMap/world_runtime_controller.gd`
- `Scripts/WorldMap/world_runtime_model.gd`

This conflicts with the same revision's ten passing headless runners and successful production launch with an empty runtime/script-error console. The evidence therefore treats the entries as an editor reload/cache diagnostic requiring follow-up, not as proof of a runtime compilation failure.

GodotIQ exposed real pointer input and UI mapping, but producing a passed-out party member, winning, completing rewards, saving/reloading, navigating to another encounter, and verifying exact unit HP would require a long non-deterministic combat traversal. That full manual two-battle flow was not claimed. The deterministic integration runner supplies the binary next-battle and persistence evidence.
