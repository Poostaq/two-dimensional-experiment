# World Save and Run-Start Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an atomic Generator V1 save envelope and non-production run-start boundary with exact interactive, in-process headless, and production-headless failure behavior.

**Architecture:** A pure codec validates the complete canonical world payload before constructing runtime state; a store owns atomic filesystem writes and immutable failures. A run-start service coordinates generation without UI or process control, while separate adapters own the interactive overlay and exit-status-70 subprocess behavior. The current 25-cell production entry remains unchanged.

**Tech Stack:** Godot 4, typed GDScript, JSON save envelopes, SHA-256, standalone headless test scripts, subprocess verification, GodotIQ scene/script validation.

---

## Authority and exclusions

Read:

- `Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md`
- `Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md`
- `Docs/superpowers/plans/2026-08-24-canonical-world-generator-v1.md`

This plan closes automated portions of WM-T13, WM-T17, and WM-T18. It does not switch `Scenes/game_world.tscn`, modify `MapController`, add save selection, render the 217-cell map, or cut over production authority.

## Concrete file map

| File | Responsibility |
|---|---|
| `Scripts/Save/world_save_error.gd` | General malformed-envelope error outside the four world taxonomy codes |
| `Scripts/Save/world_save_codec_v1.gd` | Required-field envelope serialization, recognition order, SHA and plan validation |
| `Scripts/Save/world_save_store.gd` | Atomic write/read and source-file immutability |
| `Scripts/Run/world_run_start_service.gd` | Generate-first transaction and zero-mutation typed result |
| `Scripts/Run/world_failure_formatter.gd` | Exact ordered interactive/headless diagnostic JSON |
| `Tools/WorldMap/headless_world_run_start.gd` | Production-style stderr and exit-status-70 adapter |
| `Scripts/UI/world_generation_failure_overlay.gd` | Blocking message, Return, and Copy Diagnostics behavior |
| `Scenes/world_generation_failure_overlay.tscn` | Reusable non-production failure surface |
| `Tests/Fixtures/WorldMap/SaveV1/legacy-25-cell.json` | Recognized unsupported legacy envelope |
| `Tests/Fixtures/WorldMap/SaveV1/unsupported-v2.json` | Recognized canonical envelope with unsupported generator version |
| `Tests/Save/test_world_save_codec_v1.gd` | V1 round trip, taxonomy dispatch, malformed envelope |
| `Tests/Save/test_world_save_store.gd` | Atomic write/read and failure immutability |
| `Tests/Run/test_world_run_start_service.gd` | Success/failure transaction and zero mutation |
| `Tests/Run/test_world_headless_failure.gd` | Exact formatter and `RETURN_RESULT` behavior |
| `Tests/Run/test_world_headless_exit_process.gd` | Subprocess stderr, stdout, and status 70 |
| `Tests/UI/test_world_generation_failure_overlay.gd` | Blocking copy and Return signals without production integration |

Evidence is written under `Docs/Specs/WorldMap/Evidence/SaveV1/{red,green}/`.

## Fixed contracts

The save root is JSON with `schema="twde-run-save"`, `save_version=1`, and one `world` object containing exactly the eight required target-design fields. `canonical_plan_utf8` is the canonical plan text as a JSON string; `canonical_plan_sha256` is lowercase hexadecimal.

Load dispatch order is:

1. JSON object and root schema recognition;
2. legacy 25-cell recognition;
3. required canonical-world fields;
4. generator-version reader dispatch;
5. SHA-256 and canonical-plan parsing;
6. runtime coordinate/count validation;
7. publication of a complete decoded value.

Exact errors:

- recognized legacy envelope → `LEGACY_WORLD_SAVE_UNSUPPORTED`;
- canonical envelope with unsupported generator version → `WORLD_VERSION_UNSUPPORTED`;
- malformed/unknown general envelope → `SAVE_ENVELOPE_INVALID` owned by `WorldSaveError`;
- SHA or stored-plan inconsistency → `SAVE_ENVELOPE_INVALID` without source mutation.

`WorldRunStartService.start(seed, config, policy)` supports `RETURN_RESULT` only. It never instantiates UI or quits. `Tools/WorldMap/headless_world_run_start.gd` owns `EXIT_PROCESS` and exit 70.

