# AC9.4 and AC9.5 Seeded Habitats and Towns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship generator V2 with deterministic east/west spawns, four connected clan habitats, three towns per allied habitat, V1/V2 save compatibility, generated ownership, recruitment, and topology diagnostics.

**Architecture:** Preserve generator V1 and its canonical bytes. Extend `WorldPlan` with optional immutable habitat and town records, build V2 topology through a focused deterministic solver, validate and serialize it with a V2 codec behind a version-dispatching facade, then consume the generated ownership from run start, saves, runtime rules, recruitment, presentation, and the debug drawer. V2 deliberately publishes an empty road array; AC9.6/AC9.7 belong to V3.

**Tech Stack:** Godot 4, typed GDScript, SceneTree tests, GodotIQ structured editing and validation, FNV-1a seeded priorities.

**Governing design:** `Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md`

---

## File map

- `Scripts/WorldMap/hex_world_geometry.gd`: shared rendered-horizontal key and canonical extrema.
- `Scripts/WorldMap/world_plan.gd`: immutable optional habitat/town records and derived habitat cells.
- `Scripts/WorldMap/world_habitat_solver_v2.gd`: enemy footprint, seeded anchors, deterministic connected partition, and town selection.
- `Scripts/WorldMap/world_constraint_solver_v1.gd`: retain V1 defaults while allowing V2 forest priority payloads.
- `Scripts/WorldMap/hex_world_generator_v2.gd`: V2 orchestration and complete-plan publication.
- `Scripts/WorldMap/world_plan_codec_v2.gd`: strict canonical V2 encoding, parsing, and invariant validation.
- `Scripts/WorldMap/world_plan_codec.gd`: V1/V2 dispatch facade.
- `Scripts/Run/world_run_start_service.gd`: reserved validated identity injection and V2 default.
- `Scripts/Save/world_run_save_envelope.gd`: V8 envelope support for V1 and V2 plans plus identity agreement.
- `Scripts/WorldMap/world_runtime_model.gd`, `world_presentation_controller.gd`, `world_minimap.gd`: facade validation.
- `Scripts/WorldMap/world_habitat_rules.gd`, `town_ownership_rules.gd`: generated V2 ownership with exact V1 compatibility.
- `Scripts/WorldMap/world_runtime_controller.gd`: generated-town recruitment and committed topology snapshot.
- `Scripts/UI/world_debug_presenter.gd`: V2 habitat/town/start/topology summaries.
- Tests and fixtures under `Tests/WorldMap`, `Tests/Run`, `Tests/Save`, `Tests/UI`, and `Tests/Fixtures/WorldMap/GeneratorV2`.

## Task 1: Geometry and immutable plan contract

**Files:**
- Modify: `Scripts/WorldMap/hex_world_geometry.gd`
- Modify: `Scripts/WorldMap/world_plan.gd`
- Modify: `Tests/WorldMap/test_hex_world_geometry.gd`
- Create: `Tests/WorldMap/test_world_plan_v2.gd`

- [ ] **Step 1: Write failing geometry and plan tests**

Add assertions proving the production horizontal key is `2 * q + r`, V2 extrema are `(-8, 0)` and `(8, 0)`, and ties use canonical coordinate order. Construct a V2 plan with four habitat records and nine town records, mutate every returned collection, and prove subsequent getters are unchanged.

```gdscript
_assert_equal(geometry_script.rendered_horizontal_key(Vector2i(-8, 0)), -16, "west key")
_assert_equal(geometry_script.get_visual_extrema(coords), {
    "west": Vector2i(-8, 0), "east": Vector2i(8, 0),
}, "radius-8 extrema")
_assert_equal(plan.get_habitats().size(), 4, "four immutable habitats")
_assert_equal(plan.get_towns().size(), 9, "nine immutable towns")
_assert_equal(plan.get_habitat_cells("enemy").size(), 9, "derived enemy cells")
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/WorldMap/test_hex_world_geometry.gd
godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/WorldMap/test_world_plan_v2.gd
```

Expected: missing V2 geometry helpers/accessors cause failures; the existing geometry assertions remain green.

- [ ] **Step 3: Implement the minimal shared contract**

Add these typed APIs without changing existing defaults:

```gdscript
static func rendered_horizontal_key(coord: Vector2i) -> int:
    return coord.x * 2 + coord.y

static func get_visual_extrema(coords: Array[Vector2i]) -> Dictionary:
    # Return {"west": ..., "east": ...}; compare key first and q/r second.

func _init(..., forest_clusters: Array, habitats: Array = [], towns: Array = []) -> void:
    # Deep-copy both optional collections.

func get_habitats() -> Array:
    return _habitats.duplicate(true)

func get_towns() -> Array:
    return _towns.duplicate(true)

func get_habitat_cells(habitat_id: String) -> Array[Vector2i]:
    # Derive from cells and return q/r canonical order.
```

