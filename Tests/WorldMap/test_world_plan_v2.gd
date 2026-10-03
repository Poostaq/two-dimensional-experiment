extends SceneTree

const PLAN_PATH := "res://Scripts/WorldMap/world_plan.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var plan_script: GDScript = load(PLAN_PATH)
    if plan_script == null:
        _fail("WorldPlan script is missing")
        _finish()
        return

    _test_v2_collections_are_immutable(plan_script)
    _test_v1_constructor_defaults(plan_script)
    _finish()


func _test_v2_collections_are_immutable(plan_script: GDScript) -> void:
    var enemy_coords: Array[Vector2i] = [
        Vector2i(2, -1),
        Vector2i(-1, 2),
        Vector2i(0, 0),
        Vector2i(-2, 2),
        Vector2i(1, 0),
        Vector2i(-1, 0),
        Vector2i(0, 1),
        Vector2i(-2, 1),
        Vector2i(1, -1),
    ]
    var expected_enemy_coords: Array[Vector2i] = [
        Vector2i(-2, 1),
        Vector2i(-2, 2),
        Vector2i(-1, 0),
        Vector2i(-1, 2),
        Vector2i(0, 0),
        Vector2i(0, 1),
        Vector2i(1, -1),
        Vector2i(1, 0),
        Vector2i(2, -1),
    ]
    var cells: Dictionary = {}
    for coord: Vector2i in enemy_coords:
        cells[coord] = {
            "habitat_id": "enemy",
            "details": {"flags": ["hostile"]},
        }
    cells[Vector2i(3, -2)] = {
        "habitat_id": "allied",
        "details": {"flags": ["friendly"]},
    }
    var roads: Array = [
        {
            "a": Vector2i(-2, 1),
            "b": Vector2i(-1, 0),
            "metadata": {"tags": ["primary"]},
        },
    ]
    var forest_clusters: Array = [
        [Vector2i(-2, 1), Vector2i(-1, 0)],
    ]
    var habitats: Array = [
        {
            "id": "enemy",
            "cells": [Vector2i(99, 99)],
            "metadata": {"tags": ["hostile"]},
        },
        {"id": "allied", "metadata": {"tags": ["friendly"]}},
        {"id": "neutral", "metadata": {"tags": ["open"]}},
        {"id": "boss", "metadata": {"tags": ["terminal"]}},
    ]
    var towns: Array = []
    for index: int in range(9):
        towns.append({
            "id": "town_%d" % index,
            "coord": Vector2i(index - 4, 0),
            "services": {"names": ["recruit"]},
        })

    var expected_cells: Dictionary = cells.duplicate(true)
    var expected_roads: Array = roads.duplicate(true)
    var expected_forests: Array = forest_clusters.duplicate(true)
    var expected_habitats: Array = habitats.duplicate(true)
    var expected_towns: Array = towns.duplicate(true)
    var plan: RefCounted = plan_script.new(
        2,
        "76322d746f706f6c6f6779",
        Vector2i(-8, 0),
        Vector2i(8, 0),
        cells,
        roads,
        forest_clusters,
        habitats,
        towns
    )

    _assert_equal(plan.get_version(), 2, "V2 version")
    _assert_equal(plan.get_seed_hex(), "76322d746f706f6c6f6779", "V2 seed")
    _assert_equal(plan.get_start_coord(), Vector2i(-8, 0), "V2 start")
    _assert_equal(plan.get_boss_coord(), Vector2i(8, 0), "V2 boss")
    _assert_equal(plan.get_habitats().size(), 4, "four immutable habitats")
    _assert_equal(plan.get_towns().size(), 9, "nine immutable towns")
    _assert_equal(
        plan.get_habitat_cells("enemy"),
        expected_enemy_coords,
        "enemy habitat cells derive from authoritative cell records in q/r order"
    )
    _assert_equal(plan.get_habitat_cells("missing"), [], "unknown habitat has no cells")

    cells[enemy_coords[0]]["details"]["flags"].append("mutated input")
    cells.clear()
    roads[0]["metadata"]["tags"].append("mutated input")
    roads.clear()
    forest_clusters[0].append(Vector2i(7, -7))
    forest_clusters.clear()
    habitats[0]["metadata"]["tags"].append("mutated input")
    habitats[0]["cells"].append(Vector2i(-99, -99))
    habitats.clear()
    towns[0]["services"]["names"].append("mutated input")
    towns.clear()
    _assert_plan_collections(
        plan,
        expected_cells,
        expected_roads,
        expected_forests,
        expected_habitats,
        expected_towns,
        "original input mutation"
    )

    var returned_cells: Dictionary = plan.get_cells()
    returned_cells[enemy_coords[0]]["details"]["flags"].append("mutated return")
    returned_cells.clear()
    var returned_roads: Array = plan.get_roads()
    returned_roads[0]["metadata"]["tags"].append("mutated return")
    returned_roads.clear()
    var returned_forests: Array = plan.get_forest_clusters()
    returned_forests[0].append(Vector2i(6, -6))
    returned_forests.clear()
    var returned_habitats: Array = plan.get_habitats()
    returned_habitats[0]["metadata"]["tags"].append("mutated return")
    returned_habitats[0]["cells"].append(Vector2i(-98, -98))
    returned_habitats.clear()
    var returned_towns: Array = plan.get_towns()
    returned_towns[0]["services"]["names"].append("mutated return")
    returned_towns.clear()
    var returned_habitat_cells: Array[Vector2i] = plan.get_habitat_cells("enemy")
    returned_habitat_cells[0] = Vector2i(88, 88)
    returned_habitat_cells.clear()
    _assert_plan_collections(
        plan,
        expected_cells,
        expected_roads,
        expected_forests,
        expected_habitats,
        expected_towns,
        "accessor return mutation"
    )
    _assert_equal(
        plan.get_habitat_cells("enemy"),
        expected_enemy_coords,
        "derived habitat cells are a defensive copy"
    )
    _assert_equal(plan.get_version(), 2, "scalar accessors remain unchanged")
    _assert_equal(plan.get_seed_hex(), "76322d746f706f6c6f6779", "seed remains unchanged")
    _assert_equal(plan.get_start_coord(), Vector2i(-8, 0), "start remains unchanged")
    _assert_equal(plan.get_boss_coord(), Vector2i(8, 0), "boss remains unchanged")


