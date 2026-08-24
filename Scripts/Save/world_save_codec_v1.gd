class_name WorldSaveCodecV1
extends RefCounted

const SCHEMA := "twde-run-save"
const SAVE_VERSION := 1
const GENERATOR_VERSION := 1

const REQUIRED_WORLD_FIELDS: Array[String] = [
    "generator_version",
    "run_seed_utf8_hex",
    "canonical_plan_utf8",
    "canonical_plan_sha256",
    "runtime_player_coord",
    "runtime_boss_coord",
    "move_count",
    "sudden_death_active",
]

static var SAVE_ERROR_SCRIPT: GDScript = load("res://Scripts/Save/world_save_error.gd")
static var WORLD_ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PLAN_CODEC_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")


static func encode(plan: RefCounted, runtime_state: Dictionary) -> PackedByteArray:
    var plan_bytes: PackedByteArray = PLAN_CODEC_SCRIPT.serialize(plan)
    var world := {
        "generator_version": plan.get_version(),
        "run_seed_utf8_hex": plan.get_seed_hex(),
        "canonical_plan_utf8": plan_bytes.get_string_from_utf8(),
        "canonical_plan_sha256": _sha256(plan_bytes),
        "runtime_player_coord": _coord_array(runtime_state["player_coord"]),
        "runtime_boss_coord": _coord_array(runtime_state["boss_coord"]),
        "move_count": int(runtime_state["move_count"]),
        "sudden_death_active": bool(runtime_state["sudden_death_active"]),
    }
    return (JSON.stringify({
        "schema": SCHEMA,
        "save_version": SAVE_VERSION,
        "world": world,
    }) + "\n").to_utf8_buffer()


static func decode(bytes: PackedByteArray) -> Dictionary:
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if not parsed is Dictionary:
        return _save_failure("json_object")
    var root: Dictionary = parsed
    if _is_legacy_envelope(root):
        return _world_failure(
            WORLD_ERROR_SCRIPT.LEGACY_WORLD_SAVE_UNSUPPORTED,
            "",
            0,
            "save",
            "legacy_25_cell"
        )
    if root.get("schema") != SCHEMA or int(root.get("save_version", -1)) != SAVE_VERSION:
        return _save_failure("root_schema")
    if not root.get("world") is Dictionary:
        return _save_failure("world_object")
    var world: Dictionary = root["world"]
    if world.size() != REQUIRED_WORLD_FIELDS.size():
        return _save_failure("world_field_count")
    for field: String in REQUIRED_WORLD_FIELDS:
        if not world.has(field):
            return _save_failure("missing_%s" % field)

    var generator_version: int = int(world["generator_version"])
    if generator_version != GENERATOR_VERSION:
        return _world_failure(
            WORLD_ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
            str(world["run_seed_utf8_hex"]),
            generator_version,
            "save",
            "generator_version"
        )
    if not world["canonical_plan_utf8"] is String or not world["canonical_plan_sha256"] is String:
        return _save_failure("plan_fields")
    var plan_bytes: PackedByteArray = String(world["canonical_plan_utf8"]).to_utf8_buffer()
    if _sha256(plan_bytes) != String(world["canonical_plan_sha256"]):
        return _save_failure("canonical_plan_sha256")
    var plan_result: Dictionary = PLAN_CODEC_SCRIPT.parse(plan_bytes)
    if not plan_result.get("ok", false):
        return _save_failure("canonical_plan")
    var plan: RefCounted = plan_result["plan"]
    if plan.get_seed_hex() != str(world["run_seed_utf8_hex"]):
        return _save_failure("run_seed_utf8_hex")

    var player_result: Dictionary = _decode_coord(world["runtime_player_coord"])
    var boss_result: Dictionary = _decode_coord(world["runtime_boss_coord"])
    if not player_result.get("ok", false) or not boss_result.get("ok", false):
        return _save_failure("runtime_coord")
    var player_coord: Vector2i = player_result["coord"]
    var boss_coord: Vector2i = boss_result["coord"]
    if not GEOMETRY_SCRIPT.is_valid_coord(player_coord, 8) or not GEOMETRY_SCRIPT.is_valid_coord(boss_coord, 8):
        return _save_failure("runtime_coord")
    if not world["move_count"] is float and not world["move_count"] is int:
        return _save_failure("move_count_type")
    var move_count: int = int(world["move_count"])
    if move_count < 0 or not world["sudden_death_active"] is bool:
        return _save_failure("runtime_state")

    return {
        "ok": true,
        "value": {
            "plan": plan,
            "runtime": {
                "player_coord": player_coord,
                "boss_coord": boss_coord,
                "move_count": move_count,
                "sudden_death_active": world["sudden_death_active"],
            },
        },
        "error": null,
    }


static func _decode_coord(value: Variant) -> Dictionary:
    if not value is Array or value.size() != 2:
        return {"ok": false}
    if (not value[0] is float and not value[0] is int) or (not value[1] is float and not value[1] is int):
        return {"ok": false}
    return {"ok": true, "coord": Vector2i(int(value[0]), int(value[1]))}


static func _is_legacy_envelope(root: Dictionary) -> bool:
    return int(root.get("map_width", -1)) == 5 and int(root.get("map_height", -1)) == 5


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


static func _coord_array(coord: Vector2i) -> Array[int]:
    return [coord.x, coord.y]


static func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()
