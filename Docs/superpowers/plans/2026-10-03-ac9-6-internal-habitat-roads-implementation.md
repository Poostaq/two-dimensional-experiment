# AC9.6 Internal Habitat Roads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship generator V3 with exactly three pairwise town connections inside each allied habitat while preserving immutable V1/V2 worlds and reserving V4 for AC9.7.

**Architecture:** Build roads through a pure V3 rules component, wrap the frozen V2 generator to preserve every non-road field, and encode V3 by inserting canonical road records into a V2-validated shadow plan. Cut only new runs over to V3; old saves remain on their original generator versions.

**Tech Stack:** Godot 4.7.2, typed GDScript, headless `SceneTree` tests, canonical UTF-8 world fixtures, SHA-256 fixture locking, GodotIQ validation/runtime tools.

---

## Execution constraints

- Work in the primary workspace on the existing dedicated branch `plan/ac9-6-internal-roads`; this repository forbids Git worktrees.
- Preserve the unstaged `.github/prompts` deletions and `.github/skills` additions. Never stage them in an AC9.6 commit.
- Before changing any `.gd` file, call GodotIQ `file_context(file, detail="brief")`. For the facade, start service, and save envelope, also call `impact_check` with the named change.
- After every `.gd` edit, immediately run GodotIQ `validate(target=file, detail="brief")` and `check_errors(scope=file)` before editing the next script.
- Use GodotIQ `script_ops` for every `.gd` create or patch. Use `apply_patch` only for Markdown and other non-Godot files.
- Use this executable for every headless test:

```powershell
$godotExe = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
```

## Baseline and file map

The following tests passed with exit code `0` before planning:

- `Tests/WorldMap/test_ac9_habitats_and_towns.gd`
- `Tests/WorldMap/test_world_plan_codec_v2.gd`
- `Tests/Run/test_world_run_start_service.gd`
- `Tests/Save/test_world_run_save_codec_v8.gd`

Create:

- `Scripts/WorldMap/habitat_road_rules_v3.gd` — canonical AC9.6 endpoint selection and input rejection.
- `Scripts/WorldMap/hex_world_generator_v3.gd` — V2-preserving generator wrapper that publishes a V3 plan.
- `Scripts/WorldMap/world_plan_codec_v3.gd` — V2-shadow serialization, parsing, validation, and route checks.
- `Tests/WorldMap/test_habitat_road_rules_v3.gd` — pure rule and failure-contract tests.
- `Tests/WorldMap/test_hex_world_generator_v3.gd` — V2/V3 equivalence and deterministic generation tests.
- `Tests/WorldMap/test_world_plan_codec_v3.gd` — canonical codec and mutation rejection tests.
- `Tests/WorldMap/test_generator_v3_fixture_author.gd` — guarded fixture writer and byte-for-byte verifier.
- `Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world` — immutable V3 golden fixture.
- `Docs/Specs/AC9/Evidence/AC9.6/verification.md` — final traceability and current evidence.

Modify:

- `Scripts/WorldMap/world_plan_codec.gd` — add V3 facade dispatch only.
- `Scripts/Run/world_run_start_service.gd` — make V3 the default new-run generator and error version.
- `Scripts/Save/world_run_save_envelope.gd` — admit V3 in save version 8 and share generated-identity validation across V2/V3.
- `Tests/Run/test_world_run_start_service.gd` — assert the production V3 cutover and nine roads.
- `Tests/Save/test_world_run_save_codec_v8.gd` — cover V3, retain explicit V2/V1 compatibility, and reject V4.
- `Docs/superpowers/plans/2026-09-18-ac9-clans-and-habitats.md` — assign AC9.6 to V3 and AC9.7 to V4.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — link evidence and check AC9.6 only after the final gate passes.

Do not modify `Scripts/WorldMap/hex_world_generator_v2.gd`, `Scripts/WorldMap/world_plan_codec_v2.gd`, or the V1/V2 fixture files.

## Acceptance traceability

