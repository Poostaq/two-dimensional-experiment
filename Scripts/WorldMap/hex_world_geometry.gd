class_name HexWorldGeometry
extends RefCounted

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(1, -1),
    Vector2i(0, -1),
    Vector2i(-1, 0),
    Vector2i(-1, 1),
    Vector2i(0, 1),
]


static func get_canonical_coords(radius: int = 8) -> Array[Vector2i]:
    assert(radius >= 0, "Hex world radius must be non-negative")
    var coords: Array[Vector2i] = []
    for q: int in range(-radius, radius + 1):
        var r_min: int = maxi(-radius, -q - radius)
        var r_max: int = mini(radius, -q + radius)
        for r: int in range(r_min, r_max + 1):
            coords.append(Vector2i(q, r))
    return coords


static func is_valid_coord(coord: Vector2i, radius: int = 8) -> bool:
    if radius < 0:
        return false
    var s: int = -coord.x - coord.y
    return maxi(absi(coord.x), maxi(absi(coord.y), absi(s))) <= radius


static func get_neighbors(coord: Vector2i, radius: int = 8) -> Array[Vector2i]:
    var neighbors: Array[Vector2i] = []
    for offset: Vector2i in NEIGHBOR_OFFSETS:
        var candidate := coord + offset
        if is_valid_coord(candidate, radius):
            neighbors.append(candidate)
    return neighbors


static func get_hex_distance(a: Vector2i, b: Vector2i) -> int:
    var delta := a - b
    return maxi(absi(delta.x), maxi(absi(delta.y), absi(-delta.x - delta.y)))
