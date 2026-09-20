# AC8.1 Starting Gold and World HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan inline, task-by-task, with review checkpoints. Steps use checkbox syntax. Follow repository AGENTS.md: dedicated branch in the primary workspace, no worktrees, GodotIQ inspection and per-script validation.

**Goal:** Every newly created run starts with exactly 100g, and the world HUD displays the current durable gold balance across movement, save/reload and run replacement.

**Architecture:** `WorldRunState` owns the wallet. `WorldRunStartService` assigns the starting balance once; serialization and the existing save coordinator preserve it. `WorldRuntimeController` publishes durable state to the existing HUD without introducing a second wallet, an autoload, or economy state in the movement model.

**Tech Stack:** Godot 4, typed GDScript, authored `.tscn` UI, versioned JSON saves, headless SceneTree tests and GodotIQ runtime verification.

**Status:** Implemented in `c644778` on `feat/ac8-1-starting-gold-and-hud`. AC8.1 verified with 23 passing headless suites and rendered production-menu/input checks. [Evidence and known preview-runner limitation](../../Specs/AC8/Evidence/AC8.1/verification.md). Source: [MVP criteria](../../Specs/GAME_DESIGN_SPEC_MVP.md) and [AC8 parent plan](2026-09-18-ac8-town-recruitment-and-gold.md).

---

## Scope and decisions

- Confirmed: a new run has exactly 100g and the world HUD shows its current balance using the `100g` format.
- Include wallet serialization now: a visible wallet that resets on Continue would not be a usable AC8.1 slice. AC8.8 still owns the complete reward/purchase transaction contract.
- Proposed compatibility policy for this implementation: pre-economy Save V2 runs migrate to 0g, preserving progress without granting a new-run allowance to an existing run. New Save V3 runs require an explicit valid gold field. Keep this policy visibly separate from the confirmed 100g new-run requirement when reviewing the plan.
- Save V1/legacy-world routing retains its existing behavior. Do not convert legacy maps into current generated worlds or reopen AC5.1's deferred lifecycle design.
- No battle award, spending, recruitment, reward screen or defeat implementation in this slice. AC8.2 separately requires every lost fight to end the run and return to the main menu with no Continue for the lost run.
- Gold is a non-negative integer. Persisted 0 is valid and never means uninitialized. No display-driven initialization, periodic allowance, or `+= 100` operation.

Three approaches considered: a HUD-only value is smallest but cannot survive reload; adding gold silently to V2 is smaller but changes an established save contract; an explicit V3 wallet with V2 compatibility is recommended because new saves can validate gold strictly while old saves remain identifiable.

## Inspected implementation seams

- `WorldRunState.create()` has positional arguments through `new_battle_preparation`; `from_dictionary()`, `to_dictionary()` and `canonical_key()` handle state copies and identity. Append an optional gold argument to preserve existing call sites.
- `WorldRunStartService.start()` creates the initial state and returns it in `run_state`. Its commit callback receives the plan; it is not the atomic save boundary. Set gold before returning the candidate and retain the launcher's existing save-before-session-publication behavior.
- `WorldRuntimeSaveCoordinator._clone_state()` round-trips state through dictionaries. `commit_candidate()` and `retry_pending()` publish only after successful persistence.
- `WorldRuntimeController._build_candidate_state()` begins with the durable state's dictionary, so movement, recovery, formation and preparation candidates must retain gold. `_apply_snapshot()` already updates HUD formation and cache state from the durable state.
- `WorldMapHud` uses scene-authored unique-name labels and public setter methods. Add a label/setter using the same pattern.
- `WorldRunSaveCodecV2` currently encodes V2 and routes V1 in `decode_any()`. The repository, save store and save coordinator use this codec; move production routing to V3 while keeping explicit V2 fixture support.

## Files and ownership

