extends SceneTree

const SAVE_CODEC_PATH := "res://Scripts/Save/world_save_codec_v1.gd"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const PLAN_CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"
const FIXTURE_DIR := "res://Tests/Fixtures/WorldMap/SaveV1"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var save_codec: GDScript = load(SAVE_CODEC_PATH)
    var generator_script: GDScript = load(GENERATOR_PATH)
    var plan_codec: GDScript = load(PLAN_CODEC_PATH)
    if save_codec == null:
        _fail("WorldSaveCodecV1 script is missing")
        _finish()
        return

    var generated: Dictionary = generator_script.new().generate("golden-alpha")
    _assert_true(generated.get("ok", false), "golden-alpha generation")
    var runtime := {
        "player_coord": Vector2i(-8, 0),
        "boss_coord": Vector2i(8, 0),
        "move_count": 0,
        "sudden_death_active": false,
    }
    var bytes: PackedByteArray = save_codec.encode(generated["plan"], runtime)
    var root: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
    _assert_equal(root.get("schema"), "twde-run-save", "root schema")
    _assert_equal(root.get("save_version"), 1, "save version")
    var world: Dictionary = root.get("world", {})
    _assert_equal(world.size(), 8, "exact world field count")
    for field: String in [
        "generator_version",
        "run_seed_utf8_hex",
        "canonical_plan_utf8",
        "canonical_plan_sha256",
        "runtime_player_coord",
        "runtime_boss_coord",
        "move_count",
        "sudden_death_active",
    ]:
        _assert_true(world.has(field), "required field: %s" % field)

    var decoded: Dictionary = save_codec.decode(bytes)
    _assert_true(decoded.get("ok", false), "V1 save decodes")
    if decoded.get("ok", false):
        _assert_equal(
            plan_codec.serialize(decoded["value"]["plan"]),
            plan_codec.serialize(generated["plan"]),
            "canonical plan round trip"
        )
        _assert_equal(decoded["value"]["runtime"]["player_coord"], Vector2i(-8, 0), "player runtime")
        _assert_equal(decoded["value"]["runtime"]["boss_coord"], Vector2i(8, 0), "boss runtime")

    var original: PackedByteArray = bytes.duplicate()
    var changed_sha: Dictionary = root.duplicate(true)
    changed_sha["world"]["canonical_plan_sha256"] = "00"
    var changed_result: Dictionary = save_codec.decode((JSON.stringify(changed_sha) + "\n").to_utf8_buffer())
    _assert_code(changed_result, "SAVE_ENVELOPE_INVALID", "altered SHA")
    _assert_equal(bytes, original, "decode does not mutate source bytes")

    var invalid_runtime: Dictionary = root.duplicate(true)
    invalid_runtime["world"]["runtime_player_coord"] = [99, 99]
    _assert_code(
        save_codec.decode((JSON.stringify(invalid_runtime) + "\n").to_utf8_buffer()),
        "SAVE_ENVELOPE_INVALID",
        "invalid runtime coordinate"
    )
    _assert_code(save_codec.decode("{\"unknown\":true}\n".to_utf8_buffer()), "SAVE_ENVELOPE_INVALID", "unknown envelope")
    _assert_code(_decode_fixture(save_codec, "legacy-25-cell.json"), "LEGACY_WORLD_SAVE_UNSUPPORTED", "legacy dispatch")
    _assert_code(_decode_fixture(save_codec, "unsupported-v2.json"), "WORLD_VERSION_UNSUPPORTED", "version dispatch")
    _finish()


func _decode_fixture(codec: GDScript, filename: String) -> Dictionary:
    var file := FileAccess.open(FIXTURE_DIR + "/" + filename, FileAccess.READ)
    return codec.decode(file.get_buffer(file.get_length()))


func _assert_code(result: Dictionary, expected: String, label: String) -> void:
    _assert_true(not result.get("ok", true), "%s fails" % label)
    if not result.get("ok", true):
        _assert_equal(result["error"].code, expected, "%s code" % label)


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
        print("PASS test_world_save_codec_v1")
    quit(1 if _failures > 0 else 0)