| AC9.6 behavior | Automated proof | Runtime proof |
|---|---|---|
| All three unordered town pairs exist in each allied habitat | `test_habitat_road_rules_v3.gd`, `test_hex_world_generator_v3.gd` | Active production plan has version `3` and nine roads |
| Every road stays between towns owned by the same allied habitat | Rule negative cases and V3 codec endpoint ownership rejection | Inspect all nine endpoint pairs from the active plan |
| Output is canonical and deterministic | V3 clean/interleaved corpus plus golden fixture hash | New run reloads from saved canonical bytes without regeneration |
| V1/V2 remain immutable | Existing V1 fixture integrity and V2 codec/fixture tests | Continue restores existing plan version |

## Task 1: Canonical internal-road rules

**Files:**

- Create: `Tests/WorldMap/test_habitat_road_rules_v3.gd`
- Create: `Scripts/WorldMap/habitat_road_rules_v3.gd`

- [ ] **Step 1: Write the failing rules test**

Create a headless `SceneTree` test with the standard `_failures`, deferred `_run`, `_expect`, `_expect_equal`, and `_finish` harness. Use this canonical fixture and expected result:

```gdscript
const RULES_PATH := "res://Scripts/WorldMap/habitat_road_rules_v3.gd"

func _towns() -> Array:
    return [
        {"town_id": "main_town_0", "habitat_id": "main", "local_index": 0, "coord": Vector2i(5, 0)},
        {"town_id": "main_town_1", "habitat_id": "main", "local_index": 1, "coord": Vector2i(8, -6)},
        {"town_id": "main_town_2", "habitat_id": "main", "local_index": 2, "coord": Vector2i(8, -7)},
        {"town_id": "ally_0_town_0", "habitat_id": "ally_0", "local_index": 0, "coord": Vector2i(-1, 5)},
        {"town_id": "ally_0_town_1", "habitat_id": "ally_0", "local_index": 1, "coord": Vector2i(0, -7)},
        {"town_id": "ally_0_town_2", "habitat_id": "ally_0", "local_index": 2, "coord": Vector2i(-1, -2)},
        {"town_id": "ally_1_town_0", "habitat_id": "ally_1", "local_index": 0, "coord": Vector2i(-1, 7)},
        {"town_id": "ally_1_town_1", "habitat_id": "ally_1", "local_index": 1, "coord": Vector2i(-1, 8)},
        {"town_id": "ally_1_town_2", "habitat_id": "ally_1", "local_index": 2, "coord": Vector2i(4, 3)},
    ]

const EXPECTED_ROADS: Array = [
    {"a": Vector2i(5, 0), "b": Vector2i(8, -6)},
    {"a": Vector2i(5, 0), "b": Vector2i(8, -7)},
    {"a": Vector2i(8, -6), "b": Vector2i(8, -7)},
    {"a": Vector2i(-1, 5), "b": Vector2i(0, -7)},
    {"a": Vector2i(-1, 5), "b": Vector2i(-1, -2)},
    {"a": Vector2i(0, -7), "b": Vector2i(-1, -2)},
    {"a": Vector2i(-1, 7), "b": Vector2i(-1, 8)},
    {"a": Vector2i(-1, 7), "b": Vector2i(4, 3)},
    {"a": Vector2i(-1, 8), "b": Vector2i(4, 3)},
]
```

Assert that `build(_towns(), "676f6c64656e2d616339")` succeeds, returns `EXPECTED_ROADS`, returns a deep copy, and returns the same roads after reversing the input array. Add one mutation case for each stable constraint:

| Mutation | Expected `failed_constraint` |
|---|---|
| eight records | `town_count=9` |
| non-dictionary record | `town_record_type` |
| missing field | `town_record_fields` |
| enemy habitat | `town_habitat_id` |
| duplicate habitat/local index | `town_slot_unique` |
| duplicate town ID | `town_id_unique` |
| duplicate coordinate | `town_coord_unique` |
| coordinate outside radius eight | `town_coord_on_board` |
| noncanonical town ID | `town_id_canonical` |

Every failure must return `ok=false`, `roads=[]`, `error.generator_version=3`, `error.feature_namespace="roads"`, and the supplied seed hex.

