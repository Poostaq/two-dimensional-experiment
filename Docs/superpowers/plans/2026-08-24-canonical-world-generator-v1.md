# Canonical World Generator V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and prove the pure, deterministic radius-8 Generator V1 domain and its immutable golden validation package without changing the production 25-cell world.

**Architecture:** New focused `RefCounted` domain classes own geometry, priority hashing, immutable plan data, canonical serialization, constraint solving, and orchestration. A fixture-authoring entry generates the reviewed golden corpus before production Generator V1 is implemented; production tests then consume those files read-only. `MapController`, scenes, saves, and production entry authority remain unchanged.

**Tech Stack:** Godot 4, typed GDScript, standalone headless test scripts, GodotIQ structured inspection/validation, UTF-8 canonical text artifacts, JSON manifests, SHA-256 fixture integrity.

---

## Authority and scope

Read before execution:

- `Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md`
- `Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md`
- `AGENTS.md`
- `GODOTIQ_RULES.md`

This plan closes the domain portions of WM-T01, WM-T02, WM-T03, WM-T04, WM-T05, and WM-T12. It does not integrate saves, run start, `MapController`, rendering, HUD, camera, minimap, or production scenes.

The current files below are read-only during this plan:

- `Scripts/Map/hex_map_model.gd`
- `Scripts/Map/map_controller.gd`
- `Scripts/Map/hex_tile_view.gd`
- `Scenes/game_world.tscn`
- `Scenes/map_hex_tile.tscn`
- every frozen test named by the migration authority

## Concrete file map

### Production domain files created

| File | Single responsibility |
|---|---|
| `Scripts/WorldMap/world_generation_error.gd` | Typed four-code world failure value; this plan uses only constraint/internal generation codes |
| `Scripts/WorldMap/hex_world_geometry.gd` | Radius validation, canonical coordinate enumeration, neighbors, and distance |
| `Scripts/WorldMap/world_priority.gd` | Seed normalization, exact payload construction, FNV-1a32, and stable candidate ordering |
| `Scripts/WorldMap/world_plan.gd` | Complete in-memory V1 plan value and non-mutating accessors |
| `Scripts/WorldMap/world_plan_codec_v1.gd` | Exact canonical UTF-8 serialization, parsing, and plan validation |
| `Scripts/WorldMap/world_constraint_solver_v1.gd` | Include-first deterministic town and forest backtracking |
| `Scripts/WorldMap/hex_world_generator_v1.gd` | Fixed eight-stage Generator V1 orchestration and atomic result publication |

### Fixture authoring and tests created

| File | Single responsibility |
|---|---|
| `Tools/WorldMap/generator_v1_fixture_author.gd` | Explicit developer-only corpus authoring; never called by production tests |
| `Tests/WorldMap/test_world_priority_v1.gd` | Payload, seed hex, FNV vectors, unsigned ordering |
| `Tests/WorldMap/test_hex_world_geometry.gd` | 217-cell geometry and canonical order |
| `Tests/WorldMap/test_world_constraint_solver_v1.gd` | Town/forest constraints, stable output, unsatisfiable result |
| `Tests/WorldMap/test_world_plan_codec_v1.gd` | Exact bytes, record order, round trip, validation rejection |
| `Tests/WorldMap/test_hex_world_generator_v1.gd` | Corpus summaries, roads, encounters, atomic generation |
| `Tests/WorldMap/test_generator_v1_fixture_integrity.gd` | Read-only manifest SHA-256 and complete-artifact checks |

### Immutable fixture and evidence files created

```text
Tests/Fixtures/WorldMap/GeneratorV1/
  fnv_vectors.json
  corpus_manifest.json
  empty-seed.world
  golden-alpha.world
  golden-beta.world
  town-road-01.world
  unicode-lodz.world
  unsatisfiable-town-config.json

Docs/Specs/WorldMap/Evidence/GeneratorV1/
  baseline/
    base-sha.txt
    branch-provenance.txt
    frozen-tests.sha256
    frozen-legacy.log
  red/
    priority-red.log
    geometry-red.log
    solver-red.log
    codec-red.log
    generator-red.log
  fixture-review/
    fixture-author-command.txt
    corpus-diff.txt
    fixture-hashes.sha256
    approval.md
  green/
    domain-tests.log
    fixture-integrity.log
    godotiq-validation.json
```

