# AC8.4 Shared Town Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking. Follow repository AGENTS.md: dedicated branch in the primary workspace, no worktrees, GodotIQ inspection and per-script validation.

**Goal:** Resolve every existing version-1 town to Goblin ownership through one shared rule, consistently before and after reload, without changing the map.

**Architecture:** A pure `TownOwnershipRules` module derives ownership from the immutable `WorldPlan`; `WorldRuntimeModel` exposes that result to future town consumers. Ownership is derived, not duplicated in run state or save data. Unsupported world versions fail closed until AC9 supplies its generated ownership model and versioned codec.

**Tech Stack:** Godot 4, typed GDScript, existing WorldPlan v1, run-save codecs v2–v5, headless SceneTree runners, GodotIQ.

**Status:** Ownership prerequisite implemented and verified in `09bca93` and `d40f492`; [evidence](../../Specs/AC8/Evidence/AC8.4/verification.md). Broad MVP AC8.4 remains pending filtered offers in AC8.5/AC8.6. The test below was corrected to compare canonical road order, because serialization sorts roads without changing topology.

## Scope and acceptance boundary

Sources: [AC8 parent plan](2026-09-18-ac8-town-recruitment-and-gold.md), [MVP criteria](../../Specs/GAME_DESIGN_SPEC_MVP.md), [AC9 plan](2026-09-18-ac9-clans-and-habitats.md).

The parent plan explicitly sequences ownership in AC8.4, purchasing in AC8.5, and roster-class filtering in AC8.6. The MVP AC8.4 sentence additionally requires filtered offers. This plan implements the ownership prerequisite; **do not mark the complete MVP AC8.4 checkbox passed until the AC8.5/AC8.6 integration verifies those offers**. Record ownership as verified separately. The parent plan's narrower ownership step can be checked with a link explaining that boundary.

AC9 requires remaining race/commander content before habitat implementation. Consequently this slice does not invent world v2, add habitat records, alter generation, or accept future saves. Explicit non-Goblin ownership and missing-owner rejection in an actual habitat-enabled world remain AC9 integration gates. This slice proves unknown versions never receive the Goblin fallback.

No purchase UI, class catalog, wallet mutation, town burning, alliance state, new autoload, or movement change belongs here. Ownership alone does not establish that recruitment is currently permitted: AC8.5 checks interaction availability; AC10 checks intact/allied status and boss collision precedence.

## Evidence from current code

- `Scripts/WorldMap/world_plan.gd` stores a version, seed, start/boss coordinates, cells, roads and forest clusters. Its getters return defensive collection copies.
- A town is a cell with integer `town_index >= 0`. Town encounters are `safe`; checking encounter type alone would incorrectly treat other safe cells as towns.
- `Scripts/WorldMap/world_plan_codec_v1.gd` validates the existing seven-town world and serializes canonical bytes. Keep those bytes and fixtures unchanged.
- `Scripts/WorldMap/world_runtime_model.gd` owns `_plan`, validates it in `configure`, shares it in `duplicate_model`, and restores mutable run state separately.
- `Scripts/Save/world_run_save_codec_v5.gd` delegates to the shared envelope and older decoders. Save version 5 still embeds generator/world version 1. Ownership must dispatch on `plan.get_version()`, never the outer save version.
- `Scripts/Save/world_run_save_envelope.gd` already rejects unsupported generator versions. No codec migration is needed for a derived v1 rule.

## Approach choice

Use a standalone pure resolver plus a runtime-model forwarding method. Putting the fallback in the controller would make later offer/purchase validation depend on UI coordination. Persisting a clan on every v1 town would require a needless schema migration and risk changing canonical map bytes. The pure resolver keeps one rule reusable by runtime and future transaction code.

New API: `TownOwnershipRules.resolve(plan: WorldPlan, coord: Vector2i) -> Dictionary`.

| Input | Result |
|---|---|
| Valid v1 town | `{ok: true, clan_id: &"goblin", error: &""}` |
| Null plan | Failure `invalid_plan`, empty clan |
| Any version other than 1 | Failure `unsupported_world_version`, empty clan |
| Off-map coordinate | Failure `invalid_coordinate`, empty clan |
| Non-dictionary cell, missing/non-integer town index, index below -1 | Failure `invalid_town_record`, empty clan |
| Integer town index -1 | Failure `not_a_town`, empty clan |

