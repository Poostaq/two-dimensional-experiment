# AC8.2 Battle Gold and Terminal Defeat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan inline, task-by-task, with review checkpoints. Steps use checkbox syntax. Follow repository AGENTS.md: dedicated branch in the primary workspace, no worktrees, GodotIQ inspection and per-script validation.

**Goal:** Award 50g per distinct defeated enemy after victory, and durably end an ordinary or boss loss so the run cannot be continued.

**Architecture:** BattleArena freezes battle facts; pure economy rules calculate the award. WorldRunState owns lifecycle and settlement receipts, and the save coordinator commits wallet, recovery and encounter completion together before publication. A versioned lost-run record in the existing single slot prevents both UI Continue and domain loading.

**Tech Stack:** Godot 4, typed GDScript, versioned JSON saves, existing atomic save store, authored UI scenes, SceneTree tests and GodotIQ.

**Status:** Approved by the user and implemented on `feat/ac8-2-battle-gold-and-terminal-defeat`, based on AC8.1 (`c644778`). Implementation and verification results are recorded in [AC8.2 evidence](../../Specs/AC8/Evidence/AC8.2/verification.md). The task checklists below preserve the approved implementation recipe; the execution record is authoritative for completed checks and deviations.

**Execution notes (2026-09-19):** Implemented the S/I/T contracts, production settlement, terminal retry guards, launcher rejection, and legacy readers. Static implementation review passed. Twenty-seven headless suites and separate terminal writer/reader processes passed, with rendered failure/menu/wallet captures. Tests exposed an immediate-Continue health initialization defect; new runs now persist the selected starter roster's full health explicitly. Boss victory receipts suppress later boss pursuit/rematch and resume a usable world checkpoint without adding a completion screen. Legacy regression fixtures were corrected to use valid combat coordinates and the production V4 codec. Changes are committed as consolidated implementation and evidence commits rather than the recipe's per-task commits.

---

## Scope and decisions

Confirmed requirements:

- Victory awards `50 * distinct defeated enemy identities`, including a defeated commander. Defeating, reviving and defeating the same character pays once.
- Any defeat grants zero gold, including a loss after partial enemy kills. It ends the run and returns to the main menu once.
- A settled lost run cannot resume after application restart or through a direct domain load call. New Run creates fresh roster/progress and exactly 100g.
- Duplicate events and persistence retries cannot repeat payment or termination. Victory retains existing post-battle recovery.

Recommended implementation decisions:

- Add Save V4 for lifecycle and battle receipts; retain explicit V3/V2 readers. Do not silently extend the V3 wire contract.
- Store `run_status = "active" | "lost"` in the existing atomic save envelope. Retain the lost record for deterministic validation and diagnostics. Do not delete the slot as the primary termination mechanism.
- Record stable battle identities and paid receipts now; AC8.8 completes the later recruitment and reward-acknowledgement integration, but cannot defer the durability needed for AC8.2.
- Keep the current victory choice UI as a temporary AC8.2 behavior, unlocked only after settlement succeeds. AC8.3 owns replacing it with the money icon/amount screen and removing Scout recruitment. This plan does not claim AC8.3 acceptance.
- In this slice, reloading after a committed victory resumes the completed world checkpoint without reopening the temporary legacy choices. Those choices remain optional legacy behavior, not a second gold mutation. AC8.3 must add durable pending presentation and acknowledgement before shipping its reward screen.
- Preserve existing boss-victory presentation/routing; do not invent a campaign completion screen in this slice. Include the gold settlement in that route and carry the receipt forward to AC8.3, which must present gold before any run-completion screen.

Alternatives considered: an in-memory terminal flag fails after restart; deleting the slot introduces a separate deletion/retry path and loses the terminal receipt; a V4 lost record reuses the existing atomic writer and is recommended.

Durability boundary: the permanent restart guarantee begins when the terminal atomic write succeeds. If every write fails and the application is forcibly killed before Retry succeeds, the old on-disk checkpoint may remain. Keep the player blocked and never advertise successful termination in that state. Crash-proof loss before any successful write would require an additional pre-battle journal and interrupted-battle policy; that is not silently assumed by this plan.

## Inspected seams and necessary changes

