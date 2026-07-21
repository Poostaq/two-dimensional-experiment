# AC1.1 Manual Runtime Check

**Date:** 2026-07-21
**Tester:** Codex
**Godot Version:** 4.7.1.stable.steam.a13da4feb
**Scene Run Path:** `res://Scenes/game_world.tscn` through GodotIQ `run(action="play", scene="main")`
**Spec:** `Docs/Specs/AC1/AC1.1_MAP_NAVIGATION_IMPLEMENTATION_SPEC.md`

## Results

| Step | Expected | Observed | Result |
|---|---|---|---|
| Start `res://Scenes/game_world.tscn`. | Main scene launches without script/runtime errors. | GodotIQ launch returned `success: true`, `runtime_attached: true`; debug console had 0 runtime errors and 0 script errors. | PASS |
| Confirm exactly 25 visible hexes. | Runtime map contains 25 hex tiles. | Runtime exec returned `tile_count=25`; screenshot shows a 5x5 hex map. | PASS |
| Confirm the player marker starts in one corner. | Player starts at `(0, 0)`. | State inspect returned `player_coord: (0, 0)` and player marker at `[0.0, 0.0]`. | PASS |
| Confirm the boss objective marker appears in the opposite corner. | Boss objective is `(4, 4)`. | State inspect returned `boss_coord: (4, 4)` and boss marker at `[426.5, 246.24]`; screenshot shows boss marker in opposite corner. | PASS |
| Move through a valid adjacent hex using real input. | Input moves player to an adjacent hex and increments move count. | GodotIQ input delivered `map_move_se`; state inspect returned `player_coord: (0, 1)`, `move_count: 1`. | PASS |
| Attempt an invalid edge move. | Invalid move does not change player coordinate or move count. | From `(0, 1)`, GodotIQ input delivered `map_move_w`; state remained `player_coord: (0, 1)`, `move_count: 1`. | PASS |
| Confirm player can continue toward the boss objective through valid adjacency. | A valid adjacent path exists from start to boss. | `test_map_controller_runtime.gd` moved through an adjacent path to `(4, 4)` and passed. | PASS |

## Artifacts

- Automated log: `Docs/Specs/AC1/Evidence/AC1.1/2026-07-21/automated-test.log`
- Runtime screenshot: `Docs/Specs/AC1/Evidence/AC1.1/2026-07-21/runtime-screenshot.png`
- Implementation link: `Docs/Specs/AC1/Evidence/AC1.1/2026-07-21/implementation-link.txt`

**Overall Result:** PASS
