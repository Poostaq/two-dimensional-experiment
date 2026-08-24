extends SceneTree

const AUTHOR_PATH := "res://Tools/WorldMap/generator_v1_fixture_author.gd"

const CASES: Array[Dictionary] = [
    {
        "seed": "",
        "towns": [Vector2i(-6, 0), Vector2i(-6, 4), Vector2i(-6, 8), Vector2i(-1, -4), Vector2i(3, -5), Vector2i(3, -1), Vector2i(3, 4)],
        "forest_sizes": [3, 5, 7, 6, 5, 5, 5, 6, 7, 3],
    },
    {
        "seed": "golden-alpha",
        "towns": [Vector2i(-4, 0), Vector2i(-4, 4), Vector2i(1, 2), Vector2i(1, 6), Vector2i(2, -3), Vector2i(3, -8), Vector2i(8, -2)],
        "forest_sizes": [5, 6, 3, 7, 4, 6, 5, 7, 4, 5],
    },
    {
        "seed": "golden-beta",
        "towns": [Vector2i(-5, -1), Vector2i(1, -8), Vector2i(1, -2), Vector2i(1, 3), Vector2i(1, 7), Vector2i(7, -8), Vector2i(7, -4)],
        "forest_sizes": [3, 4, 4, 5, 6, 7, 5, 4, 4, 5],
    },
    {
        "seed": "town-road-01",
        "towns": [Vector2i(-6, 3), Vector2i(-6, 7), Vector2i(-3, -2), Vector2i(-3, 8), Vector2i(0, 2), Vector2i(6, -5), Vector2i(6, -1)],
        "forest_sizes": [7, 6, 5, 5, 5, 4, 7, 6, 7, 6],
    },
    {
        "seed": "unicode-łódź",
        "towns": [Vector2i(-8, 3), Vector2i(-8, 7), Vector2i(-5, -1), Vector2i(0, -8), Vector2i(1, 2), Vector2i(1, 6), Vector2i(6, 1)],
        "forest_sizes": [6, 6, 4, 7, 4, 5, 6, 5, 4, 6],
    },
]

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var author_script: GDScript = load(AUTHOR_PATH)
    if author_script == null:
        _fail("Generator V1 fixture author is missing")
        _finish()
        return

    for fixture_case: Dictionary in CASES:
        var result: Dictionary = author_script.build_plan(fixture_case["seed"])
        _assert_true(result.get("ok", false), "fixture plan succeeds: %s" % fixture_case["seed"])
        if not result.get("ok", false):
            continue
        var plan: RefCounted = result["plan"]
        _assert_equal(_towns_from_plan(plan), fixture_case["towns"], "town summary: %s" % fixture_case["seed"])
        var actual_sizes: Array[int] = []
        for cluster: Array in plan.get_forest_clusters():
            actual_sizes.append(cluster.size())
        _assert_equal(actual_sizes, fixture_case["forest_sizes"], "forest sizes: %s" % fixture_case["seed"])

    var impossible := {
        "radius": 2,
        "town_count": 7,
        "town_min_distance": 4,
        "start": Vector2i(-2, 0),
        "boss": Vector2i(2, 0),
    }
    var failed: Dictionary = author_script.build_plan("impossible", impossible)
    _assert_true(not failed.get("ok", true), "unsatisfiable config fails")
    if not failed.get("ok", true):
        _assert_equal(failed["error"].code, "WORLD_CONSTRAINT_UNSATISFIABLE", "constraint error code")
        _assert_equal(failed["error"].feature_namespace, "town", "constraint namespace")
        _assert_equal(failed.get("plan"), null, "no partial plan")
    _finish()


func _towns_from_plan(plan: RefCounted) -> Array[Vector2i]:
    var towns: Array[Vector2i] = []
    towns.resize(7)
    var cells: Dictionary = plan.get_cells()
    for coord_value: Variant in cells.keys():
        var coord: Vector2i = coord_value
        var town_index: int = int(cells[coord]["town_index"])
        if town_index >= 0:
            towns[town_index] = coord
    return towns


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
        print("PASS test_generator_v1_fixture_author")
    quit(1 if _failures > 0 else 0)
