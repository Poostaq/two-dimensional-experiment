# 25-Cell to 217-Cell World Migration Authority

**Status:** Approved migration authority

**Date:** 2026-08-23

**Target authority:** `2026-08-23-scrollable-hex-world-target-design.md`

## Purpose

This document governs the repository migration from the current 25-cell world to the approved radius-8, 217-cell world. It defines ownership, sequencing, frozen proof, save policy, failure handling, evidence, and the single production cutover. It does not redefine the approved target design.

No implementation may begin until this migration authority is approved. After approval, focused implementation plans must reference both this document and the target design.

## Chosen strategy

Use a staged parallel-path migration:

1. Build and prove the new world domain independently of the production scene.
2. Add the new presentation and run-start flow behind a non-production test entry.
3. Integrate runtime behavior while the current 25-cell production path and legacy tests remain frozen.
4. Change production authority once, at the cutover commit.
5. Remove superseded legacy implementation only after cutover evidence passes.

The project will not perform an in-place progressive replacement and will not maintain two production world authorities after cutover.

## Current authority and ownership

Before cutover, the current production path remains authoritative:

- `Scenes/game_world.tscn` owns the production composition root.
- `Scripts/Map/map_controller.gd` owns current map runtime coordination, movement, encounters, battle transitions, Party access, roster state, and Sudden Death state.
- `Scripts/Map/hex_map_model.gd` owns current 25-cell geometry, adjacency, path queries, start/boss coordinates, and encounter layout.
- `Scenes/map_hex_tile.tscn` and `Scripts/Map/hex_tile_view.gd` own the current tile presentation and pointer signals.

The existing controller is too broad to become the canonical generator or filesystem save owner. The migration must preserve its orchestration role while moving immutable world construction and serialization into dedicated domain owners.

## Target ownership boundaries

The implementation plans must introduce these responsibilities without requiring these exact filenames:

| Responsibility | Required owner | Forbidden responsibility |
|---|---|---|
| Radius-8 coordinates, adjacency, distance, canonical coordinate order | Pure world geometry/model | Scene nodes, input, filesystem I/O |
| Seeded town, road, forest, and protected-cell planning | Pure versioned Generator V1 | Camera traversal order or runtime scene state |
| Canonical UTF-8 artifact, FNV priority payloads, SHA-256 plan identity | Versioned world-plan serializer | UI presentation |
| Save envelope, atomic writes, version dispatch, immutable failure | Future run-save owner | Map rendering or movement rules |
| Accepted-move transaction and boss pursuit | Map runtime/controller domain | Generation retries or canonical serialization |
| Main map, markers, camera, minimap, HUD, Party entry | World-map presentation scenes | Authoritative generation randomness |
| Interactive run-start failure overlay | Run-start composition owner | Partial run creation |
| Typed test failure and production headless exit policy | Run-start service/entry adapter | UI dependency in headless tests |

`MapController` may consume a successfully validated world plan. It must never observe or render a partial plan.

## Legacy-save policy

There is no post-cutover compatibility window. The only legacy-readable interval is the normal pre-cutover lifetime of the frozen 25-cell production path, ending at the exact cutover commit `C`.

- Every pre-cutover 25-cell save is unsupported immediately when the 217-cell production cutover occurs.
- No legacy world reader, converter, upgrader, or dual-path continuation is required.
- Selecting a recognized pre-cutover save after cutover returns `LEGACY_WORLD_SAVE_UNSUPPORTED` without modifying, replacing, truncating, or deleting the source file.
- The player-facing failure returns to the save-selection or pre-run surface with copyable diagnostics.
- Headless tests receive the typed failure result. Production headless entry emits the canonical structured error and exits according to the target design.
- Generator V1 saves store the complete canonical plan and follow the approved versioned save contract.

If the repository has no persisted save feature when cutover occurs, the unsupported-legacy parser path may be proven using immutable fixture envelopes rather than shipping a discoverable legacy-save UI.

### Failure-code dispatch

This authority adopts the target design's canonical world failure taxonomy without aliases:

