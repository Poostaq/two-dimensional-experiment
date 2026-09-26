# AC9.2 Seeded Allied Clan Selection Design

**Acceptance criterion:** AC9.2.

**Status:** Approved for implementation planning on 2026-09-27.

## Goal

After AC9.1 validates the player-selected main clan and commander and resolves the run seed, select exactly two distinct other playable clans. At least one selected ally must have an explicit main-clan-directed synergy. New runs persist the result, and Continue restores it without invoking selection again.

## Scope

This delivery owns playable-clan synergy data, deterministic allied-pair selection, immutable coalition validation, new-run integration, and durable save/restore of the selected allies. It assumes the merged AC9.0 roster and AC9.1 setup/V6 contracts are present.

It does not select the AC9.3 enemy clan; create habitats, towns, roads, or a new world generator; change encounter composition; add coalition presentation; or reinterpret legacy worlds. AC9.4 and later systems will consume the persisted coalition.

## Catalog authority and synergy data

`RunCharacterCatalog` remains the sole clan authority established by AC9.1. Do not add the parallel `ClanCatalog` proposed by the older aggregate AC9 plan.

Add directed synergy data keyed by the main clan. Direction is intentional: only the selected main clan's list determines whether a pair satisfies AC9.2. Do not infer reverse relationships or parse lore at runtime.

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

The value exposes defensive copies of `allied_clan_ids` and the combined three-clan identity list. Ally order is canonical playable-catalog order. The order does not encode first-choice or priority semantics.

## Deterministic selection

Add `RunAlliedClanSelector` as a pure, stateless selector. It receives a validated main clan ID and AC9.1's already-resolved seed string. It never normalizes, generates, or mutates a seed itself.

Selection follows this fixed contract:

1. Read playable clans in catalog order and exclude the main clan.
2. Enumerate every unordered two-clan combination in that order.
3. Retain combinations containing at least one clan in the main clan's directed synergy list.
4. Hash a versioned payload containing the resolved seed, main clan ID, and dedicated `ac9-allied-clans-v1` namespace.
5. Select `hash % valid_pair_count` and construct a `RunClanCoalition` through its factory.

The selector uses the project's stable FNV-1a utility rather than `RandomNumberGenerator`, shuffle state, or mutable call order. Pair selection is therefore reproducible across preview, retry, and restart boundaries. Changing the selector contract requires a new selector version/namespace rather than silently changing V1 outcomes.

Enumerating valid pairs before selection avoids the bias of first selecting a guaranteed synergy partner and then selecting a second ally. Two synergistic allies are valid. An empty valid-pair set is a typed failure; the selector never duplicates a clan or relaxes the synergy constraint.

## New-run data flow

`WorldRunStartService` retains AC9.1's ownership of setup validation, one-time seed resolution, candidate assembly, and atomic commit ordering. Its AC9.2 sequence is:

1. Validate `RunClanSelection`.
2. Resolve the seed once using AC9.1 behavior.
3. Call `RunAlliedClanSelector` exactly once with `main_clan_id` and the resolved seed.
4. Stop before generation if selection fails.
5. Carry the validated coalition through the candidate session/start result.
6. Encode the completed candidate as V7 and atomically replace the durable save only after all earlier work succeeds.

World generation remains unchanged in this delivery because habitats do not exist until AC9.4. The coalition is immutable run identity metadata, not mutable `WorldRunState` data. UI preview paths do not invoke selection. Continue restores persisted identities and never selects or rerolls allies.

## Save and compatibility contract

Create `WorldRunSaveCodecV7`. V7 extends AC9.1's V6 root `world` object with:

```text
"allied_clan_ids": ["<ally-1>", "<ally-2>"]
```

The field is required and contains exactly two stable clan-ID strings in canonical catalog order. V7 encoding accepts only a valid `RunClanCoalition` matching the persisted `main_clan_id`. V7 decoding reconstructs the coalition through the shared factory and returns it with the plan, resolved seed, run state, main clan ID, and commander ID.

V7 falls back explicitly to V6, preserving the existing V2-V6 dispatch chain. V6 and earlier saves remain readable as legacy runs without coalition metadata. Continue does not synthesize or reroll missing allies for those saves. New AC9.2 runs always write V7.

The production codec references at launcher, repository, and runtime-save boundaries move from V6 to V7 together. Existing bytes are never rewritten merely because they were loaded.

## Failure behavior