| File | Responsibility |
|---|---|
| Create `Scripts/Run/run_economy_rules.gd` | Named `STARTING_GOLD: int = 100` constant only in this slice |
| Modify `Scripts/Run/world_run_state.gd` | Typed gold field, construction, validation, serialization and canonical identity |
| Modify `Scripts/Run/world_run_start_service.gd` | Assign the allowance exclusively during new-run creation |
| Create `Scripts/Save/world_run_save_codec_v3.gd` | V3 encoding, strict gold validation and explicit older-format dispatch |
| Modify `Scripts/Save/world_run_save_codec_v2.gd` | Preserve historical V2 output by omitting gold when encoding; retain its health migration |
| Modify `Scripts/Run/world_single_slot_repository.gd`, `Scripts/Save/world_save_store.gd`, `Scripts/WorldMap/world_runtime_save_coordinator.gd` | Route production reads/writes and atomic validation through V3 |
| Modify `Scripts/Run/world_production_launcher.gd` if its inspected codec reference still points to V2 | Use V3 for initial-run persistence; retain existing lifecycle and failure semantics |
| Modify `Scripts/UI/world_map_hud.gd`, `Scenes/world_map_hud.tscn` | Read-only `GoldLabel` and `set_gold_balance()` |
| Modify `Scripts/WorldMap/world_runtime_controller.gd` | Update HUD from published durable gold |
| Create `Tests/Run/test_ac8_economy.gd` | Wallet value and dictionary-copy cases |
| Create `Tests/Save/test_world_run_save_codec_v3.gd` | V3 round-trip, corruption and V2 migration |
| Create `Tests/WorldMap/test_ac8_1_gold_runtime.gd` | End-to-end wallet preservation and HUD publication |
| Extend `Tests/Run/test_world_run_start_service.gd`, `Tests/UI/test_world_map_hud.gd` | New-run allowance and label rendering |
| Extend `Tests/WorldMap/test_world_runtime_save_coordinator.gd` | Failed write, retry and discard preserve the correct balance |

No wallet field is needed in `WorldRuntimeModel` or `WorldRuntimeSnapshot`: the HUD can consume the controller's durable state directly, just as cache presentation does.

### Task 1: Establish a clean implementation baseline

- [x] Inspect `git status --short --branch`; preserve unrelated local changes. Update `main` from origin and create `feat/ac8-1-starting-gold-and-hud` in the primary workspace. Never create a worktree.
- [x] Call `project_summary(detail="brief")`, `file_context` for affected files and `impact_check` for construction, serialization and HUD API changes. Use dependency analysis to identify every production codec reference and state factory caller.
- [x] Run `validate(target="project", detail="brief")` and the existing start-service, Save V2, repository, launcher, runtime-save-coordinator and HUD runners listed below. Record pre-existing failures separately before changing code.
- [x] Inspect the current HUD scene through GodotIQ and choose a position in its existing information container, alongside the move/cache information, with no overlap at the supported minimum viewport.

### Task 2: Add the wallet value and exactly-once initialization

- [x] Add failing wallet tests: default constructed state has 0g; explicit 0g, 100g and 375g survive dictionary round-trips; negative values fail validation; canonical identity changes when gold changes. Missing gold is rejected by normal current-state dictionary decoding; only the legacy codec adapter may supply it.
- [x] Extend the start-service runner to assert 100g for each supported commander and for two independently started runs. Mutate the first returned state's gold to 375; a second new run must still return 100. Failed generation must not publish a new wallet.
- [x] Run the two runners and record failures caused by the missing wallet contract.
- [x] Create the minimal rules resource and state field:

```gdscript
class_name RunEconomyRules
extends RefCounted

const STARTING_GOLD: int = 100
```

```gdscript
# WorldRunState fields and final create() argument:
var gold: int = 0
# Append after new_battle_preparation:
# new_gold: int = 0
# In create(), reject new_gold < 0 and assign state.gold = new_gold.
# In is_valid(), reject gold < 0. In to_dictionary(), include "gold": gold.
```

