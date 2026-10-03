extends SceneTree

const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v2.gd"
const SOLVER_PATH := "res://Scripts/WorldMap/world_constraint_solver_v1.gd"
const GEOMETRY_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"
const PRIORITY_PATH := "res://Scripts/WorldMap/world_priority.gd"
const VERSION := 2
const DEFAULT_RADIUS := 8
const HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1", "enemy"]
const ALLIED_HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1"]

var _failures: int = 0
var _generator_script: GDScript
var _geometry_script: GDScript
var _priority_script: GDScript


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _generator_script = load(GENERATOR_PATH)
    _geometry_script = load(GEOMETRY_PATH)
    _priority_script = load(PRIORITY_PATH)
    if _generator_script == null or _geometry_script == null or _priority_script == null:
        _fail("V2 generator dependencies are missing")
        _finish()
        return
    _test_golden_topology()
    _test_ordered_anchor_pair_regression()
    _test_determinism()
    _test_playable_clan_corpus()
    _test_identity_failures()
    _test_visual_extrema_failure()
    _test_finite_search_failure()
    _test_forest_versioning()
    _finish()


func _test_golden_topology() -> void:
    var result: Dictionary = _generate("golden-ac9", _golden_config())
    _assert_true(result.get("ok", false), "golden generation succeeds")
    if not result.get("ok", false):
        return
    var plan: RefCounted = result["plan"]
    _assert_equal(plan.get_version(), VERSION, "golden version")
    _assert_equal(plan.get_cells().size(), 217, "golden cell count")
    _assert_equal(plan.get_start_coord(), Vector2i(8, 0), "player starts east")
    _assert_equal(plan.get_boss_coord(), Vector2i(-8, 0), "enemy starts west")
    var expected_enemy_footprint: Array[Vector2i] = _expected_enemy_footprint(
        DEFAULT_RADIUS,
        plan.get_boss_coord()
    )
    _assert_equal(expected_enemy_footprint, [
        Vector2i(-8, 0),
        Vector2i(-8, 1),
        Vector2i(-8, 2),
        Vector2i(-7, -1),
        Vector2i(-7, 0),
        Vector2i(-7, 1),
        Vector2i(-6, -2),
        Vector2i(-6, -1),
        Vector2i(-6, 0),
    ], "independent radius-eight enemy footprint")
    _assert_equal(
        plan.get_habitat_cells("enemy"),
        expected_enemy_footprint,
        "exact enemy footprint"
    )

    var habitats: Array = plan.get_habitats()
    _assert_equal(habitats.size(), 4, "four habitat records")
    var expected_roles: Array[String] = ["main", "ally", "ally", "enemy"]
    var expected_clans: Array[String] = ["goblin", "orc", "werewolf", "human"]
    var expected_anchors: Array[Vector2i] = [
        plan.get_start_coord(),
        habitats[1].get("anchor", Vector2i.ZERO) if habitats.size() > 1 else Vector2i.ZERO,
        habitats[2].get("anchor", Vector2i.ZERO) if habitats.size() > 2 else Vector2i.ZERO,
        plan.get_boss_coord(),
    ]
    if habitats.size() == 4:
        for index: int in range(HABITAT_IDS.size()):
            var habitat: Dictionary = habitats[index]
            _assert_equal(String(habitat.get("habitat_id", "")), HABITAT_IDS[index], "habitat id order %d" % index)
            _assert_equal(String(habitat.get("role", "")), expected_roles[index], "habitat role order %d" % index)
            _assert_equal(String(habitat.get("clan_id", "")), expected_clans[index], "habitat clan order %d" % index)
            _assert_equal(habitat.get("anchor"), expected_anchors[index], "habitat anchor %d" % index)
            var anchor: Vector2i = habitat.get("anchor", Vector2i.ZERO)
            _assert_equal(
                String(plan.get_cells()[anchor].get("habitat_id", "")),
                HABITAT_IDS[index],
                "anchor belongs to habitat %d" % index
            )

    _assert_complete_exclusive_connected_coverage(plan)
    _assert_town_contract(plan)
    _assert_encounter_and_forest_contract(plan)
    _assert_equal(plan.get_roads(), [], "V2 roads remain empty")


