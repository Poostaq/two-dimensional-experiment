extends SceneTree

const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"
const FIXTURE_DIR := "res://Tests/Fixtures/WorldMap/GeneratorV1"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var generator_script: GDScript = load(GENERATOR_PATH)
    var codec_script: GDScript = load(CODEC_PATH)
    if generator_script == null or codec_script == null:
        _fail("HexWorldGeneratorV1 script is missing")
        _finish()
        return
    var manifest_file := FileAccess.open(FIXTURE_DIR + "/corpus_manifest.json", FileAccess.READ)
    var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
    var generator: RefCounted = generator_script.new()
    for fixture_value: Variant in manifest["fixtures"]:
        var fixture: Dictionary = fixture_value
        var result: Dictionary = generator.generate(fixture["seed_text"])
        _assert_true(result.get("ok", false), "generation succeeds: %s" % fixture["artifact"])
        if not result.get("ok", false):
            continue
        var actual: PackedByteArray = codec_script.serialize(result["plan"])
        var expected_file := FileAccess.open(FIXTURE_DIR + "/" + fixture["artifact"], FileAccess.READ)
        var expected: PackedByteArray = expected_file.get_buffer(expected_file.get_length())
        _assert_equal(actual, expected, "golden bytes: %s" % fixture["artifact"])

    var impossible := {
        "radius": 2,
        "town_count": 7,
        "town_min_distance": 4,
        "start": Vector2i(-2, 0),
        "boss": Vector2i(2, 0),
    }
    var failed: Dictionary = generator.generate("impossible", impossible)
    _assert_true(not failed.get("ok", true), "unsatisfiable generation fails")
    _assert_equal(failed.get("plan"), null, "failure publishes no plan")
    if not failed.get("ok", true):
        _assert_equal(failed["error"].code, "WORLD_CONSTRAINT_UNSATISFIABLE", "failure code")
    _finish()


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
        print("PASS test_hex_world_generator_v1")
    quit(1 if _failures > 0 else 0)
