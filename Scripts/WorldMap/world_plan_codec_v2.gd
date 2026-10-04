class_name WorldPlanCodecV2
extends RefCounted

const VERSION := 2
const RADIUS := 8
const CELL_COUNT := 217
const FOREST_CLUSTER_COUNT := 10
const START_COORD := Vector2i(-8, 0)
const BOSS_COORD := Vector2i(8, 0)
const HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1", "enemy"]
const HABITAT_ROLES: Array[String] = ["main", "ally", "ally", "enemy"]
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]
const ENCOUNTERS: Array[String] = ["safe", "combat", "boss"]
const TERRAINS: Array[String] = ["plain", "forest"]

static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var TOWN_SOLVER_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_town_placement_solver_v2.gd"
)


static func serialize(plan: RefCounted) -> PackedByteArray:
    var start: Vector2i = plan.get_start_coord()
    var boss: Vector2i = plan.get_boss_coord()
    var lines: Array[String] = [
        "TWDE-WORLD,%d" % plan.get_version(),
        "seed,%s" % plan.get_seed_hex(),
        "start,%d,%d" % [start.x, start.y],
        "boss,%d,%d" % [boss.x, boss.y],
    ]

    for habitat_value: Variant in plan.get_habitats():
        var habitat: Dictionary = habitat_value
        var anchor: Vector2i = habitat["anchor"]
        lines.append("habitat,%s,%s,%s,%d,%d" % [
            String(habitat["habitat_id"]),
            String(habitat["role"]),
            String(habitat["clan_id"]),
            anchor.x,
            anchor.y,
        ])

    var cells: Dictionary = plan.get_cells()
    var coords: Array[Vector2i] = []
    for coord_value: Variant in cells.keys():
        if coord_value is Vector2i:
            coords.append(coord_value)
    coords.sort_custom(_coord_less)
    for coord: Vector2i in coords:
        var cell: Dictionary = cells[coord]
        lines.append("cell,%d,%d,%s,%s,%d,%s" % [
            coord.x,
            coord.y,
            String(cell["encounter"]),
            String(cell["terrain"]),
            int(cell["town_index"]),
            String(cell["habitat_id"]),
        ])

    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        var coord: Vector2i = town["coord"]
        lines.append("town,%s,%s,%d,%d,%d" % [
            String(town["town_id"]),
            String(town["habitat_id"]),
            int(town["local_index"]),
            coord.x,
            coord.y,
        ])

    var clusters: Array = plan.get_forest_clusters()
    for cluster_index: int in range(clusters.size()):
        var cluster: Array[Vector2i] = []
        for coord_value: Variant in clusters[cluster_index]:
            if coord_value is Vector2i:
                cluster.append(coord_value)
        cluster.sort_custom(_coord_less)
        for coord: Vector2i in cluster:
            lines.append("forest,%d,%d,%d" % [cluster_index, coord.x, coord.y])
    return ("\n".join(lines) + "\n").to_utf8_buffer()


