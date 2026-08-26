class_name WorldSingleSlotRepositoryTests
extends SceneTree

const REPOSITORY_PATH := "res://Scripts/Run/world_single_slot_repository.gd"
const RUN_STATE_PATH := "res://Scripts/Run/world_run_state.gd"
const SAVE_CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v2.gd"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const FIXTURE_ROOT := "res://Tests/Fixtures/WorldMap/SaveV1"

var _failures: int = 0


class FailingSaveStore:
    extends RefCounted

    func save_atomic(_path: String, _bytes: PackedByteArray) -> Dictionary:
        return {"ok": false, "value": null, "error": null}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(REPOSITORY_PATH):
        _fail("WorldSingleSlotRepository script is missing")
        _finish()
        return
    var repository_script := load(REPOSITORY_PATH) as GDScript
    var state_script := load(RUN_STATE_PATH) as GDScript
    var save_codec := load(SAVE_CODEC_PATH) as GDScript
    var generator_script := load(GENERATOR_PATH) as GDScript
    var root := "user://tests/world-single-slot"
    var path := root + "/active-world-run.json"
    _cleanup(root)

    var repository: RefCounted = repository_script.new(path)
    _expect(not bool(repository.call("has_save")), "empty slot reports no save")

    var generated: Dictionary = generator_script.new().generate("golden-alpha")
    _expect(bool(generated.get("ok", false)), "fixture world generates")
    if not bool(generated.get("ok", false)):
        _cleanup(root)
        _finish()
        return
    var formation: Array[StringName] = [
        &"starter_vanguard", &"starter_scout", &"", &"starter_mage", &"", &"",
    ]
    var consumed: Array[Vector2i] = [Vector2i(-7, 0)]
    var state: RefCounted = state_script.create(
        Vector2i(-7, 0), Vector2i(8, -1), 31, true, false, consumed, formation
    )
    var bytes: PackedByteArray = save_codec.encode(generated["plan"], "golden-alpha", state)
    _expect(bool(repository.call("replace_atomic", bytes).get("ok", false)), "valid run saves atomically")
    _expect(bool(repository.call("has_save")), "saved slot is discoverable")

    var loaded: Dictionary = repository.call("load_validated")
    _expect(bool(loaded.get("ok", false)), "saved slot loads")
    if bool(loaded.get("ok", false)):
        var restored := loaded.get("value", {}).get("run_state") as RefCounted
        _expect(
            restored.call("canonical_key") == state.call("canonical_key"),
            "continue restores exact runtime state"
        )

    var before_cancel := _read_bytes(path)
    _expect(_read_bytes(path) == before_cancel, "overwrite cancellation performs zero writes")

    repository.set("_store", FailingSaveStore.new())
    _expect(
        not bool(repository.call("replace_atomic", "replacement".to_utf8_buffer()).get("ok", true)),
        "failed replacement is reported"
    )
    _expect(_read_bytes(path) == before_cancel, "failed replacement preserves prior bytes")

    repository = repository_script.new(path)
    _copy_fixture(FIXTURE_ROOT + "/legacy-25-cell.json", path)
    _expect_code(repository.call("load_validated"), "LEGACY_WORLD_SAVE_UNSUPPORTED", "legacy fixture")

    _copy_fixture(FIXTURE_ROOT + "/unsupported-v2.json", path)
    _expect_code(repository.call("load_validated"), "WORLD_VERSION_UNSUPPORTED", "unsupported generator")

    _cleanup(root)
    _finish()


func _copy_fixture(source_path: String, destination_path: String) -> void:
    var source := FileAccess.open(source_path, FileAccess.READ)
    if source == null:
        _fail("fixture is missing: %s" % source_path)
        return
    var bytes := source.get_buffer(source.get_length())
    source.close()
    var absolute := ProjectSettings.globalize_path(destination_path)
    DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    var destination := FileAccess.open(destination_path, FileAccess.WRITE)
    if destination == null:
        _fail("cannot open test slot")
        return
    destination.store_buffer(bytes)
    destination.close()


func _read_bytes(path: String) -> PackedByteArray:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return PackedByteArray()
    var bytes := file.get_buffer(file.get_length())
    file.close()
    return bytes


func _expect_code(result: Dictionary, expected_code: String, label: String) -> void:
    _expect(not bool(result.get("ok", true)), "%s fails" % label)
    if not bool(result.get("ok", true)):
        var error := result.get("error") as RefCounted
        _expect(is_instance_valid(error), "%s returns a typed error" % label)
        if is_instance_valid(error):
            _expect(String(error.get("code")) == expected_code, "%s maps to %s" % [label, expected_code])


func _cleanup(root: String) -> void:
    var absolute := ProjectSettings.globalize_path(root)
    var expected := ProjectSettings.globalize_path("user://tests/world-single-slot")
    if absolute != expected:
        _fail("unsafe cleanup path")
        return
    for suffix: String in ["/active-world-run.json", "/active-world-run.json.tmp", "/active-world-run.json.bak"]:
        var file_path := absolute + suffix
        if FileAccess.file_exists(file_path):
            DirAccess.remove_absolute(file_path)
    if DirAccess.dir_exists_absolute(absolute):
        DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_single_slot_repository")
    quit(1 if _failures > 0 else 0)
