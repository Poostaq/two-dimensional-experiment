extends SceneTree

const SCRIPT_PATH := "res://Scripts/WorldMap/world_priority.gd"
const VECTORS_PATH := "res://Tests/Fixtures/WorldMap/GeneratorV1/fnv_vectors.json"

var _failures: int = 0

func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var priority_script: GDScript = load(SCRIPT_PATH)
    if priority_script == null:
        _fail("WorldPriority script is missing")
        _finish()
        return

    var vectors_file := FileAccess.open(VECTORS_PATH, FileAccess.READ)
    if vectors_file == null:
        _fail("FNV vector fixture is missing")
        _finish()
        return
    var parsed: Variant = JSON.parse_string(vectors_file.get_as_text())
    if not parsed is Array:
        _fail("FNV vector fixture must be an array")
        _finish()
        return
    var vectors: Array = parsed

    _assert_equal(priority_script.normalize_seed(""), "default-run", "empty seed normalization")
    _assert_equal(priority_script.seed_hex(""), "64656661756c742d72756e", "empty seed hex")
    _assert_equal(priority_script.seed_hex("unicode-łódź"), "756e69636f64652dc582c3b364c5ba", "UTF-8 seed hex")

    for index: int in range(vectors.size()):
        var vector: Dictionary = vectors[index]
        _assert_equal(
            priority_script.fnv1a32_ascii(vector["payload"]),
            int(vector["unsigned_decimal"]),
            "FNV vector %d" % index
        )

    var expected_payload := "twde-wg|v=1|seed=64656661756c742d72756e|ns=town|i=-1|q=-8|r=0"
    _assert_equal(
        priority_script.payload(1, "", "town", -1, Vector2i(-8, 0)),
        expected_payload,
        "canonical payload"
    )

    var coords: Array[Vector2i] = [Vector2i.ZERO, Vector2i(-1, 1), Vector2i(1, -1)]
    var expected_rank: Array[Vector2i] = [Vector2i(1, -1), Vector2i(-1, 1), Vector2i.ZERO]
    _assert_equal(
        priority_script.rank_coords(coords, 1, "golden-alpha", "town"),
        expected_rank,
        "unsigned hash ordering"
    )
    _finish()


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_priority_v1")
    quit(1 if _failures > 0 else 0)
