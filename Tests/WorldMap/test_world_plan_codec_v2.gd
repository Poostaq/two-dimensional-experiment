extends SceneTree

const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v2.gd"
const PLAN_PATH := "res://Scripts/WorldMap/world_plan.gd"
const CODEC_V2_PATH := "res://Scripts/WorldMap/world_plan_codec_v2.gd"
const CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec.gd"
const CODEC_V1_PATH := "res://Scripts/WorldMap/world_plan_codec_v1.gd"
const GEOMETRY_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"
const FIXTURE_PATH := "res://Tests/Fixtures/WorldMap/GeneratorV2/golden-ac9.world"
const V1_FIXTURE_DIR := "res://Tests/Fixtures/WorldMap/GeneratorV1"
const EXPECTED_GOLDEN_SHA256 := "6e11941a374cb6cc0e6bc5e9ba07b9943454a0b7ff117ab5e2b4d58793da75ec"

var _failures: int = 0
var _generator_script: GDScript
var _plan_script: GDScript
var _codec_v2_script: GDScript
var _codec_script: GDScript
var _codec_v1_script: GDScript
var _geometry_script: GDScript


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _generator_script = load(GENERATOR_PATH)
    _plan_script = load(PLAN_PATH)
    _codec_v2_script = load(CODEC_V2_PATH)
    _codec_script = load(CODEC_PATH)
    _codec_v1_script = load(CODEC_V1_PATH)
    _geometry_script = load(GEOMETRY_PATH)
    if (
        _generator_script == null
        or _plan_script == null
        or _codec_v2_script == null
        or _codec_script == null
        or _codec_v1_script == null
        or _geometry_script == null
    ):
        _fail("V2 codec test dependencies must exist")
        _finish()
        return

    var generated: Dictionary = _generate("golden-ac9", _golden_config())
    _assert_true(generated.get("ok", false), "golden V2 generation succeeds")
    if not generated.get("ok", false):
        _finish()
        return
    var plan: RefCounted = generated["plan"]

    _test_canonical_round_trip(plan)
    _test_golden_fixture_and_determinism(plan)
    _test_v1_facade_preservation()
    _test_facade_failures(plan)
    _test_generator_identity_grammar()
    _test_byte_mutations(plan)
    _test_plan_mutations(plan)
    _test_generator_validation_gate()
    _finish()


func _test_canonical_round_trip(plan: RefCounted) -> void:
    _assert_equal(_codec_v2_script.validate(plan), null, "direct V2 validation")
    _assert_equal(_codec_script.validate(plan), null, "facade V2 validation")
    var direct: PackedByteArray = _codec_v2_script.serialize(plan)
    var facade: PackedByteArray = _codec_script.serialize(plan)
    _assert_equal(facade, direct, "direct and facade serialization agree")
    var text := direct.get_string_from_utf8()
    _assert_true(text.begins_with("TWDE-WORLD,2\nseed,676f6c64656e2d616339\nstart,8,0\nboss,-8,0\nhabitat,main,main,goblin,8,0\n"), "canonical V2 header and first habitat")
    _assert_true(not direct.is_empty() and direct[0] != 0xef, "no UTF-8 BOM")
    _assert_true(text.find("\r") == -1, "LF-only serialization")
    _assert_true(text.ends_with("\n") and not text.ends_with("\n\n"), "exactly one final LF")
    var lines: Array[String] = _to_lines(direct)
    _assert_equal(_count_prefix(lines, "habitat,"), 4, "four habitat records")
    _assert_equal(_count_prefix(lines, "cell,"), 217, "217 cell records")
    _assert_equal(_count_prefix(lines, "town,"), 9, "nine town records")
    _assert_equal(_count_prefix(lines, "forest,"), _forest_coord_count(plan), "all forest records")
    _assert_equal(lines[4].split(",")[1], "main", "habitat order main")
    _assert_equal(lines[5].split(",")[1], "ally_0", "habitat order ally 0")
    _assert_equal(lines[6].split(",")[1], "ally_1", "habitat order ally 1")
    _assert_equal(lines[7].split(",")[1], "enemy", "habitat order enemy")
    _assert_equal(lines[225].split(",")[1], "main_town_0", "town order begins main")
    _assert_equal(lines[233].split(",")[1], "ally_1_town_2", "town order ends ally 1")

    var direct_parsed: Dictionary = _codec_v2_script.parse(direct)
    var facade_parsed: Dictionary = _codec_script.parse(direct)
    _assert_parse_ok(direct_parsed, "direct canonical parse")
    _assert_parse_ok(facade_parsed, "facade canonical parse")
    if direct_parsed.get("ok", false):
        _assert_equal(_codec_v2_script.serialize(direct_parsed["plan"]), direct, "direct byte-identical round trip")
    if facade_parsed.get("ok", false):
        _assert_equal(_codec_script.serialize(facade_parsed["plan"]), direct, "facade byte-identical round trip")


