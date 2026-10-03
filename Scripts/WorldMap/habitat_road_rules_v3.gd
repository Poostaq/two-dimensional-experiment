class_name HabitatRoadRulesV3
extends RefCounted

const VERSION := 3
const RADIUS := 8
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]
const LOCAL_PAIRS: Array[Vector2i] = [
    Vector2i(0, 1),
    Vector2i(0, 2),
    Vector2i(1, 2),
]

static var GEOMETRY_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/hex_world_geometry.gd"
)
static var ERROR_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_generation_error.gd"
)


static func build(towns: Array, seed_hex: String) -> Dictionary:
    if towns.size() != 9:
        return _failure(seed_hex, "town_count=9")
    var slots: Dictionary = {}
    var seen_ids: Dictionary = {}
    var seen_coords: Dictionary = {}
    for town_value: Variant in towns:
        if not town_value is Dictionary:
            return _failure(seed_hex, "town_record_type")
        var town: Dictionary = town_value
        if not _has_exact_keys(
            town,
            ["town_id", "habitat_id", "local_index", "coord"]
        ):
            return _failure(seed_hex, "town_record_fields")
        if (
            not _is_string_value(town["town_id"])
            or not _is_string_value(town["habitat_id"])
            or not town["local_index"] is int
            or not town["coord"] is Vector2i
        ):
            return _failure(seed_hex, "town_record_type")
        var habitat_id := String(town["habitat_id"])
        var local_index: int = town["local_index"]
        var town_id := String(town["town_id"])
        var coord: Vector2i = town["coord"]
        if habitat_id not in ALLIED_HABITAT_IDS or local_index < 0 or local_index > 2:
            return _failure(seed_hex, "town_habitat_id")
        var slot := "%s:%d" % [habitat_id, local_index]
        if slots.has(slot):
            return _failure(seed_hex, "town_slot_unique")
        if seen_ids.has(town_id):
            return _failure(seed_hex, "town_id_unique")
        if town_id != "%s_town_%d" % [habitat_id, local_index]:
            return _failure(seed_hex, "town_id_canonical")
        if seen_coords.has(coord):
            return _failure(seed_hex, "town_coord_unique")
        if not GEOMETRY_SCRIPT.is_valid_coord(coord, RADIUS):
            return _failure(seed_hex, "town_coord_on_board")
        slots[slot] = coord
        seen_ids[town_id] = true
        seen_coords[coord] = true

    var roads: Array = []
    for habitat_id: String in ALLIED_HABITAT_IDS:
        for pair: Vector2i in LOCAL_PAIRS:
            var a_key := "%s:%d" % [habitat_id, pair.x]
            var b_key := "%s:%d" % [habitat_id, pair.y]
            if not slots.has(a_key) or not slots.has(b_key):
                return _failure(seed_hex, "town_slot_missing")
            roads.append({"a": slots[a_key], "b": slots[b_key]})
    return {"ok": true, "roads": roads.duplicate(true), "error": null}


static func _has_exact_keys(value: Dictionary, required: Array[String]) -> bool:
    if value.size() != required.size():
        return false
    for key: String in required:
        if not value.has(key):
            return false
    return true


static func _is_string_value(value: Variant) -> bool:
    return value is String or value is StringName


static func _failure(seed_hex: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "roads": [],
        "error": ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            seed_hex,
            VERSION,
            "roads",
            constraint
        ),
    }
