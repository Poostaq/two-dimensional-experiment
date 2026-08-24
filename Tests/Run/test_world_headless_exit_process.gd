extends SceneTree

const TOOL_PATH := "res://Tools/WorldMap/headless_world_run_start.gd"
const EXPECTED := "{\"event\":\"world_generation_failed\",\"code\":\"WORLD_CONSTRAINT_UNSATISFIABLE\",\"seed_hex\":\"696d706f737369626c65\",\"generator_version\":1,\"namespace\":\"town\",\"constraint\":\"town_count=7,min_distance=4,radius=2\",\"build_version\":\"dev-test\"}"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not FileAccess.file_exists(TOOL_PATH):
        _fail("headless world run-start tool is missing")
        _finish()
        return
    var output: Array = []
    var args := PackedStringArray([
        "--quiet",
        "--headless",
        "--path",
        ProjectSettings.globalize_path("res://"),
        "--script",
        TOOL_PATH,
        "--",
        "--force-unsatisfiable",
        "--build-version",
        "dev-test",
    ])
    var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
    var combined := "\n".join(output)
    _assert_equal(exit_code, 70, "process exit status")
    _assert_equal(combined.count(EXPECTED), 1, "one canonical failure record")
    _finish()


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_headless_exit_process")
    quit(1 if _failures > 0 else 0)
