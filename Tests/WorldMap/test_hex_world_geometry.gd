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
        print("PASS test_hex_world_geometry")
    quit(1 if _failures > 0 else 0)
