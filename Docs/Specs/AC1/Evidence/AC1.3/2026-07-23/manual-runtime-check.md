# AC1.3 Runtime Check

**Date:** 2026-07-23
**Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
**Implementation Spec:** `Docs/Specs/AC1/AC1.3_MOUSE_MAP_CONTROL_IMPLEMENTATION_SPEC.md`
**Scene:** `res://Scenes/game_world.tscn`
**Godot:** 4.7.1 stable Steam
**Execution:** Headless runtime scene with real `InputEventMouseButton` and `InputEventMouseMotion` events

| Check | Expected | Observed | Result |
|---|---|---|---|
| Click five successive adjacent tiles. | Each click advances exactly one hex. | Player advanced `(0,0)` → `(0,1)` → `(0,2)` → `(0,3)` → `(0,4)` → `(1,4)`. | PASS |
| Inspect move count after five valid clicks. | Count is `5`. | `move_count` was `5`. | PASS |
| Click two non-adjacent tiles. | Coordinate and count remain unchanged. | Player remained `(1,4)` with `move_count == 5`. | PASS |
| Click outside every tile polygon. | Coordinate and count remain unchanged. | AC1.3 off-map input check preserved both values. | PASS |
| Right-click an adjacent tile. | Coordinate and count remain unchanged. | AC1.3 right-button check preserved both values. | PASS |
| Send `map_move_se`. | Keyboard action does not move the player. | AC1.3 keyboard-disabled check preserved both values. | PASS |
| Move pointer into and out of a tile. | Hover appears without replacing tile state. | Hover emitted `[true, false]`, widened the outline, then restored its original width. | PASS |
| Continue with three adjacent clicks to boss coordinate. | Counting remains valid through eight moves. | Player reached `(4,4)` with `move_count == 8`. | PASS |

**Overall Result:** PASS
