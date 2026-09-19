class_name WorldRunSaveCodecV2
extends RefCounted

const SCHEMA := "twde-run-save"
const SAVE_VERSION := 2
const GENERATOR_VERSION := 1
const STARTER_ROSTER_VERSION := 1

static var ENVELOPE_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_envelope.gd")
static var V1_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_save_codec_v1.gd")
static var SAVE_ERROR_SCRIPT: GDScript = load("res://Scripts/Save/world_save_error.gd")


static func encode(plan: RefCounted, resolved_seed: String, run_state: RefCounted) -> PackedByteArray:
    return ENVELOPE_SCRIPT.encode(plan, resolved_seed, run_state, SAVE_VERSION)


static func decode_any(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if not parsed is Dictionary:
        return _save_failure("json_object")
    var root: Dictionary = parsed
    var version: Variant = root.get("save_version")
    if not root.has("save_version") and _is_legacy_envelope(root):
        return V1_CODEC_SCRIPT.decode(bytes)
    if not (version is int or version is float):
        return _save_failure("save_version")
    if version == 1:
        return V1_CODEC_SCRIPT.decode(bytes)
    return ENVELOPE_SCRIPT.decode(root, SAVE_VERSION)


static func _is_legacy_envelope(root: Dictionary) -> bool:
    return root.get("map_width") == 5 and root.get("map_height") == 5


static func _save_failure(constraint: String) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": SAVE_ERROR_SCRIPT.new(SAVE_ERROR_SCRIPT.SAVE_ENVELOPE_INVALID, constraint),
    }
