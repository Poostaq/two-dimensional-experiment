extends SceneTree

const SOLVER_PATH := "res://Scripts/WorldMap/world_constraint_solver_v1.gd"
const GEOMETRY_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var solver_script: GDScript = load(SOLVER_PATH)
    var geometry_script: GDScript = load(GEOMETRY_PATH)
    if solver_script == null or geometry_script == null:
        _fail("WorldConstraintSolverV1 script is missing")
        _finish()
        return
    var solver: RefCounted = solver_script.new()
    var coords: Array[Vector2i] = geometry_script.get_canonical_coords(8)
    var town_result: Dictionary = solver.solve_towns("", coords, Vector2i(-8, 0), Vector2i(8, 0), 7, 4)
    _assert_true(town_result.get("ok", false), "town solve succeeds")
    var towns: Array[Vector2i] = town_result.get("towns", [])
    _assert_equal(towns, [Vector2i(-6, 0), Vector2i(-6, 4), Vector2i(-6, 8), Vector2i(-1, -4), Vector2i(3, -5), Vector2i(3, -1), Vector2i(3, 4)], "empty-seed towns")
    for first: int in range(towns.size()):
        for second: int in range(first + 1, towns.size()):
            _assert_true(geometry_script.get_hex_distance(towns[first], towns[second]) >= 4, "town spacing")

    var forest_result: Dictionary = solver.solve_forests("", coords, towns, Vector2i(-8, 0), Vector2i(8, 0), 10)
    _assert_true(forest_result.get("ok", false), "forest solve succeeds")
    var sizes: Array[int] = []
    var occupied: Dictionary = {}
    for cluster: Array in forest_result.get("clusters", []):
        sizes.append(cluster.size())
        for coord: Vector2i in cluster:
            _assert_true(not occupied.has(coord), "forest cells are disjoint")
            occupied[coord] = true
    _assert_equal(sizes, [3, 5, 7, 6, 5, 5, 5, 6, 7, 3], "empty-seed forest sizes")

    var impossible_coords: Array[Vector2i] = geometry_script.get_canonical_coords(2)
    var failed: Dictionary = solver.solve_towns("impossible", impossible_coords, Vector2i(-2, 0), Vector2i(2, 0), 7, 4)
    _assert_true(not failed.get("ok", true), "impossible towns fail")
    if not failed.get("ok", true):
        _assert_equal(failed["error"].code, "WORLD_CONSTRAINT_UNSATISFIABLE", "error code")
        _assert_equal(failed["error"].feature_namespace, "town", "error namespace")
    _finish()


func _assert_true(value: bool, label: String) -> void:
    if not value:
        _fail(label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_constraint_solver_v1")
    quit(1 if _failures > 0 else 0)
