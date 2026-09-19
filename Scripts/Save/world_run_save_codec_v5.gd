class_name WorldRunSaveCodecV5
extends RefCounted

const SAVE_VERSION: int = 5
static var ENVELOPE_SCRIPT: Script = load("res://Scripts/Save/world_run_save_envelope.gd")
static var V4_SCRIPT: Script = load("res://Scripts/Save/world_run_save_codec_v4.gd")

static func encode(plan: RefCounted, resolved_seed: String, run_state: RefCounted) -> PackedByteArray:
	var bytes: PackedByteArray = ENVELOPE_SCRIPT.encode(plan, resolved_seed, run_state, SAVE_VERSION)
	if bytes.is_empty() or not decode_any(bytes).get("ok", false):
		return PackedByteArray()
	return bytes

static func decode_any(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary:
		var version: Variant = parsed.get("save_version")
		if (version is int or version is float) and version == SAVE_VERSION:
			return ENVELOPE_SCRIPT.decode(parsed, SAVE_VERSION)
	return V4_SCRIPT.decode_any(bytes)
