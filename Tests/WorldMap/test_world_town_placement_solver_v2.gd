extends SceneTree

const SOLVER_PATH := "res://Scripts/WorldMap/world_town_placement_solver_v2.gd"
const GEOMETRY_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"

var _failures: int = 0
var _solver_script: GDScript
var _geometry_script: GDScript


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(SOLVER_PATH):
        _fail("town placement solver resource exists")
        _finish()
        return
    _solver_script = load(SOLVER_PATH)
    _geometry_script = load(GEOMETRY_PATH)
    _expect(_solver_script != null, "town placement solver loads")
    _expect(_geometry_script != null, "hex geometry loads")
    if _solver_script == null or _geometry_script == null:
        _finish()
        return
    _test_fully_spaced_layout()
    _test_deterministic_fallback()
    _test_spawn_clearance_can_remove_capacity()
    _finish()


func _test_fully_spaced_layout() -> void:
    var candidates: Dictionary = {
        "main": [Vector2i(-6, 0), Vector2i(-4, 0), Vector2i(-2, 0)],
        "ally_0": [Vector2i(0, -6), Vector2i(0, -4), Vector2i(0, -2)],
        "ally_1": [Vector2i(2, -2), Vector2i(4, -2), Vector2i(6, -2)],
    }
    var result: Dictionary = _solve(
        "town-solver-feasible",
        candidates,
        Vector2i(-8, 0),
        Vector2i(8, 0)
    )
    _expect(result.get("ok", false), "feasible layout succeeds")
    if not result.get("ok", false):
        return
    _expect_equal(result["towns"].size(), 9, "feasible layout has nine towns")
    _expect_equal(result["adjacent_pair_count"], 0, "feasible layout has no adjacent pairs")
    _expect(result["fully_spaced"], "feasible layout reports full spacing")
    for town_value: Variant in result["towns"]:
        var town: Dictionary = town_value
        _expect(
            _geometry_script.get_hex_distance(town["coord"], Vector2i(-8, 0)) >= 2,
            "feasible town clears player start"
        )
        _expect(
            _geometry_script.get_hex_distance(town["coord"], Vector2i(8, 0)) >= 2,
            "feasible town clears enemy start"
        )


func _test_deterministic_fallback() -> void:
    var candidates: Dictionary = {
        "main": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
        "ally_0": [Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0)],
        "ally_1": [Vector2i(20, 0), Vector2i(21, 0), Vector2i(22, 0)],
    }
    var first: Dictionary = _solve(
        "town-solver-fallback",
        candidates,
        Vector2i(-20, -20),
        Vector2i(40, 20)
    )
    var second: Dictionary = _solve(
        "town-solver-fallback",
        candidates,
        Vector2i(-20, -20),
        Vector2i(40, 20)
    )
    _expect(first.get("ok", false), "fallback layout succeeds")
    if not first.get("ok", false):
        return
    _expect(not first["fully_spaced"], "fallback layout reports unavoidable adjacency")
    _expect_equal(first["adjacent_pair_count"], 6, "fallback counts all adjacent pairs")
    _expect_equal(first["total_pairwise_distance"], 372, "fallback reports exact distance score")
    _expect_equal(first, second, "fallback selection is deterministic")


func _test_spawn_clearance_can_remove_capacity() -> void:
    var candidates: Dictionary = {
        "main": [Vector2i(-8, 0), Vector2i(-7, 0), Vector2i(-6, 0)],
        "ally_0": [Vector2i(0, -6), Vector2i(0, -4), Vector2i(0, -2)],
        "ally_1": [Vector2i(2, -2), Vector2i(4, -2), Vector2i(6, -2)],
    }
    var result: Dictionary = _solve(
        "town-solver-capacity",
        candidates,
        Vector2i(-8, 0),
        Vector2i(8, 0)
    )
    _expect(not result.get("ok", true), "spawn-filtered capacity is rejected")
    _expect_equal(result.get("towns", []), [], "failed capacity publishes no towns")


func _solve(
    seed_text: String,
    candidates_by_habitat: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Dictionary:
    var coords: Array[Vector2i] = []
    var habitat_by_coord: Dictionary = {}
    for habitat_id: String in ["main", "ally_0", "ally_1"]:
        for coord_value: Variant in candidates_by_habitat[habitat_id]:
            var coord: Vector2i = coord_value
            coords.append(coord)
            habitat_by_coord[coord] = habitat_id
    return _solver_script.new().solve(
        seed_text,
        coords,
        habitat_by_coord,
        start_coord,
        enemy_coord
    )


func _expect(value: bool, label: String) -> void:
    if not value:
        _fail(label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_town_placement_solver_v2")
    quit(1 if _failures > 0 else 0)
