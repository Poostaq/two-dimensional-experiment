extends SceneTree

const PLAN_PATH := "res://Scripts/WorldMap/world_plan.gd"
const CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"
const GEOMETRY_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var plan_script: GDScript = load(PLAN_PATH)
    var codec_script: GDScript = load(CODEC_PATH)
    var geometry_script: GDScript = load(GEOMETRY_PATH)
    if plan_script == null or codec_script == null or geometry_script == null:
        _fail("WorldPlan and WorldPlanCodecV1 scripts must exist")
        _finish()
        return

    var plan: RefCounted = _make_valid_plan(plan_script, geometry_script)
    var validation: Variant = codec_script.validate(plan)
    _assert_equal(validation, null, "valid plan accepted")

    var bytes: PackedByteArray = codec_script.serialize(plan)
    var text := bytes.get_string_from_utf8()
    var expected_prefix := "TWDE-WORLD,1\nseed,64656661756c742d72756e\nstart,-8,0\nboss,8,0\ncell,-8,0,safe,plain,-1\n"
    _assert_true(text.begins_with(expected_prefix), "canonical prefix")
    _assert_true(not bytes.is_empty() and bytes[0] != 0xef, "no UTF-8 BOM")
    _assert_true(text.ends_with("\n") and not text.ends_with("\n\n"), "exactly one trailing LF")
    _assert_true(text.find("\r") == -1, "LF-only serialization")

    var parsed: Dictionary = codec_script.parse(bytes)
    _assert_true(parsed.get("ok", false), "canonical bytes parse")
    if parsed.get("ok", false):
        var round_trip: PackedByteArray = codec_script.serialize(parsed["plan"])
        _assert_equal(round_trip, bytes, "byte-identical round trip")

    var crlf: PackedByteArray = text.replace("\n", "\r\n").to_utf8_buffer()
    _assert_true(not codec_script.parse(crlf).get("ok", true), "CRLF rejected")
    var no_final_lf: PackedByteArray = text.trim_suffix("\n").to_utf8_buffer()
    _assert_true(not codec_script.parse(no_final_lf).get("ok", true), "missing final LF rejected")
    var wrong_version: PackedByteArray = text.replace("TWDE-WORLD,1", "TWDE-WORLD,2").to_utf8_buffer()
    _assert_true(not codec_script.parse(wrong_version).get("ok", true), "unsupported header rejected")
    _finish()


func _make_valid_plan(plan_script: GDScript, geometry_script: GDScript) -> RefCounted:
    var towns: Array[Vector2i] = [
        Vector2i(-6, 0),
        Vector2i(-6, 4),
        Vector2i(-6, 8),
        Vector2i(-1, -4),
        Vector2i(3, -5),
        Vector2i(3, -1),
        Vector2i(3, 4),
    ]
    var forest_clusters: Array = [
        [Vector2i(-7, -1), Vector2i(-7, 0), Vector2i(-7, 1)],
        [Vector2i(-5, -3), Vector2i(-5, -2), Vector2i(-5, -1)],
        [Vector2i(-4, -4), Vector2i(-4, -3), Vector2i(-4, -2)],
        [Vector2i(-3, -5), Vector2i(-3, -4), Vector2i(-3, -3)],
        [Vector2i(-2, -6), Vector2i(-2, -5), Vector2i(-2, -4)],
        [Vector2i(-1, -7), Vector2i(-1, -6), Vector2i(-1, -5)],
        [Vector2i(0, -8), Vector2i(0, -7), Vector2i(0, -6)],
        [Vector2i(1, -8), Vector2i(1, -7), Vector2i(1, -6)],
        [Vector2i(2, -8), Vector2i(2, -7), Vector2i(2, -6)],
        [Vector2i(4, -8), Vector2i(4, -7), Vector2i(4, -6)],
    ]
    var forest_lookup: Dictionary = {}
    for cluster: Array in forest_clusters:
        for coord: Vector2i in cluster:
            forest_lookup[coord] = true

    var town_lookup: Dictionary = {}
    for index: int in range(towns.size()):
        town_lookup[towns[index]] = index

    var cells: Dictionary = {}
    for coord: Vector2i in geometry_script.get_canonical_coords(8):
        var encounter := "combat"
        if coord == Vector2i(-8, 0) or town_lookup.has(coord):
            encounter = "safe"
        elif coord == Vector2i(8, 0):
            encounter = "boss"
        cells[coord] = {
            "encounter": encounter,
            "terrain": "forest" if forest_lookup.has(coord) else "plain",
            "town_index": int(town_lookup.get(coord, -1)),
        }

    var roads: Array = []
    for index: int in range(towns.size() - 1):
        roads.append({"a": towns[index], "b": towns[index + 1]})

    return plan_script.new(
        1,
        "64656661756c742d72756e",
        Vector2i(-8, 0),
        Vector2i(8, 0),
        cells,
        roads,
        forest_clusters
    )


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
        print("PASS test_world_plan_codec_v1")
    quit(1 if _failures > 0 else 0)
