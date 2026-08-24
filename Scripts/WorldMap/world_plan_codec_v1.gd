class_name WorldPlanCodecV1
extends RefCounted

const VERSION := 1
const START_COORD := Vector2i(-8, 0)
const BOSS_COORD := Vector2i(8, 0)
static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")

const ENCOUNTERS: Array[String] = ["safe", "combat", "boss"]
const TERRAINS: Array[String] = ["plain", "forest"]


static func serialize(plan: RefCounted) -> PackedByteArray:
    var lines: Array[String] = [
        "TWDE-WORLD,%d" % plan.get_version(),
        "seed,%s" % plan.get_seed_hex(),
        "start,%d,%d" % [plan.get_start_coord().x, plan.get_start_coord().y],
        "boss,%d,%d" % [plan.get_boss_coord().x, plan.get_boss_coord().y],
    ]
    var cells: Dictionary = plan.get_cells()
    var coords: Array[Vector2i] = []
    for key: Variant in cells.keys():
        coords.append(key)
    coords.sort_custom(_coord_less)
    for coord: Vector2i in coords:
        var cell: Dictionary = cells[coord]
        lines.append("cell,%d,%d,%s,%s,%d" % [
            coord.x,
            coord.y,
            cell["encounter"],
            cell["terrain"],
            cell["town_index"],
        ])

    var roads: Array = []
    for road_value: Variant in plan.get_roads():
        var road: Dictionary = road_value
        var a: Vector2i = road["a"]
        var b: Vector2i = road["b"]
        if _coord_less(b, a):
            var swap := a
            a = b
            b = swap
        roads.append({"a": a, "b": b})
    roads.sort_custom(_road_less)
    for road_value: Variant in roads:
        var road: Dictionary = road_value
        var a: Vector2i = road["a"]
        var b: Vector2i = road["b"]
        lines.append("road,%d,%d,%d,%d" % [a.x, a.y, b.x, b.y])

    var clusters: Array = plan.get_forest_clusters()
    for cluster_index: int in range(clusters.size()):
        var cluster: Array[Vector2i] = []
        for coord_value: Variant in clusters[cluster_index]:
            cluster.append(coord_value)
        cluster.sort_custom(_coord_less)
        for coord: Vector2i in cluster:
            lines.append("forest,%d,%d,%d" % [cluster_index, coord.x, coord.y])
    return ("\n".join(lines) + "\n").to_utf8_buffer()


