# AC1.5 Manual Runtime Check

**Execution date:** 2026-07-26
**Scene:** `res://Scenes/game_world.tscn`
**Godot:** 4.7.1.stable.steam.a13da4feb
**Input:** GodotIQ real pointer clicks against the running game viewport
**Route:** Alternate between axial coordinates `(0,0)` and `(0,1)`, closing each ordinary Encounter overlay before the next move
**Overall result:** PASS

## Observations

| Check | Expected | Observed | Result |
|---|---|---|---|
| Startup | Move 0, player `(0,0)`, boss `(4,4)`, Sudden Death inactive | `move_count=0`, `player_coord=(0,0)`, `boss_coord=(4,4)`, `_sudden_death_active=false` | PASS |
| Moves 1–14 | Boss remains at `(4,4)` | Boss remained at `(4,4)` while ordinary overlays were closed between accepted pointer moves | PASS |
| Move 15 | Sudden Death activates without moving boss | `move_count=15`, player `(0,1)`, boss `(4,4)`, `_sudden_death_active=true` | PASS |
| Move 16 | Boss takes first deterministic pursuit step | `move_count=16`, player `(0,0)`, boss `(4,3)`, `_sudden_death_active=true` | PASS |
| Later accepted moves | Exactly one boss step follows each player move | Continued alternating pointer moves advanced pursuit from `(4,3)` toward the player; rejected advancement was prevented by each active overlay until Close | PASS |
| Engagement | Boss reaching player opens one Boss Encounter overlay | On move 23, player and boss both reached `(0,1)`; UI map showed `EncounterTypeLabel` text `Boss` and one `Close (Debug)` button | PASS |
| Deterministic replay | Same route reproduces the same first pursuit step | After restarting and replaying the alternating route, move 16 again produced player `(0,0)` and boss `(4,3)` | PASS |
| Run reset | Fresh run clears pursuit state | Restart produced move 0, player `(0,0)`, boss `(4,4)`, and `_sudden_death_active=false`; the exact `set_run_id()` reset contract also passes in `test_set_run_id_resets_sudden_death` | PASS |
| Runtime health | No script/runtime errors | GodotIQ startup verification returned PASS with zero debug entries | PASS |

## Traceability

- Threshold boundary: `test_moves_before_threshold_keep_boss_idle`, `test_move_fifteen_activates_without_pursuit`, `test_move_sixteen_starts_one_step_pursuit`
- Continued pursuit: `test_each_later_accepted_move_advances_once`, `test_rejected_and_blocked_moves_do_not_advance_pursuit`
- Engagement: `test_player_entering_boss_coord_triggers_boss_encounter`, `test_boss_reaching_player_triggers_boss_encounter`
- Runtime Boss identity: `test_runtime_boss_identity_moves_and_vacated_origin_is_safe`
- Reset: `test_set_run_id_resets_sudden_death`
