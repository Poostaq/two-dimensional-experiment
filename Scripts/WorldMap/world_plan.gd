class_name WorldPlan
extends RefCounted

var _version: int
var _seed_hex: String
var _start_coord: Vector2i
var _boss_coord: Vector2i
var _cells: Dictionary
var _roads: Array
var _forest_clusters: Array
var _habitats: Array
var _towns: Array


func _init(
    version: int,
    seed_hex: String,
    start_coord: Vector2i,
    boss_coord: Vector2i,
    cells: Dictionary,
    roads: Array,
    forest_clusters: Array,
    habitats: Array = [],
    towns: Array = []
) -> void:
    _version = version
    _seed_hex = seed_hex
    _start_coord = start_coord
    _boss_coord = boss_coord
    _cells = cells.duplicate(true)
    _roads = roads.duplicate(true)
    _forest_clusters = forest_clusters.duplicate(true)
    _habitats = habitats.duplicate(true)
    _towns = towns.duplicate(true)


func get_version() -> int:
    return _version


func get_seed_hex() -> String:
    return _seed_hex


func get_start_coord() -> Vector2i:
    return _start_coord


func get_boss_coord() -> Vector2i:
    return _boss_coord


func get_cells() -> Dictionary:
    return _cells.duplicate(true)


func get_roads() -> Array:
    return _roads.duplicate(true)


func get_forest_clusters() -> Array:
    return _forest_clusters.duplicate(true)


func get_habitats() -> Array:
    return _habitats.duplicate(true)


func get_towns() -> Array:
    return _towns.duplicate(true)


func get_habitat_cells(habitat_id: String) -> Array[Vector2i]:
    if habitat_id.is_empty():
        return []
    var coords: Array[Vector2i] = []
    for coord_value: Variant in _cells:
        if not coord_value is Vector2i:
            continue
        var coord: Vector2i = coord_value
        var cell_value: Variant = _cells[coord]
        if not cell_value is Dictionary:
            continue
        var cell: Dictionary = cell_value
        if String(cell.get("habitat_id", "")) == habitat_id:
            coords.append(coord)
    coords.sort_custom(
        func(a: Vector2i, b: Vector2i) -> bool:
            return a.x < b.x or (a.x == b.x and a.y < b.y)
    )
    return coords