func _test_ordered_anchor_pair_regression() -> void:
    var seed_text := "synthetic-ordered-2"
    var start_coord := Vector2i(1, 0)
    var enemy_coord := Vector2i(-20, 0)
    var coords: Array[Vector2i] = [
        enemy_coord,
        Vector2i(-3, 2),
        Vector2i(-2, 0),
        Vector2i(-2, 1),
        Vector2i(-2, 2),
        Vector2i(-1, 1),
        Vector2i(0, 0),
        Vector2i(0, 1),
        start_coord,
        Vector2i(1, 1),
        Vector2i(2, 0),
    ]
    var expected: Array[Vector2i] = _expected_first_ordered_anchor_pair(
        seed_text,
        coords,
        start_coord,
        enemy_coord
    )
    _assert_equal(
        expected,
        [Vector2i(0, 1), Vector2i(-2, 0)],
        "test-local first feasible ordered anchor pair"
    )

    var habitat_solver_script: GDScript = load(
        "res://Scripts/WorldMap/world_habitat_solver_v2.gd"
    )
    var habitat_solver: RefCounted = habitat_solver_script.new()
    var result: Dictionary = habitat_solver.solve(
        seed_text,
        coords,
        start_coord,
        enemy_coord
    )
    _assert_true(result.get("ok", false), "ordered reverse pair solves synthetic subset")
    if not result.get("ok", false):
        return
    var habitats: Array = result["habitats"]
    var actual: Array[Vector2i] = [habitats[1]["anchor"], habitats[2]["anchor"]]
    _assert_equal(actual, expected, "solver uses first feasible ordered anchor pair")


func _test_determinism() -> void:
    var first: Dictionary = _generate("golden-ac9", _golden_config())
    var second: Dictionary = _generate("golden-ac9", _golden_config())
    _generate("interleaved-seed", {
        "main_clan_id": &"elf",
        "allied_clan_ids": [&"dwarf", &"harpy"],
        "enemy_clan_id": &"orc",
    })
    var third: Dictionary = _generate("golden-ac9", _golden_config())
    _assert_true(first.get("ok", false) and second.get("ok", false) and third.get("ok", false), "determinism inputs generate")
    if not first.get("ok", false) or not second.get("ok", false) or not third.get("ok", false):
        return
    var first_capture: String = _capture(first["plan"], DEFAULT_RADIUS)
    var second_capture: String = _capture(second["plan"], DEFAULT_RADIUS)
    var third_capture: String = _capture(third["plan"], DEFAULT_RADIUS)
    _assert_equal(second_capture, first_capture, "clean repeated capture")
    _assert_equal(third_capture, first_capture, "interleaved repeated capture")
    _assert_equal(_sha256(second_capture), _sha256(first_capture), "clean repeated hash")
    _assert_equal(_sha256(third_capture), _sha256(first_capture), "interleaved repeated hash")


func _test_playable_clan_corpus() -> void:
    var cases: Array[Dictionary] = [
        {"seed": "corpus-goblin", "main": &"goblin", "allies": [&"orc", &"werewolf"], "enemy": &"human"},
        {"seed": "corpus-orc", "main": &"orc", "allies": [&"goblin", &"dwarf"], "enemy": &"elf"},
        {"seed": "corpus-werewolf", "main": &"werewolf", "allies": [&"lizardmen", &"harpy"], "enemy": &"human"},
        {"seed": "corpus-human", "main": &"human", "allies": [&"elf", &"dwarf"], "enemy": &"goblin"},
        {"seed": "corpus-dwarf", "main": &"dwarf", "allies": [&"human", &"orc"], "enemy": &"werewolf"},
        {"seed": "corpus-elf", "main": &"elf", "allies": [&"harpy", &"lizardmen"], "enemy": &"orc"},
        {"seed": "corpus-harpy", "main": &"harpy", "allies": [&"werewolf", &"goblin"], "enemy": &"dwarf"},
        {"seed": "corpus-lizardmen", "main": &"lizardmen", "allies": [&"dwarf", &"elf"], "enemy": &"harpy"},
    ]
    for case: Dictionary in cases:
        var result: Dictionary = _generate(case["seed"], {
            "main_clan_id": case["main"],
            "allied_clan_ids": case["allies"],
            "enemy_clan_id": case["enemy"],
        })
        var label := String(case["main"])
        _assert_true(result.get("ok", false), "corpus generation %s" % label)
        if not result.get("ok", false):
            continue
        var plan: RefCounted = result["plan"]
        _assert_complete_exclusive_connected_coverage(plan)
        _assert_town_contract(plan)
        _assert_encounter_and_forest_contract(plan)