- [ ] **Step 4: Validate each changed script and rerun tests**

Use GodotIQ `validate(target=file, detail="brief")` and `check_errors(scope=file)` immediately after each script edit. Run both tests and all V1 geometry/codec/generator tests; expect exit code 0.

- [ ] **Step 5: Commit**

```powershell
git add Scripts/WorldMap/hex_world_geometry.gd Scripts/WorldMap/world_plan.gd Tests/WorldMap/test_hex_world_geometry.gd Tests/WorldMap/test_world_plan_v2.gd
git commit -m "feat: add V2 world topology contract"
```

## Task 2: Deterministic V2 topology and generation

**Files:**
- Create: `Scripts/WorldMap/world_habitat_solver_v2.gd`
- Modify: `Scripts/WorldMap/world_constraint_solver_v1.gd`
- Create: `Scripts/WorldMap/hex_world_generator_v2.gd`
- Create: `Tests/WorldMap/test_ac9_habitats_and_towns.gd`
- Modify: `Tests/WorldMap/test_world_constraint_solver_v1.gd`

- [ ] **Step 1: Write failing topology tests**

Cover exact spawns and enemy footprint, exclusive 217-cell coverage, connected habitats, three towns per allied habitat, no enemy towns, safe town/start encounters, boss encounter, forest exclusions, empty roads, deterministic clean/interleaved output, fixed seed/clan corpus, invalid identity input, and finite-search failure.

```gdscript
var config := {
    "main_clan_id": &"goblin",
    "allied_clan_ids": [&"orc", &"werewolf"],
    "enemy_clan_id": &"human",
}
var result: Dictionary = generator.generate("golden-ac9", config)
_assert_equal(result["plan"].get_start_coord(), Vector2i(8, 0), "east player spawn")
_assert_equal(result["plan"].get_boss_coord(), Vector2i(-8, 0), "west enemy spawn")
_assert_equal(result["plan"].get_habitat_cells("enemy"), EXPECTED_ENEMY_FOOTPRINT, "clipped radius-two footprint")
_assert_equal(result["plan"].get_roads(), [], "V2 roads remain empty")
```

- [ ] **Step 2: Run tests and verify RED**

Run the new AC9 test and expect load failure for `hex_world_generator_v2.gd`. Run the V1 constraint-solver test and confirm it remains green before editing production.

- [ ] **Step 3: Implement V2 solver**

Expose one focused entry point:

```gdscript
func solve(seed_text: String, coords: Array[Vector2i], start_coord: Vector2i, enemy_coord: Vector2i) -> Dictionary:
    # Build the exact distance-2 enemy set.
    # Rank allied anchor candidates with version 2 / habitat-anchor-v2.
    # Enumerate ordered candidate pairs deterministically.
    # Multi-source BFS in main, ally_0, ally_1 order and fixed neighbor order.
    # Accept only complete connected regions with three-town capacity.
    # Rank towns with habitat-town-v2 and stable habitat index.
```

Return only `{ok, habitat_by_coord, habitats, towns, error}` with no partial topology on failure.

- [ ] **Step 4: Version the forest solver without changing V1**

Add `generator_version: int = VERSION` to `solve_forests` and thread it through forest size/frontier payloads and failure records. Existing callers must serialize byte-identically.

- [ ] **Step 5: Implement V2 generator**

Validate identity shape, derive visual extrema, call the habitat solver and V2 forest solver, build cells with `habitat_id`, and create `WorldPlan(version=2, ..., roads=[], habitats, towns)`. Validate through the V2 codec only for the production radius/origins and publish no partial plan on failure.

- [ ] **Step 6: Validate scripts and verify GREEN**

