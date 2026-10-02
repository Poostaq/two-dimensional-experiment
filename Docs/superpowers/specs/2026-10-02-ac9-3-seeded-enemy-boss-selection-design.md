# AC9.3 Seeded Enemy Boss Selection Design

**Acceptance criterion:** AC9.3.

**Status:** Approved for implementation planning on 2026-10-02.

## Goal

After AC9.1 validates the player-selected clan and commander, AC9.2 selects the allied coalition, and the launcher resolves the run seed, select exactly one main enemy clan from Human, Elf, or Dwarf. Bind that clan to one stable authored four-member boss composition containing exactly one matching commander and supporting members chosen for a deliberate clan-specific combat combo. Persist the enemy clan and boss-party identities so Continue restores them without rerolling or silently changing the composition.

## Scope

This delivery owns the canonical enemy-clan pool, deterministic enemy selection, immutable enemy boss selection, versioned authored boss definitions, structural and executable combo validation, new-run integration, and V8 persistence. It builds on the merged AC9.2 baseline: `RunCharacterCatalog`, `RunClanSelection`, `RunClanCoalition`, `RunAlliedClanSelector`, `WorldRunSaveCodecV7`, and the version-aware runtime save coordinator.

AC9.3 does not place the enemy party on the world map, create the enemy habitat, change the V1 world generator, create a campaign actor, add siege or pursuit behavior, or define boss-victory handling. AC9.4 and AC10 will consume the persisted enemy boss selection when those systems exist. Existing debug boss encounter routing remains a compatibility/testing seam, not the AC9.3 production placement mechanism.

## Chosen approach

Use a stable, versioned boss-party definition referenced by a compact immutable run selection. Persist `enemy_clan_id` and `boss_party_id`, not a duplicate four-member array and not the clan ID alone.

Persisting every member ID would duplicate catalog authority in every save and complicate later mutable enemy-party state. Persisting only the clan ID would allow a future catalog edit to change an existing run's party after Continue. A versioned `boss_party_id` gives each composition a durable identity while the catalog remains the sole authority for its ordered members and combo contract.

## Canonical enemy clan pool

`RunCharacterCatalog` remains the sole clan authority established by AC9.1 and extended by AC9.2. Add canonical `ENEMY_CLAN_IDS` data and `get_enemy_clan_ids() -> Array[StringName]`, returning a defensive duplicate in this exact order:

1. `human`
2. `elf`
3. `dwarf`

The player-facing `PLAYABLE_CLAN_IDS` and directed allied synergy data remain unchanged. Enemy clans never become eligible player or allied selections. Callers do not define local enemy arrays or infer enemy eligibility from available commander scripts.

## Authored boss-party definitions

Add `EnemyBossPartyDefinition`, an immutable value containing:

- `boss_party_id: StringName`
- `enemy_clan_id: StringName`
- `commander_id: StringName`
- `combo_id: StringName`
- `member_class_ids: Array[StringName]`

The definition returns defensive copies of member IDs. Its factory rejects blank IDs, a member count other than four, duplicate members, or a commander not present exactly once.

`BossPartyCatalog` owns lookup by enemy clan ID and by boss-party ID, definition validation, and party construction through `RunCharacterCatalog.create_by_class_id()`. Catalog validation additionally requires:

- the definition's clan is in `RunCharacterCatalog.get_enemy_clan_ids()`;
- the clan and party lookups resolve to the same definition;
- all four members construct successfully;
- every member's `race_id` equals the definition's enemy clan;
- the expected commander appears exactly once; and
- the definition has the exact approved `combo_id` and ordered member list below.

The ordered list is also the initial formation order. The commander occupies index 0 so the existing adjacency-based commander mechanics have a stable authored starting relationship.

| Enemy clan | Boss-party ID | Combo ID | Ordered members | Tactical contract |
|---|---|---|---|---|
| Human | `human_fortified_line_v1` | `fortified_line` | `marshal_elian_voss`, `human_iron_sentinel`, `human_ranger`, `human_field_medic` | Elian, the Sentinel, and Medic maintain an Armor-heavy line while the Ranger supplies Snared pressure and ranged conversion. |
| Elf | `elf_moonfall_exposure_v1` | `moonfall_exposure` | `lady_saelith_moonfall`, `elf_warden_of_the_grove`, `elf_star_archer`, `elf_crescent_duelist` | The Warden supplies Snared, Saelith and the Archer supply Advantage, and the Duelist converts either setup into precision pressure. |
| Dwarf | `dwarf_stonevein_forge_v1` | `stonevein_forge` | `thane_brokk_stonevein`, `dwarf_rune_sentinel`, `dwarf_siege_smith`, `dwarf_hearthkeeper` | Brokk, the Sentinel, and Hearthkeeper establish an armored fortress while the Siege Smith provides the heavy finishing threat. |

`BossPartyCatalog.create_by_enemy_clan_id()` remains as a compatibility wrapper for existing AC9.0 tests and debug encounters. New AC9.3 code resolves the definition first and creates by `boss_party_id`, so clan selection and durable party identity cannot diverge.