## Fixed interfaces

Later tasks use these exact public signatures:

```gdscript
# world_generation_error.gd
class_name WorldGenerationError
extends RefCounted

const WORLD_CONSTRAINT_UNSATISFIABLE := "WORLD_CONSTRAINT_UNSATISFIABLE"
const WORLD_GENERATION_INTERNAL_ERROR := "WORLD_GENERATION_INTERNAL_ERROR"
const WORLD_VERSION_UNSUPPORTED := "WORLD_VERSION_UNSUPPORTED"
const LEGACY_WORLD_SAVE_UNSUPPORTED := "LEGACY_WORLD_SAVE_UNSUPPORTED"

var code: String
var seed_hex: String
var generator_version: int
var feature_namespace: String
var failed_constraint: String

# hex_world_geometry.gd
class_name HexWorldGeometry
extends RefCounted

static func get_canonical_coords(radius: int = 8) -> Array[Vector2i]
static func is_valid_coord(coord: Vector2i, radius: int = 8) -> bool
static func get_neighbors(coord: Vector2i, radius: int = 8) -> Array[Vector2i]
static func get_hex_distance(a: Vector2i, b: Vector2i) -> int

# world_priority.gd
class_name WorldPriority
extends RefCounted

static func normalize_seed(seed_text: String) -> String
static func seed_hex(seed_text: String) -> String
static func payload(version: int, seed_text: String, feature_namespace: String, index: int, coord: Vector2i) -> String
static func fnv1a32_ascii(value: String) -> int
static func rank_coords(coords: Array[Vector2i], version: int, seed_text: String, feature_namespace: String, index: int = -1) -> Array[Vector2i]

# world_plan_codec_v1.gd
class_name WorldPlanCodecV1
extends RefCounted

static func serialize(plan: WorldPlan) -> PackedByteArray
static func parse(bytes: PackedByteArray) -> Dictionary
static func validate(plan: WorldPlan) -> WorldGenerationError

# hex_world_generator_v1.gd
class_name HexWorldGeneratorV1
extends RefCounted

const VERSION := 1
func generate(seed_text: String, config: Dictionary = {}) -> Dictionary
```

`generate()` returns exactly one of:

```gdscript
{"ok": true, "plan": complete_world_plan, "error": null}
{"ok": false, "plan": null, "error": world_generation_error}
```

No partial plan is returned on failure.

## Task 1: Establish branch provenance and freeze the legacy baseline

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/base-sha.txt`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/branch-provenance.txt`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/frozen-tests.sha256`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/frozen-legacy.log`

- [ ] **Step 1: Preserve unrelated work and update the integration branch**

In the primary workspace, record `git status --short`. Stash only unrelated tracked changes if any; do not add or remove the three known unrelated untracked files. Then run:

```powershell
git switch main
git pull --ff-only origin main
$baseSha = git rev-parse HEAD
git switch -c feat/world-generator-v1
```

Expected: branch `feat/world-generator-v1` is based on the updated `origin/main`; no worktree is created.

- [ ] **Step 2: Record provenance**

Use `apply_patch` to write `base-sha.txt` as the full `$baseSha` plus LF and `branch-provenance.txt` with these exact keys:

```text
branch=feat/world-generator-v1
upstream=origin/main
base_sha=<full recorded SHA>
target_design=Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md
migration_authority=Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md
```

- [ ] **Step 3: Hash the frozen tests**

