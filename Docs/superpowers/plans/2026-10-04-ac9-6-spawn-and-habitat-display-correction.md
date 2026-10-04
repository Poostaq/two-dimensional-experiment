# AC9.6 Spawn and Habitat Display Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reverse the current generated-world spawn contract so new V2/V3 plans place the player west and the enemy east, and show the occupied habitat's capitalized race name in the world HUD.

**Architecture:** Change the V2 topology source and V2 codec invariants together; V3 will continue to inherit that corrected non-road topology and add its nine internal roads. Regenerate both canonical fixtures because the user explicitly waived old V2/V3 save compatibility, then derive habitat `display_name` from validated `clan_id` so the existing HUD renders the owning race without a scene change.

**Tech Stack:** Godot 4.7.2, typed GDScript, GodotIQ structured editing and validation, headless `SceneTree` tests, canonical UTF-8 fixtures, SHA-256 fixture locks, PowerShell.

---

## Execution constraints

- Work in the primary workspace on `plan/ac9-6-internal-roads`; this repository forbids Git worktrees.
- Preserve the user's unstaged `.github/prompts` deletions and `.github/skills` additions. Never stage them.
- Before editing every `.gd` file, call GodotIQ `file_context(file, detail="brief")`. Call `impact_check` before changing generator or codec invariants.
- Use GodotIQ `script_ops` for `.gd` edits and `apply_patch` for Markdown. Never raw-write Godot files while the editor is open.
- After each `.gd` edit, run `validate(target=file, detail="brief")` and `check_errors(scope=file)` before editing another script.
- Use test-driven development: add the new expectation, observe the old behavior fail, make the minimum production change, then rerun the focused and neighboring tests.
- Use this executable for headless tests when the open editor does not intercept the process:

```powershell
$godotExe = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
```

- A headless invocation that prints only the engine banner is not a passing test. Require the test's `PASS` sentinel and expected assertion count. If the open editor intercepts standalone runs, execute the same production path with GodotIQ Play-mode game-context probes and record that limitation.

## File map

Modify:

- `Tests/WorldMap/test_ac9_habitats_and_towns.gd` — corrected V2 spawn, enemy-footprint, ownership, and encounter assertions.
- `Tests/WorldMap/test_world_runtime_model.gd` — corrected V2/V3 runtime spawn and habitat presentation assertions.
- `Tests/Run/test_world_run_start_service.gd` — corrected production V3 session/run-state coordinates.
- `Scripts/WorldMap/hex_world_generator_v2.gd` — choose west for player and east for enemy.
- `Scripts/WorldMap/world_plan_codec_v2.gd` — enforce the corrected fixed origins.
- `Tests/WorldMap/test_world_plan_codec_v2.gd` — replace the V2 golden hash after fixture regeneration.
- `Tests/WorldMap/test_world_plan_codec_v3.gd` — replace the V3 golden hash and make road rejection mutations independent of old fixture coordinates.
- `Tests/WorldMap/test_generator_v3_fixture_author.gd` — replace the expected V3 fixture hash.
- `Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world` — regenerated corrected V2 canonical bytes.
- `Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world` — regenerated corrected V3 canonical bytes.
- `Tests/WorldMap/test_ac8_4_habitat_rules.gd` — expect generated habitat names from `clan_id`.
- `Tests/UI/test_world_map_hud.gd` — prove a non-Goblin race name and unavailable fallback in the top bar.
- `Scripts/WorldMap/world_habitat_rules.gd` — return the capitalized owning race as `display_name`.
- `Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md` — correct the governing V2 orientation.
- `Docs/superpowers/plans/2026-09-18-ac9-clans-and-habitats.md` — correct aggregate spawn requirements.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — correct the player-facing overview, AC9.4 text, and walkthrough.
- `Docs/Specs/AC9/Evidence/AC9.6/verification.md` — record the superseding decision, new hashes, deletion, and runtime evidence.

No scene file changes are required. `WorldMapHud.set_habitat()` already renders values such as `Habitat: Goblin` from the resolved `display_name`.

## Task 1: Reverse the generated spawn contract

**Files:**

- Modify: `Tests/WorldMap/test_ac9_habitats_and_towns.gd`
- Modify: `Tests/WorldMap/test_world_runtime_model.gd`
- Modify: `Tests/Run/test_world_run_start_service.gd`
- Modify: `Scripts/WorldMap/hex_world_generator_v2.gd`
- Modify: `Scripts/WorldMap/world_plan_codec_v2.gd`

