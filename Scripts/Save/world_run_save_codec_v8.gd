class_name WorldRunSaveCodecV8
extends RefCounted

const SAVE_VERSION: int = 8

static var ENVELOPE_SCRIPT: Script = load("res://Scripts/Save/world_run_save_envelope.gd")
static var V7_SCRIPT: Script = load("res://Scripts/Save/world_run_save_codec_v7.gd")


static func encode(
    plan: RefCounted,
    resolved_seed: String,
    run_state: RefCounted,
    selection: RunClanSelection,
    coalition: RunClanCoalition,
    enemy_boss_selection: RefCounted
) -> PackedByteArray:
    return ENVELOPE_SCRIPT.encode(
        plan, resolved_seed, run_state, SAVE_VERSION, selection, coalition, enemy_boss_selection
    )


static func decode_any(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if parsed is Dictionary and parsed.get("save_version") == SAVE_VERSION:
        return ENVELOPE_SCRIPT.decode(parsed, SAVE_VERSION)
    return V7_SCRIPT.decode_any(bytes)
