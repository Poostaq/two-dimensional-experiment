# AC1.2 Manual Runtime Check

**Date:** 2026-07-22  
**Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`  
**Implementation Spec:** `Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md`  
**Acceptance Criterion:** AC1.2 - Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID  
**Scene:** `res://Scenes/game_world.tscn`  
**Tester:** Codex  
**Godot:** Godot 4.7.1 stable Steam (`a13da4feb`)  

| Check | Expected | Observed | Result |
|---|---|---|---|
| Start scene with default Run ID. | Runtime map creates 25 encounter entries. | GodotIQ runtime exec returned `default_count=25`. | PASS |
| Inspect start coordinate. | `Vector2i(0, 0)` is Safe. | GodotIQ runtime exec returned `start=safe`. | PASS |
| Inspect boss coordinate. | `Vector2i(4, 4)` is Boss. | GodotIQ runtime exec returned `boss=boss`. | PASS |
| Set Run ID to `AC1.2-A` twice. | Safe/Combat/Boss layout is identical both times. | GodotIQ runtime exec returned `same_fixture_matches=true`. | PASS |
| Set Run ID to `AC1.2-B`. | Fixed fixture layout differs from `AC1.2-A` by at least one non-boss tile. | GodotIQ runtime exec returned `differing_non_boss=12`. | PASS |
| Move on the map after encounters are generated. | AC1.1 movement still works and move count increments for valid moves. | `test_ac1_1_runtime_step_counts.gd` passed in `automated-test.log`. | PASS |
| Check debug console. | No parser or runtime errors. | GodotIQ debug-console read returned `runtime_errors_total=0`, `script_errors_total=0`. | PASS |

**Runtime inspection result:** `scene=GameWorld default_count=25 start=safe boss=boss same_fixture_matches=true differing_non_boss=12`

**Overall Result:** PASS