- [ ] **Step 2: Run the test and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_habitat_road_rules_v3.gd
```

Expected: exit code `1` because `habitat_road_rules_v3.gd` does not exist.

- [ ] **Step 3: Implement the rules component**

Create `HabitatRoadRulesV3` with this public contract and canonical pair table:

```gdscript
class_name HabitatRoadRulesV3
extends RefCounted

const VERSION := 3
const RADIUS := 8
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]
const LOCAL_PAIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")

static func build(towns: Array, seed_hex: String) -> Dictionary:
    if towns.size() != 9:
        return _failure(seed_hex, "town_count=9")
    var slots: Dictionary = {}
    var seen_ids: Dictionary = {}
    var seen_coords: Dictionary = {}
    for town_value: Variant in towns:
        if not town_value is Dictionary:
            return _failure(seed_hex, "town_record_type")
        var town: Dictionary = town_value
        if not _has_exact_keys(town, ["town_id", "habitat_id", "local_index", "coord"]):
            return _failure(seed_hex, "town_record_fields")
        if (
            not _is_string_value(town["town_id"])
            or not _is_string_value(town["habitat_id"])
            or not town["local_index"] is int
            or not town["coord"] is Vector2i
        ):
            return _failure(seed_hex, "town_record_type")
        var habitat_id := String(town["habitat_id"])
        var local_index: int = town["local_index"]
        var town_id := String(town["town_id"])
        var coord: Vector2i = town["coord"]
        if habitat_id not in ALLIED_HABITAT_IDS or local_index < 0 or local_index > 2:
            return _failure(seed_hex, "town_habitat_id")
        if town_id != "%s_town_%d" % [habitat_id, local_index]:
            return _failure(seed_hex, "town_id_canonical")
        var slot := "%s:%d" % [habitat_id, local_index]
        if slots.has(slot):
            return _failure(seed_hex, "town_slot_unique")
        if seen_ids.has(town_id):
            return _failure(seed_hex, "town_id_unique")
        if seen_coords.has(coord):
            return _failure(seed_hex, "town_coord_unique")
        if not GEOMETRY_SCRIPT.is_valid_coord(coord, RADIUS):
            return _failure(seed_hex, "town_coord_on_board")
        slots[slot] = coord
        seen_ids[town_id] = true
        seen_coords[coord] = true
    var roads: Array = []
    for habitat_id: String in ALLIED_HABITAT_IDS:
        for pair: Vector2i in LOCAL_PAIRS:
            var a_key := "%s:%d" % [habitat_id, pair.x]
            var b_key := "%s:%d" % [habitat_id, pair.y]
            if not slots.has(a_key) or not slots.has(b_key):
                return _failure(seed_hex, "town_slot_missing")
            roads.append({"a": slots[a_key], "b": slots[b_key]})
    return {"ok": true, "roads": roads.duplicate(true), "error": null}
```

Implement `_has_exact_keys`, `_is_string_value`, and `_failure` as typed private static functions. `_failure` must create `WORLD_GENERATION_INTERNAL_ERROR` with version `3`, namespace `roads`, and return `{"ok": false, "roads": [], "error": error}`.

- [ ] **Step 4: Validate and verify GREEN**

Run GodotIQ validation/parser checks for the production script, then:

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_habitat_road_rules_v3.gd
```

Expected: exit code `0` and `PASS test_habitat_road_rules_v3`.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/WorldMap/habitat_road_rules_v3.gd Tests/WorldMap/test_habitat_road_rules_v3.gd
git commit -m "feat: define AC9.6 internal road rules"
```

## Task 2: V3 generator preserving V2 topology

**Files:**

- Create: `Tests/WorldMap/test_hex_world_generator_v3.gd`
- Create: `Scripts/WorldMap/hex_world_generator_v3.gd`

- [ ] **Step 1: Write the failing generator test**

For seeds `golden-ac9`, `ac9-roads-alpha`, and `ac9-roads-beta`, generate V2 and V3 with:

```gdscript
const CONFIG := {
    "main_clan_id": &"goblin",
    "allied_clan_ids": [&"orc", &"werewolf"],
    "enemy_clan_id": &"human",
}
```

Assert that V3 is version `3`; V2 and V3 have equal seed hex, spawns, cells, habitats, towns, forests; V2 has no roads; and V3 roads equal `HabitatRoadRulesV3.build(v3_plan.get_towns(), v3_plan.get_seed_hex())["roads"]`. For each habitat, resolve endpoints through the town-coordinate lookup and assert the local-index set is exactly `[Vector2i(0,1), Vector2i(0,2), Vector2i(1,2)]`.

Generate `golden-ac9`, then generate the two other seeds, then generate `golden-ac9` again. Assert both V3 serializations and every plan collection are identical. Pass `radius=9` and assert failure returns no plan with generator version `3`. Inject a V2-invalid identity configuration and assert the promoted error retains its code, namespace, constraint, and seed while reporting version `3`.

- [ ] **Step 2: Run the test and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_generator_v3.gd
```