## Task 1: Create the stacked task branch and freeze Generator V1

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/baseline.txt`

- [ ] Record current Generator V1 head, create `feat/world-save-run-start` from it, and record `upstream_base=feat/world-generator-v1`, full parent SHA, and the 22-test verification command in `baseline.txt`.
- [ ] Run all seven `Tests/WorldMap/*.gd` scripts and require exit `0` before save tests are written.
- [ ] Commit with `test: freeze Generator V1 save baseline`.

## Task 2: Drive save codec through RED/GREEN

**Files:**
- Create: `Scripts/Save/world_save_error.gd`
- Create: `Scripts/Save/world_save_codec_v1.gd`
- Create: `Tests/Save/test_world_save_codec_v1.gd`
- Create: both `Tests/Fixtures/WorldMap/SaveV1/*.json`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/red/save-codec-red.log`

- [ ] Write a standalone test that generates `golden-alpha`, encodes runtime player `(-8,0)`, boss `(8,0)`, move count `0`, and inactive Sudden Death; assert exact eight fields, SHA, and byte-identical plan round trip.
- [ ] Add legacy, unsupported-version, altered-SHA, missing-field, invalid-runtime-coordinate, and source-byte-immutability assertions.
- [ ] Run RED and require exit `1` because `world_save_codec_v1.gd` is absent.
- [ ] Implement `WorldSaveError` with `SAVE_ENVELOPE_INVALID` and implement `WorldSaveCodecV1.encode(plan, runtime_state) -> PackedByteArray` plus `decode(bytes) -> {ok,value,error}`.
- [ ] Use `WorldPlanCodecV1.parse()` for V1; never regenerate from the seed during load.
- [ ] Validate/check each script with GodotIQ, run GREEN, and commit `feat: add Generator V1 save codec`.

## Task 3: Drive atomic storage through RED/GREEN

**Files:**
- Create: `Scripts/Save/world_save_store.gd`
- Create: `Tests/Save/test_world_save_store.gd`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/red/save-store-red.log`

- [ ] Write RED tests using a unique `user://tests/world-save-v1/<run-id>/` directory. Assert successful write/read, replacement through a sibling temporary file, no leftover temp file, and unchanged source bytes after failed decode.
- [ ] Implement `save_atomic(path, bytes)` by writing `<path>.tmp`, flushing, then replacing the destination only after the full write succeeds. Implement `load_validated(path)` by reading bytes once and delegating to the codec without writes.
- [ ] Verify resolved test paths stay inside `user://tests/world-save-v1/` before cleanup.
- [ ] Validate/check, run GREEN, and commit `feat: add atomic world save store`.

## Task 4: Drive the pure run-start transaction through RED/GREEN

**Files:**
- Create: `Scripts/Run/world_run_start_service.gd`
- Create: `Tests/Run/test_world_run_start_service.gd`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/red/run-start-red.log`

- [ ] Write RED tests with injected Generator V1 and in-memory commit callbacks. Successful generation calls commit exactly once with a complete plan; the radius-2 impossible configuration calls it zero times and returns the exact typed error.
- [ ] Assert failure leaves save bytes, history, roster, rewards, encounter, battle, and published-cell counters unchanged.
- [ ] Implement `start(seed, config, policy="RETURN_RESULT")`; reject any other policy as `WORLD_GENERATION_INTERNAL_ERROR`. Generate first, then call the injected commit callback exactly once on success.
- [ ] Validate/check, run GREEN, and commit `feat: add atomic world run-start service`.

## Task 5: Drive formatter and production headless adapter through RED/GREEN

**Files:**
- Create: `Scripts/Run/world_failure_formatter.gd`
- Create: `Tools/WorldMap/headless_world_run_start.gd`
- Create: `Tests/Run/test_world_headless_failure.gd`
- Create: `Tests/Run/test_world_headless_exit_process.gd`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/red/headless-red.log`

- [ ] Write formatter RED assertions for one UTF-8 JSON line with exact key order `event,code,seed_hex,generator_version,namespace,constraint,build_version` and LF termination.
- [ ] Write subprocess RED assertions invoking the tool with the impossible config: exact stderr bytes, no failure object on stdout, and process exit `70`.
- [ ] Implement the formatter without dictionary-order reliance: JSON-escape each value and concatenate keys in the fixed order.
- [ ] Implement the tool with no display/UI access. On failure write the formatter result once to stderr and call `quit(70)`; on success print one normal result to stdout and exit `0`.
- [ ] Validate/check, run both GREEN tests using waited subprocess execution, and commit `feat: add headless world run-start failure policy`.

## Task 6: Add the reusable interactive failure overlay

**Files:**
- Create: `Scripts/UI/world_generation_failure_overlay.gd`
- Create: `Scenes/world_generation_failure_overlay.tscn`
- Create: `Tests/UI/test_world_generation_failure_overlay.gd`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/red/failure-overlay-red.log`

- [ ] Write RED scene tests asserting the exact message, modal input blocking, `Return` signal, `Copy Diagnostics` content, and no map/run mutation.
- [ ] Use GodotIQ `build_scene`/`node_ops` to create a full-rect `Control` with blocker, panel, message, Return button, and Copy Diagnostics button. Create the script through `script_ops` and connect signals through GodotIQ.
- [ ] The overlay exposes `present(error, build_version)`, `return_requested`, and `diagnostics_copied`. It uses `WorldFailureFormatter` for copy content and never starts or retries a run.
- [ ] Save, validate, check errors, run the scene test, then run GodotIQ Play/explore visual QA on the non-production scene.
- [ ] Commit `feat: add world generation failure overlay`.

## Task 7: Produce final evidence without production cutover

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/green/save-tests.log`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/green/headless-subprocess.log`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/green/godotiq-validation.json`
- Create: `Docs/Specs/WorldMap/Evidence/SaveV1/green/scope-audit.txt`

- [ ] Run all SaveV1, Run-start, overlay, and seven Generator V1 tests with waited exit-code capture.
- [ ] Run all 15 frozen legacy tests and compare their SHA manifest with the Generator V1 baseline.
- [ ] Run project GodotIQ validation, error scan, orphan-signal audit, and Play health.
- [ ] Prove `Scenes/game_world.tscn` and all current `Scripts/Map/*.gd` files have no diff from the Generator V1 parent.
- [ ] Record full implementation SHA and commands in every evidence artifact; commit `test: record Save V1 and run-start evidence`.

## Completion gate

- V1 saves round-trip complete canonical plans byte-for-byte.
- Legacy and unsupported versions dispatch to distinct exact codes.
- Failed loads never alter source bytes.
- Failed run start creates no partial state.
- Test policy returns a typed result without quitting.
- Production headless policy emits exact stderr JSON and exits 70.
- Interactive overlay remains non-production and visually verified.
- Generator V1 and all frozen legacy tests remain green and unchanged.
- Current 25-cell production authority has no diff.

Completion unlocks the third plan: scrollable world presentation, camera, minimap, layered visuals, HUD, and performance fixtures.