func _test_golden_fixture_and_determinism(plan: RefCounted) -> void:
    var canonical: PackedByteArray = _codec_script.serialize(plan)
    var fixture := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
    _assert_true(fixture != null, "golden-ac9 fixture exists")
    if fixture != null:
        var fixture_bytes: PackedByteArray = fixture.get_buffer(fixture.get_length())
        _assert_equal(fixture_bytes, canonical, "golden fixture exact bytes")
        _assert_equal(_sha256(fixture_bytes), EXPECTED_GOLDEN_SHA256, "golden fixture SHA-256 lock")

    var repeated: Dictionary = _generate("golden-ac9", _golden_config())
    var interleaved_config := {
        "main_clan_id": &"elf",
        "allied_clan_ids": [&"dwarf", &"harpy"],
        "enemy_clan_id": &"orc",
    }
    _generate("codec-interleaved", interleaved_config)
    var after_interleaving: Dictionary = _generate("golden-ac9", _golden_config())
    _assert_true(repeated.get("ok", false) and after_interleaving.get("ok", false), "determinism generations succeed")
    if repeated.get("ok", false) and after_interleaving.get("ok", false):
        var repeated_bytes: PackedByteArray = _codec_script.serialize(repeated["plan"])
        var interleaved_bytes: PackedByteArray = _codec_script.serialize(after_interleaving["plan"])
        _assert_equal(repeated_bytes, canonical, "clean repeated bytes")
        _assert_equal(interleaved_bytes, canonical, "interleaved repeated bytes")
        _assert_equal(_sha256(repeated_bytes), EXPECTED_GOLDEN_SHA256, "clean repeated hash")
        _assert_equal(_sha256(interleaved_bytes), EXPECTED_GOLDEN_SHA256, "interleaved repeated hash")


func _test_v1_facade_preservation() -> void:
    var manifest_file := FileAccess.open(V1_FIXTURE_DIR + "/corpus_manifest.json", FileAccess.READ)
    _assert_true(manifest_file != null, "V1 corpus manifest exists")
    if manifest_file == null:
        return
    var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
    for fixture_value: Variant in manifest.get("fixtures", []):
        var fixture: Dictionary = fixture_value
        var path := V1_FIXTURE_DIR + "/" + String(fixture["artifact"])
        var file := FileAccess.open(path, FileAccess.READ)
        _assert_true(file != null, "V1 fixture exists: %s" % path)
        if file == null:
            continue
        var bytes: PackedByteArray = file.get_buffer(file.get_length())
        var direct: Dictionary = _codec_v1_script.parse(bytes)
        var facade: Dictionary = _codec_script.parse(bytes)
        _assert_parse_ok(direct, "V1 direct parse: %s" % path)
        _assert_parse_ok(facade, "V1 facade parse: %s" % path)
        if direct.get("ok", false) and facade.get("ok", false):
            _assert_equal(_codec_script.serialize(facade["plan"]), bytes, "V1 facade exact bytes: %s" % path)
            _assert_equal(_codec_v1_script.serialize(direct["plan"]), bytes, "V1 direct remains exact: %s" % path)