static func parse(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf:
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            "",
            VERSION,
            "codec",
            "utf8_bom"
        )
    var text := bytes.get_string_from_utf8()
    if text.contains("\r") or not text.ends_with("\n") or text.ends_with("\n\n"):
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            "",
            VERSION,
            "codec",
            "line_endings"
        )
    var lines: PackedStringArray = text.trim_suffix("\n").split("\n", false)
    if lines.size() < 4:
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            "",
            VERSION,
            "codec",
            "missing_header"
        )
    if lines[0] != "TWDE-WORLD,2":
        var header_version := _header_version(lines[0])
        if header_version >= 0:
            return _failure(
                ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
                "",
                header_version,
                "codec",
                "world_version"
            )
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            "",
            VERSION,
            "codec",
            "header_record"
        )

    var seed_fields: PackedStringArray = lines[1].split(",", false)
    var start_fields: PackedStringArray = lines[2].split(",", false)
    var boss_fields: PackedStringArray = lines[3].split(",", false)
    if (
        seed_fields.size() != 2
        or seed_fields[0] != "seed"
        or not _is_lower_hex(seed_fields[1])
    ):
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            "",
            VERSION,
            "codec",
            "seed_record"
        )
    var seed_hex := String(seed_fields[1])
    if (
        not _coord_record_is_valid(start_fields, "start")
        or not _coord_record_is_valid(boss_fields, "boss")
    ):
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            seed_hex,
            VERSION,
            "codec",
            "origin_record"
        )
    var start_coord := Vector2i(int(start_fields[1]), int(start_fields[2]))
    var boss_coord := Vector2i(int(boss_fields[1]), int(boss_fields[2]))

    var minimum_lines := 4 + HABITAT_IDS.size() + CELL_COUNT + 9
    if lines.size() < minimum_lines:
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            seed_hex,
            VERSION,
            "codec",
            "record_count"
        )

    var cursor := 4
    var habitats: Array = []
    for habitat_index: int in range(HABITAT_IDS.size()):
        var habitat_fields: PackedStringArray = lines[cursor].split(",", false)
        cursor += 1
        if (
            habitat_fields.size() != 6
            or habitat_fields[0] != "habitat"
            or not _canonical_int(habitat_fields[4])
            or not _canonical_int(habitat_fields[5])
        ):
            return _failure(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                seed_hex,
                VERSION,
                "codec",
                "habitat_record"
            )
        habitats.append({
            "habitat_id": String(habitat_fields[1]),
            "role": String(habitat_fields[2]),
            "clan_id": StringName(habitat_fields[3]),
            "anchor": Vector2i(int(habitat_fields[4]), int(habitat_fields[5])),
        })

    var cells: Dictionary = {}
    for cell_index: int in range(CELL_COUNT):
        var cell_fields: PackedStringArray = lines[cursor].split(",", false)
        cursor += 1
        if (
            cell_fields.size() != 7
            or cell_fields[0] != "cell"
            or not _canonical_int(cell_fields[1])
            or not _canonical_int(cell_fields[2])
            or not _canonical_int(cell_fields[5])
        ):
            return _failure(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                seed_hex,
                VERSION,
                "codec",
                "cell_record"
            )
        var coord := Vector2i(int(cell_fields[1]), int(cell_fields[2]))
        if cells.has(coord):
            return _failure(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                seed_hex,
                VERSION,
                "codec",
                "duplicate_cell"
            )
        cells[coord] = {
            "encounter": String(cell_fields[3]),
            "terrain": String(cell_fields[4]),
            "town_index": int(cell_fields[5]),
            "habitat_id": String(cell_fields[6]),
        }

    var towns: Array = []
    for town_index: int in range(9):
        var town_fields: PackedStringArray = lines[cursor].split(",", false)
        cursor += 1
        if (
            town_fields.size() != 6
            or town_fields[0] != "town"
            or not _canonical_int(town_fields[3])
            or not _canonical_int(town_fields[4])
            or not _canonical_int(town_fields[5])
        ):
            return _failure(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                seed_hex,
                VERSION,
                "codec",
                "town_record"
            )
        towns.append({
            "town_id": String(town_fields[1]),
            "habitat_id": String(town_fields[2]),
            "local_index": int(town_fields[3]),
            "coord": Vector2i(int(town_fields[4]), int(town_fields[5])),
        })

    var clusters: Array = []
    clusters.resize(FOREST_CLUSTER_COUNT)
    for cluster_index: int in range(FOREST_CLUSTER_COUNT):
        clusters[cluster_index] = []
    while cursor < lines.size():
        var forest_fields: PackedStringArray = lines[cursor].split(",", false)
        cursor += 1
        if (
            forest_fields.size() != 4
            or forest_fields[0] != "forest"
            or not _all_canonical_ints(forest_fields, 1)
        ):
            return _failure(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                seed_hex,
                VERSION,
                "codec",
                "forest_record"
            )
        var cluster_index := int(forest_fields[1])
        if cluster_index < 0 or cluster_index >= FOREST_CLUSTER_COUNT:
            return _failure(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                seed_hex,
                VERSION,
                "codec",
                "forest_index"
            )
        clusters[cluster_index].append(
            Vector2i(int(forest_fields[2]), int(forest_fields[3]))
        )

    var plan: RefCounted = PLAN_SCRIPT.new(
        VERSION,
        seed_hex,
        start_coord,
        boss_coord,
        cells,
        [],
        clusters,
        habitats,
        towns
    )
    var validation: Variant = validate(plan)
    if validation != null:
        return {"ok": false, "plan": null, "error": validation}
    if serialize(plan) != bytes:
        return _failure(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            seed_hex,
            VERSION,
            "codec",
            "noncanonical_order"
        )
    return {"ok": true, "plan": plan, "error": null}


