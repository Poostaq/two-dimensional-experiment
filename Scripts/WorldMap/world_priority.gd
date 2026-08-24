class_name WorldPriority
extends RefCounted

const DEFAULT_SEED := "default-run"
const HASH_OFFSET_BASIS := 2166136261
const HASH_PRIME := 16777619
const HASH_MASK := 0xffffffff


static func normalize_seed(seed_text: String) -> String:
    return DEFAULT_SEED if seed_text.is_empty() else seed_text


static func seed_hex(seed_text: String) -> String:
    return normalize_seed(seed_text).to_utf8_buffer().hex_encode()


static func payload(
    version: int,
    seed_text: String,
    feature_namespace: String,
    index: int,
    coord: Vector2i
) -> String:
    assert(_is_valid_namespace(feature_namespace), "Invalid world priority namespace")
    return "twde-wg|v=%d|seed=%s|ns=%s|i=%d|q=%d|r=%d" % [
        version,
        seed_hex(seed_text),
        feature_namespace,
        index,
        coord.x,
        coord.y,
    ]


static func fnv1a32_ascii(value: String) -> int:
    var hash_value: int = HASH_OFFSET_BASIS
    for byte: int in value.to_ascii_buffer():
        hash_value = ((hash_value ^ byte) * HASH_PRIME) & HASH_MASK
    return hash_value


static func rank_coords(
    coords: Array[Vector2i],
    version: int,
    seed_text: String,
    feature_namespace: String,
    index: int = -1
) -> Array[Vector2i]:
    var ranked: Array[Vector2i] = coords.duplicate()
    ranked.sort_custom(
        func(a: Vector2i, b: Vector2i) -> bool:
            var a_hash: int = fnv1a32_ascii(payload(version, seed_text, feature_namespace, index, a))
            var b_hash: int = fnv1a32_ascii(payload(version, seed_text, feature_namespace, index, b))
            if a_hash != b_hash:
                return a_hash < b_hash
            if a.x != b.x:
                return a.x < b.x
            return a.y < b.y
    )
    return ranked


static func _is_valid_namespace(value: String) -> bool:
    if value.is_empty():
        return false
    for byte: int in value.to_ascii_buffer():
        var is_lowercase := byte >= 97 and byte <= 122
        var is_digit := byte >= 48 and byte <= 57
        if not is_lowercase and not is_digit and byte != 95 and byte != 45:
            return false
    return true