func _test_v1_constructor_defaults(plan_script: GDScript) -> void:
    var cells := {Vector2i.ZERO: {"encounter": "safe"}}
    var plan: RefCounted = plan_script.new(
        1,
        "76312d636f6d706174",
        Vector2i.ZERO,
        Vector2i(1, 0),
        cells,
        [],
        []
    )
    _assert_equal(plan.get_habitats(), [], "V1 habitats default empty")
    _assert_equal(plan.get_towns(), [], "V1 towns default empty")
    _assert_equal(plan.get_habitat_cells(""), [], "empty habitat ID has no cells")
    _assert_equal(plan.get_habitat_cells("enemy"), [], "V1 has no habitat cells")


func _assert_plan_collections(
    plan: RefCounted,
    expected_cells: Dictionary,
    expected_roads: Array,
    expected_forests: Array,
    expected_habitats: Array,
    expected_towns: Array,
    label: String
) -> void:
    _assert_equal(plan.get_cells(), expected_cells, "%s cells" % label)
    _assert_equal(plan.get_roads(), expected_roads, "%s roads" % label)
    _assert_equal(plan.get_forest_clusters(), expected_forests, "%s forests" % label)
    _assert_equal(plan.get_habitats(), expected_habitats, "%s habitats" % label)
    _assert_equal(plan.get_towns(), expected_towns, "%s towns" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_plan_v2")
    quit(1 if _failures > 0 else 0)
