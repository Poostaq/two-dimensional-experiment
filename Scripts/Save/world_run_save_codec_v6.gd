class_name WorldRunSaveCodecV6
extends RefCounted

const SAVE_VERSION: int = 6

static var ENVELOPE_SCRIPT: Script = load("res://Scripts/Save/world_run_save_envelope.gd")
static var V5_SCRIPT: Script = load("res://Scripts/Save/world_run_save_codec_v5.gd")


static func encode(
    plan: RefCounted,
    resolved_seed: String,
    run_state: RefCounted,
    selection: RunClanSelection
) -> PackedByteArray:
    return ENVELOPE_SCRIPT.encode(plan, resolved_seed, run_state, SAVE_VERSION, selection)


static func decode_any(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if parsed is Dictionary and parsed.get("save_version") == SAVE_VERSION:
        return ENVELOPE_SCRIPT.decode(parsed, SAVE_VERSION)
    return V5_SCRIPT.decode_any(bytes)
