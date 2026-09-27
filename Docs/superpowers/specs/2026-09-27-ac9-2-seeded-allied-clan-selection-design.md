# AC9.2 Seeded Allied Clan Selection Design

**Acceptance criterion:** AC9.2.

**Status:** Approved for implementation planning on 2026-09-27.

## Goal

After AC9.1 validates the player-selected main clan and commander and resolves the run seed, select exactly two distinct other playable clans. At least one selected ally must have an explicit main-clan-directed synergy. New runs persist the result, and Continue restores it without invoking selection again.

## Scope

This delivery owns playable-clan synergy data, deterministic allied-pair selection, immutable coalition validation, new-run integration, and durable save/restore of the selected allies. It is based on merged AC9.1 commit `89bcbf0`, including `RunClanSelection`, `WorldRunSaveCodecV6`, and the V6 envelope shape.

It does not select the AC9.3 enemy clan; create habitats, towns, roads, or a new world generator; change encounter composition; add coalition presentation; or reinterpret legacy worlds. AC9.4 and later systems will consume the persisted coalition.

## Catalog authority and synergy data

`RunCharacterCatalog` remains the sole clan authority established by AC9.1. Do not add the parallel `ClanCatalog` proposed by the older aggregate AC9 plan.

Add a `PLAYABLE_CLAN_IDS` constant and `get_playable_clan_ids() -> Array[StringName]`, returning `PLAYABLE_CLAN_IDS.duplicate()`. Keep AC9.1's `get_playable_clans()` as a compatibility wrapper that delegates to the new canonical API. The selector, coalition, and new tests use `get_playable_clan_ids()`; no new code relies on an ad hoc literal ordering.

Add directed synergy data keyed by the main clan. `get_synergistic_clan_ids(main_clan_id)` returns a defensive duplicate in canonical clan order, and `has_main_clan_synergy(main_clan_id, partner_clan_id)` is the sole boolean query. Direction is intentional: only the selected main clan's list determines whether a pair satisfies AC9.2. Do not infer reverse relationships or parse lore at runtime.

| Main clan | Synergistic partners |
|---|---|
| Goblin | Orc, Werewolf, Lizardman |
| Orc | Goblin, Lizardman, Harpy |
| Lizardman | Orc, Werewolf, Goblin |
| Harpy | Goblin, Orc, Werewolf |
| Werewolf | Goblin, Lizardman, Harpy |

Catalog APIs return typed duplicate arrays in established playable-clan order. Callers cannot mutate the catalog's source data. Unknown or non-playable clan IDs return an empty result and never become eligible through fallback behavior.

With the approved five-clan pool, each main clan has three synergistic partners and only one non-synergistic alternative. Consequently, every two-clan pair from the four eligible alternatives already contains at least one synergy. The implementation still filters and validates this invariant explicitly so later catalog expansion cannot weaken AC9.2 silently; tests prove the production matrix and every selected pair rather than inventing a currently impossible all-non-synergistic production pair.

## Coalition value

Add `RunClanCoalition`, an immutable validated value representing one main clan and exactly two selected allies. Its factory is the single validation path used by new-run selection and V7 save decoding. It rejects:

- an unknown or non-playable main clan;
- an ally array whose size is not exactly two;
- an unknown or non-playable ally;
- duplicate allies or the main clan repeated as an ally; and
- a pair containing no clan from the main clan's directed synergy list.

The value exposes defensive copies of `allied_clan_ids` and the combined three-clan identity list. The factory also rejects an otherwise valid pair when its IDs are not ascending by current `get_playable_clan_ids()` index. Ally order is therefore canonical catalog order, not a first-choice or priority semantic.

## Deterministic selection

Add `RunAlliedClanSelector` as a pure, stateless selector. It receives a validated main clan ID and AC9.1's already-resolved seed string. It never normalizes, generates, or mutates a seed itself.

Selection follows this fixed contract:

1. Read playable clans in catalog order and exclude the main clan.
2. Enumerate every unordered two-clan combination in that order.
3. Retain combinations containing at least one clan in the main clan's directed synergy list.
4. Build the exact ASCII payload `twde-ac9|v=1|seed=<resolved-seed-hex>|ns=ac9-allied-clans-v1|main=<main-clan-id>`, where `<resolved-seed-hex>` is `WorldPriority.seed_hex(resolved_seed)`.
5. Select `hash % valid_pair_count` and construct a `RunClanCoalition` through its factory.

