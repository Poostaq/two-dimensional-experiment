# AC9.1 Clan Selection and Direct Start Design

**Acceptance criteria:** AC9.1 and the directly dependent AC9.9 launch behavior.

**Status:** Approved for implementation planning on 2026-09-26.

## Goal

Before a new world is created, the player selects a playable main clan, then a commander belonging to that clan, and may optionally supply a seed. Invalid clan/commander combinations are rejected. Pressing Start creates and atomically persists the candidate run immediately; an existing save never causes an overwrite-confirmation screen.

## Scope

This delivery owns only setup validation and the direct Start transaction. It does not select AC9.2 allies or the AC9.3 enemy clan, generate habitats/towns/roads, change generator versions, or add AC10 behavior. The selected configuration is deliberately the typed input those later AC9 systems will consume.

## Architecture

Add `RunClanSelection` as a typed, immutable setup value containing `main_clan_id`, `commander_id`, and normalized optional seed text. Extend the existing `RunCharacterCatalog` with `get_playable_clans()` and `get_player_commander_ids_for_clan(clan_id)`; it remains the sole authority for playable clan order, commander ownership, and presentation. Do not add a parallel `ClanCatalog`. UI code must never derive a clan from a localized label, portrait, or commander-name prefix.

`WorldProductionLauncher` owns presentation state only. It presents clans in stable catalog order, resets the selected commander to the first valid commander whenever the clan changes, and renders only that clan's commander choices. Start forwards the currently visible clan, commander, and seed to `WorldRunStartService`.

`WorldRunStartService` constructs and validates `RunClanSelection` before it generates a candidate session. The UI and service share this one factory/validation path; neither keeps a second ownership map. It includes the validated selection in initial run state/session data and passes the completed serialized candidate to the existing `WorldSingleSlotRepository.replace_atomic()` path. The service does not mutate the repository before validation, generation, serialization, and commit are all successful.

## Direct-start behavior

The launcher adds `_start_in_flight: bool`. It removes `OVERWRITE_CONFIRM`; the `OverwriteDimmer` and `OverwriteCenter` scene subtree; the `OverwriteScreen`, `OverwriteDimmer`, `OverwriteCenter`, `OverwriteConfirmButton`, and `OverwriteCancelButton` node references; `_pending_seed` and `_pending_commander_id`; and `confirm_overwrite`, `cancel_overwrite`, `on_overwrite_confirm_pressed`, and `on_overwrite_cancel_pressed`. Remove the two scene signal connections targeting the deleted confirm/cancel handlers, then run `signal_map(find="orphans")` to prove no stale wiring remains. A Start request does the following:

1. Reject while another Start request is in flight, leaving the UI and current save unchanged.
2. Validate the raw clan ID, commander ID, and seed through `RunClanSelection` and `RunCharacterCatalog`.
3. Generate and assemble the candidate session without replacing the current save.
4. Serialize and atomically replace the single save only after the candidate is complete and valid.
5. On success, emit `session_ready` once and transition into the generated world.
6. On any failure, emit the existing failure presentation, re-enable Start, and preserve the prior save byte-for-byte.

Continue remains independent: it loads the saved run and does not revalidate, reroll, or replace the saved selection.

## Data and save contract

`RunClanSelection` uses stable `StringName` IDs for clan and commander. Its factory returns the repository's established result/error shape instead of throwing or returning a partial object. It rejects: an empty or unknown clan, an empty or unknown commander, a commander owned by another clan, and a clan with no selectable commander. The optional seed preserves the existing normalization behavior; a blank seed remains valid and is resolved once by the start service.

Initial session/run state persists `main_clan_id`, `commander_id`, and the resolved seed. Save schema V6 writes `main_clan_id` and `commander_id` as required stable strings in the root `world` object, alongside `resolved_seed` and the canonical plan. Create `WorldRunSaveCodecV6`; make it the production codec at the launcher/repository/runtime-save boundaries; and extend `WorldRunSaveEnvelope.encode/decode/_valid_current_shape` to accept V6 and its two required fields. V6 dispatches directly to the V6 envelope shape; unknown or cross-clan values fail decode. Its fallback delegates to V5, preserving exact V2–V5 decode behavior. AC9.2+ will extend V6 or a later version with allied/enemy selections; this delivery does not invent placeholder fields.

## File responsibilities

- Create `Scripts/Run/run_clan_selection.gd`: typed validated setup value and construction failure contract.
- Modify `Scripts/Run/run_character_catalog.gd`: ordered playable-clan API and clan-filtered commander lookup, built from its existing commander/faction mapping.
- Modify `Scripts/Run/world_production_launcher.gd` and `Scenes/world_run_start.tscn`: clan control, filtered commander presentation, `_start_in_flight` protection, and the enumerated overwrite-confirmation removal.
- Modify `Scripts/Run/world_run_start_service.gd`: validate a selection before candidate generation and carry it into the initial session/run state.
- Create `Scripts/Save/world_run_save_codec_v6.gd` and modify `Scripts/Save/world_run_save_envelope.gd`: V6 root-world selection persistence and explicit V6-to-V5 fallback dispatch.
- Create `Tests/Run/test_ac9_clan_selection.gd`: catalog, invalid-pair, launcher filtering, direct Start, duplicate submission, and failure-preservation coverage.
- Create `Tests/Save/test_world_run_save_codec_v6.gd`: exact V6 selection round-trip, missing/unknown/cross-clan field rejection, and V2–V5 decode regressions. Extend the closest launcher/repository/save runners only for regression coverage of their unchanged contracts.

## Verification

Automated tests must prove all five AC9.0 player clans are selectable in stable order; every catalog commander is accepted only by its owning clan; forged or unknown pairs fail without a save mutation; a blank and an explicit seed both produce one validated start request; an existing save goes directly to generation with no confirmation screen; concurrent/repeated Start input creates at most one replacement; and generator, V6 encoder, or store failures preserve prior bytes. Codec tests must prove V6 round-trips both selection IDs and that unchanged V2, V3, V4, and V5 fixtures still decode through V6's fallback chain.

Run focused headless SceneTree tests, then existing launcher, repository, save-codec, and AC9.0 commander-restoration regressions. Validate each changed script and run a GodotIQ launch inspection at 1152x648 and 1920x1080: select each clan, confirm its commander carousel contains no foreign commander, start over an existing save without a modal, and inspect the debug console for zero parser/runtime errors.

## Risks and controls

The main risk is duplicating catalog ownership logic in UI and service layers. Extending `RunCharacterCatalog` prevents that: the service validates only by constructing `RunClanSelection`, never by maintaining a second map. The main transactional risk is deleting a save before a failed candidate is complete; the design retains the repository's atomic replacement seam and treats all pre-commit values as ephemeral.

## Acceptance mapping

- **AC9.1:** a player chooses a main clan and an owning commander before new-world creation; invalid combinations are rejected.
- **AC9.9 portion included here:** no overwrite confirmation follows selection, one successful Start performs one atomic replacement, and all failures preserve the previous save.
