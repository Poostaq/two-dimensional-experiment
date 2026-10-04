# AC9.6 Spawn and Habitat Display Correction

**Status:** Approved on 2026-10-04

## Purpose

Correct the current AC9 habitat-world contract so the player begins on the visible western (left) edge and the enemy begins on the visible eastern (right) edge. The world HUD must identify the race that owns the occupied habitat instead of displaying the structural habitat identifier.

The user explicitly accepts deleting existing local saves and updating the current V2/V3 canonical contracts. No migration path or new generator version is required.

## Spawn Contract

`HexWorldGeneratorV2` remains the source of the habitat topology used by V3. It must assign:

- player start: visual west/left extremum, canonically `Vector2i(-8, 0)` on the radius-eight board;
- enemy start: visual east/right extremum, canonically `Vector2i(8, 0)`;
- the main habitat anchor to the player start;
- the enemy radius-two footprint to the enemy start;
- the safe encounter override to the player start and the boss encounter override to the enemy start.

`HexWorldGeneratorV3` continues to promote the corrected V2 non-road topology and add the existing nine internal allied-habitat roads. Production remains on generator version 3.

Because the change intentionally replaces the current V2/V3 contract, canonical V2 and V3 fixtures, hashes, coordinate assertions, topology expectations, and documentation must be regenerated or updated together. V1 remains unchanged.

## Save Handling

No compatibility migration will reinterpret an old V2 or V3 run. Before final runtime verification, delete the existing local single-slot save through the repository's established deletion path when available. If direct filesystem cleanup is required, resolve and verify the exact file inside the Godot application user-data directory before deleting only that file.

After deletion, the launcher must report that no saved run is available. A newly created run must use the corrected V3 spawn orientation.

## Habitat Race Presentation

`WorldHabitatRules` remains the authority for resolved habitat presentation. For generated V2/V3 habitats it must set `display_name` from the habitat's validated `clan_id`, not from structural IDs such as `main`, `ally_0`, or `enemy`.

Formatting converts the stable race identifier to a capitalized player-facing name:

- `goblin` becomes `Goblin`;
- `orc` becomes `Orc`;
- `werewolf` becomes `Werewolf`;
- `lizardman` becomes `Lizardman`;
- `harpy` becomes `Harpy`;
- underscore-separated future IDs become title-cased words.

The HUD retains its current label shape: `Habitat: <Race>`. Invalid or unavailable habitat data remains `Habitat: Unavailable`. V1 continues to resolve as `Goblin` through its existing compatibility rule.

## Error Handling

The generator must continue to fail atomically through `WorldGenerationError`; it must never publish a partially reversed topology. V2/V3 codec validation must reject plans whose spawn coordinates, habitat anchors, encounter overrides, or ownership no longer match the corrected contract.

Habitat presentation must reject empty or malformed clan IDs through the existing `invalid_habitat_record` result rather than rendering a structural habitat name.

## Verification

Use test-driven development and first establish failures for the old orientation and structural habitat label. Verification must cover:

- exact V2 and V3 player-left/enemy-right coordinates;
- main and enemy habitat ownership at their corrected anchors;
- player-start safe and enemy-start boss encounter overrides;
- V3 preservation of nine canonical internal roads;
- clean/interleaved deterministic generation and updated golden V2/V3 fixtures;
- codec round trips and rejection of the former orientation;
- production start-service output using V3 with the corrected coordinates;
- `WorldHabitatRules` returning the capitalized owning race for main, allied, and enemy habitats;
- HUD rendering `Habitat: Goblin` (and another non-Goblin race) plus the unavailable fallback;
- deleted local save followed by a fresh Play-mode run;
- project validation, parser checks, signal-orphan scan, and a clean debug console.

## Scope Boundaries

This correction does not change road connectivity, habitat sizes, town counts, movement rules, minimap styling, or commander selection. It does not introduce a save migration or a new generator version.