func _test_identity_failures() -> void:
    var invalid_configs: Array[Dictionary] = [
        {},
        {"main_clan_id": &"", "allied_clan_ids": [&"orc", &"werewolf"], "enemy_clan_id": &"human"},
        {"main_clan_id": &"Goblin", "allied_clan_ids": [&"orc", &"werewolf"], "enemy_clan_id": &"human"},
        {"main_clan_id": &"goblin", "allied_clan_ids": [&"orc"], "enemy_clan_id": &"human"},
        {"main_clan_id": &"goblin", "allied_clan_ids": [&"orc", &"orc"], "enemy_clan_id": &"human"},
        {"main_clan_id": &"goblin", "allied_clan_ids": [&"goblin", &"orc"], "enemy_clan_id": &"human"},
        {"main_clan_id": &"goblin", "allied_clan_ids": [&"orc", &"werewolf"], "enemy_clan_id": &"orc"},
        {"main_clan_id": 42, "allied_clan_ids": [&"orc", &"werewolf"], "enemy_clan_id": &"human"},
    ]
    for index: int in range(invalid_configs.size()):
        var result: Dictionary = _generate("invalid-%d" % index, invalid_configs[index])
        _assert_exact_failure(
            result,
            "invalid-%d" % index,
            "WORLD_GENERATION_INTERNAL_ERROR",
            "habitat",
            "identity_context_invalid",
            "identity failure %d" % index
        )


func _test_visual_extrema_failure() -> void:
    var config: Dictionary = _golden_config()
    config["radius"] = 0
    var result: Dictionary = _generate("invalid-extrema", config)
    _assert_exact_failure(
        result,
        "invalid-extrema",
        "WORLD_GENERATION_INTERNAL_ERROR",
        "habitat",
        "visual_extrema_invalid",
        "radius-zero visual extrema"
    )


func _test_finite_search_failure() -> void:
    var config: Dictionary = _golden_config()
    config["radius"] = 1
    var result: Dictionary = _generate("small-unsat", config)
    _assert_exact_failure(
        result,
        "small-unsat",
        "WORLD_CONSTRAINT_UNSATISFIABLE",
        "habitat",
        "connected_partition_with_town_capacity",
        "finite anchor search unsatisfiable"
    )


func _test_forest_versioning() -> void:
    var solver_script: GDScript = load(SOLVER_PATH)
    _assert_true(solver_script != null, "forest solver loads")
    if solver_script == null:
        return
    var solver: RefCounted = solver_script.new()
    var coords: Array[Vector2i] = _geometry_script.get_canonical_coords(DEFAULT_RADIUS)
    var excluded_towns: Array[Vector2i] = [
        Vector2i(-6, 0),
        Vector2i(-6, 4),
        Vector2i(-6, 8),
        Vector2i(-1, -4),
        Vector2i(3, -5),
        Vector2i(3, -1),
        Vector2i(3, 4),
    ]
    var v1: Dictionary = solver.solve_forests(
        "forest-version-evidence",
        coords,
        excluded_towns,
        Vector2i(-8, 0),
        Vector2i(8, 0),
        10
    )
    var v2: Dictionary = solver.solve_forests(
        "forest-version-evidence",
        coords,
        excluded_towns,
        Vector2i(-8, 0),
        Vector2i(8, 0),
        10,
        VERSION
    )
    _assert_true(v1.get("ok", false) and v2.get("ok", false), "both forest versions solve")
    if v1.get("ok", false) and v2.get("ok", false):
        _assert_true(v1["clusters"] != v2["clusters"], "V2 forest priority contract differs from V1")

    var tiny: Array[Vector2i] = _geometry_script.get_canonical_coords(1)
    var no_towns: Array[Vector2i] = []
    var failed: Dictionary = solver.solve_forests(
        "forest-v2-failure",
        tiny,
        no_towns,
        Vector2i(1, 0),
        Vector2i(-1, 0),
        10,
        VERSION
    )
    _assert_exact_error_record(
        failed,
        "forest-v2-failure",
        "WORLD_CONSTRAINT_UNSATISFIABLE",
        "forest",
        "cluster_count=10",
        "V2 forest failure"
    )