- `BattleArena._complete_battle()` currently emits only an outcome, then immediately opens victory choices. Capture immutable terminal facts before emission and prevent production reward/exit interactions until the controller publishes settlement.
- `WorldRuntimeController._on_battle_completed()` currently ignores defeats and separately saves victory recovery. `_on_battle_closed()` later saves encounter consumption. Replace this split for production terminal results with one transaction.
- `WorldRuntimeController._build_candidate_state()` starts from durable serialized state. Preserve all new fields across movement, formation, cache, preparation, recruitment and retry.
- `WorldRuntimeSaveCoordinator.commit_candidate()` already clones and saves before publication; `retry_pending()` reuses bytes. Add explicit non-discardable terminal transactions instead of maintaining another save mechanism.
- `discard_pending_autosave()` and `_on_autosave_return_requested()` currently restore the previous state and emit a launcher return. Both require domain guards for pending loss; hiding a button alone is insufficient.
- `WorldSingleSlotRepository.has_save()` only checks file existence. `load_validated()` currently returns any decoded session. Keep physical existence separate from resumability and reject a decoded lost state before returning a playable session.
- `WorldProductionLauncher` already listens to `launcher_return_requested`. Its Continue availability validates the repository result, but `back_to_main()` can be a no-op when its stored screen is already MAIN; explicitly refresh Continue after a world return.
- `WorldRunSaveEnvelope` accepts only V2/V3 and uses the shared state decoder. Add version-specific normalization so older saves receive lifecycle defaults while V4 requires explicit fields.

## Files and ownership

| Files | Responsibility |
|---|---|
| Modify `Scripts/Run/run_economy_rules.gd`; extend `Tests/Run/test_ac8_economy.gd` | Pure distinct-ID victory award calculation |
| Create `Scripts/Battle/battle_result_record.gd`; create `Tests/Battle/test_ac8_2_battle_result_record.gd` | Frozen final outcome, battle identity, defeated enemy IDs and copied player-health snapshot |
| Modify `Scripts/Battle/battle_arena.gd`; extend `Tests/Battle/test_ac2_4_battle_results.gd` | Capture facts once, track defeat identities and gate production terminal interactions |
| Modify `Scripts/Run/world_run_state.gd`; create `Tests/Run/test_ac8_2_run_settlement_state.gd` | Lifecycle, typed receipts, copying, validation and canonical identity |
| Create `Scripts/Save/world_run_save_codec_v4.gd`; modify `Scripts/Save/world_run_save_envelope.gd`; create `Tests/Save/test_world_run_save_codec_v4.gd` | Explicit V4 writing and legacy normalization |
| Modify `Scripts/Run/world_single_slot_repository.gd`, `Scripts/Run/world_production_launcher.gd`, `Scripts/Save/world_save_error.gd` | V4 routing, lost-run rejection, menu refresh and actionable terminal error |
| Modify `Scripts/Run/world_run_start_service.gd` | Explicit fresh lifecycle and empty receipt initialization |
| Modify `Scripts/WorldMap/world_runtime_save_coordinator.gd`; extend `Tests/WorldMap/test_world_runtime_save_coordinator.gd` | V4 serialization, frozen retries and non-discardable loss |
| Create `Scripts/Run/battle_settlement_rules.gd`; create `Tests/Run/test_ac8_2_battle_settlement_rules.gd` | Validate result against encounter identity and construct an atomic settlement candidate |
| Modify `Scripts/WorldMap/world_runtime_controller.gd` | Bind result to active battle, persist once, publish wallet or return once |
| Modify `Scripts/UI/world_autosave_failure_overlay.gd`; extend `Tests/UI/test_world_autosave_failure_overlay.gd` | Retry-only terminal failure mode; preserve ordinary autosave behavior |
| Create `Tests/WorldMap/test_ac8_2_victory_settlement.gd`, `Tests/WorldMap/test_ac8_2_defeat_ends_run.gd` | Production-session settlement and launcher/restart integration |
| Extend `Tests/Run/test_world_single_slot_repository.gd`, `Tests/Run/test_world_production_launcher.gd`, `Tests/Run/test_world_run_start_service.gd` | Load rejection, new-run replacement and menu behavior |

Reuse `Scenes/world_autosave_failure_overlay.tscn` and its Return button; script-controlled visibility/disabled state is sufficient unless inspection reveals layout changes are needed. No scene redesign or new autoload is required.

## Contract S: Save validity and playability (authoritative)

This section is the sole save contract. Tasks implement it; UI, repository and codec must not define alternative interpretations of terminal state. `WorldRunState.is_valid(plan)` means structurally valid, including lost state. Add `WorldRunState.is_playable() -> bool`, defined exactly as `run_status == "active"`; callers must validate before using it.

### S1. Accepted V4 envelope and field types

V4 requires these exact root keys: `schema`, `save_version`, `starter_roster_version`, `world`. Values are `"twde-run-save"`, integer 4, integer 1 and an object respectively. `world` requires these exact keys: `generator_version`, `run_seed_utf8_hex`, `resolved_seed`, `canonical_plan_utf8`, `canonical_plan_sha256`, `run_state`. Generator version is 1; resolved seed is a nonempty string; plan text, seed hex and SHA-256 must pass the existing canonical-plan parsing, seed equality and checksum checks. Never regenerate a map on decode.

