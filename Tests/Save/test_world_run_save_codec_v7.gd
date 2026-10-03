extends SceneTree

const START_SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"
const V7_CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v7.gd"
const V6_CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v6.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var started: Dictionary = load(START_SERVICE_PATH).new(
        func(_plan: RefCounted) -> void: pass,
        load("res://Scripts/WorldMap/hex_world_generator_v1.gd").new()
    ).start("ac9-vector-1")
    _expect(started.get("ok", false), "fixture run starts")
    if not started.get("ok", false):
        _finish()
        return

    var v7_codec: GDScript = load(V7_CODEC_PATH)
    var bytes: PackedByteArray = v7_codec.encode(
        started.plan,
        started.resolved_seed,
        started.run_state,
        started.selection,
        started.coalition
    )
    _expect(not bytes.is_empty(), "V7 encodes")
    if bytes.is_empty():
        _finish()
        return

    var root: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    _expect(root is Dictionary, "V7 payload is JSON")
    if root is Dictionary:
        _expect(root.get("save_version") == 7, "V7 save version")
        _expect(
            root.world.get("allied_clan_ids") == ["orc", "werewolf"],
            "V7 writes canonical allies"
        )

    var round_trip: Dictionary = v7_codec.decode_any(bytes)
    _expect(round_trip.get("ok", false), "V7 round-trip decodes")
    if round_trip.get("ok", false):
        _expect(
            round_trip.value.coalition.allied_clan_ids
            == started.coalition.allied_clan_ids,
            "V7 round-trip restores exact coalition"
        )

    _expect_malformed_rejected(v7_codec, root, null, "missing allies")
    _expect_malformed_rejected(
        v7_codec,
        root,
        ["werewolf", "orc"],
        "out-of-order allies"
    )
    _expect_malformed_rejected(
        v7_codec,
        root,
        ["orc", "orc"],
        "duplicate allies"
    )
    _expect_malformed_rejected(
        v7_codec,
        root,
        ["orc", "unknown"],
        "unknown ally"
    )
    _expect_malformed_rejected(
        v7_codec,
        root,
        ["harpy", "lizardman"],
        "noncanonical allies"
    )

    var v6_bytes: PackedByteArray = load(V6_CODEC_PATH).encode(
        started.plan,
        started.resolved_seed,
        started.run_state,
        started.selection
    )
    var legacy: Dictionary = v7_codec.decode_any(v6_bytes)
    _expect(legacy.get("ok", false), "V6 fallback decodes")
    if legacy.get("ok", false):
        _expect(
            is_instance_valid(legacy.value.selection),
            "V6 fallback preserves selection"
        )
        _expect(
            not is_instance_valid(legacy.value.coalition),
            "V6 fallback does not invent coalition"
        )
    _finish()


func _expect_malformed_rejected(
    codec: GDScript,
    source_root: Dictionary,
    allied_clan_ids: Variant,
    label: String
) -> void:
    var malformed: Dictionary = source_root.duplicate(true)
    if allied_clan_ids == null:
        malformed.world.erase("allied_clan_ids")
    else:
        malformed.world["allied_clan_ids"] = allied_clan_ids
    var bytes: PackedByteArray = (JSON.stringify(malformed) + "\n").to_utf8_buffer()
    _expect(not codec.decode_any(bytes).get("ok", true), label)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_save_codec_v7")
    quit(1 if _failures > 0 else 0)
