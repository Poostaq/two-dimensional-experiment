# AC9.2 Runtime Persistence Verification

Date: 2026-09-27

Environment: open Godot editor, normal Play/game context through GodotIQ.

## Traceability

| AC9.2 obligation | Automated coverage | Runtime evidence | Status |
|---|---|---|---|
| Deterministic allied-clan selection | `Tests/Run/test_ac9_2_allied_clan_selection.gd` | Goblin + `ac9-vector-1` produced `[orc, werewolf]` on repeated runs | Pass |
| V7 round-trip restores the exact coalition | `Tests/Save/test_world_run_save_codec_v7.gd` | V7 encode/decode restored `[orc, werewolf]` | Pass |
| Malformed V7 identities are rejected | `Tests/Save/test_world_run_save_codec_v7.gd` | Missing, reversed, duplicate, unknown, and noncanonical ally arrays were rejected | Pass |
| V6 remains readable without inventing allies | `Tests/Save/test_world_run_save_codec_v7.gd` | V7 decode chain restored V6 selection with a null coalition | Pass |
| Runtime autosave preserves V7 metadata | `Tests/WorldMap/test_ac9_2_runtime_save_coordinator.gd` | A real runtime move autosaved and reloaded with selection and coalition intact; move count was 1 | Pass |
| Legacy sessions retain their writer contract | `Tests/WorldMap/test_world_runtime_save_coordinator.gd` and `Tests/WorldMap/test_ac9_2_runtime_save_coordinator.gd` | Context-aware coordinator produced writer versions `[5, 6, 7]` for no metadata, selection-only, and selection+coalition | Pass |
| Continue restores rather than rerolls | V7 codec and runtime coordinator tests | Repository reload returned the persisted coalition; no selector call occurs in decode or autosave | Pass |

## Structured checks

- Project parser check: 275 scripts, zero errors.
- Runtime debug console after new run, autosave, reload, and V7/V6 checks: zero errors.
- Runtime writer selection: V5 without identity metadata, V6 with selection only, V7 with selection and coalition.

This is local Godot runtime evidence, not a CI record. CI should execute the three focused test scripts above plus the existing runtime-save coordinator regression suite.