`world.run_state` requires exactly the following fields; V4 has no omitted-field defaults:

| Field | Accepted value |
|---|---|
| `player_coord`, `boss_coord` | Two-element arrays of integers fitting Vector2i; both coordinates exist in the plan |
| `move_count` | Nonnegative integer; an active boss requires at least 30 moves, preserving the current invariant |
| `gold` | Integer in `[0, WorldRunState.MAX_GOLD]` |
| `boss_active`, `boss_engaged`, `cache_ready` | JSON booleans, not truthy strings or numeric substitutes |
| `consumed_encounters` | Array of unique valid plan coordinates |
| `formation` | Six strings; empty denotes an empty slot; nonempty character IDs are unique and satisfy existing roster validation |
| `character_hp` | Object mapping nonempty character IDs to positive integers; existing roster/health validation remains in force |
| `cache_move_progress` | Integer in `[0, 3]` |
| `battle_preparation` | Existing validated preparation record; cache/preparation consistency rules remain in force |
| `run_status` | Exactly `"active"` or `"lost"`, case-sensitive |
| `battle_settlements` | Ordered array of receipt objects defined below; empty is valid only for active state |

An integer means a finite, mathematically integral JSON number within its stated range; Godot's JSON float representation is accepted only after that check, before conversion. Booleans, numeric strings, fractions and overflow are rejected. Reject missing/extra keys at the V4 root, world, run-state and receipt levels. The existing preparation record retains its own validator. Do not repair invalid V4 fields or fall back to an older decoder after recognizing version 4.

Each receipt requires exactly these keys: `battle_id`, `encounter_type`, `encounter_coord`, `outcome`, `enemy_ids`, `defeated_enemy_ids`, `terminal_player_health`, `earned_gold`. Types and canonical identity are specified in Contract I. Receipts remain in successful settlement order, not ID sort order. Example of the new run-state fields (the existing fields above are also mandatory):

```json
{
  "run_status": "active",
  "battle_settlements": [
    {
      "battle_id": "combat:4:7",
      "encounter_type": "combat",
      "encounter_coord": [4, 7],
      "outcome": "victory",
      "enemy_ids": ["enemy_1", "enemy_2"],
      "defeated_enemy_ids": ["enemy_1", "enemy_2"],
      "terminal_player_health": [
        {"character_id": "player_1", "final_hp": 3, "max_hp": 14}
      ],
      "earned_gold": 100
    }
  ]
}
```

### S2. Cross-field rejection and migration

- An active state has zero defeat receipts. A lost state has exactly one defeat receipt, which is last, and preparation state `none`. No receipt follows a defeat. Duplicate `battle_id` values are invalid even if their payloads are identical.
- Ordinary receipt coordinates must identify combat cells in the saved plan. Each ordinary victory receipt must have its coordinate in `consumed_encounters`; the final ordinary defeat coordinate must not be consumed. Boss receipt coordinates must be valid traversable cells; at settlement time they must equal the engaged boss/player encounter coordinate. Do not require the moving boss to occupy a fixed generated combat cell.
- Victory amounts equal `50 * defeated_enemy_ids.size()`; defeat amounts equal zero. The receipt does not imply `gold == 100 + sum(awards)`, because legacy balances and later spending exist. Runtime candidate construction checks wallet delta and overflow against the durable prior state.
- On defeat preserve the prior durable `character_hp`, formation and gold unchanged. Zero terminal HP belongs in the receipt's `terminal_player_health`, not the positive-HP durable roster snapshot. A lost record's historical positive HP never makes it playable.
- Valid V2/V3 envelopes retain their existing schema and health migrations, then gain `run_status="active"` and `battle_settlements=[]` in memory. V2 retains 0g migration; V3 retains its exact wallet. Reject either lifecycle field appearing in a V2/V3 envelope instead of stripping it and upgrading a disguised lost run to active. No V4 validation failure enters migration.
- Reject V2/V3 encoding of any lost state or nonempty receipts; active/empty states encode with lifecycle fields omitted. Production writes only V4. Preserve V1's existing routing. Missing/unknown/nonintegral versions and unsupported schemas fail with no session.

### S3. Decode versus playable load

Keep the existing result shape `{ok, value, error}`. Add repository `inspect_slot() -> Dictionary` for validated, non-playable inspection; `load_validated()` remains the playable-load boundary. Both call the same V4 codec and state validators. Error names below are exact new contract identifiers.