- [x] Decode JSON numbers before converting to `int`: accept finite whole numeric values within a safe integer range, including 0; reject negative, fractional, string, boolean, null and out-of-range input. Avoid truncating `1.5` into `1`. Use one validation path for dictionary restoration and V3 loading.
- [x] Load the new rules script with `load()`. In `WorldRunStartService.start()`, after successful state creation and before publication, assign `run_state.set("gold", ECONOMY_RULES_SCRIPT.STARTING_GOLD)`. Do not assign an allowance in Continue, scene `_ready()`, HUD setters or ordinary state-copy construction.
- [x] Run `validate` then `check_errors` after each changed script. Run focused tests to green and include the verified wallet/start-service files and tests in the final AC8.1 commit.

### Task 3: Persist the wallet with explicit save compatibility

- [x] Add V3 failing tests using generated valid plans and existing roster fixtures: 0g, 100g and 375g round-trip exactly; missing or malformed gold fails; unknown versions fail; corrupted plan hash still fails. V2 fixtures restore their existing map, roster, health and preparation with 0g; re-encoding as V3 and reloading retains 0g.
- [x] Give `WorldRunSaveCodecV3` the existing public codec surface: static `encode(plan: RefCounted, resolved_seed: String, run_state: RefCounted) -> PackedByteArray` and `decode_any(bytes: PackedByteArray) -> Dictionary`. Encoding validates the state and emits the existing envelope with `save_version: 3` and required `world.run_state.gold`, returning empty bytes on invalid input. Decoding returns the existing `{ok, value, error}` shape; successful `value` contains `plan`, `resolved_seed` and `run_state`.

- [x] Implement explicit dispatch: V3 requires gold and uses existing canonical-plan/hash, seed, generator, roster and state checks; V2 uses its historical validation and supplies gold 0 at the compatibility boundary before current state construction; V1 uses existing legacy decoding. Keep starter-health migration applied exactly once. Reject malformed version values rather than selecting a version by lossy numeric coercion.
- [x] Keep V2 encoding historical: remove `gold` from the serialized state dictionary in that encoder. Do not silently emit economy saves marked V2. Change all production codec references identified by dependency analysis to V3, including initial-run creation and atomic store validation. Avoid duplicating plan/hash validation: extract a shared validation helper only if necessary, preserving existing V2 behavior with its regression tests.
- [x] Add save-coordinator assertions with durable gold 100 and candidate gold 375: failed save leaves live/HUD gold 100; retry publishes 375 once; discard restores 100. A later reload reads 375 after success. This is a transaction fixture, not a new player-facing gold mutation API.
- [x] Verify movement, formation, preparation and recovery candidate dictionaries retain non-default gold. Update current-state test fixtures with explicit gold while retaining true legacy fixtures without it.
- [x] Validate/check each changed script, then run V3, V2, starter-health migration, repository, launcher and coordinator tests. Include the verified persistence slice in the final AC8.1 commit.

### Task 4: Present durable gold on the world HUD

- [x] Add failing HUD tests for `100g`, `0g`, `375g` and a larger multi-digit amount. Repeating the setter must not change run state or perform a save.
- [x] Use GodotIQ scene tools to add a unique-name `GoldLabel` to the HUD's existing information container. Keep it visible with either commander; it must not inherit the Brakka-only cache visibility rule. Use container sizing and the existing typography.
- [x] Add the setter using the existing typed node-reference pattern:

```gdscript
@onready var _gold_label: Label = %GoldLabel

func set_gold_balance(balance: int) -> void:
    _gold_label.text = "%dg" % balance
```

- [x] In `WorldRuntimeController._apply_snapshot()`, after resolving the HUD, pass `int(_durable_run_state.get("gold"))` when durable state exists. Production session application must set the durable state before revealing the world; a preview with no session can show 0g. Do not derive gold from move count, enemy count, the movement snapshot or label text.
- [x] Exercise application of a 375g session, an accepted move, a formation save, failed-save retry and reapplication of the saved session. Require the HUD to show the durable amount at every step. Start another run and require 100g.
- [x] Validate/check scripts, save the scene, and run HUD plus focused runtime tests. Include the verified HUD/controller/test changes in the final AC8.1 commit.