The selector computes the hash only with `WorldPriority.fnv1a32_ascii(payload)`, rather than `RandomNumberGenerator`, shuffle state, or mutable call order. Pair selection is therefore reproducible across preview, retry, and restart boundaries. Changing the payload contract requires a new version and namespace rather than silently changing V1 outcomes.

Enumerating valid pairs before selection avoids the bias of first selecting a guaranteed synergy partner and then selecting a second ally. Two synergistic allies are valid. An empty valid-pair set is a typed failure; the selector never duplicates a clan or relaxes the synergy constraint.

## New-run data flow

AC9.1's `WorldProductionLauncher` already resolves a concrete nonempty seed before creating `RunClanSelection`; AC9.2 preserves that ownership. `WorldRunStartService` receives the validated selection and treats `selection.seed_text` as the resolved seed.

Its AC9.2 sequence is:

1. Revalidate or construct `RunClanSelection` using the established AC9.1 path.
2. Invoke `RunAlliedClanSelector.select(selection.main_clan_id, selection.seed_text)` exactly once.
3. If selection fails, return its `WorldGenerationError` before `_generator.generate()` or the commit callback.
4. Generate the unchanged V1 world and assemble the candidate run state.
5. Return both `selection` and `coalition` in the successful candidate result.
6. Let the launcher encode that complete candidate as V7 and atomically replace the durable save.

Add an optional selector dependency to `WorldRunStartService._init` alongside the existing generator dependency so focused tests can prove the selector input, exactly-one invocation, and pre-generation failure behavior without mutable globals. World generation remains unchanged in this delivery because habitats do not exist until AC9.4. The coalition is immutable run identity metadata, not mutable `WorldRunState` data. UI preview paths do not invoke selection. Continue restores persisted identities and never selects or rerolls V7 allies.

## Save and compatibility contract

Create `WorldRunSaveCodecV7`. Its encoder accepts `(plan, resolved_seed, run_state, selection, coalition)` and V7 extends AC9.1's V6 root `world` object with:

```text
"allied_clan_ids": ["<ally-1>", "<ally-2>"]
```

The field is required and contains exactly two stable clan-ID strings in canonical catalog order. V7 encoding accepts only a valid `RunClanCoalition` matching the persisted `main_clan_id`. V7 decoding reconstructs the coalition through the shared factory and returns it with the plan, resolved seed, run state, main clan ID, and commander ID.

`WorldRunSaveEnvelope` accepts versions 2 through 7. V6 and V7 both require the AC9.1 main-clan and commander fields; only V7 requires `allied_clan_ids`. Its V7 decoder validates those fields by constructing `RunClanSelection` and then `RunClanCoalition`. The exact V7 world-key list is the V6 list plus `allied_clan_ids`; additional or missing keys fail shape validation atomically.

V7 falls back explicitly to V6, preserving the existing V2-V6 dispatch chain. V6 and earlier saves remain readable. A V6 continued run retains its V6 selection and re-encodes as V6 during autosave; it is never silently assigned allies. V5-or-earlier sessions retain their existing V5 autosave behavior.

New-run launcher writes use V7. Repository reads use V7's decode chain. Runtime persistence becomes context-aware: `WorldRuntimeController` passes optional `selection` and `coalition` from the loaded/new session to `WorldRuntimeSaveCoordinator`; the coordinator writes V7 when both are valid, V6 when only a selection is valid, and V5 when neither exists. Existing bytes are never rewritten merely because they were loaded.

## Failure behavior

Selection returns the established `WorldGenerationError` result shape. Every selector failure uses code `WORLD_GENERATION_INTERNAL_ERROR`, the resolved seed hex, generator version `1`, namespace `allied-clan-selection`, and exactly one of these constraints: `invalid_main_clan_id`, `eligible_pool_too_small`, `no_valid_allied_pair`, or `coalition_invalid`. Focused fixtures assert every field. `RunClanCoalition` may retain its narrow factory error strings internally, but only the selector boundary emits the typed runtime error.

Selection failure occurs before world generation and before any save mutation. V7 encoding rejects inconsistent or invalid identity metadata with no partial bytes. Decode rejects missing, malformed, duplicate, unknown, main-repeated, or out-of-order ally fields and applies the shared synergy validation. Generation, encoding, store, or replacement failure preserves the prior save byte-for-byte under AC9.1's atomic transaction.

## File responsibilities