| Input | Codec / `inspect_slot()` | Repository `load_validated()` | Launcher / direct runtime application |
|---|---|---|---|
| Valid active V4 or valid migrated V2/V3 | `ok=true`, `value={plan,resolved_seed,run_state}`, `error=null` | Same success | Continue enabled; `apply_session` accepts subject to other integration checks |
| Valid lost V4 | Same structural success, with `run_status="lost"`; intentionally non-playable | `ok=false`, `value=null`, error code `RUN_LOST`, constraint `run_status_lost` | Continue disabled; no `session_ready`; `apply_session` returns false before roster/model mutation |
| Malformed V4, inconsistent lost record, disguised terminal legacy state | `ok=false`, `value=null`, existing `SAVE_ENVELOPE_INVALID` error with field constraint | Same failure, never `RUN_LOST` | Continue disabled; never manufacture active defaults |
| Missing/unreadable file | Repository I/O failure, `value=null` | Same failure | Continue disabled |

`has_save()` remains physical existence only. New Run uses `inspect_slot()` to skip overwrite confirmation only for a verified lost record; active or corrupt existing files retain confirmation. No load path deletes, repairs, downgrades or overwrites a terminal record. Only successfully persisting an explicitly requested New Run can replace it with active state. A failed New Run write leaves the terminal record intact.

## Contract I: Canonical battle identity and exactly-once settlement

`BattleResultRecord` is the single owner of identity construction, terminal normalization and receipt comparison. `BattleSettlementRules`, arena and controller call it; they must not reproduce string formatting or define their own equality rules.

### I1. Authoritative sources

- Ordinary encounter ID: `combat:<x>:<y>` using the accepted encounter coordinate and canonical signed decimal integer formatting (no leading zeros or plus signs). Type is exactly `combat`.
- Boss encounter ID: exactly `boss`, type exactly `boss`. There is one boss per run; its position is separate receipt data and movement never creates another payable boss identity. This replaces the earlier coordinate-based boss proposal.
- IDs are scoped to the owning run's receipt collection. They are not global IDs. New Run, even with the same seed, starts an empty collection. Repeatable encounters or multiple bosses require a new persisted occurrence-identity contract before implementation.
- Enemy canonical ID: the exact case-sensitive `String(unit.unit_id)` captured from each `BattleUnitState` with side ENEMY at authoritative battle setup. Validate nonempty IDs with no leading/trailing whitespace and global uniqueness across player/enemy units before enabling battle input. Preserve the ID across formation swaps, revival, transformation and display-name/class changes. Do not derive IDs from slots, class, name or current object instance. A commander uses its configured unit ID and receives no special multiplier or alias.
- Freeze setup membership. AC8.2 does not introduce reinforcement/summon identities; introducing new combatants requires a separately specified identity registration extension. Duplicate setup IDs fail battle setup; they are not merged into one character.
- Controller binds each completion callback to its current session generation, battle generation and originating arena object. These transient guards are distinct from the persisted encounter ID, checked first, and never reset/reused within a controller lifetime. Session replacement increments the session generation. A stale source is ignored without a write even if its run seed, coordinate and result match.

### I2. Defeat facts and canonical receipt

Observe every committed HP transition from positive to `<=0` for registered enemy IDs, including default attacks, skills, reactions and bleed, before removal or revival can hide it. Add the ID to a set; never remove it on revival. Preview, cancellation, an uncommitted action or removal of a living unit never records a defeat. Capture terminal outcome once, using the existing outcome evaluator; `IN_PROGRESS` is not a settleable result.

The receipt's `enemy_ids` is the frozen setup enemy membership; `defeated_enemy_ids` is its defeated subset. Both are sorted by case-sensitive String ordering with unique nonempty IDs. `terminal_player_health` contains exactly one row per configured player, sorted by `character_id`, each with exactly `character_id`, `final_hp`, `max_hp`; integral `max_hp>0` and `0<=final_hp<=max_hp`. IDs must be disjoint from enemy membership. At initial settlement require exact membership equality with the bound arena's frozen setup. On disk, validate the recorded sets and relationships without regenerating enemy catalog content. This is structural integrity, not tamper authentication.

Canonical equality is exact equality of this ordered tuple after validated integer conversion:

```text
[battle_id, encounter_type, [x,y], outcome,
 enemy_ids, defeated_enemy_ids,
 [[character_id,final_hp,max_hp], ...], earned_gold]
```

Object key ordering is irrelevant; array ordering must already be canonical. Compare the full tuple, not just outcome, count, battle ID or a hash. `earned_gold` is computed by economy rules, never accepted from an untrusted callback. Result/receipt getters return deep copies. Persisting terminal facts makes duplicate equality equally precise before and after reload.

