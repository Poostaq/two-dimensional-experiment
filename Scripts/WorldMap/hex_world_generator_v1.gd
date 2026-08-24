class_name HexWorldGeneratorV1
extends RefCounted

const VERSION := 1
const DEFAULT_RADIUS := 8
const START_COORD := Vector2i(-8, 0)
const BOSS_COORD := Vector2i(8, 0)

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var CODEC_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
static var SOLVER_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_constraint_solver_v1.gd")


func generate(seed_text: String, config: Dictionary = {}) -> Dictionary:
    var radius: int = int(config.get("radius", DEFAULT_RADIUS))
    var town_count: int = int(config.get("town_count", 7))
    var town_distance: int = int(config.get("town_min_distance", 4))
    var forest_count: int = int(config.get("forest_count", 10))
    var start_coord: Vector2i = config.get("start", START_COORD)
    var boss_coord: Vector2i = config.get("boss", BOSS_COORD)
    var coords: Array[Vector2i] = GEOMETRY_SCRIPT.get_canonical_coords(radius)
    var solver: RefCounted = SOLVER_SCRIPT.new()

    var town_result: Dictionary = solver.solve_towns(
        seed_text,
        coords,
        start_coord,
        boss_coord,
        town_count,
        town_distance
    )
    if not town_result.get("ok", false):
        return {"ok": false, "plan": null, "error": town_result["error"]}
    var towns: Array[Vector2i] = town_result["towns"]

    var roads: Array = _build_mst(towns)
    var forest_result: Dictionary = solver.solve_forests(
        seed_text,
        coords,
        towns,
        start_coord,
        boss_coord,
        forest_count
    )
    if not forest_result.get("ok", false):
        return {"ok": false, "plan": null, "error": forest_result["error"]}
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

    var plan: RefCounted = PLAN_SCRIPT.new(
        VERSION,
        PRIORITY_SCRIPT.seed_hex(seed_text),
        start_coord,
        boss_coord,
        cells,
        roads,
        forests
    )
    if radius == DEFAULT_RADIUS and start_coord == START_COORD and boss_coord == BOSS_COORD:
        var validation: Variant = CODEC_SCRIPT.validate(plan)
        if validation != null:
            return {"ok": false, "plan": null, "error": validation}
    return {"ok": true, "plan": plan, "error": null}


func _build_mst(towns: Array[Vector2i]) -> Array:
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


func _find_root(parent: Array[int], index: int) -> int:
    var current := index
    while parent[current] != current:
        current = parent[current]
    return current


func _coord_less(a: Vector2i, b: Vector2i) -> bool:
    return a.x < b.x or (a.x == b.x and a.y < b.y)