func _assert_complete_exclusive_connected_coverage(plan: RefCounted) -> void:
    var cells: Dictionary = plan.get_cells()
    var seen: Dictionary = {}
    for habitat_id: String in HABITAT_IDS:
        var members: Array[Vector2i] = plan.get_habitat_cells(habitat_id)
        _assert_true(not members.is_empty(), "%s habitat is nonempty" % habitat_id)
        _assert_true(_is_connected(members), "%s habitat is connected" % habitat_id)
        for coord: Vector2i in members:
            _assert_true(cells.has(coord), "%s member exists in cells" % habitat_id)
            _assert_true(not seen.has(coord), "exclusive habitat membership at %s" % coord)
            seen[coord] = habitat_id
            _assert_equal(String(cells[coord].get("habitat_id", "")), habitat_id, "cell habitat agrees at %s" % coord)
    _assert_equal(seen.size(), cells.size(), "all cells covered exactly once")
    _assert_equal(String(cells[plan.get_start_coord()].get("habitat_id", "")), "main", "player spawn in main")
    _assert_equal(String(cells[plan.get_boss_coord()].get("habitat_id", "")), "enemy", "enemy spawn in enemy")


func _assert_town_contract(plan: RefCounted) -> void:
    var towns: Array = plan.get_towns()
    var cells: Dictionary = plan.get_cells()
    _assert_equal(towns.size(), 9, "nine towns")
    var seen_coords: Dictionary = {}
    var seen_ids: Dictionary = {}
    var counts: Dictionary = {"main": 0, "ally_0": 0, "ally_1": 0, "enemy": 0}
    for global_index: int in range(towns.size()):
        var town: Dictionary = towns[global_index]
        var habitat_id := String(town.get("habitat_id", ""))
        var expected_habitat_id: String = ALLIED_HABITAT_IDS[global_index / 3]
        _assert_equal(habitat_id, expected_habitat_id, "town habitat order %d" % global_index)
        var local_index := int(town.get("local_index", -1))
        var coord: Vector2i = town.get("coord", Vector2i.ZERO)
        var expected_id := "%s_town_%d" % [habitat_id, local_index]
        _assert_equal(String(town.get("town_id", "")), expected_id, "stable town id %d" % global_index)
        _assert_true(ALLIED_HABITAT_IDS.has(habitat_id), "town belongs to allied habitat")
        _assert_equal(local_index, global_index % 3, "town local index %d" % global_index)
        _assert_true(not seen_coords.has(coord), "town coordinate unique")
        _assert_true(not seen_ids.has(expected_id), "town id unique")
        _assert_true(coord != plan.get_start_coord() and coord != plan.get_boss_coord(), "town excludes spawns")
        _assert_equal(String(cells[coord].get("habitat_id", "")), habitat_id, "town cell habitat agreement")
        _assert_equal(int(cells[coord].get("town_index", -1)), global_index, "town global index agreement")
        seen_coords[coord] = true
        seen_ids[expected_id] = true
        counts[habitat_id] = int(counts.get(habitat_id, 0)) + 1
    for habitat_id: String in ALLIED_HABITAT_IDS:
        _assert_equal(counts[habitat_id], 3, "%s has three towns" % habitat_id)
    _assert_equal(counts["enemy"], 0, "enemy has zero towns")


