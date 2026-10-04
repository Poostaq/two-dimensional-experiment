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
    for version: int in [0, 4, 99]:
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
    _test_v2_ownership(rules)
    if failures == 0:
        print("PASS test_ac8_4_town_ownership")
    quit(0 if failures == 0 else 1)

func _test_v2_ownership(rules: Script) -> void:
    var generated: Dictionary = load("res://Scripts/WorldMap/hex_world_generator_v2.gd").new().generate(
        "ac8-4-v2-towns",
        {
            "main_clan_id": &"goblin",
            "allied_clan_ids": [&"orc", &"werewolf"],
            "enemy_clan_id": &"human",
        }
    )
    _expect(generated.get("ok", false), "v2 plan generates")
    if not generated.get("ok", false):
        return
    var plan: WorldPlan = generated.plan
    var cells: Dictionary = plan.get_cells()
    var habitats: Array = plan.get_habitats()
    var towns: Array = plan.get_towns()
    var habitat_by_id: Dictionary = {}
    for habitat_value: Variant in habitats:
        var habitat: Dictionary = habitat_value
        habitat_by_id[String(habitat.habitat_id)] = habitat
    _expect(towns.size() == 9, "v2 exposes nine allied towns")
    var seen_enemy_town: bool = false
    for global_index: int in range(towns.size()):
        var town: Dictionary = towns[global_index]
        var habitat: Dictionary = habitat_by_id[String(town.habitat_id)]
        var owner: Dictionary = rules.resolve(plan, town.coord)
        _expect(owner.get("ok", false), "v2 town %d resolves" % global_index)
        _expect(owner.get("town_id", &"") == StringName(town.town_id), "town id is exact")
        _expect(owner.get("local_index", -1) == town.local_index, "local index is exact")
        _expect(owner.get("habitat_id", &"") == StringName(town.habitat_id), "habitat id is exact")
        _expect(owner.get("clan_id", &"") == habitat.clan_id, "clan id is exact")
        _expect(owner.get("role", "") == habitat.role, "role is exact")
        _expect(cells[town.coord].town_index == global_index, "global town index is exact")
        seen_enemy_town = seen_enemy_town or owner.get("role", "") == "enemy"
    _expect(not seen_enemy_town, "v2 has no enemy town")
    var ordinary: Vector2i = plan.get_start_coord()
    _expect(rules.resolve(plan, ordinary).get("error", &"") == &"not_a_town",
        "v2 non-town rejects")
    _expect(rules.resolve(plan, Vector2i(999, 999)).get("error", &"") == &"invalid_coordinate",
        "v2 off-map rejects")
    _test_v2_structural_rejections(plan, rules)
    _expect(plan.get_habitats() == habitats and plan.get_towns() == towns and plan.get_cells() == cells,
        "v2 ownership queries do not mutate the plan")

func _test_v2_structural_rejections(plan: WorldPlan, rules: Script) -> void:
    var towns: Array = plan.get_towns()
    var first_town: Dictionary = towns[0]

    var coord_mismatch_towns: Array = towns.duplicate(true)
    coord_mismatch_towns[0].coord = first_town.coord + Vector2i(1, 0)
    var coord_mismatch: WorldPlan = _copy_v2_plan(
        plan, plan.get_cells(), coord_mismatch_towns)
    _expect(rules.resolve(coord_mismatch, first_town.coord).get("error", &"") ==
        &"invalid_town_record", "v2 indexed town rejects mismatched record coord")

    var habitat_mismatch_towns: Array = towns.duplicate(true)
    habitat_mismatch_towns[0].habitat_id = &"ally_0"
    var habitat_mismatch: WorldPlan = _copy_v2_plan(
        plan, plan.get_cells(), habitat_mismatch_towns)
    _expect(rules.resolve(habitat_mismatch, first_town.coord).get("error", &"") ==
        &"invalid_town_record", "v2 indexed town rejects mismatched record habitat")

    var enemy_coords: Array[Vector2i] = plan.get_habitat_cells("enemy")
    _expect(not enemy_coords.is_empty(), "v2 enemy habitat has cells for rejection fixture")
    if enemy_coords.is_empty():
        return
    var enemy_coord: Vector2i = enemy_coords[0]
    var enemy_cells: Dictionary = plan.get_cells()
    enemy_cells[enemy_coord].town_index = 0
    var enemy_towns: Array = towns.duplicate(true)
    enemy_towns[0] = {
        "town_id": &"enemy_town_0",
        "habitat_id": &"enemy",
        "local_index": 0,
        "coord": enemy_coord,
    }
    var enemy_town_plan: WorldPlan = _copy_v2_plan(plan, enemy_cells, enemy_towns)
    _expect(rules.resolve(enemy_town_plan, enemy_coord).get("error", &"") ==
        &"enemy_town_owner", "v2 enemy-role town ownership rejects explicitly")

func _copy_v2_plan(plan: WorldPlan, cells: Dictionary, towns: Array) -> WorldPlan:
    return WorldPlan.new(
        2, plan.get_seed_hex(), plan.get_start_coord(), plan.get_boss_coord(),
        cells, plan.get_roads(), plan.get_forest_clusters(), plan.get_habitats(), towns)

func _copy_plan(plan: WorldPlan, version: int, cells: Dictionary) -> WorldPlan:
    return load("res://Scripts/WorldMap/world_plan.gd").new(version,
        plan.get_seed_hex(), plan.get_start_coord(), plan.get_boss_coord(),
        cells, plan.get_roads(), plan.get_forest_clusters())

func _expect(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error(label)