func _test_facade_failures(plan: RefCounted) -> void:
    _assert_equal(_codec_script.serialize(null), PackedByteArray(), "facade null serialization is empty")
    var generic_ref := RefCounted.new()
    var generic_bytes: PackedByteArray = _codec_script.serialize(generic_ref)
    var generic_error: Variant = _codec_script.validate(generic_ref)
    var generic_calls_completed: bool = generic_bytes.is_empty() and generic_error != null
    _assert_true(
        generic_calls_completed,
        "facade generic RefCounted calls return safe results"
    )
    if generic_calls_completed:
        print("FACADE_GENERIC_REFCOUNTED_CONTINUED")
    _assert_equal(
        generic_bytes,
        PackedByteArray(),
        "facade generic RefCounted serialization is empty"
    )
    _assert_true(generic_error != null, "facade generic RefCounted validation is typed error")
    if generic_error != null:
        _assert_equal(
            generic_error.code,
            "WORLD_VERSION_UNSUPPORTED",
            "facade generic RefCounted validation code"
        )
        _assert_equal(generic_error.feature_namespace, "codec", "facade generic RefCounted namespace")
        _assert_equal(generic_error.failed_constraint, "world_version", "facade generic RefCounted constraint")
    var unsupported_plan: RefCounted = _copy_plan(plan, {"version": 3})
    _assert_equal(
        _codec_script.serialize(unsupported_plan),
        PackedByteArray(),
        "facade unsupported serialization is empty"
    )
    var unsupported_error: Variant = _codec_script.validate(unsupported_plan)
    _assert_true(unsupported_error != null, "facade unsupported validation is typed error")
    if unsupported_error != null:
        _assert_equal(
            unsupported_error.code,
            "WORLD_VERSION_UNSUPPORTED",
            "facade unsupported validation code"
        )
    var null_error: Variant = _codec_script.validate(null)
    _assert_true(null_error != null, "facade null validation is typed error")
    var malformed: PackedByteArray = "TWDE-WORLD,+2\n".to_utf8_buffer()
    _assert_rejected(_codec_script.parse(malformed), "facade malformed version")
    var unsupported: PackedByteArray = "TWDE-WORLD,3\n".to_utf8_buffer()
    var result: Dictionary = _codec_script.parse(unsupported)
    _assert_rejected(result, "facade unsupported version")
    if result.get("error") != null:
        _assert_equal(result["error"].code, "WORLD_VERSION_UNSUPPORTED", "unsupported version error code")
        _assert_equal(result["error"].failed_constraint, "world_version", "unsupported version constraint")


func _test_generator_identity_grammar() -> void:
    var invalid_ids: Array[StringName] = [&"gob-lin", &"_goblin", &"goblin_"]
    for invalid_id: StringName in invalid_ids:
        var config: Dictionary = _golden_config()
        config["main_clan_id"] = invalid_id
        var seed_text := "invalid-clan-%s" % String(invalid_id)
        var result: Dictionary = _generate(seed_text, config)
        _assert_rejected(result, "generator invalid clan %s" % String(invalid_id))
        var error: Variant = result.get("error")
        if error == null:
            continue
        _assert_equal(
            error.code,
            "WORLD_GENERATION_INTERNAL_ERROR",
            "generator invalid clan code %s" % String(invalid_id)
        )
        _assert_equal(
            error.feature_namespace,
            "habitat",
            "generator invalid clan namespace %s" % String(invalid_id)
        )
        _assert_equal(
            error.failed_constraint,
            "identity_context_invalid",
            "generator invalid clan constraint %s" % String(invalid_id)
        )