Expected: exit code `1` because `hex_world_generator_v3.gd` does not exist.

- [ ] **Step 3: Implement the V3 generator wrapper**

Create this complete generation flow:

```gdscript
class_name HexWorldGeneratorV3
extends RefCounted

const VERSION := 3

static var V2_GENERATOR_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_generator_v2.gd")
static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var ROAD_RULES_SCRIPT: GDScript = load("res://Scripts/WorldMap/habitat_road_rules_v3.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")

func generate(seed_text: String, config: Dictionary = {}) -> Dictionary:
    var v2_result: Dictionary = V2_GENERATOR_SCRIPT.new().generate(seed_text, config)
    if not bool(v2_result.get("ok", false)):
        return _promote_failure(seed_text, v2_result.get("error"))
    var v2_plan: RefCounted = v2_result.get("plan") as RefCounted
    if not is_instance_valid(v2_plan):
        return _internal_failure(seed_text, "v2_plan_missing")
    var road_result: Dictionary = ROAD_RULES_SCRIPT.build(
        v2_plan.get_towns(),
        v2_plan.get_seed_hex()
    )
    if not bool(road_result.get("ok", false)):
        return {"ok": false, "plan": null, "error": road_result.get("error")}
    var plan: RefCounted = PLAN_SCRIPT.new(
        VERSION,
        v2_plan.get_seed_hex(),
        v2_plan.get_start_coord(),
        v2_plan.get_boss_coord(),
        v2_plan.get_cells(),
        road_result["roads"],
        v2_plan.get_forest_clusters(),
        v2_plan.get_habitats(),
        v2_plan.get_towns()
    )
    return {"ok": true, "plan": plan, "error": null}
```

Implement `_promote_failure` by copying a valid `WorldGenerationError`'s `code`, `seed_hex`, `feature_namespace`, and `failed_constraint` into a new error with generator version `3`. If the delegated error is invalid, return `WORLD_GENERATION_INTERNAL_ERROR` with the normalized seed hex and constraint `v2_generation_failure_invalid`. `_internal_failure` uses namespace `roads` and version `3`. This task deliberately stops at the tested V2-plus-rules boundary; Task 3 adds the strict V3 codec gate before production can select this generator.

- [ ] **Step 4: Validate and verify GREEN**

Run GodotIQ validation/parser checks, then:

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_habitat_road_rules_v3.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_generator_v3.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac9_habitats_and_towns.gd
```

Expected: all exit `0`; the existing V2 test remains unchanged and green.

- [ ] **Step 5: Commit**

```powershell
git add -- Scripts/WorldMap/hex_world_generator_v3.gd Tests/WorldMap/test_hex_world_generator_v3.gd
git commit -m "feat: generate V3 internal habitat roads"
```

## Task 3: Canonical V3 codec, facade, and fixture

**Files:**

- Create: `Tests/WorldMap/test_world_plan_codec_v3.gd`
- Create: `Tests/WorldMap/test_generator_v3_fixture_author.gd`
- Create: `Scripts/WorldMap/world_plan_codec_v3.gd`
- Create: `Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world`
- Modify: `Scripts/WorldMap/world_plan_codec.gd`
- Modify: `Scripts/WorldMap/hex_world_generator_v3.gd`

- [ ] **Step 1: Write failing codec and fixture tests**

In `test_world_plan_codec_v3.gd`, generate `golden-ac9` with the fixed config from Task 2 and assert:

```gdscript
const EXPECTED_GOLDEN_SHA256 := "0ffe96dff287d96deb4889ba6556f1adf4aad27ff9646333f48434191824672d"