```powershell
$frozen = @(
  'Tests/Map/test_hex_map_model.gd',
  'Tests/Map/test_map_controller_runtime.gd',
  'Tests/Map/test_ac1_1_runtime_step_counts.gd',
  'Tests/Map/test_ac1_2_encounter_determinism.gd',
  'Tests/Map/test_ac1_2_hex_tile_view_states.gd',
  'Tests/Map/test_ac1_2_runtime_encounter_layout.gd',
  'Tests/Map/test_ac1_3_mouse_navigation.gd',
  'Tests/Map/test_ac1_4_encounter_overlay.gd',
  'Tests/Map/test_ac1_5_sudden_death.gd',
  'Tests/Map/test_ac2_1_battle_arena.gd',
  'Tests/Map/test_ac3_1_recruitment_integration.gd',
  'Tests/Map/test_ac3_3_party_management_integration.gd',
  'Tests/Map/test_world_turn_counter.gd',
  'Tests/Run/test_ac3_1_run_roster.gd',
  'Tests/Run/test_ac3_3_party_formation.gd'
)
$frozen | Get-FileHash -Algorithm SHA256 | Sort-Object Path | ForEach-Object {
  '{0}  {1}' -f $_.Hash.ToLowerInvariant(), (Resolve-Path -Relative $_.Path).Replace('\','/')
} | Set-Content -Encoding utf8NoBOM 'Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/frozen-tests.sha256'
```

Expected: 15 stable SHA-256 records.

- [ ] **Step 4: Run the frozen suite**

Use the discovered Godot executable path in `$godotExe`, then:

```powershell
$log = 'Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/frozen-legacy.log'
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
foreach ($test in $frozen) {
  & $godotExe --headless --path . --script ("res://" + $test.Replace('\','/')) *>> $log
  if ($LASTEXITCODE -ne 0) { throw "Frozen test failed: $test" }
}
```

Expected: all 15 scripts exit `0`; stop on the first failure.

- [ ] **Step 5: Commit the baseline evidence**

```powershell
git add Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline
git commit -m "test: freeze legacy world baseline"
```

## Task 2: Lock priority hashing and geometry with RED tests

**Files:**
- Create: `Tests/WorldMap/test_world_priority_v1.gd`
- Create: `Tests/WorldMap/test_hex_world_geometry.gd`
- Create: `Tests/Fixtures/WorldMap/GeneratorV1/fnv_vectors.json`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/red/priority-red.log`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/red/geometry-red.log`

- [ ] **Step 1: Add immutable FNV inputs**

Create `fnv_vectors.json` with the three exact payload/decimal/hex rows from the target design. Store decimal values as JSON integers and hex values as lowercase strings.

- [ ] **Step 2: Write the priority RED test**

The standalone `SceneTree` test must load `res://Scripts/WorldMap/world_priority.gd`, assert empty seed normalization, UTF-8 lowercase seed hex, exact payload bytes, all three unsigned FNV results, and tie-break ordering by `q` then `r`. Its failure helper must call `quit(1)`; complete success calls `quit(0)`.

Core assertions:

```gdscript
assert_equal(priority.seed_hex(""), "64656661756c742d72756e", "empty seed")
assert_equal(priority.seed_hex("unicode-łódź"), "756e69636f64652dc582c3b364c5ba", "UTF-8 seed")
assert_equal(priority.fnv1a32_ascii(vectors[0].payload), 1594024070, "FNV vector 0")
assert_equal(priority.fnv1a32_ascii(vectors[1].payload), 3643676249, "FNV vector 1")
assert_equal(priority.fnv1a32_ascii(vectors[2].payload), 2873815939, "FNV vector 2")
```

- [ ] **Step 3: Write the geometry RED test**

Assert exactly 217 unique radius-8 cells, first coordinate `(-8, 0)`, last `(8, 0)`, validity rule `max(abs(q), abs(r), abs(-q-r)) <= 8`, canonical `q/r` order, six ordered center neighbors, edge clipping, symmetry, and start/boss distance `16`.