- A recognized pre-cutover 25-cell envelope maps only to `LEGACY_WORLD_SAVE_UNSUPPORTED` at `C` and later.
- A recognized canonical-world envelope whose generator version lacks a parser maps only to `WORLD_VERSION_UNSUPPORTED`.
- `WORLD_CONSTRAINT_UNSATISFIABLE` and `WORLD_GENERATION_INTERNAL_ERROR` are generation/run-start failures and are never returned by save-version dispatch.
- Save detection happens before generator-version dispatch, and failed loading never invokes generation.
- Malformed or unknown general save envelopes remain the future run-save owner's responsibility; the implementation plan must not invent a conversion to one of the four world codes.

## Parallel-path isolation

Before cutover, the 217-cell path may be entered only by tests, explicit development launch parameters, or a dedicated non-production scene. It must not silently replace `Scenes/game_world.tscn` as the normal run path.

The two paths may share stable domain concepts such as axial coordinates and encounter types, but they must not share mutable global world state. A test must prove that creating or failing a Generator V1 plan does not mutate the active 25-cell run.

The new path may not add a second autoload world authority. Dependency injection or explicit composition must supply the plan, save adapter, and failure policy.

## Frozen legacy gate

From approval of this document until the candidate cutover commit passes post-cutover verification, these current tests and their expected 25-cell values are frozen:

- `Tests/Map/test_hex_map_model.gd`
- `Tests/Map/test_map_controller_runtime.gd`
- `Tests/Map/test_ac1_1_runtime_step_counts.gd`
- `Tests/Map/test_ac1_2_encounter_determinism.gd`
- `Tests/Map/test_ac1_2_hex_tile_view_states.gd`
- `Tests/Map/test_ac1_2_runtime_encounter_layout.gd`
- `Tests/Map/test_ac1_3_mouse_navigation.gd`
- `Tests/Map/test_ac1_4_encounter_overlay.gd`
- `Tests/Map/test_ac1_5_sudden_death.gd`
- `Tests/Map/test_ac2_1_battle_arena.gd`
- `Tests/Map/test_ac3_1_recruitment_integration.gd`
- `Tests/Map/test_ac3_3_party_management_integration.gd`
- `Tests/Map/test_world_turn_counter.gd`
- `Tests/Run/test_ac3_1_run_roster.gd`
- `Tests/Run/test_ac3_3_party_formation.gd`

Before cutover, no migration commit may weaken, skip, rename, delete, rewrite, or conditionally bypass these assertions. A required correction to a frozen test stops the migration and requires project-lead approval of a documented exception.

Historical manual evidence under `Docs/Specs/**/Evidence` remains immutable. New migration evidence is additive.

## Assertion disposition at cutover

| Current proof | Cutover disposition | Successor proof |
|---|---|---|
| 25-cell count and rectangular layout | Retire only in cutover commit | WM-T01 radius-8 count, validity, uniqueness, order |
| Current start/boss coordinates | Replace only in cutover commit | WM-T05 exact `(-8, 0)` and `(8, 0)` |
| Current deterministic encounter layout | Retain principle, migrate fixtures | WM-T02 canonical plan and golden corpus |
| Current adjacent movement and step count | Retain and migrate fixtures | WM-T07 plus accepted-move transaction tests |
| Current click navigation | Retain semantic selection; extend camera input | WM-T07 drag, zoom, no edge scroll, no turn mutation |
| Current encounter/battle transitions | Retain | Migrated integration tests on Generator V1 plans |
| Current move-15/16 Sudden Death values | Replace only in cutover commit | WM-T11 move-30/31 contract |
| Current Party management and formation | Retain | WM-T10 plus AC3.3 regression |
| Current world turn counter semantics | Retain; update target values | WM-T10 and WM-T11 transaction assertions |

No retained behavior may be dropped merely because its current test depends on the legacy scene. It must first receive a passing successor fixture.

## Implementation stages

### Stage 0 — Baseline and fixture lock

- Record the full baseline commit SHA and dirty-worktree exclusions.
- Run the frozen legacy suite without modifying it.
- Hash frozen test files and store the manifest in migration evidence.
- Create the Generator V1 golden fixture directory and document fixture review ownership.

Exit: frozen suite passes and hashes are recorded.

### Stage 1 — Canonical world domain

- Add failing golden-vector, geometry, solver, road, forest, failure, and round-trip tests.
- Implement pure radius-8 geometry, Generator V1, canonical serializer, and typed results.
- Keep all production scene and controller authority unchanged.

