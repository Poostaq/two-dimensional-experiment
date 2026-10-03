class_name WorldPlanCodecV3
extends RefCounted

const VERSION := 3
const ROAD_COUNT := 9
const ROAD_INSERT_INDEX := 234
const V3_HEADER := "TWDE-WORLD,3"
const V2_HEADER := "TWDE-WORLD,2"
const RADIUS := 8

static var PLAN_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan.gd"
)
static var CODEC_V2_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan_codec_v2.gd"
)
static var ROAD_RULES_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/habitat_road_rules_v3.gd"
)
static var GEOMETRY_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/hex_world_geometry.gd"
)
static var ERROR_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_generation_error.gd"
)


static func serialize(plan: RefCounted) -> PackedByteArray:
    if validate(plan) != null:
        return PackedByteArray()
    var shadow_bytes: PackedByteArray = CODEC_V2_SCRIPT.serialize(_shadow_plan(plan))
    if shadow_bytes.is_empty():
        return PackedByteArray()
    var source_lines: PackedStringArray = (
        shadow_bytes.get_string_from_utf8().trim_suffix("\n").split("\n", false)
    )
    if source_lines.size() <= ROAD_INSERT_INDEX:
        return PackedByteArray()
    var output_lines: Array[String] = []
    var roads: Array = plan.get_roads()
    for index: int in source_lines.size():
        output_lines.append(V3_HEADER if index == 0 else source_lines[index])
        if index == ROAD_INSERT_INDEX - 1:
            for edge_value: Variant in roads:
                var edge: Dictionary = edge_value
                var a: Vector2i = edge["a"]
                var b: Vector2i = edge["b"]
                output_lines.append("road,%d,%d,%d,%d" % [a.x, a.y, b.x, b.y])
    return ("\n".join(output_lines) + "\n").to_utf8_buffer()