var bytes: PackedByteArray = codec_v3.serialize(plan)
_expect(bytes.get_string_from_utf8().begins_with("TWDE-WORLD,3\n"), "V3 header")
_expect(_sha256(bytes) == EXPECTED_GOLDEN_SHA256, "V3 golden hash")
var parsed: Dictionary = codec_v3.parse(bytes)
_expect(parsed.get("ok", false), "V3 canonical bytes parse")
_expect(codec_v3.serialize(parsed["plan"]) == bytes, "V3 byte-identical round trip")
_expect(facade.serialize(plan) == bytes, "facade serializes V3")
_expect(facade.parse(bytes).get("ok", false), "facade parses V3")
```

Mutate the canonical text and assert rejection for: V2/V4 header, UTF-8 BOM, CRLF, missing final newline, missing road, tenth road, reordered roads, reversed edge, duplicate edge, self-edge, non-town endpoint, cross-habitat endpoint, enemy endpoint, noncanonical integer, extra field, road record after a forest, changed V2-shadow cell, and altered forest. Assert serialization rejects a V3 plan with empty roads or changed road order. Assert existing V1/V2 facade serialization and fixture hashes remain unchanged.

Create `test_generator_v3_fixture_author.gd` with the same guarded `--write` behavior as the V2 author but with V3 paths, the fixed config, the exact hash above, and an unconditional comparison between production bytes and the fixture.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v3.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd
```

Expected: both exit `1` because the V3 codec, facade branch, and fixture do not exist.

- [ ] **Step 3: Implement V2-shadow codec behavior**

Create `WorldPlanCodecV3` with these constants and loaded dependencies:

```gdscript
class_name WorldPlanCodecV3
extends RefCounted

const VERSION := 3
const ROAD_COUNT := 9
const ROAD_INSERT_INDEX := 234
const V3_HEADER := "TWDE-WORLD,3"
const V2_HEADER := "TWDE-WORLD,2"

static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var CODEC_V2_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v2.gd")
static var ROAD_RULES_SCRIPT: GDScript = load("res://Scripts/WorldMap/habitat_road_rules_v3.gd")
static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
```

Implement `serialize(plan)` so it first calls `validate`, serializes `_shadow_plan(plan)` through V2, replaces only line zero with `TWDE-WORLD,3`, inserts the nine road lines at index `234`, and emits one final LF. A road line is exactly `road,<a.x>,<a.y>,<b.x>,<b.y>`.

Implement `parse(bytes)` in this fixed order:

1. reject BOM, CR, absent final LF, doubled final LF, and non-V3 header;
2. require at least `ROAD_INSERT_INDEX + ROAD_COUNT` records;
3. parse exactly lines `234..242` as five-field canonical road records;
4. remove those nine lines, change only the header to V2, and call `WorldPlanCodecV2.parse`;
5. promote a V2 parse failure to generator version `3` without changing its code or constraint;
6. construct a V3 `WorldPlan` from the parsed shadow collections and parsed roads;
7. call `validate` and require `serialize(plan) == bytes`.

Implement `validate(plan)` with these exact gates:

```gdscript
static func validate(plan: RefCounted) -> Variant:
    if plan.get_version() != VERSION:
        return _validation_error(plan, "world_version")
    var shadow: RefCounted = _shadow_plan(plan)
    var shadow_error: Variant = CODEC_V2_SCRIPT.validate(shadow)
    if shadow_error != null:
        return _validation_error(plan, "v2_shadow_%s" % shadow_error.failed_constraint)
    var road_result: Dictionary = ROAD_RULES_SCRIPT.build(
        plan.get_towns(),
        plan.get_seed_hex()
    )
    if not bool(road_result.get("ok", false)):
        return road_result.get("error")
    if plan.get_roads() != road_result["roads"]:
        return _validation_error(plan, "roads_canonical")
    for edge_value: Variant in plan.get_roads():
        if not _route_is_valid(edge_value as Dictionary):
            return _validation_error(plan, "road_route")
    return null
```