func _test_byte_mutations(plan: RefCounted) -> void:
    var canonical: PackedByteArray = _codec_v2_script.serialize(plan)
    var lines: Array[String] = _to_lines(canonical)
    var mutations: Array[Dictionary] = []

    mutations.append({"label": "reordered habitat records", "bytes": _swap(lines, 4, 5)})
    mutations.append({"label": "reordered cell records", "bytes": _swap(lines, 8, 9)})
    mutations.append({"label": "reordered town records", "bytes": _swap(lines, 225, 226)})
    var first_forest := _find_prefix(lines, "forest,")
    mutations.append({"label": "reordered forest records", "bytes": _swap(lines, first_forest, first_forest + 1)})
    mutations.append({"label": "unknown road record", "bytes": _insert(lines, 8, "road,0,0,1,0")})
    mutations.append({"label": "unknown record type", "bytes": _insert(lines, 8, "mystery,value")})
    mutations.append({"label": "habitat extra field", "bytes": _replace_line(lines, 4, lines[4] + ",extra")})
    mutations.append({"label": "cell extra field", "bytes": _replace_line(lines, 8, lines[8] + ",extra")})
    mutations.append({"label": "town extra field", "bytes": _replace_line(lines, 225, lines[225] + ",extra")})
    mutations.append({"label": "forest extra field", "bytes": _replace_line(lines, first_forest, lines[first_forest] + ",extra")})
    mutations.append({"label": "missing habitat record", "bytes": _remove(lines, 4)})
    mutations.append({"label": "duplicate habitat record", "bytes": _insert(lines, 5, lines[4])})
    mutations.append({"label": "missing cell record", "bytes": _remove(lines, 8)})
    mutations.append({"label": "duplicate cell record", "bytes": _insert(lines, 9, lines[8])})
    mutations.append({"label": "missing town record", "bytes": _remove(lines, 225)})
    mutations.append({"label": "duplicate town record", "bytes": _insert(lines, 226, lines[225])})
    mutations.append({"label": "missing forest record", "bytes": _remove(lines, first_forest)})
    mutations.append({"label": "duplicate forest record", "bytes": _insert(lines, first_forest + 1, lines[first_forest])})
    mutations.append({"label": "noncanonical positive int", "bytes": _replace_line(lines, 2, "start,+8,0")})
    mutations.append({"label": "noncanonical leading zero", "bytes": _replace_line(lines, 3, "boss,-08,0")})
    mutations.append({"label": "malformed clan id", "bytes": _replace_field(lines, 4, 3, "Goblin")})
    mutations.append({"label": "leading underscore clan", "bytes": _replace_field(lines, 4, 3, "_goblin")})
    mutations.append({"label": "trailing underscore clan", "bytes": _replace_field(lines, 4, 3, "goblin_")})
    mutations.append({"label": "wrong habitat id", "bytes": _replace_field(lines, 4, 1, "primary")})
    mutations.append({"label": "wrong habitat role", "bytes": _replace_field(lines, 5, 2, "main")})
    mutations.append({"label": "wrong habitat anchor", "bytes": _replace_field_pair(lines, 4, 4, "7", "0")})
    mutations.append({"label": "wrong start origin", "bytes": _replace_line(lines, 2, "start,7,0")})
    mutations.append({"label": "wrong boss origin", "bytes": _replace_line(lines, 3, "boss,-7,0")})
    mutations.append({"label": "conflicting cell habitat", "bytes": _replace_field(lines, 8, 6, "main")})
    mutations.append({"label": "wrong town id", "bytes": _replace_field(lines, 225, 1, "main_town_9")})
    mutations.append({"label": "wrong town local index", "bytes": _replace_field(lines, 225, 3, "1")})
    mutations.append({"label": "wrong town owner", "bytes": _replace_field(lines, 225, 2, "ally_0")})
    mutations.append({"label": "wrong town coordinate", "bytes": _replace_field_pair(lines, 225, 4, "8", "0")})
    mutations.append({"label": "wrong forest cluster index", "bytes": _replace_field(lines, first_forest, 1, "10")})
    mutations.append({"label": "CRLF", "bytes": canonical.get_string_from_utf8().replace("\n", "\r\n").to_utf8_buffer()})
    mutations.append({"label": "missing final LF", "bytes": canonical.get_string_from_utf8().trim_suffix("\n").to_utf8_buffer()})
    mutations.append({"label": "double final LF", "bytes": (canonical.get_string_from_utf8() + "\n").to_utf8_buffer()})
    var bom := PackedByteArray([0xef, 0xbb, 0xbf])
    bom.append_array(canonical)
    mutations.append({"label": "UTF-8 BOM", "bytes": bom})

    for mutation: Dictionary in mutations:
        _assert_rejected(_codec_v2_script.parse(mutation["bytes"]), mutation["label"])


