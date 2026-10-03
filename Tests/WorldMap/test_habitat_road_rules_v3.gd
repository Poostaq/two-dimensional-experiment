class_name TestHabitatRoadRulesV3
extends SceneTree

const RULES_PATH := "res://Scripts/WorldMap/habitat_road_rules_v3.gd"
const SEED_HEX := "676f6c64656e2d616339"

const EXPECTED_ROADS: Array = [
    {"a": Vector2i(5, 0), "b": Vector2i(8, -6)},
    {"a": Vector2i(5, 0), "b": Vector2i(8, -7)},
    {"a": Vector2i(8, -6), "b": Vector2i(8, -7)},
    {"a": Vector2i(-1, 5), "b": Vector2i(0, -7)},
    {"a": Vector2i(-1, 5), "b": Vector2i(-1, -2)},
    {"a": Vector2i(0, -7), "b": Vector2i(-1, -2)},
    {"a": Vector2i(-1, 7), "b": Vector2i(-1, 8)},
    {"a": Vector2i(-1, 7), "b": Vector2i(4, 3)},
    {"a": Vector2i(-1, 8), "b": Vector2i(4, 3)},
]

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var rules_script: GDScript = load(RULES_PATH)
    if rules_script == null:
        _fail("HabitatRoadRulesV3 script is missing")
        _finish()
        return
    _test_canonical_output(rules_script)
    _test_input_order_independence(rules_script)
    _test_defensive_output(rules_script)
    _test_rejections(rules_script)
    _finish()


func _test_canonical_output(rules_script: GDScript) -> void:
    var result: Dictionary = rules_script.build(_towns(), SEED_HEX)
    _expect(result.get("ok", false), "canonical towns build roads")
    _expect_equal(result.get("roads", []), EXPECTED_ROADS, "canonical pair order")
    _expect_equal(result.get("error"), null, "success has no error")


func _test_input_order_independence(rules_script: GDScript) -> void:
    var reversed: Array = _towns()
    reversed.reverse()
    var result: Dictionary = rules_script.build(reversed, SEED_HEX)
    _expect(result.get("ok", false), "reversed towns build roads")
    _expect_equal(result.get("roads", []), EXPECTED_ROADS, "input order is irrelevant")


func _test_defensive_output(rules_script: GDScript) -> void:
    var first: Dictionary = rules_script.build(_towns(), SEED_HEX)
    var returned: Array = first.get("roads", [])
    returned[0]["a"] = Vector2i(99, 99)
    returned.clear()
    var second: Dictionary = rules_script.build(_towns(), SEED_HEX)
    _expect_equal(second.get("roads", []), EXPECTED_ROADS, "returned roads are independent")


func _test_rejections(rules_script: GDScript) -> void:
    var too_few: Array = _towns()
    too_few.pop_back()
    _expect_failure(rules_script, too_few, "town_count=9", "eight towns")

    var wrong_record: Array = _towns()
    wrong_record[0] = "town"
    _expect_failure(rules_script, wrong_record, "town_record_type", "non-dictionary town")

    var missing_field: Array = _towns()
    (missing_field[0] as Dictionary).erase("coord")
    _expect_failure(rules_script, missing_field, "town_record_fields", "missing town field")

    var enemy: Array = _towns()
    enemy[0]["habitat_id"] = "enemy"
    _expect_failure(rules_script, enemy, "town_habitat_id", "enemy town")

    var duplicate_slot: Array = _towns()
    duplicate_slot[1]["local_index"] = 0
    duplicate_slot[1]["town_id"] = "main_town_0"
    _expect_failure(rules_script, duplicate_slot, "town_slot_unique", "duplicate slot")

    var duplicate_id: Array = _towns()
    duplicate_id[1]["town_id"] = "main_town_0"
    _expect_failure(rules_script, duplicate_id, "town_id_unique", "duplicate ID")

    var duplicate_coord: Array = _towns()
    duplicate_coord[1]["coord"] = duplicate_coord[0]["coord"]
    _expect_failure(rules_script, duplicate_coord, "town_coord_unique", "duplicate coordinate")

    var off_board: Array = _towns()
    off_board[0]["coord"] = Vector2i(9, 0)
    _expect_failure(rules_script, off_board, "town_coord_on_board", "off-board coordinate")

    var noncanonical_id: Array = _towns()
    noncanonical_id[0]["town_id"] = "wrong"
    _expect_failure(rules_script, noncanonical_id, "town_id_canonical", "noncanonical ID")


func _expect_failure(
    rules_script: GDScript,
    towns: Array,
    constraint: String,
    label: String
) -> void:
    var result: Dictionary = rules_script.build(towns, SEED_HEX)
    _expect(not result.get("ok", true), "%s fails" % label)
    _expect_equal(result.get("roads", ["unexpected"]), [], "%s publishes no roads" % label)
    var error: Variant = result.get("error")
    _expect(error != null, "%s returns an error" % label)
    if error == null:
        return
    _expect_equal(error.generator_version, 3, "%s reports V3" % label)
    _expect_equal(error.feature_namespace, "roads", "%s reports roads namespace" % label)
    _expect_equal(error.failed_constraint, constraint, "%s reports stable constraint" % label)
    _expect_equal(error.seed_hex, SEED_HEX, "%s preserves seed" % label)


func _towns() -> Array:
    return [
        {"town_id": "main_town_0", "habitat_id": "main", "local_index": 0, "coord": Vector2i(5, 0)},
        {"town_id": "main_town_1", "habitat_id": "main", "local_index": 1, "coord": Vector2i(8, -6)},
        {"town_id": "main_town_2", "habitat_id": "main", "local_index": 2, "coord": Vector2i(8, -7)},
        {"town_id": "ally_0_town_0", "habitat_id": "ally_0", "local_index": 0, "coord": Vector2i(-1, 5)},
        {"town_id": "ally_0_town_1", "habitat_id": "ally_0", "local_index": 1, "coord": Vector2i(0, -7)},
        {"town_id": "ally_0_town_2", "habitat_id": "ally_0", "local_index": 2, "coord": Vector2i(-1, -2)},
        {"town_id": "ally_1_town_0", "habitat_id": "ally_1", "local_index": 0, "coord": Vector2i(-1, 7)},
        {"town_id": "ally_1_town_1", "habitat_id": "ally_1", "local_index": 1, "coord": Vector2i(-1, 8)},
        {"town_id": "ally_1_town_2", "habitat_id": "ally_1", "local_index": 2, "coord": Vector2i(4, 3)},
    ]


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
        print("PASS test_habitat_road_rules_v3")
    quit(1 if _failures > 0 else 0)