`_shadow_plan` constructs version `2` with the same seed, spawns, cells, forests, habitats, towns, and `roads=[]`. `_route_is_valid` must start at `a`, repeatedly choose the first radius-eight neighbor whose distance to `b` is exactly one less, reject a missing step, and require the number of steps to equal the original hex distance. Implement typed `_parse_road`, `_canonical_int`, `_failure`, `_validation_error`, and `_promote_v2_failure` helpers with stable version-3 errors.

- [ ] **Step 4: Add V3 facade dispatch**

Patch `world_plan_codec.gd` to load `world_plan_codec_v3.gd`, add `3: return CODEC_V3_SCRIPT.serialize(plan)` and `3: return CODEC_V3_SCRIPT.validate(plan)`, and dispatch header `TWDE-WORLD,3` to `CODEC_V3_SCRIPT.parse(bytes)`. Do not alter existing V1/V2 branches or fallback errors.

- [ ] **Step 5: Add the generator's final codec publication gate**

Patch `hex_world_generator_v3.gd` to load `world_plan_codec_v3.gd` and insert this immediately after constructing the candidate plan:

```gdscript
static var CODEC_V3_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v3.gd")

var validation: Variant = CODEC_V3_SCRIPT.validate(plan)
if validation != null:
    return {"ok": false, "plan": null, "error": validation}
```

The generator must expose no V3 plan that the canonical V3 codec rejects.

- [ ] **Step 6: Validate scripts and verify codec GREEN before authoring**

Run GodotIQ validation/parser checks after each script. Then run:

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v3.gd
```

Expected: codec behavior passes except the fixture-presence assertion.

- [ ] **Step 7: Author and lock the V3 fixture**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd -- --write
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd
Get-FileHash -Algorithm SHA256 -LiteralPath Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world
```

Expected: both Godot runs exit `0`; PowerShell reports `0FFE96DFF287D96DEB4889BA6556F1ADF4AAD27FF9646333F48434191824672D`.

- [ ] **Step 8: Run immutable-version regressions**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v1_fixture_integrity.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v1.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v2_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v2.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v3.gd
```

Expected: all exit `0`; no V1/V2 fixture changes appear in `git status`.

- [ ] **Step 9: Commit**

```powershell
git add -- Scripts/WorldMap/world_plan_codec_v3.gd Scripts/WorldMap/world_plan_codec.gd Scripts/WorldMap/hex_world_generator_v3.gd Tests/WorldMap/test_world_plan_codec_v3.gd Tests/WorldMap/test_generator_v3_fixture_author.gd Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world
git commit -m "feat: add canonical V3 world plan codec"
```

## Task 4: Production new-run and save cutover

**Files:**

- Modify: `Tests/Run/test_world_run_start_service.gd`
- Modify: `Scripts/Run/world_run_start_service.gd`
- Modify: `Tests/Save/test_world_run_save_codec_v8.gd`
- Modify: `Scripts/Save/world_run_save_envelope.gd`

- [ ] **Step 1: Write failing start-service assertions**

Rename the default-success test to `_test_default_v3_success`, point its production delegate constant at `hex_world_generator_v3.gd`, and assert:

```gdscript
_assert_equal(plan.get_version(), 3, "default generator produces V3")
_assert_equal(plan.get_habitats().size(), 4, "V3 plan has four habitats")
_assert_equal(plan.get_towns().size(), 9, "V3 plan has nine towns")
_assert_equal(plan.get_roads().size(), 9, "V3 plan has nine internal roads")
```

Update every pre-generation and fixed-config failure expectation from version `2` to `3`. Keep one explicit injected V2 generator test proving the constructor seam can still start a V2 plan when compatibility tests request it.

- [ ] **Step 2: Run the start-service test and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd
```

Expected: exit code `1`; production still defaults to V2 and reports version `2` before generation.

- [ ] **Step 3: Cut new runs over to V3**

In `world_run_start_service.gd`, add `const GENERATOR_VERSION := 3`, change `GENERATOR_SCRIPT` to `hex_world_generator_v3.gd`, and replace every hard-coded pre-generation error version argument with `GENERATOR_VERSION`. Leave injected generators, configuration ownership, commit timing, starter creation, and run-state construction unchanged.