static func validate(plan: RefCounted) -> Variant:
    if plan.get_version() != VERSION:
        return ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
            plan.get_seed_hex(),
            plan.get_version(),
            "codec",
            "world_version"
        )
    if not _is_lower_hex(plan.get_seed_hex()):
        return _validation_error(plan, "seed_hex")
    if _seed_text_from_hex(plan.get_seed_hex()).is_empty():
        return _validation_error(plan, "seed_utf8")
    if (
        plan.get_start_coord() != START_COORD
        or plan.get_boss_coord() != BOSS_COORD
    ):
        return _validation_error(plan, "fixed_origins")
    if not plan.get_roads().is_empty():
        return _validation_error(plan, "roads_empty")

    var canonical_coords: Array[Vector2i] = GEOMETRY_SCRIPT.get_canonical_coords(RADIUS)
    var cells: Dictionary = plan.get_cells()
    var cell_error: String = _validate_cells(cells, canonical_coords)
    if not cell_error.is_empty():
        return _validation_error(plan, cell_error)

    var habitats: Array = plan.get_habitats()
    var habitat_error: String = _validate_habitats(
        habitats,
        cells,
        canonical_coords,
        plan
    )
    if not habitat_error.is_empty():
        return _validation_error(plan, habitat_error)

    var towns: Array = plan.get_towns()
    var town_error: String = _validate_towns(towns, cells, canonical_coords, plan)
    if not town_error.is_empty():
        return _validation_error(plan, town_error)

    var forest_error: String = _validate_forests(
        plan.get_forest_clusters(),
        towns,
        cells,
        canonical_coords,
        plan
    )
    if not forest_error.is_empty():
        return _validation_error(plan, forest_error)
    return null


static func _validate_cells(
    cells: Dictionary,
    canonical_coords: Array[Vector2i]
) -> String:
    if cells.size() != CELL_COUNT:
        return "cell_count=217"
    for key: Variant in cells.keys():
        if not key is Vector2i or key not in canonical_coords:
            return "canonical_cell_coverage"
    for coord: Vector2i in canonical_coords:
        if not cells.has(coord) or not cells[coord] is Dictionary:
            return "canonical_cell_coverage"
        var cell: Dictionary = cells[coord]
        if not _has_exact_keys(
            cell,
            ["encounter", "terrain", "town_index", "habitat_id"]
        ):
            return "cell_fields"
        if not _is_string_value(cell["encounter"]):
            return "cell_types"
        if not _is_string_value(cell["terrain"]):
            return "cell_types"
        if not cell["town_index"] is int:
            return "cell_types"
        if not _is_string_value(cell["habitat_id"]):
            return "cell_types"
        if String(cell["encounter"]) not in ENCOUNTERS:
            return "cell_encounter"
        if String(cell["terrain"]) not in TERRAINS:
            return "cell_terrain"
        if String(cell["habitat_id"]) not in HABITAT_IDS:
            return "cell_habitat_id"
        var town_index: int = cell["town_index"]
        if town_index < -1 or town_index >= 9:
            return "town_index_range"
    return ""


