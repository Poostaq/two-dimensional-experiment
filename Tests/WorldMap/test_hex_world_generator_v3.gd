class_name TestHexWorldGeneratorV3
extends SceneTree

const GENERATOR_V2_PATH := "res://Scripts/WorldMap/hex_world_generator_v2.gd"
const GENERATOR_V3_PATH := "res://Scripts/WorldMap/hex_world_generator_v3.gd"
const ROAD_RULES_PATH := "res://Scripts/WorldMap/habitat_road_rules_v3.gd"
const GEOMETRY_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"
const SEEDS: Array[String] = ["golden-ac9", "ac9-roads-alpha", "ac9-roads-beta"]
const CONFIG := {
    "main_clan_id": &"goblin",
    "allied_clan_ids": [&"orc", &"werewolf"],
    "enemy_clan_id": &"human",
}

var _failures: int = 0
var _geometry_script: GDScript


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var v2_script: GDScript = load(GENERATOR_V2_PATH)
    var v3_script: GDScript = load(GENERATOR_V3_PATH)
    var rules_script: GDScript = load(ROAD_RULES_PATH)
    _geometry_script = load(GEOMETRY_PATH)
    if (
        v2_script == null
        or v3_script == null
        or rules_script == null
        or _geometry_script == null
    ):
        _fail("V2, V3, road-rules, and geometry scripts must exist")
        _finish()
        return
    _test_v2_equivalence(v2_script, v3_script, rules_script)
    _test_interleaved_determinism(v3_script)
    _test_failure_promotion(v3_script)
    _finish()


func _test_v2_equivalence(
    v2_script: GDScript,
    v3_script: GDScript,
    rules_script: GDScript
) -> void:
    for seed_text: String in SEEDS:
        var v2_result: Dictionary = v2_script.new().generate(seed_text, CONFIG)
        var v3_result: Dictionary = v3_script.new().generate(seed_text, CONFIG)
        _expect(v2_result.get("ok", false), "%s V2 generates" % seed_text)
        _expect(v3_result.get("ok", false), "%s V3 generates" % seed_text)
        if not v2_result.get("ok", false) or not v3_result.get("ok", false):
            continue
        var v2_plan: RefCounted = v2_result["plan"]
        var v3_plan: RefCounted = v3_result["plan"]
        _expect_equal(v2_plan.get_version(), 2, "%s V2 version" % seed_text)
        _expect_equal(v3_plan.get_version(), 3, "%s V3 version" % seed_text)
        _expect_equal(v3_plan.get_seed_hex(), v2_plan.get_seed_hex(), "%s seed" % seed_text)
        _expect_equal(v3_plan.get_start_coord(), v2_plan.get_start_coord(), "%s start" % seed_text)
        _expect_equal(v3_plan.get_boss_coord(), v2_plan.get_boss_coord(), "%s boss" % seed_text)
        _expect_equal(v3_plan.get_cells(), v2_plan.get_cells(), "%s cells" % seed_text)
        _expect_equal(v3_plan.get_habitats(), v2_plan.get_habitats(), "%s habitats" % seed_text)
        _expect_equal(v3_plan.get_towns(), v2_plan.get_towns(), "%s towns" % seed_text)
        _expect_equal(
            v3_plan.get_forest_clusters(),
            v2_plan.get_forest_clusters(),
            "%s forests" % seed_text
        )
        _assert_balanced_spacing(v3_plan, seed_text)
        _expect_equal(v2_plan.get_roads(), [], "%s V2 roads remain empty" % seed_text)
        var expected: Dictionary = rules_script.build(
            v3_plan.get_towns(),
            v3_plan.get_seed_hex()
        )
        _expect_equal(v3_plan.get_roads(), expected.get("roads", []), "%s V3 roads" % seed_text)
        _assert_internal_pairs(v3_plan, seed_text)


func _test_interleaved_determinism(v3_script: GDScript) -> void:
    var first: Dictionary = v3_script.new().generate("golden-ac9", CONFIG)
    v3_script.new().generate("ac9-roads-alpha", CONFIG)
    v3_script.new().generate("ac9-roads-beta", CONFIG)
    var second: Dictionary = v3_script.new().generate("golden-ac9", CONFIG)
    _expect(first.get("ok", false) and second.get("ok", false), "interleaved runs generate")
    if not first.get("ok", false) or not second.get("ok", false):
        return
    _assert_plan_equal(first["plan"], second["plan"], "interleaved golden")