Exit: WM-T01–T05 and WM-T12 domain portions pass; frozen legacy suite still passes.

### Stage 2 — Save and run-start boundary

- Implement the Generator V1 save envelope and atomic save owner.
- Implement unsupported pre-cutover save detection.
- Implement interactive, test-headless, and production-headless failure adapters.
- Prove no save or partial run mutation on every failure path.

Exit: WM-T13, WM-T17, and WM-T18 automated portions pass; frozen legacy suite still passes.

### Stage 3 — Presentation path

- Build the 217-cell world-map scene, camera, minimap, markers, layered terrain presentation, HUD, and Party access behind a non-production entry.
- Add deterministic visual fixtures at minimum, default, and maximum zoom.
- Profile on the approved 2022 low-end reference computer.

Exit: WM-T06–T10 and WM-T14–T15 pass their automated and manual gates; production remains 25-cell.

### Stage 4 — Runtime integration

- Integrate accepted player movement, encounter transitions, turn semantics, and move-30/31 boss pursuit with Generator V1 plans.
- Migrate retained AC1, AC2, and AC3 assertions to the new entry without changing the production entry.
- Run the full frozen suite after every integration boundary.

Exit: all WM-T01–T18 successor tests pass through the non-production entry and the frozen legacy suite still passes.

### Stage 5 — Candidate cutover and proof

- Create pre-cutover evidence on the exact intended cutover parent.
- Change production authority in one cutover commit.
- Retire only assertions and entry code explicitly marked replaceable in this document.
- Produce post-cutover evidence against the unchanged cutover implementation commit.

Exit: the exact SHA rule and all gates below pass.

### Stage 6 — Cleanup

Cleanup occurs only after project-lead acceptance of the post-cutover packet. It may delete unreachable legacy production code, but it must preserve historical evidence, unsupported-save detection fixtures, and required versioned readers for Generator V1 or later.

## Exact cutover commit rule

Let `C` be the commit that first changes production world authority from the 25-cell path to Generator V1. Let `P = C^`, the sole parent of `C`.

- `C` must be a single-parent commit and the direct child of `P`.
- The pre-cutover evidence packet runs the complete frozen legacy gates against `P`; every artifact records the full `P` SHA.
- `C` contains the authority switch and the approved replacement/retirement changes. It contains no evidence generated after itself.
- The post-cutover packet runs every migrated and new gate against the exact `C` tree; every artifact records the full `C` SHA.
- The evidence commit after `C` may contain evidence only. Any implementation change creates a new candidate `C` and invalidates the previous post-cutover packet.
- Production cutover is approved only when `P` legacy proof passes, `C` successor proof passes, `C^` equals `P`, and the project lead accepts the evidence packet.

### Branch and commit provenance

- Every implementation stage follows repository governance: update local `main` from `origin/main`, create a dedicated task branch in the primary workspace, and exclude unrelated local changes.
- The first implementation plan names the task branch pattern, upstream base SHA capture command, commit sequence, and integration destination before any RED fixture commit is created.
- The cutover candidate is assembled on one dedicated cutover branch from an updated `main`. Its evidence manifest records the branch name, remote base ref, full base SHA, full `P` SHA, full `C` SHA, and `git rev-parse C^` ancestry proof.
- `C` must remain a single-parent commit. A merge commit cannot serve as `C`, and no history rewrite is allowed after project-lead acceptance of its post-cutover packet.
- Branch names are workflow metadata, not durable identity; full commit SHAs and artifact hashes remain authoritative after merge or branch deletion.

## Verification ownership matrix