static func parse(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf:
        return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, "", VERSION, "codec", "utf8_bom")
    var text := bytes.get_string_from_utf8()
    if text.contains("\r") or not text.ends_with("\n") or text.ends_with("\n\n"):
        return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, "", VERSION, "codec", "line_endings")
    var lines := text.trim_suffix("\n").split("\n", false)
    if lines.size() < 4:
        return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, "", VERSION, "codec", "missing_header")
    if lines[0] != "TWDE-WORLD,1":
        return _failure(ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED, "", _header_version(lines[0]), "codec", "world_version")

    var seed_fields := lines[1].split(",", false)
    var start_fields := lines[2].split(",", false)
    var boss_fields := lines[3].split(",", false)
    if seed_fields.size() != 2 or seed_fields[0] != "seed" or not _is_lower_hex(seed_fields[1]):
        return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, "", VERSION, "codec", "seed_record")
    if not _coord_record_is_valid(start_fields, "start") or not _coord_record_is_valid(boss_fields, "boss"):
        return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "origin_record")

    var start_coord := Vector2i(int(start_fields[1]), int(start_fields[2]))
    var boss_coord := Vector2i(int(boss_fields[1]), int(boss_fields[2]))
    var cells: Dictionary = {}
    var roads: Array = []
    var clusters: Array = []
    clusters.resize(10)
    for cluster_index: int in range(10):
        clusters[cluster_index] = []

    for line_index: int in range(4, lines.size()):
        var fields := lines[line_index].split(",", false)
        if fields.is_empty():
            return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "empty_record")
        match fields[0]:
            "cell":
                if fields.size() != 6 or not _canonical_int(fields[1]) or not _canonical_int(fields[2]) or not _canonical_int(fields[5]):
                    return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "cell_record")
                var coord := Vector2i(int(fields[1]), int(fields[2]))
                if cells.has(coord) or fields[3] not in ENCOUNTERS or fields[4] not in TERRAINS:
                    return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "cell_value")
                cells[coord] = {
                    "encounter": fields[3],
                    "terrain": fields[4],
                    "town_index": int(fields[5]),
                }
            "road":
                if fields.size() != 5 or not _all_canonical_ints(fields, 1):
                    return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "road_record")
                roads.append({
                    "a": Vector2i(int(fields[1]), int(fields[2])),
                    "b": Vector2i(int(fields[3]), int(fields[4])),
                })
            "forest":
                if fields.size() != 4 or not _all_canonical_ints(fields, 1):
                    return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "forest_record")
                var cluster_index := int(fields[1])
                if cluster_index < 0 or cluster_index >= 10:
                    return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "forest_index")
                clusters[cluster_index].append(Vector2i(int(fields[2]), int(fields[3])))
            _:
                return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "record_type")

    var plan: RefCounted = PLAN_SCRIPT.new(VERSION, seed_fields[1], start_coord, boss_coord, cells, roads, clusters)
    var validation: Variant = validate(plan)
    if validation != null:
        return {"ok": false, "plan": null, "error": validation}
    if serialize(plan) != bytes:
        return _failure(ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR, seed_fields[1], VERSION, "codec", "noncanonical_order")
    return {"ok": true, "plan": plan, "error": null}


static func validate(plan: RefCounted) -> Variant:
    if plan.get_version() != VERSION:
        return ERROR_SCRIPT.new(ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED, plan.get_seed_hex(), plan.get_version(), "codec", "world_version")
    if plan.get_start_coord() != START_COORD or plan.get_boss_coord() != BOSS_COORD:
        return _validation_error(plan, "fixed_origins")

    var cells: Dictionary = plan.get_cells()
    if cells.size() != 217:
        return _validation_error(plan, "cell_count=217")
    var canonical_coords: Array[Vector2i] = GEOMETRY_SCRIPT.get_canonical_coords(8)
    for coord: Vector2i in canonical_coords:
        if not cells.has(coord):
            return _validation_error(plan, "missing_cell")
        var cell: Dictionary = cells[coord]
        if cell.get("encounter", "") not in ENCOUNTERS or cell.get("terrain", "") not in TERRAINS:
            return _validation_error(plan, "cell_tokens")
        var town_index: int = int(cell.get("town_index", -2))
        if town_index < -1 or town_index > 6:
            return _validation_error(plan, "town_index_range")

    var towns: Array[Vector2i] = []
    towns.resize(7)
    var seen_towns: Dictionary = {}
    for coord: Vector2i in canonical_coords:
        var town_index: int = int(cells[coord]["town_index"])
        if town_index >= 0:
            if seen_towns.has(town_index):
                return _validation_error(plan, "duplicate_town_index")
            seen_towns[town_index] = true
            towns[town_index] = coord
            if cells[coord]["encounter"] != "safe":
                return _validation_error(plan, "town_not_safe")
    if seen_towns.size() != 7:
        return _validation_error(plan, "town_count=7")
    var sorted_towns: Array[Vector2i] = towns.duplicate()
    sorted_towns.sort_custom(_coord_less)
    if sorted_towns != towns:
        return _validation_error(plan, "town_index_order")
    if cells[START_COORD]["encounter"] != "safe" or cells[BOSS_COORD]["encounter"] != "boss":
        return _validation_error(plan, "origin_encounters")

    var forest_lookup: Dictionary = {}
    var clusters: Array = plan.get_forest_clusters()
    if clusters.size() != 10:
        return _validation_error(plan, "forest_cluster_count=10")
    for cluster_value: Variant in clusters:
        var cluster: Array = cluster_value
        if cluster.size() < 3 or cluster.size() > 7 or not _is_connected(cluster):
            return _validation_error(plan, "forest_cluster_shape")
        for coord_value: Variant in cluster:
            var coord: Vector2i = coord_value
            if forest_lookup.has(coord) or coord == START_COORD or coord == BOSS_COORD or coord in towns:
                return _validation_error(plan, "forest_protected_or_duplicate")
            forest_lookup[coord] = true
    for coord: Vector2i in canonical_coords:
        var expected_terrain := "forest" if forest_lookup.has(coord) else "plain"
        if cells[coord]["terrain"] != expected_terrain:
            return _validation_error(plan, "forest_terrain_mismatch")

    if not _roads_are_tree(plan.get_roads(), towns):
        return _validation_error(plan, "road_tree")
    return null