- [ ] **Step 4: Run both tests and preserve RED evidence**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_priority_v1.gd *> Docs/Specs/WorldMap/Evidence/GeneratorV1/red/priority-red.log
if ($LASTEXITCODE -eq 0) { throw 'Priority test unexpectedly passed before implementation' }
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_geometry.gd *> Docs/Specs/WorldMap/Evidence/GeneratorV1/red/geometry-red.log
if ($LASTEXITCODE -eq 0) { throw 'Geometry test unexpectedly passed before implementation' }
```

Expected: both fail because their production scripts do not exist.

- [ ] **Step 5: Commit RED tests and reviewed vectors**

```powershell
git add Tests/WorldMap/test_world_priority_v1.gd Tests/WorldMap/test_hex_world_geometry.gd Tests/Fixtures/WorldMap/GeneratorV1/fnv_vectors.json Docs/Specs/WorldMap/Evidence/GeneratorV1/red
git commit -m "test: lock world priority and geometry contracts"
```

## Task 3: Implement priority hashing and geometry GREEN

**Files:**
- Create: `Scripts/WorldMap/world_priority.gd`
- Create: `Scripts/WorldMap/hex_world_geometry.gd`
- Test: `Tests/WorldMap/test_world_priority_v1.gd`
- Test: `Tests/WorldMap/test_hex_world_geometry.gd`

- [ ] **Step 1: Inspect before creation**

Use GodotIQ `file_context(detail="brief")` on `Scripts/Map/hex_map_model.gd` to confirm the existing neighbor order and FNV constants. Do not modify it.

- [ ] **Step 2: Implement `WorldPriority`**

Use exact constants `2166136261`, `16777619`, and `0xffffffff`. Convert the normalized seed with `to_utf8_buffer().hex_encode()`. Validate namespace against `^[a-z0-9_-]+$`. Build payload with signed decimal `str()` values and no newline. Apply XOR, multiply, and mask after every ASCII byte. Ranking compares unsigned integer values, then `q`, then `r`.

```gdscript
static func fnv1a32_ascii(value: String) -> int:
    var hash_value: int = 2166136261
    for byte: int in value.to_ascii_buffer():
        hash_value = ((hash_value ^ byte) * 16777619) & 0xffffffff
    return hash_value
```

- [ ] **Step 3: Validate and compile `world_priority.gd`**

Run GodotIQ `validate(target="Scripts/WorldMap/world_priority.gd", detail="brief")`, then `check_errors(scope="Scripts/WorldMap/world_priority.gd")`.

- [ ] **Step 4: Implement `HexWorldGeometry`**

Enumerate `q` from `-radius` through `radius`, derive `r_min = max(-radius, -q-radius)` and `r_max = min(radius, -q+radius)`, and append `r` ascending. Reuse the current six axial offsets in their existing order. Return fresh typed arrays from public methods.

- [ ] **Step 5: Validate and compile `hex_world_geometry.gd`**

Run GodotIQ validation and error checks for this script only.

- [ ] **Step 6: Run both GREEN tests**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_priority_v1.gd
if ($LASTEXITCODE -ne 0) { throw 'Priority GREEN failed' }
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_geometry.gd
if ($LASTEXITCODE -ne 0) { throw 'Geometry GREEN failed' }
```

Expected: both exit `0`.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/WorldMap/world_priority.gd Scripts/WorldMap/hex_world_geometry.gd
git commit -m "feat: add canonical world priority and geometry"
```

## Task 4: Add plan values, typed errors, and canonical codec through TDD

**Files:**
- Create: `Scripts/WorldMap/world_generation_error.gd`
- Create: `Scripts/WorldMap/world_plan.gd`
- Create: `Scripts/WorldMap/world_plan_codec_v1.gd`
- Create: `Tests/WorldMap/test_world_plan_codec_v1.gd`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/red/codec-red.log`

- [ ] **Step 1: Write the codec RED test**

Construct a valid small in-memory plan and assert: header/version, lowercase seed hex, fixed start/boss, canonical cell order, canonical road endpoints/order, forest cluster/order, UTF-8 without BOM, exactly one trailing LF, parse/serialize byte identity, and rejection of duplicate/missing/out-of-radius cells.

Required byte prefix:

```gdscript
var text := bytes.get_string_from_utf8()
assert_true(text.begins_with("TWDE-WORLD,1\nseed,64656661756c742d72756e\nstart,-8,0\nboss,8,0\n"), "canonical prefix")
assert_true(text.ends_with("\n") and not text.ends_with("\n\n"), "one trailing LF")
```

- [ ] **Step 2: Capture RED**

Run the codec test into `red/codec-red.log`; require nonzero exit because the scripts do not exist. Commit the test and RED log.

- [ ] **Step 3: Implement typed values**

`WorldGenerationError` declares all four canonical taxonomy constants and stores the exact fields in the fixed interface; this plan emits only the two generation codes. `WorldPlan` stores version, seed hex, start, boss, canonical cells, six canonical road edges, and ten indexed forest clusters. Constructor inputs are duplicated deeply; accessors return duplicates so callers cannot mutate internal state.

- [ ] **Step 4: Implement the codec**

Serialize records exactly as the target design specifies. `parse()` returns the same `{ok, plan, error}` dictionary shape used by generation. Parse only `TWDE-WORLD,1`; reject CRLF, BOM, missing final LF, extra blank records, wrong field counts, invalid tokens, duplicate cells, invalid town indices, unordered records, and invalid topology. `validate()` must require 217 cells, seven towns, six roads, ten clusters, protected start/boss rules, and exact forest membership consistency; it returns `null` on success and a typed error on failure.

- [ ] **Step 5: Validate each new script separately**

For each script, run GodotIQ `validate(detail="brief")` followed by `check_errors`; do not batch past an error.

