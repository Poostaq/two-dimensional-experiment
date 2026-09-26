extends SceneTree

const SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"

var _failures: int = 0
var _commit_count: int = 0
var _committed_plan: RefCounted


class GeneratorSpy:
    extends RefCounted

    var call_count: int = 0


    func generate(_seed_text: String, _config: Dictionary) -> Dictionary:
        call_count += 1
        return {}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var service_script: GDScript = load(SERVICE_PATH)
    if service_script == null:
        _fail("WorldRunStartService script is missing")
        _finish()
        return
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"))
    var catalog_script := load("res://Scripts/Run/run_character_catalog.gd") as Script
    _assert_true(catalog_script.has_method("get_player_commander_ids"), "catalog exposes player commander registry")
    _assert_true(catalog_script.has_method("get_commander_presentation"), "catalog exposes commander presentation")
    var expected_player_commanders: Array[StringName] = [
        &"brakka_rustbanner", &"goruk_ironline", &"veyra_moontrace",
        &"sszek_still_mire", &"kyris_windscar",
    ]
    _assert_equal(catalog_script.get_player_commander_ids(), expected_player_commanders, "exact player commander roster")
    for commander_id: StringName in expected_player_commanders:
        var presentation: Dictionary = catalog_script.get_commander_presentation(commander_id)
        _assert_equal(presentation.get("commander_id", &""), commander_id, "presentation identity")
        _assert_equal(presentation.get("skills", []).size(), 4, "presentation has four skills")

    var expected_starter_formations: Dictionary[StringName, Array] = {
        &"brakka_rustbanner": [&"wirefang_skirmisher", &"brakka_rustbanner", &"snarewright"],
        &"goruk_ironline": [&"orc_bonebreaker_reaver", &"goruk_ironline", &"orc_bloodbanner_captain"],
        &"veyra_moontrace": [&"werewolf_pack_howler", &"veyra_moontrace", &"werewolf_bloodtrail_stalker"],
        &"sszek_still_mire": [&"lizardman_scale_sentinel", &"sszek_still_mire", &"lizardman_mire_spitter"],
        &"kyris_windscar": [&"harpy_storm_siren", &"kyris_windscar", &"harpy_gale_scout"],
    }
    var race_service: RefCounted = service_script.new(func(_plan: RefCounted) -> void: pass)
    for commander_id: StringName in expected_player_commanders:
        var race_id: StringName = catalog_script.get_commander_faction_id(commander_id)
        var race_start: Dictionary = race_service.call(
            "start",
            "race-starters-" + String(commander_id),
            {},
            "RETURN_RESULT",
            commander_id,
            race_id
        )
        _assert_true(race_start.get("ok", false), "%s race-specific start succeeds" % commander_id)
        if not race_start.get("ok", false):
            continue
        var actual_formation: Array[StringName] = race_start["run_state"].formation
        var expected_formation: Array = expected_starter_formations[commander_id]
        for slot_index: int in expected_formation.size():
            var identity: StringName = expected_formation[slot_index]
            _assert_equal(
                actual_formation[slot_index],
                identity,
                "%s starter slot %d uses the fixed race member" % [commander_id, slot_index]
            )
            var member: RunCharacter = catalog_script.create_by_class_id(identity)
            _assert_true(is_instance_valid(member), "%s starter constructs" % identity)
            if is_instance_valid(member):
                _assert_equal(member.race_id, race_id, "%s starter matches captain race" % identity)

    var success: Dictionary = service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"brakka_rustbanner"
    )
    _assert_true(success.get("ok", false), "successful run start")
    _assert_equal(_commit_count, 1, "success commits once")
    _assert_true(_committed_plan != null, "complete plan committed")
    if _committed_plan != null:
        _assert_equal(_committed_plan.get_cells().size(), 217, "committed cell count")
    if success.get("ok", false):
        _assert_equal(success["run_state"].get("gold"), 100, "new run wallet initialized")
        _assert_true(success["run_state"].has_character_hp_snapshot(), "fresh run persists explicit health")
        _assert_equal(success["run_state"].get_character_hp_snapshot().size(), 3, "fresh health includes three starters")
        var formation: Array[StringName] = success["run_state"].formation
        _assert_equal(formation[0], &"wirefang_skirmisher", "Goblin left starter is fixed")
        _assert_equal(formation[1], &"brakka_rustbanner", "Brakka occupies middle frontline")
        _assert_equal(formation[2], &"snarewright", "Goblin right starter is fixed")

    var generator_spy := GeneratorSpy.new()
    var rejecting_service: RefCounted = service_script.new(
        Callable(self, "_commit_plan"),
        generator_spy
    )
    var commits_before: int = _commit_count
    var invalid: Dictionary = rejecting_service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"unknown"
    )
    _assert_true(not invalid.get("ok", true), "unknown commander rejected")
    _assert_equal(generator_spy.call_count, 0, "invalid commander does not generate")
    _assert_equal(_commit_count, commits_before, "invalid commander does not commit")
    _assert_equal(invalid["error"].feature_namespace, "run-start", "invalid commander namespace")
    _assert_equal(
        invalid["error"].failed_constraint,
        "invalid_commander_id=unknown",
        "invalid commander constraint"
    )
    var invalid_pair: Dictionary = rejecting_service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"goruk_ironline",
        &"lizardman"
    )
    _assert_true(not invalid_pair.get("ok", true), "mismatched commander faction rejected")
    _assert_equal(generator_spy.call_count, 0, "mismatched faction does not generate")
    _assert_equal(
        invalid_pair["error"].failed_constraint,
        "invalid_commander_faction=goruk_ironline:lizardman",
        "mismatched faction constraint"
    )
    var orc_commander_service: RefCounted = service_script.new(func(_plan: RefCounted) -> void: pass)
    var orc_start: Dictionary = orc_commander_service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"goruk_ironline",
        &"orc"
    )
    _assert_true(orc_start.get("ok", false), "matching monster commander starts")
    if orc_start.get("ok", false):
        _assert_equal(orc_start["run_state"].formation[1], &"goruk_ironline", "selected commander occupies middle frontline")

    var before := {
        "save_bytes": PackedByteArray([1, 2, 3]),
        "history": 4,
        "roster": 5,
        "rewards": 6,
        "encounter": 7,
        "battle": 8,
        "published_cells": 217,
    }
    var snapshot: Dictionary = before.duplicate(true)
    var impossible := {
        "radius": 2,
        "town_count": 7,
        "town_min_distance": 4,
        "start": Vector2i(-2, 0),
        "boss": Vector2i(2, 0),
    }
    var failed: Dictionary = service.start("impossible", impossible, "RETURN_RESULT")
    _assert_true(not failed.get("ok", true), "failed run start")
    _assert_equal(failed["error"].code, "WORLD_CONSTRAINT_UNSATISFIABLE", "typed generation failure")
    _assert_equal(_commit_count, 1, "failure does not commit")
    _assert_equal(before, snapshot, "external state unchanged")

    var wrong_policy: Dictionary = service.start("golden-alpha", {}, "EXIT_PROCESS")
    _assert_true(not wrong_policy.get("ok", true), "service rejects process policy")
    _assert_equal(wrong_policy["error"].code, "WORLD_GENERATION_INTERNAL_ERROR", "policy failure code")
    _assert_equal(_commit_count, 1, "wrong policy does not commit")
    _finish()


func _commit_plan(plan: RefCounted) -> void:
    _commit_count += 1
    _committed_plan = plan


func _assert_true(value: bool, label: String) -> void:
    if not value:
        _fail(label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_start_service")
    quit(1 if _failures > 0 else 0)
