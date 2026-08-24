extends SceneTree

const STORE_PATH := "res://Scripts/Save/world_save_store.gd"
const SAVE_CODEC_PATH := "res://Scripts/Save/world_save_codec_v1.gd"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var store_script: GDScript = load(STORE_PATH)
    if store_script == null:
        _fail("WorldSaveStore script is missing")
        _finish()
        return
    var codec: GDScript = load(SAVE_CODEC_PATH)
    var generator: GDScript = load(GENERATOR_PATH)
    var root := "user://tests/world-save-v1/store-test"
    var path := root + "/run.json"
    _cleanup(root)

    var generated: Dictionary = generator.new().generate("golden-alpha")
    var runtime := {
        "player_coord": Vector2i(-8, 0),
        "boss_coord": Vector2i(8, 0),
        "move_count": 0,
        "sudden_death_active": false,
    }
    var first: PackedByteArray = codec.encode(generated["plan"], runtime)
    var store: RefCounted = store_script.new()
    _assert_true(store.save_atomic(path, first).get("ok", false), "first atomic save")
    _assert_true(not FileAccess.file_exists(path + ".tmp"), "no temp after save")
    _assert_true(not FileAccess.file_exists(path + ".bak"), "no backup after save")
    _assert_true(store.load_validated(path).get("ok", false), "saved file loads")

    runtime["move_count"] = 1
    var second: PackedByteArray = codec.encode(generated["plan"], runtime)
    _assert_true(store.save_atomic(path, second).get("ok", false), "replacement save")
    var replaced: Dictionary = store.load_validated(path)
    _assert_true(replaced.get("ok", false), "replacement loads")
    if replaced.get("ok", false):
        _assert_equal(replaced["value"]["runtime"]["move_count"], 1, "replacement runtime")

    var corrupt := "{\"schema\":\"twde-run-save\"}\n".to_utf8_buffer()
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_buffer(corrupt)
    file.close()
    var before := _read_bytes(path)
    var failed: Dictionary = store.load_validated(path)
    _assert_true(not failed.get("ok", true), "invalid save rejected")
    _assert_equal(_read_bytes(path), before, "failed load leaves source unchanged")
    _cleanup(root)
    _finish()


func _read_bytes(path: String) -> PackedByteArray:
    var file := FileAccess.open(path, FileAccess.READ)
    return file.get_buffer(file.get_length())


func _cleanup(root: String) -> void:
    var absolute := ProjectSettings.globalize_path(root)
    var expected := ProjectSettings.globalize_path("user://tests/world-save-v1/")
    if not absolute.begins_with(expected):
        _fail("unsafe cleanup path")
        return
    for suffix: String in ["/run.json", "/run.json.tmp", "/run.json.bak"]:
        var file_path := absolute + suffix
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(file_path)
    if DirAccess.dir_exists_absolute(absolute):
        DirAccess.remove_absolute(absolute)


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
        print("PASS test_world_save_store")
    quit(1 if _failures > 0 else 0)