func _test_plan_mutations(plan: RefCounted) -> void:
    var cells: Dictionary = plan.get_cells()
    var habitats: Array = plan.get_habitats()
    var towns: Array = plan.get_towns()
    var forests: Array = plan.get_forest_clusters()

    var extra_cell_fields: Dictionary = cells.duplicate(true)
    extra_cell_fields[plan.get_start_coord()]["extra"] = true
    _assert_validation_error(_copy_plan(plan, {"cells": extra_cell_fields}), "unknown cell field")
    var missing_cell_field: Dictionary = cells.duplicate(true)
    missing_cell_field[plan.get_start_coord()].erase("terrain")
    _assert_validation_error(_copy_plan(plan, {"cells": missing_cell_field}), "missing cell field")
    var extra_habitat_fields: Array = habitats.duplicate(true)
    extra_habitat_fields[0]["extra"] = true
    _assert_validation_error(_copy_plan(plan, {"habitats": extra_habitat_fields}), "unknown habitat field")
    var extra_town_fields: Array = towns.duplicate(true)
    extra_town_fields[0]["extra"] = true
    _assert_validation_error(_copy_plan(plan, {"towns": extra_town_fields}), "unknown town field")

    var duplicate_clans: Array = habitats.duplicate(true)
    duplicate_clans[1]["clan_id"] = duplicate_clans[0]["clan_id"]
    _assert_validation_error(_copy_plan(plan, {"habitats": duplicate_clans}), "duplicate clan identity")
    var wrong_cell_type: Dictionary = cells.duplicate(true)
    wrong_cell_type[plan.get_start_coord()]["town_index"] = -1.0
    _assert_validation_error(_copy_plan(plan, {"cells": wrong_cell_type}), "wrong cell field type")
    var wrong_habitat_type: Array = habitats.duplicate(true)
    wrong_habitat_type[1]["anchor"] = "0,0"
    _assert_validation_error(_copy_plan(plan, {"habitats": wrong_habitat_type}), "wrong habitat field type")
    var wrong_town_type: Array = towns.duplicate(true)
    wrong_town_type[0]["local_index"] = "0"
    _assert_validation_error(_copy_plan(plan, {"towns": wrong_town_type}), "wrong town field type")
    var wrong_forest_type: Array = []
    for cluster_value: Variant in forests:
        var untyped_cluster: Array = []
        for coord_value: Variant in cluster_value:
            untyped_cluster.append(coord_value)
        wrong_forest_type.append(untyped_cluster)
    wrong_forest_type[0][0] = "0,0"
    _assert_validation_error(
        _copy_plan(plan, {"forests": wrong_forest_type}),
        "wrong forest field type"
    )

    var wrong_footprint: Dictionary = cells.duplicate(true)
    wrong_footprint[Vector2i(-6, 1)]["habitat_id"] = "enemy"
    _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": wrong_footprint}), "wrong enemy footprint")

    var disconnected_cells: Dictionary = cells.duplicate(true)
    var disconnected_coord: Vector2i = _find_isolated_foreign_coord(plan, "main", "ally_0")
    _assert_true(disconnected_coord != Vector2i(999, 999), "disconnected habitat mutation coordinate found")
    if disconnected_coord != Vector2i(999, 999):
        disconnected_cells[disconnected_coord]["habitat_id"] = "ally_0"
        _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": disconnected_cells}), "disconnected habitat")

    var missing_town: Array = towns.duplicate(true)
    var removed_town: Dictionary = missing_town.pop_back()
    var missing_town_cells: Dictionary = cells.duplicate(true)
    missing_town_cells[removed_town["coord"]]["town_index"] = -1
    _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": missing_town_cells, "towns": missing_town}), "missing town")

    var duplicate_town: Array = towns.duplicate(true)
    duplicate_town[1] = duplicate_town[0].duplicate(true)
    _assert_serialized_plan_rejected(_copy_plan(plan, {"towns": duplicate_town}), "duplicate town")

    var enemy_town: Array = towns.duplicate(true)
    var enemy_cells: Dictionary = cells.duplicate(true)
    var old_coord: Vector2i = enemy_town[8]["coord"]
    var enemy_coord := Vector2i(-8, 1)
    enemy_cells[old_coord]["town_index"] = -1
    enemy_cells[enemy_coord]["town_index"] = 8
    enemy_cells[enemy_coord]["encounter"] = "safe"
    enemy_town[8] = {
        "town_id": "enemy_town_2",
        "habitat_id": "enemy",
        "local_index": 2,
        "coord": enemy_coord,
    }
    _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": enemy_cells, "towns": enemy_town}), "enemy town")

    var unsafe_cells: Dictionary = cells.duplicate(true)
    unsafe_cells[towns[0]["coord"]]["encounter"] = "combat"
    _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": unsafe_cells}), "non-safe town")

    var second_boss: Dictionary = cells.duplicate(true)
    second_boss[towns[0]["coord"]]["encounter"] = "boss"
    _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": second_boss}), "boss is not unique")

    _assert_validation_error(
        _copy_plan(
            plan,
            {"roads": [{"a": towns[0]["coord"], "b": towns[1]["coord"]}]}
        ),
        "nonempty V2 roads"
    )

    var missing_forests: Array = forests.duplicate(true)
    missing_forests.pop_back()
    _assert_serialized_plan_rejected(_copy_plan(plan, {"forests": missing_forests}), "missing forest cluster")

    var mismatched_terrain: Dictionary = cells.duplicate(true)
    var forest_coord: Vector2i = forests[0][0]
    mismatched_terrain[forest_coord]["terrain"] = "plain"
    _assert_serialized_plan_rejected(_copy_plan(plan, {"cells": mismatched_terrain}), "forest terrain mismatch")

    var disconnected_forests: Array = forests.duplicate(true)
    var disconnected_forest_cells: Dictionary = cells.duplicate(true)
    var old_forest_coord: Vector2i = disconnected_forests[0].pop_back()
    var new_forest_coord: Vector2i = _find_disconnected_forest_coord(plan, disconnected_forests[0])
    _assert_true(new_forest_coord != Vector2i(999, 999), "disconnected forest mutation coordinate found")
    if new_forest_coord != Vector2i(999, 999):
        disconnected_forests[0].append(new_forest_coord)
        disconnected_forest_cells[old_forest_coord]["terrain"] = "plain"
        disconnected_forest_cells[new_forest_coord]["terrain"] = "forest"
        _assert_serialized_plan_rejected(
            _copy_plan(plan, {"cells": disconnected_forest_cells, "forests": disconnected_forests}),
            "disconnected forest"
        )


