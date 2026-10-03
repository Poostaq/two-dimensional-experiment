class_name WorldPlanCodec
extends RefCounted

static var CODEC_V1_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan_codec_v1.gd"
)
static var CODEC_V2_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan_codec_v2.gd"
)
static var CODEC_V3_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan_codec_v3.gd"
)
static var ERROR_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_generation_error.gd"
)
static var PLAN_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan.gd"
)


static func serialize(plan: Variant) -> PackedByteArray:
	if (
		plan == null
		or not plan is RefCounted
		or not plan.has_method("get_version")
		or plan.get_script() != PLAN_SCRIPT
	):
		return PackedByteArray()
	match int(plan.get_version()):
		1:
			return CODEC_V1_SCRIPT.serialize(plan)
		2:
			return CODEC_V2_SCRIPT.serialize(plan)
		3:
			return CODEC_V3_SCRIPT.serialize(plan)
		_:
			return PackedByteArray()


static func parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf:
		return _failure(
			ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
			-1,
            "utf8_bom"
		)
	var text := bytes.get_string_from_utf8()
	var newline_index := text.find("\n")
	if newline_index < 0:
		return _failure(
			ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
			-1,
            "header_record"
		)
	var header := text.substr(0, newline_index)
	match header:
		"TWDE-WORLD,1":
			return CODEC_V1_SCRIPT.parse(bytes)
		"TWDE-WORLD,2":
			return CODEC_V2_SCRIPT.parse(bytes)
		"TWDE-WORLD,3":
			return CODEC_V3_SCRIPT.parse(bytes)
		_:
			var version := _header_version(header)
			if version >= 0:
				return _failure(
					ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
					version,
                    "world_version"
				)
			return _failure(
				ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
				-1,
                "header_record"
			)


static func validate(plan: Variant) -> Variant:
	if (
		plan == null
		or not plan is RefCounted
		or not plan.has_method("get_version")
		or plan.get_script() != PLAN_SCRIPT
	):
		return ERROR_SCRIPT.new(
			ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
			"",
			-1,
			"codec",
            "world_version"
		)
	match int(plan.get_version()):
		1:
			return CODEC_V1_SCRIPT.validate(plan)
		2:
			return CODEC_V2_SCRIPT.validate(plan)
		3:
			return CODEC_V3_SCRIPT.validate(plan)
		_:
			return ERROR_SCRIPT.new(
				ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
				plan.get_seed_hex(),
				plan.get_version(),
				"codec",
                "world_version"
			)


static func _failure(code: String, version: int, constraint: String) -> Dictionary:
	return {
		"ok": false,
		"plan": null,
		"error": ERROR_SCRIPT.new(
			code,
			"",
			version,
			"codec",
			constraint
		),
	}


static func _header_version(header: String) -> int:
	var fields: PackedStringArray = header.split(",", false)
	if (
		fields.size() != 2
		or fields[0] != "TWDE-WORLD"
		or not _canonical_int(fields[1])
	):
		return -1
	return int(fields[1])


static func _canonical_int(value: String) -> bool:
	if value == "0":
		return true
	if value.is_empty() or value.begins_with("-") or value.begins_with("0"):
		return false
	for character: String in value:
		if character not in "0123456789":
			return false
	return true
