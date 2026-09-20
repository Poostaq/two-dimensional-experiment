class_name AC84HabitatRulesTests
extends SceneTree

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var path: String = "res://Scripts/WorldMap/world_habitat_rules.gd"
    if not ResourceLoader.exists(path):
        _expect(false, "shared habitat rules exist")
        quit(1)
        return
    var rules: Script = load(path)
    var town_rules: Script = load("res://Scripts/WorldMap/town_ownership_rules.gd")
    var codec: Script = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
    var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
        "res://Tests/Fixtures/WorldMap/GeneratorV1/town-road-01.world")
    var parsed: Dictionary = codec.parse(bytes)
    _expect(parsed.get("ok", false), "canonical fixture parses")
    if not parsed.get("ok", false):
        quit(1)
        return
    var plan: WorldPlan = parsed.plan
    var cells: Dictionary = plan.get_cells()
    var model: RefCounted = load("res://Scripts/WorldMap/world_runtime_model.gd").new()
    _expect(model.has_method("get_habitat"), "runtime exposes habitat query")
    _expect(model.configure(plan), "runtime accepts canonical plan")
    var towns: int = 0
    var ordinary: int = 0
    for coord: Vector2i in cells:
        var result: Dictionary = rules.resolve(plan, coord)
        _expect(result == _success(), "every on-map v1 cell has legacy Goblin habitat")
        if model.has_method("get_habitat"):
            _expect(model.call("get_habitat", coord) == result, "runtime delegates habitat query")
        var town: Dictionary = town_rules.resolve(plan, coord)
        if cells[coord].town_index >= 0:
            towns += 1
            _expect(town == {"ok": true, "clan_id": result.clan_id, "error": &""},
                "town API keeps exact three-key success contract")
        else:
            ordinary += 1
            _expect(town == {"ok": false, "clan_id": &"", "error": &"not_a_town"},
                "ordinary habitat does not grant town ownership")
    _expect(towns == 7 and ordinary > 0, "covers all towns and non-town cells")
    var start: Vector2i = plan.get_start_coord()
    _expect(rules.resolve(null, start) == _failure(&"invalid_plan"), "null plan fails explicitly")
    _expect(rules.resolve(plan, Vector2i(999, 999)) == _failure(&"invalid_coordinate"),
        "off-map fails explicitly")
    for version: int in [0, 2, 99]:
        var unknown: WorldPlan = _copy_plan(plan, version, cells)
        _expect(rules.resolve(unknown, start) == _failure(&"unsupported_world_version"),
            "unknown versions never inherit legacy rule")
        _expect(town_rules.resolve(unknown, start) ==
            {"ok": false, "clan_id": &"", "error": &"unsupported_world_version"},
            "town keeps version error precedence")
    for invalid: Variant in [null, true, 0, "cell", []]:
        var altered: Dictionary = cells.duplicate(true)
        altered[start] = invalid
        var malformed: WorldPlan = _copy_plan(plan, 1, altered)
        _expect(rules.resolve(malformed, start) == _failure(&"invalid_cell_record"),
            "non-dictionary cell fails explicitly")
        _expect(town_rules.resolve(malformed, start) ==
            {"ok": false, "clan_id": &"", "error": &"invalid_town_record"},
            "town preserves malformed-record error")
    var empty_cell: Dictionary = cells.duplicate(true)
    empty_cell[start] = {}
    _expect(rules.resolve(_copy_plan(plan, 1, empty_cell), start) == _success(),
        "habitat does not depend on town metadata")
    if model.has_method("get_habitat"):
        var unconfigured: RefCounted = load("res://Scripts/WorldMap/world_runtime_model.gd").new()
        _expect(unconfigured.call("get_habitat", start) == _failure(&"invalid_plan"),
            "unconfigured runtime rejects habitat query")
        _expect(model.call("get_habitat", Vector2i(999, 999)) == _failure(&"invalid_coordinate"),
            "runtime propagates off-map failure")
        var duplicate: RefCounted = model.duplicate_model()
        _expect(duplicate.call("get_habitat", start) == _success(), "duplicate retains habitat")
        var mutable_result: Dictionary = model.call("get_habitat", start)
        mutable_result.clan_id = &"changed"
        _expect(model.call("get_habitat", start) == _success(), "query results are independent")
    _expect(codec.serialize(plan) == bytes and plan.get_cells() == cells,
        "queries preserve canonical bytes and topology")
    if failures == 0:
        print("PASS test_ac8_4_habitat_rules cells=%d towns=%d" % [cells.size(), towns])
    quit(0 if failures == 0 else 1)

func _success() -> Dictionary:
    return {"ok": true, "clan_id": &"goblin", "display_name": "Goblin",
        "source": "Legacy world v1 rule", "habitat_id": &"", "error": &""}

func _failure(error: StringName) -> Dictionary:
    return {"ok": false, "clan_id": &"", "display_name": "",
        "source": "", "habitat_id": &"", "error": error}

func _copy_plan(plan: WorldPlan, version: int, cells: Dictionary) -> WorldPlan:
    return load("res://Scripts/WorldMap/world_plan.gd").new(version,
        plan.get_seed_hex(), plan.get_start_coord(), plan.get_boss_coord(),
        cells, plan.get_roads(), plan.get_forest_clusters())

func _expect(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error(label)
