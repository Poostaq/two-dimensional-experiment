class_name WorldTownPlacementSolverV2
extends RefCounted

const VERSION := 2
const MIN_DISTANCE := 2
const TOWNS_PER_HABITAT := 3
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")

var _best_fallback: Dictionary = {}


func solve(
    seed_text: String,
    coords: Array[Vector2i],
    habitat_by_coord: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Dictionary:
    var candidates_by_habitat: Dictionary = _rank_eligible_candidates(
        seed_text,
        coords,
        habitat_by_coord,
        start_coord,
        enemy_coord
    )
    if not _has_capacity(candidates_by_habitat):
        return _failure()

    var selected: Array[Vector2i] = []
    var fully_spaced: Array[Vector2i] = _search_zero_adjacency(
        candidates_by_habitat,
        0,
        0,
        0,
        selected
    )
    if not fully_spaced.is_empty():
        return _success(fully_spaced, 0, true)

    _best_fallback = {}
    selected.clear()
    _search_fallback(candidates_by_habitat, 0, 0, 0, selected, 0, 0)
    if _best_fallback.is_empty():
        return _failure()
    return _success(
        _best_fallback["coords"],
        int(_best_fallback["adjacent_pair_count"]),
        false
    )


func _rank_eligible_candidates(
    seed_text: String,
    coords: Array[Vector2i],
    habitat_by_coord: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Dictionary:
    var result: Dictionary = {}
    for habitat_index: int in range(ALLIED_HABITAT_IDS.size()):
        var habitat_id: String = ALLIED_HABITAT_IDS[habitat_index]
        var candidates: Array[Vector2i] = []
        for coord: Vector2i in coords:
            if String(habitat_by_coord.get(coord, "")) != habitat_id:
                continue
            if GEOMETRY_SCRIPT.get_hex_distance(coord, start_coord) < MIN_DISTANCE:
                continue
            if GEOMETRY_SCRIPT.get_hex_distance(coord, enemy_coord) < MIN_DISTANCE:
                continue
            candidates.append(coord)
        result[habitat_id] = PRIORITY_SCRIPT.rank_coords(
            candidates,
            VERSION,
            seed_text,
            "habitat-town-v2",
            habitat_index
        )
    return result


func _has_capacity(candidates_by_habitat: Dictionary) -> bool:
    for habitat_id: String in ALLIED_HABITAT_IDS:
        if not candidates_by_habitat.has(habitat_id):
            return false
        if candidates_by_habitat[habitat_id].size() < TOWNS_PER_HABITAT:
            return false
    return true


func _search_zero_adjacency(
    candidates_by_habitat: Dictionary,
    habitat_index: int,
    candidate_start: int,
    selected_in_habitat: int,
    selected: Array[Vector2i]
) -> Array[Vector2i]:
    if habitat_index >= ALLIED_HABITAT_IDS.size():
        return selected.duplicate()
    if selected_in_habitat >= TOWNS_PER_HABITAT:
        return _search_zero_adjacency(candidates_by_habitat, habitat_index + 1, 0, 0, selected)

    var habitat_id: String = ALLIED_HABITAT_IDS[habitat_index]
    var candidates: Array[Vector2i] = candidates_by_habitat[habitat_id]
    var needed: int = TOWNS_PER_HABITAT - selected_in_habitat
    var final_start: int = candidates.size() - needed
    for candidate_index: int in range(candidate_start, final_start + 1):
        var candidate: Vector2i = candidates[candidate_index]
        if not _clears_selected(candidate, selected):
            continue
        selected.append(candidate)
        var result: Array[Vector2i] = _search_zero_adjacency(
            candidates_by_habitat,
            habitat_index,
            candidate_index + 1,
            selected_in_habitat + 1,
            selected
        )
        selected.pop_back()
        if not result.is_empty():
            return result
    return []


func _search_fallback(
    candidates_by_habitat: Dictionary,
    habitat_index: int,
    candidate_start: int,
    selected_in_habitat: int,
    selected: Array[Vector2i],
    adjacent_pair_count: int,
    total_pairwise_distance: int
) -> void:
    if habitat_index >= ALLIED_HABITAT_IDS.size():
        _consider_fallback(selected, adjacent_pair_count, total_pairwise_distance)
        return
    if selected_in_habitat >= TOWNS_PER_HABITAT:
        _search_fallback(
            candidates_by_habitat,
            habitat_index + 1,
            0,
            0,
            selected,
            adjacent_pair_count,
            total_pairwise_distance
        )
        return

    var habitat_id: String = ALLIED_HABITAT_IDS[habitat_index]
    var candidates: Array[Vector2i] = candidates_by_habitat[habitat_id]
    var needed: int = TOWNS_PER_HABITAT - selected_in_habitat
    var final_start: int = candidates.size() - needed
    for candidate_index: int in range(candidate_start, final_start + 1):
        var candidate: Vector2i = candidates[candidate_index]
        var contribution: Dictionary = _score_contribution(candidate, selected)
        var next_adjacent: int = adjacent_pair_count + int(contribution["adjacent_pair_count"])
        if (
            not _best_fallback.is_empty()
            and next_adjacent > int(_best_fallback["adjacent_pair_count"])
        ):
            continue
        selected.append(candidate)
        _search_fallback(
            candidates_by_habitat,
            habitat_index,
            candidate_index + 1,
            selected_in_habitat + 1,
            selected,
            next_adjacent,
            total_pairwise_distance + int(contribution["total_pairwise_distance"])
        )
        selected.pop_back()


func _clears_selected(candidate: Vector2i, selected: Array[Vector2i]) -> bool:
    for coord: Vector2i in selected:
        if GEOMETRY_SCRIPT.get_hex_distance(candidate, coord) < MIN_DISTANCE:
            return false
    return true


func _score_contribution(candidate: Vector2i, selected: Array[Vector2i]) -> Dictionary:
    var adjacent_pair_count: int = 0
    var total_pairwise_distance: int = 0
    for coord: Vector2i in selected:
        var distance: int = GEOMETRY_SCRIPT.get_hex_distance(candidate, coord)
        if distance < MIN_DISTANCE:
            adjacent_pair_count += 1
        total_pairwise_distance += distance
    return {
        "adjacent_pair_count": adjacent_pair_count,
        "total_pairwise_distance": total_pairwise_distance,
    }


func _consider_fallback(
    selected: Array[Vector2i],
    adjacent_pair_count: int,
    total_pairwise_distance: int
) -> void:
    if not _best_fallback.is_empty():
        var best_adjacent: int = int(_best_fallback["adjacent_pair_count"])
        var best_distance: int = int(_best_fallback["total_pairwise_distance"])
        if adjacent_pair_count > best_adjacent:
            return
        if adjacent_pair_count == best_adjacent and total_pairwise_distance <= best_distance:
            return
    _best_fallback = {
        "coords": selected.duplicate(),
        "adjacent_pair_count": adjacent_pair_count,
        "total_pairwise_distance": total_pairwise_distance,
    }


func _success(
    selected: Array[Vector2i],
    adjacent_pair_count: int,
    fully_spaced: bool
) -> Dictionary:
    var towns: Array = []
    var global_index: int = 0
    for habitat_id: String in ALLIED_HABITAT_IDS:
        for local_index: int in range(TOWNS_PER_HABITAT):
            towns.append({
                "town_id": "%s_town_%d" % [habitat_id, local_index],
                "habitat_id": habitat_id,
                "local_index": local_index,
                "coord": selected[global_index],
            })
            global_index += 1
    return {
        "ok": true,
        "towns": towns,
        "adjacent_pair_count": adjacent_pair_count,
        "total_pairwise_distance": _total_pairwise_distance(selected),
        "fully_spaced": fully_spaced,
    }


func _total_pairwise_distance(selected: Array[Vector2i]) -> int:
    var total: int = 0
    for first_index: int in range(selected.size()):
        for second_index: int in range(first_index + 1, selected.size()):
            total += GEOMETRY_SCRIPT.get_hex_distance(
                selected[first_index],
                selected[second_index]
            )
    return total


func _failure() -> Dictionary:
    return {
        "ok": false,
        "towns": [],
        "adjacent_pair_count": 0,
        "total_pairwise_distance": 0,
        "fully_spaced": false,
    }
