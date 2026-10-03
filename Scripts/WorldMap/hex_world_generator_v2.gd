class_name HexWorldGeneratorV2
extends RefCounted

const VERSION := 2
const DEFAULT_RADIUS := 8
const DEFAULT_FOREST_COUNT := 10

static var GEOMETRY_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_geometry.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var PLAN_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var HABITAT_SOLVER_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_habitat_solver_v2.gd")
static var CONSTRAINT_SOLVER_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_constraint_solver_v1.gd")


func generate(seed_text: String, config: Dictionary = {}) -> Dictionary:
    var identity_context: Dictionary = _parse_identity_context(config)
    if identity_context.is_empty():
        return _internal_failure(seed_text, "identity_context_invalid")

    var radius_value: Variant = config.get("radius", DEFAULT_RADIUS)
    if not radius_value is int or int(radius_value) < 0:
        return _internal_failure(seed_text, "visual_extrema_invalid")
    var radius: int = radius_value
    var coords: Array[Vector2i] = GEOMETRY_SCRIPT.get_canonical_coords(radius)
    var extrema: Dictionary = GEOMETRY_SCRIPT.get_visual_extrema(coords)
    if not _valid_visual_extrema(extrema, coords):
        return _internal_failure(seed_text, "visual_extrema_invalid")
    var start_coord: Vector2i = extrema["east"]
    var enemy_coord: Vector2i = extrema["west"]

    var habitat_solver: RefCounted = HABITAT_SOLVER_SCRIPT.new()
    var topology: Dictionary = habitat_solver.solve(
        seed_text,
        coords,
        start_coord,
        enemy_coord
    )
    if not topology.get("ok", false):
        return {"ok": false, "plan": null, "error": topology.get("error")}

    var habitats: Array = _attach_clan_ids(topology["habitats"], identity_context)
    var towns: Array = topology["towns"].duplicate(true)
    var habitat_by_coord: Dictionary = topology["habitat_by_coord"].duplicate(true)
    var town_coords: Array[Vector2i] = []
    for town_value: Variant in towns:
        var town: Dictionary = town_value
        town_coords.append(town["coord"])

    var forest_count_value: Variant = config.get("forest_count", DEFAULT_FOREST_COUNT)
    if not forest_count_value is int or int(forest_count_value) < 0:
        return _internal_failure(seed_text, "identity_context_invalid")
    var forest_count: int = forest_count_value
    var constraint_solver: RefCounted = CONSTRAINT_SOLVER_SCRIPT.new()
    var forest_result: Dictionary = constraint_solver.solve_forests(
        seed_text,
        coords,
        town_coords,
        start_coord,
        enemy_coord,
        forest_count,
        VERSION
    )
    if not forest_result.get("ok", false):
        return {"ok": false, "plan": null, "error": forest_result.get("error")}
    var forests: Array = forest_result["clusters"]

    var town_lookup: Dictionary = {}
    for town_index: int in range(towns.size()):
        var town: Dictionary = towns[town_index]
        town_lookup[town["coord"]] = town_index
    var forest_lookup: Dictionary = {}
    for cluster_value: Variant in forests:
        var cluster: Array = cluster_value
        for coord_value: Variant in cluster:
            var coord: Vector2i = coord_value
            forest_lookup[coord] = true

    var cells: Dictionary = {}
    for coord: Vector2i in coords:
        var encounter_hash: int = PRIORITY_SCRIPT.fnv1a32_ascii(
            PRIORITY_SCRIPT.payload(VERSION, seed_text, "encounter", -1, coord)
        )
        var encounter := "safe" if encounter_hash % 100 < 40 else "combat"
        if coord == start_coord or town_lookup.has(coord):
            encounter = "safe"
        elif coord == enemy_coord:
            encounter = "boss"
        cells[coord] = {
            "encounter": encounter,
            "terrain": "forest" if forest_lookup.has(coord) else "plain",
            "town_index": int(town_lookup.get(coord, -1)),
            "habitat_id": String(habitat_by_coord.get(coord, "")),
        }

    var plan: RefCounted = PLAN_SCRIPT.new(
        VERSION,
        PRIORITY_SCRIPT.seed_hex(seed_text),
        start_coord,
        enemy_coord,
        cells,
        [],
        forests,
        habitats,
        towns
    )
    return {"ok": true, "plan": plan, "error": null}


func _parse_identity_context(config: Dictionary) -> Dictionary:
    if not config.has("main_clan_id") or not config.has("allied_clan_ids") or not config.has("enemy_clan_id"):
        return {}
    var main_value: Variant = config["main_clan_id"]
    var allies_value: Variant = config["allied_clan_ids"]
    var enemy_value: Variant = config["enemy_clan_id"]
    if not _is_string_value(main_value) or not allies_value is Array or not _is_string_value(enemy_value):
        return {}
    var allies: Array = allies_value
    if allies.size() != 2 or not _is_string_value(allies[0]) or not _is_string_value(allies[1]):
        return {}

    var main_id := String(main_value)
    var ally_0_id := String(allies[0])
    var ally_1_id := String(allies[1])
    var enemy_id := String(enemy_value)
    if not _is_valid_stable_id(main_id):
        return {}
    if not _is_valid_stable_id(ally_0_id) or not _is_valid_stable_id(ally_1_id):
        return {}
    if not _is_valid_stable_id(enemy_id):
        return {}
    if ally_0_id == ally_1_id or main_id == ally_0_id or main_id == ally_1_id:
        return {}
    if enemy_id == main_id or enemy_id == ally_0_id or enemy_id == ally_1_id:
        return {}
    return {
        "main": StringName(main_id),
        "ally_0": StringName(ally_0_id),
        "ally_1": StringName(ally_1_id),
        "enemy": StringName(enemy_id),
    }


func _attach_clan_ids(topology_habitats: Array, identity_context: Dictionary) -> Array:
    var habitats: Array = []
    for habitat_value: Variant in topology_habitats:
        var habitat: Dictionary = habitat_value.duplicate(true)
        var habitat_id := String(habitat.get("habitat_id", ""))
        habitat["clan_id"] = identity_context[habitat_id]
        habitats.append(habitat)
    return habitats


func _valid_visual_extrema(extrema: Dictionary, coords: Array[Vector2i]) -> bool:
    if extrema.size() != 2 or not extrema.has("west") or not extrema.has("east"):
        return false
    if not extrema["west"] is Vector2i or not extrema["east"] is Vector2i:
        return false
    var west: Vector2i = extrema["west"]
    var east: Vector2i = extrema["east"]
    if west == east or west not in coords or east not in coords:
        return false
    return GEOMETRY_SCRIPT.rendered_horizontal_key(west) < GEOMETRY_SCRIPT.rendered_horizontal_key(east)


func _is_string_value(value: Variant) -> bool:
    return value is String or value is StringName


func _is_valid_stable_id(value: String) -> bool:
    if value.is_empty():
        return false
    for byte: int in value.to_ascii_buffer():
        var is_lowercase: bool = byte >= 97 and byte <= 122
        var is_digit: bool = byte >= 48 and byte <= 57
        if not is_lowercase and not is_digit and byte != 95 and byte != 45:
            return false
    return true


func _internal_failure(seed_text: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "plan": null,
        "error": ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            PRIORITY_SCRIPT.seed_hex(seed_text),
            VERSION,
            "habitat",
            constraint
        ),
    }