## Immutable run selection

Add `RunEnemyBossSelection`, an immutable validated value containing:

- `enemy_clan_id: StringName`
- `boss_party_id: StringName`

Its factory is the shared validation path used by deterministic selection and V8 decoding. It rejects an unknown enemy clan, unknown party ID, a party belonging to another clan, or a structurally invalid catalog definition. It exposes party creation through the catalog rather than storing mutable `RunCharacter` instances in immutable run identity metadata.

The selection deliberately does not contain battle HP, status, cooldown, formation mutation, world coordinates, or AI campaign state. Those will belong to later mutable runtime/save models.

## Deterministic selection

Add `RunEnemyClanSelector` as a pure, stateless selector. It receives AC9.1's already-resolved, nonempty seed and never normalizes, generates, or mutates a seed itself.

Selection follows this fixed contract:

1. Read the canonical enemy clans from `RunCharacterCatalog.get_enemy_clan_ids()`.
2. Build the exact ASCII payload `twde-ac9|v=1|seed=<resolved-seed-hex>|ns=ac9-enemy-clan-v1`, where `<resolved-seed-hex>` is `WorldPriority.seed_hex(resolved_seed)`.
3. Compute `WorldPriority.fnv1a32_ascii(payload)`.
4. Select `hash % enemy_clan_count` from canonical enemy order.
5. Resolve that clan's authored boss definition and construct `RunEnemyBossSelection` through its factory.

The selector does not reuse AC9.2's allied-selection hash or namespace, consume `RandomNumberGenerator` state, depend on call order, or include the player's clan in the payload. Enemy selection is therefore independently reproducible for a resolved seed.

The golden selector vector is:

- resolved seed: `ac9-enemy-vector-1`
- payload: `twde-ac9|v=1|seed=6163392d656e656d792d766563746f722d31|ns=ac9-enemy-clan-v1`
- FNV-1a result: `1650523226`
- selected index: `2`
- selected clan/party: `dwarf` / `dwarf_stonevein_forge_v1`

Changing the payload, canonical order, or composition requires a new selector or party version rather than silently changing V1 outcomes.

## New-run data flow

`WorldRunStartService` retains seed and transaction ownership. Its AC9.3 sequence is:

1. Revalidate or construct the AC9.1 `RunClanSelection`.
2. Invoke the AC9.2 allied selector exactly once.
3. Invoke the AC9.3 enemy selector exactly once with the same resolved seed.
4. If either selector fails, return its typed error before `_generator.generate()` or the commit callback.
5. Generate the unchanged V1 world and assemble the candidate run state.
6. Return `selection`, `coalition`, and `enemy_boss_selection` with the successful candidate.
7. Let `WorldProductionLauncher` encode the complete candidate as V8 and atomically replace the durable save.

Add an optional enemy-selector dependency to `WorldRunStartService._init` after the existing allied-selector dependency. Focused tests use a spy to prove exact input, one invocation, selection order, and pre-generation failure behavior without mutable globals.

`WorldProductionLauncher` includes `enemy_boss_selection` in the emitted session. Continue restores it from V8 and never calls either selector. No UI preview path performs enemy selection.

## Save and compatibility contract

Create `WorldRunSaveCodecV8`. Its encoder accepts the existing V7 values plus `enemy_boss_selection`. V8 extends the V7 root `world` object with:

```text
"enemy_clan_id": "<human|elf|dwarf>",
"boss_party_id": "<versioned-party-id>"
```

Both fields are required nonempty stable IDs. V8 encoding accepts only a valid `RunEnemyBossSelection` whose party belongs to the persisted enemy clan. V8 decoding reconstructs the value through the shared factory and returns it with the existing plan, seed, run state, player selection, and allied coalition.

`WorldRunSaveEnvelope` accepts versions 2 through 8. The exact V8 world-key list is V7 plus `enemy_clan_id` and `boss_party_id`; missing or additional keys fail shape validation atomically. V8 falls back explicitly to V7, preserving the existing V2-V7 dispatch chain.

New-run launcher writes use V8. Repository reads use V8's decode chain. Runtime persistence remains context-aware:

- V8 when selection, coalition, and enemy boss selection are valid;
- V7 when selection and coalition are valid but enemy boss selection is absent;
- V6 when only player selection is valid;
- V5 when none of the AC9 immutable identities exists.

Legacy sessions are never assigned an enemy clan during Continue or silently upgraded merely because they were loaded. Existing bytes remain unchanged until their established flow writes the same schema version.

## Failure behavior

Selector failures use the established `WorldGenerationError` result shape with code `WORLD_GENERATION_INTERNAL_ERROR`, resolved seed hex, generator version `1`, namespace `enemy-clan-selection`, and exactly one of these constraints:

- `enemy_clan_pool_invalid`
- `boss_party_definition_missing`
- `boss_party_definition_invalid`
- `enemy_boss_selection_invalid`