The resolver expects a plan validated by the existing load/configure boundary; it does not rerun whole-map spacing/road validation on each query. Defensive local checks make failure deterministic. The new canonical clan ID is `goblin`; it is independent of class IDs and display names. AC9 must preserve or explicitly migrate that identifier when introducing its clan catalog.

## File map

| Action | File | Responsibility |
|---|---|---|
| Create | `Scripts/WorldMap/town_ownership_rules.gd` | Pure v1 ownership rule and explicit failures |
| Modify | `Scripts/WorldMap/world_runtime_model.gd` | Expose `get_town_ownership(coord)` using the shared resolver |
| Create | `Tests/WorldMap/test_ac8_4_town_ownership.gd` | All towns/non-towns, unsupported versions, malformed local data, no mutation |
| Create | `Tests/WorldMap/test_ac8_4_town_ownership_reload.gd` | Runtime forwarding, model copy, v2–v5 save restoration, canonical topology preservation |
| Create | `Docs/Specs/AC8/Evidence/AC8.4/verification.md` and `.gdignore` | Actual command/results and scoped acceptance |
| Modify after verification | Parent AC8 plan and MVP verification mapping | Link ownership evidence and retain dependent acceptance gates |

Godot-generated `.gd.uid` files accompany new scripts. No production plan, codec, generator, scene or run-state file should need modification.

## Task 1: Establish the implementation baseline

- [x] Inspect `git status --short --branch`. Preserve the user's unrelated tracked and untracked work; the planning session already has unrelated modifications and untracked parent plans. Do not stage or overwrite them.
- [x] Before code work, fetch origin, update `main` with a fast-forward, then create `feat/ac8-4-town-ownership` in the primary workspace. Stash unrelated work if switching requires it and restore it without including it in feature commits. If main lacks AC8.3, resolve that prerequisite explicitly; do not silently start from an incompatible base.
- [x] Call GodotIQ `project_summary(detail="brief")`, then `file_context` for the two production paths and new test paths (a missing-file response is expected for new files). Inspect `dependency_graph`/`impact_check` for the runtime model before adding its public method. Run `validate(target="project", detail="brief")` and `check_errors(scope="project")`; record existing issues separately.
- [x] Run the existing plan-codec, generator-fixture-integrity, runtime-model and v5-codec runners from the final gate below. Record baseline output before modifying code.

## Task 2: Add the pure rule with a failing ownership runner

- [x] Create `Tests/WorldMap/test_ac8_4_town_ownership.gd` through GodotIQ. Use this complete runner:

```gdscript
extends SceneTree

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var path: String = "res://Scripts/WorldMap/town_ownership_rules.gd"
    if not ResourceLoader.exists(path):
        _expect(false, "ownership rules exist")
        quit(1)
        return
    var rules: Script = load(path)
    var codec: Script = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
        "res://Tests/Fixtures/WorldMap/GeneratorV1/town-road-01.world")
    var parsed: Dictionary = codec.parse(bytes)
    _expect(parsed.get("ok", false), "canonical fixture parses")
    if not parsed.get("ok", false):
        quit(1)
        return
    var plan: WorldPlan = parsed.plan
    var town_count: int = 0
    var first_town: Vector2i = Vector2i.ZERO
    var cells: Dictionary = plan.get_cells()
    for coord: Vector2i in cells:
        var result: Dictionary = rules.resolve(plan, coord)
        if cells[coord].town_index >= 0:
            town_count += 1
            first_town = coord
            _expect(result == {"ok": true, "clan_id": &"goblin", "error": &""},
                "every town resolves to Goblin")
        else:
            _expect(result == {"ok": false, "clan_id": &"", "error": &"not_a_town"},
                "non-town cannot acquire ownership")
    _expect(town_count == 7, "all seven v1 towns tested")
    _expect(rules.resolve(null, first_town).error == &"invalid_plan", "null rejects")
    _expect(rules.resolve(plan, Vector2i(999, 999)).error == &"invalid_coordinate", "off-map rejects")
    for version: int in [0, 2, 99]:
        var future: WorldPlan = _copy_plan(plan, version, cells)
        var rejected: Dictionary = rules.resolve(future, first_town)
        _expect(not rejected.ok and rejected.clan_id == &"" and
            rejected.error == &"unsupported_world_version", "no unknown-version fallback")
    for invalid: Variant in [null, true, 0.0, "0", -2]:
        var altered: Dictionary = cells.duplicate(true)
        altered[first_town].town_index = invalid
        _expect(rules.resolve(_copy_plan(plan, 1, altered), first_town).error ==
            &"invalid_town_record", "malformed index rejects")
    var missing: Dictionary = cells.duplicate(true)
    missing[first_town].erase("town_index")
    _expect(rules.resolve(_copy_plan(plan, 1, missing), first_town).error ==
        &"invalid_town_record", "missing index rejects")
    var malformed: Dictionary = cells.duplicate(true)
    malformed[first_town] = null
    _expect(rules.resolve(_copy_plan(plan, 1, malformed), first_town).error ==
        &"invalid_town_record", "malformed cell rejects")
    _expect(codec.serialize(plan) == bytes and plan.get_cells() == cells,
        "queries preserve canonical topology")
    if failures == 0:
        print("PASS test_ac8_4_town_ownership")
    quit(0 if failures == 0 else 1)

func _copy_plan(plan: WorldPlan, version: int, cells: Dictionary) -> WorldPlan:
    return load("res://Scripts/WorldMap/world_plan.gd").new(version,
        plan.get_seed_hex(), plan.get_start_coord(), plan.get_boss_coord(),
        cells, plan.get_roads(), plan.get_forest_clusters())

func _expect(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error(label)
```

- [x] Validate/check this test, then run it and require failure specifically at `ownership rules exist`.
- [x] Create `Scripts/WorldMap/town_ownership_rules.gd` with the following complete implementation:

```gdscript
class_name TownOwnershipRules
extends RefCounted

const PRE_HABITAT_WORLD_VERSION: int = 1
const GOBLIN_CLAN_ID: StringName = &"goblin"

static func resolve(plan: WorldPlan, coord: Vector2i) -> Dictionary:
    if not is_instance_valid(plan):
        return _failure(&"invalid_plan")
    if plan.get_version() != PRE_HABITAT_WORLD_VERSION:
        return _failure(&"unsupported_world_version")
    var cells: Dictionary = plan.get_cells()
    if not cells.has(coord):
        return _failure(&"invalid_coordinate")
    var cell: Variant = cells[coord]
    if not cell is Dictionary:
        return _failure(&"invalid_town_record")
    var index: Variant = cell.get("town_index")
    if not index is int:
        return _failure(&"invalid_town_record")
    if index < -1:
        return _failure(&"invalid_town_record")
    if index == -1:
        return _failure(&"not_a_town")
    return {"ok": true, "clan_id": GOBLIN_CLAN_ID, "error": &""}

static func _failure(error: StringName) -> Dictionary:
    return {"ok": false, "clan_id": &"", "error": error}
```

- [x] Run GodotIQ validate/check for the resolver, then rerun the focused test to PASS with exit 0 and no script errors. Commit only these scripts and their generated UIDs: `feat(ac8.4): add shared pre-habitat town ownership rule`.

## Task 3: Expose the rule and prove reload invariance

**Service API verification:** GodotIQ `script_ops(op="read")` confirms the declaration at `Scripts/Run/world_run_start_service.gd:21` is:

```gdscript
func start(
    seed_text: String,
    config: Dictionary = {},
    policy: String = RETURN_RESULT,
    commander_id: StringName = GoblinCommanderCatalog.BRAKKA_ID
) -> Dictionary:
```

`service.start(seed_text)` below supplies the required seed and uses the three defaults. A zero-argument `start()` call would omit the required seed. During plan review, GodotIQ `file_context(detail="brief")` reported `args: []` and an empty return type for this multiline declaration; that summary disagrees with the source returned by `script_ops`. Recheck the source declaration when rebasing rather than treating that summary as a zero-argument API.

- [x] Create `Tests/WorldMap/test_ac8_4_town_ownership_reload.gd` with this complete runner. It exercises every town on three generated maps and every supported run-save envelope version without modifying codec contracts.

