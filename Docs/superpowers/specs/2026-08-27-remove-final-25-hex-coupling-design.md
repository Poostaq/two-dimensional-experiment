# Remove Final 25-Hex Runtime Coupling Design

**Status:** Approved cleanup boundary; awaiting written-spec review

**Date:** 2026-08-27

## Purpose

Complete the post-cutover architecture cleanup by removing the retired 25-hex map model from executable code. Historical specifications, plans, evidence, and compatibility records remain intact and may continue to describe the former 25-hex version.

This design follows the Stage 6 cleanup recorded in `Docs/superpowers/specs/2026-08-27-stage6-legacy-world-runtime-cleanup-design.md`. Stage 6 removed the old production scenes and controller but retained `HexMapModel` because current systems still borrowed its encounter constants and neighbor ordering. This follow-up moves those shared contracts to Radius-8-owned authorities and then deletes the remaining 5x5 implementation.

## Architecture boundary

The retired component is:

- `Scripts/Map/hex_map_model.gd` and its `.uid` sidecar;
- `Tests/Map/test_hex_map_model.gd` and its `.uid` sidecar;
- any orphan UID sidecar whose corresponding retired test script no longer exists, including `Tests/Map/test_world_turn_counter.gd.uid` when present on the task branch.

The model is not a valid shared abstraction. It owns `MAP_WIDTH = 5`, `MAP_HEIGHT = 5`, the 25-cell coordinate set, old encounter generation, old start and boss corners, and legacy pursuit helpers. Current code uses only two small pieces from it: neighbor ordering and encounter identifiers.

## Replacement ownership

### Hex geometry

`HexWorldGeometry` becomes the sole owner of axial neighbor ordering. It already defines `NEIGHBOR_OFFSETS` and the Radius-8 geometry operations. `WorldRuntimeModel` must use `HexWorldGeometry.NEIGHBOR_OFFSETS` for deterministic pursuit tie-breaking.

### Encounter identifiers

Create `Scripts/WorldMap/world_encounter_type.gd` with class name `WorldEncounterType`. It owns the canonical string identifiers used across the generated world and tactical transition boundary:

- `NONE := ""`
- `SAFE := "safe"`
- `COMBAT := "combat"`
- `BOSS := "boss"`

The encounter overlay, battle arena, reward catalog, runtime model, and current integration tests use this authority instead of `HexMapModel`. The class contains identifiers only; generation rules and encounter state remain owned by the world plan and runtime model.

## Preserved compatibility behavior

Legacy-save recognition is deliberately retained in:

- `Scripts/Save/world_save_codec_v1.gd`;
- `Scripts/Save/world_run_save_codec_v2.gd`;
- `Tests/Fixtures/WorldMap/SaveV1/legacy-25-cell.json`;
- save and repository tests that expect `LEGACY_WORLD_SAVE_UNSUPPORTED`.

These paths prevent obsolete saves from being misinterpreted or mutated. They do not make the old map playable and therefore remain part of the current production safety contract.

`Tests/Run/test_world_cutover_entry.gd` is also retained because it asserts that deleted legacy runtime entry points stay absent.

## Documentation policy

No historical document or evidence artifact is deleted merely for mentioning 25 hexes, a 5x5 board, old coordinates, or the previous UI. Documentation may describe past architecture when its historical status is clear. Executable code, scenes, active project settings, and current tests must not depend on the retired map or UI.

## Implementation sequence

1. Add focused tests for the new encounter-type authority and migrate current tests away from `HexMapModel`.
2. Replace production neighbor-offset and encounter-identifier references with the new authorities.
3. Run parser and focused behavior checks before deletion.
4. Delete the 5x5 model, its direct test, and orphan sidecars.
5. Search executable paths for remaining 25-hex and `HexMapModel` references, classifying save-rejection references as intentional.
6. Run the full current world, battle, encounter, save, launcher, and cutover verification gates.

## Acceptance criteria

1. No executable scene or production script references `HexMapModel`.
2. `Scripts/Map/hex_map_model.gd` and its direct 25-cell test no longer exist.
3. `HexWorldGeometry` is the only runtime owner of axial neighbor ordering.
4. Current encounter and battle code obtains canonical encounter identifiers from `WorldEncounterType`.
5. Radius-8 movement, pursuit tie-breaking, encounters, battle entry, rewards, and production startup retain their verified behavior.
6. Legacy 25-cell saves still fail atomically with `LEGACY_WORLD_SAVE_UNSUPPORTED`.
7. The cutover-entry test still proves that the retired runtime and UI paths are absent.
8. Historical documentation and evidence remain available.
9. Project validation, parser checks, and the signal audit introduce no cleanup-caused errors or orphan signals.

## Exclusions

- No boss-AI redesign or change to the current move-30 pursuit contract.
- No generator, world-plan, save-schema, UI-layout, battle-rule, or reward-content redesign.
- No deletion of historical documents or evidence.
- No removal of explicit legacy-save rejection behavior.

## Rollback

Before integration, abandon or revert the task branch. After integration, revert the cleanup commit. No save data or historical evidence is rewritten by this change.