- [ ] **Step 1: Write failing V2 topology assertions**

In `test_ac9_habitats_and_towns.gd`, replace the old east-player/west-enemy assertions and independently lock the east enemy footprint:

```gdscript
_assert_equal(plan.get_start_coord(), Vector2i(-8, 0), "player starts west")
_assert_equal(plan.get_boss_coord(), Vector2i(8, 0), "enemy starts east")
_assert_equal(expected_enemy_footprint, [
    Vector2i(6, 0),
    Vector2i(6, 1),
    Vector2i(6, 2),
    Vector2i(7, -1),
    Vector2i(7, 0),
    Vector2i(7, 1),
    Vector2i(8, -2),
    Vector2i(8, -1),
    Vector2i(8, 0),
], "independent radius-eight enemy footprint")
```

Retain the existing assertions that the main habitat anchor equals `plan.get_start_coord()`, the enemy anchor equals `plan.get_boss_coord()`, the start encounter is safe, the boss encounter is unique, and neither spawn is forested or a town.

- [ ] **Step 2: Write failing runtime and production assertions**

In `_run_v2_contract()` in `test_world_runtime_model.gd`, change the two coordinate assertions to:

```gdscript
_expect(snapshot.player_coord == Vector2i(-8, 0), "v2 player starts west")
_expect(snapshot.boss_coord == Vector2i(8, 0), "v2 boss starts east")
```

In `_run_v3_contract()`, add two assertions and increment `EXPECTED_TEST_COUNT` by two:

```gdscript
var snapshot: WorldRuntimeSnapshot = model.get_snapshot()
_expect(snapshot.player_coord == Vector2i(-8, 0), "v3 player starts west")
_expect(snapshot.boss_coord == Vector2i(8, 0), "v3 boss starts east")
```

In the default-success branch of `test_world_run_start_service.gd`, replace the old coordinates and state labels:

```gdscript
_assert_equal(plan.get_start_coord(), Vector2i(-8, 0), "player starts at west extreme")
_assert_equal(plan.get_boss_coord(), Vector2i(8, 0), "boss starts at east extreme")
_assert_equal(success["run_state"].player_coord, plan.get_start_coord(), "state starts west")
_assert_equal(success["run_state"].boss_coord, plan.get_boss_coord(), "state boss is east")
```

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac9_habitats_and_towns.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_model.gd
& $godotExe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd
```

Expected: each exercised spawn assertion fails because current V2/V3 production returns player `(8, 0)` and enemy `(-8, 0)`. Parser errors are not an acceptable RED result.

- [ ] **Step 4: Reverse V2 generation**

In `hex_world_generator_v2.gd`, change only the extrema assignment:

```gdscript
var start_coord: Vector2i = extrema["west"]
var enemy_coord: Vector2i = extrema["east"]
```

Leave solver inputs, encounter overrides, forest protection, plan construction, and identity attachment unchanged so they consume the corrected semantic coordinates.

- [ ] **Step 5: Reverse V2 codec invariants**

In `world_plan_codec_v2.gd`, update the fixed-origin constants:

```gdscript
const START_COORD := Vector2i(-8, 0)
const BOSS_COORD := Vector2i(8, 0)
```

Do not loosen `fixed_origins`, `main_anchor`, `enemy_anchor`, `enemy_footprint`, `start_not_safe`, `boss_encounter`, or `sole_boss` validation. Those gates must now prove the reversed contract.

- [ ] **Step 6: Validate each production edit and verify behavioral GREEN**

After the required per-file GodotIQ checks, rerun:

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac9_habitats_and_towns.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_model.gd
& $godotExe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_generator_v3.gd
```

Expected: coordinate/topology/runtime assertions pass. Fixture-locked tests may still fail until Task 2 authors the approved replacement artifacts.

- [ ] **Step 7: Commit the semantic contract change**

```powershell
git add -- Scripts/WorldMap/hex_world_generator_v2.gd Scripts/WorldMap/world_plan_codec_v2.gd Tests/WorldMap/test_ac9_habitats_and_towns.gd Tests/WorldMap/test_world_runtime_model.gd Tests/Run/test_world_run_start_service.gd
git commit -m "fix: reverse generated world spawn contract"
```

## Task 2: Regenerate and relock V2/V3 canonical fixtures

**Files:**