```gdscript
extends SceneTree

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var model_script: Script = load("res://Scripts/WorldMap/world_runtime_model.gd")
    var probe: RefCounted = model_script.new()
    if not probe.has_method("get_town_ownership"):
        _expect(false, "runtime ownership API exists")
        quit(1)
        return
    _expect(probe.get_town_ownership(Vector2i.ZERO).error == &"invalid_plan",
        "unconfigured runtime rejects")
    var plan_codec: Script = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
    var current_codec: Script = load("res://Scripts/Save/world_run_save_codec_v5.gd")
    for seed_text: String in ["golden-alpha", "ac8-town-beta", "ac8-town-gamma"]:
        var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(
            func(_plan: RefCounted) -> void: pass)
        var session: Dictionary = service.start(seed_text)
        _expect(session.get("ok", false), "new run starts")
        if not session.get("ok", false):
            continue
        var plan: WorldPlan = session.plan
        var before: PackedByteArray = plan_codec.serialize(plan)
        var canonical_plan: WorldPlan = plan_codec.parse(before).plan
        var original_state: Dictionary = session.run_state.to_dictionary()
        var model: RefCounted = model_script.new()
        _expect(model.configure(plan), "runtime configures")
        _expect(model.restore_run_state(session.run_state), "runtime restores")
        var expected: Dictionary = _owners(model, plan)
        _expect(expected.size() == 7, "seven generated towns")
        _expect(_owners(model.duplicate_model(), plan) == expected, "candidate copy agrees")
        for version: int in [2, 3, 4, 5]:
            var writer: Script = load("res://Scripts/Save/world_run_save_codec_v%d.gd" % version)
            var saved: PackedByteArray = writer.encode(plan, seed_text, session.run_state)
            _expect(not saved.is_empty(), "save encodes")
            var decoded: Dictionary = current_codec.decode_any(saved)
            _expect(decoded.get("ok", false), "save decodes")
            if not decoded.get("ok", false):
                continue
            var restored_plan: WorldPlan = decoded.value.plan
            var restored: RefCounted = model_script.new()
            _expect(restored.configure(restored_plan), "restored runtime configures")
            _expect(restored.restore_run_state(decoded.value.run_state), "restored state valid")
            var restored_state: Dictionary = decoded.value.run_state.to_dictionary()
            _expect(_owners(restored, restored_plan) == expected, "all owners survive reload")
            _expect(plan_codec.serialize(restored_plan) == before, "canonical bytes unchanged")
            _expect(decoded.value.run_state.to_dictionary() == restored_state,
                "ownership queries do not mutate restored state")
            _expect(plan.get_cells() == restored_plan.get_cells() and
                canonical_plan.get_roads() == restored_plan.get_roads() and
                plan.get_start_coord() == restored_plan.get_start_coord() and
                plan.get_boss_coord() == restored_plan.get_boss_coord(),
                "towns roads and spawns preserved")
        _expect(session.run_state.to_dictionary() == original_state, "live state unchanged")
        _expect(plan_codec.serialize(plan) == before, "live map unchanged")
    if failures == 0:
        print("PASS test_ac8_4_town_ownership_reload")
    quit(0 if failures == 0 else 1)

func _owners(model: RefCounted, plan: WorldPlan) -> Dictionary:
    var result: Dictionary = {}
    var cells: Dictionary = plan.get_cells()
    for coord: Vector2i in cells:
        if cells[coord].town_index >= 0:
            var owner: Dictionary = model.get_town_ownership(coord)
            _expect(owner.ok and owner.clan_id == &"goblin", "runtime resolves Goblin")
            result[coord] = owner
        else:
            _expect(not model.get_town_ownership(coord).ok, "runtime rejects non-town")
    return result

func _expect(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error(label)
```

- [x] Validate/check the new test and run it; require failure at `runtime ownership API exists` before implementing the forwarding method.
- [x] After fresh `file_context` and impact inspection, add this field and method to `Scripts/WorldMap/world_runtime_model.gd`, alongside its existing script references and query methods:

```gdscript
var _town_ownership_rules: GDScript = load("res://Scripts/WorldMap/town_ownership_rules.gd")

func get_town_ownership(coord: Vector2i) -> Dictionary:
    return _town_ownership_rules.resolve(_plan, coord)
```

