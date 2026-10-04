class_name TestWorldPlanCodecV3
extends SceneTree

const GENERATOR_V1_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const GENERATOR_V2_PATH := "res://Scripts/WorldMap/hex_world_generator_v2.gd"
const GENERATOR_V3_PATH := "res://Scripts/WorldMap/hex_world_generator_v3.gd"
const CODEC_V1_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"
const CODEC_V2_PATH := "res://Scripts/WorldMap/world_plan_codec_v2.gd"
const CODEC_V3_PATH := "res://Scripts/WorldMap/world_plan_codec_v3.gd"
const FACADE_PATH := "res://Scripts/WorldMap/world_plan_codec.gd"
const PLAN_PATH := "res://Scripts/WorldMap/world_plan.gd"
const EXPECTED_GOLDEN_SHA256 := "8f6d33613442749ce31c209ba3ddf93bd260addb66cfce74594804ae0285ad30"
const CONFIG := {
    "main_clan_id": &"goblin",
    "allied_clan_ids": [&"orc", &"werewolf"],
    "enemy_clan_id": &"human",
}
const ROAD_INDEX := 234
const ROAD_COUNT := 9

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var generator_v3: GDScript = load(GENERATOR_V3_PATH)
    var codec_v3: GDScript = load(CODEC_V3_PATH)
    var facade: GDScript = load(FACADE_PATH)
    if generator_v3 == null or codec_v3 == null or facade == null:
        _fail("V3 generator, V3 codec, and facade must exist")
        _finish()
        return
    var generated: Dictionary = generator_v3.new().generate("golden-ac9", CONFIG)
    _expect(generated.get("ok", false), "golden V3 generates")
    if not generated.get("ok", false):
        _finish()
        return
    var plan: RefCounted = generated["plan"]
    var bytes: PackedByteArray = codec_v3.serialize(plan)
    _test_canonical_round_trip(codec_v3, facade, plan, bytes)
    _test_parse_rejections(codec_v3, plan, bytes)
    _test_serialize_rejections(codec_v3, plan)
    _test_legacy_dispatch(facade)
    _finish()


func _test_canonical_round_trip(
    codec_v3: GDScript,
    facade: GDScript,
    plan: RefCounted,
    bytes: PackedByteArray
) -> void:
    _expect(not bytes.is_empty(), "V3 serialization is nonempty")
    _expect(
        bytes.get_string_from_utf8().begins_with("TWDE-WORLD,3\n"),
        "V3 header"
    )
    _expect_equal(_sha256(bytes), EXPECTED_GOLDEN_SHA256, "V3 golden hash")
    var parsed: Dictionary = codec_v3.parse(bytes)
    _expect(parsed.get("ok", false), "V3 canonical bytes parse")
    if parsed.get("ok", false):
        _expect_equal(codec_v3.serialize(parsed["plan"]), bytes, "byte-identical round trip")
        _expect_equal(parsed["plan"].get_roads(), plan.get_roads(), "roads round trip")
    _expect_equal(facade.serialize(plan), bytes, "facade serializes V3")
    var facade_parsed: Dictionary = facade.parse(bytes)
    _expect(facade_parsed.get("ok", false), "facade parses V3")
    _expect_equal(facade.validate(plan), null, "facade validates V3")