### I3. Event decision table

| Condition (evaluate top to bottom) | Required behavior |
|---|---|
| Stale session/generation/arena | Ignore; zero save, award or return calls |
| Malformed result or mismatch with bound encounter/setup | Reject and block integration; zero state change |
| Same battle ID and identical tuple already pending | No-op; do not retry implicitly or replace pending bytes |
| Same battle ID and identical tuple already durable | No-op; zero writes/publication/return; after reload use the durable receipt |
| Same battle ID but different tuple, pending or durable | Reject `settlement_conflict`; retain the original candidate/receipt and blocked state where applicable |
| Different battle while a candidate is pending, or any new settlement after lost status | Reject; cannot overwrite pending/terminal state |
| Valid first terminal result for current battle and active run | Build one candidate and attempt one atomic commit |

There is one settlement per **battle**, not one per outcome. Victory followed by a defeat callback for the same battle is a conflict, not a second transaction. Reward acknowledgement, arena exit and duplicate completion never calculate a fresh award.

## Contract T: Terminal failure and publication sequencing

`WorldRuntimeController` owns the terminal phase; `WorldRuntimeSaveCoordinator` owns the frozen persistence bundle. These phases are transient and never serialized as additional `run_status` values.

| Phase | Entry and permitted actions | Exit |
|---|---|---|
| `PLAYING` | Valid active session; normal input | First valid defeat freezes result and synchronously blocks world/battle input before building candidate |
| `LOSS_COMMITTING` | Build/validate lost candidate; clone prior state; encode once; capture pending bundle before I/O. No Return, Retry, New Run, reward or gameplay mutation | Atomic write success -> `LOSS_DURABLE`; write failure with retained bundle -> `LOSS_SAVE_FAILED` |
| `LOSS_SAVE_FAILED` | Show Retry-only overlay only now. Copy diagnostics allowed. Direct discard/return/close/Continue/session replacement calls rejected | Retry -> `LOSS_COMMITTING` with the same bundle; repeated failure returns here |
| `LOSS_DURABLE` | Install committed lost state; keep gameplay blocked; latch publication; dismiss overlay | Set return-emitted latch before emitting `launcher_return_requested`, then `RETURNED` |
| `RETURNED` | No further publication, save, return or gameplay actions from this controller | Launcher frees world and refreshes Continue from repository |

Validation/encoding failure is not an I/O failure: enter blocked integration-error handling, produce diagnostics, emit no launcher return and do not offer Retry without valid bytes. Never show a Retry-only save overlay merely because an invalid candidate was rejected. A later implementation must not turn this case into success or checkpoint restoration.

The retained bundle consists of: deep-copied prior durable state, deep-copied lost candidate, canonical terminal receipt, exact `PackedByteArray` output, original repository/slot binding, publication Callable, session/battle generation, `allow_discard=false`, publication/return latches and diagnostic error. Capture before the first write. The wallet, roster health and progress visible as durable state remain the old values until successful publication, but the phase guard makes that checkpoint non-playable in this process.

Retry performs only `replace_atomic(retained_bytes)` against the retained repository. It must not re-encode, recalculate HP/gold, read mutable arena units, accept a new result, change save version or bind another slot. Disable/reject concurrent Retry while committing. Every failed attempt preserves byte-for-byte equality and all latches; success installs the candidate once and clears the persistence bundle only after retaining the once-only publication guard. The controller's generic `retry_autosave()` path must not restore the model or emit a gameplay-unblocking recovery action after terminal publication.

All authoritative entry points check phase, not overlay visibility: move, party/formation, recruitment, preparation, battle actions, debug exit, arena close, reward confirmation, discard, menu return and applying another session to this controller. Ordinary autosave behavior remains discardable. A lost transaction is never discardable, including by direct method calls.

Restart outcomes are explicit:

- Successful atomic replacement followed by a crash before callback/menu return: disk contains valid lost V4; Contract S rejects playable loading. The new process does not replay the old controller's return signal.
- Failed write followed by successful Retry: same result and bytes are committed; one callback/return in the live process; reload remains non-playable.
- Failed terminal write followed by forced process termination before any successful write: only the earlier active checkpoint may exist. This is the durability limitation stated above, not an upgrade of a persisted lost state. This revision does **not** claim unconditional crash-proof loss in that case; resolving it would require a product decision on interrupted battles and a pre-battle durable marker. Approval must explicitly accept this boundary or require that additional design before implementation.
- Persisted lost or malformed V4 data: never migrate/fall back to active. Failed New Run replacement also cannot make the lost run playable.