- Modify: `Tests/WorldMap/test_world_plan_codec_v2.gd`
- Modify: `Tests/WorldMap/test_world_plan_codec_v3.gd`
- Modify: `Tests/WorldMap/test_generator_v3_fixture_author.gd`
- Modify: `Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world`
- Modify: `Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world`

- [ ] **Step 1: Make V3 mutation tests topology-independent**

Replace hard-coded old road coordinates in `_test_parse_rejections()` with mutations derived from the current first road:

```gdscript
var first_fields: PackedStringArray = lines[ROAD_INDEX].split(",", false)

var reversed: PackedStringArray = lines.duplicate()
reversed[ROAD_INDEX] = "road,%s,%s,%s,%s" % [
    first_fields[3], first_fields[4], first_fields[1], first_fields[2],
]
_expect_rejected(codec_v3, _text(reversed), "reversed road")

var self_edge: PackedStringArray = lines.duplicate()
self_edge[ROAD_INDEX] = "road,%s,%s,%s,%s" % [
    first_fields[1], first_fields[2], first_fields[1], first_fields[2],
]
_expect_rejected(codec_v3, _text(self_edge), "self edge")

var non_town: PackedStringArray = lines.duplicate()
non_town[ROAD_INDEX] = "road,0,0,%s,%s" % [first_fields[3], first_fields[4]]
_expect_rejected(codec_v3, _text(non_town), "non-town endpoint")

var noncanonical_int: PackedStringArray = lines.duplicate()
var padded_q: String = "+%s" % first_fields[1] if not first_fields[1].begins_with("-") else "-0%s" % first_fields[1].trim_prefix("-")
noncanonical_int[ROAD_INDEX] = "road,%s,%s,%s,%s" % [
    padded_q, first_fields[2], first_fields[3], first_fields[4],
]
_expect_rejected(codec_v3, _text(noncanonical_int), "noncanonical integer")
```

For the cross-habitat case, build coordinate strings from `plan.get_towns()` in `_test_parse_rejections()` by passing the generated plan into the function, selecting one town with `habitat_id == "main"` and one with `habitat_id == "ally_0"`, and replacing the first road with those endpoints. This preserves the intended rejection without coupling the test to one golden seed layout.

- [ ] **Step 2: Verify fixture tests are RED against the old artifacts**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v2_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v2.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v3.gd
```

Expected: old fixture bytes and old SHA-256 locks fail against the corrected generator output.

- [ ] **Step 3: Author replacement fixture bytes**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v2_fixture_author.gd -- --write
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd -- --write
Get-FileHash -Algorithm SHA256 -LiteralPath 'Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world'
Get-FileHash -Algorithm SHA256 -LiteralPath 'Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world'
```

Capture the two printed 64-character lowercase digests. Patch the V2 digest into `EXPECTED_GOLDEN_SHA256` in `test_world_plan_codec_v2.gd`. Patch the V3 digest into both `EXPECTED_GOLDEN_SHA256` in `test_world_plan_codec_v3.gd` and `EXPECTED_SHA256` in `test_generator_v3_fixture_author.gd`. The two V3 constants must be byte-identical.

- [ ] **Step 4: Verify canonical bytes and determinism GREEN**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v2_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v2.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v3.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_generator_v3.gd
```

Expected: all five tests print their PASS sentinel; clean and interleaved generation produce the newly locked bytes; V3 still contains exactly nine canonical internal roads.

- [ ] **Step 5: Preserve V1**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v1_fixture_integrity.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v1.gd
git status --short -- Tests/Fixtures/WorldMap/GeneratorV1
```

Expected: both tests pass and no V1 fixture file is modified.

- [ ] **Step 6: Commit regenerated contracts**

```powershell
git add -- Tests/WorldMap/test_world_plan_codec_v2.gd Tests/WorldMap/test_world_plan_codec_v3.gd Tests/WorldMap/test_generator_v3_fixture_author.gd Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world Tests/Fixtures/WorldMap/GeneratorV3/golden-ac9.world
git commit -m "test: relock reversed V2 and V3 worlds"
```

## Task 3: Present the owning race in the habitat top bar

**Files:**

- Modify: `Tests/WorldMap/test_ac8_4_habitat_rules.gd`
- Modify: `Tests/WorldMap/test_world_runtime_model.gd`
- Modify: `Tests/UI/test_world_map_hud.gd`
- Modify: `Scripts/WorldMap/world_habitat_rules.gd`

- [ ] **Step 1: Write failing habitat-rule expectations**

