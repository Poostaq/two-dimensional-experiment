extends SceneTree

const SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"
const GENERATOR_V2_PATH := "res://Scripts/WorldMap/hex_world_generator_v2.gd"
const GENERATOR_V3_PATH := "res://Scripts/WorldMap/hex_world_generator_v3.gd"

var _failures: int = 0
var _commit_count: int = 0
var _committed_plan: RefCounted


class GeneratorSpy:
    extends RefCounted

    var call_count: int = 0
    var captured_seed: String = ""
    var captured_config: Dictionary = {}
    var delegate: RefCounted
    var forced_result: Dictionary = {}


    func _init(candidate_delegate: RefCounted = null) -> void:
        delegate = candidate_delegate


    func generate(seed_text: String, config: Dictionary) -> Dictionary:
        call_count += 1
        captured_seed = seed_text
        captured_config = config.duplicate(true)
        if not forced_result.is_empty():
            return forced_result
        if is_instance_valid(delegate):
            return delegate.generate(seed_text, config)
        return {}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var service_script: GDScript = load(SERVICE_PATH)
    if service_script == null:
        _fail("WorldRunStartService script is missing")
        _finish()
        return
    _test_default_v3_success(service_script)
    _test_explicit_v2_generator_compatibility(service_script)
    _test_race_starters(service_script)
    _test_reserved_config_injection(service_script)
    _test_pre_generation_validation(service_script)
    _test_generation_failure_is_atomic(service_script)
    _test_fixed_config_failure_is_atomic(service_script)
    _finish()


func _test_default_v3_success(service_script: GDScript) -> void:
    _reset_commits()
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"))
    var success: Dictionary = service.call(
        "start",
        "golden-alpha",
        {},
        "RETURN_RESULT",
        &"brakka_rustbanner"
    )
    _assert_true(success.get("ok", false), "default successful run start")
    _assert_equal(_commit_count, 1, "default success commits once")
    _assert_true(_committed_plan != null, "complete plan committed")
    if not success.get("ok", false):
        return
    var plan: RefCounted = success["plan"]
    _assert_equal(plan.get_version(), 3, "default generator produces V3")
    _assert_equal(plan.get_start_coord(), Vector2i(-8, 0), "player starts at west extreme")
    _assert_equal(plan.get_boss_coord(), Vector2i(8, 0), "boss starts at east extreme")
    _assert_equal(plan.get_habitats().size(), 4, "V3 plan has four habitats")
    _assert_equal(plan.get_towns().size(), 9, "V3 plan has nine towns")
    _assert_equal(plan.get_roads().size(), 9, "V3 plan has nine internal roads")
    _assert_equal(success["run_state"].player_coord, plan.get_start_coord(), "state starts west")
    _assert_equal(success["run_state"].boss_coord, plan.get_boss_coord(), "state boss is east")
    _assert_true(success.has("coalition"), "new run returns allied coalition")
    _assert_true(success.has("enemy_boss_selection"), "new run returns enemy boss selection")
    _assert_equal(success["run_state"].get("gold"), 100, "new run wallet initialized")
    _assert_true(
        success["run_state"].has_character_hp_snapshot(),
        "fresh run persists explicit health"
    )
    _assert_equal(
        success["run_state"].get_character_hp_snapshot().size(),
        3,
        "fresh health includes three starters"
    )
    var formation: Array[StringName] = success["run_state"].formation
    _assert_equal(formation[0], &"wirefang_skirmisher", "Goblin left starter is fixed")
    _assert_equal(formation[1], &"brakka_rustbanner", "Brakka occupies middle frontline")
    _assert_equal(formation[2], &"snarewright", "Goblin right starter is fixed")


func _test_explicit_v2_generator_compatibility(service_script: GDScript) -> void:
    _reset_commits()
    var generator_v2: RefCounted = load(GENERATOR_V2_PATH).new()
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"), generator_v2)
    var started: Dictionary = service.start("explicit-v2-compatibility")
    _assert_true(started.get("ok", false), "explicit V2 generator remains supported")
    _assert_equal(_commit_count, 1, "explicit V2 start commits once")
    if not started.get("ok", false):
        return
    var plan: RefCounted = started["plan"]
    _assert_equal(plan.get_version(), 2, "explicit generator preserves V2 plan")
    _assert_equal(plan.get_roads(), [], "explicit V2 plan keeps roads empty")