| Gate | Stable criteria | Proof owner | Required evidence | Blocking |
|---|---|---|---|---|
| Frozen legacy | Existing AC1–AC3 and world-turn assertions | Current GUT suites | Command, full SHA, results, frozen-file hashes | Yes |
| Canonical fixtures | WM-T01–T05, WM-T12 | Pure generator test runner | Golden vectors, artifact hashes, unsatisfiable fixture | Yes |
| Save compatibility | WM-T02, WM-T13, WM-T17 | Save serialization/integration runner | Round-trip bytes, atomic-write checks, unsupported-legacy fixture | Yes |
| Runtime behavior | WM-T07, WM-T10–T13 | Migrated map integration runner | Movement, turn, encounter, Party, failure results | Yes |
| Headless behavior | WM-T13, WM-T18 | In-process tests plus subprocess runner | Typed result, exact stderr JSON, empty stdout, exit 70, mutation audit | Yes |
| Godot structure | WM-T06–T10, WM-T14 | GodotIQ validation and scene checks | Project validation, error scan, orphan-signal report | Yes |
| Runtime health | WM-T06–T11 | GodotIQ Play verification | Startup result, debug console, interaction evidence | Yes |
| Visual | WM-T06, WM-T08–T10, WM-T14 | Visual regression runner plus project-lead review | Reference fixtures and approved screenshots | Yes |
| Performance | WM-T15 | Runtime performance profile | Hardware manifest, build, 60-second capture, timings, memory | Yes |
| Cutover audit | WM-T16 | Migration evidence audit | `P`, `C`, ancestry proof, artifact index and hashes | Yes |

Golden fixture integrity and generator runtime behavior are separate assertions: the fixture runner owns immutable bytes and hashes; the generator runner owns behavior that produces them. Both must pass.

## Evidence packet

The migration packet must contain:

```text
Docs/Specs/WorldMap/Evidence/<cutover-date>/
  manifest.json
  frozen-tests.sha256
  legacy-pre-cutover.log
  generator-golden.log
  save-compatibility.log
  headless-contract.log
  migrated-post-cutover.log
  godotiq-validation.json
  godotiq-runtime-health.json
  performance-profile.json
  visual-review.md
  screenshots/
```

`manifest.json` records the target-design revision, migration-authority revision, full `P` and `C` SHAs, commands, environment, reference hardware, artifact SHA-256 values, result status, and project-lead approval. Paths may vary only if the implementation plan names the replacement before evidence is generated.

## Run-start failure flow

Generation and validation finish before a run is committed.

Interactive flow:

1. Run-start owner requests a Generator V1 plan.
2. Failure leaves the prior screen and all persisted state unchanged.
3. The run-start composition opens the blocking failure overlay.
4. `Return` closes the overlay to the same save-selection or pre-run screen.
5. Copy diagnostics exposes the canonical structured payload.

Automated flow:

- In-process tests use `RETURN_RESULT`, receive a typed error, and never access display APIs or terminate the process.
- Production-style headless entry uses `EXIT_PROCESS`, writes exactly one canonical JSON error record to stderr, writes no failure payload to stdout, and exits with status 70.
- Both paths prove zero published cells and zero save, history, roster, reward, encounter, battle, or run mutation.

## Rollback and recovery

Before project-lead acceptance, rollback means restoring production authority to `P`; it does not alter or weaken `C` evidence. After acceptance, a defect is fixed by a new forward commit and new targeted evidence. Saves created by Generator V1 must never be opened by the legacy 25-cell path.

Because pre-cutover saves are unsupported, rollback planning must not promise that a run can cross the authority boundary in either direction.

## Planning decomposition after approval

Approval of this migration authority unlocks four focused implementation plans, written and reviewed in this order:

1. Canonical world generator and golden validation package.
2. Versioned save envelope, unsupported-legacy handling, and run-start failure policies.
3. Scrollable world presentation, camera, minimap, layered visuals, HUD, and performance fixtures.
4. Runtime integration, migrated tests, evidence production, and exact cutover.

Each plan must name owned files, RED/GREEN verification, GodotIQ checks, rollback boundary, and the target criteria it closes. No plan may independently authorize production cutover.

Before the first plan can be approved for execution, it must provide a concrete proposed file map for the pure geometry, Generator V1, canonical serializer, typed result, golden fixtures, tests, and evidence outputs. It must also name the exact RED command and failing evidence location, the GREEN command and passing evidence location, and the immutable fixture-review step. Missing directories or implementation files in the current repository are expected pre-implementation state, not proof of completion; the plan must create them explicitly and no cutover approval may rely on their proposed existence.

## Approval record

The project lead approved this document on 2026-08-24. Approval fixes the staged parallel-path strategy and the zero-duration legacy-save compatibility window. Any later change to those decisions requires an explicit amendment and renewed approval.