static func _validate_habitats(
    habitats: Array,
    cells: Dictionary,
    canonical_coords: Array[Vector2i],
    plan: RefCounted
) -> String:
    if habitats.size() != HABITAT_IDS.size():
        return "habitat_count=4"
    var clan_ids: Dictionary = {}
    var anchors: Dictionary = {}
    for index: int in range(HABITAT_IDS.size()):
        if not habitats[index] is Dictionary:
            return "habitat_types"
        var habitat: Dictionary = habitats[index]
        if not _has_exact_keys(
            habitat,
            ["habitat_id", "role", "clan_id", "anchor"]
        ):
            return "habitat_fields"
        if (
            not _is_string_value(habitat["habitat_id"])
            or not _is_string_value(habitat["role"])
            or not _is_string_value(habitat["clan_id"])
            or not habitat["anchor"] is Vector2i
        ):
            return "habitat_types"
        var habitat_id: String = String(habitat["habitat_id"])
        var role: String = String(habitat["role"])
        var clan_id: String = String(habitat["clan_id"])
        var anchor: Vector2i = habitat["anchor"]
        if habitat_id != HABITAT_IDS[index] or role != HABITAT_ROLES[index]:
            return "habitat_order"
        if not _is_stable_id(clan_id) or clan_ids.has(clan_id):
            return "clan_identity"
        clan_ids[clan_id] = true
        if anchor not in canonical_coords or anchors.has(anchor):
            return "habitat_anchor"
        anchors[anchor] = true
        if String(cells[anchor]["habitat_id"]) != habitat_id:
            return "habitat_anchor_membership"
        if index == 0 and anchor != plan.get_start_coord():
            return "main_anchor"
        if index == 3 and anchor != plan.get_boss_coord():
            return "enemy_anchor"

    var enemy_members: Array[Vector2i] = []
    var expected_enemy: Array[Vector2i] = []
    for coord: Vector2i in canonical_coords:
        var habitat_id: String = String(cells[coord]["habitat_id"])
        if habitat_id == "enemy":
            enemy_members.append(coord)
        if GEOMETRY_SCRIPT.get_hex_distance(coord, plan.get_boss_coord()) <= 2:
            expected_enemy.append(coord)
    if enemy_members != expected_enemy:
        return "enemy_footprint"

    var allied_counts: Dictionary = {}
    var sorted_counts: Array[int] = []
    var allied_anchors: Array[Vector2i] = []
    for allied_index: int in range(ALLIED_HABITAT_IDS.size()):
        var allied_id: String = ALLIED_HABITAT_IDS[allied_index]
        var count: int = 0
        for coord: Vector2i in canonical_coords:
            if String(cells[coord]["habitat_id"]) == allied_id:
                count += 1
        allied_counts[allied_id] = count
        sorted_counts.append(count)
        allied_anchors.append(habitats[allied_index]["anchor"])
    sorted_counts.sort()
    var expected_counts: Array[int] = [69, 69, 70]
    if sorted_counts != expected_counts:
        return "allied_habitat_balance"

    var seed_text: String = _seed_text_from_hex(plan.get_seed_hex())
    var ranked_anchors: Array[Vector2i] = PRIORITY_SCRIPT.rank_coords(
        allied_anchors,
        VERSION,
        seed_text,
        "habitat-quota-v2"
    )
    var bonus_habitat_id: String = ""
    for allied_index: int in range(allied_anchors.size()):
        if allied_anchors[allied_index] == ranked_anchors[0]:
            bonus_habitat_id = ALLIED_HABITAT_IDS[allied_index]
            break
    if bonus_habitat_id.is_empty() or int(allied_counts[bonus_habitat_id]) != 70:
        return "allied_habitat_bonus_quota"

    for habitat_id: String in HABITAT_IDS:
        var members: Array[Vector2i] = []
        for coord: Vector2i in canonical_coords:
            if String(cells[coord]["habitat_id"]) == habitat_id:
                members.append(coord)
        if members.is_empty() or not _is_connected(members):
            return "habitat_connected"
        if habitat_id in ALLIED_HABITAT_IDS:
            var capacity: int = 0
            for coord: Vector2i in members:
                if coord != plan.get_start_coord() and coord != plan.get_boss_coord():
                    capacity += 1
            if capacity < 3:
                return "habitat_town_capacity"
    return ""