### Review acceptance fixtures

Add table-driven assertions to the named test suites, in addition to their gameplay cases:

| Contract | Required fixtures |
|---|---|
| S | Valid active/empty, active/victories, lost/final-defeat; missing status; unknown/case-changed status; active+defeat; lost without defeat; two defeats; receipt after loss; duplicate receipt; nonzero loss gold; V4 extra/missing keys; fractional/boolean numeric fields; V3 containing lifecycle fields; corrupted V4 never falling back |
| S boundaries | Same valid lost bytes: codec and inspection succeed, playable repository fails `RUN_LOST`, runtime application rejects without mutation, menu disabled; malformed lost bytes fail validation instead; fresh process repeats these results |
| I | Commander ID, same-class distinct IDs, duplicate setup ID rejection, revived enemy recorded once, removed living enemy unpaid, same enemy IDs in distinct encounters paid separately, moving boss remains `boss`, same tuple no-op, changed outcome/HP/IDs conflict, stale arena/session ignored |
| T | First-write success; fail/fail/success with byte equality; repeated and reentrant Retry; direct discard/return/exit during failure; validation failure without Retry; crash after successful write before publication; separate-process lost rejection; failed New Run preserves lost slot |

These are design acceptance fixtures, not executed evidence. The implementation gate remains unapproved until review accepts S, I and T, including the pre-successful-write crash boundary.

### Task 1: Establish the implementation baseline

- [ ] Preserve unrelated working-tree changes, update `main` from origin and create `feat/ac8-2-battle-gold-and-terminal-defeat` in the primary workspace. Include this plan in the task handoff; do not carry or stage unrelated documentation or the existing battle-debug scene edit.
- [ ] Use GodotIQ `project_summary(detail="brief")`, `file_context` for each affected file and `impact_check` before signature/signal changes. Trace codec consumers and arena result/exit listeners using `dependency_graph` and `signal_map`.
- [ ] Run project validation and the baseline runners listed below. Record the known `test_world_runtime_migrated_flows.gd` preview-fixture stall separately; do not count a timeout as a pass.

### Task 2: Freeze battle results and implement award arithmetic

- [ ] Add failing economy assertions for three unique IDs -> 150, duplicate ID -> one payment, defeat with kills -> 0, in-progress -> 0, zero enemies -> 0. The result validator separately rejects invalid enemy identities.

```gdscript
var economy: Script = load("res://Scripts/Run/run_economy_rules.gd")
var ids: Array[StringName] = [&"enemy_1", &"enemy_2", &"enemy_1", &"enemy_3"]
assert(economy.victory_gold(BattleOutcome.Type.VICTORY, ids) == 150)
assert(economy.victory_gold(BattleOutcome.Type.DEFEAT, ids) == 0)
assert(economy.victory_gold(BattleOutcome.Type.IN_PROGRESS, ids) == 0)
```

- [ ] Add the pure rule while retaining `STARTING_GOLD`:

```gdscript
const GOLD_PER_DEFEATED_ENEMY: int = 50

static func victory_gold(outcome: BattleOutcome.Type, enemy_ids: Array[StringName]) -> int:
    if outcome != BattleOutcome.Type.VICTORY:
        return 0
    var distinct: Dictionary[StringName, bool] = {}
    for enemy_id: StringName in enemy_ids:
        if not enemy_id.is_empty():
            distinct[enemy_id] = true
    return GOLD_PER_DEFEATED_ENEMY * distinct.size()
```

- [ ] Implement `BattleResultRecord` as Contract I's sole identity, canonical tuple and receipt validator, with copy-returning accessors. Add `BattleArena.get_terminal_result()` without changing the existing `battle_completed(outcome)` signature. Capture before emitting; reset the record and defeated-ID set during `configure_units()`; invalidate old callback generations before enabling the replacement battle.
- [ ] Test committed default attack, skill and bleed/reaction kills; revival followed by another defeat; living-unit removal; commander defeat; mutated returned snapshots; repeated completion calls and battle reset. Use actual battle actions for integration assertions, not only direct calls to private completion methods.
- [ ] Run the two focused Battle runners and economy runner to green. Validate/check every edited script immediately, then commit the verified result/award slice.

### Task 3: Add V4 lifecycle and durable settlement receipts

