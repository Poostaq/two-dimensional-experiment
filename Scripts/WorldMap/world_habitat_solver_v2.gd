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
static var TOWN_SOLVER_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_town_placement_solver_v2.gd"
)


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

    var best_fallback: Dictionary = {}
    for first_index: int in range(anchor_candidates.size()):
        for second_index: int in range(anchor_candidates.size()):
            if first_index == second_index:
                continue
            var anchors: Array[Vector2i] = [
                start_coord,
                anchor_candidates[first_index],
                anchor_candidates[second_index],
            ]
            var quotas: Dictionary = _quota_by_habitat(
                seed_text,
                anchors,
                allied_coords.size()
            )
            var habitat_by_coord: Dictionary = _partition(allied_coords, anchors, quotas)
            if habitat_by_coord.size() != allied_coords.size():
                continue

            for enemy_cell_value: Variant in enemy_lookup.keys():
                var enemy_cell: Vector2i = enemy_cell_value
                habitat_by_coord[enemy_cell] = "enemy"

            var town_result: Dictionary = TOWN_SOLVER_SCRIPT.new().solve(
                seed_text,
                coords,
                habitat_by_coord,
                start_coord,
                enemy_coord
            )
            if not town_result.get("ok", false):
                continue
            if town_result.get("fully_spaced", false):
                return _success(
                    habitat_by_coord,
                    anchors,
                    enemy_coord,
                    town_result["towns"]
                )
            if _is_better_fallback(town_result, best_fallback):
                best_fallback = {
                    "habitat_by_coord": habitat_by_coord,
                    "anchors": anchors,
                    "town_result": town_result,
                }

    if not best_fallback.is_empty():
        var fallback_town_result: Dictionary = best_fallback["town_result"]
        return _success(
            best_fallback["habitat_by_coord"],
            best_fallback["anchors"],
            enemy_coord,
            fallback_town_result["towns"]
        )
    return _failure(seed_text, "balanced_partition_with_town_capacity")


func _quota_by_habitat(
    seed_text: String,
    anchors: Array[Vector2i],
    allied_cell_count: int
) -> Dictionary:
    var base_quota: int = allied_cell_count / ALLIED_HABITAT_IDS.size()
    var bonus_count: int = allied_cell_count % ALLIED_HABITAT_IDS.size()
    var ranked_anchors: Array[Vector2i] = PRIORITY_SCRIPT.rank_coords(
        anchors,
        VERSION,
        seed_text,
        "habitat-quota-v2"
    )
    var bonus_anchors: Dictionary = {}
    for index: int in range(bonus_count):
        bonus_anchors[ranked_anchors[index]] = true

    var quotas: Dictionary = {}
    for index: int in range(ALLIED_HABITAT_IDS.size()):
        quotas[ALLIED_HABITAT_IDS[index]] = (
            base_quota + 1 if bonus_anchors.has(anchors[index]) else base_quota
        )
    return quotas


func _partition(
    allied_coords: Array[Vector2i],
    anchors: Array[Vector2i],
    quotas: Dictionary
) -> Dictionary:
    var traversable: Dictionary = {}
    for coord: Vector2i in allied_coords:
        traversable[coord] = true
    for anchor: Vector2i in anchors:
        if not traversable.has(anchor):
            return {}

    var ownership: Dictionary = {}
    var frontiers: Dictionary = {}
    var cursors: Dictionary = {}
    var counts: Dictionary = {}
    for index: int in range(ALLIED_HABITAT_IDS.size()):
        var habitat_id: String = ALLIED_HABITAT_IDS[index]
        var anchor: Vector2i = anchors[index]
        ownership[anchor] = habitat_id
        frontiers[habitat_id] = [anchor]
        cursors[habitat_id] = 0
        counts[habitat_id] = 1

    while ownership.size() < allied_coords.size():
        var round_progress: bool = false
        for habitat_id: String in ALLIED_HABITAT_IDS:
            if int(counts[habitat_id]) >= int(quotas[habitat_id]):
                continue
            var frontier: Array = frontiers[habitat_id]
            var cursor: int = int(cursors[habitat_id])
            var claimed_for_habitat: bool = false
            while cursor < frontier.size() and not claimed_for_habitat:
                var current: Vector2i = frontier[cursor]
                cursor += 1
                for offset: Vector2i in GEOMETRY_SCRIPT.NEIGHBOR_OFFSETS:
                    if int(counts[habitat_id]) >= int(quotas[habitat_id]):
                        break
                    var neighbor: Vector2i = current + offset
                    if not traversable.has(neighbor) or ownership.has(neighbor):
                        continue
                    ownership[neighbor] = habitat_id
                    frontier.append(neighbor)
                    counts[habitat_id] = int(counts[habitat_id]) + 1
                    claimed_for_habitat = true
                    round_progress = true
            frontiers[habitat_id] = frontier
            cursors[habitat_id] = cursor
        if not round_progress:
            return {}

    for habitat_id: String in ALLIED_HABITAT_IDS:
        if int(counts[habitat_id]) != int(quotas[habitat_id]):
            return {}
    return ownership


func _is_better_fallback(candidate: Dictionary, current: Dictionary) -> bool:
    if current.is_empty():
        return true
    var current_town_result: Dictionary = current["town_result"]
    var candidate_adjacent: int = int(candidate["adjacent_pair_count"])
    var current_adjacent: int = int(current_town_result["adjacent_pair_count"])
    if candidate_adjacent != current_adjacent:
        return candidate_adjacent < current_adjacent
    return (
        int(candidate["total_pairwise_distance"])
        > int(current_town_result["total_pairwise_distance"])
    )


func _success(
    habitat_by_coord: Dictionary,
    anchors: Array[Vector2i],
    enemy_coord: Vector2i,
    towns: Array
) -> Dictionary:
    var habitats: Array = [
        {"habitat_id": "main", "role": "main", "anchor": anchors[0]},
        {"habitat_id": "ally_0", "role": "ally", "anchor": anchors[1]},
        {"habitat_id": "ally_1", "role": "ally", "anchor": anchors[2]},
        {"habitat_id": "enemy", "role": "enemy", "anchor": enemy_coord},
    ]
    return {
        "ok": true,
        "habitat_by_coord": habitat_by_coord,
        "habitats": habitats,
        "towns": towns,
        "error": null,
    }


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
