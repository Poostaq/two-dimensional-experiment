class_name WorldPlan
extends RefCounted

var _version: int
var _seed_hex: String
var _start_coord: Vector2i
var _boss_coord: Vector2i
var _cells: Dictionary
var _roads: Array
var _forest_clusters: Array


func _init(
    version: int,
    seed_hex: String,
    start_coord: Vector2i,
    boss_coord: Vector2i,
    cells: Dictionary,
    roads: Array,
    forest_clusters: Array
) -> void:
    _version = version
    _seed_hex = seed_hex
    _start_coord = start_coord
    _boss_coord = boss_coord
    _cells = cells.duplicate(true)
    _roads = roads.duplicate(true)
    _forest_clusters = forest_clusters.duplicate(true)


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