After each file edit, run GodotIQ file validation and parse checks. Run the AC9, V1 solver, V1 generator, and V1 fixture-integrity tests; expect all exit code 0 and unchanged V1 bytes.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/WorldMap/world_habitat_solver_v2.gd Scripts/WorldMap/world_constraint_solver_v1.gd Scripts/WorldMap/hex_world_generator_v2.gd Tests/WorldMap/test_ac9_habitats_and_towns.gd Tests/WorldMap/test_world_constraint_solver_v1.gd
git commit -m "feat: generate deterministic V2 habitats and towns"
```

## Task 3: Canonical V2 codec and dispatch facade

**Files:**
- Create: `Scripts/WorldMap/world_plan_codec_v2.gd`
- Create: `Scripts/WorldMap/world_plan_codec.gd`
- Create: `Tests/WorldMap/test_world_plan_codec_v2.gd`
- Create: `Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world`
- Modify: `Tests/WorldMap/test_generator_v1_fixture_integrity.gd` only if needed to assert facade preservation.

- [ ] **Step 1: Write failing codec tests**

Test canonical record order, exact V2 header, byte-identical round trip, version dispatch, golden bytes/hash, and rejection of reordered records, unknown fields/IDs, duplicate or missing records, noncanonical numbers, malformed clan IDs, inconsistent town references, disconnected habitats, wrong spawns/footprint, enemy towns, nonempty roads, and V1 byte preservation.

```gdscript
var bytes: PackedByteArray = facade.serialize(plan)
_assert_true(bytes.get_string_from_utf8().begins_with("TWDE-WORLD,2\n"), "V2 header")
_assert_equal(facade.serialize(facade.parse(bytes)["plan"]), bytes, "canonical round trip")
_assert_equal(facade.serialize(v1_plan), v1_codec.serialize(v1_plan), "V1 bytes unchanged")
```

- [ ] **Step 2: Run tests and verify RED**

Expected: missing V2 codec/facade scripts fail to load.

- [ ] **Step 3: Implement strict V2 codec**

Serialize in this order: header/seed/start/boss, four habitats, canonical cells with `habitat_id`, nine towns by global index, then forests. Parse tokens without permissive extras, construct a plan, run full invariants, and require `serialize(parsed_plan) == bytes`.

- [ ] **Step 4: Implement dispatch facade**

```gdscript
static func serialize(plan: RefCounted) -> PackedByteArray:
    match plan.get_version():
        1: return CODEC_V1.serialize(plan)
        2: return CODEC_V2.serialize(plan)
        _: return PackedByteArray()

static func parse(bytes: PackedByteArray) -> Dictionary:
    # Read only the canonical header version and dispatch.

static func validate(plan: RefCounted) -> Variant:
    # Dispatch by immutable plan version.
```

- [ ] **Step 5: Author the fixture from verified canonical output**

Generate `golden-ac9.world` once from seed `golden-ac9` and the fixed identity config, then lock its bytes and SHA-256 in the test. The test—not manual inspection—must prove a clean and interleaved run match the fixture.

- [ ] **Step 6: Validate and verify GREEN**

Run codec V2, generator V2, codec V1, generator V1, and fixture-integrity tests. Expect exit code 0 and exact V1 corpus preservation.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/WorldMap/world_plan_codec_v2.gd Scripts/WorldMap/world_plan_codec.gd Tests/WorldMap/test_world_plan_codec_v2.gd Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world Tests/WorldMap/test_generator_v1_fixture_integrity.gd
git commit -m "feat: add canonical V2 world plan codec"
```

## Task 4: Run start and V8 save compatibility

**Files:**
- Modify: `Scripts/Run/world_run_start_service.gd`
- Modify: `Scripts/Save/world_run_save_envelope.gd`
- Modify: `Tests/Run/test_world_run_start_service.gd`
- Modify: `Tests/Save/test_world_run_save_codec_v8.gd`

- [ ] **Step 1: Write failing integration tests**

Extend the generator spy to capture configuration and assert `main_clan_id`, ordered `allied_clan_ids`, and `enemy_clan_id` overwrite forged caller values. Assert exactly one generator call after selection, no call/commit after selection or generation failure, new runs use V2, V8/V2 round trips, V8/V1 remains readable, plan/envelope version equality is required, all four plan clan identities must match persisted selections, and Continue invokes no generator or selector.

- [ ] **Step 2: Run tests and verify RED**

Expected failures: default version is 1, reserved fields are absent, and V8 rejects V2.

- [ ] **Step 3: Switch start service safely**

Use `HexWorldGeneratorV2` as the default. Duplicate caller configuration only after validating all selections, overwrite the three reserved fields, then invoke the injected generator once.

- [ ] **Step 4: Add V1/V2 save dispatch and identity agreement**

Replace the V1 codec dependency with the facade. Allow versions 1 and 2, require envelope/plan version equality, keep the V8 JSON shape and checksum unchanged, and for V2 compare habitat clans against main selection, ordered allies, and enemy selection before constructing run state.

- [ ] **Step 5: Validate and verify GREEN**

Run start-service, V8, all older save-codec, repository, and runtime-save-coordinator tests. Expect exit code 0 and schema-appropriate autosave behavior.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Run/world_run_start_service.gd Scripts/Save/world_run_save_envelope.gd Tests/Run/test_world_run_start_service.gd Tests/Save/test_world_run_save_codec_v8.gd
git commit -m "feat: start and persist V2 generated worlds"
```

## Task 5: Runtime ownership, recruitment, and presentation consumers

**Files:**
- Modify: `Scripts/WorldMap/world_runtime_model.gd`
- Modify: `Scripts/WorldMap/world_presentation_controller.gd`
- Modify: `Scripts/WorldMap/world_minimap.gd`
- Modify: `Scripts/WorldMap/world_habitat_rules.gd`
- Modify: `Scripts/WorldMap/town_ownership_rules.gd`
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`
- Modify: existing focused tests under `Tests/WorldMap`.

