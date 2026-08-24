extends SceneTree

const CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"
const FIXTURE_DIR := "res://Tests/Fixtures/WorldMap/GeneratorV1"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var codec_script: GDScript = load(CODEC_PATH)
    var manifest_file := FileAccess.open(FIXTURE_DIR + "/corpus_manifest.json", FileAccess.READ)
    if codec_script == null or manifest_file == null:
        _fail("Codec or corpus manifest missing")
        _finish()
        return
    var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
    _assert_equal(manifest.get("generator_version"), 1, "manifest version")
    _assert_equal(manifest.get("fixtures", []).size(), 5, "fixture count")
    for fixture_value: Variant in manifest["fixtures"]:
        var fixture: Dictionary = fixture_value
        var path: String = FIXTURE_DIR + "/" + fixture["artifact"]
        var file := FileAccess.open(path, FileAccess.READ)
        _assert_true(file != null, "fixture exists: %s" % path)
        if file == null:
            continue
        var bytes: PackedByteArray = file.get_buffer(file.get_length())
        _assert_equal(bytes.size(), int(fixture["byte_length"]), "byte length: %s" % path)
        _assert_equal(_sha256(bytes), fixture["sha256"], "SHA-256: %s" % path)
        var parsed: Dictionary = codec_script.parse(bytes)
        _assert_true(parsed.get("ok", false), "fixture parses: %s" % path)
        if parsed.get("ok", false):
            _assert_equal(codec_script.serialize(parsed["plan"]), bytes, "round trip: %s" % path)
            _assert_equal(parsed["plan"].get_cells().size(), 217, "cell count: %s" % path)
            _assert_equal(parsed["plan"].get_roads().size(), 6, "road count: %s" % path)
            _assert_equal(parsed["plan"].get_forest_clusters().size(), 10, "forest count: %s" % path)
    _finish()


func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


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
        print("PASS test_generator_v1_fixture_integrity")
    quit(1 if _failures > 0 else 0)
