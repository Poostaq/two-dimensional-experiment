class_name GeneratorV1FixtureAuthor
extends SceneTree

const VERSION := 1
const DEFAULT_RADIUS := 8
const DEFAULT_TOWN_COUNT := 7
const DEFAULT_TOWN_DISTANCE := 4
const DEFAULT_FOREST_COUNT := 10
const START_COORD := Vector2i(-8, 0)
const BOSS_COORD := Vector2i(8, 0)

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var CODEC_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")


func _init() -> void:
    call_deferred("_run_cli")


static func build_plan(seed_text: String, overrides: Dictionary = {}) -> Dictionary:
    var radius: int = int(overrides.get("radius", DEFAULT_RADIUS))
    var town_count: int = int(overrides.get("town_count", DEFAULT_TOWN_COUNT))
    var town_distance: int = int(overrides.get("town_min_distance", DEFAULT_TOWN_DISTANCE))
    var start_coord: Vector2i = overrides.get("start", START_COORD)
    var boss_coord: Vector2i = overrides.get("boss", BOSS_COORD)
    var seed_hex: String = PRIORITY_SCRIPT.seed_hex(seed_text)
    var coords: Array[Vector2i] = GEOMETRY_SCRIPT.get_canonical_coords(radius)

    var protected: Dictionary = {start_coord: true, boss_coord: true}
    for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(start_coord, radius):
        protected[neighbor] = true
    for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(boss_coord, radius):
        protected[neighbor] = true

    var town_candidates: Array[Vector2i] = []
    for coord: Vector2i in coords:
        if not protected.has(coord):
            town_candidates.append(coord)
    town_candidates = PRIORITY_SCRIPT.rank_coords(town_candidates, VERSION, seed_text, "town")
    var towns: Array[Vector2i] = _solve_towns(town_candidates, town_count, town_distance)
    if towns.size() != town_count:
        return _constraint_failure(seed_hex, "town", "town_count=%d,min_distance=%d,radius=%d" % [town_count, town_distance, radius])
    towns.sort_custom(_coord_less)

    var roads: Array = _build_mst(towns)
    var forest_result: Dictionary = _solve_forests(seed_text, coords, towns, start_coord, boss_coord)
    if not forest_result.get("ok", false):
        return forest_result
    var forests: Array = forest_result["clusters"]

    var town_lookup: Dictionary = {}
    for town_index: int in range(towns.size()):
        town_lookup[towns[town_index]] = town_index
    var forest_lookup: Dictionary = {}
    for cluster: Array in forests:
        for coord: Vector2i in cluster:
            forest_lookup[coord] = true

    var cells: Dictionary = {}
    for coord: Vector2i in coords:
        var encounter_hash: int = PRIORITY_SCRIPT.fnv1a32_ascii(
            PRIORITY_SCRIPT.payload(VERSION, seed_text, "encounter", -1, coord)
        )
        var encounter := "safe" if encounter_hash % 100 < 40 else "combat"
        if coord == start_coord or town_lookup.has(coord):
            encounter = "safe"
        elif coord == boss_coord:
            encounter = "boss"
        cells[coord] = {
            "encounter": encounter,
            "terrain": "forest" if forest_lookup.has(coord) else "plain",
            "town_index": int(town_lookup.get(coord, -1)),
        }

    var plan: RefCounted = PLAN_SCRIPT.new(VERSION, seed_hex, start_coord, boss_coord, cells, roads, forests)
    if radius == DEFAULT_RADIUS and start_coord == START_COORD and boss_coord == BOSS_COORD:
        var validation: Variant = CODEC_SCRIPT.validate(plan)
        if validation != null:
            return {"ok": false, "plan": null, "error": validation}
    return {"ok": true, "plan": plan, "error": null}


static func _solve_towns(candidates: Array[Vector2i], target_count: int, min_distance: int) -> Array[Vector2i]:
    return _solve_towns_recursive(candidates, 0, [], target_count, min_distance)


static func _solve_towns_recursive(
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
        var solved: Array[Vector2i] = _solve_towns_recursive(candidates, index + 1, next_selected, target_count, min_distance)
        if solved.size() == target_count:
            return solved
    return []


static func _solve_forests(
    seed_text: String,
    coords: Array[Vector2i],
    towns: Array[Vector2i],
    start_coord: Vector2i,
    boss_coord: Vector2i
) -> Dictionary:
    var unavailable: Dictionary = {start_coord: true, boss_coord: true}
    for town: Vector2i in towns:
        unavailable[town] = true
    var result: Array = _solve_forest_index(seed_text, coords, unavailable, 0, [])
    if result.size() != DEFAULT_FOREST_COUNT:
        return _constraint_failure(PRIORITY_SCRIPT.seed_hex(seed_text), "forest", "cluster_count=10")
    return {"ok": true, "clusters": result, "error": null}


static func _solve_forest_index(
    seed_text: String,
    coords: Array[Vector2i],
    unavailable: Dictionary,
    cluster_index: int,
    selected_clusters: Array
) -> Array:
    if cluster_index == DEFAULT_FOREST_COUNT:
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
            next_clusters
        )
        if solved.size() == DEFAULT_FOREST_COUNT:
            return solved
    return []


