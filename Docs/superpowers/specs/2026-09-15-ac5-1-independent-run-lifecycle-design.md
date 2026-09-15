# AC5.1 Independent Run Lifecycle Design

## Goal

Integrate the existing single-slot run lifecycle so Continue Run restores the last durable session, while Start New Run requires confirmation before atomically replacing an existing session with a fresh seeded run whose roster and mutable run state are independent.

## Scope

AC5.1 covers new-run creation, overwrite confirmation, continuation of the last session, atomic replacement, and isolation of all run-owned state. It does not add meta-progression, multiple save slots, a global run-session autoload, or AC5.3 reproducibility guarantees beyond retaining the existing seed behavior.

## Architecture

`WorldProductionLauncher` remains the UI and lifecycle coordinator. It queries `WorldSingleSlotRepository` to decide whether Continue Run is available and whether Begin must enter overwrite confirmation. It delegates new-run construction to `WorldRunStartService` and durable replacement to the repository.

`WorldRunStartService` constructs a complete fresh `WorldRunState` from the requested seed and commander. The service must not read or merge the previous save. `WorldSingleSlotRepository.replace_atomic()` remains the only replacement boundary, so the old session survives generation, encoding, or write failures.

No autoload is introduced. Run ownership stays within the existing launcher, repository, runtime model, and save-coordinator boundaries.

## State Ownership and Checkpoint Boundary

The single-slot file is a durable world checkpoint, not a serialization of every live node. Save V2 owns the generated plan, resolved seed, and `WorldRunState`. `WorldRunState` owns player and boss coordinates, move count, boss lifecycle, consumed encounters, six formation IDs, character HP, Quartermaster cache state, and committed battle preparation.

The active battle arena owns combat turns, current battle units, cooldowns, action history, target selection, reward presentation, and unconfirmed reward choice. Launcher confirmation fields and save-coordinator pending bytes/callbacks are also process-local. None of these transient values are encoded. A save is committed only at an existing world checkpoint after a completed state transition; AC5.1 does not add mid-battle or mid-reward saves.

Consequently, Continue Run restores the last durable world checkpoint exactly. If the application closes during an active battle or unconfirmed reward screen, Continue Run returns to the world checkpoint committed before that transient flow. It does not resume the battle or reward UI.

Slot presence and session validity are distinct:

- `has_save() == true` means bytes exist at the single-slot path and is sufficient to require overwrite confirmation.
- A resumable session exists only when `load_validated()` returns `ok == true` with a decoded plan, non-empty resolved seed, and valid `WorldRunState` compatible with the plan.
- The launcher calls `load_validated()` while refreshing the main menu: once during `_ready()` and every time `_set_screen(Screen.MAIN)` makes Main active. Continue is enabled only when that call returns `ok == true`; it is disabled for a missing, corrupt, legacy, or unsupported slot.
- Main-menu validation is read-only and does not emit `launch_failed` or show the failure overlay. It only sets Continue availability. Direct `continue_saved_run()` calls still validate again to prevent a time-of-check/time-of-use gap.
- Invalid bytes still make `has_save() == true`, so Start New Run requires explicit overwrite confirmation. Cancel preserves those bytes; Confirm may replace them atomically.

## Signal and Transition Ordering

Godot signal delivery is synchronous in this flow. `session_ready` means that a validated session is available to launch; it does not mean the world scene has already opened. The launcher's internal `_on_session_ready` listener is intentionally the mechanism that creates and applies the world during the `emit()` call.

- Continue success: validate and decode → emit `session_ready(session)` → `_on_session_ready` instantiates the world, adds it to `WorldHost`, applies the session, and hides the launcher surface → return session success. No screen change occurs; Main remains the logical return target while hidden.
- New-run success: generate and validate → encode → complete atomic replacement → emit `session_ready(session)` → `_on_session_ready` instantiates/applies the world and hides the launcher surface → return session success. No `session_ready` may precede the durable write.
- Continue load failure: emit `launch_failed(error)` so the synchronous listener presents the failure overlay → establish `Screen.MAIN` → return failure. No world is created and no write occurs.
- Begin or Confirm generation/persistence failure: emit `launch_failed(error)` → establish `Screen.NEW_RUN` → return failure. Confirm has already consumed its pending input.
- Cancel: clear pending confirmation → set `Screen.NEW_RUN` and emit its `screen_changed` notification synchronously → return without `session_ready` or `launch_failed`.
- World instantiation or `apply_session()` failure: `session_ready` has already fired because the session itself is valid. `_on_session_ready` removes the unusable world and synchronously emits `launch_failed(error)`. The launcher surface remains visible on the operation's logical screen. Observers receive exactly one `session_ready` followed by exactly one `launch_failed`. The public operation still reports session success because persistence or validation succeeded; `launch_failed` is the authoritative presentation-failure result.

