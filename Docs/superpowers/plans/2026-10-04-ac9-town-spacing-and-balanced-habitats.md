# AC9 Town Spacing and Balanced Allied Habitats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate connected 69/69/70 allied habitats, keep the enemy's fixed 9-cell footprint, and place all nine towns away from both starts with globally nonadjacent placement whenever feasible.

**Architecture:** `WorldHabitatSolverV2` remains the topology orchestrator and replaces unrestricted multi-source BFS with deterministic quota-aware frontier growth. A new pure `WorldTownPlacementSolverV2` owns spawn filtering, global spacing search, deterministic fallback scoring, and canonical town records; `WorldPlanCodecV2` reuses those rules when validating persisted V2/V3 topology.

**Tech Stack:** Godot 4.7.2, typed GDScript, SceneTree test runners, GodotIQ validation/runtime tools, canonical text fixtures, Git.

---

## File map

- Create `Scripts/WorldMap/world_town_placement_solver_v2.gd`: pure nine-town constraint search and deterministic fallback scoring.
- Create `Tests/WorldMap/test_world_town_placement_solver_v2.gd`: focused feasible, fallback, spawn-clearance, capacity, and determinism tests.
- Modify `Scripts/WorldMap/world_habitat_solver_v2.gd`: seeded 69/69/70 quotas, quota-aware connected partitioning, and cross-partition town-result selection.
- Modify `Tests/WorldMap/test_ac9_habitats_and_towns.gd`: corpus assertions for balance, enemy size, spawn clearance, and global town spacing.
- Modify `Scripts/WorldMap/world_plan_codec_v2.gd`: enforce balanced counts, seeded 70-cell ownership, spawn clearance, and canonical town selection.
- Modify `Tests/WorldMap/test_world_plan_codec_v2.gd`: direct and serialized mutation coverage for every new invariant.
- Modify `Tests/WorldMap/test_hex_world_generator_v3.gd`: assert inherited balance/spacing and unchanged internal-road pairing.
- Modify `Tests/WorldMap/test_generator_v3_fixture_author.gd`: replace the approved V3 SHA-256 after regeneration.
- Regenerate `Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world` and `Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world`.
- Modify `Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md`: mark the original unbalanced/no-spacing clauses as superseded by the approved correction.

### Task 1: Establish the baseline and add the pure town-placement solver

**Files:**
- Create: `Tests/WorldMap/test_world_town_placement_solver_v2.gd`
- Create: `Scripts/WorldMap/world_town_placement_solver_v2.gd`

- [ ] **Step 1: Capture the required pre-refactor baseline and dependency impact**

Use GodotIQ `validate(target="project", detail="brief")`, then run `impact_check` for `world_habitat_solver_v2.gd` and `world_plan_codec_v2.gd` with action `modify`. Record the existing warning/info counts so only new issues are treated as regressions.

- [ ] **Step 2: Write the failing focused solver test**

Create a SceneTree runner that loads `res://Scripts/WorldMap/world_town_placement_solver_v2.gd` and exercises this public contract:

```gdscript
var result: Dictionary = solver.solve(
    "town-solver-feasible",
    coords,
    habitat_by_coord,
    Vector2i(-8, 0),
    Vector2i(8, 0)
)
_expect(result.get("ok", false), "feasible layout succeeds")
_expect_equal(result["towns"].size(), 9, "nine towns")
_expect_equal(result["adjacent_pair_count"], 0, "no adjacent pairs")
_expect(result["fully_spaced"], "full spacing reported")
for town: Dictionary in result["towns"]:
    _expect(GEOMETRY.get_hex_distance(town["coord"], Vector2i(-8, 0)) >= 2, "player clearance")
    _expect(GEOMETRY.get_hex_distance(town["coord"], Vector2i(8, 0)) >= 2, "enemy clearance")
```