Selection returns the repository's established result/error shape. Invalid main-clan input, fewer than two eligible other clans, an empty valid-pair set, or coalition construction failure produces a typed error under the `allied-clan-selection` feature namespace.

Selection failure occurs before world generation and before any save mutation. V7 encoding rejects inconsistent or invalid identity metadata with no partial bytes. Decode rejects missing, malformed, duplicate, unknown, main-repeated, or out-of-order ally fields and applies the shared synergy validation. Generation, encoding, store, or replacement failure preserves the prior save byte-for-byte under AC9.1's atomic transaction.

## File responsibilities

- Modify `Scripts/Run/run_character_catalog.gd`: explicit directed synergy map and defensive-copy query APIs.
- Create `Scripts/Run/run_clan_coalition.gd`: shared immutable coalition validation and typed accessors.
- Create `Scripts/Run/run_allied_clan_selector.gd`: versioned, stateless valid-pair enumeration and seeded selection.
- Modify `Scripts/Run/world_run_start_service.gd`: invoke selection after seed resolution and carry coalition metadata through candidate creation.
- Create `Scripts/Save/world_run_save_codec_v7.gd`: V7 encode/decode and explicit V6 fallback.
- Modify `Scripts/Save/world_run_save_envelope.gd`: exact V7 shape and coalition field serialization/deserialization.
- Modify AC9.1's production codec call sites in `Scripts/Run/world_production_launcher.gd`, `Scripts/Run/world_single_slot_repository.gd`, and `Scripts/WorldMap/world_runtime_save_coordinator.gd` to use V7.
- Create `Tests/Run/test_ac9_2_allied_clan_selection.gd`: catalog, coalition, selector, determinism, reachability, and failure tests.
- Extend AC9.1 start/launcher tests for one-time selection and candidate propagation.
- Create `Tests/Save/test_world_run_save_codec_v7.gd`: V7 round-trip, malformed identity rejection, Continue restoration, and V2-V6 fallback regressions.

## Verification and traceability

| AC9.2 obligation | Classification | Verification path | Passing evidence |
|---|---|---|---|
| Select exactly two other clans | Logic | Selector corpus covers every playable main clan | Every result has two allies and excludes the main clan |
| All three identities are distinct | Logic | Coalition factory rejection cases plus selector corpus | Duplicate and main-repeated inputs fail; produced coalitions contain three unique IDs |
| At least one ally is synergistic | Logic | Exact directed catalog matrix and every selected pair checked against it | Every coalition contains a listed main-directed partner |
| Use explicit catalog synergy data | Logic | Catalog API and defensive-copy tests | Exact five lists pass; caller mutation cannot change later results |
| Use the resolved run seed | Integration | Start-service spy captures the selector input for blank and explicit seed starts | Selector receives AC9.1's one resolved value exactly once |
| Selection is random but reproducible | Logic | Fixed golden fixtures, same-input replay, interleaved-call test, and seed corpus | Fixtures remain stable; every valid pair is reachable without call-order dependence |
| Restore rather than reroll | Persistence | V7 round-trip and Continue test with selector spy | Stored allies survive reload and selector call count remains zero |
| Reject invalid durable identities | Persistence | Missing, wrong-size, duplicate, unknown, main-repeated, and out-of-order V7 fixtures; all decoded coalitions pass shared synergy validation | Each malformed save fails with the expected typed constraint |
| Preserve old saves | Integration | V2-V6 decode regression suite | Existing fixtures decode through the unchanged fallback chain |

Focused SceneTree tests run first, followed by affected launcher, repository, runtime-save, AC9.1, and codec regression suites. Each changed script receives GodotIQ `validate` and `check_errors`; project verification includes `check_errors(scope="project")`, `signal_map(find="orphans")`, and a headless launch smoke check. AC9.2 has no scene or presentation changes, so screenshot or visual-tour evidence is not required.

## Risks and controls

The main determinism risk is consuming mutable RNG state or relying on incidental array ordering. Pure pair enumeration, a versioned namespace, catalog-order canonicalization, and golden fixtures make the selection contract explicit.

The main ownership risk is duplicating clan eligibility or synergy rules across selector, service, and codec. `RunCharacterCatalog` owns data and `RunClanCoalition` owns invariants; service and codec call those authorities instead of reproducing maps.

The main compatibility risk is adding required fields to an already shipped V6 shape. V7 isolates the new contract and leaves legacy decode behavior unchanged. Legacy runs remain legacy rather than receiving unsaved selections during Continue.
