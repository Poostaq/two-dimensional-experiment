# Two-Enemy Debug Battle Fixture Design

**Status:** Approved

## Goal

Shorten default runtime battles used for manual verification by reducing the debug enemy team from six active enemies to two, while preserving the six-slot battle layout required by AC2.1.

## Scope

The default fixture created by `BattleArena._create_debug_units()` will retain:

- `enemy_0`, “Enemy Front 1,” in enemy slot 0.
- `enemy_4`, “Enemy Back 2,” in enemy slot 4.

The fixture will remove `enemy_1`, `enemy_2`, `enemy_3`, and `enemy_5`. Their four slots remain visible and render as unoccupied.

Explicit unit arrays supplied by focused tests are unchanged. Enemy slot count, player slot count, targeting rules, victory rules, and production roster behavior are unchanged.

## Rationale

`enemy_0` preserves a front-row enemy with Savage Blow and Blood Scent. `enemy_4` preserves a back-row enemy with Shadow Lunge and its positional requirement. The pair keeps representative front/back and skill behavior while making manual reward and recruitment verification substantially faster.

## Behavior

When a default battle arena becomes ready, its debug fixture contains the existing six player fixtures and exactly two enemy fixtures. The turn queue includes only those active units. Enemy slots 1, 2, 3, and 5 display as unoccupied.

`MapController` continues replacing the six debug player fixtures with the current `RunRoster`, while carrying the two battle-owned enemies into the configured battle.

## Verification

Update the AC2.1 battle-arena runner before changing production code. It must verify:

- Both formations still expose exactly six slots.
- The default enemy team contains exactly `enemy_0` and `enemy_4`.
- Their authoritative slots are 0 and 4.
- Four enemy slots render as unoccupied.
- The default player-side fixture and explicitly configured test battles retain their existing contracts.

Run the AC2.1, AC3.1 integration, battle outcome, reward selection, skill, and full test corpus regressions. Validate and compile `battle_arena.gd` with GodotIQ, then run the project readiness gate. No scene edit or acceptance-criterion status change is part of this fixture adjustment.