func _test_generator_validation_gate() -> void:
    var config: Dictionary = _golden_config()
    config["forest_count"] = 0
    var result: Dictionary = _generate("codec-gate", config)
    _assert_rejected(result, "production generator rejects codec-invalid final plan")
    if result.get("error") != null:
        _assert_equal(result["error"].feature_namespace, "habitat", "generator rejects fixed config before solving")
        _assert_equal(result["error"].failed_constraint, "forest_cluster_count=10", "generator reports fixed forest count")


func _copy_plan(plan: RefCounted, overrides: Dictionary) -> RefCounted:
    return _plan_script.new(
        overrides.get("version", plan.get_version()),
        overrides.get("seed_hex", plan.get_seed_hex()),
        overrides.get("start", plan.get_start_coord()),
        overrides.get("boss", plan.get_boss_coord()),
        overrides.get("cells", plan.get_cells()),
        overrides.get("roads", plan.get_roads()),
        overrides.get("forests", plan.get_forest_clusters()),
        overrides.get("habitats", plan.get_habitats()),
        overrides.get("towns", plan.get_towns())
    )


func _assert_serialized_plan_rejected(plan: RefCounted, label: String) -> void:
    _assert_validation_error(plan, label + " direct validation")
    _assert_rejected(_codec_v2_script.parse(_codec_v2_script.serialize(plan)), label + " parse")


func _assert_validation_error(plan: RefCounted, label: String) -> void:
    var error: Variant = _codec_v2_script.validate(plan)
    _assert_true(error != null, "%s returns validation error" % label)
    if error != null:
        _assert_equal(error.code, "WORLD_GENERATION_INTERNAL_ERROR", "%s error code" % label)
        _assert_equal(error.generator_version, 2, "%s error version" % label)
        _assert_equal(error.feature_namespace, "validation", "%s error namespace" % label)


func _find_isolated_foreign_coord(plan: RefCounted, source_id: String, target_id: String) -> Vector2i:
    var target_members: Array[Vector2i] = plan.get_habitat_cells(target_id)
    for candidate: Vector2i in plan.get_habitat_cells(source_id):
        if candidate == plan.get_start_coord():
            continue
        var adjacent := false
        for member: Vector2i in target_members:
            if _geometry_script.get_hex_distance(candidate, member) <= 1:
                adjacent = true
                break
        if not adjacent:
            return candidate
    return Vector2i(999, 999)