The script reference initializes on each model instance; `duplicate_model` needs no new state copying. Do not infer owner from the dynamic encounter type, which may be overridden by a moving boss. AC8.5 must call this API or the same pure resolver for both browsing and transaction validation.

- [x] Validate/check the model immediately. Run both focused runners and the existing runtime-model/save-codec tests. Commit this verified slice: `feat(ac8.4): expose town ownership across runtime reloads`.

## Task 4: Verification, evidence and handoff

- [x] Run each required script separately with a 120-second process timeout. Command template from repository root:

```powershell
& 'D:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 1800 --script res://Tests/WorldMap/test_ac8_4_town_ownership.gd
```

Use Python `subprocess.run(..., capture_output=True, text=True, timeout=120)` for reliable Windows GUI-executable capture, as in AC8.3 evidence. A pass requires exit 0, the runner's explicit PASS output, and no script/runtime errors; timeout or forced quit without PASS fails.

Required paths (substitute each into the template):

```text
Tests/WorldMap/test_ac8_4_town_ownership.gd
Tests/WorldMap/test_ac8_4_town_ownership_reload.gd
Tests/WorldMap/test_world_plan_codec_v1.gd
Tests/WorldMap/test_hex_world_generator_v1.gd
Tests/WorldMap/test_generator_v1_fixture_integrity.gd
Tests/WorldMap/test_world_runtime_model.gd
Tests/WorldMap/test_world_runtime_scene.gd
Tests/Save/test_world_save_codec_v1.gd
Tests/Save/test_world_run_save_codec_v2.gd
Tests/Save/test_world_run_save_codec_v3.gd
Tests/Save/test_world_run_save_codec_v4.gd
Tests/Save/test_world_run_save_codec_v5.gd
Tests/Run/test_world_run_start_service.gd
Tests/Run/test_world_single_slot_repository.gd
Tests/Run/test_world_production_launcher.gd
Tests/WorldMap/test_ac8_3_reward_presentation.gd
```

- [x] Run final project validation/error checks and scoped orphan-signal inspection. No signal changes are expected; record existing findings separately from regressions.
- [x] Use GodotIQ play → verify_project_runs → debug console → state inspection in a disposable production run. Record seed, world version, town count, player/boss coordinates and move count; confirm ordinary movement still works. Restart/Continue and inspect the restored state. Use a disposable save or preserve the user's existing slot before this check. Automated runners above prove every restored town's owner and exact topology. No visual changes are planned, so screenshots/tours are unnecessary.
- [x] Create `Docs/Specs/AC8/Evidence/AC8.4/.gdignore` and `verification.md` with tested commit, exact commands, results, runtime observations, seven-town checks for each seed, and unchanged canonical-byte evidence. State that filtered offers and actual habitat-enabled ownership remain unverified dependencies.
- [x] Update the parent plan's ownership step only after its gate passes. Link the focused plan/evidence from the MVP verification row while leaving the broad AC8.4 criterion unchecked until filtered offers pass in AC8.5/AC8.6. Leave AC8.5–AC8.8 unchecked.
- [x] Inspect the final diff and stage only relevant scripts, UIDs and evidence/documentation hunks. Commit the evidence; push only if the user requests remote handoff.

## Future integration contract

AC8.5/AC8.6 consume `clan_id` from this shared rule and enforce roster-class filtering, including passed-out members. They must never hardcode Goblin ownership independently. No offers are persisted.

AC9 extends the resolver with an explicitly supported habitat world version after its content prerequisite and ownership schema are ready. Its branch must resolve town → generated habitat → canonical clan; absent/invalid ownership fails. It must test at least one non-Goblin town, missing ownership, old-v1 compatibility and save/reload. Never use `version >= 2` or a missing-field fallback to accept arbitrary future worlds. Outer run-save version and world-generation version remain independent.

## Plan review

Coverage: every existing town, non-town rejection, null/off-map/malformed input, unknown-version rejection, candidate copies, current/legacy reload, unchanged map bytes/roads/spawns, and no run-state mutation have concrete tests above. No ownership state or schema migration is introduced. Filtered offers and habitat-enabled behavior are explicitly tracked integration dependencies, not claimed as completed by this slice.