static func _validate_towns(
    towns: Array,
    cells: Dictionary,
    canonical_coords: Array[Vector2i],
    plan: RefCounted
) -> String:
    if towns.size() != 9:
        return "town_count=9"
    var seen_coords: Dictionary = {}
    var town_lookup: Dictionary = {}
    for global_index: int in range(towns.size()):
        if not towns[global_index] is Dictionary:
            return "town_types"
        var town: Dictionary = towns[global_index]
        if not _has_exact_keys(
            town,
            ["town_id", "habitat_id", "local_index", "coord"]
        ):
            return "town_fields"
        if (
            not _is_string_value(town["town_id"])
            or not _is_string_value(town["habitat_id"])
            or not town["local_index"] is int
            or not town["coord"] is Vector2i
        ):
            return "town_types"
        var expected_habitat_id: String = ALLIED_HABITAT_IDS[global_index / 3]
        var expected_local_index: int = global_index % 3
        var expected_town_id: String = "%s_town_%d" % [
            expected_habitat_id,
            expected_local_index,
        ]
        var town_id: String = String(town["town_id"])
        var habitat_id: String = String(town["habitat_id"])
        var local_index: int = town["local_index"]
        var coord: Vector2i = town["coord"]
        if (
            town_id != expected_town_id
            or habitat_id != expected_habitat_id
            or local_index != expected_local_index
        ):
            return "town_order"
        if (
            coord not in canonical_coords
            or coord == plan.get_start_coord()
            or coord == plan.get_boss_coord()
            or seen_coords.has(coord)
        ):
            return "town_coord"
        if (
            GEOMETRY_SCRIPT.get_hex_distance(coord, plan.get_start_coord()) < 2
            or GEOMETRY_SCRIPT.get_hex_distance(coord, plan.get_boss_coord()) < 2
        ):
            return "town_spawn_clearance"
        seen_coords[coord] = true
        town_lookup[coord] = global_index
        if (
            String(cells[coord]["habitat_id"]) != habitat_id
            or int(cells[coord]["town_index"]) != global_index
        ):
            return "town_cell_agreement"
        if String(cells[coord]["encounter"]) != "safe":
            return "town_not_safe"

    for coord: Vector2i in canonical_coords:
        var expected_index: int = int(town_lookup.get(coord, -1))
        if int(cells[coord]["town_index"]) != expected_index:
            return "town_index_coverage"

    if String(cells[plan.get_start_coord()]["encounter"]) != "safe":
        return "start_not_safe"
    if String(cells[plan.get_boss_coord()]["encounter"]) != "boss":
        return "boss_encounter"
    var boss_count: int = 0
    for coord: Vector2i in canonical_coords:
        if String(cells[coord]["encounter"]) == "boss":
            boss_count += 1
    if boss_count != 1:
        return "sole_boss"

    var habitat_by_coord: Dictionary = {}
    for coord: Vector2i in canonical_coords:
        habitat_by_coord[coord] = String(cells[coord]["habitat_id"])
    var canonical_towns: Dictionary = TOWN_SOLVER_SCRIPT.new().solve(
        _seed_text_from_hex(plan.get_seed_hex()),
        canonical_coords,
        habitat_by_coord,
        plan.get_start_coord(),
        plan.get_boss_coord()
    )
    if (
        not canonical_towns.get("ok", false)
        or canonical_towns.get("towns", []) != towns
    ):
        return "noncanonical_town_placement"
    return ""


