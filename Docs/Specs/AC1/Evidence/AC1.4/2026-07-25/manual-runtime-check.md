# AC1.4 Manual Runtime Check

Date: 2026-07-25
Godot: 4.7.1.stable.steam.a13da4feb
Scene: res://Scenes/game_world.tscn
Branch: ac1.4-encounter-overlay
Implementation commit under test: 6729a9d2a53339b1497b87aa14278dcea750680f

## Runtime Startup

Tool path:

- GodotIQ `run(action="play", scene="res://Scenes/game_world.tscn")`
- GodotIQ `read_debug_console(include_runtime=true, include_script=true)`
- GodotIQ `state_inspect("/root/GameWorld", ["player_coord", "move_count"])`
- GodotIQ `ui_map(root="", max_depth=8)`

Observed:

- Game started successfully with runtime attached.
- Debug console entries: 0 runtime errors, 0 script errors.
- Initial `player_coord`: `(0, 0)`.
- Initial `move_count`: `0`.
- Initial UI: `UI` CanvasLayer present; no Encounter overlay controls visible.

Result: PASS.

## Real Input Path

Input used GodotIQ `input(click_at=...)` against the running game viewport, followed by `state_inspect`, `ui_map`, and `read_debug_console`.

| Step | Input / Check | Expected | Observed | Result |
|---|---|---|---|---|
| Startup | Start game | No overlay at initialization | UI CanvasLayer only; `player_coord=(0, 0)`, `move_count=0` | PASS |
| Safe entry | Click adjacent hex at viewport `[392, 216]` | Accepted move opens Safe Encounter overlay | `player_coord=(0, 1)`, `move_count=1`, `EncounterTypeLabel="Safe"`, `CloseDebugButton` visible | PASS |
| Input blocking | Click covered map at viewport `[520, 216]` while overlay is open | No map mutation | `player_coord=(0, 1)`, `move_count=1`, overlay remains visible | PASS |
| Debug close | Click `Close (Debug)` at viewport `[576, 358]` | Overlay closes; state preserved | UI returns to CanvasLayer only; `player_coord=(0, 1)`, `move_count=1` | PASS |
| Combat entry | Click adjacent hex at viewport `[432, 288]` | Accepted move opens Combat Encounter overlay | `player_coord=(0, 2)`, `move_count=2`, `EncounterTypeLabel="Combat"`, `CloseDebugButton` visible | PASS |
| Close/resume path | Close each overlay, then continue valid adjacent clicks | Navigation resumes only after Close; every accepted move opens one overlay | Path advanced through `(1, 2)`, `(2, 2)`, `(3, 2)`, `(4, 2)`, `(4, 3)` with one overlay per accepted entry | PASS |
| Boss entry | Click final boss hex at viewport `[796, 404]` | Accepted move opens Boss Encounter overlay | `player_coord=(4, 4)`, `move_count=8`, `EncounterTypeLabel="Boss"`, `CloseDebugButton` visible | PASS |
| Runtime health | Read debug console after path | No script/runtime errors | 0 runtime errors, 0 script errors | PASS |

## Deferred Close Regression

During evidence gathering, a real-input close/click sequence showed that removing the overlay immediately during a `Button.pressed` event could allow the same pointer event to reach map tiles underneath. The fix in `Scripts/Encounter/encounter_overlay.gd` now marks viewport input handled and defers `close_requested` emission until the current input frame ends.

Verification:

- `test_debug_close_preserves_state_and_restores_navigation` now asserts that `Close (Debug)` keeps the active encounter through the current frame and clears it on the next frame.
- Fresh focused run reported `AC1.4 encounter overlay tests: PASS (6/6)`.
- Repeated live close/click path advanced one move per intended click and reached Boss at `(4, 4)` with `move_count=8`.

Result: PASS.