func _assert_encounter_and_forest_contract(plan: RefCounted) -> void:
    var cells: Dictionary = plan.get_cells()
    _assert_equal(String(cells[plan.get_start_coord()].get("encounter", "")), "safe", "start is safe")
    _assert_equal(String(cells[plan.get_boss_coord()].get("encounter", "")), "boss", "enemy spawn is boss")
    var forbidden: Dictionary = {plan.get_start_coord(): true, plan.get_boss_coord(): true}
    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        var coord: Vector2i = town["coord"]
        forbidden[coord] = true
        _assert_equal(String(cells[coord].get("encounter", "")), "safe", "town is safe")
    var clusters: Array = plan.get_forest_clusters()
    _assert_equal(clusters.size(), 10, "ten forest clusters")
    var occupied: Dictionary = {}
    for cluster_value: Variant in clusters:
        var cluster: Array = cluster_value
        var typed_cluster: Array[Vector2i] = []
        for coord_value: Variant in cluster:
            typed_cluster.append(coord_value)
        _assert_true(_is_connected(typed_cluster), "forest cluster connected")
        for coord: Vector2i in typed_cluster:
            _assert_true(not forbidden.has(coord), "forest excludes spawn and towns")
            _assert_true(not occupied.has(coord), "forest clusters disjoint")
            occupied[coord] = true
            _assert_equal(String(cells[coord].get("terrain", "")), "forest", "forest terrain agrees")