static func _validate_forests(
    clusters: Array,
    towns: Array,
    cells: Dictionary,
    canonical_coords: Array[Vector2i],
    plan: RefCounted
) -> String:
    if clusters.size() != FOREST_CLUSTER_COUNT:
        return "forest_cluster_count=10"
    var protected: Dictionary = {
        plan.get_start_coord(): true,
        plan.get_boss_coord(): true,
    }
    for town_value: Variant in towns:
        var town: Dictionary = town_value
        protected[town["coord"]] = true
    var forest_lookup: Dictionary = {}
    for cluster_value: Variant in clusters:
        if not cluster_value is Array:
            return "forest_types"
        var cluster: Array = cluster_value
        if cluster.size() < 3 or cluster.size() > 7:
            return "forest_cluster_size"
        var typed_cluster: Array[Vector2i] = []
        for coord_value: Variant in cluster:
            if not coord_value is Vector2i:
                return "forest_types"
            var coord: Vector2i = coord_value
            if (
                coord not in canonical_coords
                or protected.has(coord)
                or forest_lookup.has(coord)
            ):
                return "forest_coord"
            forest_lookup[coord] = true
            typed_cluster.append(coord)
        if not _is_connected(typed_cluster):
            return "forest_connected"
    for coord: Vector2i in canonical_coords:
        var expected_terrain: String = "forest" if forest_lookup.has(coord) else "plain"
        if String(cells[coord]["terrain"]) != expected_terrain:
            return "forest_terrain_mismatch"
    return ""


static func _is_connected(coords: Array[Vector2i]) -> bool:
    if coords.is_empty():
        return false
    var allowed: Dictionary = {}
    for coord: Vector2i in coords:
        allowed[coord] = true
    var visited: Dictionary = {coords[0]: true}
    var frontier: Array[Vector2i] = [coords[0]]
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(current, RADIUS):
            if allowed.has(neighbor) and not visited.has(neighbor):
                visited[neighbor] = true
                frontier.append(neighbor)
    return visited.size() == allowed.size()


static func _has_exact_keys(value: Dictionary, required: Array[String]) -> bool:
    if value.size() != required.size():
        return false
    for key: String in required:
        if not value.has(key):
            return false
    return true


static func _failure(
    code: String,
    seed_hex: String,
    version: int,
    feature_namespace: String,
    constraint: String
) -> Dictionary:
    return {
        "ok": false,
        "plan": null,
        "error": ERROR_SCRIPT.new(
            code,
            seed_hex,
            version,
            feature_namespace,
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


static func _coord_record_is_valid(
    fields: PackedStringArray,
    token: String
) -> bool:
    return (
        fields.size() == 3
        and fields[0] == token
        and _canonical_int(fields[1])
        and _canonical_int(fields[2])
    )


static func _all_canonical_ints(
    fields: PackedStringArray,
    first_index: int
) -> bool:
    for index: int in range(first_index, fields.size()):
        if not _canonical_int(fields[index]):
            return false
    return true


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


static func _seed_text_from_hex(seed_hex: String) -> String:
    var bytes: PackedByteArray = seed_hex.hex_decode()
    var seed_text: String = bytes.get_string_from_utf8()
    if seed_text.to_utf8_buffer().hex_encode() != seed_hex:
        return ""
    return seed_text


static func _is_lower_hex(value: String) -> bool:
    if value.is_empty() or value.length() % 2 != 0:
        return false
    for character: String in value:
        if character not in "0123456789abcdef":
            return false
    return true


static func _is_stable_id(value: String) -> bool:
    if (
        value.is_empty()
        or value.begins_with("_")
        or value.ends_with("_")
    ):
        return false
    for character: String in value:
        if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
            return false
    return true


static func _is_string_value(value: Variant) -> bool:
    return value is String or value is StringName


static func _header_version(header: String) -> int:
    var fields: PackedStringArray = header.split(",", false)
    if (
        fields.size() != 2
        or fields[0] != "TWDE-WORLD"
        or not _canonical_int(fields[1])
    ):
        return -1
    return int(fields[1])


static func _coord_less(a: Vector2i, b: Vector2i) -> bool:
    return a.x < b.x or (a.x == b.x and a.y < b.y)
