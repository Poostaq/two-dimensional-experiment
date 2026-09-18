# Goblin race encounters verification

Verdict: PASS. Godot 4.7.2 Steam on Windows, 2026-09-18.

## Delivered behavior

- Default party uses Scrapshield Bruiser, Wirefang Skirmisher, and Snarewright with authored stats and three skills each. Existing commander selection still replaces the middle starter. Saved starter IDs remain stable.
- Exactly two enemies per encounter: Ranger/Crossbowman, Siege Smith/Thunderbreaker, or Star Archer/Moon Sage. All have three authored skills. The AI uses legal setup/payoff actions, then Default Attack when skills cannot act.
- Standalone `BattleArena.debug_encounter_index`: 0 human, 1 dwarf, 2 elf, wrapping modulo three. World selection is `posmod(coord.x + 2 * coord.y, 3)`, stable across reloads and repeated entry. Both enemy IDs and slots remain `enemy_0`/0 and `enemy_4`/4.
- Armor stripping, actual same-round Armor loss, Armor bypass, movement bonuses, and conditional status bonuses use the shared transaction planner. Preview is nonmutating. Armor loss displays negative feedback.
- Save V2 now writes `starter_roster_version=1`. Missing/zero marks legacy health: cap player_1 and player_2 to 14 and 16 HP respectively, preserving lower HP; reject legacy values above the former 20 HP maximum. Modern values are not silently migrated. Formation and preparation identity remain unchanged.

## Automated evidence

[Logs and final battle summary](GoblinEncounters20260918/final-battle-summary.json) record **31/31 Battle runners**, exit 0, no script errors. This includes the catalog, shared enemy mechanics (31 assertions), and arena integration tests. Integration proves all three actual enemy opener/payoff commits, matching target selection, automatic enemy scheduling, manual explicit fixtures, player authority, fallback attacks, and deterministic selection.

The 18 additional Run/Save/WorldMap/UI runners passed with no script errors. After migration, six affected runners passed again: new starter migration, Save V1/V2/store, run-start service, and AC6.7 integration (104 assertions). Their logs are the `post-migration-*` files in the same directory. Negative-definition tests intentionally emit existing validation diagnostics; every runner exits successfully.

Reproduction (PowerShell; use a pipe to wait for the Windows executable):

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/Battle/test_goblin_encounter_integration.gd 2>&1 | Out-String
```

Repeat with `test_debug_encounter_catalog.gd`, `test_enemy_skill_rules.gd`, and `res://Tests/Save/test_goblin_starter_save_migration.gd`. The full Battle run used hidden `Start-Process -Wait -PassThru`, inspecting exit codes and per-runner log files.

## Runtime and visual evidence

GodotIQ play/verify/console checks passed for `Scenes/battle_arena.tscn` and the main launcher. The arena screenshot showed three named goblins, two named humans, empty unused slots, correct health, readable skills, and the Human Marksmen encounter heading.

Mouse input completed three player Default Attacks and allowed both automatic enemy turns. Observed round 2, battle revision 5, player control returned to Wirefang, Ranger at 7/18 HP, and Scrapshield at 8/20 HP after the human pair's focused attack. No runtime or script errors were captured. Screenshot feedback marked damaged Scrapshield red and attacking Crossbowman green. Tool UI taps initially used logical coordinates; scaling clicks to the 1920x1080 viewport resolved input delivery.

Project validation: 181 scripts, zero errors, 27 warnings and six informational findings, matching the baseline warning totals. Project parser checks: zero errors. Arena signal map: no orphan or missing signals.

## Review and workspace

Independent review found the negative Armor highlight bug; a failing regression reproduced it and passed after the fix. Historical placeholder units now live only in explicit test fixtures; existing combat assertions were retained. AC6.7 now waits for the intended player actor instead of assuming uninterrupted player initiative.

The pre-existing debug-drawer scene edit was restored byte-for-byte (Git blob `4e2a354f585cffd59895d6ec49c299a618b48d00`) and is excluded from this change. No new unit art was authored; existing unit-card presentation renders the playable kits.