- [ ] Add failing state/codec tests for active/lost round-trips, canonical identity changes, deep-copy isolation, malformed receipts, duplicate IDs, inconsistent amounts, invalid status and missing V4 fields.
- [ ] Extend state construction with trailing optional lifecycle/receipt arguments so existing callers remain valid. New runs explicitly initialize active status and an empty receipt collection. Dictionary decoding is strict for the current shape; legacy defaults belong in the codec adapter.
- [ ] Implement Contract S's V4 dispatch and exact key/type checks before constructing state. V4 validation failure returns immediately; only explicitly recognized older versions reach legacy decoding. Extend envelope version checks to `[2, 3, 4]`. Reject lifecycle fields in V2/V3 before supplying active/empty defaults; preserve V2 -> 0g and V3's exact wallet. For V2/V3 encoding, omit V4 fields and reject terminal/settled state to prevent lossy downgrade.
- [ ] Switch the repository, launcher and save coordinator production codec references to V4. Preserve V1's existing compatibility/rejection routing and canonical saved map bytes; no map regeneration.
- [ ] Implement `inspect_slot()` and `load_validated()` exactly as Contract S3, using one validation path and `is_playable()` predicate. Add `RUN_LOST` with constraint `run_status_lost`. Reject terminal `apply_session()` before roster/model mutation. Test each S3 row through every entry point with the same bytes.
- [ ] Test reconstruction through a new repository instance using actual temporary save files. Check the launcher does not emit `session_ready` for a terminal record. Keep `has_save()` as physical existence; use validation for Continue and suppress pointless overwrite confirmation for a verified lost record, while retaining confirmation for active or corrupt existing slots.
- [ ] Run V4/V3/V2, starter-health migration, repository and start-service runners. Validate/check scripts and commit the persistence slice.

### Task 4: Make victory settlement atomic

- [ ] Add failing production-session tests with initial 100g: three defeated enemies -> 250g, two -> 200g, same IDs in a later distinct encounter pay again, same result repeated does not. Verify health recovery and encounter consumption share the wallet's successful write.
- [ ] Introduce `BattleSettlementRules` to build a candidate from durable state, plan and validated result, using existing recovery rules. Validate `current_gold + award <= WorldRunState.MAX_GOLD`; reject overflow unchanged instead of wrapping or silently reducing the confirmed award.
- [ ] Replace the controller's standalone recovery commit with settlement. Build a candidate model/state without mutating the live model first. Ordinary victory consumes the battle coordinate immediately; arena close becomes presentation cleanup and cannot consume or award again. Preserve boss state using the existing model's boss route, with explicit tests instead of assuming ordinary-close behavior applies.
- [ ] Add arena production settlement gating before `_complete_battle()` can show choices. Only successful publication unlocks legacy choices; failed saves, stale results, debug exit, keyboard close and direct reward calls cannot bypass the gate. Standalone debug battle behavior remains usable without a production repository.
- [ ] Inject write failure: gold, HP and encounter state remain at the durable checkpoint; retry sends identical bytes and publishes once. Duplicate result events while blocked do not replace pending data. Reload after success restores the awarded balance and consumed encounter without another battle/award.
- [ ] Run victory settlement, recovery integration, cache/preparation, reward-selection and Scout-recruitment regressions. Update assertions only where atomic timing intentionally changes, keeping legacy choice behavior until AC8.3. Validate/check and commit.

### Task 5: Settle defeat without playable rollback

- [ ] Add failing ordinary/boss-loss tests, each with zero kills and partial kills. Assert unchanged gold, no recovery, no reward selection, one terminal write and one launcher return after success.
- [ ] Extend `commit_candidate()` with an optional `allow_discard: bool = true` and store it alongside pending bytes. Add `can_discard_pending() -> bool`. On non-discardable failure, `discard_pending()` returns null without clearing pending state. `_clear_pending()` resets the flag for unrelated future transactions.
- [ ] Implement Contract T's phases and frozen bundle; submit defeat with `allow_discard = false`. Capture bytes before I/O and offer Retry only for an I/O failure with retained bytes. Latch publication and launcher return before callbacks; retry must not then restore a world snapshot or reopen battle controls. Run every T fixture, including failure before valid encoding and reentrant Retry.
- [ ] Guard controller discard and return handlers before any model mutation or signal emission. Guard `_on_battle_closed()` against pending or settled loss. A stale exit signal cannot consume the encounter and overwrite terminal state with an active save.
- [ ] Extend overlay `present(error, build_version, allow_return: bool = true)`. For terminal failure, hide/disable Return, retain Retry and diagnostics, and show `Run lost. Saving the result failed. Retry to return to the main menu.` Its return handler must check the mode as well. Reset mode on later ordinary presentations.
- [ ] Test failing twice then succeeding, repeated defeat events, direct discard calls, direct return calls, debug exit, reward confirmation and movement during pending loss. Confirm no live rollback, no gold, identical retry bytes and one return. Verify ordinary autosave discard still works.
- [ ] Explicitly refresh Continue on launcher world return even if `_screen` is already MAIN. New Run after loss must replace the slot atomically with fresh 100g/roster/progress and empty receipts; a failed new-run write leaves the lost record rejected.
- [ ] Validate/check scripts, run defeat/coordinator/overlay/launcher suites and commit.

