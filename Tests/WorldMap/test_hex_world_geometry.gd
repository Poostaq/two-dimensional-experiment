extends SceneTree

const SCRIPT_PATH := "res://Scripts/WorldMap/hex_world_geometry.gd"

var _failures: int = 0

func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var geometry_script: GDScript = load(SCRIPT_PATH)
    if geometry_script == null:
        _fail("HexWorldGeometry script is missing")
        _finish()
        return

    var coords: Array[Vector2i] = geometry_script.get_canonical_coords(8)
    _assert_equal(coords.size(), 217, "radius-8 cell count")
    _assert_equal(coords[0], Vector2i(-8, 0), "first canonical coordinate")
    _assert_equal(coords[coords.size() - 1], Vector2i(8, 0), "last canonical coordinate")

    var unique: Dictionary = {}
    var previous := Vector2i(-999, -999)
    for coord: Vector2i in coords:
        unique[coord] = true
        _assert_true(geometry_script.is_valid_coord(coord, 8), "coordinate must be valid: %s" % coord)
        if previous.x != -999:
            _assert_true(
                coord.x > previous.x or (coord.x == previous.x and coord.y > previous.y),
                "coordinates must be sorted by q then r"
            )
        previous = coord
    _assert_equal(unique.size(), 217, "unique coordinate count")

    _assert_true(not geometry_script.is_valid_coord(Vector2i(8, 1), 8), "outside coordinate rejected")
    _assert_equal(
        geometry_script.get_neighbors(Vector2i.ZERO, 8),
        [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)],
        "center neighbor order"
    )
    _assert_equal(geometry_script.get_neighbors(Vector2i(-8, 0), 8).size(), 3, "corner neighbor clipping")
    _assert_equal(
        geometry_script.get_hex_distance(Vector2i(-8, 0), Vector2i(8, 0)),
        16,
        "start to boss distance"
    )

    _assert_equal(geometry_script.rendered_horizontal_key(Vector2i(-8, 0)), -16, "west key")
    _assert_equal(geometry_script.rendered_horizontal_key(Vector2i(8, 0)), 16, "east key")
    _assert_equal(
        geometry_script.get_visual_extrema(coords),
        {"west": Vector2i(-8, 0), "east": Vector2i(8, 0)},
        "radius-8 visual extrema"
    )
    var tied_coords: Array[Vector2i] = [
        Vector2i(1, -2),
        Vector2i(0, 0),
        Vector2i(-1, 2),
    ]
    _assert_equal(
        geometry_script.get_visual_extrema(tied_coords),
        {"west": Vector2i(-1, 2), "east": Vector2i(1, -2)},
        "visual extrema ties use canonical coordinate order"
    )
    var empty_coords: Array[Vector2i] = []
    _assert_equal(geometry_script.get_visual_extrema(empty_coords), {}, "empty visual extrema")
    _assert_horizontal_formula_ordering(geometry_script, coords)
    _finish()


func _assert_horizontal_formula_ordering(geometry_script: GDScript, coords: Array[Vector2i]) -> void:
    const CELL_FLAT_WIDTH: float = 80.0
    const MINI_HEX_RADIUS: float = 8.0
    var previous_key: int = -999
    var previous_world_x: float = -INF
    var previous_minimap_x: float = -INF
    var ordered_coords := coords.duplicate()
    ordered_coords.sort_custom(
        func(a: Vector2i, b: Vector2i) -> bool:
            var a_key: int = geometry_script.rendered_horizontal_key(a)
            var b_key: int = geometry_script.rendered_horizontal_key(b)
            if a_key != b_key:
                return a_key < b_key
            return a.x < b.x or (a.x == b.x and a.y < b.y)
    )
    for coord: Vector2i in ordered_coords:
        var key: int = geometry_script.rendered_horizontal_key(coord)
        var axial_offset: float = float(coord.x) + 0.5 * float(coord.y)
        var world_x: float = CELL_FLAT_WIDTH * axial_offset
        var minimap_x: float = MINI_HEX_RADIUS * sqrt(3.0) * axial_offset
        _assert_true(key >= previous_key, "rendered key ordering")
        _assert_true(world_x >= previous_world_x, "axial_to_world horizontal ordering")
        _assert_true(minimap_x >= previous_minimap_x, "minimap projection horizontal ordering")
        _assert_true(
            is_equal_approx(float(key), world_x * 2.0 / CELL_FLAT_WIDTH),
            "rendered key matches CELL_FLAT_WIDTH axial_to_world formula"
        )
        _assert_true(
            is_equal_approx(
                float(key),
                minimap_x * 2.0 / (MINI_HEX_RADIUS * sqrt(3.0))
            ),
            "rendered key matches MINI_HEX_RADIUS minimap formula"
        )
        previous_key = key
        previous_world_x = world_x
        previous_minimap_x = minimap_x


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
        print("PASS test_hex_world_geometry")
    quit(1 if _failures > 0 else 0)