Add a deliberately small partition with exactly one possible nine-town selection containing adjacent pairs, and assert `fully_spaced == false`, the exact adjacent-pair count, and the exact total-pairwise-distance score. Add an insufficient-capacity case caused by spawn filtering and two identical calls proving result equality.

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\Projects\two-dimension-exploration' --script res://Tests/WorldMap/test_world_town_placement_solver_v2.gd
```

Expected: nonzero exit because `world_town_placement_solver_v2.gd` does not exist.

- [ ] **Step 4: Implement the minimal pure solver**

Create `WorldTownPlacementSolverV2` with this API and result shape:

```gdscript
class_name WorldTownPlacementSolverV2
extends RefCounted

const VERSION := 2
const MIN_DISTANCE := 2
const TOWNS_PER_HABITAT := 3
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")

func solve(
    seed_text: String,
    coords: Array[Vector2i],
    habitat_by_coord: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Dictionary:
    var candidates_by_habitat: Dictionary = _rank_eligible_candidates(
        seed_text, coords, habitat_by_coord, start_coord, enemy_coord
    )
    if not _has_capacity(candidates_by_habitat):
        return _failure()
    var fully_spaced: Array[Vector2i] = _find_first_zero_adjacency(candidates_by_habitat)
    if not fully_spaced.is_empty():
        return _success(fully_spaced, 0, true)
    var fallback: Dictionary = _find_best_fallback(candidates_by_habitat)
    if fallback.is_empty():
        return _failure()
    return _success(
        fallback["coords"],
        int(fallback["adjacent_pair_count"]),
        false
    )
```

Use two deterministic depth-first passes. The first rejects a candidate immediately when its distance from any selected town is less than 2 and returns the first complete selection in habitat/candidate order. The second explores all remaining combinations, pruning branches whose current adjacency count already exceeds the best score, and compares completed selections by fewest adjacent pairs, greatest total pairwise distance, then traversal order. `_success` emits town IDs and local/global order exactly as V2 currently does.

- [ ] **Step 5: Validate the new script, compile it, and run GREEN**

Run GodotIQ `validate` and `check_errors` against the new production script, then run the focused SceneTree command from Step 3.

Expected: `PASS test_world_town_placement_solver_v2`, exit 0, and no parser errors.

- [ ] **Step 6: Commit the isolated solver**

```powershell
git add -- Scripts/WorldMap/world_town_placement_solver_v2.gd Tests/WorldMap/test_world_town_placement_solver_v2.gd
git commit -m "feat: add deterministic global town placement solver"
```

### Task 2: Generate connected balanced allied habitats and integrate town selection

**Files:**
- Modify: `Tests/WorldMap/test_ac9_habitats_and_towns.gd`
- Modify: `Scripts/WorldMap/world_habitat_solver_v2.gd`

- [ ] **Step 1: Add failing corpus assertions**

For every existing seed/config corpus result, derive counts from `plan.get_habitat_cells()` and add these assertions:

```gdscript
var allied_counts: Array[int] = [
    plan.get_habitat_cells("main").size(),
    plan.get_habitat_cells("ally_0").size(),
    plan.get_habitat_cells("ally_1").size(),
]
allied_counts.sort()
_assert_equal(allied_counts, [69, 69, 70], "%s balanced allied habitat sizes" % seed_text)
_assert_equal(plan.get_habitat_cells("enemy").size(), 9, "%s enemy footprint size" % seed_text)
for town_value: Variant in plan.get_towns():
    var town: Dictionary = town_value
    _assert_true(_geometry_script.get_hex_distance(town["coord"], plan.get_start_coord()) >= 2, "%s town clears player start" % seed_text)
    _assert_true(_geometry_script.get_hex_distance(town["coord"], plan.get_boss_coord()) >= 2, "%s town clears enemy start" % seed_text)
_assert_equal(_adjacent_town_pair_count(plan.get_towns()), 0, "%s global town spacing" % seed_text)
```

Add `_adjacent_town_pair_count(towns: Array) -> int` using `HexWorldGeometry.get_hex_distance`. Keep the existing enemy-footprint, connectivity, ownership, deterministic-order, and failure assertions.

- [ ] **Step 2: Run the AC9 suite and verify RED**

Run the SceneTree runner for `test_ac9_habitats_and_towns.gd`.

Expected: failures showing current counts such as `21/62/125` instead of `69/69/70`, plus adjacent-town failures.

- [ ] **Step 3: Add seeded quota calculation and quota-aware partition growth**

After GodotIQ `file_context` and `impact_check`, add the town solver dependency and replace `_partition` with quota-aware connected growth:

```gdscript
static var TOWN_SOLVER_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_town_placement_solver_v2.gd")

func _quota_by_habitat(seed_text: String, anchors: Array[Vector2i]) -> Dictionary:
    var ranked: Array[Vector2i] = PRIORITY_SCRIPT.rank_coords(
        anchors, VERSION, seed_text, "habitat-quota-v2"
    )
    var bonus_anchor: Vector2i = ranked[0]
    var quotas: Dictionary = {}
    for index: int in range(ALLIED_HABITAT_IDS.size()):
        quotas[ALLIED_HABITAT_IDS[index]] = 70 if anchors[index] == bonus_anchor else 69
    return quotas
```

Maintain one FIFO frontier and cursor per habitat. Seed each frontier with its anchor. In stable habitat order, process the next frontier cell and claim canonical neighbors only while that habitat remains below its quota. Enqueue every claimed cell into the same habitat frontier. Repeat rounds until all 208 allied cells are owned; reject a partition if a full round makes no claim or final counts differ from the quotas. Because every claim is adjacent to an already owned cell, every accepted habitat is connected.

- [ ] **Step 4: Integrate the pure town solver and cross-partition fallback**

Replace `_select_towns` with `TOWN_SOLVER_SCRIPT.new().solve(...)`. Reject partitions that do not return nine towns. Return immediately on `fully_spaced == true`; otherwise retain the best result using:

```gdscript
func _is_better_fallback(candidate: Dictionary, current: Dictionary) -> bool:
    if current.is_empty():
        return true
    var candidate_adjacent: int = int(candidate["adjacent_pair_count"])
    var current_adjacent: int = int(current["adjacent_pair_count"])
    if candidate_adjacent != current_adjacent:
        return candidate_adjacent < current_adjacent
    return int(candidate["total_pairwise_distance"]) > int(current["total_pairwise_distance"])
```

Keep the earlier result on a full tie so stable partition order remains the final tie-break. If every valid partition lacks hard town capacity, return `balanced_partition_with_town_capacity` through the existing atomic `_failure` shape.

- [ ] **Step 5: Validate after the script change and run GREEN**

Run GodotIQ `validate` and `check_errors` for `world_habitat_solver_v2.gd`, then run both the focused town solver suite and `test_ac9_habitats_and_towns.gd`.

Expected: both PASS; every corpus entry reports 69/69/70 allied cells, 9 enemy cells, and zero adjacent town pairs.

- [ ] **Step 6: Commit balanced topology generation**

```powershell
git add -- Scripts/WorldMap/world_habitat_solver_v2.gd Tests/WorldMap/test_ac9_habitats_and_towns.gd
git commit -m "feat: balance allied habitats and space towns"
```

### Task 3: Enforce the new topology contract in the V2 codec

**Files:**
- Modify: `Tests/WorldMap/test_world_plan_codec_v2.gd`
- Modify: `Scripts/WorldMap/world_plan_codec_v2.gd`

- [ ] **Step 1: Add failing plan and byte-mutation tests**

Extend `_test_plan_mutations` with four independently valid-looking mutations:

1. Transfer a non-anchor border cell between allied habitats to produce `68/70/70` while keeping total coverage.
2. Move a town to an empty cell at distance 1 from the player start, updating both affected `town_index` values and encounter safety.
3. Move a town to an eligible same-habitat noncanonical coordinate, updating cell town indices.
4. Transfer the 70th cell so a different allied habitat owns the seeded extra quota.

For each mutation call `_assert_serialized_plan_rejected(...)`. Add helper searches that select border and replacement coordinates from the generated plan rather than hard-coding fixture line numbers.

- [ ] **Step 2: Run the codec suite and verify RED**

Run `test_world_plan_codec_v2.gd` headlessly.

Expected: at least the balanced-count, seeded-quota, spawn-clearance, and noncanonical-town mutations are accepted by the old codec, causing test failure.

- [ ] **Step 3: Add codec dependencies and balance validation**

After GodotIQ `file_context` and `impact_check`, load `WorldPriority` and `WorldTownPlacementSolverV2`. Decode the stored seed with a round-trip guard:

```gdscript
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var TOWN_SOLVER_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_town_placement_solver_v2.gd")

static func _seed_text(seed_hex: String) -> String:
    var bytes: PackedByteArray = seed_hex.hex_decode()
    var seed_text: String = bytes.get_string_from_utf8()
    return seed_text if seed_text.to_utf8_buffer().hex_encode() == seed_hex else ""
```

Count allied membership during topology validation. Require sorted counts `[69, 69, 70]`. Rank the three stored anchors with namespace `habitat-quota-v2` and require the habitat at the first ranked anchor to contain 70 cells. Retain the exact existing enemy-footprint comparison.

- [ ] **Step 4: Add spawn-clearance and canonical-town validation**

Before accepting the town collection, reject any town whose distance from either start is less than 2. Build `habitat_by_coord` from the plan cells and rerun the pure town solver using canonical coordinates and the decoded seed. Require solver success and exact town-array equality:

```gdscript
var canonical: Dictionary = TOWN_SOLVER_SCRIPT.new().solve(
    seed_text,
    GEOMETRY_SCRIPT.get_canonical_coords(RADIUS),
    habitat_by_coord,
    plan.get_start_coord(),
    plan.get_boss_coord()
)
if not canonical.get("ok", false) or canonical.get("towns", []) != plan.get_towns():
    return _validation_error(plan, "noncanonical_town_placement")
```

Use focused constraints `allied_habitat_balance`, `allied_habitat_bonus_quota`, `town_spawn_clearance`, and `noncanonical_town_placement`.

- [ ] **Step 5: Validate and run codec plus generator suites**

Run GodotIQ `validate` and `check_errors` for the codec, then run:

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\Projects\two-dimension-exploration' --script res://Tests/WorldMap/test_world_plan_codec_v2.gd
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\Projects\two-dimension-exploration' --script res://Tests/WorldMap/test_ac9_habitats_and_towns.gd
```

Expected: both PASS with no parser/runtime errors.

- [ ] **Step 6: Commit codec enforcement**

```powershell
git add -- Scripts/WorldMap/world_plan_codec_v2.gd Tests/WorldMap/test_world_plan_codec_v2.gd
git commit -m "fix: validate balanced canonical AC9 topology"
```

### Task 4: Preserve V3 roads and regenerate canonical fixtures

**Files:**
- Modify: `Tests/WorldMap/test_hex_world_generator_v3.gd`
- Modify: `Tests/WorldMap/test_generator_v3_fixture_author.gd`
- Regenerate: `Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world`
- Regenerate: `Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world`

- [ ] **Step 1: Extend V3 assertions before changing fixtures**

In `_test_v2_equivalence`, assert sorted allied counts `[69, 69, 70]`, enemy count `9`, every town's distance from both starts is at least `2`, and global adjacent-pair count is `0`. Keep exact V2/V3 non-road equality and `_assert_internal_pairs` so relocated endpoints cannot alter the road contract.

- [ ] **Step 2: Run V3 and fixture-author tests to verify the expected fixture RED**

Run `test_hex_world_generator_v3.gd`, `test_generator_v2_fixture_author.gd`, and `test_generator_v3_fixture_author.gd` without `--write`.

Expected: V3 topology assertions pass; both fixture authors fail because canonical bytes changed, and V3 additionally reports an outdated approved hash.

- [ ] **Step 3: Regenerate V2 and obtain the new V3 hash**

Run V2 authoring with `-- --write`. For V3, temporarily calculate and print the new production hash before its approval comparison, copy that exact lowercase SHA-256 into `EXPECTED_SHA256`, validate/check the modified test script, then run V3 authoring with `-- --write`.

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\Projects\two-dimension-exploration' --script res://Tests/WorldMap/test_generator_v2_fixture_author.gd -- --write
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path 'D:\Projects\two-dimension-exploration' --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd -- --write
```

- [ ] **Step 4: Verify fixture integrity and unchanged V1 bytes**

Run both fixture authors without `--write`, `test_world_plan_codec_v2.gd`, `test_hex_world_generator_v3.gd`, and `test_generator_v1_fixture_integrity.gd`.

Expected: all PASS; V2/V3 fixtures match production; V1 fixture integrity remains unchanged.

- [ ] **Step 5: Commit fixture and V3 test updates**

```powershell
git add -- Tests/WorldMap/test_hex_world_generator_v3.gd Tests/WorldMap/test_generator_v3_fixture_author.gd Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world
git commit -m "test: approve balanced AC9 world fixtures"
```

### Task 5: Reconcile governing documentation and run final verification

**Files:**
- Modify: `Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md`

- [ ] **Step 1: Reconcile the superseded clauses**

Update the status/supersession note to link `2026-10-04-ac9-town-spacing-and-balanced-habitats-design.md`. Replace the old “first connected partition with capacity” and “no additional spacing rule” statements with a concise note that the correction governs allied area quotas, spawn clearance, global spacing, and fallback. Do not rewrite historical V1 behavior or the enemy-footprint contract.

- [ ] **Step 2: Run the complete focused regression set**

Run, at minimum:

```text
Tests/WorldMap/test_world_town_placement_solver_v2.gd
Tests/WorldMap/test_ac9_habitats_and_towns.gd
Tests/WorldMap/test_world_plan_codec_v2.gd
Tests/WorldMap/test_hex_world_generator_v3.gd
Tests/WorldMap/test_world_plan_codec_v3.gd
Tests/WorldMap/test_generator_v2_fixture_author.gd
Tests/WorldMap/test_generator_v3_fixture_author.gd
Tests/WorldMap/test_generator_v1_fixture_integrity.gd
Tests/Run/test_world_run_start_service.gd
Tests/Save/test_world_run_save_codec_v8.gd
Tests/WorldMap/test_world_runtime_model.gd
Tests/WorldMap/test_world_production_scene.gd
```

Every runner must exit 0, print its PASS marker, and contain no unexpected `ERROR` line.

- [ ] **Step 3: Run GodotIQ project gates**

Run `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`. Compare validation counts with Task 1's baseline and investigate every new issue.

- [ ] **Step 4: Verify the production path in Play mode**

Use GodotIQ `run(action="play")`, `verify_project_runs()`, and `read_debug_console()`. Start a new run through the production launcher and inspect game state to prove version 3, start `(-8, 0)`, boss `(8, 0)`, allied counts `69/69/70`, enemy count `9`, nine towns with start clearance, zero adjacent pairs for the production seed, and nine internal roads. Stop the game afterward.

- [ ] **Step 5: Commit documentation and verification-ready state**

```powershell
git add -- Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md
git commit -m "docs: reconcile AC9 habitat and town contracts"
```

- [ ] **Step 6: Audit the final diff**

Run `git status --short`, `git diff HEAD~4 --check`, and inspect the task-branch commit list. Confirm that only the planned AC9 files are committed and the user's unrelated `.github` deletions/untracked skills remain unstaged and untouched.