func _expected_first_ordered_anchor_pair(
    seed_text: String,
    coords: Array[Vector2i],
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> Array[Vector2i]:
    var allied_coords: Array[Vector2i] = []
    for coord: Vector2i in coords:
        if _geometry_script.get_hex_distance(coord, enemy_coord) > 2:
            allied_coords.append(coord)
    var candidates: Array[Vector2i] = []
    for coord: Vector2i in allied_coords:
        if coord != start_coord:
            candidates.append(coord)
    candidates = _priority_script.rank_coords(
        candidates,
        VERSION,
        seed_text,
        "habitat-anchor-v2"
    )
    for first_index: int in range(candidates.size()):
        for second_index: int in range(candidates.size()):
            if first_index == second_index:
                continue
            var anchors: Array[Vector2i] = [
                start_coord,
                candidates[first_index],
                candidates[second_index],
            ]
            var ownership: Dictionary = _test_partition(allied_coords, anchors)
            if (
                ownership.size() == allied_coords.size()
                and _test_has_town_capacity(ownership, start_coord, enemy_coord)
            ):
                return [anchors[1], anchors[2]]
    return []


func _test_partition(
    allied_coords: Array[Vector2i],
    anchors: Array[Vector2i]
) -> Dictionary:
    var traversable: Dictionary = {}
    for coord: Vector2i in allied_coords:
        traversable[coord] = true
    var ownership: Dictionary = {}
    var queue_coords: Array[Vector2i] = []
    var queue_habitat_ids: Array[String] = []
    for index: int in range(ALLIED_HABITAT_IDS.size()):
        ownership[anchors[index]] = ALLIED_HABITAT_IDS[index]
        queue_coords.append(anchors[index])
        queue_habitat_ids.append(ALLIED_HABITAT_IDS[index])
    var cursor: int = 0
    while cursor < queue_coords.size():
        var current: Vector2i = queue_coords[cursor]
        var habitat_id: String = queue_habitat_ids[cursor]
        cursor += 1
        for offset: Vector2i in _geometry_script.NEIGHBOR_OFFSETS:
            var neighbor: Vector2i = current + offset
            if not traversable.has(neighbor) or ownership.has(neighbor):
                continue
            ownership[neighbor] = habitat_id
            queue_coords.append(neighbor)
            queue_habitat_ids.append(habitat_id)
    return ownership


func _test_has_town_capacity(
    ownership: Dictionary,
    start_coord: Vector2i,
    enemy_coord: Vector2i
) -> bool:
    var counts: Dictionary = {"main": 0, "ally_0": 0, "ally_1": 0}
    for coord_value: Variant in ownership.keys():
        var coord: Vector2i = coord_value
        if coord == start_coord or coord == enemy_coord:
            continue
        var habitat_id: String = String(ownership[coord])
        counts[habitat_id] = int(counts.get(habitat_id, 0)) + 1
    for habitat_id: String in ALLIED_HABITAT_IDS:
        if int(counts[habitat_id]) < 3:
            return false
    return true


func _expected_enemy_footprint(radius: int, enemy_coord: Vector2i) -> Array[Vector2i]:
    var footprint: Array[Vector2i] = []
    for coord: Vector2i in _geometry_script.get_canonical_coords(radius):
        if _geometry_script.get_hex_distance(coord, enemy_coord) <= 2:
            footprint.append(coord)
    return footprint


func _is_connected(coords: Array[Vector2i]) -> bool:
    if coords.is_empty():
        return false
    var members: Dictionary = {}
    for coord: Vector2i in coords:
        members[coord] = true
    var visited: Dictionary = {coords[0]: true}
    var queue: Array[Vector2i] = [coords[0]]
    var cursor := 0
    while cursor < queue.size():
        var current: Vector2i = queue[cursor]
        cursor += 1
        for offset: Vector2i in _geometry_script.NEIGHBOR_OFFSETS:
            var neighbor := current + offset
            if members.has(neighbor) and not visited.has(neighbor):
                visited[neighbor] = true
                queue.append(neighbor)
    return visited.size() == coords.size()


func _capture(plan: RefCounted, radius: int) -> String:
    var lines: PackedStringArray = [
        "v=%d" % plan.get_version(),
        "seed=%s" % plan.get_seed_hex(),
        "start=%d,%d" % [plan.get_start_coord().x, plan.get_start_coord().y],
        "boss=%d,%d" % [plan.get_boss_coord().x, plan.get_boss_coord().y],
    ]
    for habitat_value: Variant in plan.get_habitats():
        var habitat: Dictionary = habitat_value
        var anchor: Vector2i = habitat["anchor"]
        lines.append("h=%s|%s|%s|%d,%d" % [
            String(habitat["habitat_id"]),
            String(habitat["role"]),
            String(habitat["clan_id"]),
            anchor.x,
            anchor.y,
        ])
    var cells: Dictionary = plan.get_cells()
    for coord: Vector2i in _geometry_script.get_canonical_coords(radius):
        var cell: Dictionary = cells[coord]
        lines.append("c=%d,%d|%s|%s|%d|%s" % [
            coord.x,
            coord.y,
            String(cell["encounter"]),
            String(cell["terrain"]),
            int(cell["town_index"]),
            String(cell["habitat_id"]),
        ])
    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        var coord: Vector2i = town["coord"]
        lines.append("t=%s|%s|%d|%d,%d" % [
            String(town["town_id"]),
            String(town["habitat_id"]),
            int(town["local_index"]),
            coord.x,
            coord.y,
        ])
    for cluster_index: int in range(plan.get_forest_clusters().size()):
        var cluster: Array = plan.get_forest_clusters()[cluster_index]
        for coord_value: Variant in cluster:
            var coord: Vector2i = coord_value
            lines.append("f=%d|%d,%d" % [cluster_index, coord.x, coord.y])
    return "\n".join(lines)


func _sha256(value: String) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(value.to_utf8_buffer())
    return context.finish().hex_encode()


func _golden_config() -> Dictionary:
    return {
        "main_clan_id": &"goblin",
        "allied_clan_ids": [&"orc", &"werewolf"],
        "enemy_clan_id": &"human",
    }


func _generate(seed_text: String, config: Dictionary) -> Dictionary:
    var generator: RefCounted = _generator_script.new()
    return generator.generate(seed_text, config)


func _assert_exact_failure(
    result: Dictionary,
    seed_text: String,
    code: String,
    feature_namespace: String,
    constraint: String,
    label: String
) -> void:
    _assert_true(not result.get("ok", true), "%s rejects input" % label)
    _assert_equal(result.get("plan"), null, "%s publishes no plan" % label)
    _assert_exact_error_record(result, seed_text, code, feature_namespace, constraint, label)


func _assert_exact_error_record(
    result: Dictionary,
    seed_text: String,
    code: String,
    feature_namespace: String,
    constraint: String,
    label: String
) -> void:
    var error: Variant = result.get("error")
    _assert_true(error != null, "%s returns typed error" % label)
    if error == null:
        return
    _assert_equal(error.code, code, "%s code" % label)
    _assert_equal(error.seed_hex, _priority_script.seed_hex(seed_text), "%s seed hex" % label)
    _assert_equal(error.generator_version, VERSION, "%s generator version" % label)
    _assert_equal(error.feature_namespace, feature_namespace, "%s namespace" % label)
    _assert_equal(error.failed_constraint, constraint, "%s constraint" % label)


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
        print("PASS test_ac9_habitats_and_towns")
    quit(1 if _failures > 0 else 0)
