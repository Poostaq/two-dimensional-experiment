class_name WorldRunSaveCodecV3
extends RefCounted

const SAVE_VERSION: int = 3

static var ENVELOPE_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_envelope.gd")
static var V2_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_codec_v2.gd")


static func encode(plan: RefCounted, resolved_seed: String, run_state: RefCounted) -> PackedByteArray:
    return ENVELOPE_SCRIPT.encode(plan, resolved_seed, run_state, SAVE_VERSION)


static func decode_any(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if parsed is Dictionary:
        var version: Variant = parsed.get("save_version")
        if (version is int or version is float) and version == SAVE_VERSION:
            return ENVELOPE_SCRIPT.decode(parsed, SAVE_VERSION)
    return V2_CODEC_SCRIPT.decode_any(bytes)