In the generated-habitat loop in `test_ac8_4_habitat_rules.gd`, replace the structural-ID expectation with:

```gdscript
var expected_race_name: String = String(record.clan_id).replace("_", " ").capitalize()
_expect(
    result.get("display_name", "") == expected_race_name,
    "v2 display name derives from owning race"
)
```

This exercises the main, both allies, and enemy habitat records.

In both generated contracts in `test_world_runtime_model.gd`, strengthen the habitat assertion:

```gdscript
_expect(
    habitat.get("ok", false)
    and habitat.get("habitat_id", &"") == &"main"
    and habitat.get("display_name", "") == "Goblin",
    "generated runtime exposes Goblin main habitat"
)
```

- [ ] **Step 2: Write the failing HUD presentation assertion**

In `test_world_map_hud.gd`, after the existing Goblin check, add one assertion and increment `EXPECTED_TEST_COUNT` by one:

```gdscript
hud.call("set_habitat", {"ok": true, "display_name": "Lizardman"})
_expect(habitat.text == "Habitat: Lizardman", "top bar shows the capitalized owning race")
```

Keep the existing `Habitat: Unavailable` assertion unchanged.

- [ ] **Step 3: Run focused tests and verify RED**

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac8_4_habitat_rules.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_model.gd
& $godotExe --headless --path . --script res://Tests/UI/test_world_map_hud.gd
```

Expected: generated habitat rules still return `Main`, `Ally 0`, `Ally 1`, and `Enemy`; the HUD-only dictionary test already passes and documents that no scene/layout change is needed.

- [ ] **Step 4: Derive display name from `clan_id`**

In `_resolve_generated()` in `world_habitat_rules.gd`, replace the old structural display name with:

```gdscript
var clan_id := String(clan_id_value)
var display_name: String = clan_id.replace("_", " ").capitalize()
return {
    "ok": true,
    "clan_id": StringName(clan_id),
    "display_name": display_name,
    "source": "Generated world v%d" % plan.get_version(),
    "habitat_id": StringName(habitat_id),
    "role": String(role_value),
    "anchor": anchor_value,
    "cell_count": cell_count,
    "error": &"",
}
```

The existing validation already rejects an empty `clan_id`; do not add a fallback to `habitat_id`.

- [ ] **Step 5: Validate and verify GREEN**

Run the required GodotIQ per-file checks, then rerun all three tests. Expected: all pass; V1 still displays `Goblin`; generated main, ally, and enemy habitats display their owning race; the top bar retains `Habitat: Unavailable` on failure.

- [ ] **Step 6: Commit race-name presentation**

```powershell
git add -- Scripts/WorldMap/world_habitat_rules.gd Tests/WorldMap/test_ac8_4_habitat_rules.gd Tests/WorldMap/test_world_runtime_model.gd Tests/UI/test_world_map_hud.gd
git commit -m "fix: show habitat race in world HUD"
```

## Task 4: Reconcile documentation and delete the obsolete local save

**Files:**

- Modify: `Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md`
- Modify: `Docs/superpowers/plans/2026-09-18-ac9-clans-and-habitats.md`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Modify: `Docs/Specs/AC9/Evidence/AC9.6/verification.md`

- [ ] **Step 1: Reconcile governing text**

Change every active AC9 world requirement from player-east/enemy-west to player-west/enemy-east. In the AC9.4/AC9.5 design, replace the exact coordinates with player `Vector2i(-8, 0)` and enemy `Vector2i(8, 0)`. Add a link to the approved correction design and state that the user authorized replacing the V2/V3 fixture contracts and deleting local saves.

In the MVP overview, World Map Traversal bullet, AC9.4 criterion, and walkthrough, state that the player begins west/left and the enemy begins east/right. Do not alter the V1 legacy contract.

- [ ] **Step 2: Resolve and delete only the production save artifacts**

Start Play mode and use game-context execution so `user://` resolves through Godot. Execute this bounded deletion logic:

```gdscript
func run():
    var relative_paths: Array[String] = [
        "user://active-world-run.json",
        "user://active-world-run.json.tmp",
        "user://active-world-run.json.bak",
    ]
    var root_path: String = ProjectSettings.globalize_path("user://").simplify_path()
    var removed: Array[String] = []
    for relative_path: String in relative_paths:
        var absolute_path: String = ProjectSettings.globalize_path(relative_path).simplify_path()
        if not absolute_path.begins_with(root_path + "/") and not absolute_path.begins_with(root_path + "\\"):
            return str({"ok": false, "error": "path_outside_user_data", "path": absolute_path})
        if FileAccess.file_exists(relative_path):
            var error: Error = DirAccess.remove_absolute(absolute_path)
            if error != OK:
                return str({"ok": false, "error": error_string(error), "path": absolute_path})
            removed.append(absolute_path)
    return str({
        "ok": true,
        "user_data_root": root_path,
        "removed": removed,
        "save_exists": FileAccess.file_exists("user://active-world-run.json"),
    })
```

Expected: `ok=true`, `save_exists=false`, and every removed path is inside the resolved `TwoDimensionExploration` user-data directory. This deletion is user-authorized and unrecoverable unless another backup exists; report the exact removed paths in the final handoff.

- [ ] **Step 3: Run the complete automated gate**

Require PASS sentinels for:

```powershell
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac9_habitats_and_towns.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v2.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v2_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_hex_world_generator_v3.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_plan_codec_v3.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v3_fixture_author.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac8_4_habitat_rules.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_ac8_4_town_ownership.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_world_runtime_model.gd
& $godotExe --headless --path . --script res://Tests/UI/test_world_map_hud.gd
& $godotExe --headless --path . --script res://Tests/Run/test_world_run_start_service.gd
& $godotExe --headless --path . --script res://Tests/Save/test_world_run_save_codec_v8.gd
& $godotExe --headless --path . --script res://Tests/WorldMap/test_generator_v1_fixture_integrity.gd
```

Expected: all thirteen tests pass, V1 fixture integrity remains unchanged, and V2/V3 hashes match their newly committed constants.

- [ ] **Step 4: Run project and Play-mode verification**

Run:

1. `validate(target="project", detail="brief")`; no new errors relative to the 51-issue baseline (`0` errors, `46` warnings, `5` info).
2. `check_errors(scope="project")`; zero parser/compile errors.
3. `signal_map(scope="all", find="orphans", detail="brief")`; zero orphan signals.
4. `verify_project_runs(scene="main", check_scope="project", stop_after=false)`; PASS.
5. In game context, generate a production V3 run with a no-op commit callback and assert version `3`, player `Vector2i(-8, 0)`, enemy `Vector2i(8, 0)`, nine roads, player habitat `display_name == "Goblin"`, and HUD label `Habitat: Goblin`.
6. Read the debug console; zero runtime or script errors.
7. Capture one screenshot at `scale=0.25`, `quality=0.3` showing the player marker on the left, enemy marker on the right, and `Habitat: Goblin` in the top bar.
8. Stop Play mode.

- [ ] **Step 5: Update verification evidence**

In `Docs/Specs/AC9/Evidence/AC9.6/verification.md`, record:

- correction design and implementation-plan links;
- implementation commit IDs;
- new V2/V3 fixture byte counts, line counts, and exact SHA-256 values;
- explicit confirmation that V1 stayed unchanged while V2/V3 were intentionally replaced;
- the exact production save artifacts removed;
- all focused test PASS sentinels;
- project validation, parser, signal, Play-mode, debug-console, and screenshot results;
- runtime proof of player-left/enemy-right and `Habitat: Goblin`.

- [ ] **Step 6: Commit documentation and evidence**

```powershell
git add -- Docs/superpowers/specs/2026-10-03-ac9-4-ac9-5-seeded-habitats-and-towns-design.md Docs/superpowers/plans/2026-09-18-ac9-clans-and-habitats.md Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC9/Evidence/AC9.6/verification.md
git commit -m "docs: reconcile corrected AC9 spawn orientation"
```

## Final completion gate

- [ ] `git diff main...HEAD --check` reports no whitespace errors.
- [ ] `git status --short` shows only the user's pre-existing `.github` changes.
- [ ] The latest V2 and V3 fixture authors, codec suites, generator suites, runtime model, HUD, start service, V8 save, and V1 fixture integrity tests all show fresh PASS sentinels.
- [ ] GodotIQ reports zero parser errors, no orphan signals, a passing main-scene launch, and a clean debug console.
- [ ] The production save and its `.tmp`/`.bak` siblings do not exist.
- [ ] A fresh V3 run proves player west/left, enemy east/right, nine internal roads, and `Habitat: Goblin`.
- [ ] Only relevant files are staged and committed; the user's `.github` changes remain untouched.