static func _roads_are_tree(roads: Array, towns: Array[Vector2i]) -> bool:
    if roads.size() != 6:
        return false
    var adjacency: Dictionary = {}
    for town: Vector2i in towns:
        adjacency[town] = []
    var edges: Dictionary = {}
    for road_value: Variant in roads:
        var road: Dictionary = road_value
        var a: Vector2i = road.get("a", Vector2i(999, 999))
        var b: Vector2i = road.get("b", Vector2i(999, 999))
        if a == b or a not in towns or b not in towns:
            return false
        var ordered := [a, b] if _coord_less(a, b) else [b, a]
        var edge_key := "%d,%d:%d,%d" % [ordered[0].x, ordered[0].y, ordered[1].x, ordered[1].y]
        if edges.has(edge_key):
            return false
        edges[edge_key] = true
        adjacency[a].append(b)
        adjacency[b].append(a)
    var visited: Dictionary = {towns[0]: true}
    var frontier: Array[Vector2i] = [towns[0]]
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        for neighbor_value: Variant in adjacency[current]:
            var neighbor: Vector2i = neighbor_value
            if not visited.has(neighbor):
                visited[neighbor] = true
                frontier.append(neighbor)
    return visited.size() == towns.size()


static func _is_connected(cluster: Array) -> bool:
    if cluster.is_empty():
        return false
    var allowed: Dictionary = {}
    for coord_value: Variant in cluster:
        allowed[coord_value] = true
    var first: Vector2i = cluster[0]
    var visited: Dictionary = {first: true}
    var frontier: Array[Vector2i] = [first]
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(current, 8):
            if allowed.has(neighbor) and not visited.has(neighbor):
                visited[neighbor] = true
                frontier.append(neighbor)
    return visited.size() == allowed.size()


static func _failure(code: String, seed_hex: String, version: int, feature_namespace: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "plan": null,
        "error": ERROR_SCRIPT.new(code, seed_hex, version, feature_namespace, constraint),
    }


static func _validation_error(plan: RefCounted, constraint: String) -> RefCounted:
    return ERROR_SCRIPT.new(
        ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
        plan.get_seed_hex(),
        plan.get_version(),
        "validation",
        constraint
    )


static func _coord_record_is_valid(fields: PackedStringArray, token: String) -> bool:
    return fields.size() == 3 and fields[0] == token and _canonical_int(fields[1]) and _canonical_int(fields[2])


static func _all_canonical_ints(fields: PackedStringArray, first_index: int) -> bool:
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
    return digits.is_valid_int()


static func _is_lower_hex(value: String) -> bool:
    if value.is_empty() or value.length() % 2 != 0:
        return false
    for character: String in value:
        if character not in "0123456789abcdef":
            return false
    return true


static func _header_version(header: String) -> int:
    var fields := header.split(",", false)
    return int(fields[1]) if fields.size() == 2 and fields[1].is_valid_int() else -1


static func _coord_less(a: Vector2i, b: Vector2i) -> bool:
    return a.x < b.x or (a.x == b.x and a.y < b.y)


static func _road_less(a: Dictionary, b: Dictionary) -> bool:
    if a["a"] != b["a"]:
        return _coord_less(a["a"], b["a"])
    return _coord_less(a["b"], b["b"])
