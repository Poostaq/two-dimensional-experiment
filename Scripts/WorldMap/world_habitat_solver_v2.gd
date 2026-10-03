class_name WorldHabitatSolverV2
extends RefCounted

const VERSION := 2
const ENEMY_FOOTPRINT_RADIUS := 2
const TOWNS_PER_ALLIED_HABITAT := 3
const HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1", "enemy"]
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")


func solve(
    seed_text: String,
    coords: Array[Vector2i],
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Dictionary:
    var enemy_lookup: Dictionary = {}
    var allied_coords: Array[Vector2i] = []
    for coord: Vector2i in coords:
        if GEOMETRY_SCRIPT.get_hex_distance(coord, enemy_coord) <= ENEMY_FOOTPRINT_RADIUS:
            enemy_lookup[coord] = true
        else:
            allied_coords.append(coord)

    var anchor_candidates: Array[Vector2i] = []
    for coord: Vector2i in allied_coords:
        if coord != start_coord:
            anchor_candidates.append(coord)
    anchor_candidates = PRIORITY_SCRIPT.rank_coords(
        anchor_candidates,
        VERSION,
        seed_text,
        "habitat-anchor-v2"
    )

    for first_index: int in range(anchor_candidates.size()):
        for second_index: int in range(anchor_candidates.size()):
            if first_index == second_index:
                continue
            var anchors: Array[Vector2i] = [
                start_coord,
                anchor_candidates[first_index],
                anchor_candidates[second_index],
            ]
            var habitat_by_coord: Dictionary = _partition(allied_coords, anchors)
            if habitat_by_coord.size() != allied_coords.size():
                continue
            if not _has_town_capacity(habitat_by_coord, start_coord, enemy_coord):
                continue

            for enemy_cell_value: Variant in enemy_lookup.keys():
                var enemy_cell: Vector2i = enemy_cell_value
                habitat_by_coord[enemy_cell] = "enemy"

            var habitats: Array = [
                {"habitat_id": "main", "role": "main", "anchor": anchors[0]},
                {"habitat_id": "ally_0", "role": "ally", "anchor": anchors[1]},
                {"habitat_id": "ally_1", "role": "ally", "anchor": anchors[2]},
                {"habitat_id": "enemy", "role": "enemy", "anchor": enemy_coord},
            ]
            var towns: Array = _select_towns(
                seed_text,
                coords,
                habitat_by_coord,
                start_coord,
                enemy_coord
            )
            if towns.size() != ALLIED_HABITAT_IDS.size() * TOWNS_PER_ALLIED_HABITAT:
                continue
            return {
                "ok": true,
                "habitat_by_coord": habitat_by_coord,
                "habitats": habitats,
                "towns": towns,
                "error": null,
            }

    return _failure(seed_text, "connected_partition_with_town_capacity")


func _partition(
    allied_coords: Array[Vector2i],
    anchors: Array[Vector2i]
) -> Dictionary:
    var traversable: Dictionary = {}
    for coord: Vector2i in allied_coords:
        traversable[coord] = true
    for anchor: Vector2i in anchors:
        if not traversable.has(anchor):
            return {}

    var ownership: Dictionary = {}
    var queue_coords: Array[Vector2i] = []
    var queue_habitat_ids: Array[String] = []
    for index: int in range(ALLIED_HABITAT_IDS.size()):
        var anchor: Vector2i = anchors[index]
        ownership[anchor] = ALLIED_HABITAT_IDS[index]
        queue_coords.append(anchor)
        queue_habitat_ids.append(ALLIED_HABITAT_IDS[index])

    var cursor: int = 0
    while cursor < queue_coords.size():
        var current: Vector2i = queue_coords[cursor]
        var habitat_id: String = queue_habitat_ids[cursor]
        cursor += 1
        for offset: Vector2i in GEOMETRY_SCRIPT.NEIGHBOR_OFFSETS:
            var neighbor: Vector2i = current + offset
            if not traversable.has(neighbor) or ownership.has(neighbor):
                continue
            ownership[neighbor] = habitat_id
            queue_coords.append(neighbor)
            queue_habitat_ids.append(habitat_id)
    return ownership


func _has_town_capacity(
    habitat_by_coord: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> bool:
    var capacity: Dictionary = {"main": 0, "ally_0": 0, "ally_1": 0}
    for coord_value: Variant in habitat_by_coord.keys():
        var coord: Vector2i = coord_value
        if coord == start_coord or coord == enemy_coord:
            continue
        var habitat_id: String = String(habitat_by_coord[coord])
        if capacity.has(habitat_id):
            capacity[habitat_id] = int(capacity[habitat_id]) + 1
    for habitat_id: String in ALLIED_HABITAT_IDS:
        if int(capacity[habitat_id]) < TOWNS_PER_ALLIED_HABITAT:
            return false
    return true


func _select_towns(
    seed_text: String,
    coords: Array[Vector2i],
    habitat_by_coord: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Array:
    var towns: Array = []
    for habitat_index: int in range(ALLIED_HABITAT_IDS.size()):
        var habitat_id: String = ALLIED_HABITAT_IDS[habitat_index]
        var candidates: Array[Vector2i] = []
        for coord: Vector2i in coords:
            if coord == start_coord or coord == enemy_coord:
                continue
            if String(habitat_by_coord.get(coord, "")) == habitat_id:
                candidates.append(coord)
        candidates = PRIORITY_SCRIPT.rank_coords(
            candidates,
            VERSION,
            seed_text,
            "habitat-town-v2",
            habitat_index
        )
        if candidates.size() < TOWNS_PER_ALLIED_HABITAT:
            return []
        for local_index: int in range(TOWNS_PER_ALLIED_HABITAT):
            towns.append({
                "town_id": "%s_town_%d" % [habitat_id, local_index],
                "habitat_id": habitat_id,
                "local_index": local_index,
                "coord": candidates[local_index],
            })
    return towns


func _failure(seed_text: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "habitat_by_coord": {},
        "habitats": [],
        "towns": [],
        "error": ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_CONSTRAINT_UNSATISFIABLE,
            PRIORITY_SCRIPT.seed_hex(seed_text),
            VERSION,
            "habitat",
            constraint
        ),
    }