static func _grow_first_cluster(
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
        for neighbor: Vector2i in GEOMETRY_SCRIPT.get_neighbors(selected_coord, DEFAULT_RADIUS):
            if valid_coords.has(neighbor) and not unavailable.has(neighbor) and neighbor not in selected:
                frontier_lookup[neighbor] = true
    var frontier: Array[Vector2i] = []
    for coord_value: Variant in frontier_lookup.keys():
        frontier.append(coord_value)
    frontier = PRIORITY_SCRIPT.rank_coords(frontier, VERSION, seed_text, "forest-frontier", cluster_index)
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


static func _build_mst(towns: Array[Vector2i]) -> Array:
    var candidates: Array = []
    for first: int in range(towns.size()):
        for second: int in range(first + 1, towns.size()):
            candidates.append({
                "a": towns[first],
                "b": towns[second],
                "distance": GEOMETRY_SCRIPT.get_hex_distance(towns[first], towns[second]),
                "a_index": first,
                "b_index": second,
            })
    candidates.sort_custom(
        func(a: Dictionary, b: Dictionary) -> bool:
            if a["distance"] != b["distance"]:
                return a["distance"] < b["distance"]
            if a["a"] != b["a"]:
                return _coord_less(a["a"], b["a"])
            return _coord_less(a["b"], b["b"])
    )
    var parent: Array[int] = []
    for index: int in range(towns.size()):
        parent.append(index)
    var roads: Array = []
    for edge_value: Variant in candidates:
        var edge: Dictionary = edge_value
        var a_root: int = _find_root(parent, edge["a_index"])
        var b_root: int = _find_root(parent, edge["b_index"])
        if a_root == b_root:
            continue
        parent[b_root] = a_root
        roads.append({"a": edge["a"], "b": edge["b"]})
        if roads.size() == towns.size() - 1:
            break
    return roads


static func _find_root(parent: Array[int], index: int) -> int:
    var current := index
    while parent[current] != current:
        current = parent[current]
    return current


static func _constraint_failure(seed_hex: String, feature_namespace: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "plan": null,
        "error": ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_CONSTRAINT_UNSATISFIABLE,
            seed_hex,
            VERSION,
            feature_namespace,
            constraint
        ),
    }


static func _coord_less(a: Vector2i, b: Vector2i) -> bool:
    return a.x < b.x or (a.x == b.x and a.y < b.y)


func _run_cli() -> void:
    var args := OS.get_cmdline_user_args()
    var output_dir := ""
    var verify_summaries := false
    var index := 0
    while index < args.size():
        match args[index]:
            "--output-dir":
                index += 1
                if index < args.size():
                    output_dir = args[index]
            "--verify-summaries":
                verify_summaries = true
        index += 1
    if output_dir.is_empty() or not output_dir.replace("\\", "/").ends_with("Tests/Fixtures/WorldMap/GeneratorV1"):
        push_error("Output path must end with Tests/Fixtures/WorldMap/GeneratorV1")
        quit(1)
        return
    var absolute_dir := output_dir
    if not output_dir.is_absolute_path():
        absolute_dir = ProjectSettings.globalize_path("res://" + output_dir.replace("\\", "/"))
    DirAccess.make_dir_recursive_absolute(absolute_dir)

    var fixtures: Array[Dictionary] = [
        {"file": "empty-seed.world", "seed": ""},
        {"file": "golden-alpha.world", "seed": "golden-alpha"},
        {"file": "golden-beta.world", "seed": "golden-beta"},
        {"file": "town-road-01.world", "seed": "town-road-01"},
        {"file": "unicode-lodz.world", "seed": "unicode-łódź"},
    ]
    var manifest_fixtures: Array = []
    for fixture: Dictionary in fixtures:
        var result: Dictionary = build_plan(fixture["seed"])
        if not result.get("ok", false):
            push_error("Failed to author fixture: %s" % fixture["file"])
            quit(1)
            return
        var plan: RefCounted = result["plan"]
        var bytes: PackedByteArray = CODEC_SCRIPT.serialize(plan)
        var file_path := absolute_dir.path_join(fixture["file"])
        var file := FileAccess.open(file_path, FileAccess.WRITE)
        file.store_buffer(bytes)
        file.close()
        var forest_sizes: Array[int] = []
        for cluster: Array in plan.get_forest_clusters():
            forest_sizes.append(cluster.size())
        manifest_fixtures.append({
            "artifact": fixture["file"],
            "seed_text": fixture["seed"],
            "seed_hex": plan.get_seed_hex(),
            "byte_length": bytes.size(),
            "sha256": _sha256(bytes),
            "cell_count": plan.get_cells().size(),
            "town_count": 7,
            "road_edge_count": plan.get_roads().size(),
            "cluster_count": plan.get_forest_clusters().size(),
            "forest_sizes": forest_sizes,
        })
    var manifest := {"generator_version": VERSION, "fixtures": manifest_fixtures}
    var manifest_file := FileAccess.open(absolute_dir.path_join("corpus_manifest.json"), FileAccess.WRITE)
    manifest_file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
    manifest_file.close()

    var impossible := {
        "radius": 2,
        "town_count": 7,
        "town_min_distance": 4,
        "start": [-2, 0],
        "boss": [2, 0],
        "expected_code": "WORLD_CONSTRAINT_UNSATISFIABLE",
        "expected_namespace": "town",
        "expected_published_cells": 0,
        "expected_save_mutation": false,
    }
    var impossible_file := FileAccess.open(absolute_dir.path_join("unsatisfiable-town-config.json"), FileAccess.WRITE)
    impossible_file.store_string(JSON.stringify(impossible, "\t", false) + "\n")
    impossible_file.close()
    if verify_summaries:
        print("Verified five Generator V1 fixture summaries")
    quit(0)


static func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()
