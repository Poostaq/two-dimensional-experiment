class_name WorldRunSaveCodecV2
extends RefCounted

const SCHEMA := "twde-run-save"
const SAVE_VERSION := 2
const GENERATOR_VERSION := 1

static var V1_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_save_codec_v1.gd")
static var SAVE_ERROR_SCRIPT: GDScript = load("res://Scripts/Save/world_save_error.gd")
static var WORLD_ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PLAN_CODEC_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")


static func encode(plan: RefCounted, resolved_seed: String, run_state: RefCounted) -> PackedByteArray:
    if not is_instance_valid(plan) or not is_instance_valid(run_state):
        return PackedByteArray()
    var plan_bytes: PackedByteArray = PLAN_CODEC_SCRIPT.serialize(plan)
    var root := {
        "schema": SCHEMA,
        "save_version": SAVE_VERSION,
        "world": {
            "generator_version": plan.get_version(),
            "run_seed_utf8_hex": plan.get_seed_hex(),
            "resolved_seed": resolved_seed,
            "canonical_plan_utf8": plan_bytes.get_string_from_utf8(),
            "canonical_plan_sha256": _sha256(plan_bytes),
            "run_state": run_state.to_dictionary(),
        },
    }
    return (JSON.stringify(root) + "\n").to_utf8_buffer()


static func decode_any(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if not parsed is Dictionary:
        return _save_failure("json_object")
    var root := parsed as Dictionary
    if int(root.get("save_version", -1)) == 1 or _is_legacy_envelope(root):
        return V1_CODEC_SCRIPT.decode(bytes)
    return _decode_v2(root)


static func _is_legacy_envelope(root: Dictionary) -> bool:
    return int(root.get("map_width", -1)) == 5 and int(root.get("map_height", -1)) == 5


static func _decode_v2(root: Dictionary) -> Dictionary:
    if root.get("schema") != SCHEMA or int(root.get("save_version", -1)) != SAVE_VERSION:
        return _save_failure("root_schema")
    var world_value: Variant = root.get("world")
    if not world_value is Dictionary:
        return _save_failure("world_object")
    var world := world_value as Dictionary
    for field: String in [
        "generator_version",
        "run_seed_utf8_hex",
        "resolved_seed",
        "canonical_plan_utf8",
        "canonical_plan_sha256",
        "run_state",
    ]:
        if not world.has(field):
            return _save_failure("missing_%s" % field)
    var generator_version := int(world.get("generator_version", -1))
    if generator_version != GENERATOR_VERSION:
        return _world_failure(
            WORLD_ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
            String(world.get("run_seed_utf8_hex", "")),
            generator_version,
            "save",
            "generator_version"
        )
    if not world.get("canonical_plan_utf8") is String or not world.get("canonical_plan_sha256") is String:
        return _save_failure("plan_fields")
    var plan_bytes := String(world["canonical_plan_utf8"]).to_utf8_buffer()
    if _sha256(plan_bytes) != String(world["canonical_plan_sha256"]):
        return _save_failure("canonical_plan_sha256")
    var plan_result: Dictionary = PLAN_CODEC_SCRIPT.parse(plan_bytes)
    if not bool(plan_result.get("ok", false)):
        return _save_failure("canonical_plan")
    var plan := plan_result.get("plan") as RefCounted
    if not is_instance_valid(plan) or plan.get_seed_hex() != String(world.get("run_seed_utf8_hex", "")):
        return _save_failure("run_seed_utf8_hex")
    if not world.get("resolved_seed") is String or not world.get("run_state") is Dictionary:
        return _save_failure("runtime_fields")
    var state_result: Dictionary = RUN_STATE_SCRIPT.from_dictionary(world["run_state"], plan)
    if not bool(state_result.get("ok", false)):
        return _save_failure("run_state")
    return {
        "ok": true,
        "value": {
            "plan": plan,
            "resolved_seed": String(world["resolved_seed"]),
            "run_state": state_result["value"],
        },
        "error": null,
    }


static func _save_failure(constraint: String) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": SAVE_ERROR_SCRIPT.new(SAVE_ERROR_SCRIPT.SAVE_ENVELOPE_INVALID, constraint),
    }


static func _world_failure(
    code: String,
    seed_hex: String,
    version: int,
    feature_namespace: String,
    constraint: String
) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": WORLD_ERROR_SCRIPT.new(code, seed_hex, version, feature_namespace, constraint),
    }


static func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()