### Task 5: Run the acceptance gate and record evidence

Use the project's Godot executable (resolve its installed path if it is not on PATH):

```powershell
$goldRunners = @(
  'Tests/Run/test_ac8_economy.gd',
  'Tests/Run/test_world_run_start_service.gd',
  'Tests/Save/test_world_run_save_codec_v3.gd',
  'Tests/Save/test_world_run_save_codec_v2.gd',
  'Tests/Save/test_goblin_starter_save_migration.gd',
  'Tests/Save/test_world_save_store.gd',
  'Tests/Run/test_world_single_slot_repository.gd',
  'Tests/Run/test_world_production_launcher.gd',
  'Tests/WorldMap/test_world_runtime_save_coordinator.gd',
  'Tests/UI/test_world_map_hud.gd',
  'Tests/UI/test_world_run_start_scene.gd',
  'Tests/WorldMap/test_ac8_1_gold_runtime.gd'
)
foreach ($goldRunner in $goldRunners) {
  & godot.windows.opt.tools.64.exe --headless --path . --script "res://$goldRunner"
  if ($LASTEXITCODE -ne 0) { throw "Failed: $goldRunner" }
}
```

- [x] Require exit code 0 and no parser/runtime errors for each runner. Baseline uses only existing runners; the new runners enter the gate once created.
- [x] Run project validation, project error checks and `signal_map(find="orphans")` after integration. Investigate new errors relative to baseline.
- [x] GodotIQ runtime sequence: play, verify project runs, read debug console, inspect state. Start a production run and observe 100g; move and return through the normal save/Continue flow and observe 100g again.
- [x] Use a valid test session with 375g, then one with 0g, to verify exact restoration through production loading. Start a replacement run and observe 100g. Do not use battle rewards as a prerequisite for this AC8.1 check.
- [x] Inspect the authored HUD at 1152x648 and a larger supported viewport: gold is legible, never clipped, and does not overlap party/cache/movement controls. Capture one screenshot per verification point, describe visible results, fix layout defects and repeat the affected point. Stop the game after verification.
- [x] Save commands, results, runtime observations and the tested commit under `Docs/Specs/AC8/Evidence/AC8.1/`. Mark AC8.1 complete only after this evidence passes; keep AC8.2-AC8.8 unchecked. Commit only relevant implementation and evidence files.

## Acceptance traceability

| Requirement | Proof |
|---|---|
| Exactly 100g for every new run | Start-service runner and production new-run check |
| No allowance on reload/re-entry | 0g/375g codec and production Continue cases |
| Current gold visible | HUD setter runner, runtime integration and screenshots |
| No lost gold in unrelated saves | Candidate-copy cases for movement, formation, preparation and recovery |
| No premature publication or double mutation | Save failure/retry/discard coordinator cases |
| Older saves remain explicit and readable | V2/legacy regressions plus V2-to-V3 wallet migration case |

The proposed legacy 0g migration is the only new product-policy default in this plan. It can be revised during plan review without changing the confirmed 100g allowance for newly created runs.

## Execution notes

- The approved legacy policy is implemented: V2 migrates to 0g; new runs receive 100g.
- Shared envelope checks were extracted into `Scripts/Save/world_run_save_envelope.gd`. `WorldSaveStore` needed no change: its atomic writer is codec-independent and production validation is owned by the repository.
- GodotIQ startup passed. Embedded input/screenshot calls were unreliable; a separate OpenGL rendered runner verified real keyboard and mouse input and produced inspected screenshots.
- The unrelated preview-flow runner stalls with both the original and updated runtime controller; it is documented separately and excluded from the 23 passing production/affected suites.
- Verified changes were consolidated into one implementation/evidence commit. Existing local documentation and debug-scene edits were restored without staging them. Roadmap status updates remain alongside those local documentation edits.
