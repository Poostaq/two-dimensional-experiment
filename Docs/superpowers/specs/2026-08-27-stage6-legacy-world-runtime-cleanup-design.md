# Stage 6 Legacy World Runtime Cleanup Design

**Status:** Approved

**Date:** 2026-08-27

## Purpose

Remove the frozen 25-cell production runtime after the radius-8 world production cutover. The cleanup must remove only the isolated legacy runtime and its legacy-only tests while preserving current production behavior, supported compatibility readers, migration fixtures, preview tooling, and historical evidence.

## Authority and scope

This cleanup follows `Docs/superpowers/specs/2026-08-26-world-production-cutover-stage5-design.md`, whose Stage 6 boundary permits removal of unreachable legacy production code and replacement of obsolete test entry points after cutover.

The candidate legacy cluster is:

- `Scenes/game_world.tscn`
- `Scenes/map_hex_tile.tscn`
- `Scripts/Map/map_controller.gd`
- `Scripts/Map/hex_tile_view.gd`
- matching `.uid` files
- tests under `Tests/Map/` whose sole subject is one or more deleted legacy paths

The final deletion set is evidence-driven. A candidate is deleted only after GodotIQ dependency inspection and repository test-reference inspection show that no retained production or migrated test path depends on it.

Compiler-backed verification established that `Scripts/Map/hex_map_model.gd` remains shared production code: retained battle, encounter, reward, and world-runtime scripts use its encounter constants and neighbor offsets. The model and its direct unit test are therefore preserved.

## Preserved contracts

The cleanup preserves:

- `Scenes/world_run_start.tscn` as the production entry;
- `Scenes/world_map_runtime.tscn` and the Stage 4/5 world runtime;
- Save V1 parsing and version dispatch;
- `Tests/Fixtures/WorldMap/SaveV1/legacy-25-cell.json` and other compatibility fixtures;
- Generator V1, world-plan codecs, and deterministic fixtures;
- migrated battle, encounter, recruitment, party, and runtime integration behavior;
- world preview scenes and development tooling unless dependency evidence proves a specific artifact belongs exclusively to the deleted 25-cell runtime;
- historical specifications and evidence packets.

## Cleanup method

Before deletion, capture a baseline project validation, parser check, signal-orphan report, and relevant successor tests. Inspect each candidate with GodotIQ `file_context`, `dependency_graph`, and impact analysis where supported.

Add or extend a current cutover test so the desired post-cleanup contract is executable: the production main scene remains the run-start launcher and the removed legacy paths do not exist. Run that assertion before deletion and confirm it fails for the expected reason. Then delete the approved cluster and obsolete tests, update only retained runners or manifests that reference removed tests, and rerun the assertion.

No production behavior is redesigned. Shared code discovered during dependency inspection is retained or migrated through the smallest architecture-preserving change.

## Verification

The cleanup is accepted only when:

1. GodotIQ project validation and project-wide parser checks show no cleanup-caused errors.
2. The signal map shows no new orphan or missing signal caused by the deletion.
3. The cutover-entry test proves the production authority and absence of legacy runtime paths.
4. Save V1/V2 compatibility tests pass.
5. Generator V1, production launcher, production world, runtime model, migrated flows, battle entry, and current party/recruitment integration tests pass.
6. The configured main scene starts successfully and the debug console contains no cleanup-caused error.
7. The final diff contains only the approved cleanup, required test updates, and cleanup documentation.

## Review and integration

Implementation occurs on `cleanup/stage6-legacy-world-runtime`, created from updated `main`. After verification, run the repository code-review workflow against the complete changed-file diff and address blocking or correctness findings. Commit only relevant files.

After review passes, merge the cleanup branch into `main` locally and rerun the critical verification gates on the merge result. Do not push unless explicitly requested. The pre-existing workspace changes remain preserved in the named stash and are not applied to the cleanup branch or merge commit.

## Rollback

Before merge, abandon the cleanup branch. After a local merge, revert the cleanup merge or cleanup commit. Historical evidence and compatibility fixtures remain available regardless of rollback.