Focused fixtures assert every field. Narrow factories may retain specific internal error strings, but only the selector boundary emits runtime generation errors.

Selection or definition failure occurs before world generation and before save mutation. V8 encoding rejects inconsistent identity metadata without producing partial bytes. Decoding rejects missing, blank, unknown, cross-clan, or invalid definition IDs. Generation, encoding, store, or replacement failure preserves the prior save byte-for-byte under the existing atomic transaction.

## Verification contract

### Selection and persistence

- Lock the exact payload/hash/index golden vector.
- Repeat the same seed around interleaved calls and receive the same result.
- Observe Human, Elf, and Dwarf across a fixed 4,096-seed corpus.
- Prove the selector is called once after allied selection and before generation.
- Prove selector failure prevents generator and commit calls.
- Round-trip V8 identities and reject every malformed or mismatched form.
- Prove Continue performs zero selector calls.
- Retain V2-V7 decode and schema-appropriate autosave behavior.

### Authored party and combo checks

For every definition, tests assert the exact party ID, combo ID, ordered member IDs, four-member count, clan match, and exactly one expected commander. Caller mutation of a returned definition member list or constructed party array cannot affect later results.

Each composition also receives an executable battle-level combo fixture:

- Human: Elian's action-start formation passive grants Armor to himself and the authored adjacent Iron Sentinel, establishing the fortified line used by the party's defensive skills.
- Elf: the authored Warden/Archer setup supplies Snared and Advantage, and Saelith or the Crescent Duelist legally converts the prepared target.
- Dwarf: Brokk's action-start passive grants Armor to the authored adjacent defensive members, after which Rune Sentinel/Hearthkeeper protection remains legal and the Siege Smith retains a legal damage path.

The fixture must exercise production skills and battle state. Merely checking `combo_id`, tooltip text, or class names does not satisfy the combo requirement.

### Project verification

Run the focused AC9.3 selector/catalog runner first, followed by affected start-service, launcher, repository, runtime-save, AC9.0 boss-catalog, AC9.1, AC9.2, and V8/V7 codec suites. Every changed script receives GodotIQ `validate` and `check_errors`; the final gate includes project `check_errors`, orphan-signal inspection, and a headless launch smoke check.

AC9.3 changes no scene or presentation resource, so screenshot or visual-tour evidence is not required.

## File responsibilities

- Modify `Scripts/Run/run_character_catalog.gd`: canonical enemy-clan IDs and defensive-copy query.
- Create `Scripts/Battle/enemy_boss_party_definition.gd`: immutable versioned authored definition.
- Modify `Scripts/Battle/boss_party_catalog.gd`: exact definitions, lookup by clan/party, validation, construction, and compatibility wrapper.
- Create `Scripts/Run/run_enemy_boss_selection.gd`: immutable validated run identity.
- Create `Scripts/Run/run_enemy_clan_selector.gd`: independent versioned seed selection and typed errors.
- Modify `Scripts/Run/world_run_start_service.gd`: invoke and propagate enemy selection before generation.
- Create `Scripts/Save/world_run_save_codec_v8.gd`: V8 writer/reader and V7 fallback.
- Modify `Scripts/Save/world_run_save_envelope.gd`: exact V8 shape and enemy identity reconstruction.
- Modify `Scripts/Run/world_production_launcher.gd`: V8 new-run writer and session metadata.
- Modify `Scripts/Run/world_single_slot_repository.gd`: V8 decode-chain reader.
- Modify `Scripts/WorldMap/world_runtime_controller.gd` and `Scripts/WorldMap/world_runtime_save_coordinator.gd`: carry enemy identity and preserve V5/V6/V7/V8 writer selection.
- Create `Tests/Run/test_ac9_3_enemy_boss_selection.gd`: catalog, immutable value, golden selector, reachability, structural party validation, and executable combo fixtures.
- Extend start-service and launcher tests for invocation order, propagation, and failure atomicity.
- Create `Tests/Save/test_world_run_save_codec_v8.gd`: V8 round-trip, malformed identity rejection, and V2-V7 fallback regressions.
- Extend runtime-save tests for V8 writes and unchanged legacy writer selection.

## Risks and controls

The main determinism risk is coupling enemy selection to AC9.2 RNG or incidental dictionary order. A dedicated namespace, canonical array, FNV-1a payload, and golden vector make the contract explicit.

The main content risk is calling any same-clan roster a tailored combo. Exact versioned definitions plus executable production-skill fixtures prove the intended formation interaction rather than trusting labels.

The main ownership risk is duplicating enemy eligibility or party composition across selector, service, codec, and future world generation. `RunCharacterCatalog` owns clan eligibility, `BossPartyCatalog` owns authored composition, and `RunEnemyBossSelection` owns the cross-reference invariant.

The main compatibility risk is adding required identity fields to V7. V8 isolates the new contract, and context-aware writer selection prevents legacy sessions from receiving fabricated AC9.3 identities.