static func parse(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf:
        return _failure("", "utf8_bom")
    var text := bytes.get_string_from_utf8()
    if text.contains("\r") or not text.ends_with("\n") or text.ends_with("\n\n"):
        return _failure("", "line_endings")
    var lines: PackedStringArray = text.trim_suffix("\n").split("\n", false)
    if lines.is_empty() or lines[0] != V3_HEADER:
        var header_version: int = _header_version(lines[0] if not lines.is_empty() else "")
        if header_version >= 0:
            return _failure(
                "",
                "world_version",
                ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
                header_version
            )
        return _failure("", "header_record")
    if lines.size() < ROAD_INSERT_INDEX + ROAD_COUNT:
        return _failure("", "record_count")

    var roads: Array = []
    for index: int in range(ROAD_INSERT_INDEX, ROAD_INSERT_INDEX + ROAD_COUNT):
        var road_result: Dictionary = _parse_road(lines[index])
        if not bool(road_result.get("ok", false)):
            return _failure("", String(road_result.get("constraint", "road_record")))
        roads.append(road_result["edge"])

    var shadow_lines: Array[String] = []
    for index: int in lines.size():
        if index >= ROAD_INSERT_INDEX and index < ROAD_INSERT_INDEX + ROAD_COUNT:
            continue
        shadow_lines.append(V2_HEADER if index == 0 else lines[index])
    var shadow_bytes := ("\n".join(shadow_lines) + "\n").to_utf8_buffer()
    var shadow_result: Dictionary = CODEC_V2_SCRIPT.parse(shadow_bytes)
    if not bool(shadow_result.get("ok", false)):
        return _promote_v2_failure(shadow_result.get("error"))
    var shadow: RefCounted = shadow_result.get("plan") as RefCounted
    if not is_instance_valid(shadow):
        return _failure("", "v2_shadow_missing")

    var plan: RefCounted = PLAN_SCRIPT.new(
        VERSION,
        shadow.get_seed_hex(),
        shadow.get_start_coord(),
        shadow.get_boss_coord(),
        shadow.get_cells(),
        roads,
        shadow.get_forest_clusters(),
        shadow.get_habitats(),
        shadow.get_towns()
    )
    var validation: Variant = validate(plan)
    if validation != null:
        return {"ok": false, "plan": null, "error": validation}
    if serialize(plan) != bytes:
        return _failure(plan.get_seed_hex(), "noncanonical_order")
    return {"ok": true, "plan": plan, "error": null}


static func validate(plan: RefCounted) -> Variant:
    if (
        not is_instance_valid(plan)
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
    if plan.get_version() != VERSION:
        return _validation_error(plan, "world_version")
    var shadow: RefCounted = _shadow_plan(plan)
    var shadow_error: Variant = CODEC_V2_SCRIPT.validate(shadow)
    if shadow_error != null:
        return _validation_error(
            plan,
            "v2_shadow_%s" % String(shadow_error.failed_constraint)
        )
    var road_result: Dictionary = ROAD_RULES_SCRIPT.build(
        plan.get_towns(),
        plan.get_seed_hex()
    )
    if not bool(road_result.get("ok", false)):
        return road_result.get("error")
    if plan.get_roads() != road_result["roads"]:
        return _validation_error(plan, "roads_canonical")
    for edge_value: Variant in plan.get_roads():
        if not edge_value is Dictionary or not _route_is_valid(edge_value):
            return _validation_error(plan, "road_route")
    return null


static func _shadow_plan(plan: RefCounted) -> RefCounted:
    return PLAN_SCRIPT.new(
        2,
        plan.get_seed_hex(),
        plan.get_start_coord(),
        plan.get_boss_coord(),
        plan.get_cells(),
        [],
        plan.get_forest_clusters(),
        plan.get_habitats(),
        plan.get_towns()
    )


static func _parse_road(line: String) -> Dictionary:
    var fields: PackedStringArray = line.split(",", false)
    if (
        fields.size() != 5
        or fields[0] != "road"
        or not _canonical_int(fields[1])
        or not _canonical_int(fields[2])
        or not _canonical_int(fields[3])
        or not _canonical_int(fields[4])
    ):
        return {"ok": false, "edge": {}, "constraint": "road_record"}
    return {
        "ok": true,
        "edge": {
            "a": Vector2i(int(fields[1]), int(fields[2])),
            "b": Vector2i(int(fields[3]), int(fields[4])),
        },
        "constraint": "",
    }


static func _route_is_valid(edge: Dictionary) -> bool:
    if (
        not edge.has("a")
        or not edge.has("b")
        or not edge["a"] is Vector2i
        or not edge["b"] is Vector2i
    ):
        return false
    var current: Vector2i = edge["a"]
    var destination: Vector2i = edge["b"]
    if (
        current == destination
        or not GEOMETRY_SCRIPT.is_valid_coord(current, RADIUS)
        or not GEOMETRY_SCRIPT.is_valid_coord(destination, RADIUS)
    ):
        return false
    var expected_steps: int = GEOMETRY_SCRIPT.get_hex_distance(current, destination)
    var steps := 0
    while current != destination:
        var current_distance: int = GEOMETRY_SCRIPT.get_hex_distance(
            current,
            destination
        )
        var next_coord := current
        for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(current, RADIUS):
            if (
                GEOMETRY_SCRIPT.get_hex_distance(neighbor, destination)
                == current_distance - 1
            ):
                next_coord = neighbor
                break
        if next_coord == current:
            return false
        current = next_coord
        steps += 1
    return steps == expected_steps


static func _promote_v2_failure(error: Variant) -> Dictionary:
    if (
        error != null
        and error is RefCounted
        and error.get_script() == ERROR_SCRIPT
    ):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                error.code,
                error.seed_hex,
                VERSION,
                error.feature_namespace,
                error.failed_constraint
            ),
        }
    return _failure("", "v2_shadow_failure_invalid")


static func _failure(
    seed_hex: String,
    constraint: String,
    code: String = ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
    error_version: int = VERSION
) -> Dictionary:
    return {
        "ok": false,
        "plan": null,
        "error": ERROR_SCRIPT.new(
            code,
            seed_hex,
            error_version,
            "codec",
            constraint
        ),
    }


static func _validation_error(plan: RefCounted, constraint: String) -> RefCounted:
    return ERROR_SCRIPT.new(
        ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
        plan.get_seed_hex(),
        VERSION,
        "validation",
        constraint
    )


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
    var digits := value
    if value.begins_with("-"):
        digits = value.substr(1)
    if digits.is_empty() or digits.begins_with("0"):
        return false
    for character: String in digits:
        if character not in "0123456789":
            return false
    return true
