extends SceneTree

const FORMATTER_PATH := "res://Scripts/Run/world_failure_formatter.gd"
const ERROR_PATH := "res://Scripts/WorldMap/world_generation_error.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var formatter: GDScript = load(FORMATTER_PATH)
    var error_script: GDScript = load(ERROR_PATH)
    if formatter == null:
        _fail("WorldFailureFormatter script is missing")
        _finish()
        return
    var error: RefCounted = error_script.new(
        "WORLD_CONSTRAINT_UNSATISFIABLE",
        "64656661756c742d72756e",
        1,
        "town",
        "town_count=7,min_distance=4,radius=2"
    )
    var expected := "{\"event\":\"world_generation_failed\",\"code\":\"WORLD_CONSTRAINT_UNSATISFIABLE\",\"seed_hex\":\"64656661756c742d72756e\",\"generator_version\":1,\"namespace\":\"town\",\"constraint\":\"town_count=7,min_distance=4,radius=2\",\"build_version\":\"dev-test\"}\n"
    _assert_equal(formatter.format_json_line(error, "dev-test"), expected, "canonical failure line")
    _assert_equal(formatter.format_json_line(error, "quote\"test").count("\n"), 1, "one physical line")
    _finish()


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
    if actual != expected:
        _fail("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_headless_failure")
    quit(1 if _failures > 0 else 0)
