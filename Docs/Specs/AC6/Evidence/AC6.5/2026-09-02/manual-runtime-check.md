# AC6.5 Brakka Rustbanner verification record

Date: 2026-09-02  
Branch: `feat/ac6-5-brakka`  
Godot: `4.7.2.stable.steam.ed1daf0bf`  
Viewport: `1152x648`  
Runtime seed contract: `ac6-5-runtime` (explicit-seed preservation is covered by the launcher runner)

## Implementation

Commits through the verification candidate:

- `2162bf5` closest active opponent
- `bca2260` action-start reaction dispatch
- `e414dc9` Brakka catalog definition
- `d47ee26` arena resolution and typed authored logs
- `de42dd9` selected-commander run start and persistence
- `6df1358` launcher commander payload
- `ba38503` combined New Run commander screen
- `f3f2498` hardened AC6.5 behavior matrix

## Automated evidence

- `test_ac6_5_brakka.gd` passed twice at `70/70`; the complete outputs are byte-identical in `green/ac6-5-run-1.log` and `green/ac6-5-run-2.log`.
- All 18 `Tests/Battle/test_*.gd` runners exited `0`. Individual logs are stored under `green/`.
- Retained counts: AC6.1 `40/40`, AC6.2 `113/113`, AC6.3 `116/116`, AC6.4 `93/93`, active-turn lock `5/5`.
- `test_world_run_start_service.gd`, Save V2, AC3.1 roster `14/14`, AC3.3 formation `41/41`, launcher, UI scene, and production cutover all exited `0`; logs are stored under `green/`.
- Save V2 remains schema version `2`; Brakka's stable ID round-trips at formation slot `1`, and repeated encoding is byte-stable.

## GodotIQ gate

- Project validation: 134 scripts and 12 scenes, `0` errors, 12 warnings, 6 info findings.
- Project parser check: 134 scripts, `0` errors.
- Signal audit: `0` orphan signals. Reported missing names are engine UI signals emitted by tests, not undefined project signals.
- `verify_project_runs(scene="main", check_scope="scene")`: PASS with zero captured runtime or script errors.

## Runtime and UI checks

1. Production main screen opened and `Start New Run` entered the combined setup screen: PASS.
2. The setup screen visibly contains the placeholder portrait, Brakka name/title, disabled adjacent arrows, four skill squares, optional seed, Back, and Begin: PASS.
3. ST/PB/BN/BH are focusable and carry catalog-authored tooltip text; BH has a distinct gold passive style: PASS by live focus styling plus `test_world_run_start_scene.gd`. Native tooltip screenshot automation timed out, so tooltip text is not claimed from a captured hover image.
4. Explicit and blank seed flow, Begin payload, overwrite preservation/cancellation, and invalid commander rejection before writes: PASS in `test_world_production_launcher.gd`.
5. Production run construction places `brakka_rustbanner` at `formation[1]` while retaining slots `0` and `2`: PASS in `test_world_run_start_service.gd` and the cutover runner.
6. Brakka's initial action applies Advantage to the deterministic closest active enemy and writes `Brakka Rustbanner's Banner Holder applied Advantage to Enemy Back 2.`: PASS in the instantiated production `battle_arena.tscn` focused runner.
7. Same-round replay, stale activity, stale distance, and no-enemy behavior are guarded and do not redirect: PASS in the 70/70 focused runner.
8. Default Attack and Default Swap preserve Advantage; an eligible Active consumes it: PASS in the focused runner.
9. Save/reload identity, four-skill order, fresh conversion, and ordinary move/swap identity are retained: PASS in Save V2, roster, and formation runners.

## Visual evidence

- `screenshots/new-run.png` — final production New Run surface after the visual-fit loop.

Observed layout: portrait and disabled arrows occupy the left column; Brakka details and four skill squares occupy the right column; seed is below both columns; Back and Begin are at the bottom. After tightening the content and portrait minimum heights, the panel fits the 1152x648 viewport without clipping.

## Scope boundary

AC6.5 is evidenced. AC6.6 Cache/preparation behavior and the AC6.7 full end-battle/start-next-battle integration walkthrough remain incomplete. The aggregate AC6 milestone is not complete.