- [ ] **Step 4: Validate and verify start-service GREEN**

Run GodotIQ validation/parser checks, then rerun the start-service test. Expected: exit `0` and exactly one commit on success, zero on every failure.

- [ ] **Step 5: Write failing V8 save assertions**

Change the primary fixture to `_start_v3()` and assert the envelope stores generator version `3`, decoded plans retain nine roads, canonical bytes reserialize identically, and identity mismatch checks reject V3. Add `_start_v2()` using an injected `HexWorldGeneratorV2` and assert V2 still round-trips with empty roads. Preserve the existing V1 round trip. Change the unsupported generator version mutation from `3` to `4`.

- [ ] **Step 6: Run the save test and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/Save/test_world_run_save_codec_v8.gd
```

Expected: exit code `1`; the V8 envelope currently caps generated worlds at version `2`.

- [ ] **Step 7: Admit V3 in the existing V8 envelope**

In `world_run_save_envelope.gd`:

```gdscript
const GENERATOR_VERSION := 1
const GENERATOR_VERSION_V2 := 2
const GENERATOR_VERSION_V3 := 3
const GENERATED_GENERATOR_VERSIONS: Array[int] = [GENERATOR_VERSION_V2, GENERATOR_VERSION_V3]
```

For save version `8`, allow generator versions `[1, 2, 3]`. Rename `_v2_identities_match` to `_generated_identities_match` and call it for both versions in `GENERATED_GENERATOR_VERSIONS`. In `_valid_current_shape`, set the V8 maximum generator version to `GENERATOR_VERSION_V3`. Decode must continue to require envelope version equals parsed plan version. Do not change `world_run_save_codec_v8.gd`; its facade validation already accepts every supported plan version.

- [ ] **Step 8: Validate and run integration regressions**

Run GodotIQ validation/parser checks, then:

```powershell
& $godotExe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd
& $godotExe --headless --path . --script res://Tests/Save/test_world_run_save_codec_v8.gd
& $godotExe --headless --path . --script res://Tests/Run/test_world_single_slot_repository.gd
& $godotExe --headless --path . --script res://Tests/Run/test_world_production_launcher.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_model.gd
```

Expected: all exit `0`; V3 is used only for new runs, while V1/V2 decode without regeneration.

- [ ] **Step 9: Commit**

```powershell
git add -- Scripts/Run/world_run_start_service.gd Scripts/Save/world_run_save_envelope.gd Tests/Run/test_world_run_start_service.gd Tests/Save/test_world_run_save_codec_v8.gd
git commit -m "feat: start and persist V3 road worlds"
```

## Task 5: Version-roadmap reconciliation and acceptance evidence

**Files:**

- Modify: `Docs/superpowers/plans/2026-09-18-ac9-clans-and-habitats.md`
- Create: `Docs/Specs/AC9/Evidence/AC9.6/verification.md`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`

- [ ] **Step 1: Reconcile the aggregate AC9 roadmap**

Replace statements assigning AC9.6 and AC9.7 together to V3 with the approved immutable sequence:

- V2: AC9.4/AC9.5 habitats and towns, no roads.
- V3: AC9.6 internal all-pairs roads only.
- V4: AC9.7 closest tied cross-habitat roads.

Split the old combined Task 4 into independent V3 and V4 tasks. Keep the AC9.7 endpoint and shared-segment requirements unchanged.

- [ ] **Step 2: Run the complete automated gate and save logs**

Create `Docs/Specs/AC9/Evidence/AC9.6`, define this exit-code-preserving helper, and invoke it for all twelve scripts:

```powershell
function Invoke-GodotTest {
    param([string]$ScriptPath, [string]$LogName)
    & $godotExe --headless --path . --script $ScriptPath 2>&1 |
        Tee-Object -FilePath (Join-Path 'Docs/Specs/AC9/Evidence/AC9.6' $LogName)
    if ($LASTEXITCODE -ne 0) {
        throw "$ScriptPath failed with exit code $LASTEXITCODE"
    }
}

Invoke-GodotTest 'res://Tests/WorldMap/test_habitat_road_rules_v3.gd' 'test_habitat_road_rules_v3.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_hex_world_generator_v3.gd' 'test_hex_world_generator_v3.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_world_plan_codec_v3.gd' 'test_world_plan_codec_v3.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_generator_v3_fixture_author.gd' 'test_generator_v3_fixture_author.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_generator_v1_fixture_integrity.gd' 'test_generator_v1_fixture_integrity.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_generator_v2_fixture_author.gd' 'test_generator_v2_fixture_author.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_world_plan_codec_v2.gd' 'test_world_plan_codec_v2.log'
Invoke-GodotTest 'res://Tests/Run/test_world_run_start_service.gd' 'test_world_run_start_service.log'
Invoke-GodotTest 'res://Tests/Save/test_world_run_save_codec_v8.gd' 'test_world_run_save_codec_v8.log'
Invoke-GodotTest 'res://Tests/Run/test_world_single_slot_repository.gd' 'test_world_single_slot_repository.log'
Invoke-GodotTest 'res://Tests/Run/test_world_production_launcher.gd' 'test_world_production_launcher.log'
Invoke-GodotTest 'res://Tests/WorldMap/test_world_runtime_model.gd' 'test_world_runtime_model.log'
```

Expected: twelve exit codes `0`; any nonzero result stops the gate immediately.

- [ ] **Step 3: Run project-level GodotIQ gates**

Run:

1. `validate(target="project", detail="brief")` and compare with the pre-change baseline; no new issues.
2. `check_errors(scope="project")`; zero parser/compile errors.
3. `signal_map(find="orphans", detail="brief")`; zero new orphan signals.
4. `verify_project_runs(scene="main", check_scope="project", stop_after=false)`; PASS.
5. In game context, instantiate `WorldRunStartService` with a no-op commit callback and call `start("ac9-6-runtime", {}, "RETURN_RESULT", &"brakka_rustbanner")`. Return and assert `ok=true`, `plan.get_version()==3`, `plan.get_towns().size()==9`, and `plan.get_roads().size()==9`. Build a town-coordinate lookup from `plan.get_towns()` and assert each road's two resolved town records have the same `habitat_id`.
6. Read the debug console; no new errors.
7. Stop the game.

Use `exec(context="game")` for step 5. Do not use editor-context execution for this runtime proof.

No screenshot is required because AC9.6 changes topology data and AC9.10 owns final visual presentation.

- [ ] **Step 4: Write verification evidence and close AC9.6**

In `verification.md`, record:

- spec and design links;
- branch and implementation commit IDs;
- the criterion matrix from this plan;
- all twelve commands, exit codes, named behaviors covered, and log links;
- V3 fixture path, byte count `8236`, line count `292`, and SHA-256 `0ffe96dff287d96deb4889ba6556f1adf4aad27ff9646333f48434191824672d`;
- GodotIQ project/runtime results;
- explicit confirmation that V1/V2 fixture files were unchanged;
- explicit deferral of cross-habitat roads to AC9.7/V4 and presentation to AC9.10.

Only after every recorded gate passes, change AC9.6 to `[x]` in `GAME_DESIGN_SPEC_MVP.md` and link `AC9/Evidence/AC9.6/verification.md`.

- [ ] **Step 5: Commit documentation and evidence**

```powershell
git add -- Docs/superpowers/plans/2026-09-18-ac9-clans-and-habitats.md Docs/Specs/AC9/Evidence/AC9.6 Docs/Specs/GAME_DESIGN_SPEC_MVP.md
git commit -m "test: verify AC9.6 internal habitat roads"
```

## Final completion check

- [ ] `git diff main...HEAD --check` reports no whitespace errors.
- [ ] `git status --short` shows only the user's pre-existing unstaged `.github` changes.
- [ ] `git diff main...HEAD --name-only` contains only AC9.6 implementation, tests, fixture, plan/spec, and evidence files.
- [ ] V1 and V2 golden fixture hashes match their pre-implementation values.
- [ ] The V3 fixture hash is `0ffe96dff287d96deb4889ba6556f1adf4aad27ff9646333f48434191824672d`.
- [ ] AC9.6 has complete automated and runtime evidence; AC9.7 and AC9.10 remain unchecked.