func _test_parse_rejections(
    codec_v3: GDScript,
    plan: RefCounted,
    bytes: PackedByteArray
) -> void:
    var text: String = bytes.get_string_from_utf8()
    _expect_rejected(codec_v3, text.replace("TWDE-WORLD,3", "TWDE-WORLD,2"), "V2 header")
    _expect_rejected(codec_v3, text.replace("TWDE-WORLD,3", "TWDE-WORLD,4"), "V4 header")
    _expect_rejected_bytes(codec_v3, PackedByteArray([0xef, 0xbb, 0xbf]) + bytes, "BOM")
    _expect_rejected(codec_v3, text.replace("\n", "\r\n"), "CRLF")
    _expect_rejected(codec_v3, text.trim_suffix("\n"), "missing final LF")
    _expect_rejected(codec_v3, text + "\n", "double final LF")

    var lines: PackedStringArray = text.trim_suffix("\n").split("\n", false)
    var first_road_fields: PackedStringArray = lines[ROAD_INDEX].split(",", false)
    var first_start: Vector2i = Vector2i(int(first_road_fields[1]), int(first_road_fields[2]))
    var first_end: Vector2i = Vector2i(int(first_road_fields[3]), int(first_road_fields[4]))
    var first_habitat_id: String = ""
    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        if town.get("coord", Vector2i.ZERO) == first_start:
            first_habitat_id = String(town.get("habitat_id", ""))
            break
    var cross_habitat_coord: Vector2i = first_end
    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        if String(town.get("habitat_id", "")) != first_habitat_id:
            cross_habitat_coord = town.get("coord", Vector2i.ZERO)
            break

    var missing: PackedStringArray = lines.duplicate()
    missing.remove_at(ROAD_INDEX)
    _expect_rejected(codec_v3, _text(missing), "missing road")

    var extra: PackedStringArray = lines.duplicate()
    extra.insert(ROAD_INDEX + ROAD_COUNT, lines[ROAD_INDEX])
    _expect_rejected(codec_v3, _text(extra), "extra road")

    var reordered: PackedStringArray = lines.duplicate()
    var first_road: String = reordered[ROAD_INDEX]
    reordered[ROAD_INDEX] = reordered[ROAD_INDEX + 1]
    reordered[ROAD_INDEX + 1] = first_road
    _expect_rejected(codec_v3, _text(reordered), "reordered roads")

    var reversed: PackedStringArray = lines.duplicate()
    reversed[ROAD_INDEX] = "road,%s,%s,%s,%s" % [
        first_road_fields[3],
        first_road_fields[4],
        first_road_fields[1],
        first_road_fields[2],
    ]
    _expect_rejected(codec_v3, _text(reversed), "reversed road")

    var duplicate: PackedStringArray = lines.duplicate()
    duplicate[ROAD_INDEX + 1] = duplicate[ROAD_INDEX]
    _expect_rejected(codec_v3, _text(duplicate), "duplicate road")

    var self_edge: PackedStringArray = lines.duplicate()
    self_edge[ROAD_INDEX] = "road,%d,%d,%d,%d" % [
        first_start.x,
        first_start.y,
        first_start.x,
        first_start.y,
    ]
    _expect_rejected(codec_v3, _text(self_edge), "self edge")

    var non_town: PackedStringArray = lines.duplicate()
    var non_town_coord: Vector2i = plan.get_start_coord()
    non_town[ROAD_INDEX] = "road,%d,%d,%d,%d" % [
        non_town_coord.x,
        non_town_coord.y,
        first_end.x,
        first_end.y,
    ]
    _expect_rejected(codec_v3, _text(non_town), "non-town endpoint")

    var cross_habitat: PackedStringArray = lines.duplicate()
    cross_habitat[ROAD_INDEX] = "road,%d,%d,%d,%d" % [
        first_start.x,
        first_start.y,
        cross_habitat_coord.x,
        cross_habitat_coord.y,
    ]
    _expect_rejected(codec_v3, _text(cross_habitat), "cross-habitat edge")

    var noncanonical_int: PackedStringArray = lines.duplicate()
    noncanonical_int[ROAD_INDEX] = "road,+%s,%s,%s,%s" % [
        first_road_fields[1],
        first_road_fields[2],
        first_road_fields[3],
        first_road_fields[4],
    ]
    _expect_rejected(codec_v3, _text(noncanonical_int), "noncanonical integer")

    var extra_field: PackedStringArray = lines.duplicate()
    extra_field[ROAD_INDEX] += ",x"
    _expect_rejected(codec_v3, _text(extra_field), "extra road field")

    var late_road: PackedStringArray = lines.duplicate()
    var moved: String = late_road[ROAD_INDEX]
    late_road.remove_at(ROAD_INDEX)
    late_road.append(moved)
    _expect_rejected(codec_v3, _text(late_road), "road after forests")

    var changed_cell: PackedStringArray = lines.duplicate()
    changed_cell[8] = changed_cell[9]
    _expect_rejected(codec_v3, _text(changed_cell), "invalid V2 shadow cell")

    var changed_forest: PackedStringArray = lines.duplicate()
    changed_forest.remove_at(changed_forest.size() - 1)
    _expect_rejected(codec_v3, _text(changed_forest), "invalid V2 shadow forest")


func _test_serialize_rejections(codec_v3: GDScript, plan: RefCounted) -> void:
    var plan_script: GDScript = load(PLAN_PATH)
    var no_roads: RefCounted = _copy_plan(plan_script, plan, [])
    _expect(codec_v3.serialize(no_roads).is_empty(), "empty roads do not serialize")
    var changed_roads: Array = plan.get_roads()
    changed_roads.reverse()
    var reordered: RefCounted = _copy_plan(plan_script, plan, changed_roads)
    _expect(codec_v3.serialize(reordered).is_empty(), "reordered roads do not serialize")


func _test_legacy_dispatch(facade: GDScript) -> void:
    var v1: Dictionary = load(GENERATOR_V1_PATH).new().generate("codec-v3-v1")
    _expect(v1.get("ok", false), "V1 compatibility plan generates")
    if v1.get("ok", false):
        _expect_equal(
            facade.serialize(v1["plan"]),
            load(CODEC_V1_PATH).serialize(v1["plan"]),
            "V1 facade bytes unchanged"
        )
    var v2: Dictionary = load(GENERATOR_V2_PATH).new().generate("golden-ac9", CONFIG)
    _expect(v2.get("ok", false), "V2 compatibility plan generates")
    if v2.get("ok", false):
        _expect_equal(
            facade.serialize(v2["plan"]),
            load(CODEC_V2_PATH).serialize(v2["plan"]),
            "V2 facade bytes unchanged"
        )


func _copy_plan(plan_script: GDScript, plan: RefCounted, roads: Array) -> RefCounted:
    return plan_script.new(
        plan.get_version(),
        plan.get_seed_hex(),
        plan.get_start_coord(),
        plan.get_boss_coord(),
        plan.get_cells(),
        roads,
        plan.get_forest_clusters(),
        plan.get_habitats(),
        plan.get_towns()
    )


func _expect_rejected(codec_v3: GDScript, text: String, label: String) -> void:
    _expect_rejected_bytes(codec_v3, text.to_utf8_buffer(), label)


func _expect_rejected_bytes(
    codec_v3: GDScript,
    bytes: PackedByteArray,
    label: String
) -> void:
    var result: Dictionary = codec_v3.parse(bytes)
    _expect(not result.get("ok", true), "%s rejected" % label)
    _expect_equal(result.get("plan"), null, "%s publishes no plan" % label)
    _expect(result.get("error") != null, "%s returns typed error" % label)


func _text(lines: PackedStringArray) -> String:
    return "\n".join(lines) + "\n"


func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


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
        print("PASS test_world_plan_codec_v3")
    quit(1 if _failures > 0 else 0)