### Task 6: Verify restart, regressions and runtime behavior

- [ ] Exercise real file persistence across fresh processes, not just in-memory repository doubles: write a terminal run, exit the runner, then launch a separate reader process and reject Continue/domain loading. Use a test-specific path and never overwrite `user://active-world-run.json` during automated tests.
- [ ] Run the focused and regression suites below; require exit code 0, runner PASS and no parser/runtime errors. Record known baseline failures separately and investigate any new failure caused by the change.
- [ ] GodotIQ: `run(action="play")` -> `verify_project_runs()` -> debug console -> state inspection. Verify ordinary victory balance/recovery, ordinary defeat, boss defeat, duplicate callbacks, terminal save failure/Retry and fresh New Run through production launcher input.
- [ ] Inspect a screenshot of the retry-only overlay and main menu with Continue disabled; inspect the HUD after victory. Capture only those visual verification points. Stop the game after verification.
- [ ] Write `Docs/Specs/AC8/Evidence/AC8.2/verification.md` with commit, commands, results and screenshots; include `.gdignore` in the evidence directory. Update the parent plan and MVP AC8.2 status only after passing evidence. Keep AC8.3-AC8.8 unchecked.
- [ ] Commit only relevant implementation, tests and evidence. Restore unrelated changes without staging them. Push only when remote handoff is requested.

## Test commands and acceptance mapping

Use the executable recorded by AC8.1. Run each runner independently with a timeout and inspect its output; a nonzero exit or script error is a failure even if another runner passes.

```powershell
$godotExe = 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
& $godotExe --headless --path . --script res://Tests/Run/test_ac8_economy.gd
& $godotExe --headless --path . --script res://Tests/Battle/test_ac8_2_battle_result_record.gd
& $godotExe --headless --path . --script res://Tests/Run/test_ac8_2_run_settlement_state.gd
& $godotExe --headless --path . --script res://Tests/Run/test_ac8_2_battle_settlement_rules.gd
& $godotExe --headless --path . --script res://Tests/Save/test_world_run_save_codec_v4.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac8_2_victory_settlement.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac8_2_defeat_ends_run.gd
```

Run the same command form for these existing regressions:

```text
Tests/Battle/test_ac2_4_battle_results.gd
Tests/Battle/test_ac2_5_reward_selection.gd
Tests/Run/test_ac3_5_post_battle_recovery.gd
Tests/Run/test_world_run_start_service.gd
Tests/Run/test_world_single_slot_repository.gd
Tests/Run/test_world_production_launcher.gd
Tests/Save/test_world_run_save_codec_v3.gd
Tests/Save/test_world_run_save_codec_v2.gd
Tests/Save/test_goblin_starter_save_migration.gd
Tests/Save/test_world_save_store.gd
Tests/WorldMap/test_world_runtime_save_coordinator.gd
Tests/WorldMap/test_world_production_scene.gd
Tests/WorldMap/test_world_runtime_scene.gd
Tests/WorldMap/test_world_runtime_model.gd
Tests/WorldMap/test_world_battle_entry.gd
Tests/WorldMap/test_ac8_1_gold_runtime.gd
Tests/WorldMap/test_ac3_5_recovery_integration.gd
Tests/WorldMap/test_ac6_6_runtime_integration.gd
Tests/WorldMap/test_scout_recruitment_flow.gd
Tests/UI/test_world_autosave_failure_overlay.gd
```

| Acceptance | Evidence |
|---|---|
| 50g per distinct defeated enemy, including commander | Economy/result-record tests plus ordinary/boss victory integration |
| Revival, duplicate events and repeated callbacks pay once | Battle identity tests, settlement tests and reloaded receipts |
| Award, recovery and encounter completion are atomic | Failed-write candidate comparison and retry tests |
| Ordinary/boss loss with partial kills awards zero | Defeat integration and production runtime observations |
| Exactly one return; no recovery or playable rollback | Duplicate-result, direct-discard, exit and retry tests |
| Lost run rejected after restart | Separate-process repository/launcher tests with real files |
| New Run is fresh and starts at 100g | Launcher/start-service tests, including same-seed replacement |
| Older saves preserve their existing state | V2/V3 migration and health regressions |

Final gate: project-wide GodotIQ validation, project error check and orphan-signal inspection after the refactor, plus the recorded runtime evidence. This document is a plan, not evidence that AC8.2 passes.
