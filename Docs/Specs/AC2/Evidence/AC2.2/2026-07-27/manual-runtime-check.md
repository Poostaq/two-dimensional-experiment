# AC2.2 Manual Runtime Check

| Field | Value |
|---|---|
| Date | 2026-07-27 |
| Godot | 4.7.1.stable.steam.a13da4feb |
| Scene | `res://Scenes/game_world.tscn` and focused `res://Scenes/battle_arena.tscn` |
| Branch | `feature/ac2-2-speed-order` |
| Implementation commit | `ec2e00e` |
| Run ID | Existing deterministic default |
| Runtime health | PASS — startup succeeded; debug console contained 0 runtime and 0 script errors |

| Input/check | Expected | Observed | Result |
|---|---|---|---|
| Open Combat overlay and click `Enter Battle` through real pointer input | Combat arena opens | `Combat Battle` arena opened | PASS |
| Inspect all twelve populated slots | Names and speeds are visible and unclipped | All player/enemy names and speeds mapped inside 140×80 slots | PASS |
| Inspect semantic formation | Player `[3,0] [4,1] [5,2]`; enemy `[0,3] [1,4] [2,5]` | UI map and visual tour matched the approved diagram | PASS |
| Inspect initial turn | Round 1, highest-speed stable head highlighted | `Player Back 2 | Speed 9`; player slot 4 highlighted | PASS |
| Click `Advance Turn (Debug)` once | Advance exactly one queue entry | Current label changed to `Enemy Back 2 | Speed 9` | PASS |
| Advance through all twelve entries | Speeds descend; ties use player `0→5`, then enemy `0→5` | Exact automated/runtime order: `player_4, enemy_4, player_0, enemy_0, enemy_1, player_1, player_2, enemy_2, player_3, enemy_3, player_5, enemy_5` | PASS |
| Inspect thirteenth state | Wrap to queue head in Round 2 | `Round 2`; `Player Back 2 | Speed 9` | PASS |
| Configure an empty typed unit array | Exact no-active-unit contract | `No active units`, advance disabled, round reset to 1, zero current highlights verified by focused test | PASS |
| Click `Exit Battle (Debug)` | Arena closes without map mutation | Active battle false; player `(0,0)`; move count `0` | PASS |
| Open Boss overlay and click `Enter Battle` | Same AC2.2 initialization under Boss context | `Boss Battle`, Round 1, `Player Back 2 | Speed 9` | PASS |
| Inspect debug controls | Readable and valid pointer targets | Both controls visible at 48px height; no undersized-target warning | PASS |

## Visual QA

GodotIQ tour showed the complete dark full-screen arena with opposing two-column formations, populated names/speeds, turn status, and both debug controls. The corrected player front column is nearest the enemy; the enemy front column is nearest the player. A second tour after the correction confirmed the final layout.

## Overall

PASS
