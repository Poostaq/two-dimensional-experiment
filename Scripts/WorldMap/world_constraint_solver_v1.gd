class_name WorldConstraintSolverV1
extends RefCounted

const VERSION := 1

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")


func solve_towns(
    seed_text: String,
    coords: Array[Vector2i],
    start_coord: Vector2i,
    boss_coord: Vector2i,
    target_count: int = 7,
    min_distance: int = 4
) -> Dictionary:
    var radius: int = _radius_for(coords)
    var protected: Dictionary = {start_coord: true, boss_coord: true}
    for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(start_coord, radius):
        protected[neighbor] = true
    for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(boss_coord, radius):
        protected[neighbor] = true
    var candidates: Array[Vector2i] = []
    for coord: Vector2i in coords:
        if not protected.has(coord):
            candidates.append(coord)
    candidates = PRIORITY_SCRIPT.rank_coords(candidates, VERSION, seed_text, "town")
    var towns: Array[Vector2i] = _solve_towns_recursive(candidates, 0, [], target_count, min_distance)
    if towns.size() != target_count:
        return _failure(
            seed_text,
            "town",
            "town_count=%d,min_distance=%d,radius=%d" % [target_count, min_distance, radius]
        )
    towns.sort_custom(_coord_less)
    return {"ok": true, "towns": towns, "error": null}


func solve_forests(
    seed_text: String,
    coords: Array[Vector2i],
    towns: Array[Vector2i],
    start_coord: Vector2i,
    boss_coord: Vector2i,
    cluster_count: int = 10
) -> Dictionary:
    var unavailable: Dictionary = {start_coord: true, boss_coord: true}
    for town: Vector2i in towns:
        unavailable[town] = true
    var clusters: Array = _solve_forest_index(
        seed_text,
        coords,
        unavailable,
        0,
        cluster_count,
        []
    )
    if clusters.size() != cluster_count:
        return _failure(seed_text, "forest", "cluster_count=%d" % cluster_count)
    return {"ok": true, "clusters": clusters, "error": null}


func _solve_towns_recursive(
    candidates: Array[Vector2i],
    candidate_index: int,
    selected: Array[Vector2i],
    target_count: int,
    min_distance: int
) -> Array[Vector2i]:
    if selected.size() == target_count:
        return selected
    if candidates.size() - candidate_index < target_count - selected.size():
        return []
    for index: int in range(candidate_index, candidates.size()):
        var candidate: Vector2i = candidates[index]
        var valid: bool = true
        for town: Vector2i in selected:
            if GEOMETRY_SCRIPT.get_hex_distance(candidate, town) < min_distance:
                valid = false
                break
        if not valid:
            continue
        var next_selected: Array[Vector2i] = selected.duplicate()
        next_selected.append(candidate)
        var solved: Array[Vector2i] = _solve_towns_recursive(
            candidates,
            index + 1,
            next_selected,
            target_count,
            min_distance
        )
        if solved.size() == target_count:
            return solved
    return []


func _solve_forest_index(
    seed_text: String,
    coords: Array[Vector2i],
    unavailable: Dictionary,
    cluster_index: int,
    cluster_count: int,
    selected_clusters: Array
) -> Array:
    if cluster_index == cluster_count:
        return selected_clusters
    var size_hash: int = PRIORITY_SCRIPT.fnv1a32_ascii(
        PRIORITY_SCRIPT.payload(VERSION, seed_text, "forest-size", cluster_index, Vector2i.ZERO)
    )
    var target_size: int = 3 + size_hash % 5
    var available: Array[Vector2i] = []
    for coord: Vector2i in coords:
        if not unavailable.has(coord):
            available.append(coord)
    var roots: Array[Vector2i] = PRIORITY_SCRIPT.rank_coords(
        available,
        VERSION,
        seed_text,
        "forest-frontier",
        cluster_index
    )
    for root: Vector2i in roots:
        var cluster: Array[Vector2i] = _grow_first_cluster(
            seed_text,
            cluster_index,
            target_size,
            [root],
            unavailable,
            coords
        )
        if cluster.size() != target_size:
            continue
        var next_unavailable: Dictionary = unavailable.duplicate()
        for coord: Vector2i in cluster:
            next_unavailable[coord] = true
        var next_clusters: Array = selected_clusters.duplicate(true)
        next_clusters.append(cluster)
        var solved: Array = _solve_forest_index(
            seed_text,
            coords,
            next_unavailable,
            cluster_index + 1,
            cluster_count,
            next_clusters
        )
        if solved.size() == cluster_count:
            return solved
    return []


func _grow_first_cluster(
    seed_text: String,
    cluster_index: int,
    target_size: int,
    selected: Array[Vector2i],
    unavailable: Dictionary,
    coords: Array[Vector2i]
) -> Array[Vector2i]:
    if selected.size() == target_size:
        return selected
    var valid_coords: Dictionary = {}
    for coord: Vector2i in coords:
        valid_coords[coord] = true
    var frontier_lookup: Dictionary = {}
    for selected_coord: Vector2i in selected:
        for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(selected_coord, _radius_for(coords)):
            if valid_coords.has(neighbor) and not unavailable.has(neighbor) and neighbor not in selected:
                frontier_lookup[neighbor] = true
    var frontier: Array[Vector2i] = []
    for coord_value: Variant in frontier_lookup.keys():
        frontier.append(coord_value)
    frontier = PRIORITY_SCRIPT.rank_coords(
        frontier,
        VERSION,
        seed_text,
        "forest-frontier",
        cluster_index
    )
    for candidate: Vector2i in frontier:
        var next_selected: Array[Vector2i] = selected.duplicate()
        next_selected.append(candidate)
        var solved: Array[Vector2i] = _grow_first_cluster(
            seed_text,
            cluster_index,
            target_size,
            next_selected,
            unavailable,
            coords
        )
        if solved.size() == target_size:
            return solved
    return []


func _failure(seed_text: String, feature_namespace: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "towns": [],
        "clusters": [],
        "error": ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_CONSTRAINT_UNSATISFIABLE,
            PRIORITY_SCRIPT.seed_hex(seed_text),
            VERSION,
            feature_namespace,
            constraint
        ),
    }


func _radius_for(coords: Array[Vector2i]) -> int:
    var radius := 0
    for coord: Vector2i in coords:
        radius = maxi(radius, GEOMETRY_SCRIPT.get_hex_distance(Vector2i.ZERO, coord))
    return radius


func _coord_less(a: Vector2i, b: Vector2i) -> bool:
    return a.x < b.x or (a.x == b.x and a.y < b.y)
