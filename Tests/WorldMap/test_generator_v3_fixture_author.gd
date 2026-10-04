class_name TestGeneratorV3FixtureAuthor
extends SceneTree

const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v3.gd"
const CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec_v3.gd"
const FIXTURE_DIR := "res://Tests/Fixtures/WorldMap/GeneratorV3"
const FIXTURE_PATH := FIXTURE_DIR + "/golden-ac9.world"
const EXPECTED_SHA256 := "8f6d33613442749ce31c209ba3ddf93bd260addb66cfce74594804ae0285ad30"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var generator_script: GDScript = load(GENERATOR_PATH)
    var codec_script: GDScript = load(CODEC_PATH)
    if generator_script == null or codec_script == null:
        _fail("V3 generator and codec must exist")
        _finish()
        return
    var config := {
        "main_clan_id": &"goblin",
        "allied_clan_ids": [&"orc", &"werewolf"],
        "enemy_clan_id": &"human",
    }
    var result: Dictionary = generator_script.new().generate("golden-ac9", config)
    if not result.get("ok", false):
        _fail("golden-ac9 V3 generation must succeed")
        _finish()
        return
    var plan: RefCounted = result["plan"]
    if codec_script.validate(plan) != null:
        _fail("golden-ac9 V3 plan must validate")
        _finish()
        return
    var bytes: PackedByteArray = codec_script.serialize(plan)
    var production_sha256: String = _sha256(bytes)
    print("V3_PRODUCTION_SHA256=%s" % production_sha256)
    if production_sha256 != EXPECTED_SHA256:
        _fail("production V3 bytes do not match the approved hash")
        _finish()
        return

    if "--write" in OS.get_cmdline_user_args():
        var directory_error := DirAccess.make_dir_recursive_absolute(
            ProjectSettings.globalize_path(FIXTURE_DIR)
        )
        if directory_error != OK:
            _fail("fixture directory creation failed: %s" % error_string(directory_error))
            _finish()
            return
        var output: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.WRITE)
        if output == null:
            _fail("fixture output could not be opened")
            _finish()
            return
        output.store_buffer(bytes)
        output.close()

    var fixture: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
    if fixture == null:
        _fail("fixture is missing; invoke with -- --write to author it")
        _finish()
        return
    var actual: PackedByteArray = fixture.get_buffer(fixture.get_length())
    if actual != bytes:
        _fail("fixture differs from production V3 generator and codec bytes")
    if _sha256(actual) != EXPECTED_SHA256:
        _fail("fixture hash differs from the approved V3 hash")
    print("V3_FIXTURE_SHA256=%s" % _sha256(actual))
    _finish()


func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_generator_v3_fixture_author")
    quit(1 if _failures > 0 else 0)