- [ ] **Step 6: Run codec GREEN and commit**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v1.gd
if ($LASTEXITCODE -ne 0) { throw 'Codec GREEN failed' }
git add Scripts/WorldMap/world_generation_error.gd Scripts/WorldMap/world_plan.gd Scripts/WorldMap/world_plan_codec_v1.gd Tests/WorldMap/test_world_plan_codec_v1.gd Docs/Specs/WorldMap/Evidence/GeneratorV1/red/codec-red.log
git commit -m "feat: add canonical world plan codec"
```

## Task 5: Author and approve the immutable Generator V1 corpus

**Files:**
- Create: `Tools/WorldMap/generator_v1_fixture_author.gd`
- Create: all remaining files under `Tests/Fixtures/WorldMap/GeneratorV1/`
- Create: files under `Docs/Specs/WorldMap/Evidence/GeneratorV1/fixture-review/`

- [ ] **Step 1: Implement the developer-only fixture author**

The tool independently executes the target's fixed order: radius-8 enumeration; fixed starts; town include-first backtracking; coordinate-ordered MST; indexed forest-size hash and outer backtracking; encounter hash classification preserving the current 40% Safe rule while forcing start/towns Safe and boss Boss; validation; serialization. It accepts only `--output-dir` and `--verify-summaries`; it refuses to write outside a path ending in `Tests/Fixtures/WorldMap/GeneratorV1`.

Use namespaces `town`, `road`, `forest-size`, `forest-frontier`, and `encounter`. Non-indexed priorities use `i=-1`; cluster operations use the cluster index. Encounter classification is `safe` when the unsigned `encounter` priority modulo 100 is below 40, otherwise `combat`, before forced overrides.

- [ ] **Step 2: Validate the authoring script**

Use GodotIQ per-file validation and compilation checks.

- [ ] **Step 3: Generate the corpus once**

```powershell
$fixtureDir = 'Tests/Fixtures/WorldMap/GeneratorV1'
& $godotExe --headless --path . --script res://Tools/WorldMap/generator_v1_fixture_author.gd -- --output-dir $fixtureDir --verify-summaries
if ($LASTEXITCODE -ne 0) { throw 'Fixture authoring failed' }
```

Expected: five complete `.world` files match every published town coordinate and forest-size vector; the unsatisfiable JSON is copied exactly; `corpus_manifest.json` contains byte lengths, SHA-256 values, and required counts.

- [ ] **Step 4: Record independent review material**

Write the exact author command to `fixture-author-command.txt`. Run `git diff --no-index -- NUL <fixture>` equivalents or `git diff --word-diff=porcelain` against any prior reviewed corpus and store the normalized output in `corpus-diff.txt`. Hash every fixture in filename order into `fixture-hashes.sha256`.

- [ ] **Step 5: Commit the fixture candidate**

```powershell
git add Tools/WorldMap/generator_v1_fixture_author.gd Tests/Fixtures/WorldMap/GeneratorV1 Docs/Specs/WorldMap/Evidence/GeneratorV1/fixture-review
git commit -m "test: add Generator V1 golden corpus candidate"
$fixtureCommit = git rev-parse HEAD
```

- [ ] **Step 6: Obtain project-lead fixture approval**

Pause execution and present the manifest, corpus summaries, diff, hashes, and full `$fixtureCommit` for review. After explicit approval, use `apply_patch` to create `approval.md` with these exact keys and actual values:

```text
fixture_commit=<full fixture candidate SHA>
manifest_sha256=<lowercase SHA-256 of corpus_manifest.json>
reviewer=<project-lead identity recorded for this review>
reviewed_at=<ISO-8601 timestamp with offset>
status=APPROVED
```

Production Generator V1 implementation cannot begin before this record exists.

- [ ] **Step 7: Commit the approval record**

```powershell
git add Docs/Specs/WorldMap/Evidence/GeneratorV1/fixture-review/approval.md
git commit -m "docs: approve Generator V1 golden corpus"
```

## Task 6: Lock solver and generator behavior with RED tests

**Files:**
- Create: `Tests/WorldMap/test_world_constraint_solver_v1.gd`
- Create: `Tests/WorldMap/test_hex_world_generator_v1.gd`
- Create: `Tests/WorldMap/test_generator_v1_fixture_integrity.gd`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/red/solver-red.log`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/red/generator-red.log`

- [ ] **Step 1: Write solver tests**

Assert seven towns, protected-cell exclusion, every pair distance at least four, ten disjoint connected clusters of target sizes, stable same-seed output, and the radius-2 injected configuration returning `WORLD_CONSTRAINT_UNSATISFIABLE` with namespace `town` and no plan.

- [ ] **Step 2: Write generator tests**

For all five seeds, assert canonical town coordinates and cluster sizes from the target table, exactly 217 cells, six connected acyclic road edges, all towns Safe, start Safe, boss Boss, forest/terrain agreement, same-seed byte identity, and different traversal requests having no effect.

- [ ] **Step 3: Write fixture-integrity tests**

Read `corpus_manifest.json`, verify every listed file exists, recompute SHA-256 and byte length, parse it, assert all counts, and serialize back to byte-identical content. Never call the fixture author from this test.

- [ ] **Step 4: Capture RED**

Run solver and generator tests into their RED logs. Both must fail because `world_constraint_solver_v1.gd` and `hex_world_generator_v1.gd` do not exist. The fixture-integrity test must already pass against the approved corpus.

- [ ] **Step 5: Commit RED tests**

```powershell
git add Tests/WorldMap Docs/Specs/WorldMap/Evidence/GeneratorV1/red
git commit -m "test: lock Generator V1 behavior"
```

## Task 7: Implement deterministic constraints, roads, encounters, and atomic generation

**Files:**
- Create: `Scripts/WorldMap/world_constraint_solver_v1.gd`
- Create: `Scripts/WorldMap/hex_world_generator_v1.gd`
- Test: all `Tests/WorldMap/*.gd`

- [ ] **Step 1: Implement town solving**

Filter canonical cells by start, boss, and their neighbors. Rank with namespace `town`, index `-1`. Use include-first recursion; prune when remaining candidates are fewer than required slots; reject a candidate when its distance from any selected town is below four. Return the first complete seven-town solution.

- [ ] **Step 2: Implement forest solving**

For indices `0..9`, compute `3 + (priority(forest-size, index, Vector2i.ZERO) % 5)`. Enumerate connected sets include-first from ranked roots/frontiers while excluding protected and already selected cells. The outer recursion backtracks cluster choices when later clusters cannot complete. Preserve cluster identity even when clusters touch.

- [ ] **Step 3: Validate the solver script, then run solver GREEN**

Use GodotIQ validation/error checks, then run `test_world_constraint_solver_v1.gd`; require exit `0`.

- [ ] **Step 4: Implement deterministic MST and encounters**

Build all town pairs with endpoints internally canonical, sort by `(distance, a.q, a.r, b.q, b.r)`, and apply Kruskal with canonical town indices. Exactly six accepted edges must connect seven towns. Classify other cells through namespace `encounter`, `i=-1`, modulo-100 `< 40` Safe rule; force start/towns Safe and boss Boss.

- [ ] **Step 5: Implement atomic orchestration**

`generate()` performs the target's eight fixed stages inside the boundary. It returns no `WorldPlan` until solver and codec validation succeed. Valid unsatisfiable search returns the typed constraint code. Unexpected faults convert to `WORLD_GENERATION_INTERNAL_ERROR` with no partial plan.

- [ ] **Step 6: Validate generator, then run all Generator V1 tests**

Run GodotIQ per-file validation/error checks, followed by every `Tests/WorldMap/*.gd` script. Require every exit code to be `0`.

- [ ] **Step 7: Prove the fixture author is not a runtime dependency**

Run GodotIQ `dependency_graph(file="Scripts/WorldMap/hex_world_generator_v1.gd", depth=4, detail="brief")`. Expected: no dependency on `Tools/WorldMap/generator_v1_fixture_author.gd` and no scene/controller dependency.

- [ ] **Step 8: Commit GREEN implementation**

```powershell
git add Scripts/WorldMap/world_constraint_solver_v1.gd Scripts/WorldMap/hex_world_generator_v1.gd
git commit -m "feat: implement deterministic Generator V1"
```

## Task 8: Produce GREEN evidence and run the frozen regression gate

**Files:**
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/green/domain-tests.log`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/green/fixture-integrity.log`
- Create: `Docs/Specs/WorldMap/Evidence/GeneratorV1/green/godotiq-validation.json`
- Update: no production or frozen test files

- [ ] **Step 1: Verify frozen hashes are unchanged**

Recompute the Task 1 manifest and compare byte-for-byte with `baseline/frozen-tests.sha256`. Expected: identical.

- [ ] **Step 2: Capture all domain tests**

Run each `Tests/WorldMap/*.gd` in sorted filename order into `green/domain-tests.log`, preserving command and exit code. Run fixture integrity separately into `green/fixture-integrity.log`. Any nonzero exit blocks completion.

- [ ] **Step 3: Run GodotIQ project checks**

Run `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`. Store the structured outputs in `godotiq-validation.json`. Existing unrelated warnings must be identified; new Generator V1 errors or orphan signals block completion.

- [ ] **Step 4: Run the frozen legacy suite again**

Repeat Task 1 Step 4. Expected: all 15 exit `0`; the production 25-cell entry remains unchanged.

- [ ] **Step 5: Verify repository scope**

```powershell
git diff --name-only $baseSha...HEAD
git status --short
```

Expected: only the files named by this plan plus approved evidence are changed; unrelated untracked files remain untouched.

- [ ] **Step 6: Commit GREEN evidence**

```powershell
git add Docs/Specs/WorldMap/Evidence/GeneratorV1/green Docs/Specs/WorldMap/Evidence/GeneratorV1/baseline/frozen-legacy.log
git commit -m "test: record Generator V1 domain evidence"
```

## Completion gate

This plan is complete only when:

- all five golden artifacts match the approved target summaries and their manifest;
- fixture integrity and all WorldMap domain tests pass;
- the unsatisfiable fixture returns the exact typed error with no plan;
- GodotIQ reports no new script or dependency errors;
- all frozen legacy tests and hashes remain unchanged;
- production scenes and current Map scripts have no diff;
- every evidence artifact records the implementation SHA and command used;
- the branch contains only scoped commits and is ready for review, not production cutover.

Completion unlocks the second plan: versioned save envelope, unsupported-legacy handling, and run-start failure policies.