- [ ] **Step 1: Write failing consumer tests**

Prove the model, presentation, and minimap accept both versions through the facade; V2 resolves habitat ID/role/clan/anchor/cell count/source; towns resolve stable town ID and owning habitat; every playable allied clan can expose its recruit catalog; invalid/non-town/enemy/unsupported ownership is rejected; V1 retains whole-board Goblin wording and recruitment.

- [ ] **Step 2: Run focused tests and verify RED**

Expected failures: direct V1 validation and temporary `version == 1`/Goblin-only guards reject V2.

- [ ] **Step 3: Implement generated ownership and facade validation**

Dispatch habitat rules by plan version. For V2, read the cell `habitat_id`, resolve the matching immutable habitat, and return stable ownership fields. Town rules must add the matching town record while delegating clan ownership to habitat rules. Replace direct V1 codec dependencies in all three consumers with the facade.

- [ ] **Step 4: Generalize recruitment boundary**

Remove only the temporary V1/Goblin restrictions. Require a supported plan, valid allied town ownership, and a nonempty recruitable catalog for the resolved clan. Keep `TownRecruitmentRules` unchanged.

- [ ] **Step 5: Validate and verify GREEN**

Run habitat, town ownership/reload, recruitment, runtime model, presentation, minimap, migrated-flow, and production-scene tests. Expect exit code 0.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/WorldMap/world_runtime_model.gd Scripts/WorldMap/world_presentation_controller.gd Scripts/WorldMap/world_minimap.gd Scripts/WorldMap/world_habitat_rules.gd Scripts/WorldMap/town_ownership_rules.gd Scripts/WorldMap/world_runtime_controller.gd Tests/WorldMap
git commit -m "feat: consume generated habitat ownership at runtime"
```

## Task 6: Debug topology diagnostics and end-to-end evidence

**Files:**
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`
- Modify: `Scripts/UI/world_debug_presenter.gd`
- Modify: `Tests/UI/test_world_debug_presenter.gd`
- Modify: `Tests/WorldMap/test_ac8_4_world_debug_integration.gd`
- Create: `Tests/WorldMap/capture_ac9_4_habitats_and_towns.gd`

- [ ] **Step 1: Write failing debug snapshot/presenter tests**

Assert the committed snapshot exposes current habitat ID/role/clan/anchor/source/cell count, current town ID/owner, generated starts distinct from mutable positions, per-habitat cell/town counts, enemy footprint count, seed, and generator version. Assert V2 totals `enemy cells=9`, `main/ally_0/ally_1 towns=3`, `enemy towns=0`; V1 uses unavailable values and legacy text; repeated snapshot/format calls do not mutate the plan.

- [ ] **Step 2: Run tests and verify RED**

Expected: new topology keys and formatted lines are absent.

- [ ] **Step 3: Extend snapshot and presenter**

Derive every value from `_runtime_plan` and committed runtime state. Add compact Habitat and Map lines without introducing mutable caches or scene restructuring. Format missing V1-only data as `Unavailable`.

- [ ] **Step 4: Validate focused code and verify GREEN**

Run presenter, drawer, debug integration, AC9 topology, start/save, runtime, presentation, and fixture tests. Use GodotIQ project validation, project parse check, Play-mode verification, debug-console inspection, and state inspection.

- [ ] **Step 5: Capture visual evidence**

Run the production world from a V2 session and capture one visual verification showing the player marker on the east, enemy marker on the west, nine towns, and no roads. Stop Play after inspection.

- [ ] **Step 6: Audit determinism and traceability**

Record the seed/config, clean/interleaved hashes, fixture hash, V1 preservation result, and AC9.4/AC9.5 criterion-to-test matrix in the final handoff. Any divergence or uncovered blocking criterion is a failure.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/WorldMap/world_runtime_controller.gd Scripts/UI/world_debug_presenter.gd Tests/UI/test_world_debug_presenter.gd Tests/WorldMap/test_ac8_4_world_debug_integration.gd Tests/WorldMap/capture_ac9_4_habitats_and_towns.gd
git commit -m "feat: expose V2 topology diagnostics"
```

## Final verification

- [ ] Run every changed/focused SceneTree test with the production Godot executable and require exit code 0.
- [ ] Run all V1 world fixtures and V2 canonical fixture checks; require byte equality and stable hashes.
- [ ] Run GodotIQ `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`.
- [ ] Run GodotIQ Play verification and read the debug console; require no parser/runtime errors.
- [ ] Compare implementation line-by-line against the approved design and this plan; record any intentionally deferred AC9.6/AC9.7/AC9.10 work.
- [ ] Request spec-compliance and code-quality review, fix all Critical/Important findings, and rerun verification before completion.
