class_name WorldRunSaveCodecV2Tests
extends SceneTree

const RUN_STATE_PATH := "res://Scripts/Run/world_run_state.gd"
const SAVE_CODEC_V2_PATH := "res://Scripts/Save/world_run_save_codec_v2.gd"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const PLAN_CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(RUN_STATE_PATH):
        _fail("WorldRunState script is missing")
        _finish()
        return
    if not ResourceLoader.exists(SAVE_CODEC_V2_PATH):
        _fail("WorldRunSaveCodecV2 script is missing")
        _finish()
        return
    var state_script := load(RUN_STATE_PATH) as GDScript
    var save_codec := load(SAVE_CODEC_V2_PATH) as GDScript
    var generator_script := load(GENERATOR_PATH) as GDScript
    var plan_codec := load(PLAN_CODEC_PATH) as GDScript
    var generated: Dictionary = generator_script.new().generate("golden-alpha")
    _expect(bool(generated.get("ok", false)), "golden-alpha generation succeeds")
    if not bool(generated.get("ok", false)):
        _finish()
        return
    var formation: Array[StringName] = [
        &"starter_vanguard",
        &"starter_scout",
        &"",
        &"starter_mage",
        &"",
        &"",
    ]
    var consumed: Array[Vector2i] = [Vector2i(-7, 0)]
    var state: RefCounted = state_script.create(
        Vector2i(-7, 0),
        Vector2i(8, -1),
        31,
        true,
        false,
        consumed,
        formation
    )
    _expect(is_instance_valid(state), "valid durable run state is created")
    var bytes: PackedByteArray = save_codec.encode(generated["plan"], "golden-alpha", state)
    var root_value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    _expect(root_value is Dictionary, "Save V2 is JSON")
    if root_value is Dictionary:
        var root := root_value as Dictionary
        _expect(root.get("schema") == "twde-run-save", "Save V2 schema is canonical")
        _expect(int(root.get("save_version", 0)) == 2, "Save V2 version is 2")
    var decoded: Dictionary = save_codec.decode_any(bytes)
    _expect(bool(decoded.get("ok", false)), "Save V2 decodes")
    if bool(decoded.get("ok", false)):
        var value := decoded.get("value", {}) as Dictionary
        var decoded_state := value.get("run_state") as RefCounted
        _expect(
            decoded_state.call("canonical_key") == state.call("canonical_key"),
            "runtime state round trips"
        )
        _expect(
            plan_codec.serialize(value.get("plan")) == plan_codec.serialize(generated["plan"]),
            "canonical plan bytes round trip"
        )
        _expect(String(value.get("resolved_seed", "")) == "golden-alpha", "resolved seed round trips")
    var root := root_value as Dictionary
    var altered_sha := root.duplicate(true)
    altered_sha["world"]["canonical_plan_sha256"] = "00"
    _expect_code(
        save_codec.decode_any((JSON.stringify(altered_sha) + "\n").to_utf8_buffer()),
        "SAVE_ENVELOPE_INVALID",
        "altered Save V2 plan SHA"
    )
    var unsupported_version := root.duplicate(true)
    unsupported_version["world"]["generator_version"] = 2
    _expect_code(
        save_codec.decode_any((JSON.stringify(unsupported_version) + "\n").to_utf8_buffer()),
        "WORLD_VERSION_UNSUPPORTED",
        "unsupported Save V2 generator"
    )
    var v1_codec := load("res://Scripts/Save/world_save_codec_v1.gd") as GDScript
    var v1_bytes: PackedByteArray = v1_codec.encode(generated["plan"], {
        "player_coord": Vector2i(-8, 0),
        "boss_coord": Vector2i(8, 0),
        "move_count": 0,
        "sudden_death_active": false,
    })
    _expect(bool(save_codec.decode_any(v1_bytes).get("ok", false)), "Save V1 remains readable through V2 dispatch")
    _expect(
        not is_instance_valid(state_script.create(
            Vector2i(-8, 0), Vector2i(8, 0), 29, true, false, [], formation
        )),
        "boss cannot activate before move 30"
    )
    var duplicate_formation: Array[StringName] = [&"same", &"same", &"", &"", &"", &""]
    _expect(
        not is_instance_valid(state_script.create(
            Vector2i(-8, 0), Vector2i(8, 0), 0, false, false, [], duplicate_formation
        )),
        "duplicate formation IDs are rejected"
    )
    _finish()


func _expect_code(result: Dictionary, expected_code: String, message: String) -> void:
    _expect(not bool(result.get("ok", true)), "%s fails" % message)
    if not bool(result.get("ok", true)):
        var error := result.get("error") as RefCounted
        _expect(String(error.get("code")) == expected_code, "%s returns %s" % [message, expected_code])


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_save_codec_v2")
    quit(1 if _failures > 0 else 0)