func _find_disconnected_forest_coord(plan: RefCounted, cluster: Array) -> Vector2i:
    var occupied: Dictionary = {}
    for forest_cluster: Array in plan.get_forest_clusters():
        for coord: Vector2i in forest_cluster:
            occupied[coord] = true
    for coord: Vector2i in _geometry_script.get_canonical_coords(8):
        if occupied.has(coord) or coord == plan.get_start_coord() or coord == plan.get_boss_coord():
            continue
        var is_town := int(plan.get_cells()[coord]["town_index"]) >= 0
        if is_town:
            continue
        var disconnected := true
        for member: Vector2i in cluster:
            if _geometry_script.get_hex_distance(coord, member) <= 1:
                disconnected = false
                break
        if disconnected:
            return coord
    return Vector2i(999, 999)


func _generate(seed_text: String, config: Dictionary) -> Dictionary:
    return _generator_script.new().generate(seed_text, config)


func _golden_config() -> Dictionary:
    return {
        "main_clan_id": &"goblin",
        "allied_clan_ids": [&"orc", &"werewolf"],
        "enemy_clan_id": &"human",
    }


func _to_lines(bytes: PackedByteArray) -> Array[String]:
    var result: Array[String] = []
    for line: String in bytes.get_string_from_utf8().trim_suffix("\n").split("\n", false):
        result.append(line)
    return result


func _from_lines(lines: Array[String]) -> PackedByteArray:
    return ("\n".join(lines) + "\n").to_utf8_buffer()


func _swap(lines: Array[String], first: int, second: int) -> PackedByteArray:
    var changed: Array[String] = lines.duplicate()
    var temporary: String = changed[first]
    changed[first] = changed[second]
    changed[second] = temporary
    return _from_lines(changed)


func _insert(lines: Array[String], index: int, value: String) -> PackedByteArray:
    var changed: Array[String] = lines.duplicate()
    changed.insert(index, value)
    return _from_lines(changed)


func _remove(lines: Array[String], index: int) -> PackedByteArray:
    var changed: Array[String] = lines.duplicate()
    changed.remove_at(index)
    return _from_lines(changed)


func _replace_line(lines: Array[String], index: int, value: String) -> PackedByteArray:
    var changed: Array[String] = lines.duplicate()
    changed[index] = value
    return _from_lines(changed)


func _replace_field(lines: Array[String], line_index: int, field_index: int, value: String) -> PackedByteArray:
    var changed: Array[String] = lines.duplicate()
    var fields: PackedStringArray = changed[line_index].split(",", false)
    fields[field_index] = value
    changed[line_index] = ",".join(fields)
    return _from_lines(changed)


func _replace_field_pair(
    lines: Array[String],
    line_index: int,
    field_index: int,
    first: String,
    second: String
) -> PackedByteArray:
    var changed: Array[String] = lines.duplicate()
    var fields: PackedStringArray = changed[line_index].split(",", false)
    fields[field_index] = first
    fields[field_index + 1] = second
    changed[line_index] = ",".join(fields)
    return _from_lines(changed)


func _find_prefix(lines: Array[String], prefix: String) -> int:
    for index: int in range(lines.size()):
        if lines[index].begins_with(prefix):
            return index
    return -1


func _count_prefix(lines: Array[String], prefix: String) -> int:
    var count := 0
    for line: String in lines:
        if line.begins_with(prefix):
            count += 1
    return count


func _forest_coord_count(plan: RefCounted) -> int:
    var count := 0
    for cluster: Array in plan.get_forest_clusters():
        count += cluster.size()
    return count


func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


func _assert_parse_ok(result: Dictionary, label: String) -> void:
    _assert_true(result.get("ok", false), label)
    if result.get("ok", false):
        _assert_true(result.get("plan") != null, "%s returns plan" % label)
        _assert_equal(result.get("error"), null, "%s has no error" % label)


func _assert_rejected(result: Dictionary, label: String) -> void:
    _assert_true(not result.get("ok", true), "%s rejected" % label)
    _assert_equal(result.get("plan"), null, "%s publishes no plan" % label)
    _assert_true(result.get("error") != null, "%s returns typed error" % label)


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
        print("PASS test_world_plan_codec_v2")
    quit(1 if _failures > 0 else 0)
