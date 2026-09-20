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