- Modify `Scripts/Run/run_character_catalog.gd`: `PLAYABLE_CLAN_IDS`, canonical `get_playable_clan_ids()` API, AC9.1 compatibility wrapper, explicit directed synergy map, and defensive-copy query APIs.
- Create `Scripts/Run/run_clan_coalition.gd`: shared immutable coalition validation and typed accessors.
- Create `Scripts/Run/run_allied_clan_selector.gd`: versioned, stateless valid-pair enumeration and seeded selection.
- Modify `Scripts/Run/world_run_start_service.gd`: inject/call the selector after AC9.1 selection validation, map exact selector errors, and carry coalition metadata through candidate creation.
- Create `Scripts/Save/world_run_save_codec_v7.gd`: V7 encode/decode and explicit V6 fallback.
- Modify `Scripts/Save/world_run_save_envelope.gd`: exact V7 shape and coalition field serialization/deserialization.
- Modify `Scripts/Run/world_production_launcher.gd`: use V7 for new candidates and include `coalition` in the emitted session.
- Modify `Scripts/Run/world_single_slot_repository.gd`: make V7's decode chain the repository reader.
- Modify `Scripts/WorldMap/world_runtime_controller.gd` and `Scripts/WorldMap/world_runtime_save_coordinator.gd`: carry immutable save identity through runtime persistence and select the V5/V6/V7 writer without losing legacy metadata.
- Create `Tests/Run/test_ac9_2_allied_clan_selection.gd`: canonical-order, defensive-copy, coalition, selector, exact-error, deterministic replay, and reachability tests.
- Extend AC9.1 start/launcher tests for one-time selection, pre-generation failure, candidate propagation, and new-run V7 persistence.
- Create `Tests/Save/test_world_run_save_codec_v7.gd`: V7 round-trip, malformed identity rejection, canonical-order rejection, V6 preservation, and V2-V5 fallback regressions.

## Verification and traceability

| AC9.2 obligation | Classification | Verification path | Passing evidence |
|---|---|---|---|
| Select exactly two other clans | Logic | Selector corpus covers every playable main clan | Every result has two allies and excludes the main clan |
| All three identities are distinct | Logic | Coalition factory rejection cases plus selector corpus | Duplicate and main-repeated inputs fail; produced coalitions contain three unique IDs |
| At least one ally is synergistic | Logic | Exact directed catalog matrix and every selected pair checked against it | Every coalition contains a listed main-directed partner |
| Use explicit catalog synergy data | Logic | Canonical-order and defensive-copy tests plus the exact five directed lists | Catalog order is stable; caller mutation cannot change later results |
| Use the resolved run seed | Integration | Start-service selector spy captures launcher-resolved blank and explicit seed starts | Selector receives AC9.1's one resolved nonempty value exactly once |
| Selection is random but reproducible | Logic | Exact-payload golden fixtures, same-input replay, interleaved-call test, and 4,096-seed corpus per main clan | Fixtures remain stable; every valid pair is observed without call-order dependence |
| Restore rather than reroll | Persistence | V7 round-trip and Continue test with selector spy | Stored allies survive reload and selector call count remains zero |
| Reject invalid durable identities | Persistence | Missing, wrong-size, duplicate, unknown, main-repeated, and out-of-order V7 fixtures; all decoded coalitions pass shared synergy validation | Each malformed save fails with the expected typed constraint |
| Preserve old saves | Integration | V2-V5 fallback, V6 selection restoration, and V6 autosave writer regression suites | Existing fixtures decode and legacy sessions retain their original writer contract |

Focused SceneTree tests run first, followed by affected launcher, repository, runtime-save, AC9.1, and codec regression suites. Each changed script receives GodotIQ `validate` and `check_errors`; project verification includes `check_errors(scope="project")`, `signal_map(find="orphans")`, and a headless launch smoke check. AC9.2 has no scene or presentation changes, so screenshot or visual-tour evidence is not required.

## Risks and controls

The main determinism risk is consuming mutable RNG state or relying on incidental array ordering. Pure pair enumeration, a versioned namespace, catalog-order canonicalization, and golden fixtures make the selection contract explicit.

The main ownership risk is duplicating clan eligibility or synergy rules across selector, service, and codec. `RunCharacterCatalog` owns data and `RunClanCoalition` owns invariants; service and codec call those authorities instead of reproducing maps.

The main compatibility risk is adding required fields to an already shipped V6 shape. V7 isolates the new contract and leaves legacy decode behavior unchanged. Legacy runs remain legacy rather than receiving unsaved selections during Continue.