## Operation Contracts

### Continue Run

- Input: no arguments; current repository slot.
- Session success: follows the success ordering above, returns `{ok: true, value: session, error: null}` and emits `session_ready(session)` exactly once. `session` contains `plan`, `resolved_seed`, and `run_state`.
- Load failure: follows the failure ordering above, returns `{ok: false, value: null, error: typed_error}`, emits `launch_failed(typed_error)` exactly once, ends on Main with Continue disabled, emits no `session_ready`, and performs no write.
- World-application failure after session success: keeps the launcher visible, returns the session-success dictionary, emits one `session_ready` followed by exactly one `launch_failed`, and performs no write. Consumers use `launch_failed`, rather than the returned session result, to detect this presentation failure.

### Begin New Run

- Input: seed text and a commander ID from `GoblinCommanderCatalog`; blank seed text is resolved to non-empty generated seed text.
- Invalid commander: returns `{ok: false, confirmation_required: false, error: typed_error}`, generates nothing, writes nothing, and launches nothing.
- No slot bytes: constructs and persists immediately. Success follows the new-run success ordering, returns `{ok: true, value: session, error: null}`, and emits `session_ready` once. Generation or persistence failure emits `launch_failed` once, establishes `NEW_RUN`, returns `{ok: false, error: typed_error}`, and emits no session.
- Existing slot bytes, whether valid or corrupt: writes nothing, stores only the resolved seed and commander as pending launcher state, changes to `OVERWRITE_CONFIRM`, and returns `{ok: false, confirmation_required: true, error: null}`.

### Cancel Overwrite

- Input: current overwrite-confirmation state.
- Result: clears pending seed and commander, returns to `NEW_RUN`, emits no session or failure, and performs zero repository writes. A later Confirm without a new Begin request must fail closed.

### Confirm Overwrite

- Input: pending seed and commander established by Begin while on `OVERWRITE_CONFIRM`.
- Invalid state or missing pending input: returns `{ok: false, confirmation_required: false, error: null}`, emits nothing, and writes nothing.
- Success: consumes pending input once, builds a fresh session, atomically replaces the slot, returns `{ok: true, value: session, error: null}`, and emits `session_ready` exactly once.
- Generation or replacement failure: consumes pending input, emits `launch_failed` once, returns to `NEW_RUN`, and returns `{ok: false, value: null, error: typed_error}`. It emits no session and preserves the prior durable bytes, so retry requires another Begin request and confirmation.

## User Flow

1. On the main menu, Continue Run is enabled only when a valid single-slot session exists.
2. Continue Run loads and validates that session, then launches its last durable world checkpoint.
3. Start New Run opens the existing seed and commander configuration screen regardless of save presence.
4. With no existing session, Begin generates, validates, saves, and launches the new run directly.
5. With an existing session, Begin retains the requested seed and commander only as pending launcher state and opens the overwrite confirmation.
6. Cancel closes confirmation and returns to run configuration without changing the durable session.
7. Confirm constructs and encodes the fresh run, then replaces the old slot atomically.
8. If confirmation fails, the previous session remains loadable and the launcher presents the existing failure handling.

## Independence Contract

A replacement run starts exclusively from its requested seed, selected commander, and canonical starter roster. None of the following may carry over from the prior session:

- recruited or dismissed characters;
- formation slot assignments beyond the new starter formation;
- character HP snapshots;
- player or boss coordinates;
- move count, sudden-death state, or boss engagement state;
- consumed encounters;
- Quartermaster cache progress or readiness;
- committed battle preparation;
- transient battle, reward, selection, or pending-save state.

Continue Run must restore those durable fields from the existing checkpoint rather than resetting them. Active combat, unconfirmed rewards, UI selection, launcher pending confirmation, and save-coordinator pending transactions are excluded because they are never part of a committed checkpoint.

## Failure Handling

New-run construction and validation occur before durable replacement. Cancel never invokes replacement. Invalid or corrupt existing saves follow the repository's validated-load error path and are not silently treated as resumable sessions. Generation failure or atomic-write failure leaves the previous bytes intact and prevents launch of a partially created run. The current Save V2 encoder is synchronous and does not expose a failure result, so AC5.1 does not invent a separate encoding-error state.