func _test_failure_promotion(v3_script: GDScript) -> void:
    var fixed_failure: Dictionary = v3_script.new().generate(
        "invalid-radius",
        CONFIG.merged({"radius": 9}, true)
    )
    _expect_failure(fixed_failure, "fixed_radius=8", "invalid radius")

    var identity_failure: Dictionary = v3_script.new().generate(
        "invalid-identity",
        {
            "main_clan_id": &"goblin",
            "allied_clan_ids": [&"orc", &"orc"],
            "enemy_clan_id": &"human",
        }
    )
    _expect_failure(identity_failure, "identity_context_invalid", "invalid identity")


func _assert_balanced_spacing(plan: RefCounted, label: String) -> void:
    var allied_counts: Array[int] = [
        plan.get_habitat_cells("main").size(),
        plan.get_habitat_cells("ally_0").size(),
        plan.get_habitat_cells("ally_1").size(),
    ]
    allied_counts.sort()
    var expected_counts: Array[int] = [69, 69, 70]
    _expect_equal(allied_counts, expected_counts, "%s allied habitat balance" % label)
    _expect_equal(plan.get_habitat_cells("enemy").size(), 9, "%s enemy footprint" % label)

    var towns: Array = plan.get_towns()
    for town_value: Variant in towns:
        var town: Dictionary = town_value
        var coord: Vector2i = town["coord"]
        _expect(
            _geometry_script.get_hex_distance(coord, plan.get_start_coord()) >= 2,
            "%s town clears player start" % label
        )
        _expect(
            _geometry_script.get_hex_distance(coord, plan.get_boss_coord()) >= 2,
            "%s town clears enemy start" % label
        )
    var adjacent_pairs: int = 0
    for first_index: int in range(towns.size()):
        for second_index: int in range(first_index + 1, towns.size()):
            if _geometry_script.get_hex_distance(
                towns[first_index]["coord"],
                towns[second_index]["coord"]
            ) < 2:
                adjacent_pairs += 1
    _expect_equal(adjacent_pairs, 0, "%s global town spacing" % label)


func _assert_internal_pairs(plan: RefCounted, label: String) -> void:
    var town_by_coord: Dictionary = {}
    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        town_by_coord[town["coord"]] = town
    var actual_by_habitat: Dictionary = {
        "main": [],
        "ally_0": [],
        "ally_1": [],
    }
    for edge_value: Variant in plan.get_roads():
        var edge: Dictionary = edge_value
        _expect(town_by_coord.has(edge["a"]), "%s road a is a town" % label)
        _expect(town_by_coord.has(edge["b"]), "%s road b is a town" % label)
        if not town_by_coord.has(edge["a"]) or not town_by_coord.has(edge["b"]):
            continue
        var a: Dictionary = town_by_coord[edge["a"]]
        var b: Dictionary = town_by_coord[edge["b"]]
        _expect_equal(a["habitat_id"], b["habitat_id"], "%s internal habitat" % label)
        actual_by_habitat[a["habitat_id"]].append(
            Vector2i(int(a["local_index"]), int(b["local_index"]))
        )
    var expected: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
    for habitat_id: String in actual_by_habitat:
        _expect_equal(actual_by_habitat[habitat_id], expected, "%s %s pairs" % [label, habitat_id])


func _assert_plan_equal(a: RefCounted, b: RefCounted, label: String) -> void:
    _expect_equal(a.get_version(), b.get_version(), "%s version" % label)
    _expect_equal(a.get_seed_hex(), b.get_seed_hex(), "%s seed" % label)
    _expect_equal(a.get_start_coord(), b.get_start_coord(), "%s start" % label)
    _expect_equal(a.get_boss_coord(), b.get_boss_coord(), "%s boss" % label)
    _expect_equal(a.get_cells(), b.get_cells(), "%s cells" % label)
    _expect_equal(a.get_roads(), b.get_roads(), "%s roads" % label)
    _expect_equal(a.get_forest_clusters(), b.get_forest_clusters(), "%s forests" % label)
    _expect_equal(a.get_habitats(), b.get_habitats(), "%s habitats" % label)
    _expect_equal(a.get_towns(), b.get_towns(), "%s towns" % label)


func _expect_failure(result: Dictionary, constraint: String, label: String) -> void:
    _expect(not result.get("ok", true), "%s rejected" % label)
    _expect_equal(result.get("plan"), null, "%s publishes no plan" % label)
    var error: Variant = result.get("error")
    _expect(error != null, "%s has typed error" % label)
    if error == null:
        return
    _expect_equal(error.generator_version, 3, "%s reports V3" % label)
    _expect_equal(error.failed_constraint, constraint, "%s constraint" % label)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_hex_world_generator_v3")
    quit(1 if _failures > 0 else 0)
