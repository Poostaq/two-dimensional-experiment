# AC9.2 Seeded Allied Clan Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist a deterministic two-clan allied coalition for every new AC9.2 run while preserving V2-V6 saves.

**Architecture:** `RunCharacterCatalog` owns canonical playable IDs and directed synergy data. `RunClanCoalition` validates immutable identities; `RunAlliedClanSelector` uses a versioned FNV-1a payload to choose a canonical valid pair. V7 serializes the coalition, while runtime persistence retains V5/V6 writer behavior for legacy sessions.

**Tech Stack:** Godot 4, typed GDScript, SceneTree runners, versioned JSON save envelopes.

---

## File map

| File | Responsibility |
|---|---|
| `Scripts/Run/run_character_catalog.gd` | Stable clan order and directed synergy authority |
| `Scripts/Run/run_clan_coalition.gd` | Shared coalition validation/accessors |
| `Scripts/Run/run_allied_clan_selector.gd` | Pure seed-to-pair selection and typed failures |
| `Scripts/Run/world_run_start_service.gd` | One selector call before generation |
| `Scripts/Save/world_run_save_codec_v7.gd` | V7 writer/reader and V6 fallback |
| `Scripts/Save/world_run_save_envelope.gd` | Exact V7 JSON shape |
| `Scripts/Run/world_production_launcher.gd` | V7 new-run writer/session metadata |
| `Scripts/Run/world_single_slot_repository.gd` | V7 decode-chain reader |
| `Scripts/WorldMap/world_runtime_controller.gd`, `world_runtime_save_coordinator.gd` | Version-aware runtime autosave |

### Task 1: Catalog, coalition, and pure selector

**Files:** modify `Scripts/Run/run_character_catalog.gd`; create `Scripts/Run/run_clan_coalition.gd`, `Scripts/Run/run_allied_clan_selector.gd`; create `Tests/Run/test_ac9_2_allied_clan_selection.gd`.

- [ ] Write the failing runner asserting `get_playable_clan_ids() == [goblin, orc, werewolf, lizardman, harpy]`, defensive copies, all five directed synergy lists, coalition rejection for wrong size/unknown/duplicate/main-repeat/out-of-order, and golden selector output `[orc, werewolf]` for Goblin/`ac9-vector-1`.
- [ ] Run `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Run/test_ac9_2_allied_clan_selection.gd`; expect nonzero because the classes/API are absent.
- [ ] Implement `PLAYABLE_CLAN_IDS`, `get_playable_clan_ids()`, compatibility `get_playable_clans()`, and the two synergy queries. Implement `RunClanCoalition.create(main, allies)` returning `{ok, value, error}` and enforcing catalog-index order. Implement `RunAlliedClanSelector.select(main, seed)` using exactly `WorldPriority.fnv1a32_ascii("twde-ac9|v=1|seed=%s|ns=ac9-allied-clans-v1|main=%s" % [WorldPriority.seed_hex(seed), main])` and typed `WorldGenerationError` constraints `invalid_main_clan_id`, `eligible_pool_too_small`, `no_valid_allied_pair`, `coalition_invalid`.
- [ ] Re-run the runner; expect `PASS test_ac9_2_allied_clan_selection`, including 4,096 seeds per main clan and all valid pairs observed.
- [ ] Validate each changed script and commit `feat: add deterministic allied clan selector`.

### Task 2: Start-service selection boundary

**Files:** modify `Scripts/Run/world_run_start_service.gd`; extend `Tests/Run/test_world_run_start_service.gd`.

- [ ] Add failing spies proving `WorldRunStartService` calls an injected selector once with `selection.main_clan_id` and `selection.seed_text`, returns `coalition`, and does not call the generator or commit callback when the selector returns an `allied-clan-selection` error.
- [ ] Run `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd`; expect nonzero on missing coalition behavior.
- [ ] Extend `_init(commit_callback, generator = null, allied_selector = null)`, load the production selector by default, select after `RunClanSelection` validation and before `_generator.generate`, then add `coalition` to the successful result without changing V1 generation inputs.
- [ ] Re-run the runner; expect `PASS test_world_run_start_service`. Validate the script and commit `feat: select allies before run generation`.

### Task 3: V7 envelope and codec

**Files:** create `Scripts/Save/world_run_save_codec_v7.gd`, `Tests/Save/test_world_run_save_codec_v7.gd`; modify `Scripts/Save/world_run_save_envelope.gd`.

- [ ] Write failing V7 tests for round trip, missing/wrong-size/duplicate/unknown/main-repeated/out-of-order `allied_clan_ids`, V6 selection fallback, and V2-V5 fallback.
- [ ] Run `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Save/test_world_run_save_codec_v7.gd`; expect nonzero because V7 is absent.
- [ ] Add V7 to envelope accepted versions. Require `selection` for V6/V7 and `coalition` only for V7; serialize the canonical two IDs; append `allied_clan_ids` only to V7 exact world keys; decode V7 through `RunClanSelection.create` then `RunClanCoalition.create`. Implement V7 `decode_any` as `V6_SCRIPT.decode_any(bytes)` fallback.
- [ ] Re-run V7 and V6 runners; expect both PASS. Validate scripts and commit `feat: persist allied coalitions in V7 saves`.

### Task 4: Production write/read/autosave integration

**Files:** modify `Scripts/Run/world_production_launcher.gd`, `Scripts/Run/world_single_slot_repository.gd`, `Scripts/WorldMap/world_runtime_controller.gd`, `Scripts/WorldMap/world_runtime_save_coordinator.gd`; extend `Tests/Run/test_world_production_launcher.gd`, `Tests/Run/test_world_single_slot_repository.gd`, `Tests/WorldMap/test_world_runtime_save_coordinator.gd`.

- [ ] Write failing tests for V7 new-run bytes/session coalition, repository V7 decoding, V7 runtime autosave, and a loaded V6 session retaining its V6 writer.
- [ ] Run each runner with `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/<path>.gd`; expect failures at the old V6/V5 writer boundaries.
- [ ] Switch launcher and repository decode references to V7. Carry `selection` and `coalition` in session/apply/configure calls. In the coordinator select V7 only when both values are valid, V6 when selection alone is valid, otherwise V5; call the matching codec encoder with its required identity arguments.
- [ ] Re-run the four runners; expect PASS. Validate every changed script and run `signal_map(find="orphans")`; commit `feat: preserve coalition identity through runtime saves`.

### Task 5: Regression gate and evidence

**Files:** no production files; optionally create `Docs/Specs/AC9/Evidence/AC9.2/verification.md`.

- [ ] Run focused AC9.2, AC9.1, V6/V7, launcher, repository, and runtime-save SceneTree runners; require exit 0, explicit PASS, and no parser/runtime errors.
- [ ] Run `validate(target="project", detail="brief")`, `check_errors(scope="project")`, `signal_map(find="orphans")`, and `verify_project_runs(scene="main", check_scope="project", stop_after=true)`.
- [ ] Record command/result evidence and commit `test: verify AC9.2 seeded allied clans`.