## Verification

Create `Tests/Run/test_ac5_1_independent_run_lifecycle.gd` as the focused acceptance runner. It will use an isolated `user://tests/ac5-1-independent-run/active-world-run.json` slot, real Save V2 encoding/decoding, the real repository, and launcher/service spies only at injected process boundaries. Its named cases and observable assertions are:

- `test_continue_restores_last_durable_checkpoint`: decoded seed and `WorldRunState.canonical_key()` equal the fixture; exactly one `session_ready`; zero writes.
- `test_continue_rejects_corrupt_slot`: typed load error; exactly one `launch_failed`; zero sessions and writes; corrupt bytes unchanged.
- `test_main_menu_disables_continue_for_invalid_slot`: initial ready and return-to-Main refresh each call validated load; valid fixture enables Continue; missing, corrupt, legacy, and unsupported fixtures disable it without emitting a failure or mutating bytes.
- `test_begin_without_slot_commits_directly`: no confirmation; one generated session; one atomic write; canonical initial state.
- `test_begin_with_slot_requires_confirmation`: `OVERWRITE_CONFIRM`; pending seed and commander retained; old bytes unchanged; no session.
- `test_cancel_preserves_slot_and_consumes_pending_request`: returns to `NEW_RUN`; bytes unchanged; subsequent Confirm emits nothing and writes nothing.
- `test_confirm_replaces_once_with_fresh_state`: replacement seed and commander are used; one session and write; second Confirm is rejected without another write.
- `test_failed_generation_preserves_previous_session`: typed generation error; old bytes still decode to the original canonical key; no session emitted.
- `test_failed_atomic_replace_preserves_previous_session`: typed persistence error; old bytes still decode to the original canonical key; no session emitted.
- `test_replacement_does_not_carry_run_state`: replacement has canonical starter formation and initial coordinates, move count, boss flags, encounters, HP provenance, cache, and preparation despite the old fixture containing non-default values and a recruited character.
- `test_lifecycle_signal_ordering`: `session_ready` observers see replacement bytes already committed; after synchronous signal delivery completes, the internal listener has applied the world and hidden the launcher. World-application failure keeps the launcher visible and records `session_ready` followed by `launch_failed`. Load, generation, and persistence failures record only `launch_failed` and end on their documented screen.

Add `Tests/Fixtures/Run/AC5.1/progressed-session-v2.json` as a fixed valid Save V2 fixture containing a non-default seed, recruited character, rearranged formation, HP snapshot, consumed encounter, advanced movement/boss state, cache progress, and committed preparation. Add `Tests/Fixtures/Run/AC5.1/corrupt-session.json` as invalid JSON bytes. Fixture hashes are recorded with the evidence so accidental fixture drift fails review.

Regression coverage will run `Tests/Run/test_world_production_launcher.gd`, `Tests/Run/test_world_run_start_service.gd`, `Tests/Run/test_world_single_slot_repository.gd`, `Tests/UI/test_world_run_start_scene.gd`, `Tests/Save/test_world_run_save_codec_v2.gd`, `Tests/WorldMap/test_world_runtime_model.gd`, `Tests/WorldMap/test_world_runtime_save_coordinator.gd`, `Tests/Run/test_ac3_1_run_roster.gd`, `Tests/Run/test_ac3_3_party_formation.gd`, `Tests/Run/test_ac3_5_post_battle_recovery.gd`, `Tests/WorldMap/test_ac3_5_recovery_integration.gd`, `Tests/Battle/test_ac6_5_brakka.gd`, and `Tests/WorldMap/test_ac6_7_goblin_integration.gd`.

Manual runtime verification will load the progressed fixture through the production main scene and record the seed, formation IDs, HP, move count, and consumed encounter shown by `state_inspect`. Continue Run must reproduce those values. The reviewer then returns to the main menu, requests a different seed, cancels once, and proves Continue still restores the original values. Finally the reviewer confirms overwrite and records that the new seed is active, only the canonical starters occupy their configured formation slots, and move count, encounters, HP provenance, cache, and preparation are initial. The debug console must contain no parser or runtime errors.

## Acceptance Boundary

AC5.1 is complete only when the same tested implementation commit has focused automated lifecycle evidence, regression evidence, GodotIQ validation and error checks, and a manual main-menu proof of continuation plus confirmed independent replacement. The criterion remains incomplete if cancellation mutates the old session, failures destroy it, any prior run-owned state leaks, or Continue Run resets the saved session.