func _test_race_starters(service_script: GDScript) -> void:
    var catalog_script := load("res://Scripts/Run/run_character_catalog.gd") as Script
    var expected_starter_formations: Dictionary[StringName, Array] = {
        &"brakka_rustbanner": [&"wirefang_skirmisher", &"brakka_rustbanner", &"snarewright"],
        &"goruk_ironline": [&"orc_bonebreaker_reaver", &"goruk_ironline", &"orc_bloodbanner_captain"],
        &"veyra_moontrace": [&"werewolf_pack_howler", &"veyra_moontrace", &"werewolf_bloodtrail_stalker"],
        &"sszek_still_mire": [&"lizardman_scale_sentinel", &"sszek_still_mire", &"lizardman_mire_spitter"],
        &"kyris_windscar": [&"harpy_storm_siren", &"kyris_windscar", &"harpy_gale_scout"],
    }
    for commander_id: StringName in expected_starter_formations:
        var race_id: StringName = catalog_script.get_commander_faction_id(commander_id)
        var service: RefCounted = service_script.new(func(_plan: RefCounted) -> void: pass)
        var started: Dictionary = service.call(
            "start",
            "race-starters-" + String(commander_id),
            {},
            "RETURN_RESULT",
            commander_id,
            race_id
        )
        _assert_true(started.get("ok", false), "%s race-specific start succeeds" % commander_id)
        if not started.get("ok", false):
            continue
        var actual: Array[StringName] = started["run_state"].formation
        var expected: Array = expected_starter_formations[commander_id]
        for index: int in expected.size():
            _assert_equal(actual[index], expected[index], "%s starter slot %d" % [commander_id, index])
            var member: RunCharacter = catalog_script.create_by_class_id(expected[index])
            _assert_true(is_instance_valid(member), "%s starter constructs" % expected[index])
            if is_instance_valid(member):
                _assert_equal(member.race_id, race_id, "%s starter matches race" % expected[index])


func _test_reserved_config_injection(service_script: GDScript) -> void:
    _reset_commits()
    var seed_text := "reserved-config"
    var selection: RunClanSelection = _selection(seed_text)
    var coalition: RunClanCoalition = _coalition()
    var enemy_selection: RefCounted = _enemy_selection(seed_text)
    var generator_spy := GeneratorSpy.new(load(GENERATOR_V3_PATH).new())
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"), generator_spy)
    var caller_config := {
        "main_clan_id": &"forged_main",
        "allied_clan_ids": [&"forged_ally_0", &"forged_ally_1"],
        "enemy_clan_id": &"forged_enemy",
        "nested": {"kept": ["caller"]},
    }
    var original: Dictionary = caller_config.duplicate(true)
    var started: Dictionary = service.call(
        "start",
        seed_text,
        caller_config,
        "RETURN_RESULT",
        &"brakka_rustbanner",
        &"goblin",
        selection,
        coalition,
        enemy_selection
    )
    _assert_true(started.get("ok", false), "validated injected identities generate")
    _assert_equal(generator_spy.call_count, 1, "generator invoked exactly once")
    _assert_equal(generator_spy.captured_seed, seed_text, "generator receives resolved seed")
    _assert_equal(
        generator_spy.captured_config.get("main_clan_id"),
        selection.main_clan_id,
        "validated main clan overwrites caller value"
    )
    _assert_equal(
        generator_spy.captured_config.get("allied_clan_ids"),
        coalition.allied_clan_ids,
        "validated ordered allies overwrite caller value"
    )
    _assert_equal(
        generator_spy.captured_config.get("enemy_clan_id"),
        enemy_selection.enemy_clan_id,
        "validated enemy clan overwrites caller value"
    )
    generator_spy.captured_config["nested"]["kept"].append("spy")
    _assert_equal(caller_config, original, "caller config remains deeply unchanged")
    _assert_equal(_commit_count, 1, "identity-injected success commits once")


