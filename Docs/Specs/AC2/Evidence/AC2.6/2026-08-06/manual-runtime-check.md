# Pre-3.1 UI Hardening Manual Runtime Check

- Verification date: 2026-08-06
- Tested implementation SHA: `3617001fa11ce905679b590d56b63ce9ae265a8a`
- Viewport: Godot main-project game viewport, 1152 x 648 capture basis; `game_world.tscn` at startup and `battle_arena.tscn` for battle interaction evidence.
- Debugger: final GodotIQ read reported 0 runtime errors, 0 script errors, and 0 total entries.
- Visual structure: `ui_map` observed `TurnCounterLabel` visible at top-left rect `[16, 16, 116, 44]`; tour rendered the complete map with the badge at the viewport top-left.

| ID | Result | Live observation |
|---|---|---|
| B1 | PASS | Initial active unit `player_4`; inspector remained `player_4` and displayed 4 skills without a slot click. |
| B2 | PASS | A real click on a non-current formation slot left the actual current/inspected unit and displayed skills unchanged. |
| B3 | PASS | Turn advance selected `enemy_4`; inspector showed `enemy_4` with 1 skill. |
| B4 | PASS | The following turn synchronized to `player_0`; inspector showed `player_0` with 2 skills. |
| B5 | PASS | Removing current `player_0` rebuilt the queue from 12 to 11 entries and synchronized inspection to `player_4`, still showing 4 skills. |
| B6 | PASS | Live no-current state observed queue size 0, current `NONE`, empty inspected ID, prompt visible, inspector body hidden, and 0 skill rows; the terminal branch also passed its focused automated assertion. |
| M1 | PASS | Initial map state was move count 0 with `Turns: 0`; `ui_map` measured the label in the top-left rect `[16,16,116,44]`. |
| M2 | PASS | A real viewport click on adjacent coordinate `(1,0)` was accepted; move count became 1, label became `Turns: 1`, and the encounter overlay opened. |
| M3 | PASS | A real non-adjacent tile click was rejected; coordinate, move count, and counter text remained unchanged. |
| M4 | PASS | Calling the supported `set_run_id` reset path restored move count 0 and `Turns: 0`. |

## Interaction and root-cause method

Player-facing map cases used GodotIQ `ui_map` to locate rendered controls and GodotIQ input to send actual viewport clicks through the normal `gui_input`/tile-selection pipeline; battle slot checks likewise used mouse input rather than directly invoking production mutation methods. State was read after each interaction through the live runtime tree. The only direct method call was `set_run_id` for M4 because run reset is the public reset boundary under test.

The first CLI capture attempt appeared to hang specifically on AC2.6. Root cause was the Windows GUI-subsystem Godot executable plus sequential redirected-stream reading: expected rejection-path `push_error` diagnostics filled stderr while stdout was read first. The rerun wrapper consumed stdout and stderr concurrently with `ReadToEndAsync`, eliminating the transport deadlock. All 23 runners then exited 0 with PASS signatures and no `FAILED:` markers; the rejection diagnostics remained expected test stimuli.

## Verdict

All six battle scenarios and four map scenarios passed against the implementation SHA above. Runtime startup, debugger inspection, `ui_map`, and the visual tour added fresh readiness evidence; detailed scenario values are the preserved live interaction observations from the same tested implementation commit.