func _test_pre_generation_validation(service_script: GDScript) -> void:
    _reset_commits()
    var spy := GeneratorSpy.new(load(GENERATOR_V3_PATH).new())
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"), spy)
    var cases: Array[Dictionary] = []

    cases.append({
        "label": "unknown commander",
        "args": ["validation", {}, "RETURN_RESULT", &"unknown"],
    })
    cases.append({
        "label": "unsupported policy",
        "args": ["validation", {}, "EXIT_PROCESS", &"brakka_rustbanner"],
    })

    var invalid_selection := RunClanSelection.new()
    invalid_selection.main_clan_id = &"orc"
    invalid_selection.commander_id = &"brakka_rustbanner"
    invalid_selection.seed_text = "validation"
    cases.append({
        "label": "invalid main selection",
        "args": [
            "validation", {}, "RETURN_RESULT", &"brakka_rustbanner", &"goblin",
            invalid_selection,
        ],
    })

    var invalid_coalition := RunClanCoalition.new()
    invalid_coalition.main_clan_id = &"goblin"
    invalid_coalition.allied_clan_ids = [&"werewolf", &"orc"]
    cases.append({
        "label": "invalid ordered coalition",
        "args": [
            "validation", {}, "RETURN_RESULT", &"brakka_rustbanner", &"goblin",
            _selection("validation"), invalid_coalition,
        ],
    })

    var invalid_enemy := RunEnemyBossSelection.new()
    invalid_enemy.resolved_seed = "other-seed"
    invalid_enemy.enemy_clan_id = &"human"
    invalid_enemy.boss_party_id = &"human_fortified_line_v1"
    cases.append({
        "label": "invalid enemy selection",
        "args": [
            "validation", {}, "RETURN_RESULT", &"brakka_rustbanner", &"goblin",
            _selection("validation"), _coalition(), invalid_enemy,
        ],
    })

    for case: Dictionary in cases:
        var before_calls: int = spy.call_count
        var before_commits: int = _commit_count
        var result: Dictionary = service.callv("start", case["args"])
        _assert_true(not result.get("ok", true), "%s rejected" % case["label"])
        _assert_equal(spy.call_count, before_calls, "%s does not generate" % case["label"])
        _assert_equal(_commit_count, before_commits, "%s does not commit" % case["label"])
        _assert_true(result.get("error") != null, "%s returns typed error" % case["label"])
        if result.get("error") != null:
            _assert_equal(
                result["error"].generator_version,
                3,
                "%s reports V3 generator version" % case["label"]
            )


func _test_generation_failure_is_atomic(service_script: GDScript) -> void:
    _reset_commits()
    var spy := GeneratorSpy.new()
    var error_script: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
    spy.forced_result = {
        "ok": false,
        "plan": null,
        "error": error_script.new(
            error_script.WORLD_CONSTRAINT_UNSATISFIABLE,
            "00",
            3,
            "test",
            "forced"
        ),
    }
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"), spy)
    var result: Dictionary = service.start("generator-failure")
    _assert_true(not result.get("ok", true), "generator failure returned")
    _assert_equal(spy.call_count, 1, "failing generator called once")
    _assert_equal(_commit_count, 0, "generator failure does not commit")
    _assert_equal(result.get("plan"), null, "generator failure returns no plan")
    _assert_equal(result.get("run_state"), null, "generator failure returns no run state")
    _assert_equal(
        result["error"].code,
        "WORLD_CONSTRAINT_UNSATISFIABLE",
        "generator failure preserves typed error"
    )


func _test_fixed_config_failure_is_atomic(service_script: GDScript) -> void:
    _reset_commits()
    var service: RefCounted = service_script.new(Callable(self, "_commit_plan"))
    var result: Dictionary = service.start(
        "noncanonical-run-start",
        {"radius": 9, "forest_count": 0}
    )
    _assert_true(not result.get("ok", true), "noncanonical V3 config is rejected")
    _assert_equal(result.get("plan"), null, "noncanonical V3 config publishes no plan")
    _assert_equal(result.get("run_state"), null, "noncanonical V3 config builds no run state")
    _assert_equal(_commit_count, 0, "noncanonical V3 config does not commit")
    _assert_true(result.get("error") != null, "noncanonical V3 config returns typed error")
    if result.get("error") != null:
        _assert_equal(result["error"].generator_version, 3, "config failure reports V3")
        _assert_equal(result["error"].feature_namespace, "habitat", "config failure namespace")
        _assert_equal(result["error"].failed_constraint, "fixed_radius=8", "config failure constraint")


func _selection(seed_text: String) -> RunClanSelection:
    var result: Dictionary = RunClanSelection.create(
        &"goblin",
        &"brakka_rustbanner",
        seed_text
    )
    return result.get("value") as RunClanSelection


func _coalition() -> RunClanCoalition:
    var result: Dictionary = RunClanCoalition.create(
        &"goblin",
        [&"orc", &"werewolf"]
    )
    return result.get("value") as RunClanCoalition


func _enemy_selection(seed_text: String) -> RefCounted:
    var result: Dictionary = RunEnemyBossSelection.create(
        seed_text,
        &"human",
        &"human_fortified_line_v1"
    )
    return result.get("value") as RefCounted


func _reset_commits() -> void:
    _commit_count = 0
    _committed_plan = null


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
